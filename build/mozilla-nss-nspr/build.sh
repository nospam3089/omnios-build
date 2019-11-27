#!/usr/bin/bash
#
# {{{ CDDL HEADER
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source. A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
# }}}
#
# Copyright 2017 OmniTI Computer Consulting, Inc.  All rights reserved.
# Copyright 2019 OmniOS Community Edition (OmniOSce) Association.

. ../../lib/functions.sh

PROG=nss
VER=3.47.1
# Include NSPR version since we're downloading a combined tarball.
NSPRVER=4.23
# But set BUILDDIR to just be the NSS version.
set_builddir "$PROG-$VER"
PKG=$PROG ##IGNORE##
SUMMARY="Overridden for each package below"
DESC="$SUMMARY"

# NOTE: These are generated by uname and build variables.
DIST32=SunOS5.11_i86pc_gcc_OPT.OBJ
DIST64=SunOS5.11_i86pc_gcc_64_OPT.OBJ

BUILD_DEPENDS_IPS="library/nspr/header-nspr"

MAKE_ARGS="
    BUILD_OPT=1
    NS_USE_GCC=1
    NO_MDUPDATE=1
    NSDISTMODE=copy
    NSS_USE_SYSTEM_SQLITE=1
    NSS_ENABLE_WERROR=0
"
MAKE_ARGS_WS_32="
    XCFLAGS=\"-g $CFLAGS32 $CFLAGS\"
    LDFLAGS=\"$LDFLAGS32 $LDFLAGS\"
"
MAKE_ARGS_WS_64="
    XCFLAGS=\"-g $CFLAGS64 $CFLAGS\"
    LDFLAGS=\"$LDFLAGS64 $LDFLAGS\"
"

NSS_LIBS="libfreebl3.so libnss3.so libnssckbi.so libnssdbm3.so
          libnssutil3.so libsmime3.so libsoftokn3.so libssl3.so"
NSS_BINS="certutil"
NSS_MANS="certutil.1"

NSPR_LIBS="libnspr4.so libplc4.so libplds4.so"
NSPR_BINS=
NSPR_MANS=

NSPR_SAVE="$TMPDIR/nspr-save.$$"

export CC

make_clean() {
    # Assume PWD == top-level with nss & nspr subdirs.
    /bin/rm -rf dist
    pushd nss >/dev/null || logerr "pushd nss"
    logcmd gmake $MAKE_ARGS nss_clean_all || logerr "Can't make clean"
    popd >/dev/null
}

configure32() {
    # Get the install/prototype path out of the way now.
    logcmd mkdir -p $DESTDIR/usr/lib/mps \
        || logerr "Failed to create NSS install directory."
}

make_prog32() {
    eval set -- $MAKE_ARGS_WS_32
    pushd nss >/dev/null || logerr "pushd nss"
    logmsg "  -- nspr"
    logcmd $MAKE $MAKE_ARGS "$@" $MAKE_JOBS build_nspr \
        || logerr "nspr build failed"
    for d in coreconf lib cmd; do
        logmsg "  -- $d"
        logcmd $MAKE $MAKE_ARGS "$@" -C $d || logerr "$d build failed"
    done
    popd >/dev/null
}

