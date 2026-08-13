#pragma once

#include <string>
#include <vector>

// True when the name is a real human account with a RID of 1000 or more, not a built in system account
bool isRealUser(const std::wstring& username);

// Returns the unique real usernames from a given list
std::vector<std::wstring> filterRealUsers(const std::vector<std::wstring>& allUsernames);
