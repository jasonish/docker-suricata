#! /bin/bash
#
# License: MIT

set -e

if [ "${REPO}" = "" ]; then
    REPO="docker.io/jasonish/suricata"
fi

MAJOR=$(basename $(pwd))
VERSION=$(cat VERSION)
LATEST=$(cat ../LATEST)

manifest_only="no"

builder="docker"
build_command="build"

# Handle command line arguments.
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        --push)
            push="yes"
            shift
            ;;
        --no-cache)
            no_cache="--no-cache"
            shift
            ;;
        --manifest-only)
            manifest_only="yes"
            shift
            ;;
        --*)
            echo "error: bad argument: ${arg}"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

ARCHS=(amd64 arm32v6 arm64v8)
if [[ $# -gt 0 ]]; then
    archs=$@
else
    archs=${ARCHS[@]}
fi

if [[ "${manifest_only}" = "yes" ]]; then
    archs=""
fi

# Get the number of cores, defaulting to 2 if unable to get.
CORES=$(cat /proc/cpuinfo | grep ^processor | wc -l)
if [ "${CORES}" = "0" ]; then
    CORES=2
fi

build() {
    arch="$1"
    profiling="$2"

    tag="${REPO}:${VERSION}-${arch}"

    configure_args=""
    if [ "${profiling}" = "profiling" ]; then
        configure_args="${configure_args} --enable-profiling --enable-profiling-locks"
        tag="${tag}-profiling"
    fi

    build_opts=""

    if [[ "${CARGO_NET_GIT_FETCH_WITH_CLI}" ]]; then
        build_opts="${build_opts} --build-arg CARGO_NET_GIT_FETCH_WITH_CLI=${CARGO_NET_GIT_FETCH_WITH_CLI}"
    fi

    ${builder} ${build_command} \
               ${build_opts} ${no_cache} \
               --rm \
	       --build-arg VERSION="${VERSION}" \
               --build-arg CORES="${CORES}" \
               --build-arg CONFIGURE_ARGS="${configure_args}" \
               --tag "${tag}" \
               -f Dockerfile.${arch} \
               .
}

for arch in ${archs[@]}; do
    echo "===> Building ${arch}"
    build $arch
    echo "===> Building ${arch} (profiling)"
    build $arch profiling
done

if [ "${push}" = "yes" ]; then
    for arch in ${archs[@]}; do
        tag="${REPO}:${VERSION}-${arch}"
        echo "Pushing ${tag}"
        docker push ${tag}

        tag="${REPO}:${VERSION}-${arch}-profiling"
        echo "Pushing ${tag}"
        docker push ${tag}
    done

    # Create and push the manifest for the version.
    echo "Creating manifest: ${REPO}:${VERSION}"
    docker manifest create ${REPO}:${VERSION} \
           -a ${REPO}:${VERSION}-amd64 \
           -a ${REPO}:${VERSION}-arm32v6 \
           -a ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm64v8
    docker manifest push --purge ${REPO}:${VERSION}

    manifest="${REPO}:${VERSION}-profiling"
    echo "Creating manifest: ${manifest}"
    docker manifest create ${manifest} \
           -a ${REPO}:${VERSION}-amd64-profiling \
           -a ${REPO}:${VERSION}-arm32v6-profiling \
           -a ${REPO}:${VERSION}-arm64v8-profiling
    docker manifest push --purge ${manifest}

    # Create and push the manifest for the major version.
    docker manifest create ${REPO}:${MAJOR} \
           -a ${REPO}:${VERSION}-amd64 \
           -a ${REPO}:${VERSION}-arm32v6 \
           -a ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm64v8
    docker manifest push --purge ${REPO}:${MAJOR}

    manifest="${REPO}:${MAJOR}-profiling"
    echo "Creating manifest: ${manifest}"
    docker manifest create ${manifest} \
           -a ${REPO}:${VERSION}-amd64-profiling \
           -a ${REPO}:${VERSION}-arm32v6-profiling \
           -a ${REPO}:${VERSION}-arm64v8-profiling
    docker manifest push --purge ${manifest}

    if [ "${MAJOR}" = "${LATEST}" ]; then
        for arch in ${archs[@]}; do
            docker tag ${REPO}:${VERSION}-${arch} ${REPO}:latest-${arch}
            docker push ${REPO}:latest-${arch}
        done
        docker manifest create ${REPO}:latest \
               -a ${REPO}:${VERSION}-amd64 \
               -a ${REPO}:${VERSION}-arm32v6 \
               -a ${REPO}:${VERSION}-arm64v8
        docker manifest annotate --arch arm --variant v6 \
               ${REPO}:latest ${REPO}:${VERSION}-arm32v6
        docker manifest annotate --arch arm --variant v8 \
               ${REPO}:latest ${REPO}:${VERSION}-arm64v8
        docker manifest annotate --arch arm64 --variant v8 \
               ${REPO}:latest ${REPO}:${VERSION}-arm64v8
        docker manifest push --purge ${REPO}:latest

        # Profiling.
        docker manifest create ${REPO}:latest-profiling \
               -a ${REPO}:${VERSION}-amd64-profiling \
               -a ${REPO}:${VERSION}-arm32v6-profiling \
               -a ${REPO}:${VERSION}-arm64v8-profiling
        docker manifest push --purge ${REPO}:latest-profiling
    fi
fi
