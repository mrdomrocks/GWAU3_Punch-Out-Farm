#cs
;;; Punch Out Farmer = Created by MrDomRocks
; Hard Mode and Normal Mode
: Punch and Run
#ce
#RequireAdmin

#include "../../API/_GwAu3.au3"
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiStatusBar.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <TabConstants.au3>
#include <GuiTab.au3>
#include <ListViewConstants.au3>

Global $Start, $RunInfosGroup, $RunsLabel, $TimeLabel, $Ales, $Form1, $gIdentifyCheckbox, $gSellCheckbox, $gHardModeCheckbox, $gRenderingCheckbox, $ConsoleEdit
Global $SuccessLabel, $FailuresLabel
Global $CharacterChoiceCombo
Global $BotRunning = False
Global $RunCount = 0
Global $AleCount = 0
Global $TimerInit = 0

; Characters Tab Globals
Global $g_i_CtrlID_Tab, $g_i_CtrlID_AccountList, $g_h_CtrlHnd_AccountList
Global $g_i_CtrlID_Button_Add, $g_i_CtrlID_Button_Edit, $g_i_CtrlID_Button_Remove

#Region ### START Koda GUI section ### Form=
$Form1 = GUICreate("Punch Out", 479, 304, 836, 477)
GUISetCursor (2)
GUISetFont(8, 400, 0, "Calibri")
$g_i_CtrlID_Tab = GUICtrlCreateTab(15, 10, 450, 260, $TCS_FIXEDWIDTH)
GUICtrlCreateTabItem("General")
$ConsoleEdit = GUICtrlCreateEdit("", 171, 42, 280, 150, BitOR($GUI_SS_DEFAULT_EDIT,$ES_READONLY))
GUICtrlSetData(-1, "")
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
GUICtrlSetColor(-1, 0xFFFFFF)
$Start = GUICtrlCreateButton("Start", 171, 232, 90, 25)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$CharacterChoiceCombo = GUICtrlCreateCombo("", 171, 202, 200, 25)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$gIdentifyCheckbox = GUICtrlCreateCheckbox("Auto Identify", 45, 52, 120, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$gSellCheckbox = GUICtrlCreateCheckbox("Auto Sell", 45, 84, 120, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$gHardModeCheckbox = GUICtrlCreateCheckbox("Hard Mode", 45, 113, 120, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$gRenderingCheckbox = GUICtrlCreateCheckbox("Disable Rendering", 45, 142, 120, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
GUICtrlCreateTabItem("Statistics")
$TimeLabel = GUICtrlCreateLabel("Time: 00:00:00", 45, 87, 200, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$RunsLabel = GUICtrlCreateLabel("Runs: 0", 45, 112, 200, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$SuccessLabel = GUICtrlCreateLabel("Success: 0", 45, 137, 200, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$FailuresLabel = GUICtrlCreateLabel("Failures: 0", 45, 162, 200, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$Ales = GUICtrlCreateLabel("Ales: 0", 45, 187, 200, 20)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
GUICtrlCreateTabItem("Characters")
$g_i_CtrlID_AccountList = GUICtrlCreateListView("E-Mail|Character Name|File Path", 21, 42, 435, 150, -1, BitOR($WS_EX_CLIENTEDGE,$WS_EX_STATICEDGE))
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 0, 50)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 1, 50)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 2, 50)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$g_i_CtrlID_Button_Add = GUICtrlCreateButton("Add", 21, 197, 100, 25)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$g_i_CtrlID_Button_Edit = GUICtrlCreateButton("Edit", 131, 197, 100, 25)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
$g_i_CtrlID_Button_Remove = GUICtrlCreateButton("Remove", 241, 197, 100, 25)
GUICtrlSetFont(-1, 8, 400, 0, "Arial")
GUICtrlCreateTabItem("")
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

; === Status Bar (Kept separate for safety) ===
$StatusBar1 = _GUICtrlStatusBar_Create($Form1)
Dim $StatusBar1_PartsWidth[3] = [100, 225, 1]
_GUICtrlStatusBar_SetParts($StatusBar1, $StatusBar1_PartsWidth)
_GUICtrlStatusBar_SetText($StatusBar1, "Punch Out Farm", 0)
_GUICtrlStatusBar_SetText($StatusBar1, "By MrDomRocks", 1)
_GUICtrlStatusBar_SetText($StatusBar1, "With thanks to the GwAu3 Community", 2)
_GUICtrlStatusBar_SetBkColor($StatusBar1, 0xB4B4B4)
_GUICtrlStatusBar_SetMinHeight($StatusBar1, 34)

Func LogOut($TEXT)
    Local $TEXTLEN = StringLen($TEXT)
    Local $CONSOLELEN = _GUICtrlEdit_GetTextLen($ConsoleEdit)
    If $TEXTLEN + $CONSOLELEN > 30000 Then GUICtrlSetData($ConsoleEdit, StringRight(_GUICtrlEdit_GetText($ConsoleEdit), 30000 - $TEXTLEN - 1000))
    _GUICtrlEdit_AppendText($ConsoleEdit, @CRLF & $TEXT)
    _GUICtrlEdit_Scroll($ConsoleEdit, 1)
EndFunc
