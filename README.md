# Suricata Docker Image

Please refer to the README.md in the master branch for up to date
usage instructions.

https://github.com/jasonish/docker-suricata/blob/master/README.md

# Building for Arm v7 on x86_64

Building for Arm v7 on x86_64 requires the experimental docker buildx
support. Once that is enabled, the following needs to be run:
```
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx rm builder
docker buildx create --name builder --driver docker-container --use
docker buildx inspect --bootstrap
```
Then to build:
```
docker buildx build --platform linux/arm/v7 -f Dockerfile.arm7 .
```
