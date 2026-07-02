# plugin-libc: libc/libm/libstdc++/libsupc++ and the libgcc unwinder,
# compiled as -fPIC for linking into plugin .so files.
#
# By default, plugins link against the prebuilt archive in lib/. To compile
# everything from source instead (needed when changing plugin-libc itself),
# configure with -DMETAMODULE_BUILD_LIBC_FROM_SOURCE=ON.
#
# To regenerate the prebuilt archive after changing plugin-libc sources, run:
#   scripts/build-plugin-libc.sh

option(METAMODULE_BUILD_LIBC_FROM_SOURCE
	"Compile plugin-libc from source instead of using the prebuilt archive in plugin-libc/lib/" OFF)

if (METAMODULE_BUILD_LIBC_FROM_SOURCE)
	add_library(metamodule-plugin-libc STATIC)
	add_library(metamodule::plugin-libc ALIAS metamodule-plugin-libc)

	include(libm.cmake)
	include(libc.cmake)
	include(libsupcpp.cmake)
	include(libstdcpp.cmake)
	include(libgcc.cmake)

	target_compile_options(metamodule-plugin-libc PRIVATE
		-fbuiltin
		-fno-math-errno

		# Do not export plugin-libc symbols (removes unused symbols and does not make GOT/PLT tables for them):
		-fvisibility=hidden
	)
else()
	add_library(metamodule-plugin-libc INTERFACE)
	add_library(metamodule::plugin-libc ALIAS metamodule-plugin-libc)

	# Header overrides (arm-acle-compat.h), same as the source build exports
	target_include_directories(metamodule-plugin-libc INTERFACE
		${CMAKE_CURRENT_LIST_DIR}/include
	)
endif()