make_install32() {
    logmsg "Installing libraries (32)"
    for lib in $TGT_LIBS; do
        logcmd cp $TMPDIR/$BUILDDIR/dist/$DIST32/lib/$lib \
            $DESTDIR/usr/lib/mps/$lib \
            || logerr "Install $lib failed"
    done
    logmsg "Installing headers"
    logcmd mkdir -p $DESTDIR/usr/include/mps \
        || logerr "Failed to create NSS header install directory."
    logcmd cp $TMPDIR/$BUILDDIR/dist/public/nss/* $DESTDIR/usr/include/mps/
    logcmd cp $TMPDIR/$BUILDDIR/dist/public/dbm/* $DESTDIR/usr/include/mps/

    # Save 32-bit NSPR dist off for NSPR build.
    logcmd mkdir $NSPR_SAVE
    for lib in $NSPR_LIBS; do
        logcmd cp $TMPDIR/$BUILDDIR/dist/$DIST32/lib/$lib $NSPR_SAVE
    done
    logcmd cp $TMPDIR/$BUILDDIR/nspr/$DIST32/config/nspr.pc $NSPR_SAVE

    logmsg "Installing binaries (32)"
    logcmd mkdir -p $DESTDIR/usr/bin/i386
    for bin in $TGT_BINS; do
        logcmd cp $TMPDIR/$BUILDDIR/dist/$DIST32/bin/$bin \
            $DESTDIR/usr/bin/i386/$bin \
            || logerr "Install $bin failed"
        logcmd elfedit -e 'dyn:runpath /usr/lib/mps' \
            $DESTDIR/usr/bin/i386/$bin
    done
}

configure64() {
    # Get the install/prototype path out of the way now.
    logcmd mkdir -p $DESTDIR/usr/lib/mps/amd64 \
        || logerr "Failed to create NSS install directory."
}

make_prog64() {
    eval set -- $MAKE_ARGS_WS_64
    pushd nss >/dev/null || logerr "pushd nss"
    logmsg "  -- nspr"
    logcmd $MAKE $MAKE_ARGS "$@" $MAKE_JOBS USE_64=1 build_nspr \
        || logerr "nspr build failed"
    for d in coreconf lib cmd; do
        logmsg "  -- $d"
        logcmd $MAKE $MAKE_ARGS "$@" USE_64=1 -C $d || logerr "$d build failed"
    done
    popd >/dev/null
}

make_install64() {
    logmsg "Installing libraries (64)"
    for lib in $TGT_LIBS; do
        logcmd cp $TMPDIR/$BUILDDIR/dist/$DIST64/lib/$lib \
            $DESTDIR/usr/lib/mps/amd64/$lib \
            || logerr "Install $lib failed"
    done
    logmsg "Installing binaries (64)"
    logcmd mkdir -p $DESTDIR/usr/bin/amd64
    for bin in $TGT_BINS; do
        logcmd cp $TMPDIR/$BUILDDIR/dist/$DIST64/bin/$bin \
            $DESTDIR/usr/bin/amd64/$bin
        logcmd elfedit -e 'dyn:runpath /usr/lib/mps/amd64' \
            $DESTDIR/usr/bin/amd64/$bin \
            || logerr "Install $bin failed"
    done
    for man in $TGT_MANS; do
        sec=${man/#*./}
        logcmd mkdir -p $DESTDIR/usr/share/man/man$sec
        logcmd cp $TMPDIR/$BUILDDIR/$TGT_COMP/doc/nroff/$man \
            $DESTDIR/usr/share/man/man$sec/ || logerr "Install $man failed"
    done
}

secv1_links() {
    logcmd ln -s amd64 $DESTDIR/usr/lib/mps/64
    logcmd mkdir -p $DESTDIR/usr/lib/mps/secv1/amd64
    logcmd ln -s amd64 $DESTDIR/usr/lib/mps/secv1/64
    logcmd mkdir -p $DESTDIR/usr/lib/pkgconfig
    sed < $SRCDIR/files/$PC_FILE \
        > $DESTDIR/usr/lib/pkgconfig/`basename $PC_FILE` "
        s/__NSSVER__/$VER/g
        s/__NSPRVER__/$NSPRVER/g
    "
    for lib in $TGT_LIBS; do
        logcmd ln -s ../../amd64/$lib $DESTDIR/usr/lib/mps/secv1/amd64/$lib
        logcmd ln -s ../$lib $DESTDIR/usr/lib/mps/secv1/$lib
    done
}

init
download_source $PROG $PROG "$VER-with-nspr-$NSPRVER"
patch_source

###########################################################################
# NSS

LOCAL_MOG_FILE=nss-local.mog
TGT_COMP=nss
TGT_LIBS=$NSS_LIBS
TGT_BINS=$NSS_BINS
TGT_MANS=$NSS_MANS
PC_FILE=nss.pc

prep_build
build
secv1_links
make_isa_stub

###########################################################################
# system/library/mozilla-nss/headers-nss

PKG=system/library/mozilla-nss/header-nss
SUMMARY="Network Security Services Headers"
DESC="$SUMMARY"
make_package header-nss.mog

###########################################################################
# system/library/mozilla-nss

PKG=system/library/mozilla-nss
SUMMARY="Network Security Services Libraries/Utilities"
DESC="$SUMMARY"
make_package nss.mog

###########################################################################
# Clean up NSS.

clean_up

###########################################################################
# library/nspr/header-nspr

PKG=library/nspr/header-nspr
SUMMARY="Netscape Portable Runtime Headers"
DESC="$SUMMARY"

VER=$NSPRVER
TGT_COMP=nspr
TGT_LIBS=$NSPR_LIBS
TGT_BINS=$NSPR_BINS
TGT_MANS=$NSPR_MANS
PC_FILE=nspr.pc
LOCAL_MOG_FILE=nspr-local.mog
DESTDIR=${DESTDIR/nss/nspr}

prep_build

for dir in md obsolete private pkgconfig; do
    logcmd mkdir -p $DESTDIR/usr/include/mps/$dir \
        || logerr "Failed to create NSPR header install $dir directory."
done

for dir in amd64 pkgconfig amd64/pkgconfig; do
    logcmd mkdir -p $DESTDIR/usr/lib/mps/$dir \
        || logerr "Failed to create NSPR install $dir directory."
done

make_install64

for dir in "" obsolete private; do
    logcmd cp \
        $TMPDIR/$BUILDDIR/dist/$DIST64/include/$dir/*.h \
        $DESTDIR/usr/include/mps/$dir \
        || logerr "Failed to copy $dir header files"
done

logcmd cp \
    $TMPDIR/$BUILDDIR/dist/$DIST64/include/md/*.cfg \
    $DESTDIR/usr/include/mps/md \
    || logerr "Failed to copy md/ cfg files"

make_package header-nspr.mog

###########################################################################
# library/nspr

PKG=library/nspr
SUMMARY="Netscape Portable Runtime"
DESC="$SUMMARY"

logcmd cp $TMPDIR/$BUILDDIR/nspr/$DIST64/config/nspr.pc \
    $DESTDIR/usr/lib/mps/amd64/pkgconfig \
    || logerr "Failed to copy pkgconfig"

# Restore 32-bit NSPR libraries.
logcmd cp $NSPR_SAVE/nspr.pc $DESTDIR/usr/lib/mps/pkgconfig/nspr.pc
logcmd cp $NSPR_SAVE/*.so $DESTDIR/usr/lib/mps \
    || logerr "32-bit NSPR library installation failure"
logcmd rm -rf $NSPR_SAVE

secv1_links

make_package nspr.mog

###########################################################################

# This cleans up NSPR.
clean_up

# Vim hints
# vim:ts=4:sw=4:et:fdm=marker
