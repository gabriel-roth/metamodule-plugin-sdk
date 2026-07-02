set(libstdcpp ${CMAKE_CURRENT_LIST_DIR}/libstdc++-v3/src)
set(libstdcpp_config ${CMAKE_CURRENT_LIST_DIR}/libstdc++-v3/config)

# In a normal libstdc++ build, configure copies these into the build tree
# (c_locale.cc -> c++locale.cc, basic_file_stdio.cc -> basic_file.cc, etc)
# based on the locale model (generic), OS (newlib), and IO model (stdio).
# They provide the C-locale facet implementations and the stdio-backed
# __basic_file<char> that iostreams/fstreams need.
set(LIBSTDCPP_HOST_SOURCES
	${libstdcpp_config}/locale/generic/c_locale.cc
	${libstdcpp_config}/locale/generic/codecvt_members.cc
	${libstdcpp_config}/locale/generic/collate_members.cc
	${libstdcpp_config}/locale/newlib/ctype_members.cc # clocale model for newlib is "newlib" for this file, "generic" for the rest
	${libstdcpp_config}/locale/generic/messages_members.cc
	${libstdcpp_config}/locale/generic/monetary_members.cc
	${libstdcpp_config}/locale/generic/numeric_members.cc
	${libstdcpp_config}/locale/generic/time_members.cc
	${libstdcpp_config}/os/newlib/ctype_configure_char.cc
	${libstdcpp_config}/io/basic_file_stdio.cc
)

set(LIBSTDCPP_C98_SOURCES
	${libstdcpp}/c++98/bitmap_allocator.cc
	${libstdcpp}/c++98/pool_allocator.cc
	${libstdcpp}/c++98/mt_allocator.cc
	${libstdcpp}/c++98/codecvt.cc
	${libstdcpp}/c++98/complex_io.cc
	${libstdcpp}/c++98/globals_io.cc
	${libstdcpp}/c++98/hash_tr1.cc
	${libstdcpp}/c++98/hashtable_tr1.cc
	${libstdcpp}/c++98/ios_failure.cc
	${libstdcpp}/c++98/ios_init.cc
	${libstdcpp}/c++98/ios_locale.cc
	${libstdcpp}/c++98/list.cc
	${libstdcpp}/c++98/list-aux.cc
	${libstdcpp}/c++98/list-aux-2.cc
	${libstdcpp}/c++98/list_associated.cc
	${libstdcpp}/c++98/list_associated-2.cc
	${libstdcpp}/c++98/locale.cc
	${libstdcpp}/c++98/locale_init.cc
	${libstdcpp}/c++98/locale_facets.cc
	${libstdcpp}/c++98/localename.cc
	${libstdcpp}/c++98/math_stubs_float.cc
	${libstdcpp}/c++98/math_stubs_long_double.cc
	${libstdcpp}/c++98/misc-inst.cc
	${libstdcpp}/c++98/stdexcept.cc
	${libstdcpp}/c++98/strstream.cc
	${libstdcpp}/c++98/tree.cc
	${libstdcpp}/c++98/istream.cc
	${libstdcpp}/c++98/istream-string.cc
	${libstdcpp}/c++98/cow-istream-string.cc
	${libstdcpp}/c++98/streambuf.cc
	${libstdcpp}/c++98/valarray.cc
)

set(LIBSTDCPP_C11_SOURCES
	${libstdcpp}/c++11/chrono.cc
	${libstdcpp}/c++11/codecvt.cc
	${libstdcpp}/c++11/condition_variable.cc
	${libstdcpp}/c++11/cow-stdexcept.cc
	# Old-ABI (COW) std::string instantiations: std::logic_error/runtime_error
	# hold a __cow_string for dual-ABI compatibility, so constructing standard
	# exception objects references these:
	${libstdcpp}/c++11/cow-string-inst.cc
	${libstdcpp}/c++11/cow-wstring-inst.cc
	# Dual-ABI locale facet shims, referenced by locale_init.cc:
	${libstdcpp}/c++11/cow-locale_init.cc
	${libstdcpp}/c++11/cow-shim_facets.cc
	${libstdcpp}/c++11/cxx11-shim_facets.cc
	# New-ABI std::ios_base::failure (the type streams actually throw):
	${libstdcpp}/c++11/cxx11-ios_failure.cc
	# New-ABI string constructors for the stdexcept exception classes:
	${libstdcpp}/c++11/cxx11-stdexcept.cc
	${libstdcpp}/c++11/ctype.cc
	${libstdcpp}/c++11/debug.cc
	${libstdcpp}/c++11/functexcept.cc
	${libstdcpp}/c++11/functional.cc
	${libstdcpp}/c++11/futex.cc
	${libstdcpp}/c++11/future.cc
	${libstdcpp}/c++11/hash_c++0x.cc
	${libstdcpp}/c++11/hashtable_c++0x.cc
	${libstdcpp}/c++11/ios.cc
	${libstdcpp}/c++11/limits.cc
	${libstdcpp}/c++11/mutex.cc
	${libstdcpp}/c++11/placeholders.cc
	${libstdcpp}/c++11/random.cc
	${libstdcpp}/c++11/regex.cc 
	${libstdcpp}/c++11/shared_ptr.cc
	${libstdcpp}/c++11/snprintf_lite.cc
	${libstdcpp}/c++11/system_error.cc
	# ${libstdcpp}/c++11/thread.cc
	${libstdcpp}/c++11/sso_string.cc

	${libstdcpp}/c++11/ext11-inst.cc
	${libstdcpp}/c++11/fstream-inst.cc
	${libstdcpp}/c++11/ios-inst.cc
	${libstdcpp}/c++11/iostream-inst.cc
	${libstdcpp}/c++11/istream-inst.cc
	${libstdcpp}/c++11/locale-inst.cc # old (COW) ABI facets; the cxx11-* files below compile it again for the new ABI
	${libstdcpp}/c++11/cxx11-locale-inst.cc
	${libstdcpp}/c++11/cxx11-wlocale-inst.cc
	${libstdcpp}/c++11/ostream-inst.cc
	${libstdcpp}/c++11/sstream-inst.cc
	${libstdcpp}/c++11/streambuf-inst.cc
	${libstdcpp}/c++11/string-inst.cc
	${libstdcpp}/c++11/string-io-inst.cc
	${libstdcpp}/c++11/wlocale-inst.cc
	${libstdcpp}/c++11/wstring-inst.cc
	${libstdcpp}/c++11/wstring-io-inst.cc
)

