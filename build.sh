#!/usr/bin/env sh

set -e

log() {
    >&2 echo $1
}

NMAP_NAME=nmap
NMAP_VER=7.70
NMAP_DESTDIR=${PWD}/out

NDK_VER=r18b
NDK_ANDROID_PLATFORM=android-28
NDK_BUILD_PLATFORM=linux-x86_64
NDK=${PWD}/ndk
NDK_ARCH=arm
NDK_STL=libc++
NDK_NAME=android-ndk

case $NDK_ARCH in
    arm)
        NMAP_HOST=arm-linux-androideabi
        DYNAMIC_LINKER=/system/bin/linker
        ;;
    arm64)
        NMAP_HOST=aarch64-linux-android
        DYNAMIC_LINKER=/system/bin/linker64
        ;;
    mips)
        NMAP_HOST=mipsel-linux-android
        DYNAMIC_LINKER=/system/bin/linker
        ;;
    mips64)
        NMAP_HOST=mips64el-linux-android
        DYNAMIC_LINKER=/system/bin/linker64
        ;;
    x86)
        NMAP_HOST=i686-linux-android
        DYNAMIC_LINKER=/system/bin/linker
        ;;
    x86_64)
        NMAP_HOST=x86_64-linux-android
        DYNAMIC_LINKER=/system/bin/linker64
        ;;
    *)
        log "unsupported arch: $ARCH"
        exit 3
        ;;
esac

NMAP_ARCHIVE=${NMAP_NAME}-${NMAP_VER}.tar.bz2
NMAP_ARCHIVE_FMT=bz2
NMAP_DL_URL=https://nmap.org/dist/${NMAP_ARCHIVE}
NMAP_REPO=${PWD}/${NMAP_NAME}-${NMAP_VER}

NDK_ARCHIVE=${NDK_NAME}-${NDK_VER}-${NDK_BUILD_PLATFORM}.zip
NDK_ARCHIVE_FMT=zip
NDK_DL_URL=https://dl.google.com/android/repository/${NDK_ARCHIVE}

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
        --arch=${NDK_ARCH} \
        --platform=${NDK_ANDROID_PLATFORM} \
        --stl=${NDK_STL} \
        --verbose \
        --force
}

nmap_configure() {
    cd ${NMAP_REPO}

    PATH=${NDK}/bin:${PATH} \
    CC=clang \
    CXX=clang++ \
    CFLAGS="-fvisibility=hidden -fPIE" \
    CXXFLAGS="-fvisibility=hidden -fPIE" \
    LDFLAGS="-s -static-libstdc++ -dynamic-linker=${DYNAMIC_LINKER}" \
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
    PATH=${NDK}/bin:${PATH} make
}

nmap_make_install() {
    rm -rf ${NMAP_DESTDIR}
    mkdir -p ${NMAP_DESTDIR}
    cd ${NMAP_REPO}
    PATH=${NDK}/bin:${PATH} make DESTDIR=${NMAP_DESTDIR} install

    prefix=${NMAP_DESTDIR}/usr/local
    install -c -m 755 ${prefix}/bin/${NMAP_NAME} ${NMAP_DESTDIR}/
    install -c -m 644 ${prefix}/share/nmap/* ${NMAP_DESTDIR}/
    rm -rf ${NMAP_DESTDIR}/usr
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
nmap_make_install
