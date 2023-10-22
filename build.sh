#! /usr/bin/env bash

set -e
set -x

version=$(cat VERSION)
cores=$(cat /proc/cpuinfo | grep ^processor | wc -l)
arch=${ARCH:-amd64}
docker=${DOCKER:-docker}

if [[ "${TAG}" ]]; then
    tag="--tag ${TAG}"
fi

configure_args=""

while [ "$#" -gt 0 ]; do
    case "$1" in
	profiling)
	    configure_args="${configure_args} --enable-profiling --enable-profiling-locks"
	    ;;
	--*)
	    configure_args="${configure_args} $1"
	    ;;
	*)
	    echo "error: bad argument: $1"
	    exit 1
	    ;;
    esac
    shift
done

${docker} build --rm \
	  --build-arg VERSION=${version} \
	  --build-arg CORES=${cores} \
	  --build-arg CONFIGURE_ARGS="${configure_args}" \
	  ${tag} \
	  -f Dockerfile.${arch} \
	  .
