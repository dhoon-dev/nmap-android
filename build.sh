#!/usr/bin/env sh

set -e

NMAP_NAME=nmap
NMAP_VER=7.70
NMAP_HOST=arm-linux-androideabi

NDK_VER=r15c
NDK_ANDROID_PLATFORM=android-26
NDK_BUILD_PLATFORM=linux-x86_64
NDK=${PWD}/ndk
NDK_TOOLCHAIN=${NMAP_HOST}-4.8
NDK_STL=libc++
NDK_NAME=android-ndk

NMAP_ARCHIVE=${NMAP_NAME}-${NMAP_VER}.tar.bz2
NMAP_ARCHIVE_FMT=bz2
NMAP_DL_URL=https://nmap.org/dist/${NMAP_ARCHIVE}
NMAP_REPO=${PWD}/${NMAP_NAME}-${NMAP_VER}

NDK_ARCHIVE=${NDK_NAME}-${NDK_VER}-${NDK_BUILD_PLATFORM}.zip
NDK_ARCHIVE_FMT=zip
NDK_DL_URL=https://dl.google.com/android/repository/${NDK_ARCHIVE}

export PATH=${NDK}/bin:${PATH}
export CC=clang
export CXX=clang++

log() {
    >&2 echo $1
}

download() {
    wget $1
}

unarchive() {
    archive=$1
    fmt=$2
    case $fmt in
        zip)
            unzip $archive
        ;;
        gz|bz2)
            tar xfv $archive
        ;;
        *)
            log "unsupported format: $archive $fmt"
            exit 3
        ;;
    esac
}

ndk_setup() {
    if [ ! -d "${NDK_NAME}-${NDK_VER}" ]; then
        if [ ! -f "${NDK_ARCHIVE}" ]; then
            download ${NDK_DL_URL}
        fi
        unarchive ${NDK_ARCHIVE} ${NDK_ARCHIVE_FMT}
    fi
    ${NDK_NAME}-${NDK_VER}/build/tools/make-standalone-toolchain.sh \
        --install-dir=${NDK} \
        --platform=${NDK_ANDROID_PLATFORM} \
        --stl=${NDK_STL} \
        --toolchain=${NDK_TOOLCHAIN} \
        --verbose \
        --force
}

nmap_configure() {
    cd ${NMAP_REPO}
    ./configure \
        --host=${NMAP_HOST} \
        --without-subversion \
        --without-liblua \
        --without-zenmap \
        --with-pcre=/usr \
        --with-libpcap=included \
        --with-pcap=linux \
        --with-libdnet=included \
        --without-ndiff \
        --without-nmap-update \
        --without-ncat \
        --without-liblua \
        --without-nping \
        --without-openssl \
        --enable-static
}

nmap_make() {
    cd ${NMAP_REPO}
    make static
}

if [ ! -d ${NDK} ]; then
    ndk_setup
fi

if [ ! -d ${NMAP_REPO} ]; then
    if [ ! -f ${NMAP_ARCHIVE} ]; then
        download ${NMAP_DL_URL}
    fi
    unarchive ${NMAP_ARCHIVE} ${NMAP_ARCHIVE_FMT}
fi

nmap_configure
nmap_make
