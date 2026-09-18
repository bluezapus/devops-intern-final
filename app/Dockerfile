FROM nginx:1.27-alpine

ARG BUILD_SHA=unknown

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /tmp/index.html

RUN sed "s/BUILD_SHA/${BUILD_SHA}/g" /tmp/index.html > /usr/share/nginx/html/index.html && rm /tmp/index.html && chown -R nginx:nginx /usr/share/nginx/html && touch /var/run/nginx.pid && chown nginx:nginx /var/run/nginx.pid && chown -R nginx:nginx /var/cache/nginx && chown -R nginx:nginx /var/log/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q --spider http://localhost:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]