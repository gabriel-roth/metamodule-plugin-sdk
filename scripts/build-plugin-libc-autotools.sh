#!/usr/bin/env bash
#
# EXPERIMENTAL: build plugin-libc from the real newlib and libstdc++ autotools
# build systems, instead of the per-file source lists in plugin-libc/*.cmake.
#
# Produces plugin-libc/autotools-build/libmetamodule-plugin-libc.a -- a
# drop-in replacement for the archive in plugin-libc/lib/ (it is NOT
# installed there automatically; test on hardware first, then copy manually).
#
# What this does:
#  1. Downloads newlib-4.3.0.20230120 (the version the ARM 12.3 toolchain
#     ships) and gcc-12.3.0 (for libstdc++-v3) source tarballs
#  2. Builds newlib with CFLAGS_FOR_TARGET += -fPIC and configure flags that
#     reproduce the ARM toolchain's configuration exactly (verified by
#     diffing the generated newlib.h against the toolchain's installed copy)
#  3. Builds libstdc++-v3 standalone (--host=arm-none-eabi) with -fPIC and
#     --with-pic, using the installed cross compiler. Configure link-tests
#     are impossible for bare metal (GCC_NO_EXECUTABLES), so the answers are
#     seeded to match the toolchain's installed c++config.h
#  4. Compiles the ARM EABI unwinder + glue (same files libgcc.cmake builds)
#  5. Removes archive members whose symbols must bind to the firmware at
#     load time (malloc family, abort, the reentrant _*_r syscalls, init/fini
#     hooks) -- same set that libc.cmake excludes from the source build
#  6. Replaces libstdc++'s __verbose_terminate_handler (which drags in the
#     ~100kB demangler) with glue/vterminate_lite.cc
#  7. Merges everything into one libmetamodule-plugin-libc.a
#
# Usage:
#   scripts/build-plugin-libc-autotools.sh [/path/to/arm-gnu-toolchain-12.3/bin]
#
set -euo pipefail

SDK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$SDK_DIR/plugin-libc/autotools-build"
NEWLIB_VER=newlib-4.3.0.20230120
GCC_VER=gcc-12.3.0
NEWLIB_URL="https://sourceware.org/pub/newlib/${NEWLIB_VER}.tar.gz"
GCC_URL="https://ftp.gnu.org/gnu/gcc/${GCC_VER}/${GCC_VER}.tar.xz"

TOOLCHAIN_BASE_DIR="${1:-${TOOLCHAIN_BASE_DIR:-}}"
if [ -z "$TOOLCHAIN_BASE_DIR" ]; then
	TOOLCHAIN_BASE_DIR="$(dirname "$(command -v arm-none-eabi-gcc)")"
fi
TC="$TOOLCHAIN_BASE_DIR"

# The whole build must use the 12.2/12.3 toolchain. A stray newer
# arm-none-eabi-gcc on PATH ICEs on libsupc++ (seen with 14.2:
# "internal compiler error: in gimple_build_eh_must_not_throw").
export PATH="$TC:$PATH"
GCCVER=$("$TC/arm-none-eabi-gcc" -dumpversion)
case "$GCCVER" in
	12.2*|12.3*) ;;
	*) echo "ERROR: arm-none-eabi-gcc $GCCVER at $TC; need 12.2/12.3" >&2; exit 1 ;;
esac

TC_SYSROOT="$("$TC/arm-none-eabi-gcc" -print-sysroot)"
ARCH_FLAGS="-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb-interwork -mno-unaligned-access -mtune=cortex-a7"
PIC_FLAGS="-fPIC -ffunction-sections -fdata-sections -O2 -g"

NPROC="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
# Recursive `make -j` on the newlib / libstdc++ autotools trees occasionally
# dies on a transient parallel-build race -- more likely on many-core
# machines, which is why this can fail on one mac and succeed on another. The
# build is fully resumable, so retry a couple of times (each retry just
# continues where the last left off) before treating it as a real failure.
run_make() {
	local tries=0
	until make -j"$NPROC"; do
		tries=$((tries + 1))
		if [ "$tries" -ge 3 ]; then
			echo "ERROR: 'make' failed $tries times in $(pwd) -- this is a real" >&2
			echo "       build error, not a parallel race. Re-run with 'make' (no" >&2
			echo "       -j) here to see the failing command clearly." >&2
			return 1
		fi
		echo "==== 'make' failed (likely a -j$NPROC parallel race); retrying ($tries/2)..." >&2
	done
}

