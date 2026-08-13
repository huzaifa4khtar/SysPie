#include "user/user_filter.h"

#include <windows.h>
#include <sddl.h>
#include <set>
#include <vector>
#include <string>

bool isRealUser(const std::wstring& username) {
    if (username.empty()) return false;

    // Reject known built in system accounts first to avoid extra API calls
    static const std::set<std::wstring> systemAccounts = {
        L"SYSTEM",
        L"LOCAL SERVICE",
        L"NETWORK SERVICE",
        L"DefaultAccount",
        L"WDAGUtilityAccount",
        L"Administrator",
        L"Guest",
    };

    // Compare against the known system accounts without caring about case
    std::wstring upperName = username;
    for (auto& c : upperName) c = towupper(c);
    for (const auto& sys : systemAccounts) {
        if (upperName == sys) return false;
    }

    // Resolve the username to a SID so it can be inspected
    BYTE sidBuffer[SECURITY_MAX_SID_SIZE];
    DWORD sidSize = sizeof(sidBuffer);
    WCHAR domainName[256];
    DWORD domainSize = sizeof(domainName) / sizeof(WCHAR);
    SID_NAME_USE sidUse;

    BOOL result = LookupAccountNameW(
        nullptr,
        username.c_str(),
        sidBuffer,
        &sidSize,
        domainName,
        &domainSize,
        &sidUse
    );

    if (!result) return false;

    // Only accept accounts whose SID is a real user SID
    if (sidUse != SidTypeUser) return false;

    // Treat the final sub authority of the SID as the RID
    PSID sid = (PSID)sidBuffer;
    if (!IsValidSid(sid)) return false;

    BYTE subAuthorityCount = *GetSidSubAuthorityCount(sid);
    if (subAuthorityCount < 1) return false;

    DWORD rid = *GetSidSubAuthority(sid, subAuthorityCount - 1);

    // Human accounts have a RID of 1000 or more, built in ones stay lower
    return rid >= 1000;
}

std::vector<std::wstring> filterRealUsers(const std::vector<std::wstring>& allUsernames) {
    std::set<std::wstring> seen;
    std::vector<std::wstring> result;
    result.reserve(allUsernames.size());

    for (const auto& username : allUsernames) {
        if (seen.find(username) == seen.end()) {
            seen.insert(username);
            if (isRealUser(username)) {
                result.push_back(username);
            }
        }
    }

    return result;
}
