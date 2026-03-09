#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <GuiComboBox.au3>
#include <File.au3>
#include "Security.au3"

; Constants
Global Const $GC_S_CHARACTERS_INI_PATH = @ScriptDir & "\Config\characters.ini"
Global Const $GC_S_DATA_SEPARATOR = "|"
Global Const $GC_I_CHARACTER_GUI_TYPE_ADD = 1
Global Const $GC_I_CHARACTER_GUI_TYPE_EDIT = 2
Global Const $GC_I_CHARACTER_GUI_TYPE_MULTI_EDIT = 3

; Globals for Character Edit GUI
Global $g_h_CharacterGUI
Global $g_i_CtrlID_CharsInput, $g_i_CtrlID_EmailInput, $g_i_CtrlID_PwdInput, $g_i_CtrlID_FilePathInput
Global $g_i_CtrlID_ShowPwdButton, $g_i_CtrlID_BrowseButton
Global $g_b_PwdMasked = True
Global $g_s_OldCharacter = ""
Global $g_ai_EditQueue[0]
Global $g_i_QueuePos = 0

; Helper for Labeled Input
Func GUI_CreateLabeledInput($sLabel, $iX, $iY, $iW, $iH, $iInputW, $iInputH)
    GUICtrlCreateLabel($sLabel, $iX, $iY, $iW, $iH)
    Return GUICtrlCreateInput("", $iX + $iW, $iY - 3, $iInputW, $iInputH)
EndFunc

; ===============================================================================================================================
; Character List Management
; ===============================================================================================================================