mkdir -p "$WORK"
cd "$WORK"

# Mirror all stdout/stderr to a logfile. The recursive -j build produces a lot
# of interleaved output, so when something fails the error scrolls off the
# terminal -- grep this file (e.g. for 'Error ' or 'error:') to find it.
BUILD_LOG="$WORK/build.log"
exec > >(tee "$BUILD_LOG") 2>&1
echo "==== full build output is being saved to $BUILD_LOG"

##############################################################################
echo "==== 1. Sources"
[ -f ${NEWLIB_VER}.tar.gz ] || curl -L -o ${NEWLIB_VER}.tar.gz "$NEWLIB_URL"
[ -f ${GCC_VER}.tar.xz ]    || curl -L -o ${GCC_VER}.tar.xz "$GCC_URL"
[ -d ${NEWLIB_VER} ] || tar xzf ${NEWLIB_VER}.tar.gz
# libstdc++-v3 needs these pieces of the gcc tree (but never builds gcc itself):
[ -d ${GCC_VER} ] || tar xJf ${GCC_VER}.tar.xz \
	${GCC_VER}/libstdc++-v3 ${GCC_VER}/config ${GCC_VER}/libgcc \
	${GCC_VER}/libiberty ${GCC_VER}/include \
	${GCC_VER}/gcc/BASE-VER ${GCC_VER}/gcc/DATESTAMP \
	${GCC_VER}/config.guess ${GCC_VER}/config.sub ${GCC_VER}/install-sh \
	${GCC_VER}/ltmain.sh ${GCC_VER}/missing ${GCC_VER}/config-ml.in \
	${GCC_VER}/depcomp ${GCC_VER}/mkinstalldirs

BUILD_TRIPLET=$(${GCC_VER}/config.guess)

##############################################################################
echo "==== 2. newlib"
# Configure flags reproduce the ARM GNU toolchain 12.3 newlib configuration
# (validated below by diffing the generated newlib.h).
mkdir -p build-newlib && cd build-newlib
if [ ! -f Makefile ]; then
../${NEWLIB_VER}/configure \
	--build=$BUILD_TRIPLET --host=$BUILD_TRIPLET --target=arm-none-eabi \
	--prefix="$WORK/install" \
	--disable-multilib --disable-nls \
	--disable-newlib-supplied-syscalls \
	--enable-newlib-io-long-long \
	--enable-newlib-io-c99-formats \
	--enable-newlib-mb \
	--enable-newlib-reent-check-verify \
	--enable-newlib-register-fini \
	--enable-newlib-retargetable-locking \
	CC_FOR_TARGET="$TC/arm-none-eabi-gcc" \
	GCC_FOR_TARGET="$TC/arm-none-eabi-gcc" \
	CXX_FOR_TARGET="$TC/arm-none-eabi-g++" \
	AR_FOR_TARGET="$TC/arm-none-eabi-gcc-ar" \
	RANLIB_FOR_TARGET="$TC/arm-none-eabi-gcc-ranlib" \
	CFLAGS_FOR_TARGET="$ARCH_FLAGS $PIC_FLAGS"
fi
run_make
cd "$WORK"

echo "==== 2a. verify newlib.h matches the toolchain's"
GEN_NEWLIB_H=$(find build-newlib -name newlib.h -path "*targ-include*" | head -1)
if ! diff <(grep -E "^#define|^/\* #undef" "$TC_SYSROOT/include/newlib.h" | grep -v VERSION | grep -v PATCHLEVEL | sort) \
          <(grep -E "^#define|^/\* #undef" "$GEN_NEWLIB_H"              | grep -v VERSION | grep -v PATCHLEVEL | sort); then
	echo "ERROR: generated newlib.h differs from the toolchain's -- configure flags need updating" >&2
	exit 1
fi
echo "newlib.h: OK (identical configuration)"

