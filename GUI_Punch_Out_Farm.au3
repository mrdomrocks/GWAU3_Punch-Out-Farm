#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

Global $StartButton, $FarmProgress, $RunInfosGroup, $RunsLabel, $FailuresLabel, $TimeLabel, $Ales
#Region ### START Koda GUI section ### Form=C:\Users\mrdom\Desktop\GUI.kxf
$Form1 = GUICreate("Punch Out", 451, 470, 624, 254)
GUISetCursor (2)
GUISetFont(8, 400, 0, "Calibri")
GUISetBkColor(0x008080)
$Start = GUICtrlCreateButton("Start", 294, 56, 75, 25)
$StatusBar1 = _GUICtrlStatusBar_Create($Form1)
Dim $StatusBar1_PartsWidth[3] = [100, 225, -1]
_GUICtrlStatusBar_SetParts($StatusBar1, $StatusBar1_PartsWidth)
_GUICtrlStatusBar_SetText($StatusBar1, "Punch Out Farm", 0)
_GUICtrlStatusBar_SetText($StatusBar1, "By MrDomRocks", 1)
_GUICtrlStatusBar_SetText($StatusBar1, "With thanks to the GwAu3 Community", 2)
_GUICtrlStatusBar_SetBkColor($StatusBar1, 0xB4B4B4)
_GUICtrlStatusBar_SetMinHeight($StatusBar1, 34)
$CharacterChoiceCombo = GUICtrlCreateCombo("No character selected", 15, 11, 326, 30)
$FarmProgress = GUICtrlCreateProgress(309, 406, 126, 21)
$RunInfosGroup = GUICtrlCreateGroup("Infos", 17, 46, 266, 131)
$RunsLabel = GUICtrlCreateLabel("Runs: 0", 27, 71, 246, 16)
$FailuresLabel = GUICtrlCreateLabel("Failures: 0", 27, 96, 246, 16)
$TimeLabel = GUICtrlCreateLabel("Time: 0", 27, 121, 246, 16)
$Ales = GUICtrlCreateLabel("Ales: 0", 26, 146, 246, 16)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$ConsoleEdit = GUICtrlCreateEdit("", 22, 195, 261, 231)
GUICtrlSetData(-1, "")
GUICtrlSetState(-1, $GUI_DISABLE)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

