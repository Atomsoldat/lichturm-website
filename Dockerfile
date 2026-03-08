# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.29.5@sha256:0236ee02dcbce00b9bd83e0f5fbc51069e7e1161bd59d99885b3ae1734f3392e
COPY public /usr/share/nginx/html
COPY container_files/nginx.conf /etc/nginx/nginx.conf


# the nginx image runs /docker-entrypoint.sh and /docker-entrypoint.d/*
# might want to override later
#ENTRYPOINT []
# the global option passed here runs nginx in the foreground
#CMD ["nginx", "-g", "daemon off;"]

# the nginx container listens here by default
EXPOSE 80/tcp