##############################################################################
echo "==== 3. libstdc++"
# Link tests are not possible (bare metal, GCC_NO_EXECUTABLES), so probe
# answers that need them are seeded to match the toolchain's installed
# c++config.h (arm-none-eabi/include/c++/*/arm-none-eabi/*/bits/c++config.h).
# The result is verified against that file below.
#
# The arch flags and -fPIC are part of $CC/$CXX (not CFLAGS/CXXFLAGS):
# some configure probes replace CXXFLAGS entirely (the atomic-builtins asm
# probe sets CXXFLAGS='-O0 -S'), and without -mcpu the probe miscompiles
# for the default architecture and concludes there are no atomic builtins.
# This is also how the in-tree multilib build passes arch flags.
mkdir -p build-libstdcxx && cd build-libstdcxx
if [ ! -f Makefile ]; then
../${GCC_VER}/libstdc++-v3/configure \
	--host=arm-none-eabi --build=$BUILD_TRIPLET \
	--prefix="$WORK/install" \
	--disable-shared --disable-multilib --disable-nls \
	--with-newlib --disable-libstdcxx-pch \
	--with-pic \
	ac_cv_func_fcntl=yes ac_cv_func_getexecname=no ac_cv_func__wfopen=no \
	ac_cv_func_secure_getenv=no ac_cv_func_setenv=no ac_cv_func_quick_exit=no \
	ac_cv_func_at_quick_exit=no ac_cv_func_timespec_get=no ac_cv_func_sockatmark=no \
	ac_cv_func_uselocale=no ac_cv_func_sincos=no ac_cv_func__sincos=no \
	ac_cv_func_strtof=yes ac_cv_func_strtold=no \
	ac_cv_func___cxa_thread_atexit=no ac_cv_func___cxa_thread_atexit_impl=no \
	glibcxx_cv_c99_complex_cxx98=yes glibcxx_cv_c99_complex_cxx11=yes \
	glibcxx_cv_getentropy=no glibcxx_cv_arc4random=no \
	glibcxx_cv_openat=no glibcxx_cv_unlinkat=no \
	glibcxx_cv_readlink=no glibcxx_cv_symlink=no \
	glibcxx_cv_fchmod=no glibcxx_cv_fchmodat=no \
	CC="$TC/arm-none-eabi-gcc $ARCH_FLAGS -fPIC" \
	CXX="$TC/arm-none-eabi-g++ $ARCH_FLAGS -fPIC" \
	CFLAGS="-ffunction-sections -fdata-sections -O2 -g" \
	CXXFLAGS="-ffunction-sections -fdata-sections -O2 -g"
fi
run_make
cd "$WORK"

echo "==== 3a. verify c++config.h matches the toolchain's"
# Everything except the __GLIBCXX__ datestamp (12.3.0 release vs the
# toolchain's 12.3.1 branch snapshot) must be identical, otherwise the
# archive's internals disagree with the headers plugins compile against.
# (This catches, e.g., std::random_device referencing getentropy that the
# firmware does not provide.)
MULTIDIR=$("$TC/arm-none-eabi-gcc" $ARCH_FLAGS -print-multi-directory)
TC_CXXCONF="$TC_SYSROOT/include/c++/$("$TC/arm-none-eabi-gcc" -dumpversion)/arm-none-eabi/$MULTIDIR/bits/c++config.h"
GEN_CXXCONF="build-libstdcxx/include/arm-none-eabi/bits/c++config.h"
if ! diff <(grep -E "^#define _GLIBCXX|^/\* #undef _GLIBCXX" "$GEN_CXXCONF" | grep -v "__GLIBCXX__" | sort) \
          <(grep -E "^#define _GLIBCXX|^/\* #undef _GLIBCXX" "$TC_CXXCONF" | grep -v "__GLIBCXX__" | sort); then
	echo "ERROR: generated c++config.h differs from the toolchain's -- seeds need updating" >&2
	exit 1
fi
echo "c++config.h: OK (identical configuration)"

