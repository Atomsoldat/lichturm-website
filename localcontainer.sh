#!/bin/bash

hugo --minify

docker build -t lichturm-website-local-build:debug .

docker run -p 8080:80 --rm lichturm-website-local-build:debug 
