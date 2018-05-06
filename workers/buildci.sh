#!/bin/bash
# This script is intended to be ran on SemaphoreCI or GDC Buildbot platform.
# Following environmental variables are assumed to be exported on SemaphoreCI.
#
# - SEMAPHORE_PROJECT_DIR
# - SEMAPHORE_CACHE_DIR
#
# See https://semaphoreci.com/docs/available-environment-variables.html
#
# Following environmental variables are assumed to be exported on GDC Buildbot.
#
# - PWD
# - BUILDBOT_CACHE_DIR
# - BUILDBOT_TARGET
#
## Commonize CI environment variables.
if [ "${SEMAPHORE}" = "true" ]; then
    project_dir=${SEMAPHORE_PROJECT_DIR}
    cache_dir=${SEMAPHORE_CACHE_DIR}
    build_host=$(/usr/share/misc/config.guess)
    build_host_canonical=$(/usr/share/misc/config.sub ${build_host})
    build_target=$(/usr/share/misc/config.guess)
    build_target_canonical=$(/usr/share/misc/config.sub ${build_target})
elif [ "${BUILDBOT}" = "true" ]; then
    project_dir=${PWD}
    cache_dir=${BUILDBOT_CACHE_DIR}
    build_host=$(/usr/share/misc/config.guess)
    build_host_canonical=$(/usr/share/misc/config.sub ${build_host})
    build_target=${BUILDBOT_TARGET}
    build_target_canonical=$(/usr/share/misc/config.sub ${build_target})

    # Tell CI to clean entire build directory before run.
    touch ${project_dir}/.buildbot-patched
else
    echo "Unhandled CI environment"
    exit 1
fi

## Options determined by target, what steps to skip, or extra flags to add.
## Also, should the testsuite be ran under a simulator?
#
# build_supports_phobos:    whether to build phobos and run unittests.
# build_enable_languages:   which languages to build, this affects whether C++
#                           or LTO tests are ran in the testsuite.
# build_configure_flags:    extra configure flags for the target.
# build_test_flags:         options to pass to RUNTESTFLAGS.
#
build_supports_phobos='yes'
build_enable_languages='c++,d,lto'
build_configure_flags=''
case ${build_target_canonical} in
    i[34567]86-*-*      \
  | x86_64-*-*)
        if [ "${build_host_canonical}" != "${build_target_canonical}" ]; then
            build_test_flags='--target_board=buildbot-generic-sim'
        fi
        ;;
  arm-*-*eabihf)
        build_configure_flags='--with-arch=armv7-a --with-fpu=vfpv3-d16 --with-float=hard'
        ;;
  arm*-*-*eabi)
        build_configure_flags='--with-arch=armv5t --with-float=soft'
        ;;
  mips-*-*|mipsel-*-*)
        build_configure_flags='--with-arch=mips32r2'
        ;;
  mips64*-*-*)
        build_configure_flags='--with-arch-64=mips64r2 --with-abi=64'
        ;;
  powerpc64*-*-*)
        build_configure_flags='--with-cpu=power7'
        ;;
    *)
        build_supports_phobos='no'
        build_enable_languages='c++,d --disable-lto'
        ;;
esac

build_test_flags=''
if [ "${build_host_canonical}" != "${build_target_canonical}" ]; then
    # Building a cross compiler, need to explicitly say where to find native headers.
    build_configure_flags="${build_configure_flags} --with-native-system-header-dir=/usr/${build_target}/include"

    # Note: setting target board to something other than "generic" only makes
    # sense if phobos is being built. Without phobos, all runnable tests will
    # all fail as being 'UNRESOLVED', and so are never ran anyway.
    case ${build_target_canonical} in
        arm*-*-*)
            build_test_flags='--target_board=buildbot-arm-sim'
            ;;

        *)
            build_test_flags='--target_board=buildbot-generic-sim'
            ;;
    esac
fi

## Find out which branch we are building.
gcc_version=$(cat gcc.version)

if [ "${gcc_version:0:5}" = "gcc-9" ]; then
    gcc_tarball="snapshots/${gcc_version:4}/${gcc_version}.tar.xz"
    gcc_prereqs="gmp-6.1.0.tar.bz2 mpfr-3.1.4.tar.bz2 mpc-1.0.3.tar.gz isl-0.16.1.tar.bz2"
    patch_version="9"
    host_package="5"
