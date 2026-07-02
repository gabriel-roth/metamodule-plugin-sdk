# Standalone project that compiles plugin-libc from source, to regenerate the
# prebuilt archive shipped in plugin-libc/lib/. Normally invoked through
# scripts/build-plugin-libc.sh -- see that script for usage.

cmake_minimum_required(VERSION 3.19)
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_LIST_DIR}/../../cmake/arm-none-eabi-gcc.cmake)
project(MetaModulePluginLibcArchive LANGUAGES C CXX ASM)

# The archive must be built with the same toolchain version plugins use
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if(NOT (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "12.2.0" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "12.4.0"))
        message(FATAL_ERROR
            " ARM GCC ${CMAKE_CXX_COMPILER_VERSION} is not supported."
            " The MetaModule Plugin SDK requires ARM GNU Toolchain 12.2 or 12.3.\n"
            " Specify the toolchain path with:\n"
            "   cmake -DTOOLCHAIN_BASE_DIR=/path/to/arm-toolchain-12.3/bin ...")
    endif()
endif()

set(CMAKE_BUILD_TYPE "RelWithDebInfo")
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ccache.cmake)

set(METAMODULE_BUILD_LIBC_FROM_SOURCE ON)

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/arch_mp15xa7.cmake)
link_libraries(arch_mp15x_a7)

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/.. plugin-libc)
