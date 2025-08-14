# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.29.1@sha256:0301e87c557f7514729bdb6d331f037c1f8fe607cbe87c0a8a68bae76d23ce16
COPY public /usr/share/nginx/html
COPY container_files/nginx.conf /etc/nginx/nginx.conf


# the nginx image runs /docker-entrypoint.sh and /docker-entrypoint.d/*
# might want to override later
#ENTRYPOINT []
# the global option passed here runs nginx in the foreground
#CMD ["nginx", "-g", "daemon off;"]

# the nginx container listens here by default
EXPOSE 80/tcp
