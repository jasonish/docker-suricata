TAG :=	jasonish/suricata

all: build

build:
	docker build --rm -t ${TAG} .
