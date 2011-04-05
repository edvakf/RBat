END {

$dlls = []

require 'Win32API'
# http://msdn.microsoft.com/en-us/library/ms682621(v=vs.85).aspx

# functions

# DWORD WINAPI GetCurrentProcessId(void);
win32_GetCurrentProcessId = Win32API.new('kernel32.dll', 'GetCurrentProcessId', 'V', 'L')
# HANDLE WINAPI OpenProcess( __in DWORD dwDesiredAccess, __in BOOL bInheritHandle, __in DWORD dwProcessId );
win32_OpenProcess = Win32API.new('kernel32.dll', 'OpenProcess', 'LIL', 'L')
# BOOL WINAPI EnumProcessModules( __in HANDLE hProcess, __out HMODULE *lphModule, __in DWORD cb, __out LPDWORD lpcbNeeded );
win32_EnumProcessModules =
  Win32API.new('kernel32.dll', 'EnumProcessModules', 'LPLP', 'I') rescue
  Win32API.new('psapi.dll', 'EnumProcessModules', 'LPLP', 'I') # psapi.dll on XP
# DWORD WINAPI GetModuleFileName( __in_opt HMODULE hModule, __out LPTSTR lpFilename, __in DWORD nSize );
win32_GetModuleFileName = Win32API.new('kernel32.dll', 'GetModuleFileName', 'LPL', 'L')
# BOOL WINAPI CloseHandle( __in HANDLE hObject );
win32_CloseHandle = Win32API.new('kernel32.dll', 'CloseHandle', 'L', 'I')

# constants

_PROCESS_QUERY_INFORMATION = 0x0400
_PROCESS_VM_READ = 0x0010
_MAX_PATH = 260
sizeof_HANDLE = 4

# start here

buflen = 1024
hMods = "\0" * sizeof_HANDLE * buflen

processID = win32_GetCurrentProcessId.call()
hProcess = win32_OpenProcess.call(_PROCESS_QUERY_INFORMATION | _PROCESS_VM_READ, 0, processID)
raise "Error in OpenProcess" if 0 == hProcess

cbNeeded = "\0" * 4
if 0 != win32_EnumProcessModules.call(hProcess, hMods, hMods.length, cbNeeded)
  len = cbNeeded.unpack("l!")[0] / sizeof_HANDLE
  hMods.unpack("l!#{len}").each {|hModule|
    szModName = "\0" * _MAX_PATH

    if 0 != win32_GetModuleFileName.call(hModule, szModName, _MAX_PATH)
      $dlls << szModName.sub(/\0.*/, '')
    end
  }
end

win32_CloseHandle.call(hProcess)

puts $dlls.map{|dll|
  dll.sub(/^\\\\?\\/, '')
}.sort
}