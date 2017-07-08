#!/bin/bash
# This script is intended to be ran on SemaphoreCI or GDC Buildbot platform.
# Following environmental variables are assumed to be exported on SemaphoreCI.
# - SEMAPHORE_PROJECT_DIR
# - SEMAPHORE_CACHE_DIR
# See https://semaphoreci.com/docs/available-environment-variables.html
#
# Following environmental variables are assumed to be exported on GDC Buildbot.
# - PWD
# - BUILDBOT_CACHE_DIR
# - BUILDBOT_TARGET

## Commonize CI environment variables.
if [ "${SEMAPHORE}" = "true" ]; then
    PROJECT_DIR=${SEMAPHORE_PROJECT_DIR}
    CACHE_DIR=${SEMAPHORE_CACHE_DIR}
    BUILD_HOST=$(/usr/share/misc/config.guess)
    BUILD_TARGET=${BUILD_HOST}
elif [ "${BUILDBOT}" = "true" ]; then
    PROJECT_DIR=${PWD}
    CACHE_DIR=${BUILDBOT_CACHE_DIR}
    BUILD_HOST=$(/usr/share/misc/config.guess)
    BUILD_TARGET=${BUILDBOT_TARGET}

    # Tell CI to clean entire build directory before run.
    touch ${PROJECT_DIR}/.buildbot-patched
else
    echo "Unhandled CI environment"
    exit 1
fi

## Options determined by target, what steps to skip, or extra flags to add.
# BUILD_SUPPORTS_PHOBOS:    whether to build phobos and run unittests.
# BUILD_CONFIGURE_FLAGS:    extra configure flags for the target.
case ${BUILD_TARGET} in
    i[34567]86-*-*      \
  | x86_64-*-*)
        BUILD_SUPPORTS_PHOBOS=yes
        BUILD_CONFIGURE_FLAGS=
        ;;
  arm-*-*eabihf)
        BUILD_SUPPORTS_PHOBOS=yes
        BUILD_CONFIGURE_FLAGS='--with-arch=armv7-a --with-fpu=vfpv3-d16 --with-float=hard'
        ;;
  arm*-*-*eabi)
        BUILD_SUPPORTS_PHOBOS=yes
        BUILD_CONFIGURE_FLAGS='--with-arch=armv5t --with-float=soft'
        ;;
    *)
        BUILD_SUPPORTS_PHOBOS=no
        BUILD_CONFIGURE_FLAGS=
        ;;
esac

## Should the testsuite be ran under a simulator?
if [ "${BUILD_HOST}" = "$(/usr/share/misc/config.sub ${BUILD_TARGET})" ]; then
    BUILD_TEST_FLAGS=''
else
    case ${BUILD_TARGET} in
        arm*-*-*)
            BUILD_TEST_FLAGS='--target_board=buildbot-arm-sim'
            ;;

        *)
            BUILD_TEST_FLAGS='--target_board=buildbot-generic-sim'
            ;;
    esac
fi

## Find out which branch we are building.
GCC_VERSION=$(cat gcc.version)

if [ "${GCC_VERSION:0:5}" = "gcc-8" ]; then
    GCC_TARBALL="snapshots/${GCC_VERSION:4}/${GCC_VERSION}.tar.xz"
    GCC_PREREQS="gmp-6.1.0.tar.bz2 mpfr-3.1.4.tar.bz2 mpc-1.0.3.tar.gz isl-0.16.1.tar.bz2"
    PATCH_VERSION="8"
    HOST_PACKAGE="5"
elif [ "${GCC_VERSION:0:5}" = "gcc-7" ]; then
    GCC_TARBALL="releases/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
    GCC_PREREQS="gmp-6.1.0.tar.bz2 mpfr-3.1.4.tar.bz2 mpc-1.0.3.tar.gz isl-0.16.1.tar.bz2"
    PATCH_VERSION="7"
    HOST_PACKAGE="5"
elif [ "${GCC_VERSION:0:5}" = "gcc-6" ]; then
    GCC_TARBALL="releases/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
    GCC_PREREQS="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.15.tar.bz2"
    PATCH_VERSION="6"
    HOST_PACKAGE="5"
elif [ "${GCC_VERSION:0:5}" = "gcc-5" ]; then
    GCC_TARBALL="releases/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
    GCC_PREREQS="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.14.tar.bz2"
    PATCH_VERSION="5"
    HOST_PACKAGE="5"
elif [ "${GCC_VERSION:0:7}" = "gcc-4.9" ]; then
    GCC_TARBALL="releases/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
    GCC_PREREQS="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.12.2.tar.bz2 cloog-0.18.1.tar.gz"
    PATCH_VERSION="4.9"
    HOST_PACKAGE="4.9"
