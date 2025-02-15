#!/usr/bin/bash

VER=1.8
MVER=${VER##*.}
PROG=jdk
PROGU=$PROG${MVER}u
REPO="https://hg.openjdk.java.net/$PROGU/$PROGU"

err() {
    echo "$@"
    exit 1
}

PWD=`pwd`
TAG="$1"
[ -z "$TAG" ] && err "usage: $0 <tag>"

dir=`mktemp -d`

set -x
pushd $dir >/dev/null
/usr/bin/hg clone $REPO $TAG || err "failed to checkout from $REPO"
pushd $TAG >/dev/null
/usr/bin/hg checkout $TAG || err "failed to update to $TAG"

for i in `seq 1 10`; do
    echo "get_sources $i..."
    /usr/bin/bash ./get_source.sh && break
    [ $i -ge 10 ] && err "failed to get sources"
done

/usr/bin/bash ./make/scripts/hgforest.sh checkout $TAG \
    || err "failed to update to $TAG"

/opt/ooce/bin/fd -H '^\.hg$' -td -X rm -rf

popd >/dev/null
popd >/dev/null

dest="$PWD/$TAG.tar.zst"
echo "compressing $TAG..."
/usr/bin/tar -cf - -C $dir $TAG | /usr/bin/pv | /usr/bin/zstd -9vc > "$dest"
/usr/bin/digest -a sha256 "$dest" > "$dest.sha256"

[ -d "$dir" ] && rm -rf "$dir"

