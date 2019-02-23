# =============================================================================
# © You i Labs Inc. 2000-2017. All rights reserved.
cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

# Pre-defined options
option(YI_TREAT_WARNINGS_AS_ERRORS "Warnings will result in failure to compile when set to ON." ON)
option(YI_BUILD_CLOUD_SERVER "Build the application as a cloud server (for cloud-based Roku)" OFF)

set(YI_PROJECT_NAME "YouiTestApp") # The name of the project. When building for Android, this is passed from Android Studio.
set(YI_PACKAGE_NAME "tv.youi.youitestapp") # The package name used for the project.")
set(YI_DISPLAY_NAME "YouiTestApp") # The name of the application displayed on the device.
set(YI_EXCLUDED_ASSET_FILE_EXTENSIONS ".log,.aep" CACHE STRING "Comma-delimited list of file extensions whose files should be omitted during asset copying.")
set(YI_YOUI_ENGINE_VERSION 4.999.0 CACHE STRING "Version required for the You.i Engine.")
set(YI_VERSION_NUMBER 1.0.0.0 CACHE STRING "Build version of the application. This is the version that will be displayed to the end user in the store.")
set(YI_BUILD_NUMBER "ENG-unversioned" CACHE STRING "Release version number that needs to be incremented for each store submission. For Apple platforms, this is the CFBundleVersion. For Android, this is the Version Code.")

set(YI_BUNDLE_URL_SCHEME "yirnapp")
set(IOS_BUNDLE_URL_SCHEME "<string>${YI_BUNDLE_URL_SCHEME}</string>")
set(TVOS_BUNDLE_URL_SCHEME "<string>${YI_BUNDLE_URL_SCHEME}</string>")
set(UWP_BUNDLE_URL_SCHEME "<Extensions>\n\t\t\t\t<uap:Extension Category=\"windows.protocol\">\n\t\t\t\t\t<uap:Protocol Name=\"${YI_BUNDLE_URL_SCHEME}\" />\n\t\t\t\t</uap:Extension>\n\t\t\t</Extensions>")

