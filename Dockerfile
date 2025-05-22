# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.28.0@sha256:eaa7e36decc3421fc04478c586dfea0d931cebe47d5bc0b15d758a32ba51126f
COPY public /usr/share/nginx/html
COPY container_files/nginx.conf /etc/nginx/nginx.conf


# the nginx image runs /docker-entrypoint.sh and /docker-entrypoint.d/*
# might want to override later
#ENTRYPOINT []
# the global option passed here runs nginx in the foreground
#CMD ["nginx", "-g", "daemon off;"]

# the nginx container listens here by default
EXPOSE 80/tcp
