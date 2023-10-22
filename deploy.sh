#! /bin/bash

set -e

REPOS=(
    "docker.io/jasonish/suricata"
    "quay.io/jasonish/suricata"
)

REPO=${REPO:-"docker.io/jasonish/suricata"}
MAJOR=$(basename $(pwd))
VERSION=$(cat VERSION)
LATEST=$(cat ../LATEST)
ARCHS=(amd64 arm64v8)
DOCKER=docker

TAGS=()
PUSHED_IMAGES=()
PUSHED_MANIFESTS=()

args=()

while [ "$#" -gt 0 ]; do
    key="$1"
    case "${key}" in
        --podman)
            DOCKER="podman"
            ;;
        --build)
            build="yes"
            ;;
        --push)
            push="yes"
            ;;
        --manifest)
            manifest="yes"
            ;;
        *)
            args+=($key)
            ;;
    esac
    shift
done

if [[ "${manifest}" = "yes" && "${push}" != "yes" ]]; then
    echo "error: --manifest requires --push"
    exit 1
fi

set -- "${args[@]}"

build() {
    arch="$1"; shift

    if ! test -e Dockerfile.${arch}; then
        echo "error: Dockerfile for arch ${arch} does not exist."
        exit 1
    fi

    tag="${REPO}:${VERSION}-${arch}"
    TAG=${tag} ARCH=${arch} ../build.sh
    TAGS+=("${tag}")

    tag="${REPO}:${VERSION}-${arch}-profiling"
    TAG=${tag} ARCH=${arch} ../build.sh profiling
    TAGS+=("${tag}")
}

manifest() {
    version="$1"
    variant="$2"
    ${DOCKER} manifest rm "${REPO}:${version}${variant}" > /dev/null 2>&1 || true
    for arch in "${ARCHS[@]}"; do
        if test -e Dockerfile.${arch}; then
            ${DOCKER} manifest create "${REPO}:${version}${variant}" \
                -a "${REPO}:${VERSION}-${arch}${variant}"
        fi
    done

    manifest_name="${REPO}:${version}${variant}"

    echo "Pushing manifest ${manifest_name}"
    PUSHED_MANIFESTS+=("${manifest_name}")
    if [ "${DOCKER}" = "docker" ]; then
        ${DOCKER} manifest push "${manifest_name}"
    elif [ "${DOCKER}" = "podman" ]; then
        ${DOCKER} manifest push --purge "${manifest_name}" \
            docker://"${manifest_name}"
    else
        echo "error: unsupported docker command: ${DOCKER}"
        exit 1
    fi
}
 
if [[ "${build}" = "yes" ]]; then
    for repo in "${REPOS[@]}"; do
	for arch in "${ARCHS[@]}"; do
            if test -e Dockerfile.${arch}; then
		REPO=${repo} build "${arch}"
		REPO=${repo} build "${arch}" "profiling"
            fi
	done
    done
fi

if [[ "${push}" = "yes" ]]; then
    for tag in "${TAGS[@]}"; do
	echo "===> Pushing ${tag}"
	${DOCKER} push ${tag}
	PUSHED_IMAGES+=("${tag}")
    done
fi

if [[ "${manifest}" = "yes" ]]; then
    for repo in "${REPOS[@]}"; do
	REPO=${repo} manifest ${VERSION}
	REPO=${repo} manifest ${VERSION} "-profiling"
	if [ "${MAJOR}" != "${VERSION}" ]; then
	    REPO=${repo} manifest ${MAJOR}
	    REPO=${repo} manifest ${MAJOR} "-profiling"
	fi
	if [ "${MAJOR}" = "${LATEST}" ]; then
	    REPO=${repo} manifest latest
	    REPO=${repo} manifest latest "-profiling"
	fi
    done
fi

echo "Tags built:"
for tag in "${TAGS[@]}"; do
    echo "- ${tag}"
done

if [ "${PUSHED_IMAGES}" ]; then
    echo "Tags pushed:"
    for tag in "${PUSHED_IMAGES[@]}"; do
        echo "- ${tag}"
    done
fi

if [ "${PUSHED_MANIFESTS}" ]; then
    echo "Manifests pushed:"
    for tag in "${PUSHED_MANIFESTS[@]}"; do
        echo "- ${tag}"
    done
fi
