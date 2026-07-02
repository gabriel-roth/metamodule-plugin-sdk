#!/usr/bin/env bash
#
# Regenerates the prebuilt plugin-libc archive shipped in plugin-libc/lib/.
# Run this after changing anything in plugin-libc/ (source lists, flags,
# vendored library sources).
#
# Usage:
#   scripts/build-plugin-libc.sh [/path/to/arm-gnu-toolchain-12.3/bin]
#
# The toolchain bin dir may also be given via the TOOLCHAIN_BASE_DIR
# environment variable. If neither is set, arm-none-eabi-gcc is taken from
# PATH (it must be version 12.2 or 12.3).

set -euo pipefail

SDK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${SDK_DIR}/plugin-libc/archive-project/build"
DEST="${SDK_DIR}/plugin-libc/lib/libmetamodule-plugin-libc.a"

TOOLCHAIN_BASE_DIR="${1:-${TOOLCHAIN_BASE_DIR:-}}"

CMAKE_ARGS=(-G Ninja)
if [ -n "$TOOLCHAIN_BASE_DIR" ]; then
	CMAKE_ARGS+=("-DTOOLCHAIN_BASE_DIR=${TOOLCHAIN_BASE_DIR}")
	STRIP="${TOOLCHAIN_BASE_DIR}/arm-none-eabi-strip"
	RANLIB="${TOOLCHAIN_BASE_DIR}/arm-none-eabi-gcc-ranlib"
else
	STRIP="arm-none-eabi-strip"
	RANLIB="arm-none-eabi-gcc-ranlib"
fi

cmake -B "$BUILD_DIR" -S "${SDK_DIR}/plugin-libc/archive-project" "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR"

# Strip debug info (but keep symbols): plugin builds strip -g from the final
# .so anyway, and this keeps the shipped archive small.
mkdir -p "$(dirname "$DEST")"
cp "$BUILD_DIR/plugin-libc/libmetamodule-plugin-libc.a" "$DEST"
"$STRIP" -g "$DEST"
"$RANLIB" "$DEST"

ls -lh "$DEST"
echo "Done: $DEST"
