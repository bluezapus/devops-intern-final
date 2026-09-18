# Loki Logging Setup

## Overview

This monitoring stack collects logs from the NGINX application deployed by Nomad.

The stack consists of:

- **Grafana** — log visualization and exploration
- **Loki** — centralized log aggregation and storage
- **Promtail** — Docker log discovery and forwarding to Loki

The NGINX application runs as a Docker container managed by Nomad. Promtail discovers the Nomad-managed container through the Docker socket and forwards its logs to Loki.

## Start the Monitoring Stack

From the repository root:

```bash
docker compose -f monitoring/docker-compose.yaml up -d
```

Verify the services:

```bash
docker compose -f monitoring/docker-compose.yaml ps
```

Expected services:

```text
grafana
loki
promtail
```

Verify Loki readiness:

```bash
curl -i http://localhost:3100/ready
```

Expected result after initialization:

```text
HTTP/1.1 200 OK

ready
```

Immediately after startup Loki may temporarily report:

```text
Ingester not ready: waiting for 15s after being ready
```

This is expected while the ingester initializes. Retry the readiness request after several seconds.

## Grafana Configuration

Grafana is available locally at:

```text
http://localhost:3000
```

Add **Loki** as a Grafana data source and use:

```text
http://loki:3100
```

The hostname `loki` is used because Grafana and Loki run in the same Docker Compose network.

Use **Save & test** to verify the connection.

## Promtail Log Discovery

Promtail uses Docker service discovery through:

```text
/var/run/docker.sock
```

The Docker socket is mounted read-only into Promtail.

Inspection of the Nomad-managed NGINX container showed the following Nomad metadata:

```text
com.hashicorp.nomad.alloc_id
```

Example observed during the assessment:

```text
com.hashicorp.nomad.alloc_id=24d15392-1df7-1620-8c39-c8ef92345144
```

The container did not expose a Nomad job-name label. Promtail therefore uses the Nomad allocation label to identify Nomad-managed containers and assigns the application job identifier explicitly.

The resulting Loki labels are:

| Label | Description |
| --- | --- |
| `container` | Docker container name |
| `job` | Application identifier (`nginx-app`) |
| `nomad_alloc_id` | Nomad allocation identifier |
| `service_name` | Application service identifier (`nginx`) |

Promtail only keeps containers containing the Nomad allocation label. This prevents unrelated Docker containers and the monitoring stack itself from being mixed into the NGINX application log stream.

## Verify the Nomad Application

Check the job:

```bash
nomad job status nginx-app
```

Check its allocation:

```bash
nomad alloc status <allocation-id>
```

During validation the deployment reported:

```text
Status              = running
Deployment Health   = healthy
```

The allocation uses a dynamic host port mapped to container port `8080`.

Example observed during testing:

```text
*http  yes  192.168.20.8:26862 -> 8080
```

The host port is dynamic and can change when Nomad creates a new allocation.

## Generate NGINX Access Logs

Determine the current address:

```bash
nomad alloc status <allocation-id>
```

Generate a normal request:

```bash
curl -i http://<nomad-address>/
```

Verify the health endpoint:

```bash
curl -i http://<nomad-address>/healthz
```

Generate a missing-path request:

```bash
curl -i http://<nomad-address>/not-found
```

Expected response:

```text
HTTP/1.1 404 Not Found
```

Additional test requests can be generated with:

```bash
curl -i http://<nomad-address>/missing-page
curl -i http://<nomad-address>/test-404
```

## LogQL Queries

Open **Grafana → Explore** and select Loki.

### NGINX Application Logs

```logql
{job="nginx-app"}
```

### HTTP 404 Requests

```logql
{job="nginx-app"} |= "404"
```

The second query was validated by requesting missing paths from the deployed NGINX application.

## Observed Results

The validated log flow is:

```text
NGINX on Nomad
      |
      v
Docker logs
      |
      v
Promtail
      |
      v
Loki
      |
      v
Grafana Explore
```

Promtail successfully discovered the Docker container managed by Nomad. Loki received the forwarded logs, and Grafana Explore was able to isolate the NGINX application logs.

HTTP 404 access logs could be isolated with:

```logql
{job="nginx-app"} |= "404"
```

The log stream included labels identifying the Docker container and its Nomad allocation.

## Troubleshooting

### Loki Initially Reported Not Ready

Immediately after startup Loki returned:

```text
Ingester not ready: waiting for 15s after being ready
```

The readiness endpoint was retried after the initialization period:

```bash
curl -i http://localhost:3100/ready
```

### Nomad Job Label Was Missing

The initial Promtail configuration expected Nomad job metadata, but inspection of the actual container showed only:

```text
com.hashicorp.nomad.alloc_id
```

The metadata was inspected with:

```bash
docker inspect <container-id> \
  --format '{{json .Config.Labels}}' | jq
```

Observed metadata:

```json
{
  "com.hashicorp.nomad.alloc_id": "24d15392-1df7-1620-8c39-c8ef92345144",
  "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>"
}
```

Promtail was changed to identify Nomad-managed containers using `nomad_alloc_id` and assign:

```text
job=nginx-app
```

explicitly.

### Monitoring Logs Appeared in Grafana Explore

An initial broad query:

```logql
{container=~".+"}
```

also returned monitoring-container logs.

Promtail was then restricted to containers containing:

```text
com.hashicorp.nomad.alloc_id
```

The application could subsequently be isolated with:

```logql
{job="nginx-app"}
```

## Evidence

Monitoring stack:

![Monitoring Stack](../docs/screenshots/monitoring-stack.png)

Grafana Loki data source:

![Grafana Loki Data Source](../docs/screenshots/grafana-loki-datasource.png)

Loki labels:

![Grafana Loki Labels](../docs/screenshots/grafana-labels.png)

Grafana Explore showing NGINX logs and HTTP 404 filtering:

![Grafana Explore](../docs/screenshots/grafana-explore.png)

## Stop the Monitoring Stack

Stop the services:

```bash
docker compose -f monitoring/docker-compose.yaml down
```

To also remove monitoring volumes:

```bash
docker compose -f monitoring/docker-compose.yaml down -v
```
