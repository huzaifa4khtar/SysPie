#pragma once

#ifndef BUILDING_DLL
#define SYSPIE_API __declspec(dllimport)
#else
#define SYSPIE_API __declspec(dllexport)
#endif

#include <cstdint>

extern "C" {
    SYSPIE_API int32_t pl_init();
    SYSPIE_API void pl_shutdown();

    SYSPIE_API const char* pl_enumerate_processes_diff_json();
    SYSPIE_API const char* pl_get_stats_json();

    SYSPIE_API int32_t pl_terminate(uint32_t pid);
    SYSPIE_API int32_t pl_terminate_tree(uint32_t pid);
    SYSPIE_API int32_t pl_terminate_batch(const uint32_t* pids, int32_t count);
    SYSPIE_API int32_t pl_close_window(int64_t hwnd);

    SYSPIE_API int32_t pl_check_dangerous(uint32_t pid);

    SYSPIE_API const char* pl_get_icon(uint32_t pid);
    SYSPIE_API const char* pl_get_icons_batch_json(const uint32_t* pids, int32_t count);
    SYSPIE_API const char* pl_get_aumid_icon(const char* aumid);

    SYSPIE_API const char* pl_enumerate_services_json();
    SYSPIE_API int32_t pl_start_service(const wchar_t* name);
    SYSPIE_API int32_t pl_stop_service(const wchar_t* name);
    SYSPIE_API int32_t pl_restart_service(const wchar_t* name);
    SYSPIE_API const char* pl_get_last_service_error();

    SYSPIE_API const char* pl_list_users_json();

    SYSPIE_API int32_t pl_open_services();
    SYSPIE_API int32_t pl_open_properties(uint32_t pid);
    SYSPIE_API int32_t pl_open_file_location(uint32_t pid);

    /// Launches an application by name and makes its window topmost over SysPie.
    /// Supported values: "resmon", "taskmgr", "services".
    SYSPIE_API void pl_open_window_topmost(const wchar_t* appName);

    SYSPIE_API void pl_free_string(const char* str);
}
