#!/bin/bash

set -euxo pipefail


function cleanup() {
  docker stop lichturm-website-debug-container
}

# nuke container when finished
trap cleanup EXIT

#hugo --minify

docker build -t lichturm-website-local-build:debug .
docker run --publish 8080:80 --detach --rm --name lichturm-website-debug-container lichturm-website-local-build:debug 

firefox --private-window http://localhost:8080

docker logs -f lichturm-website-debug-container

