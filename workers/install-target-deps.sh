#!/bin/bash

# This file switches on the shell variable ${target}, and also uses the
# following shell variables:
#
#  install_packages     List of all common packages to install.
#
#  binutils_packages    List of all binutils-related packages to install.
#
#  libc_packages        List of all libc-related packages to install.

target=${1}
install_packages="gcc-${DOCKER_GCC_VERSION} g++-${DOCKER_GCC_VERSION} \
    autogen autoconf2.64 automake1.11 bison dejagnu flex patch"
binutils_packages="binutils"
libc_packages="libc6-dev"

# Install base dependencies.
apt-get update -qq
apt-get install --no-install-recommends -qq software-properties-common
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt-get update -qq

# Do we need something more specific for the worker?
case ${target} in
    all-linux-gnu)
        binutils_packages="${binutils_packages} \
            binutils-aarch64-linux-gnu \
            binutils-alpha-linux-gnu \
            binutils-arm-linux-gnueabi \
            binutils-arm-linux-gnueabihf \
            binutils-arm-none-eabi \
            binutils-hppa-linux-gnu \
            binutils-hppa64-linux-gnu \
            binutils-mips-linux-gnu \
            binutils-mips64-linux-gnuabi64 \
            binutils-mips64el-linux-gnuabi64 \
            binutils-mipsel-linux-gnu \
            binutils-powerpc-linux-gnu \
            binutils-powerpc-linux-gnuspe \
            binutils-powerpc64-linux-gnu \
            binutils-powerpc64le-linux-gnu \
            binutils-s390x-linux-gnu \
            binutils-sh4-linux-gnu \
            binutils-sparc64-linux-gnu"
        libc_packages="${libc_packages} \
            libc6.1-dev-alpha-cross \
            libc6-dev-arm64-cross \
            libc6-dev-armel-armhf-cross \
            libc6-dev-armel-cross \
            libc6-dev-armhf-cross \
            libc6-dev-armhf-armel-cross \
            libc6-dev-armhf-cross \
            libc6-dev-hppa-cross \
            libc6-dev-mips-cross \
            libc6-dev-mips32-mips64-cross \
            libc6-dev-mips32-mips64el-cross \
            libc6-dev-mips64-cross \
            libc6-dev-mips64-mips-cross \
            libc6-dev-mips64-mipsel-cross \
            libc6-dev-mips64el-cross \
            libc6-dev-mipsel-cross \
            libc6-dev-mipsn32-mips-cross \
            libc6-dev-mipsn32-mips64-cross \
            libc6-dev-mipsn32-mips64el-cross \
            libc6-dev-mipsn32-mipsel-cross \
            libc6-dev-powerpc-cross \
            libc6-dev-powerpc-ppc64-cross \
            libc6-dev-powerpcspe-cross \
            libc6-dev-ppc64-cross \
            libc6-dev-ppc64-powerpc-cross \
            libc6-dev-ppc64el-cross \
            libc6-dev-s390-s390x-cross \
            libc6-dev-s390x-cross \
            libc6-dev-sh4-cross \
            libc6-dev-sparc64-cross \
            libc6-dev-sparc-sparc64-cross"
        ;;

    *)
        ;;
esac

apt-get install --no-install-recommends -qq \
    $install_packages $binutils_packages $libc_packages

# Clean-up.
apt-get clean
rm -rf /var/lib/apt/lists/*
