#! /usr/bin/env bash

set -e

VERSION=$(cat VERSION)
DOCKER=docker
CORES=$(nproc --all)
MAJOR=$(basename $(pwd))
LATEST=$(cat ../LATEST)
NOCACHE=""

PUSH=no
MANIFEST=no

REPOS=(
    "docker.io/jasonish/suricata"
    "quay.io/jasonish/suricata"
    "ghcr.io/jasonish/suricata"
)

while [ "$#" -gt 0 ]; do
    key="$1"
    case "${key}" in
        --push)
            PUSH="yes"
            ;;
        --manifest)
            MANIFEST="yes"
            ;;
        --no-cache)
            NOCACHE="--no-cache"
            ;;
        *)
            args+=($key)
            ;;
    esac
    shift
done

BUILT=()
PUSHED=()

build() {
    configure_args="$1"
    ${DOCKER} build ${NOCACHE} \
              --rm \
              --pull \
              --build-arg VERSION=${VERSION} \
              --build-arg CORES=${CORES} \
              --build-arg CONFIGURE_ARGS="${configure_args}" \
              --platform linux/${arch} \
              --tag ${tag} \
              -f Dockerfile.${arch} \
              .
    BUILT+=(${tag})
}

TAGS=()

for repo in "${REPOS[@]}"; do
    for arch in amd64 arm64; do
        tag=${repo}:${VERSION}-${arch}
        arch=${arch} tag=${tag} build

        tag=${tag}-profiling
        arch=${arch} tag=${tag} build \
            "--enable-profiling --enable-profiling-locks"
    done
done

if [[ "${PUSH}" = "yes" ]]; then
    for tag in "${BUILT[@]}"; do
        ${DOCKER} push ${tag}
        PUSHED+=(${tag})
    done
fi    

for tag in "${BUILT[@]}"; do
    echo "Built: ${tag}"
done

for tag in "${PUSHED[@]}"; do
    echo "Pushed: ${tag}"
done

if [[ "${MANIFEST}" = "yes" ]]; then
    for repo in "${REPOS[@]}"; do
        docker manifest create --amend \
               ${repo}:${MAJOR} \
               ${repo}:${VERSION}-amd64 \
               ${repo}:${VERSION}-arm64
        docker manifest push ${repo}:${MAJOR}
        
        docker manifest create --amend \
               ${repo}:${MAJOR}-profiling \
               ${repo}:${VERSION}-amd64-profiling \
               ${repo}:${VERSION}-arm64-profiling
        docker manifest push ${repo}:${MAJOR}-profiling
        
        docker manifest create --amend \
               ${repo}:${VERSION} \
               ${repo}:${VERSION}-amd64 \
               ${repo}:${VERSION}-arm64
        docker manifest push ${repo}:${VERSION}
        
        docker manifest create --amend \
               ${repo}:${VERSION}-profiling \
               ${repo}:${VERSION}-amd64-profiling \
               ${repo}:${VERSION}-arm64-profiling
        docker manifest push ${repo}:${VERSION}-profiling
        
        if [[ "${MAJOR}" = "${LATEST}" ]]; then
            docker manifest create --amend \
                   ${repo}:latest \
                   ${repo}:${VERSION}-amd64 \
                   ${repo}:${VERSION}-arm64
            docker manifest push ${repo}:latest
            
            docker manifest create --amend \
                   ${repo}:latest-profiling \
                   ${repo}:${VERSION}-amd64-profiling \
                   ${repo}:${VERSION}-arm64-profiling
            docker manifest push ${repo}:latest-profiling
        fi
    done
fi

