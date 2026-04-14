#include-once
#include <Crypt.au3>
#include <StringConstants.au3>
#include <WinAPI.au3>
#include <WinAPIMem.au3>
#include <WinAPIProc.au3>
#include "Security.au3"

; ===============================================================================================================================
; Globals & Constants
; ===============================================================================================================================
Global Const $GC_S_GWPROCESS_GAME_CLASS = "ArenaNet_Dx_Window_Class"
Global Const $GC_S_GWPROCESS_GAME_EXE = "Gw.exe"
Global Const $GC_I_GWPROCESS_PROC_ACCESS = BitOR($PROCESS_TERMINATE, $PROCESS_SET_QUOTA, $PROCESS_QUERY_LIMITED_INFORMATION)

Global Const $GC_I_WAIT_TIMEOUT = 0x00000102
Global Const $GC_I_WAIT_FAILED = 0xFFFFFFFF
Global Const $GC_I_ERROR_ALREADY_EXISTS = 183

Global $g_h_GameMutex = 0

; Grid Constants
Global Const $GC_I_GRID_COLS = 3
Global Const $GC_I_GRID_ROWS = 2
Global Const $GC_S_GRID_INI = @ScriptDir & "\Config\grid.ini"
Global Const $GC_S_GRID_DELIMITER = "|"
Global $g_i_GridAllocatedSlot = -1
Global $g_i_GWProcessId = 0 ; Set this after launch

OnAutoItExitRegister("_PunchOut_Launcher_OnExit")

; ===============================================================================================================================
; Logging Helper
; ===============================================================================================================================
Func _Launcher_Log($sMsg)
    ConsoleWrite($sMsg & @CRLF)
    If IsFunc("Out") Then Out($sMsg)
EndFunc

