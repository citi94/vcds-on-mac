/*
 * iphlpapi.dll wrapper for VCDS on Wine/macOS
 *
 * Problem: macOS has 30+ network interfaces (Thunderbolt bridges, VPN tunnels,
 * Apple Neural Processing interfaces, etc.). VCDS calls GetAdaptersInfo with a
 * fixed-size buffer, gets ERROR_BUFFER_OVERFLOW, and gives up. WiFi
 * auto-discovery reports "Broadcast(s) used: NONE".
 *
 * This DLL replaces iphlpapi.dll in the VCDS directory. It forwards all 179
 * exports to Wine's real iphlpapi (renamed to iphlpapi_wine.dll) except
 * GetAdaptersInfo, which we wrap to properly handle the buffer overflow and
 * filter to only real network adapters.
 *
 * Build (requires MinGW cross-compiler):
 *   brew install mingw-w64
 *   x86_64-w64-mingw32-gcc -shared -o iphlpapi.dll iphlpapi.c iphlpapi.def \
 *       -liphlpapi -static-libgcc
 *
 * Install:
 *   Copy iphlpapi.dll to the VCDS directory
 *   Copy Wine's builtin iphlpapi.dll to the VCDS directory as iphlpapi_wine.dll
 *   Launch with: WINEDLLOVERRIDES="iphlpapi=n,b" wine VCDS.exe
 *
 * License: MIT
 */

#include <windows.h>
#include <iphlpapi.h>
#include <string.h>
#include <stdio.h>

typedef DWORD (WINAPI *pGetAdaptersInfo)(PIP_ADAPTER_INFO, PULONG);
static pGetAdaptersInfo real_GetAdaptersInfo = NULL;

static void ensure_loaded(void) {
    if (real_GetAdaptersInfo)
        return;
    HMODULE hmod = LoadLibraryA("iphlpapi_wine.dll");
    if (hmod)
        real_GetAdaptersInfo = (pGetAdaptersInfo)GetProcAddress(hmod, "GetAdaptersInfo");
}

static int is_useful_ip(const char *ip) {
    if (!ip || !ip[0] || strcmp(ip, "0.0.0.0") == 0)
        return 0;
    /* Skip loopback */
    if (strncmp(ip, "127.", 4) == 0)
        return 0;
    /* Skip Tailscale/CGNAT range 100.64.0.0/10 */
    unsigned int a = 0, b = 0;
    if (sscanf(ip, "%u.%u.", &a, &b) == 2) {
        if (a == 100 && b >= 64 && b <= 127)
            return 0;
    }
    /* Skip link-local */
    if (strncmp(ip, "169.254.", 8) == 0)
        return 0;
    return 1;
}

DWORD WINAPI GetAdaptersInfo(PIP_ADAPTER_INFO AdapterInfo, PULONG SizePointer) {
    PIP_ADAPTER_INFO all_buf = NULL;
    ULONG all_size = 0;
    DWORD ret;
    int count;

    ensure_loaded();
    if (!real_GetAdaptersInfo)
        return ERROR_NOT_SUPPORTED;

    /* Get required buffer size */
    ret = real_GetAdaptersInfo(NULL, &all_size);
    if (ret != ERROR_BUFFER_OVERFLOW)
        return ret;

    all_buf = (PIP_ADAPTER_INFO)HeapAlloc(GetProcessHeap(), 0, all_size);
    if (!all_buf)
        return ERROR_OUTOFMEMORY;

    ret = real_GetAdaptersInfo(all_buf, &all_size);
    if (ret != ERROR_SUCCESS) {
        HeapFree(GetProcessHeap(), 0, all_buf);
        return ret;
    }

    /* Count adapters with useful IPs */
    count = 0;
    PIP_ADAPTER_INFO p;
    for (p = all_buf; p; p = p->Next) {
        if (is_useful_ip(p->IpAddressList.IpAddress.String))
            count++;
    }

    if (count == 0) {
        HeapFree(GetProcessHeap(), 0, all_buf);
        if (SizePointer) *SizePointer = 0;
        return ERROR_NO_DATA;
    }

    ULONG needed = count * sizeof(IP_ADAPTER_INFO);

    if (!AdapterInfo || !SizePointer || *SizePointer < needed) {
        if (SizePointer) *SizePointer = needed;
        HeapFree(GetProcessHeap(), 0, all_buf);
        return ERROR_BUFFER_OVERFLOW;
    }

    /* Copy filtered adapters */
    PIP_ADAPTER_INFO dst = AdapterInfo;
    int remaining = count;
    for (p = all_buf; p; p = p->Next) {
        if (!is_useful_ip(p->IpAddressList.IpAddress.String))
            continue;
        memcpy(dst, p, sizeof(IP_ADAPTER_INFO));
        remaining--;
        if (remaining > 0) {
            dst->Next = dst + 1;
            dst++;
        } else {
            dst->Next = NULL;
        }
    }

    *SizePointer = needed;
    HeapFree(GetProcessHeap(), 0, all_buf);
    return ERROR_SUCCESS;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    (void)hinstDLL; (void)lpvReserved;
    (void)fdwReason;
    return TRUE;
}
