# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.28.0@sha256:0ad9e58f00f6a0d92f8c0a2a32285366a0ee948d9f91aee4a2c965a5516c59d5
COPY public /usr/share/nginx/html
COPY container_files/nginx.conf /etc/nginx/nginx.conf


# the nginx image runs /docker-entrypoint.sh and /docker-entrypoint.d/*
# might want to override later
#ENTRYPOINT []
# the global option passed here runs nginx in the foreground
#CMD ["nginx", "-g", "daemon off;"]

# the nginx container listens here by default
EXPOSE 80/tcp
