DIRS +=	master \
	6.0 \
	5.0 \
	4.1

all: build

build:
	for d in $(DIRS); do \
		(cd $$d && ../build.sh); \
	done

push:
	for d in $(DIRS); do \
		(cd $$d && ../build.sh push); \
	done

clean:
	find . -name \*~ -print -delete
