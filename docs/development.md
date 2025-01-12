## Manually deploying
In case we want to mess with things without waiting for CI/CD, we can deploy the container ourselves.

```
gcloud projects list

gcloud config set core/project <PROJECT_NAME>
gcloud config set artifacts/location <REGION_NAME>
```


Figure out the image name using the following two command blocks

```
# get registry URI
gcloud artifacts repositories list
export REGISTRY_NAME=<REGISTRY_NAME>
export REGISTRY_URI=$(gcloud artifacts repositories describe $REGISTRY_NAME 2>&1 | grep Uri | awk '{print $2}')

# list images in that registry
export IMAGE_NAME=$(gcloud artifacts docker images list --include-tags $REGISTRY_URI 2>&1 | grep prod | awk '{print $1}')
```


If necessary, configure authentication for the  artifact registry being used (note that this refers to just the generic URI of the registry offered by google, nothing project specific).
See the first part of the `REGISTRY_URI` above.

```
gcloud auth configure-docker <ARTIFACTS_REGISTRY_NAME>

# build and push local image
docker build . -t $IMAGE_NAME:prod
docker push $IMAGE_NAME:prod

# get service name
gcloud run services list

# deploy new revision of cloud run service
gcloud run deploy --image=$IMAGE_NAME:prod --platform managed --port 80 <SERVICE_NAME>
```