elif [ "${GCC_VERSION:0:7}" = "gcc-4.8" ]; then
    GCC_TARBALL="releases/${GCC_VERSION}/${GCC_VERSION}.tar.bz2"
    GCC_PREREQS="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz"
    PATCH_VERSION="4.8"
    HOST_PACKAGE="4.8"
else
    echo "This version of GCC ($GCC_VERSION) is not supported."
    exit 1
fi

export CC="gcc-${HOST_PACKAGE}"
export CXX="g++-${HOST_PACKAGE}"

installdeps() {
    ## Install build dependencies.
    # Would save 1 minute if these were preinstalled in some docker image.
    # But the network speed is nothing to complain about so far...
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update -qq
    sudo apt-get install -qq gcc-${HOST_PACKAGE} g++-${HOST_PACKAGE} \
        autogen autoconf2.64 automake1.11 bison dejagnu flex patch || exit 1
}

configure() {
    ## Download and extract GCC sources.
    # Makes use of local cache to save downloading on every build run.
    if [ ! -e ${CACHE_DIR}/${GCC_TARBALL} ]; then
        curl "ftp://ftp.mirrorservice.org/sites/sourceware.org/pub/gcc/${GCC_TARBALL}" \
            --create-dirs -o ${CACHE_DIR}/${GCC_TARBALL} || exit 1
    fi

    tar --strip-components=1 -xf ${CACHE_DIR}/${GCC_TARBALL}

    ## Apply GDC patches to GCC.
    for PATCH in toplev gcc targetdm; do
        patch -p1 -i ./gcc/d/patches/patch-${PATCH}-${PATCH_VERSION}.x || exit 1
    done

    ## And download GCC prerequisites.
    # Makes use of local cache to save downloading on every build run.
    for PREREQ in ${GCC_PREREQS}; do
        if [ ! -e ${CACHE_DIR}/infrastructure/${PREREQ} ]; then
            curl "ftp://gcc.gnu.org/pub/gcc/infrastructure/${PREREQ}" \
                --create-dirs -o ${CACHE_DIR}/infrastructure/${PREREQ} || exit 1
        fi
        tar -xf ${CACHE_DIR}/infrastructure/${PREREQ}
        ln -s "${PREREQ%.tar*}" "${PREREQ%-*}"
    done

    ## Create the build directory.
    # Build typically takes around 10 minutes with -j4, could this be cached across CI runs?
    mkdir ${PROJECT_DIR}/build
    cd ${PROJECT_DIR}/build

    ## Configure GCC to build a D compiler.
    ${PROJECT_DIR}/configure --prefix=/usr --libdir=/usr/lib --libexecdir=/usr/lib --with-sysroot=/ \
        --enable-languages=c++,d,lto --enable-checking --enable-link-mutex \
        --disable-bootstrap --disable-werror --disable-libgomp --disable-libmudflap \
        --disable-libquadmath --disable-libitm --disable-libsanitizer --disable-multilib \
        --build=${BUILD_HOST} --host=${BUILD_HOST} --target=${BUILD_TARGET} \
        --includedir=/usr/${BUILD_TARGET}/include ${BUILD_CONFIGURE_FLAGS} \
        --with-bugurl="http://bugzilla.gdcproject.org"
}

setup() {
    installdeps
    configure
}

build() {
    ## Build the bare-minimum in order to run tests.
    cd ${PROJECT_DIR}/build
    make -j$(nproc) all-gcc || exit 1

    # Note: libstdc++ and libphobos are built separately so that build errors don't mix.
    if [ "${BUILD_SUPPORTS_PHOBOS}" = "yes" ]; then
        make -j$(nproc) all-target-libstdc++-v3 || exit 1
        make -j$(nproc) all-target-libphobos || exit 1
    fi
}

testsuite() {
    ## Run just the compiler testsuite.
    cd ${PROJECT_DIR}/build
    make -j$(nproc) check-gcc-d RUNTESTFLAGS="${BUILD_TEST_FLAGS}"

    ## Print out summaries of testsuite run after finishing.
    # Just omit testsuite PASSes from the summary file.
    grep -v "^PASS" ${PROJECT_DIR}/build/gcc/testsuite/gdc*/gdc.sum ||:

    # Test for any failures and return false if any.
    if grep -q "^\(FAIL\|UNRESOLVED\)" ${PROJECT_DIR}/build/gcc/testsuite/gdc*/gdc.sum; then
       echo "== Testsuite has failures =="
       exit 1
    fi
}

unittests() {
    ## Run just the library unittests.
    if [ "${BUILD_SUPPORTS_PHOBOS}" = "yes" ]; then
        cd ${PROJECT_DIR}/build
        if ! make -j$(nproc) check-target-libphobos RUNTESTFLAGS="${BUILD_TEST_FLAGS}"; then
            echo "== Unittest has failures =="
            exit 1
        fi
    fi
}


## Run a single build task or all at once.
if [ "$1" != "" ]; then
    $1
else
    setup
    build
    unittests
fi
