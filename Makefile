TAG :=	$(shell cat TAG)

all: build

build:
	docker build --rm -t ${TAG} .

clean:
	find . -name \*~ -print0 | xargs -0 rm -f
