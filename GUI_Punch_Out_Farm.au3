#cs
;;; GUI Created by MrDomRocks
#ce
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiStatusBar.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

Global $Start, $RefreshButton, $RunInfosGroup, $RunsLabel, $FailuresLabel, $TimeLabel, $Ales, $Form1
#Region ### START Koda GUI section ### Form=C:\Users\mrdom\Desktop\GUI.kxf
$Form1 = GUICreate("Punch Out", 441, 212, 493, 422)
GUISetCursor (2)
GUISetFont(8, 400, 0, "Calibri")
GUISetBkColor(0x008080)
$Start = GUICtrlCreateButton("Start", 359, 11, 75, 25)
$StatusBar1 = _GUICtrlStatusBar_Create($Form1)
Dim $StatusBar1_PartsWidth[3] = [100, 225, -1]
_GUICtrlStatusBar_SetParts($StatusBar1, $StatusBar1_PartsWidth)
_GUICtrlStatusBar_SetText($StatusBar1, "Punch Out Farm", 0)
_GUICtrlStatusBar_SetText($StatusBar1, "By MrDomRocks", 1)
_GUICtrlStatusBar_SetText($StatusBar1, "With thanks to the GwAu3 Community", 2)
_GUICtrlStatusBar_SetBkColor($StatusBar1, 0xB4B4B4)
_GUICtrlStatusBar_SetMinHeight($StatusBar1, 34)
$CharacterChoiceCombo = GUICtrlCreateCombo("No character selected", 15, 11, 250, 30, BitOR($CBS_DROPDOWN,$CBS_AUTOHSCROLL))
$RefreshButton = GUICtrlCreateButton("Refresh", 275, 11, 75, 25)
$RunInfosGroup = GUICtrlCreateGroup("Infos", 12, 41, 136, 105)
$RunsLabel = GUICtrlCreateLabel("Runs: 0", 22, 61, 125, 16)
$FailuresLabel = GUICtrlCreateLabel("Failures: 0", 22, 81, 125, 16)
$TimeLabel = GUICtrlCreateLabel("Time: 0", 22, 101, 125, 16)
$Ales = GUICtrlCreateLabel("Ales: 0", 21, 121, 125, 16)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$ConsoleEdit = GUICtrlCreateEdit("", 182, 45, 221, 125)
GUICtrlSetData(-1, "")
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetBkColor(-1, 0x000000)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###