set(_STAGING_DIR "${CMAKE_CURRENT_BINARY_DIR}/Staging")
set(_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src")

# This is used solely for projects that are built within the You.i Engine repository and can be removed for commercial projects.
include(${YouiEngine_DIR}/cmake/Hunter/YiInitializeHunter.cmake OPTIONAL)
project(${YI_PROJECT_NAME} LANGUAGES C CXX)

# The ordering of the paths within the CMAKE_MODULE_PATH variable is imporant, since having the project's 'cmake'
# path first will tell CMake to first look under that folder when the short form 'include(Modules/<module>)' command is used
# instead of the long form 'include(<path>/Modules/<filename>.cmake)'.
#
# If CMake finds a module under the project directory structure, it will load that file and stop looking in the CMAKE_MODULE_PATH.
# This allows projects to customize modules as they need to, without requiring changes at the engine level.
list(INSERT CMAKE_MODULE_PATH 0 ${YouiEngine_DIR}/cmake)

if(YI_BUILD_CLOUD_SERVER)
    find_path(YI_CLOUD_CMAKE_DIR
        Modules/YiCloudDeployment.cmake
        PATH_SUFFIXES
            cmake/cloud
            cloud/cmake
        PATHS ${YouiEngine_DIR}
    )
    mark_as_advanced(YI_CLOUD_CMAKE_DIR)

    list(INSERT CMAKE_MODULE_PATH 0 ${YI_CLOUD_CMAKE_DIR})
endif()
list(INSERT CMAKE_MODULE_PATH 0 ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

if (NOT MSVC_IDE AND NOT XCODE AND NOT CMAKE_BUILD_TYPE)
    message(FATAL_ERROR "CMAKE_BUILD_TYPE needs to be set for single configuration generators. Default builds are not allowed.")
endif()

if(NOT DEFINED YI_PLATFORM)
    message(FATAL_ERROR "The YI_PLATFORM variable was not given to the generator.")
endif()

include(Platform/Yi${YI_PLATFORM_CAPITALIZED} OPTIONAL RESULT_VARIABLE HAVE_YIPLATFORM_INCLUDE)
if (NOT HAVE_YIPLATFORM_INCLUDE)
    message( FATAL_ERROR "Unsupported platform specified: " ${YI_PLATFORM_CAPITALIZED})
endif()

# By having the list of source files for the project outside of the CMakeLists.txt file a project can
# use tools to auto-generate the contents of that file without having a lot of commits on the CMakeLists.txt
# file. This also makes the CMakeLists.txt and SourceList.cmake files more portable to move between projects with
# minimal effort.
include("${CMAKE_CURRENT_SOURCE_DIR}/SourceList.cmake")

if(NOT YouiEngine_FOUND)
    if(YI_BUILD_CLOUD_SERVER)
        set(_EXTRA_COMPONENTS cloud)
    endif()

    find_package(YouiEngine ${YI_YOUI_ENGINE_VERSION}
        COMPONENTS react ${_EXTRA_COMPONENTS}
        HINTS ${YouiEngine_DIR}
        REQUIRED
    )
endif()

include(Modules/YiPlatformSourceFiles)
set(YI_PROJECT_CODE_FILES
    ${YI_APP_SOURCE_FILES}
    ${YI_APP_SOURCE_HEADERS}
    ${PLATFORM_SOURCE_FILES_${YI_PLATFORM_UPPER}}
    ${PLATFORM_SOURCE_FILES_${YI_PLATFORM_UPPER}_${YI_RENDER_TYPE}}
    ${PLATFORM_SOURCE_HEADERS_${YI_PLATFORM_UPPER}}
    ${PLATFORM_SOURCE_HEADERS_${YI_PLATFORM_UPPER}_${YI_RENDER_TYPE}}
    ${YI_PROJECT_SOURCE}
    ${YI_PROJECT_HEADERS}
)

# Not all platforms will need to perform some kind of initialization. Because this is optional,
# we first check to see if the command actually exists. If not, we can safely ignore it.
#
# Initialization is performed before the target for the project() is created. At this time,
# PROJECT_NAME is not available and thus no use of it should be done. If further
# configuration is required, that can be done within the optional yi_configure_platform method.
include(Modules/${YI_PLATFORM_LOWER}/YiInitializePlatform OPTIONAL)
if(COMMAND yi_initialize_platform)
    yi_initialize_platform()
endif()

# Some platforms, such as IOS and TVOS have resources that are used for setting up the application
# icons. By making this include OPTIONAL, if no YiPlatformResources.cmake file exists, the build
# will continue without failing.
include(Modules/${YI_PLATFORM_LOWER}/YiPlatformResources OPTIONAL)

# The yi_add_executable function can be swapped with yi_add_library, if your project needs to
# output a library instead of an application executable.
include(Modules/YiAddExecutable)
yi_add_executable(TARGET ${PROJECT_NAME}
    SRC_FILES ${YI_PROJECT_CODE_FILES}
    EXTRA_FILES ${YI_PLATFORM_RESOURCES_${YI_PLATFORM_UPPER}}
)

# NOTE: This is only valid for Visual Studio-based generators
set_directory_properties(PROPERTIES
    VS_STARTUP_PROJECT ${PROJECT_NAME}
)

set(APPCOMMON_INCLUDE_DIR ${YouiEngine_DIR}/templates/mains/src)
if(YI_BUILD_CLOUD_SERVER)
    find_path(APPCOMMON_INCLUDE_DIR
        AppFactory.h
        PATH_SUFFIXES
            templates/mains/Resources/roku
            cloud/AppCommon/src
        PATHS
            ${YouiEngine_DIR}
    )
    mark_as_advanced(APPCOMMON_INCLUDE_DIR)

    find_path(CLOUD_INCLUDE_DIR
        cloud/YiCloud.h
        PATH_SUFFIXES include/cloud cloud/cloud/dist/include
        PATHS ${YouiEngine_DIR}
    )
    mark_as_advanced(CLOUD_INCLUDE_DIR)

    target_include_directories(${PROJECT_NAME}
        PRIVATE ${CLOUD_INCLUDE_DIR}
    )

endif()


target_include_directories(${PROJECT_NAME}
    PRIVATE ${_SRC_DIR}
    PRIVATE ${APPCOMMON_INCLUDE_DIR}
)
unset(APPCOMMON_INCLUDE_DIR CACHE)

target_link_libraries(${YI_PROJECT_NAME}
    PRIVATE
        $<$<BOOL:${YI_BUILD_CLOUD_SERVER}>:youi::cloud>
        youi::react
)

include(Modules/${YI_PLATFORM_LOWER}/YiLinkExternalLibraries OPTIONAL RESULT_VARIABLE _EXTERNAL_LIBS_PATH)
if(NOT _EXTERNAL_LIBS_PATH MATCHES NOTFOUND)
    yi_link_external_libraries(TARGET ${PROJECT_NAME})
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    RESOURCE "${YI_PLATFORM_RESOURCES_${YI_PLATFORM_UPPER}}"
)

source_group("Header Files" FILES ${YI_PROJECT_HEADERS})
source_group("Source Files" FILES ${YI_PROJECT_SOURCE})
source_group("Header Files\\App" FILES
    ${YI_APP_SOURCE_HEADERS}
    ${PLATFORM_SOURCE_HEADERS_${YI_PLATFORM_UPPER}}
    ${PLATFORM_SOURCE_HEADERS_${YI_PLATFORM_UPPER}_${YI_RENDER_TYPE}}
)
source_group("Source Files\\App" FILES
    ${YI_APP_SOURCE_FILES}
    ${PLATFORM_SOURCE_FILES_${YI_PLATFORM_UPPER}}
    ${PLATFORM_SOURCE_FILES_${YI_PLATFORM_UPPER}_${YI_RENDER_TYPE}}
)
source_group("Resources" FILES ${YI_PLATFORM_RESOURCES_${YI_PLATFORM_UPPER}})

# === START OF OPTION HANDLING ================================================

# Instrumented builds can help with determining code coverage.
# By using this module, the project can set up Debug builds to be able to output
# coverage data.
include(Modules/YiConfigureInstrumentedBuild)
yi_configure_instrumented_build(TARGET ${PROJECT_NAME})

# === END OF OPTION HANDLING ==================================================

# === START OF COMPILER SETUP =================================================

if(MSVC)
    target_compile_options(${PROJECT_NAME}
        PRIVATE $<$<BOOL:${YI_TREAT_WARNINGS_AS_ERRORS}>:/WX>
    )
else()
    target_compile_options(${PROJECT_NAME}
        PRIVATE -Wall
            -Wextra
            -Wno-float-equal
            -Wpointer-arith
            -Wwrite-strings
            -Wunused-variable
            -Wno-unused-parameter # for JSExecutor header
        PRIVATE -Wno-unused-result -Wno-unused-function
        PRIVATE $<$<BOOL:${YI_TREAT_WARNINGS_AS_ERRORS}>:-Werror>
    )
endif()

# The configuration method is made available for a platform to set up any specific
# functionality that requires use of the target variables, such as PROJECT_NAME, etc.
if(COMMAND yi_configure_platform)
    yi_configure_platform(PROJECT_TARGET ${PROJECT_NAME})
endif()

if(COMMAND yi_copy_cloud_libs)
    yi_copy_cloud_libs(PROJECT_TARGET ${PROJECT_NAME} REACTNATIVE)
endif()


include(Modules/react/YiConfigureJsBundling)
yi_configure_js_bundling(PROJECT_TARGET ${PROJECT_NAME} BASE_OUTPUT_DIR ${YI_BASE_OUTPUT_DIRECTORY})

# === END OF COMPILER SETUP ===================================================

# === START OF ASSET COPYING ==================================================

include(Modules/YiConfigureAssetCopying)
yi_configure_asset_copying(PROJECT_TARGET ${PROJECT_NAME}
    OUTPUT_DIRECTORY ${YI_BASE_OUTPUT_DIRECTORY}
    EXCLUDED_EXTENSIONS ${YI_EXCLUDED_ASSET_FILE_EXTENSIONS}
)

include(Modules/react/YiConfigureCommonReactAssets)
yi_configure_common_react_assets(PROJECT_TARGET ${PROJECT_NAME}
    OUTPUT_DIRECTORY ${YI_BASE_OUTPUT_DIRECTORY}
    EXCLUDED_EXTENSIONS ${YI_EXCLUDED_ASSET_FILE_EXTENSIONS}
)

# === END OF ASSET COPYING ====================================================

# === START OF PROJECT PACKAGING ==============================================

# Because not every platform requires custom packaging functionality, having a Package target
# is optional only if the platform's CMake file implements the yi_configure_packaging_for_platform
# function.
include(Modules/${YI_PLATFORM_LOWER}/YiConfigurePackagingForPlatform OPTIONAL)
if (COMMAND yi_configure_packaging_for_platform)
    include(Modules/YiGenerateUniqueTargetName)
    yi_generate_unique_target_name(TARGET Package PREFIX "${PROJECT_NAME}_" RESULT_VARIABLE _PACKAGE_TARGET)

    add_custom_target(${_PACKAGE_TARGET} ${YI_PACKAGE_IN_ALL})
    yi_configure_packaging_for_platform(PROJECT_TARGET ${PROJECT_NAME}
        PACKAGE_TARGET ${_PACKAGE_TARGET}
    )
endif()

# === END OF PROJECT PACKAGING ================================================