; ===============================================================================================================================
; Launch Functions
; ===============================================================================================================================
Func Launch_LaunchAccountFromINI($a_s_IniFile, $a_s_Character, $a_b_Restart = False)
    Local $l_i_Timeout = 10000
    Local $l_h_IniMutex = Security_AcquireFileMutex($a_s_IniFile, $l_i_Timeout)
    If $l_h_IniMutex <= 0 Then Return 0

    Local $l_s_Email = IniRead($a_s_IniFile, $a_s_Character, "Email", "")
    Local $l_s_Pwd = Security_DecryptString(IniRead($a_s_IniFile, $a_s_Character, "Pwd", ""))
    Local $l_s_FilePath = IniRead($a_s_IniFile, $a_s_Character, "FilePath", "")
    
    Security_CloseMutex($l_h_IniMutex)

    If Not FileExists($l_s_FilePath) Then
        _Launcher_Log("[ERR] Could not find Guild Wars executable (Gw.exe): " & $l_s_FilePath)
        Return 0
    EndIf

    Local $l_s_GameMutex = "AU3-Mutex-Window-Guild Wars-" & $a_s_Character
    If $a_b_Restart Then Security_CloseMutex($g_h_GameMutex)

    $g_h_GameMutex = _WinAPI_CreateMutex($l_s_GameMutex)
    If $g_h_GameMutex = 0 Then
        _Launcher_Log("[ERR] Failed to create/open mutex object: " & $l_s_GameMutex)
        Return 0
    EndIf

    Local $l_i_LastErr = _WinAPI_GetLastError()
    If $l_i_LastErr = $GC_I_ERROR_ALREADY_EXISTS Then
        _Launcher_Log("[ERR] Mutex object already exists: " & $l_s_GameMutex)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    _Launcher_Log("[INIT] Launching account")
    _Launcher_Log("[INIT] E-Mail: " & $l_s_Email)
    _Launcher_Log("[INIT] Character: " & $a_s_Character)

    Local $l_b_RequiresPasswordSend = StringInStr($l_s_Pwd, '"') > 0

    Local $l_s_Args = ' -fps 30'
    $l_s_Args &= ' -character ' & Launch_QuoteArg($a_s_Character)
    $l_s_Args &= ' -email ' & Launch_QuoteArg($l_s_Email)  
    If Not $l_b_RequiresPasswordSend Then
        $l_s_Args &= ' -password ' & Launch_QuoteArg($l_s_Pwd)
    EndIf

    Local $l_s_Cmd = Launch_QuoteArg($l_s_FilePath) & $l_s_Args

    If Not StringInStr($l_s_FilePath, '\') Then
        _Launcher_Log("[ERR] Invalid File Path: " & $l_s_FilePath)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf
    Local $l_s_WorkingDir = StringRegExpReplace($l_s_FilePath, "^(.*\\).*?$", "$1")

    Local $l_d_StartupInfo = DllStructCreate($tagSTARTUPINFO)
    Local $l_d_ProcessInfo = DllStructCreate($tagPROCESS_INFORMATION)
    DllStructSetData($l_d_StartupInfo, "Size", DllStructGetSize($l_d_StartupInfo))

    Local $l_av_Result = DllCall("kernel32.dll", "bool", "CreateProcessW", _
        "wstr", $l_s_FilePath, _
        "wstr", $l_s_Cmd, _
        "ptr", 0, _
        "ptr", 0, _
        "bool", False, _
        "dword", $CREATE_SUSPENDED, _
        "ptr", 0, _
        "wstr", $l_s_WorkingDir, _
        "struct*", $l_d_StartupInfo, _
        "struct*", $l_d_ProcessInfo)

    If @error Or Not $l_av_Result[0] Then
        _Launcher_Log("[ERR] Failed to launch process (CreateProcessW). LastError=" & _WinAPI_GetLastError())
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    Local $l_h_Process = DllStructGetData($l_d_ProcessInfo, "hProcess")
    Local $l_h_Thread = DllStructGetData($l_d_ProcessInfo, "hThread")
    Local $l_i_PID = DllStructGetData($l_d_ProcessInfo, "ProcessId")

    Local $l_h_Job = _WinAPI_CreateJobObject()
    If @error Or $l_h_Job = 0 Then
        _Launcher_Log("[ERR] Failed to create job object, PID-chain of launcher cannot be tracked")
        _WinAPI_CloseHandle($l_h_Thread)
        _WinAPI_CloseHandle($l_h_Process)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    If Not _WinAPI_AssignProcessToJobObject($l_h_Job, $l_h_Process) Then
        _Launcher_Log("[ERR] Failed to assign process to job object")
        _WinAPI_CloseHandle($l_h_Thread)
        _WinAPI_CloseHandle($l_h_Process)
        _WinAPI_CloseHandle($l_h_Job)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    If Not Launch_ApplyMultiClientPatch($l_h_Process) Then
        _Launcher_Log("[WARN] MultiClient patch failed; continuing without patch")
    EndIf

    Local $l_av_Resume = DllCall("kernel32.dll", "dword", "ResumeThread", "handle", $l_h_Thread)
    If @error Or $l_av_Resume[0] = -1 Then
        _Launcher_Log("[ERR] Failed to resume thread")
        _WinAPI_CloseHandle($l_h_Thread)
        _WinAPI_CloseHandle($l_h_Process)
        _WinAPI_CloseHandle($l_h_Job)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    Local $l_av_Wait = DllCall("kernel32.dll", "dword", "WaitForSingleObject", "handle", $l_h_Process, "dword", 0)
    If @error Or $l_av_Wait[0] <> $GC_I_WAIT_TIMEOUT Then
        _Launcher_Log("[ERR] Process not running after resume")
        _WinAPI_CloseHandle($l_h_Thread)
        _WinAPI_CloseHandle($l_h_Process)
        _WinAPI_CloseHandle($l_h_Job)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    _WinAPI_CloseHandle($l_h_Thread)
    _WinAPI_CloseHandle($l_h_Process)

    Local $l_i_WindowGracePeriod = 20000
    Local $l_i_OverallTimeout = 600000
    Local $l_i_UpdatedPID = Launch_WaitForPlayablePID($l_i_PID, $l_h_Job, $l_i_WindowGracePeriod, $l_i_OverallTimeout)
    If @error Or $l_i_UpdatedPID = 0 Then
        _Launcher_Log("[ERR] Failed to find playable Gw.exe")
        _WinAPI_CloseHandle($l_h_Job)
        Security_CloseMutex($g_h_GameMutex)
        Return 0
    EndIf

    _WinAPI_CloseHandle($l_h_Job)

    _Launcher_Log("[INIT] Successfully launched account")
    _Launcher_Log("[INIT] PID: " & $l_i_UpdatedPID)
    
    $g_i_GWProcessId = $l_i_UpdatedPID

    Local $l_i_Slot = Launch_AllocateGridSlot()
    If $l_i_Slot <> -1 Then
        Local $l_h_Wnd = Launch_ProcessWindowOfClass($g_i_GWProcessId, $GC_S_GWPROCESS_GAME_CLASS)
        If $l_h_Wnd Then
            Launch_MoveWindowToGridSlot($l_h_Wnd, $l_i_Slot)
        EndIf
    EndIf

    If $l_b_RequiresPasswordSend Then
        Local $l_h_LoginWnd = Launch_WaitForWindowOfClass($g_i_GWProcessId, $GC_S_GWPROCESS_GAME_CLASS, 30000)
        If $l_h_LoginWnd Then
            If Not Launch_SendPasswordAndEnter($l_h_LoginWnd, $l_s_Pwd) Then
                _Launcher_Log("[WARN] Failed to send password to Gw.exe window")
            EndIf
        Else
            _Launcher_Log("[WARN] Failed to find Gw.exe window for password entry")
        EndIf
    EndIf

    Return $l_i_UpdatedPID
EndFunc

Func Launch_WaitForWindowOfClass($a_i_PID, $a_s_Class, $a_i_TimeoutMs)
    Local $l_i_T0 = TimerInit()
    While TimerDiff($l_i_T0) < $a_i_TimeoutMs
        Local $l_h_Wnd = Launch_ProcessWindowOfClass($a_i_PID, $a_s_Class)
        If $l_h_Wnd Then Return $l_h_Wnd
        Sleep(100)
    WEnd
    Return 0
EndFunc

Func Launch_SendPasswordAndEnter($a_h_Wnd, $a_s_Pwd)
    WinActivate($a_h_Wnd)
    WinWaitActive($a_h_Wnd, "", 2)
    Sleep(200)
    Launch_SendPassword($a_s_Pwd)
    ControlSend($a_h_Wnd, "", "", "{ENTER}")
    Return True
EndFunc

Func Launch_SendPassword($a_s_Pwd)
    Local $l_i_Len = StringLen($a_s_Pwd)
    For $i = 1 To $l_i_Len
        Local $l_s_Char = StringMid($a_s_Pwd, $i, 1)
        Switch $l_s_Char
            Case "!"
                Send("{!}")
            Case "+"
                Send("{+}")
            Case "^"
                Send("{^}")
            Case "#"
                Send("{#}")
            Case "{"
                Send("{{}")
            Case "}"
                Send("{}}")
            Case '"'
                Send('{"}')
            Case Else
                Send($l_s_Char)
        EndSwitch
    Next
EndFunc

Func Launch_QuoteArg($a_s_ArgumentString)
    If $a_s_ArgumentString = "" Then Return '""'

    If Not StringRegExp($a_s_ArgumentString, '[\s"]') Then Return $a_s_ArgumentString

    Local $l_s_ResultQuoted = '"'
    Local $l_i_Index = 1
    Local $l_i_StringLength = StringLen($a_s_ArgumentString)

    While $l_i_Index <= $l_i_StringLength
        Local $l_i_BackslashCount = 0
        While $l_i_Index <= $l_i_StringLength And StringMid($a_s_ArgumentString, $l_i_Index, 1) = '\'
            $l_i_BackslashCount += 1
            $l_i_Index += 1
        WEnd

        If $l_i_Index > $l_i_StringLength Then
            $l_s_ResultQuoted &= _StringRepeat('\', $l_i_BackslashCount * 2)
            ExitLoop
        EndIf

        Local $l_s_CurrentChar = StringMid($a_s_ArgumentString, $l_i_Index, 1)

        If $l_s_CurrentChar = '"' Then
            $l_s_ResultQuoted &= _StringRepeat('\', $l_i_BackslashCount * 2 + 1) & '"'
        Else
            $l_s_ResultQuoted &= _StringRepeat('\', $l_i_BackslashCount) & $l_s_CurrentChar
        EndIf

        $l_i_Index += 1
    WEnd

    $l_s_ResultQuoted &= '"'
    Return $l_s_ResultQuoted
EndFunc

Func Launch_ApplyMultiClientPatch($a_h_Process)
    Local $l_ax_Pattern[19] = [0x56, 0x57, 0x68, 0x00, 0x01, 0x00, 0x00, 0x89, 0x85, _
                              0xF4, 0xFE, 0xFF, 0xFF, 0xC7, 0x00, 0x00, 0x00, 0x00, 0x00]
    Local $l_ax_Patch[4] = [0x31, 0xC0, 0x90, 0xC3]

    Local $l_b_Found = False
    Local $l_p_PatchAddr = 0
    Local $l_i_BlockSize = 0x10000

    Local $l_p_CurrAddr = 0x10000
    Local $l_p_MaxAddr = 0x7FFFFFFF
    Local $l_i_ConsecutiveFailures = 0

    While $l_p_CurrAddr < $l_p_MaxAddr
        Local $l_d_MemInfo = DllStructCreate("ptr BaseAddress;ptr AllocationBase;dword AllocationProtect;ptr RegionSize;dword State;dword Protect;dword Type")
        Local $l_amx_QueryResult = DllCall("kernel32.dll", "ulong_ptr", "VirtualQueryEx", _
            "handle", $a_h_Process, _
            "ptr", $l_p_CurrAddr, _
            "struct*", $l_d_MemInfo, _
            "ulong_ptr", DllStructGetSize($l_d_MemInfo))

        If @error Or $l_amx_QueryResult[0] = 0 Then
            $l_p_CurrAddr += 0x10000
            $l_i_ConsecutiveFailures += 1
            If $l_i_ConsecutiveFailures > 100 Then ExitLoop
            ContinueLoop
        EndIf

        $l_i_ConsecutiveFailures = 0

        Local $l_p_RegionBase = DllStructGetData($l_d_MemInfo, "BaseAddress")
        Local $l_i_RegionSize = DllStructGetData($l_d_MemInfo, "RegionSize")
        Local $l_i_State = DllStructGetData($l_d_MemInfo, "State")
        Local $l_i_Protect = DllStructGetData($l_d_MemInfo, "Protect")

        If $l_i_State = 0x1000 And BitAND($l_i_Protect, 0xEE) > 0 Then
            For $l_i_Offset = 0 To $l_i_RegionSize - 1 Step $l_i_BlockSize
                Local $l_i_ReadSize = $l_i_BlockSize
                If $l_i_Offset + $l_i_ReadSize > $l_i_RegionSize Then
                    $l_i_ReadSize = $l_i_RegionSize - $l_i_Offset
                EndIf

                Local $l_d_Buffer = DllStructCreate("byte[" & $l_i_ReadSize & "]")
                Local $l_i_PatternSize = UBound($l_ax_Pattern)
                Local $l_i_BytesRead = 0

                If _WinAPI_ReadProcessMemory($a_h_Process, $l_p_RegionBase + $l_i_Offset, $l_d_Buffer, $l_i_ReadSize, $l_i_BytesRead) And $l_i_BytesRead >= $l_i_PatternSize Then
                    For $l_i_Pos = 1 To ($l_i_BytesRead - $l_i_PatternSize)
                        Local $l_b_Match = True
                        For $l_i_Byte = 0 To $l_i_PatternSize - 1
                            If DllStructGetData($l_d_Buffer, 1, $l_i_Pos + $l_i_Byte) <> $l_ax_Pattern[$l_i_Byte] Then
                                $l_b_Match = False
                                ExitLoop
                            EndIf
                        Next

                        If $l_b_Match Then
                            $l_p_PatchAddr = $l_p_RegionBase + $l_i_Offset + ($l_i_Pos - 1) - 0x1A
                            ExitLoop 3
                        EndIf
                    Next
                EndIf
            Next
        EndIf
        $l_p_CurrAddr = $l_p_RegionBase + $l_i_RegionSize
    WEnd

    Local $l_d_TestRead = DllStructCreate("byte[4]")
    Local $l_i_TestReadBytes = 0
    If Not _WinAPI_ReadProcessMemory($a_h_Process, $l_p_PatchAddr, $l_d_TestRead, 4, $l_i_TestReadBytes) Or $l_i_TestReadBytes <> 4 Then
        Return False
    EndIf

    Local $l_i_OldProtect = 0
    _WinAPI_VirtualProtectEx($a_h_Process, $l_p_PatchAddr, 4, $PAGE_EXECUTE_READWRITE, $l_i_OldProtect)

    Local $l_d_Payload = DllStructCreate("byte[4]")
    For $l_i_Idx = 0 To 3
        DllStructSetData($l_d_Payload, 1, $l_ax_Patch[$l_i_Idx], $l_i_Idx + 1)
    Next

    Local $l_amx_WriteResult = DllCall("kernel32.dll", "bool", "WriteProcessMemory", _
        "handle", $a_h_Process, _
        "ptr", $l_p_PatchAddr, _
        "struct*", $l_d_Payload, _
        "ulong_ptr", 4, _
        "ulong_ptr*", 0)

    _WinAPI_VirtualProtectEx($a_h_Process, $l_p_PatchAddr, 4, $l_i_OldProtect, $l_i_OldProtect)

    If @error Or Not IsArray($l_amx_WriteResult) Or $l_amx_WriteResult[5] <> 4 Then
        Return False
    EndIf

    Return True
EndFunc

Func _WinAPI_VirtualProtectEx($a_h_Process, $a_p_Address, $a_i_Size, $a_i_NewProtection, ByRef $a_i_OldProtection)
    Local $l_amx_Result = DllCall("kernel32.dll", "bool", "VirtualProtectEx", _
        "handle", $a_h_Process, _
        "ptr", $a_p_Address, _
        "ulong_ptr", $a_i_Size, _
        "dword", $a_i_NewProtection, _
        "dword*", 0)

    If @error Then
        Return SetError(@error, @extended, False)
    EndIf

    $a_i_OldProtection = $l_amx_Result[5]

    Return $l_amx_Result[0] <> 0
EndFunc

Func Launch_WaitForPlayablePID($a_i_RootPID, $a_h_Job, $a_i_WindowGraceMs, $a_i_OverallTimeoutMs)
    Local $l_i_T0 = TimerInit()
    Local $l_i_TGrace = TimerInit()
    Local $l_s_Exe = StringLower($GC_S_GWPROCESS_GAME_EXE)

    While TimerDiff($l_i_T0) < $a_i_OverallTimeoutMs
        If ProcessExists($a_i_RootPID) And TimerDiff($l_i_TGrace) <= $a_i_WindowGraceMs Then
            If Launch_ProcessWindowOfClass($a_i_RootPID, $GC_S_GWPROCESS_GAME_CLASS) Then
                Return $a_i_RootPID
            EndIf
        EndIf

        Local $l_av_PIDs = Launch_JobObjectEnumPIDs($a_h_Job)
        If IsArray($l_av_PIDs) Then
            For $l_i_Idx = 0 To UBound($l_av_PIDs) - 1
                Local $l_i_PID = $l_av_PIDs[$l_i_Idx]
                If $l_i_PID = 0 Or $l_i_PID = $a_i_RootPID Then ContinueLoop
                If Not ProcessExists($l_i_PID) Then ContinueLoop

                Local $l_s_FileName = _WinAPI_GetProcessFileName($l_i_PID)
                If @error Or $l_s_FileName = "" Then ContinueLoop
                Local $l_s_Base = StringLower(StringRegExpReplace($l_s_FileName, "^.*\\", ""))
                If $l_s_Base <> $l_s_Exe Then ContinueLoop
                
                $l_i_TGrace = TimerInit()
                While TimerDiff($l_i_TGrace) < $a_i_WindowGraceMs
                    If Not ProcessExists($l_i_PID) Then Return SetError(1, 0, 0)
                    If Launch_ProcessWindowOfClass($l_i_PID, $GC_S_GWPROCESS_GAME_CLASS) Then
                        Return $l_i_PID
                    EndIf
                    Sleep(150)
                WEnd
            Next
        EndIf
        Sleep(150)
    WEnd

    Return SetError(1, 0, 0)
EndFunc

Func Launch_JobObjectEnumPIDs($a_h_Job)
    Local Const $LC_I_BUFFER = 16
    Local $l_d_ProcessListInfo = DllStructCreate($tagJOBOBJECT_BASIC_PROCESS_ID_LIST & ";ulong_ptr ProcessIdList[" & $LC_I_BUFFER & "]")
    Local $l_av_Result = DllCall("kernel32.dll", "bool", "QueryInformationJobObject", _
        "handle", $a_h_Job, _
        "int", 3, _
        "ptr", DllStructGetPtr($l_d_ProcessListInfo), _
        "dword", DllStructGetSize($l_d_ProcessListInfo), _
        "dword*", 0)
    If @error Or Not $l_av_Result[0] Then Return SetError(1, 0, 0)

    Local $l_i_Count = DllStructGetData($l_d_ProcessListInfo, "NumberOfProcessIdsInList")
    If $l_i_Count > $LC_I_BUFFER Then $l_i_Count = $LC_I_BUFFER

    Local $l_av_PIDs[$l_i_Count]
    For $l_i_Idx = 1 To $l_i_Count
        $l_av_PIDs[$l_i_Idx - 1] = DllStructGetData($l_d_ProcessListInfo, "ProcessIdList", $l_i_Idx)
    Next
    Return $l_av_PIDs
EndFunc

Func Launch_ProcessWindowOfClass($a_i_PID, $a_s_Class)
    Local $l_av_Windows = WinList("[CLASS:" & $a_s_Class & "]")
    If Not IsArray($l_av_Windows) Then Return 0
    For $l_i_Idx = 1 To $l_av_Windows[0][0]
        Local $l_h_Wnd = $l_av_Windows[$l_i_Idx][1]
        If WinGetProcess($l_h_Wnd) = $a_i_PID Then
            Return $l_h_Wnd
        EndIf
    Next
    Return 0
EndFunc

Func _PunchOut_Launcher_OnExit()
    If $g_i_GWProcessId <> 0 And $g_i_GridAllocatedSlot <> -1 Then
        Launch_ReleaseGridSlot($g_i_GridAllocatedSlot)
    EndIf
EndFunc

Func Launch_AllocateGridSlot()
    Local $l_i_Timeout = 10000
    Local $l_h_Mutex = Security_AcquireFileMutex($GC_S_GRID_INI, $l_i_Timeout)
    If $l_h_Mutex <= 0 Then Return SetError(1, 0, -1)

    Local $l_i_PID = $g_i_GWProcessId
    Local $l_i_Total = $GC_I_GRID_COLS * $GC_I_GRID_ROWS
    Local $l_ai_Depth[$l_i_Total]

    Local $i
    For $i = 0 To $l_i_Total - 1
        Local $l_s_Old = IniRead($GC_S_GRID_INI, "Slots", "S" & $i, "")
        Local $l_s_Pruned = Launch_GridPIDListPrune($l_s_Old)
        If $l_s_Pruned <> $l_s_Old Then
            If $l_s_Pruned = "" Then
                IniDelete($GC_S_GRID_INI, "Slots", "S" & $i)
            Else
                IniWrite($GC_S_GRID_INI, "Slots", "S" & $i, $l_s_Pruned)
            EndIf
        EndIf
        $l_ai_Depth[$i] = Launch_GridPIDListCount($l_s_Pruned)
    Next

    Local $l_i_MinDepth = 0x7FFFFFFF, $l_i_Slot = -1
    For $i = 0 To $l_i_Total - 1
        If $l_ai_Depth[$i] < $l_i_MinDepth Then
            $l_i_MinDepth = $l_ai_Depth[$i]
            $l_i_Slot = $i
        EndIf
    Next

    If $l_i_Slot = -1 Then
        Security_CloseMutex($l_h_Mutex)
        Return SetError(3, 0, -1)
    EndIf

    Local $l_s_List = IniRead($GC_S_GRID_INI, "Slots", "S" & $l_i_Slot, "")
    Local $l_s_NewList = Launch_GridPIDListAppend($l_s_List, $l_i_PID)
    Local $l_b_Write = IniWrite($GC_S_GRID_INI, "Slots", "S" & $l_i_Slot, $l_s_NewList)

    Security_CloseMutex($l_h_Mutex)

    If Not $l_b_Write Then
        Return SetError(4, 0, -1)
    EndIf

    $g_i_GridAllocatedSlot = $l_i_Slot
    Return $l_i_Slot
EndFunc

Func Launch_ReleaseGridSlot($a_i_Slot)
    Local $l_i_Timeout = 5000
    Local $l_h_Mutex = Security_AcquireFileMutex($GC_S_GRID_INI, $l_i_Timeout)
    If $l_h_Mutex <= 0 Then $l_h_Mutex = 0

    Local $l_i_PID = $g_i_GWProcessId
    Local $l_s_Key  = "S" & $a_i_Slot
    Local $l_s_List = IniRead($GC_S_GRID_INI, "Slots", $l_s_Key, "")

    If $l_s_List <> "" Then
        Local $l_s_NewList = Launch_RemoveGridPIDFromList($l_s_List, $l_i_PID)
        If $l_s_NewList = "" Then
            IniDelete($GC_S_GRID_INI, "Slots", $l_s_Key)
        Else
            IniWrite($GC_S_GRID_INI, "Slots", "S" & $a_i_Slot, $l_s_NewList)
        EndIf
    EndIf

    Security_CloseMutex($l_h_Mutex)
EndFunc

Func Launch_MoveWindowToGridSlot($a_h_Wnd, $a_i_Slot)
    Local $l_ai_Rect = Launch_GetGridSlotPosition($a_i_Slot)
    WinMove($a_h_Wnd, "", $l_ai_Rect[0], $l_ai_Rect[1], $l_ai_Rect[2], $l_ai_Rect[3], 1)
EndFunc

Func Launch_GetGridSlotPosition($a_i_Slot)
    Local $l_i_Left = 0, $l_i_Top = 0
    Local $l_i_Width = @DesktopWidth, $l_i_Height = @DesktopHeight

    Local $l_i_CellWidth  = Floor($l_i_Width  / $GC_I_GRID_COLS)
    Local $l_i_CellHeight = Floor($l_i_Height / $GC_I_GRID_ROWS)

    Local $l_i_Row = Floor($a_i_Slot / $GC_I_GRID_COLS)
    Local $l_i_Col = Mod($a_i_Slot, $GC_I_GRID_COLS)

    Local $l_i_X = $l_i_Left + ($l_i_Col * $l_i_CellWidth)
    Local $l_i_Y = $l_i_Top  + ($l_i_Row * $l_i_CellHeight)

    Local $l_ai_SlotPos[4] = [$l_i_X, $l_i_Y, $l_i_CellWidth, $l_i_CellHeight]
    Return $l_ai_SlotPos
EndFunc

Func Launch_GridPIDListCount($a_s_List)
    If $a_s_List = "" Then Return 0
    Local $l_as_PIDs = StringSplit($a_s_List, $GC_S_GRID_DELIMITER)
    Return $l_as_PIDs[0]
EndFunc

Func Launch_GridPIDListPrune($a_s_List)
    If $a_s_List = "" Then Return ""

    Local $l_as_PIDs = StringSplit($a_s_List, $GC_S_GRID_DELIMITER)
    Local $l_s_NewList = ""
    Local $i
    For $i = 1 To $l_as_PIDs[0]
        Local $l_i_PID = Number($l_as_PIDs[$i])
        If $l_i_PID <> 0 And ProcessExists($l_i_PID) Then
            If $l_s_NewList = "" Then
                $l_s_NewList = $l_i_PID
            Else
                $l_s_NewList &= $GC_S_GRID_DELIMITER & $l_i_PID
            EndIf
        EndIf
    Next
    Return $l_s_NewList
EndFunc

Func Launch_RemoveGridPIDFromList($a_s_List, $a_i_PID)
    If $a_s_List = "" Then Return ""

    Local $l_as_PIDs = StringSplit($a_s_List, $GC_S_GRID_DELIMITER)
    Local $l_s_NewList = ""
    Local $i
    For $i = 1 To $l_as_PIDs[0]
        If Number($l_as_PIDs[$i]) <> Number($a_i_PID) Then
            If $l_s_NewList = "" Then
                $l_s_NewList = $l_as_PIDs[$i]
            Else
                $l_s_NewList &= $GC_S_GRID_DELIMITER & $l_as_PIDs[$i]
            EndIf
        EndIf
    Next
    Return $l_s_NewList
EndFunc

Func Launch_GridPIDListAppend($a_s_List, $a_i_Value)
    If $a_s_List = "" Then
        Return $a_i_Value
    Else
        Return $a_s_List & $GC_S_GRID_DELIMITER & $a_i_Value
    EndIf
EndFunc