Func GUI_LoadCharacterList()
    If Not FileExists($GC_S_CHARACTERS_INI_PATH) Then
        ; Create directory if needed
        If Not FileExists(@ScriptDir & "\Config") Then DirCreate(@ScriptDir & "\Config")
        ; Return 0
    EndIf

    _GUICtrlListView_DeleteAllItems($g_h_CtrlHnd_AccountList)

    Local $l_i_Timeout = 5000
    Local $l_h_IniMutex = Security_AcquireFileMutex($GC_S_CHARACTERS_INI_PATH, $l_i_Timeout)
    If $l_h_IniMutex = 0 Then Return 0
        
    Local $l_as_Sections = IniReadSectionNames($GC_S_CHARACTERS_INI_PATH)
    If @error Or Not IsArray($l_as_Sections) Then
        GUICtrlSetData($CharacterChoiceCombo, $GC_S_DATA_SEPARATOR)
        Security_CloseMutex($l_h_IniMutex)
        Return 0
    EndIf

    Local $l_as_ValidCharacters[UBound($l_as_Sections)], $l_i_Count_ValidCharacters = 0

    For $i = 1 To $l_as_Sections[0]
        Local $l_s_Character = $l_as_Sections[$i]
        Local $l_s_Email = IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Email", "")
        Local $l_s_Pwd = IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Pwd", "")
        Local $l_s_FilePath = IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "FilePath", "")

        ; Auto-encrypt password if needed
        If StringLeft($l_s_Pwd, $GC_S_SEC_TAG_LE) <> $GC_S_SEC_TAG And $l_s_Pwd <> "" Then 
            IniWrite($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Pwd", Security_EncryptString($l_s_Pwd))
        EndIf

        $l_as_ValidCharacters[$l_i_Count_ValidCharacters] = $l_s_Character
        $l_i_Count_ValidCharacters += 1

        Local $l_i_Row = _GUICtrlListView_AddItem($g_h_CtrlHnd_AccountList, $l_s_Email)
        _GUICtrlListView_SetItemText($g_h_CtrlHnd_AccountList, $l_i_Row, $l_s_Character, 1)
        _GUICtrlListView_SetItemText($g_h_CtrlHnd_AccountList, $l_i_Row, $l_s_FilePath, 2)
    Next

    Security_CloseMutex($l_h_IniMutex)

    ReDim $l_as_ValidCharacters[$l_i_Count_ValidCharacters]
    _ArraySort($l_as_ValidCharacters)

    ; Update Combo Box (Merge with logged in chars or replace?)
    ; For now, let's append registered characters to the combo, but mark them?
    ; Or just replace the list with registered characters if the user wants to use the launcher.
    ; The original code used Scanner_GetLoggedCharNames().
    ; Let's combine them.
    
    Local $l_s_RegisteredChars = _ArrayToString($l_as_ValidCharacters, $GC_S_DATA_SEPARATOR)
    
    ; We need a way to distinguish between "Running Client" and "Registered Account" in the combo.
    ; Usually Launcher bots just list the registered accounts.
    ; Let's just list the registered accounts in the combo for now, as that's what the user asked for.
    ; But we should probably preserve the ability to attach to running clients.
    
    ; Let's prepend "Launcher: " to registered chars? No, that's ugly.
    ; Let's just list them.
    
    GUICtrlSetData($CharacterChoiceCombo, $GC_S_DATA_SEPARATOR & $l_s_RegisteredChars)
    
    ; Auto Size Columns
    For $i = 0 To 2
        _GUICtrlListView_SetColumnWidth($g_h_CtrlHnd_AccountList, $i, -2) ; -2 = Autosize to header
    Next
EndFunc

; ===============================================================================================================================
; Event Handlers
; ===============================================================================================================================

Func GUI_Main_OnAdd()
    GUI_CreateCharacterGUI("Add Character", $GC_I_CHARACTER_GUI_TYPE_ADD)
EndFunc

Func GUI_Main_OnEdit()
    Local $l_i_Count_Rows = _GUICtrlListView_GetItemCount($g_h_CtrlHnd_AccountList)
    Local $l_ai_Checked[$l_i_Count_Rows], $l_i_Count_Checked = 0
    For $i = 0 To $l_i_Count_Rows - 1
        If _GUICtrlListView_GetItemChecked($g_h_CtrlHnd_AccountList, $i) Then
            $l_ai_Checked[$l_i_Count_Checked] = $i
            $l_i_Count_Checked += 1
        EndIf
    Next
    ReDim $l_ai_Checked[$l_i_Count_Checked]

    If $l_i_Count_Checked = 0 Then
        MsgBox($MB_ICONWARNING, "Warning", "Please select at least one item to edit.")
        Return
    EndIf

    $g_ai_EditQueue = $l_ai_Checked
    $g_i_QueuePos = 0
    GUI_ShowNextEdit()
EndFunc

Func GUI_Main_OnRemove()
    Local $l_i_Count_Rows = _GUICtrlListView_GetItemCount($g_h_CtrlHnd_AccountList)
    Local $l_ai_Checked[$l_i_Count_Rows], $l_i_Count_Checked = 0
    For $i = 0 To $l_i_Count_Rows - 1
        If _GUICtrlListView_GetItemChecked($g_h_CtrlHnd_AccountList, $i) Then
            $l_ai_Checked[$l_i_Count_Checked] = $i
            $l_i_Count_Checked += 1
        EndIf
    Next
    ReDim $l_ai_Checked[$l_i_Count_Checked]

    If $l_i_Count_Checked = 0 Then
        MsgBox($MB_ICONWARNING, "Warning", "Please select at least one item to remove.")
        Return
    EndIf

    If MsgBox($MB_YESNO + $MB_ICONWARNING, "Confirm Remove", "Are you sure you want to remove the selected character(s)?") = 6 Then
        For $i = 1 To $l_i_Count_Checked
            Local $l_i_Row = $l_ai_Checked[$i - 1]
            Local $l_s_Character = _GUICtrlListView_GetItemText($g_h_CtrlHnd_AccountList, $l_i_Row, 1)
            IniDelete($GC_S_CHARACTERS_INI_PATH, $l_s_Character)
        Next
        GUI_LoadCharacterList()
    EndIf
EndFunc

; ===============================================================================================================================
; Character Dialog
; ===============================================================================================================================

Func GUI_CreateCharacterGUI($sTitle, $iType)
    GUISetState(@SW_DISABLE, $Form1)

    $g_h_CharacterGUI = GUICreate($sTitle, 330, 208, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU), -1, $Form1)
    GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_Character_OnCancel", $g_h_CharacterGUI)
    
    $g_i_CtrlID_CharsInput = GUI_CreateLabeledInput("Character:", 19, 23, 87, 20, 223, 22)
    $g_i_CtrlID_EmailInput = GUI_CreateLabeledInput("E-Mail:",    19, 55, 87, 52, 223, 22)

    GUICtrlCreateLabel("Password:", 19, 87, 70, 20)
    $g_i_CtrlID_PwdInput = GUICtrlCreateInput("", 87, 84, 185, 22, $ES_PASSWORD)
    $g_i_CtrlID_ShowPwdButton = GUICtrlCreateButton("Show", 281, 83, 30, 24)
    $g_b_PwdMasked = True
    GUICtrlSetOnEvent($g_i_CtrlID_ShowPwdButton, "GUI_Character_OnShowPwd")

    GUICtrlCreateLabel("File Path:", 19, 119, 70, 20)
    $g_i_CtrlID_FilePathInput = GUICtrlCreateInput("", 87, 116, 185, 22)
    $g_i_CtrlID_BrowseButton = GUICtrlCreateButton("...", 281, 115, 30, 24)
    GUICtrlSetOnEvent($g_i_CtrlID_BrowseButton, "GUI_Character_OnBrowse")

    ; Buttons
    Local $iBtnOK = GUICtrlCreateButton("OK", 80, 160, 75, 25)
    Local $iBtnCancel = GUICtrlCreateButton("Cancel", 175, 160, 75, 25)
    
    If $iType = $GC_I_CHARACTER_GUI_TYPE_ADD Then
        GUICtrlSetOnEvent($iBtnOK, "GUI_Character_OnConfirm_Add")
    Else
        GUICtrlSetOnEvent($iBtnOK, "GUI_Character_OnConfirm_Edit")
    EndIf
    GUICtrlSetOnEvent($iBtnCancel, "GUI_Character_OnCancel")

    GUISetState(@SW_SHOW, $g_h_CharacterGUI)
