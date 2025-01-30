#!/bin/bash

set -euxo pipefail


# group commands and run in background
{
 echo "waiting 2s for hugo to start running..."
 sleep 2
 firefox --private-window http://localhost:1313
} &

hugo serve \
	--buildDrafts=true \
	--disableFastRender \
	--ignoreCache \
	--noHTTPCache
	--navigateToChanged \
	--port 1313



