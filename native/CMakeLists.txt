cmake_minimum_required(VERSION 3.20)
project(SysPieNative LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

enable_testing()

set(SYSPIE_MODULE_SOURCES
    modules/common/nt_api_init.cpp
    modules/process/process_enumerator.cpp
    modules/process/process_icons.cpp
    modules/process/process_terminator.cpp
    modules/cpu/cpu_stats.cpp
    modules/network/network_etw.cpp
    modules/disk/disk_stats.cpp
    modules/gpu/gpu_stats.cpp
    modules/gpu/gpu_engine_collector.cpp
    modules/service/service_enumerator.cpp
    modules/user/user_filter.cpp
    modules/window/window_enumerator.cpp
    modules/power/power_estimator.cpp
    modules/disk/disk_permission_checker.cpp
)

add_executable(syspie_native
    src/main.cpp
    ${SYSPIE_MODULE_SOURCES}
)

target_include_directories(syspie_native PRIVATE modules)

target_link_libraries(syspie_native PRIVATE ntdll iphlpapi gdiplus shlwapi dxgi wtsapi32 shell32 ole32 advapi32)

if(MSVC)
    target_compile_options(syspie_native PRIVATE /EHsc /bigobj)
endif()

# ============================================================================
# DLL target for FFI (loaded by Flutter via dart:ffi)
# ============================================================================

add_library(syspie_native_dll SHARED
    bindings/exports.cpp
    bindings/json_helpers.cpp
    ${SYSPIE_MODULE_SOURCES}
)

set_target_properties(syspie_native_dll PROPERTIES OUTPUT_NAME "syspie_native")
target_include_directories(syspie_native_dll PRIVATE modules bindings)
target_link_libraries(syspie_native_dll PRIVATE ntdll iphlpapi gdiplus shlwapi dxgi wtsapi32 shell32 ole32 oleaut32 advapi32 wbemuuid)
target_compile_definitions(syspie_native_dll PRIVATE BUILDING_DLL)
if(MSVC)
    target_compile_options(syspie_native_dll PRIVATE /EHsc /bigobj)
endif()

# ============================================================================
# CTest harness — pure logic only (power estimator + user filter)
# ============================================================================

add_executable(syspie_native_tests
    tests/logic_tests.cpp
    modules/power/power_estimator.cpp
    modules/user/user_filter.cpp
)

target_include_directories(syspie_native_tests PRIVATE modules)
target_link_libraries(syspie_native_tests PRIVATE advapi32)
if(MSVC)
    target_compile_options(syspie_native_tests PRIVATE /EHsc /bigobj)
endif()

add_test(NAME logic_tests COMMAND syspie_native_tests)
