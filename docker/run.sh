#!/bin/bash

# from from project root as `bash docker/build.sh`
docker run \
    --rm --interactive --tty \
    --volume="$PWD:/home/jdgallag/workspace:rw" \
    coq-tactician-api \
    bash