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
BUILD=yes
VARIANT=both

REPOS=(
    "docker.io/jasonish/suricata"
    "quay.io/jasonish/suricata"
    "ghcr.io/jasonish/suricata"
)

ARCHES_ALL=("amd64" "arm64")

ARCHES=()

while [ "$#" -gt 0 ]; do
    key="$1"
    case "${key}" in
        --push)
            PUSH="yes"
            ;;
        --manifest)
            MANIFEST="yes"
            ;;
        --no-build)
            BUILD="no"
            ;;
        --no-cache)
            NOCACHE="--no-cache"
            ;;
        --arch)
            shift
            if [ "$#" -eq 0 ]; then
                echo "error: --arch requires a value" >&2
                exit 1
            fi
            ARCHES+=("$1")
            ;;
        --arch=*)
            ARCHES+=("${key#*=}")
            ;;
        --variant)
            shift
            if [ "$#" -eq 0 ]; then
                echo "error: --variant requires a value" >&2
                exit 1
            fi
            VARIANT="$1"
            ;;
        --variant=*)
            VARIANT="${key#*=}"
            ;;
        *)
            args+=($key)
            ;;
    esac
    shift
done

if [ ${#ARCHES[@]} -eq 0 ]; then
    ARCHES=("${ARCHES_ALL[@]}")
fi

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

if [[ "${BUILD}" = "yes" ]]; then
    for repo in "${REPOS[@]}"; do
        for arch in "${ARCHES[@]}"; do
            if [[ "${VARIANT}" = "regular" || "${VARIANT}" = "both" ]]; then
                tag=${repo}:${VERSION}-${arch}
                arch=${arch} tag=${tag} build
            fi

            if [[ "${VARIANT}" = "profiling" || "${VARIANT}" = "both" ]]; then
                tag=${repo}:${VERSION}-${arch}-profiling
                arch=${arch} tag=${tag} build \
                    "--enable-profiling --enable-profiling-locks"
            fi
        done
    done
fi

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
        docker manifest rm ${repo}:${MAJOR} || true
        docker manifest create --amend \
               ${repo}:${MAJOR} \
               ${repo}:${VERSION}-amd64 \
               ${repo}:${VERSION}-arm64
        docker manifest push ${repo}:${MAJOR}
        
        docker manifest rm ${repo}:${MAJOR}-profiling || true
        docker manifest create --amend \
               ${repo}:${MAJOR}-profiling \
               ${repo}:${VERSION}-amd64-profiling \
               ${repo}:${VERSION}-arm64-profiling
        docker manifest push ${repo}:${MAJOR}-profiling
        
        docker manifest rm ${repo}:${VERSION} || true
        docker manifest create --amend \
               ${repo}:${VERSION} \
               ${repo}:${VERSION}-amd64 \
               ${repo}:${VERSION}-arm64
        docker manifest push ${repo}:${VERSION}
        
        docker manifest rm ${repo}:${VERSION}-profiling || true
        docker manifest create --amend \
               ${repo}:${VERSION}-profiling \
               ${repo}:${VERSION}-amd64-profiling \
               ${repo}:${VERSION}-arm64-profiling
        docker manifest push ${repo}:${VERSION}-profiling
        
	if [[ "${MAJOR}" = "main" ]]; then
	    echo "*** Tagging main as master"

            docker manifest rm ${repo}:master || true
            docker manifest create --amend \
                   ${repo}:master \
                   ${repo}:${VERSION}-amd64 \
                   ${repo}:${VERSION}-arm64
            docker manifest push ${repo}:master

            docker manifest rm ${repo}:master-profiling || true
            docker manifest create --amend \
                   ${repo}:master-profiling \
                   ${repo}:${VERSION}-amd64-profiling \
                   ${repo}:${VERSION}-arm64-profiling
            docker manifest push ${repo}:master-profiling
	fi

        if [[ "${MAJOR}" = "${LATEST}" ]]; then
            echo "*** Tagging ${MAJOR} as latest"

            docker manifest rm ${repo}:latest || true
            docker manifest create --amend \
                   ${repo}:latest \
                   ${repo}:${VERSION}-amd64 \
                   ${repo}:${VERSION}-arm64
            docker manifest push ${repo}:latest
            
            docker manifest rm ${repo}:latest-profiling || true
            docker manifest create --amend \
                   ${repo}:latest-profiling \
                   ${repo}:${VERSION}-amd64-profiling \
                   ${repo}:${VERSION}-arm64-profiling
            docker manifest push ${repo}:latest-profiling
        fi
    done
fi
