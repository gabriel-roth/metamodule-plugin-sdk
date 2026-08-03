cmake_minimum_required(VERSION 3.22)

if(NOT DEFINED METAMODULE_SDK_DIR)
	set(METAMODULE_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}/../..")
endif()
include(${METAMODULE_SDK_DIR}/plugin.cmake)

project(UsbInfoTestPlugin
	VERSION 0.1
	DESCRIPTION "Test plugin for the System USB query API"
	LANGUAGES C CXX ASM
)

add_library(UsbInfoTest STATIC src/main.cc)

set_property(TARGET UsbInfoTest PROPERTY CXX_STANDARD 20)

if(NOT DEFINED INSTALL_DIR)
	set(INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/plugin)
endif()

create_plugin(
	SOURCE_LIB UsbInfoTest
	PLUGIN_NAME UsbInfoTest
	PLUGIN_JSON ${CMAKE_CURRENT_LIST_DIR}/plugin.json
	SOURCE_ASSETS ${CMAKE_CURRENT_LIST_DIR}/assets
	DESTINATION ${INSTALL_DIR}
)
