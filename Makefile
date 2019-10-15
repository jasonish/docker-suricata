NAME :=	jasonish/suricata
TAG :=	$(shell git rev-parse --abbrev-ref HEAD)

CORES :=$(shell cat /proc/cpuinfo | grep ^processor | wc -l)

all: build

build:
	docker build --pull --rm -t ${NAME}:${TAG} --build-arg CORES="${CORES}" .

clean:
	find . -name \*~ -print0 | xargs -0 rm -f

push-branch: build
	docker push ${NAME}:${TAG}

push:
	$(MAKE) push-branch
