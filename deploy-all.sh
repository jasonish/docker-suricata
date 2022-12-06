#! /bin/sh

set -e

VERSIONS="master 7.0 6.0"

for v in ${VERSIONS}; do
    echo "$0: Building ${v}"
    (cd $v && ../deploy.sh $@)
done
