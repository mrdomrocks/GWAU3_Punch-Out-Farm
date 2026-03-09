#include-once
#include <Crypt.au3>
#include <StringConstants.au3>
#include <WinAPI.au3>
#include <WinAPIProc.au3>

; ===============================================================================================================================
; Security Globals & Constants
; ===============================================================================================================================
Global Const $GC_I_WAIT_OBJECT_0 = 0x00000000
Global Const $GC_I_WAIT_ABANDONED = 0x00000080
Global Const $GC_S_SEC_TAG = "{SEC}"
Global Const $GC_S_SEC_TAG_LE = StringLen($GC_S_SEC_TAG)
Global Const $GC_S_SEC_KEY = @ScriptName

; ===============================================================================================================================
; Security Functions
; ===============================================================================================================================
Func Security_EncryptString($a_s_Plain)
    If Not IsString($a_s_Plain) Then Return SetError(1, 0, "")
    If StringLeft($a_s_Plain, $GC_S_SEC_TAG_LE) = $GC_S_SEC_TAG Then Return $a_s_Plain
    If $a_s_Plain = "" Then Return ""

    _Crypt_Startup()
    Local $l_x_UTF8 = StringToBinary($a_s_Plain, $SB_UTF8)
    Local $l_s_Hex = _Crypt_EncryptData($l_x_UTF8, $GC_S_SEC_KEY, $CALG_AES_256)
    _Crypt_Shutdown()
    
    If @error Or $l_s_Hex = "" Then Return SetError(1, 0, "")

    Return $GC_S_SEC_TAG & StringTrimLeft($l_s_Hex, 2)
EndFunc 

Func Security_DecryptString($a_s_Crypt)
    If Not IsString($a_s_Crypt) Then Return $a_s_Crypt
    If StringLeft($a_s_Crypt, $GC_S_SEC_TAG_LE) <> $GC_S_SEC_TAG Then Return $a_s_Crypt

    _Crypt_Startup()
    Local $l_s_Hex = "0x" & StringMid($a_s_Crypt, $GC_S_SEC_TAG_LE + 1)
    Local $l_x_Plain = _Crypt_DecryptData($l_s_Hex, $GC_S_SEC_KEY, $CALG_AES_256)
    _Crypt_Shutdown()
    
    If @error Or $l_x_Plain = "" Then Return SetError(2, 0, $a_s_Crypt)

    Return BinaryToString($l_x_Plain, $SB_UTF8)
EndFunc

Func Security_PathToMutexName($a_s_Path)
    _Crypt_Startup()
    Local $l_s_Hash = _Crypt_HashData(StringLower($a_s_Path), $CALG_MD5)
    _Crypt_Shutdown()
    Return "AU3-Mutex-" & StringTrimLeft($l_s_Hash, 2)
EndFunc

Func Security_AcquireFileMutex($a_s_Path, $a_i_Timeout)
    Local $l_s_Mutex = Security_PathToMutexName($a_s_Path)
    Local $l_av_Create = _WinAPI_CreateMutex($l_s_Mutex)
    If @error Or $l_av_Create = 0 Then
        Return SetError(1, 0, -1)
    EndIf
    Local $l_h_Mutex = $l_av_Create

    Local $l_av_Wait = _WinAPI_WaitForSingleObject($l_h_Mutex, $a_i_Timeout)
    If @error Or ($l_av_Wait <> $GC_I_WAIT_OBJECT_0 And $l_av_Wait <> $GC_I_WAIT_ABANDONED) Then
        _WinAPI_CloseHandle($l_h_Mutex)
        Return SetError(2, 0, -1)
    EndIf

    Return $l_h_Mutex
EndFunc

Func Security_CloseMutex(ByRef $a_h_Mutex)
    If $a_h_Mutex = 0 Then Return

    _WinAPI_ReleaseMutex($a_h_Mutex)
    _WinAPI_CloseHandle($a_h_Mutex)
    $a_h_Mutex = 0
EndFunc