EndFunc

Func GUI_ShowNextEdit()
    Local $l_i_QueueSize = UBound($g_ai_EditQueue)
    If $g_i_QueuePos >= $l_i_QueueSize Then
        ReDim $g_ai_EditQueue[0]
        $g_i_QueuePos = 0
        $g_s_OldCharacter = ""
        _GUICtrlListView_SetItemChecked($g_h_CtrlHnd_AccountList, -1, False)
        GUISetState(@SW_ENABLE, $Form1)
        WinActivate($Form1)
        Return True
    EndIf

    Local $l_i_Row = $g_ai_EditQueue[$g_i_QueuePos]
    Local $l_s_Character = _GUICtrlListView_GetItemText($g_h_CtrlHnd_AccountList, $l_i_Row, 1)

    Local $l_i_Timeout = 5000
    Local $l_h_IniMutex = Security_AcquireFileMutex($GC_S_CHARACTERS_INI_PATH, $l_i_Timeout)

    Local $l_s_Email = IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Email", "")
    Local $l_s_Pwd = Security_DecryptString(IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Pwd", ""))
    Local $l_s_FilePath = IniRead($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "FilePath", "")

    Security_CloseMutex($l_h_IniMutex)

    $g_s_OldCharacter = $l_s_Character

    Local $l_s_Title = "Edit Character [" & ($g_i_QueuePos + 1) & " of " & $l_i_QueueSize & "]"
    GUI_CreateCharacterGUI($l_s_Title, $GC_I_CHARACTER_GUI_TYPE_EDIT)

    GUICtrlSetData($g_i_CtrlID_CharsInput, $l_s_Character)
    GUICtrlSetData($g_i_CtrlID_EmailInput, $l_s_Email)
    GUICtrlSetData($g_i_CtrlID_PwdInput, $l_s_Pwd)
    GUICtrlSetData($g_i_CtrlID_FilePathInput, $l_s_FilePath)
EndFunc

Func GUI_Character_OnConfirm($a_i_Type)
    Local $l_s_Character = GUICtrlRead($g_i_CtrlID_CharsInput)
    Local $l_s_Email = StringStripWS(GUICtrlRead($g_i_CtrlID_EmailInput), 8)
    Local $l_s_Pwd = GUICtrlRead($g_i_CtrlID_PwdInput)
    Local $l_s_FilePath = StringStripWS(GUICtrlRead($g_i_CtrlID_FilePathInput), 3)

    If $l_s_Character = "" Then Return MsgBox($MB_ICONERROR, "Error", "Character Name is required.")
    If $l_s_Email = "" Then Return MsgBox($MB_ICONERROR, "Error", "E-Mail is required.")
    If $l_s_Pwd = "" Then Return MsgBox($MB_ICONERROR, "Error", "Password is required.")
    If $l_s_FilePath = "" Then Return MsgBox($MB_ICONERROR, "Error", "File Path is required.")

    Local $l_i_Timeout = 5000
    Local $l_h_IniMutex = Security_AcquireFileMutex($GC_S_CHARACTERS_INI_PATH, $l_i_Timeout)
    If $l_h_IniMutex = 0 Then Return MsgBox(16, "Error", "Failed to lock character file.")
    
    Switch $a_i_Type
        Case $GC_I_CHARACTER_GUI_TYPE_ADD
            IniReadSection($GC_S_CHARACTERS_INI_PATH, $l_s_Character)
            If Not @error Then 
                Security_CloseMutex($l_h_IniMutex)
                Return MsgBox($MB_ICONERROR, "Error", "Character already exists.")
            EndIf
        Case $GC_I_CHARACTER_GUI_TYPE_EDIT
            If $g_s_OldCharacter <> $l_s_Character Then IniDelete($GC_S_CHARACTERS_INI_PATH, $g_s_OldCharacter)
    EndSwitch

    IniWrite($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Email", $l_s_Email)
    IniWrite($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "Pwd", Security_EncryptString($l_s_Pwd))
    IniWrite($GC_S_CHARACTERS_INI_PATH, $l_s_Character, "FilePath", $l_s_FilePath)

    Security_CloseMutex($l_h_IniMutex)

    GUI_LoadCharacterList()

    GUIDelete($g_h_CharacterGUI)
    GUISetState(@SW_ENABLE, $Form1)
    WinActivate($Form1)

    If $a_i_Type = $GC_I_CHARACTER_GUI_TYPE_EDIT Then
        $g_i_QueuePos += 1
        GUI_ShowNextEdit()
    EndIf
EndFunc

Func GUI_Character_OnConfirm_Add()
    GUI_Character_OnConfirm($GC_I_CHARACTER_GUI_TYPE_ADD)
EndFunc

Func GUI_Character_OnConfirm_Edit()
    GUI_Character_OnConfirm($GC_I_CHARACTER_GUI_TYPE_EDIT)
EndFunc

Func GUI_Character_OnCancel()
    GUIDelete($g_h_CharacterGUI)
    GUISetState(@SW_ENABLE, $Form1)
    WinActivate($Form1)
    
    If UBound($g_ai_EditQueue) > 0 Then
        $g_i_QueuePos += 1
        GUI_ShowNextEdit()
    EndIf
EndFunc

Func GUI_Character_OnBrowse()
    Local $sFile = FileOpenDialog("Select Gw.exe", @ScriptDir, "Guild Wars (Gw.exe)|All Files (*.*)", 1)
    If Not @error And $sFile <> "" Then
        GUICtrlSetData($g_i_CtrlID_FilePathInput, $sFile)
    EndIf
EndFunc

Func GUI_Character_OnShowPwd()
    ; Toggle password visibility logic
    ; This is a bit complex in AutoIt without deleting/recreating control usually
    ; Simplified: Just msgbox for now or skip implementation to save space?
    ; Or just unmask it.
    
    ; Recreating the input control is the standard way
    Local $sRead = GUICtrlRead($g_i_CtrlID_PwdInput)
    Local $iX = 87, $iY = 84, $iW = 185, $iH = 22
    GUICtrlDelete($g_i_CtrlID_PwdInput)
    
    If $g_b_PwdMasked Then
        $g_i_CtrlID_PwdInput = GUICtrlCreateInput($sRead, $iX, $iY, $iW, $iH)
        GUICtrlSetData($g_i_CtrlID_ShowPwdButton, "Hide")
        $g_b_PwdMasked = False
    Else
        $g_i_CtrlID_PwdInput = GUICtrlCreateInput($sRead, $iX, $iY, $iW, $iH, $ES_PASSWORD)
        GUICtrlSetData($g_i_CtrlID_ShowPwdButton, "Show")
        $g_b_PwdMasked = True
    EndIf
EndFunc