elif [ "${gcc_version:0:5}" = "gcc-8" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.xz"
    gcc_prereqs="gmp-6.1.0.tar.bz2 mpfr-3.1.4.tar.bz2 mpc-1.0.3.tar.gz isl-0.16.1.tar.bz2"
    patch_version="8"
    host_package="5"
elif [ "${gcc_version:0:5}" = "gcc-7" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.xz"
    gcc_prereqs="gmp-6.1.0.tar.bz2 mpfr-3.1.4.tar.bz2 mpc-1.0.3.tar.gz isl-0.16.1.tar.bz2"
    patch_version="7"
    host_package="5"
elif [ "${gcc_version:0:5}" = "gcc-6" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.xz"
    gcc_prereqs="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.15.tar.bz2"
    patch_version="6"
    host_package="5"
elif [ "${gcc_version:0:5}" = "gcc-5" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.xz"
    gcc_prereqs="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.14.tar.bz2"
    patch_version="5"
    host_package="5"
elif [ "${gcc_version:0:7}" = "gcc-4.9" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.bz2"
    gcc_prereqs="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz isl-0.12.2.tar.bz2 cloog-0.18.1.tar.gz"
    patch_version="4.9"
    host_package="4.9"
elif [ "${gcc_version:0:7}" = "gcc-4.8" ]; then
    gcc_tarball="releases/${gcc_version}/${gcc_version}.tar.bz2"
    gcc_prereqs="gmp-4.3.2.tar.bz2 mpfr-2.4.2.tar.bz2 mpc-0.8.1.tar.gz"
    patch_version="4.8"
    host_package="4.8"
else
    echo "This version of GCC ($gcc_version) is not supported."
    exit 1
fi

export CC="gcc-${host_package}"
export CXX="g++-${host_package}"
export GDC="gdc-${host_package}"

installdeps() {
    ## Install build dependencies.
    # Would save 1 minute if these were preinstalled in some docker image.
    # But the network speed is nothing to complain about so far...
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update -qq
    sudo apt-get install -qq gcc-${host_package} g++-${host_package} gdc-${host_package} \
        autogen autoconf2.64 automake1.11 bison dejagnu flex patch || exit 1
}

configure() {
    ## Download and extract GCC sources.
    # Makes use of local cache to save downloading on every build run.
    if [ ! -e ${cache_dir}/${gcc_tarball} ]; then
        curl "ftp://ftp.mirrorservice.org/sites/sourceware.org/pub/gcc/${gcc_tarball}" \
            --create-dirs -o ${cache_dir}/${gcc_tarball} || exit 1
    fi

    tar --strip-components=1 -xf ${cache_dir}/${gcc_tarball}

    ## Apply GDC patches to GCC.
    for patch_name in toplev gcc targetdm; do
        patch -p1 -i ./gcc/d/patches/patch-${patch_name}-${patch_version}.patch || exit 1
    done

    ## And download GCC prerequisites.
    # Makes use of local cache to save downloading on every build run.
    for prereq in ${gcc_prereqs}; do
        if [ ! -e ${cache_dir}/infrastructure/${prereq} ]; then
            curl "ftp://gcc.gnu.org/pub/gcc/infrastructure/${prereq}" \
                --create-dirs -o ${cache_dir}/infrastructure/${prereq} || exit 1
        fi
        tar -xf ${cache_dir}/infrastructure/${prereq}
        ln -s "${prereq%.tar*}" "${prereq%-*}"
    done

    ## Create the build directory.
    # Build typically takes around 10 minutes with -j4, could this be cached across CI runs?
    mkdir ${project_dir}/build
    cd ${project_dir}/build

    ## Configure GCC to build a D compiler.
    ${project_dir}/configure --prefix=/usr --libdir=/usr/lib --libexecdir=/usr/lib --with-sysroot=/ \
        --enable-languages=${build_enable_languages} --enable-checking --enable-link-mutex \
        --disable-bootstrap --disable-werror --disable-libgomp --disable-libmudflap \
        --disable-libquadmath --disable-libitm --disable-libsanitizer --disable-multilib \
        --build=${build_host} --host=${build_host} --target=${build_target} \
        ${build_configure_flags} --with-bugurl="http://bugzilla.gdcproject.org"
}

setup() {
    installdeps
    configure
}

build() {
    ## Build the bare-minimum in order to run tests.
    cd ${project_dir}/build
    make -j$(nproc) all-gcc || exit 1

    # Note: libstdc++ and libphobos are built separately so that build errors don't mix.
    if [ "${build_supports_phobos}" = "yes" ]; then
        make -j$(nproc) all-target-libstdc++-v3 || exit 1
        make -j$(nproc) all-target-libphobos || exit 1
    fi
}

testsuite() {
    ## Run just the compiler testsuite.
    cd ${project_dir}/build
    make -j$(nproc) check-gcc-d RUNTESTFLAGS="${build_test_flags}"

    # For now, be lenient towards targets with no phobos support,
    # and ignore unresolved test failures.
    if [ "${build_supports_phobos}" = "yes" ]; then
        print_filter="^PASS"
        fail_filter="^\(FAIL\|UNRESOLVED\)"
    else
        print_filter="^\(PASS\|UNRESOLVED\)"
        fail_filter="^FAIL"
    fi

    ## Print out summaries of testsuite run after finishing.
    # Just omit testsuite PASSes from the summary file.
    grep -v ${print_filter} ${project_dir}/build/gcc/testsuite/gdc*/gdc.sum ||:

    # Test for any failures and return false if any.
    if grep -q ${fail_filter} ${project_dir}/build/gcc/testsuite/gdc*/gdc.sum; then
       echo "== Testsuite has failures =="
       exit 1
    fi
}

unittests() {
    ## Run just the library unittests.
    if [ "${build_supports_phobos}" = "yes" ]; then
        cd ${project_dir}/build
        if ! make -j$(nproc) check-target-libphobos RUNTESTFLAGS="${build_test_flags}"; then
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
