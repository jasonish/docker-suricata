#! /bin/sh

set -e

VERSIONS="master 6.0 5.0"

for v in ${VERSIONS}; do
    (cd $v && ../build.sh $@)
done
