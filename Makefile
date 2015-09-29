TAG :=	jasonish/suricata:latest

all: build

build:
	docker build --rm -t ${TAG} .
