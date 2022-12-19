FROM alpine:latest

RUN apk --no-cache add nginx curl && rm -rf /etc/nginx/http.d/*.conf

COPY config/nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/www/test-app
RUN chown -R nobody.nobody /var/www/test-app && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/log/nginx

user nobody
WORKDIR /var/www/test-app

COPY --chown=nobody test-app/ /var/www/test-app/

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]