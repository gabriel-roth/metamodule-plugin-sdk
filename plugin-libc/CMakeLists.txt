# plugin-libc: libc/libm/libstdc++/libsupc++ and the libgcc unwinder,
# compiled as -fPIC for linking into plugin .so files.
#
# Plugins link against the prebuilt archive in lib/ that matches the
# toolchain's gcc major version (selected in plugin.cmake).
#
# To regenerate the prebuilt archives, run:
#   scripts/build-plugin-libc-autotools.sh

add_library(metamodule-plugin-libc INTERFACE)
add_library(metamodule::plugin-libc ALIAS metamodule-plugin-libc)

# Header overrides (arm-acle-compat.h)
target_include_directories(metamodule-plugin-libc INTERFACE
	${CMAKE_CURRENT_LIST_DIR}/include
)
