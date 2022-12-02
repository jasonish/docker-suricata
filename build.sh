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

ARCHS=(amd64 arm64v8 arm32v6)
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
    if test -e "Dockerfile.${arch}"; then
        echo "===> Building ${arch}"
        build $arch
        echo "===> Building ${arch} (profiling)"
        build $arch profiling
    fi
done

push_manifest() {
    local manifest_version="$1"
    shift
    local suffix="$1"
    shift
    push_archs=("$@")
    for arch in ${push_archs[@]}; do
        docker manifest create ${REPO}:${manifest_version}${suffix} \
            -a ${REPO}:${VERSION}-${arch}${suffix}
        case "${arch}" in
            arm64v8)
                docker manifest annotate --arch arm --variant v8 \
                    ${REPO}:${manifest_version}${suffix} ${REPO}:${VERSION}-${arch}${suffix}
                docker manifest annotate --arch arm64 --variant v8 \
                    ${REPO}:${manifest_version}${suffix} ${REPO}:${VERSION}-${arch}${suffix}
                ;;
            arm32v6)
                docker manifest annotate --arch arm --variant v6 \
                    ${REPO}:${manifest_version}${suffix} ${REPO}:${VERSION}-${arch}${suffix}
                ;;
        esac
    done

    docker manifest push --purge ${REPO}:${manifest_version}${suffix}
}

if [ "${push}" = "yes" ]; then
    available_archs=()

    for arch in ${archs[@]}; do
        if test -e "Dockerfile.${arch}"; then
            available_archs+=(${arch})
            tag="${REPO}:${VERSION}-${arch}"
            echo "Pushing ${tag}"
            docker push ${tag}

            tag="${REPO}:${VERSION}-${arch}-profiling"
            echo "Pushing ${tag}"
            docker push ${tag}
        fi
    done

    push_manifest "${VERSION}" "" "${available_archs[@]}"
    push_manifest "${MAJOR}" "" "${available_archs[@]}"

    push_manifest "${VERSION}" "-profiling" "${available_archs[@]}"
    push_manifest "${MAJOR}" "-profiling" "${available_archs[@]}"

    if [ "${MAJOR}" = "${LATEST}" ]; then
        push_manifest "latest" "" "${available_archs[@]}"
        push_manifest "latest" "-profiling" "${available_archs[@]}"
    fi
fi
