# https://hub.docker.com/_/nginx
# https://github.com/nginxinc/docker-nginx
FROM nginx:1.27.3@sha256:42e917aaa1b5bb40dd0f6f7f4f857490ac7747d7ef73b391c774a41a8b994f15
COPY public /usr/share/nginx/html

# the nginx container listens here by default
EXPOSE 80/tcp
