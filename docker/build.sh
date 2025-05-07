#!/bin/bash

# from from project root as `bash docker/build.sh`
docker build \
    --tag coq-tactician-api \
    --file docker/plain.Dockerfile \
    --build-arg USERNAME=jdgallag \
    --build-arg USER_UID=1000 \
    --build-arg USER_GID=1000 \
    .
