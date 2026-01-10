#cs
;;; Punch Out Farmer = Created by MrDomRocks
; You run in Normal Mode
: Punch and Run
#ce

#RequireAdmin
#include "C:\Users\mrdom\Desktop\GwAu3-main\API\_GwAu3.au3"
#include "C:\Users\mrdom\Desktop\GwAu3-main\Scripts\AddOns\GwAu3_AddOns_Punch_Out_Farm.au3"
#include "C:\Users\mrdom\Desktop\GwAu3-main\Scripts\GUI\GUI_Punch_Out_Farm.au3"
#include "C:\Users\mrdom\Desktop\GwAu3-main\API\SmartCast\_UtilityAI.au3"
#include "C:\Users\mrdom\Desktop\GwAu3-main\API\SmartCast\Core\UtilityAI_Core.au3"

Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

#Region Declarations
Global $ProcessID = ""
Global $timer = TimerInit()

Global $BotRunning = False
Global $Bot_Core_Initialized = False
Global Const $BotTitle = "Punch Out Farmer by MrDomRocks"


$g_bAutoStart = False  ; Flag for auto-start
$g_s_MainCharName  = ""

Func RndSleep($iBase)
    Sleep($iBase + Random(-$iBase * 0.1, $iBase * 0.1, 1))
EndFunc

#Region Global Const Declarations
; === Maps ===
Global Const $MAP_ID_GUUNAR = 644
Global Const $MAP_ID_FRONISINSTANCE = 704

; === Quests ===
Global Const $FRONIS_QUEST = 856

; === Dialogs ===
Global Const $FIRST_DIALOG = 0x00000085

; === Skills ===
Global Const $maxAllowdEnergy = 120

; === Skill Cost ===
Global Const $intAdrenaline[7] = [0, 0, 0, 100, 250, 175, 0]
#EndRegion Global Const Declarations
#EndRegion Declarations

; === Teleport To Waypoint ===
Func Travel_TeleportToWaypoint()
    ; Teleport to Guunars Hold
    Travel_TeleportToWaypoint($MAP_ID_GUUNAR)
    Sleep(2000)
    ; Wait until in Guunars Hold
    While Player_GetMapID() <> $MAP_ID_GUUNAR
        Sleep(500)
    WEnd
    Sleep(1000)
EndFunc

Func Take_Quest()
    ; Move to Killroy Stonekin
    Travel_WalkTo(6260.55, -1938.88)
    Sleep(1000)
    ; Interact with Killroy Stonekin
    NPC_InteractByName("Killroy Stonekin")
    Sleep(2000)
    ; Talk to Killroy Stoneskin
    Dialog_SelectOption($FIRST_DIALOG)
    Sleep(2000)
    ; Accept Kilroy Stonekin's Punch-Out Extravaganza!  
    NPC_InteractByName("Killroy Stonekin")
    Dialog_selectOption($FIRST_DIALOG)
    Sleep(2000)
    ;Enter Fronis Instance
    NPC_InteractByName("Killroy Stonekin")
    Dialog_selectOption($FIRST_DIALOG)
    Sleep(2000)
EndFunc

Func RunPunchOutSequence()
    ; Get current position
    Local $x = Agent_GetAgentInfo(-2, "X")
    Local $y = Agent_GetAgentInfo(-2, "Y")
    UAI_Fight($x, $y, 1320, 3500, $g_i_FinisherMode)
    UAI_Fight($x, $y, -3585, -15915, $g_i_FinisherMode)
    UAI_Fight($x, $y, -1081, -14387, $g_i_FinisherMode)
    UAI_Fight($x, $y, 3788, -16406, $g_i_FinisherMode)
    UAI_Fight($x, $y, 5724,-15148, $g_i_FinisherMode)
    UAI_Fight($x, $y, 8913, -16174, $g_i_FinisherMode)
    UAI_Fight($x, $y, 12900, -16065, $g_i_FinisherMode)
    Sleep(100)
    Update("Opening final chest")
	Sleep(100)
	$agent = GetNearestSignpostToCoords(13275,-16039)
    ChangeTarget($agent)
	MoveTo(DllStructGetData($agent, 'X'),DllStructGetData($agent, 'Y'))
	Sleep(500)
	;GoSignpost($agent)
	;ActionInteract()
	Sleep(Random(3000,4000,1))
	Sleep(2000)
	Update("Picking up ale")
	PickUpLoot()
EndFunc