##############################################################################
echo "==== 4. unwinder + glue objects (same sources libgcc.cmake compiles)"
PL="$SDK_DIR/plugin-libc"
mkdir -p glue-obj && cd glue-obj
CC="$TC/arm-none-eabi-gcc"
CXX="$TC/arm-none-eabi-g++"
GLUE_INC="-I$PL/glue -I$PL/libgcc"
$CC  $ARCH_FLAGS $PIC_FLAGS $GLUE_INC -fexceptions -fnon-call-exceptions -Wno-address -fvisibility=hidden -c "$PL/glue/unwind-arm.c" -o unwind-arm.o
$CC  $ARCH_FLAGS $PIC_FLAGS $GLUE_INC -c "$PL/libgcc/config/arm/libunwind.S" -o libunwind.o
$CC  $ARCH_FLAGS $PIC_FLAGS $GLUE_INC -fexceptions -fnon-call-exceptions -fvisibility=hidden -c "$PL/libgcc/config/arm/pr-support.c" -o pr-support.o
$CC  $ARCH_FLAGS $PIC_FLAGS $GLUE_INC -fexceptions -fnon-call-exceptions -fvisibility=hidden -c "$PL/libgcc/unwind-c.c" -o unwind-c.o
$CXX $ARCH_FLAGS $PIC_FLAGS -fvisibility=hidden -c "$PL/glue/vterminate_lite.cc" -o vterminate_lite.o
$CC  $ARCH_FLAGS $PIC_FLAGS -c "$PL/dso_handle.c" -o dso_handle.o
cd "$WORK"

##############################################################################
echo "==== 5. archive surgery"
AR="$TC/arm-none-eabi-ar"
RANLIB="$TC/arm-none-eabi-gcc-ranlib"

cp build-newlib/arm-none-eabi/newlib/libc.a libc-plugin.a
cp build-newlib/arm-none-eabi/newlib/libm.a libm-plugin.a
cp build-libstdcxx/src/.libs/libstdc++.a libstdc++-plugin.a

# Symbols that must resolve to the firmware at load time: delete the newlib
# members that define them (mirrors the exclusions in libc.cmake).
#  - malloc family + abort: firmware's heap/abort
#  - _*_r reentrant syscalls: exported by the firmware (see api-symbols.txt)
#  - init/fini/__call_atexit: the plugin loader runs .init_array itself
$AR d libc-plugin.a \
	libc_a-malloc.o libc_a-mallocr.o libc_a-calloc.o libc_a-callocr.o \
	libc_a-realloc.o libc_a-reallocr.o libc_a-freer.o \
	libc_a-malign.o libc_a-malignr.o libc_a-msize.o \
	libc_a-abort.o \
	libc_a-init.o libc_a-fini.o libc_a-__call_atexit.o \
	libc_a-closer.o libc_a-fstatr.o libc_a-gettimeofdayr.o \
	libc_a-isattyr.o libc_a-lseekr.o libc_a-openr.o libc_a-readr.o \
	libc_a-sbrkr.o libc_a-signalr.o libc_a-timesr.o libc_a-writer.o

# Use the lightweight verbose terminate handler instead of the demangler
$AR d libstdc++-plugin.a vterminate.o cp-demangle.o

##############################################################################
echo "==== 6. merge into libmetamodule-plugin-libc.a"
rm -f libmetamodule-plugin-libc.a
$AR -M <<MRI
CREATE libmetamodule-plugin-libc.a
ADDLIB libstdc++-plugin.a
ADDLIB libc-plugin.a
ADDLIB libm-plugin.a
ADDMOD glue-obj/unwind-arm.o
ADDMOD glue-obj/libunwind.o
ADDMOD glue-obj/pr-support.o
ADDMOD glue-obj/unwind-c.o
ADDMOD glue-obj/vterminate_lite.o
ADDMOD glue-obj/dso_handle.o
SAVE
END
MRI
"$TC/arm-none-eabi-strip" -g libmetamodule-plugin-libc.a
$RANLIB libmetamodule-plugin-libc.a

ls -lh "$WORK/libmetamodule-plugin-libc.a"
echo ""
echo "Done. To test it, replace plugin-libc/lib/libmetamodule-plugin-libc.a"
echo "with $WORK/libmetamodule-plugin-libc.a and rebuild a plugin."
