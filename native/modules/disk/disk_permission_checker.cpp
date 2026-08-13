#include "disk/disk_permission_checker.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <aclapi.h>
#include <sddl.h>
#include <processthreadsapi.h>

#include <string>
#include <vector>

// FILE GENERIC WRITE includes FILE APPEND DATA, FILE WRITE ATTRIBUTES, FILE WRITE DATA,
// FILE WRITE EA, STANDARD RIGHTS WRITE, and SYNCHRONIZE.
// We treat FILE WRITE DATA 0x0002 as the core write indicator and FILE GENERIC WRITE 0x120116 as the broad one.
static constexpr ACCESS_MASK FILE_GENERIC_WRITE_VALUE = 0x00120116;
static constexpr ACCESS_MASK FILE_WRITE_DATA_VALUE    = 0x00000002;

std::wstring checkDiskPermission(uint32_t pid) {
    // Open the process to get its executable path
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) {
        return L"Read";
    }

    DWORD bufSize = MAX_PATH;
    std::vector<wchar_t> exePath(bufSize);
    BOOL ok = QueryFullProcessImageNameW(hProcess, 0, exePath.data(), &bufSize);
    CloseHandle(hProcess);

    if (!ok || bufSize == 0) {
        return L"Read";
    }

    std::wstring exePathStr(exePath.data());

    // Get the file's security descriptor and DACL
    PSECURITY_DESCRIPTOR pSD = nullptr;
    PACL pDacl = nullptr;
    DWORD result = GetNamedSecurityInfoW(
        exePathStr.c_str(),
        SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION,
        nullptr, nullptr, &pDacl, nullptr, &pSD
    );

    if (result != ERROR_SUCCESS || !pSD) {
        return L"Read";
    }

    // Build a trustee for the process's user, needing the process token to get the user SID
    HANDLE hToken = nullptr;
    BOOL tokenOk = OpenProcessToken(
        hProcess,
        TOKEN_QUERY,
        &hToken
    );

    if (!tokenOk || !hToken) {
        // Reopen the process since we closed it earlier
        hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (hProcess) {
            tokenOk = OpenProcessToken(hProcess, TOKEN_QUERY, &hToken);
            CloseHandle(hProcess);
        }
    }

    if (!tokenOk || !hToken) {
        LocalFree(pSD);
        return L"Read";
    }

    // Get the user SID from the token
    DWORD tokenInfoLen = 0;
    GetTokenInformation(hToken, TokenUser, nullptr, 0, &tokenInfoLen);

    std::vector<BYTE> tokenInfoBuf(tokenInfoLen);
    BOOL tokenUserOk = GetTokenInformation(hToken, TokenUser, tokenInfoBuf.data(), tokenInfoLen, &tokenInfoLen);
    CloseHandle(hToken);

    if (!tokenUserOk) {
        LocalFree(pSD);
        return L"Read";
    }

    auto pTokenUser = reinterpret_cast<PTOKEN_USER>(tokenInfoBuf.data());
    PSID pUserSid = pTokenUser->User.Sid;

    // Use GetEffectiveRightsFromAcl to get the effective access mask
    TRUSTEEW trustee = {};
    trustee.TrusteeForm = TRUSTEE_IS_SID;
    trustee.TrusteeType = TRUSTEE_IS_USER;
    trustee.pMultipleTrustee = nullptr;
    trustee.ptstrName = reinterpret_cast<LPWSTR>(pUserSid);

    ACCESS_MASK accessMask = 0;
    result = GetEffectiveRightsFromAclW(pDacl, &trustee, &accessMask);

    LocalFree(pSD);

    if (result != ERROR_SUCCESS) {
        return L"Read";
    }

    // Classify the access mask
    if ((accessMask & FILE_GENERIC_WRITE_VALUE) == FILE_GENERIC_WRITE_VALUE ||
        (accessMask & FILE_WRITE_DATA_VALUE) == FILE_WRITE_DATA_VALUE) {
        return L"Read/Write";
    }

    return L"Read";
}
