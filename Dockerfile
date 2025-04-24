# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.28.0@sha256:9334faa48d730571746a7baab46d62896cb685502bc29d270c4495e26fc78afd
COPY public /usr/share/nginx/html
COPY container_files/nginx.conf /etc/nginx/nginx.conf


# the nginx image runs /docker-entrypoint.sh and /docker-entrypoint.d/*
# might want to override later
#ENTRYPOINT []
# the global option passed here runs nginx in the foreground
#CMD ["nginx", "-g", "daemon off;"]

# the nginx container listens here by default
EXPOSE 80/tcp
