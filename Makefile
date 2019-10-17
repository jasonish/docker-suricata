NAME :=	jasonish/suricata
TAG ?=	$(shell git rev-parse --abbrev-ref HEAD)

CORES :=$(shell cat /proc/cpuinfo | grep ^processor | wc -l)

DOCKER ?=docker

all: build

build:
	${DOCKER} build --pull --rm -t ${NAME}:${TAG} --build-arg CORES="${CORES}" .

clean:
	find . -name \*~ -print0 | xargs -0 rm -f

push-branch: build
	${DOCKER} push ${NAME}:${TAG}

push: push-branch
