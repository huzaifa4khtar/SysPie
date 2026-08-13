#pragma once

// Enumerates top level windows with EnumWindows and groups them by owning PID. Windows are only pseudo children of a process for display and share its PID, so they must never be treated as real processes in code that terminates them or changes their priority. Task Manager shows folder windows under Explorer using the same idea.

#include "common/types.h"

// Returns all meaningful top level windows as entries pairing a PID with a window title, one per window so a PID may appear more than once
std::vector<WindowGroupEntry> enumerateWindows();
