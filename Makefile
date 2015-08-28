TAG :=	jasonish/suricata:stable

all: build

build:
	docker build --rm -t ${TAG} .