set(LIBSTDCPP_C17_SOURCES
	${libstdcpp}/c++17/floating_from_chars.cc
	${libstdcpp}/c++17/floating_to_chars.cc
	# ${libstdcpp}/c++17/fs_dir.cc
	# ${libstdcpp}/c++17/fs_ops.cc
	# ${libstdcpp}/c++17/fs_path.cc
	${libstdcpp}/c++17/memory_resource.cc
	# ${libstdcpp}/c++17/ostream-inst.cc
	${libstdcpp}/c++17/string-inst.cc
)

set(LIBSTDCPP_C20_SOURCES
	${libstdcpp}/c++20/sstream-inst.cc
)

set(LIBSTDCPP_FILESYSTEM_SOURCES
	${libstdcpp}/filesystem/dir.cc
	${libstdcpp}/filesystem/ops.cc
	${libstdcpp}/filesystem/path.cc
)

set(LIBSTDCPP_SHARED_SOURCES
	${libstdcpp}/shared/hashtable-aux.cc
)

add_library(libstdcpp98 OBJECT ${LIBSTDCPP_C98_SOURCES} ${LIBSTDCPP_HOST_SOURCES})
target_compile_options(libstdcpp98 PRIVATE -std=c++11)

# The real libstdc++ build compiles src/c++98 with -std=gnu++98. Most of these
# files happen to build as c++11 too, but not all: ios_locale.cc instantiates
# the C++98-only basic_ios<>::operator void*, and basic_file_stdio.cc needs
# POSIX fdopen/fileno, which newlib headers hide under strict-ANSI modes.
set_source_files_properties(
	${libstdcpp}/c++98/ios_locale.cc
	${libstdcpp}/c++98/misc-inst.cc
	${LIBSTDCPP_HOST_SOURCES}
	PROPERTIES COMPILE_OPTIONS "-std=gnu++98"
)

# The locale facet members are compiled a second time with the old (COW
# string) ABI -- the equivalent of the generated *_members_cow.cc objects in a
# real libstdc++ build (src/c++98/Makefile.am, ENABLE_DUAL_ABI).
add_library(libstdcpp98_cow OBJECT
	${libstdcpp_config}/locale/generic/collate_members.cc
	${libstdcpp_config}/locale/generic/messages_members.cc
	${libstdcpp_config}/locale/generic/monetary_members.cc
	${libstdcpp_config}/locale/generic/numeric_members.cc
)
target_compile_options(libstdcpp98_cow PRIVATE -std=gnu++98)
target_compile_definitions(libstdcpp98_cow PRIVATE _GLIBCXX_USE_CXX11_ABI=0)

add_library(libstdcpp11 OBJECT ${LIBSTDCPP_C11_SOURCES})
target_compile_options(libstdcpp11 PRIVATE -std=c++11)

# Export include dirs so we can override system headers
# (arm-acle-compat.h)
target_include_directories(metamodule-plugin-libc PUBLIC
	${CMAKE_CURRENT_LIST_DIR}/include
)

target_sources(metamodule-plugin-libc PRIVATE
    ${LIBSTDCPP_C17_SOURCES}
	${LIBSTDCPP_C20_SOURCES}
	# ${LIBSTDCPP_FILESYSTEM_SOURCES} # filesystem not used in MetaModule
    ${LIBSTDCPP_SHARED_SOURCES}
)
set_source_files_properties(
	${LIBSTDCPP_C20_SOURCES}
	PROPERTIES COMPILE_OPTIONS "-std=gnu++20"
)
set_source_files_properties(
    ${libstdcpp}/c++98/strstream.cc 
    ${libstdcpp}/c++98/bitmap_allocator.cc 
    PROPERTIES COMPILE_OPTIONS "-Wno-deprecated"
)


target_link_libraries(metamodule-plugin-libc PUBLIC libstdcpp98 libstdcpp11 libstdcpp98_cow)
