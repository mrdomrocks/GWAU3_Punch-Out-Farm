#cs =============================================================================================================================
	AutoIt Version: 3.3.16.1
	Author: KleuTSchi ft. ZupaBlahq
	Status: Public
	Function: Farms Ministerial Commendations and other items by repeatedly entering the quest "A Chance Encounter"
#ce =============================================================================================================================

#RequireAdmin
#NoTrayIcon

#Region Includes
; #INCLUDES# ====================================================================================================================
; Note: All native AutoIt includes are covered by GwAu3/API/_GwAu3.au3 which should always be included in the main script.
;       The same applies to GwAu3 API-specific includes. Other includes containing script-specific files are covered 
;       by Files/_Includes.au3.
#include "../../API/_GwAu3.au3"
#include "Files/_Includes.au3"
; ===============================================================================================================================
#EndRegion Includes

#Region Declarations
; #GLOBALS - BOT VERSION# =======================================================================================================
Global Const $GC_S_BOT_VERSION = "Version 2.5"
; ===============================================================================================================================

; #GLOBALS - WINEVENT HOOK# =====================================================================================================
; WinEvent hook (crash dialog detection) buffers, flags, and handles
Global Const $GC_S_CRASH_CLASS = "#32770"
Global Const $GC_S_CRASH_TITLE = "Gw.exe"
Global Const $GC_I_CRASH_TITLE_LEN = StringLen($GC_S_CRASH_TITLE)

Global $g_b_HookActive = False, $g_h_WinEventHook_Show = 0, $g_h_Callback = 0
Global $g_d_ClassBuffer = DllStructCreate("wchar[256]")
Global $g_p_ClassBuffer = DllStructGetPtr($g_d_ClassBuffer)
Global $g_d_TitleBuffer = DllStructCreate("wchar[256]")
Global $g_p_TitleBuffer = DllStructGetPtr($g_d_TitleBuffer)

Global $g_b_Heartbeat = False
; ===============================================================================================================================

; #GLOBALS - BOT STATE# =========================================================================================================
; High-level bot state flags and current state
Global Const $GC_I_BOTSTATE_INIT = -1
Global Const $GC_I_BOTSTATE_RUN = 0
Global Const $GC_I_BOTSTATE_IDLE = 1
Global Const $GC_I_BOTSTATE_OPEN = 3
Global Const $GC_I_BOTSTATE_TRADE = 4
Global Const $GC_I_BOTSTATE_ERROR = 5
Global $g_i_BotState = $GC_I_BOTSTATE_INIT

Global $g_b_BotInitialized = False
Global $g_b_PauseRequested = False
Global $g_b_ResumeRequested = False
Global $g_b_AutoTradeReady = False
Global $g_b_AutoTradeLeave = False
; ===============================================================================================================================

; #GLOBALS - MAPS & MODE# =======================================================================================================
; Canonical map IDs and run-mode flags
Global Const $GC_I_MAP_ID_OUTPOST = $GC_I_MAP_ID_KAINENG_CENTER
Global Const $GC_I_MAP_ID_OUTPOST_EVENT = $GC_I_MAP_ID_KAINENG_CENTER_CANTHAN_NEW_YEAR
Global Const $GC_I_MAP_ID_EXPLORABLE = $GC_I_MAP_ID_A_CHANCE_ENCOUNTER_KAINENG_CENTER

Global $g_b_TravelGH = True
Global $g_b_HardMode = True
; ===============================================================================================================================

; #GLOBALS - HEROES & BUILDS# ===================================================================================================
; Hero aliases and party composition/behavior presets
Global Const $GC_I_HERO_1 = $GC_I_HERO_ID_ACOLYTE_SOUSUKE ; Sousuke = Starburst
Global Const $GC_I_HERO_2 = $GC_I_HERO_ID_VEKK ; Vekk = Stone Sheath
Global Const $GC_I_HERO_3 = $GC_I_HERO_ID_PYRE_FIERCESHOT ; Pyre Fierceshot = Trapper
Global Const $GC_I_HERO_4 = $GC_I_HERO_ID_GWEN ; Gwen = Martyr Prot Mesmer
Global Const $GC_I_HERO_5 = $GC_I_HERO_ID_RAZAH ; Razah = SoS Resto + Recall
Global Const $GC_I_HERO_6 = $GC_I_HERO_ID_OLIAS ; Olias = BiP Resto
Global Const $GC_I_HERO_7 = $GC_I_HERO_ID_XANDRA ; Xandra = ST Mot

Global Const $GC_AI_HEROES[] = [ _
    $GC_I_HERO_1, _
    $GC_I_HERO_2, _
    $GC_I_HERO_3, _
    $GC_I_HERO_4, _
    $GC_I_HERO_5, _
    $GC_I_HERO_6, _
    $GC_I_HERO_7 _
]

Global Const $GC_AI_HERO_BEHAVIORS[] = [0, 0, 0, 0, 2, 1, 2]

; Build templates and party builds list (index-aligned with heroes)
Global Const $GC_S_BUILD_FIRE_ELE = "OgBDgqyMSlVHR3C8CLg4CKDADA"
Global Const $GC_S_BUILD_EARTH_ELE = "OgljkwMopOdVm22oHuK2x14UBA"
Global Const $GC_S_BUILD_TRAPPER = "OggjclYsYSNHLHJHKHchYOIHCAA"
Global Const $GC_S_BUILD_PROT_MESMER = "OQNDAowvOqkcw0z0NEEcaRBA"
Global Const $GC_S_BUILD_SOS_RESTO = "OAejEyiM5QXTYMdOTMSTdiVPciA"
Global Const $GC_S_BUILD_BIP_RESTO = "OAhjQoGYIP3BqdVV4JNncDzxJA"
Global Const $GC_S_BUILD_ST_MOT = "OAmjAyk85QYTWPPOhTOTkTQTfiA"

Global Const $GC_AS_HERO_BUILDS[] = [ _
    $GC_S_BUILD_FIRE_ELE, _
    $GC_S_BUILD_EARTH_ELE, _
    $GC_S_BUILD_TRAPPER, _
    $GC_S_BUILD_PROT_MESMER, _
    $GC_S_BUILD_SOS_RESTO, _
    $GC_S_BUILD_BIP_RESTO, _
    $GC_S_BUILD_ST_MOT _
]

Global Const $GC_S_BUILD_PLAYER_WARRIOR = "OQojQhV6KT4k9F8E7gUiEY5iwF"
Global Const $GC_S_BUILD_PLAYER_RANGER = "OgEUcDqWV8S4k9F8E7gUi+G5iMH"
Global Const $GC_S_BUILD_PLAYER_MONK = "OwEUAj2S1qS4k9F8E7gUigE5iwF"
Global Const $GC_S_BUILD_PLAYER_NECROMANCER = "OAFUYCqWVyS4k9F8E7gUizB5iwF"
Global Const $GC_S_BUILD_PLAYER_MESMER = "OQFUAixS1qS4k9F8E7gUioA5iwF"
Global Const $GC_S_BUILD_PLAYER_ELEMENTALIST = "OgFUwi1S1qS4k9F8E7gUitT5iwF"
Global Const $GC_S_BUILD_PLAYER_ASSASSIN = "OwFkQpV63OG0dZfBPxOYDkLTuIcB"
Global Const $GC_S_BUILD_PLAYER_RITUALIST = "OAGkQGhLlWpEOZfBPxOIlo0UuIcB"
Global Const $GC_S_BUILD_PLAYER_PARAGON = "OQGjgOUcFT4k9F8E7gUiBA5iwF"
Global Const $GC_S_BUILD_PLAYER_DERVISH = "OgGlwWrJlWpqFhT2XwTsDSJSglL29B"

Global Const $GC_AS_PLAYER_BUILDS[] = [ _
    $GC_S_BUILD_PLAYER_WARRIOR, _
    $GC_S_BUILD_PLAYER_RANGER, _
    $GC_S_BUILD_PLAYER_MONK, _
    $GC_S_BUILD_PLAYER_NECROMANCER, _
    $GC_S_BUILD_PLAYER_MESMER, _
    $GC_S_BUILD_PLAYER_ELEMENTALIST, _
    $GC_S_BUILD_PLAYER_ASSASSIN, _
    $GC_S_BUILD_PLAYER_RITUALIST, _
	$GC_S_BUILD_PLAYER_PARAGON, _
	$GC_S_BUILD_PLAYER_DERVISH _
]

; In-instance agent IDs
Global Const $GC_I_PLAYER_ID = 5
Global Const $GC_I_HERO_ID_1 = 6
Global Const $GC_I_HERO_ID_2 = 7
Global Const $GC_I_HERO_ID_3 = 8
Global Const $GC_I_HERO_ID_4 = 9
Global Const $GC_I_HERO_ID_5 = 10
Global Const $GC_I_HERO_ID_6 = 11
Global Const $GC_I_HERO_ID_7 = 12
Global Const $GC_I_MIKU_ID = 58

Global $g_p_Miku
; ===============================================================================================================================

; #GLOBALS - QUEST & FIGHT FLOW# ================================================================================================
; Control flags, player profession cache, and BiP cadence
Global $g_i_PlayerProfession = 0
Global $g_b_CanContinue = True
Global $g_b_JourneyReady = False
Global $g_b_PlayerAssistance = True
Global $g_ai_BiPDelays[] = [10, 0, 0, 0, 0, 0]
Global Const $GC_I_MAXIMUM_BIP_DELAY = $g_ai_BiPDelays[0]
Global Const $GC_I_BIP_TARGETS = UBound($g_ai_BiPDelays, $UBOUND_ROWS) - 1
; ===============================================================================================================================

; #GLOBALS - SPIKE / SPIRITS# ===================================================================================================
; Final spike coordination flags
Global $g_b_PlaceSpirits = False
Global $g_b_SpikeSuccess = False
; ===============================================================================================================================

; #GLOBALS - EXCHANGE / ECONOMY# =================================================================================================
; Exchange thresholds and model sets for MC turn-ins and gold conversion
Global Const $GC_I_EMPTY_SLOT_THRESHOLD = 10
Global Const $GC_I_EXCHANGE_AMOUNT = 2250
Global Const $GC_I_EXCHANGE_REQ = 3

Global Const $GC_AI_MODELIDS_EXCHANGE_MC[] = [ _
    $GC_I_MODELID_IMPERIAL_GUARD_REINFORCEMENT_ORDER, _
    $GC_I_MODELID_SEAL_OF_THE_DRAGON_EMPIRE, _
    $GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX _
]
Global Const $GC_AI_MODELIDS_EXCHANGE_GOLD[] = [ _
    $GC_I_MODELID_GLOB_OF_ECTOPLASM, _
    $GC_I_MODELID_OBSIDIAN_SHARD, _
    $GC_I_MODELID_LOCKPICK _
]
; ===============================================================================================================================

; #GLOBALS - ITEM MODEL IDS# ====================================================================================================
; Lockbox loot item model IDs and helpers
Global Const $GC_I_MODELID_MINIATURE_MINISTER_REIKO = 30224
Global Const $GC_I_MODELID_MINIATURE_ECCLESIATE_XUN_RAO = 30225
Global Const $GC_I_MODELID_BEI_CHIS_BULWARK = 30230
Global Const $GC_I_MODELID_CLAW_OF_THE_WHISPERED = 30228
Global Const $GC_I_MODELID_GANSHUS_RECORD = 30229
Global Const $GC_I_MODELID_OROKUS_SLICERS = 30218
Global Const $GC_I_MODELID_PHOENIXS_RETRIBUTION = 30226
Global Const $GC_I_MODELID_PLAGUE_SOAKED_STAVE = 30231
Global Const $GC_I_MODELID_SHATTERED_ILLUSION = 30232
Global Const $GC_I_MODELID_UNENDING_NIGHTS_GRASP = 30227
Global Const $GC_I_MODELID_VISION_OF_PURITY = 30233
Global Const $GC_I_MODELID_XUN_RAOS_ABSOLUTION = 30219
Global Const $GC_I_MODELID_XUN_RAOS_COMMAND = 30217
Global Const $GC_I_MODELID_XUN_RAOS_JUSTICE = 30220
Global Const $GC_I_MODELID_XUN_RAOS_QUILL = 30215
Global Const $GC_I_MODELID_IMPERIAL_PANDA_LICENSE = 30213

Global Const $GC_I_EXTRAID_ANY = 0xFFFF
; ===============================================================================================================================

; #GLOBALS - LOOT / OPEN / TRADE LISTS# =========================================================================================
; Keep/junk sets for lockbox openings
Global Const $GC_AI_MODELIDS_OPEN_KEEP[] = [ _
    $GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX, $GC_I_MODELID_BATTLE_ISLE_ICED_TEA, _
    $GC_I_MODELID_DELICIOUS_CAKE, $GC_I_MODELID_PARTY_BEACON, _
    $GC_I_MODELID_TENGU_SUPPORT_FLARE, $GC_I_MODELID_LOCKPICK _
]
Global Const $GC_AI_MODELIDS_OPEN_JUNK[] = [ _
    $GC_I_MODELID_MINIATURE_MINISTER_REIKO, $GC_I_MODELID_MINIATURE_ECCLESIATE_XUN_RAO, _
    $GC_I_MODELID_BEI_CHIS_BULWARK, $GC_I_MODELID_CLAW_OF_THE_WHISPERED, _
    $GC_I_MODELID_GANSHUS_RECORD, $GC_I_MODELID_OROKUS_SLICERS, _
    $GC_I_MODELID_PHOENIXS_RETRIBUTION, $GC_I_MODELID_PLAGUE_SOAKED_STAVE, _
    $GC_I_MODELID_SHATTERED_ILLUSION, $GC_I_MODELID_UNENDING_NIGHTS_GRASP, _
    $GC_I_MODELID_VISION_OF_PURITY, $GC_I_MODELID_XUN_RAOS_ABSOLUTION, _
    $GC_I_MODELID_XUN_RAOS_COMMAND, $GC_I_MODELID_XUN_RAOS_JUSTICE, _
    $GC_I_MODELID_XUN_RAOS_QUILL, $GC_I_MODELID_IMPERIAL_PANDA_LICENSE _
]

; Trade sets (expanded from GUI options)
Global Const $GC_AI_MODELIDS_TRADE_TOMES[] = [ _
    $GC_I_MODELID_ASSASSIN_TOME, $GC_I_MODELID_MESMER_TOME, _
    $GC_I_MODELID_NECROMANCER_TOME, $GC_I_MODELID_ELEMENTALIST_TOME, _
    $GC_I_MODELID_MONK_TOME, $GC_I_MODELID_WARRIOR_TOME, _
    $GC_I_MODELID_RANGER_TOME, $GC_I_MODELID_DERVISH_TOME, _
    $GC_I_MODELID_RITUALIST_TOME, $GC_I_MODELID_PARAGON_TOME _
]
Global Const $GC_AI_MODELIDS_TRADE_PCONS[] = [ _
    $GC_I_MODELID_CUPCAKE, $GC_I_MODELID_PUMPKIN_PIE, _
    $GC_I_MODELID_GOLDEN_EGG, $GC_I_MODELID_CANDY_APPLE, _
    $GC_I_MODELID_CANDY_CORN, $GC_I_MODELID_PUMPKIN_COOKIE, _
    $GC_I_MODELID_HONEYCOMB _
]
Global Const $GC_AI_MODELIDS_TRADE_EVENT_TOKENS[] = [ _
    $GC_I_MODELID_TOTS, $GC_I_MODELID_CC_SHARDS, _
    $GC_I_MODELID_VICTORY_TOKEN, $GC_I_MODELID_LUNAR_TOKEN, _
    $GC_I_MODELID_WAYFARER_MARK _
]
Global Const $GC_AI_MODELIDS_TRADE_TPITEMS[] = [ _
    $GC_I_MODELID_SHAMROCK_ALE, $GC_I_MODELID_CHOCOLATE_BUNNY, _
    $GC_I_MODELID_HARD_APPLE_CIDER, $GC_I_MODELID_HUNTERS_ALE, _
    $GC_I_MODELID_KRYTAN_BRANDY, $GC_I_MODELID_BOTTLE_ROCKET, _
    $GC_I_MODELID_CHAMPAGNE_POPPER, $GC_I_MODELID_SPARKLER, _
    $GC_I_MODELID_SUGARY_BLUE_DRINK, $GC_I_MODELID_EGGNOG, _
    $GC_I_MODELID_FRUITCAKE, $GC_I_MODELID_SNOWMAN_SUMMONER, _
    $GC_I_MODELID_BOTTLE_OF_GROG, $GC_I_MODELID_GHOST_IN_THE_BOX, _
    $GC_I_MODELID_SQUASH_SERUM, $GC_I_MODELID_VIAL_OF_ABSINTHE, _
    $GC_I_MODELID_WITCHS_BREW _
]

; Loot filters (drop pickup)
Global Const $GC_AI_MODELIDS_LOOT_TOMES[] = [ _
    $GC_I_MODELID_ASSASSIN_TOME, $GC_I_MODELID_MESMER_TOME, _
    $GC_I_MODELID_NECROMANCER_TOME, $GC_I_MODELID_ELEMENTALIST_TOME, _
    $GC_I_MODELID_MONK_TOME, $GC_I_MODELID_WARRIOR_TOME, _
    $GC_I_MODELID_RANGER_TOME, $GC_I_MODELID_DERVISH_TOME, _
    $GC_I_MODELID_RITUALIST_TOME, $GC_I_MODELID_PARAGON_TOME _
]
Global Const $GC_AI_MODELIDS_LOOT_PCONS[] = [ _
    $GC_I_MODELID_CUPCAKE, $GC_I_MODELID_PUMPKIN_PIE, _
    $GC_I_MODELID_GOLDEN_EGG, $GC_I_MODELID_HONEYCOMB _
]
Global Const $GC_AI_MODELIDS_LOOT_EVENT_TOKENS[] = [ _
    $GC_I_MODELID_TOTS, $GC_I_MODELID_CC_SHARDS, _
    $GC_I_MODELID_VICTORY_TOKEN, $GC_I_MODELID_LUNAR_TOKEN, _
    $GC_I_MODELID_WAYFARER_MARK _
]
Global Const $GC_AI_MODELIDS_LOOT_TPITEMS[] = [ _
    $GC_I_MODELID_SHAMROCK_ALE, $GC_I_MODELID_CHOCOLATE_BUNNY, _
    $GC_I_MODELID_HARD_APPLE_CIDER, $GC_I_MODELID_HUNTERS_ALE, _
    $GC_I_MODELID_KRYTAN_BRANDY, $GC_I_MODELID_BOTTLE_ROCKET, _
    $GC_I_MODELID_CHAMPAGNE_POPPER, $GC_I_MODELID_SPARKLER, _
    $GC_I_MODELID_SUGARY_BLUE_DRINK, $GC_I_MODELID_EGGNOG, _
    $GC_I_MODELID_FRUITCAKE, $GC_I_MODELID_SNOWMAN_SUMMONER, _
    $GC_I_MODELID_BOTTLE_OF_GROG _
]
; ===============================================================================================================================

; #GLOBALS - STATISTICS TRACKERS# ===============================================================================================
; Logical categories assigned via @extended when picking up items
Global Enum $GC_I_STATISTICS_TRACKER_NONE, _
    $GC_I_STATISTICS_TRACKER_GOLDEN_ITEM, _
    $GC_I_STATISTICS_TRACKER_MINISTERIAL_COMMENDATION, _
    $GC_I_STATISTICS_TRACKER_LOCKPICK, _
    $GC_I_STATISTICS_TRACKER_BLACK_DYE
; ===============================================================================================================================
#EndRegion Declarations

#Region Setup
; #FUNCTION# ====================================================================================================================
; Name...........: SetupEncounter
; Description....: Prepares party and UI before starting the "A Chance Encounter" farm.
; Syntax.........: SetupEncounter ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Sleep durations are ping-adjusted via Other_GetPing().
;                  - Expects arrays $GC_AS_PLAYER_BUILDS to be size-aligned with maximum profession count (10).
;                  - Expects arrays $GC_AI_HEROES, $GC_AS_HERO_BUILDS to be size-aligned.
; Related........: AddOns_CloseAllPanels, AddOns_EnableAllHeroSkillbars, AddOns_GetTotalItemCountbyModelID, AddOns_RndTravel,
;                  Ui_LeaveGroup, Ui_SetDifficulty, AddHeroes, Attribute_LoadSkillTemplate, Map_GetMapID, Other_GetPing,
;                  Party_GetPartyProfessionInfo, SetHeroBehaviors
; ===============================================================================================================================
Func SetupEncounter()
	Local $l_i_Ping = Other_GetPing()

	Friend_SetOfflineStatus()
	Sleep(500 + $l_i_Ping)

	Local $l_i_MapID = Map_GetMapID()
	If $l_i_MapID <> $GC_I_MAP_ID_OUTPOST And $l_i_MapID <> $GC_I_MAP_ID_OUTPOST_EVENT Then
		If Not HeartbeatTravel($GC_I_MAP_ID_OUTPOST) Then Return SetError(1, 0, False)
	EndIf

	Ui_LeaveGroup()
	Sleep(500 + $l_i_Ping)

	AddOns_AddHeroes($GC_AI_HEROES)
	Sleep(500 + $l_i_Ping)

	AddOns_SetHeroBehaviors($GC_AI_HERO_BEHAVIORS)
	Sleep(500 + $l_i_Ping)

	Ui_SetDifficulty($g_b_HardMode)
	Sleep(500 + $l_i_Ping)

    Static $s_b_InitialSetup = True
    If $s_b_InitialSetup Then
        $g_i_PlayerProfession = Party_GetPartyProfessionInfo(-2, "Primary")
        If $g_i_PlayerProfession <= 0 Then 
            FailHeartbeat("SetupEncounter → GetPartyProfessionInfo → Invalid primary professsion value")
        EndIf    

        Attribute_LoadSkillTemplate($GC_AS_PLAYER_BUILDS[$g_i_PlayerProfession - 1])

        Local $l_i_HeroCount = UBound($GC_AI_HEROES)
        For $i = 1 To $l_i_HeroCount
            Attribute_LoadSkillTemplate($GC_AS_HERO_BUILDS[$i - 1], $i)
            Sleep(150 + $l_i_Ping)
        Next
        AddOns_EnableAllHeroSkillbars($l_i_HeroCount)
        $s_b_InitialSetup = False
    EndIf

	$g_i_Count_MinisterialCommendation = AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_MINISTERIAL_COMMENDATION)
	$g_i_Count_MinisterialCommendation += (AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER) * $GC_I_EXCHANGE_REQ)
EndFunc   ;==>SetupEncounter
#EndRegion Setup

#Region Inventory
Func DepositItems($a_i_IncludeBag1 = True, $a_i_IncludeBag2 = True, $a_i_IncludeBag3 = True, $a_i_IncludeBag4 = True)
    Local $l_av2_Inv = Item_GetInventoryArray($a_i_IncludeBag1, $a_i_IncludeBag2, $a_i_IncludeBag3, $a_i_IncludeBag4)
    Local $l_i_ItemCnt = UBound($l_av2_Inv)

    If $l_i_ItemCnt = 0 Then
        AddOns_Out("[ERR] Inventory array is empty")
        Return SetError(1, 0, 0)
    EndIf

    Local $l_i_Ping = Other_GetPing()
    Local $l_i_StashedWeapons = 0

    For $i = 0 To $l_i_ItemCnt - 1
        Local $l_p_Item = $l_av2_Inv[$i][$GC_I_INVENTORY_PTR]
        Local $l_i_Type = $l_av2_Inv[$i][$GC_I_INVENTORY_ITEMTYPE]

        Switch $l_i_Type
            Case $GC_I_TYPE_AXE, $GC_I_TYPE_BOW, $GC_I_TYPE_OFFHAND, $GC_I_TYPE_HAMMER, $GC_I_TYPE_WAND, $GC_I_TYPE_SHIELD, _
		    $GC_I_TYPE_STAFF, $GC_I_TYPE_SWORD, $GC_I_TYPE_DAGGERS, $GC_I_TYPE_SCYTHE, $GC_I_TYPE_SPEAR
                Local $l_ai_StorageSlot = AddOns_GetEmptyStorageSlot()
                If $l_ai_StorageSlot[0] = 0 Then ContinueLoop

                Item_MoveItem_($l_p_Item, $l_ai_StorageSlot[0], $l_ai_StorageSlot[1])

                Local $l_h_Timeout = TimerInit()
                Do
                	Sleep(10 + $l_i_Ping)
					If Item_GetItemBySlot($l_ai_StorageSlot[0], $l_ai_StorageSlot[1]) <> 0 Then
						AddOns_Out("[INFO] Stashed a rare weapon")
						$l_i_StashedWeapons += 1
						ExitLoop
					EndIf
                Until TimerDiff($l_h_Timeout) > (1500 + $l_i_Ping)

            Case Else
                If $l_av2_Inv[$i][$GC_I_INVENTORY_QUANTITY] = 250 Then 
                    Local $l_ai_StorageSlot = AddOns_GetEmptyStorageSlot()
                    If $l_ai_StorageSlot[0] = 0 Then ContinueLoop

                    Item_MoveItem_($l_p_Item, $l_ai_StorageSlot[0], $l_ai_StorageSlot[1])

                    Local $l_h_Timeout = TimerInit()
                    Do
                        Sleep(10 + $l_i_Ping)
						If Item_GetItemBySlot($l_ai_StorageSlot[0], $l_ai_StorageSlot[1]) <> 0 Then ExitLoop
                    Until TimerDiff($l_h_Timeout) > (1500 + $l_i_Ping)
                EndIf
        EndSwitch
            
        ContinueLoop
    Next

	$g_i_Count_StoredGoldItem += $l_i_StashedWeapons

    Return $l_i_StashedWeapons
EndFunc   ;==>DepositItems

; #FUNCTION# ====================================================================================================================
; Name...........: UseBag
; Description....: Returns whether a given bag index is enabled in the GUI.
; Syntax.........: UseBag ( $a_i_BagNumber )
; Parameters.....: $a_i_BagNumber - Integer (1..4) : Bag index.
; Return values..: True  - Bag is enabled.
;                  False - Bag is disabled.
; Author.........: KleuTSchi
; Remarks........: - Reads GUI state only; no side effects.
; Related........: GUI_GUICtrlIsChecked, Inventory
; ===============================================================================================================================
Func UseBag($a_i_BagNumber)
	Switch $a_i_BagNumber
		Case 1
			If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_UseBag1) Then Return True
		Case 2
			If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_UseBag2) Then Return True
		Case 3
			If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_UseBag3) Then Return True
		Case 4
			If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_UseBag4) Then Return True
	EndSwitch
	Return False
EndFunc   ;==>UseBag

; #FUNCTION# ====================================================================================================================
; Name...........: BuyFromRareMaterialTrader
; Description....: Moves to a Rare Material Trader and buys items in a loop.
; Syntax.........: BuyFromRareMaterialTrader ( $a_i_MapID, $a_i_ModelID [, $a_i_Quantity = 1 ] )
; Parameters.....: $a_i_MapID    - Integer : Target map/outpost.
;                  $a_i_ModelID  - Integer : Item model ID.
;                  $a_i_Quantity - Integer : Units per attempt.
; Return values..: Success - True with @extended = total bought.
;                  Failure - False with @error set to:
;                            1 -> Navigation failed.
; Author.........: KleuTSchi
; Remarks........: - Brief sleeps use ping-adjusted delays to avoid UI spam.
;                  - May optionally convert excess gold with BuyFromMerchant.
; Related........: BuyFromMerchant, Item_GetInventoryInfo, Merchant_BuyItem, Other_GetPing, Pathing_GoRareMaterialTrader            
; ===============================================================================================================================
Func BuyFromRareMaterialTrader($a_i_MapID, $a_i_ModelID, $a_i_Quantity = 1)
    If Not Pathing_GoRareMaterialTrader($a_i_MapID) Then Return SetError(1, 0, False)

	Local $l_i_Ping = Other_GetPing()
	Local $l_i_AmountBought = 0
    While True
        If Not Merchant_BuyItem($a_i_ModelID, $a_i_Quantity, True) Then ExitLoop
		$l_i_AmountBought += $a_i_Quantity
        Sleep(50 + $l_i_Ping)
    WEnd

    Local $l_i_InvGold = Item_GetInventoryInfo("GoldCharacter")
    If $l_i_InvGold > 75000 Then
        Local $l_i_Qty = Int($l_i_InvGold / 1500)
        BuyFromMerchant($a_i_MapID, $GC_AI_MODELIDS_EXCHANGE_GOLD[2], $l_i_Qty)
    EndIf

    Return SetExtended($l_i_AmountBought, True)
EndFunc   ;==>BuyFromRareMaterialTrader

; #FUNCTION# ====================================================================================================================
; Name...........: BuyFromMerchant
; Description....: Moves to a Merchant and buys a specific item.
; Syntax.........: BuyFromMerchant ( $a_i_MapID, $a_i_ModelID [, $a_i_Quantity = 1 ] )
; Parameters.....: $a_i_MapID    - Integer : Target map/outpost.
;                  $a_i_ModelID  - Integer : Item model ID.
;                  $a_i_Quantity - Integer : Quantity to buy.
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Navigation failed.
; Author.........: KleuTSchi
; Remarks........: - One-shot purchase; caller decides on retries.
; Related........: Merchant_BuyItem, Other_GetPing, Pathing_GoMerchant
; ===============================================================================================================================
Func BuyFromMerchant($a_i_MapID, $a_i_ModelID, $a_i_Quantity = 1)
    If Not Pathing_GoMerchant($a_i_MapID) Then Return SetError(1, 0, False)

	Local $l_i_Ping = Other_GetPing()
    Local $l_b_Success = Merchant_BuyItem($a_i_ModelID, $a_i_Quantity)
    Sleep(50 + $l_i_Ping)

    Return $l_b_Success
EndFunc   ;==>BuyFromMerchant

; #FUNCTION# ====================================================================================================================
; Name...........: GoldCheck
; Description....: Deposits or exchanges excess gold based on thresholds and GUI options.
; Syntax.........: GoldCheck ( $a_i_MapID )
; Parameters.....: $a_i_MapID - Integer : Reference map for traders.
; Return values..: 0 -> No action.
;                  1 -> Deposited to storage.
;                  2 -> Exchanged for selected item.
;                  Failure - 0 with @error set to:
;                            1 -> Invalid exchange config.
;                            2 -> Exchange failed.
; Author.........: KleuTSchi
; Remarks........: - Uses simple thresholds for inventory/storage caps.
;                  - Emits status via AddOns_Out.
; Related........: AddOns_Out, BuyFromMerchant, BuyFromRareMaterialTrader, GUI_GUICtrlIsChecked, Item_DepositGold, 
;                  Item_GetInventoryInfo
; ===============================================================================================================================
Func GoldCheck($a_i_MapID)
    Local Const $LC_I_INV_THRESHOLD = 75000
    Local Const $LC_I_STG_THRESHOLD = 900000

    Local $l_i_InvGold = Item_GetInventoryInfo("GoldCharacter")
    If $l_i_InvGold < $LC_I_INV_THRESHOLD Then Return 0

    Local $l_i_StgGold = Item_GetInventoryInfo("GoldStorage")
    If $l_i_StgGold >= $LC_I_STG_THRESHOLD Then
        If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeEcto) Then
            AddOns_Out("[INFO] Exchanging Gold for Globs of Ectoplasm")
            If BuyFromRareMaterialTrader($a_i_MapID, $GC_AI_MODELIDS_EXCHANGE_GOLD[0]) Then Return 2
        ElseIf GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeObby) Then
            AddOns_Out("[INFO] Exchanging Gold for Obsidian Shards")
            If BuyFromRareMaterialTrader($a_i_MapID, $GC_AI_MODELIDS_EXCHANGE_GOLD[1]) Then Return 2
        ElseIf GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeLP) Then
            AddOns_Out("[INFO] Exchanging Gold for Lockpicks")
			Local $l_i_Qty = Int($l_i_InvGold / 1500)
            If BuyFromMerchant($a_i_MapID, $GC_AI_MODELIDS_EXCHANGE_GOLD[2], $l_i_Qty) Then Return 2
        Else
            AddOns_Out("[ERR] Invalid item for Gold exchange")
            Return SetError(1, 0, 0)
        EndIf
    Else
        AddOns_Out("[INFO] Depositing Gold")
        Item_DepositGold()
        Return 1
    EndIf

	Return SetError(2, 0, 0)
EndFunc   ;==>GoldCheck

; #FUNCTION# ====================================================================================================================
; Name...........: Inventory
; Description....: Performs inventory maintenance (identify/sell) and handles travel.
; Syntax.........: Inventory ( [$a_b_CleanUpInventory = False] )
; Parameters.....: $a_b_CleanUpInventory - Boolean : Force cleanup sequence.
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> No empty slots in storage.
;                            2 -> Move to a Merchant failed.
; Author.........: KleuTSchi
; Remarks........: - Triggers when free slots ≤ $GC_I_EMPTY_SLOT_THRESHOLD or forced.
;                  - Keeps difficulty setting when returning from GH.
; Related........: AddOns_GetEmptyInventorySlotCount, AddOns_GetEmptyStorageSlotCount, AddOns_IdentifyInventory,
;                  AddOns_RndTravel, AddOns_SellInventory, Ui_SetDifficulty, GoldCheck, Map_GetMapID, Map_TravelGH,
;                  Other_PingSleep, Pathing_GoChest, Pathing_GoMerchant, UseBag
; ===============================================================================================================================
Func Inventory($a_b_CleanUpInventory = False)
	Local $l_i_EmptyInvSlots = AddOns_GetEmptyInventorySlotCount()
    Local $l_b_NeedsCleanUp = ($a_b_CleanUpInventory Or $l_i_EmptyInvSlots <= $GC_I_EMPTY_SLOT_THRESHOLD)
    If Not $l_b_NeedsCleanUp Then Return True

    If Not $a_b_CleanUpInventory Then
        Local $l_i_EmptyStgSlots = AddOns_GetEmptyStorageSlotCount()
        If $l_i_EmptyStgSlots <= 0 Then
            $g_b_PauseRequested = True
            AddOns_Out("[WARN] Not enough empty slots available")
            Return SetError(1, 0, False)
		ElseIf $l_i_EmptyStgSlots <= 10 Then
			AddOns_Out("[WARN] Low storage slot count, " & $l_i_EmptyStgSlots & " empty slots remain")
        EndIf
    EndIf

	Local $l_i_MapID_Inventory

	If $g_b_TravelGH Then 
		If Not Map_TravelGH() Then Return SetError(2, 0, False)
		$l_i_MapID_Inventory = Map_GetMapID()
	Else
		$l_i_MapID_Inventory = Map_GetMapID()
		If $l_i_MapID_Inventory <> $GC_I_MAP_ID_OUTPOST And $l_i_MapID_Inventory <> $GC_I_MAP_ID_OUTPOST_EVENT Then
			If Not AddOns_RndTravel($GC_I_MAP_ID_OUTPOST) Then Return SetError(2, 0, False)
			$l_i_MapID_Inventory = $GC_I_MAP_ID_OUTPOST
		EndIf
	EndIf

	GoldCheck($l_i_MapID_Inventory)

	If Not Pathing_GoMerchant($l_i_MapID_Inventory) Then Return SetError(3, 0, False)

	Local $l_ab_Bags = [UseBag(1), UseBag(2), UseBag(3), UseBag(4)]

	AddOns_Out("[INFO] Identifying items in inventory")
	AddOns_IdentifyInventory($l_ab_Bags[0], $l_ab_Bags[1], $l_ab_Bags[2], $l_ab_Bags[3])

	AddOns_Out("[INFO] Selling items in inventory")
	AddOns_SellInventory($l_ab_Bags[0], $l_ab_Bags[1], $l_ab_Bags[2], $l_ab_Bags[3])

	DepositItems($l_ab_Bags[0], $l_ab_Bags[1], $l_ab_Bags[2], $l_ab_Bags[3])

	GUI_UpdateStatistics()

	Other_PingSleep(500)

	If $a_b_CleanUpInventory Then
		Pathing_GoChest($l_i_MapID_Inventory)
	ElseIf $g_b_TravelGH Then
		If Not AddOns_RndTravel($GC_I_MAP_ID_OUTPOST) Then Return SetError(4, 0, False)
		Ui_SetDifficulty($g_b_HardMode)
	EndIf
EndFunc   ;==>Inventory
#EndRegion Inventory

#Region RewardExchange
; #FUNCTION# ====================================================================================================================
; Name...........: ExchangeRewards
; Description....: Balances IGRO and MC for a target amount, converts MC → IGRO as needed, then exchanges IGRO for the selected reward.
;                  Deposits rewards and updates MC-equivalent counters.
; Syntax.........: ExchangeRewards ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Incorrect amount of MC have been tracked
;                            2 -> Pathing_GoExchangeMC failed
;                            3 -> IGRO inventory < GC_I_EXCHANGE_AMOUNT / GC_I_EXCHANGE_REQ after MC conversions
;                            4 -> Pathing_GoExchangeIGRO failed
;                            5 -> No valid exchange option selected
; Author.........: KleuTSchi
; Remarks........: - Computes planned IGRO usage from GC_I_EXCHANGE_AMOUNT / GC_I_EXCHANGE_REQ; withdraws MC/IGRO
;                    from storage only as needed.
;                  - Requires being in an outpost; travels there if not.
;                  - Repeats Merchant_CollectorExchange calls until the NPC declines; waits are ping-adjusted.
;                  - Enforces a minimum IGRO buffer (≥750) before the reward exchange step.
;                  - Finalizes by depositing rewards and recalculating $g_i_Count_MinisterialCommendation as
;                    MC + IGRO * GC_I_EXCHANGE_REQ.
; Related........: AddOns_DepositItemsToStorage, AddOns_GetInventoryItemCountbyModelID, AddOns_GetStorageItemCountbyModelID,
;                  AddOns_GetTotalItemCountbyModelID, AddOns_Out, AddOns_RndTravel, AddOns_WithdrawItemsFromStorage,
;                  GUI_GUICtrlIsChecked, Map_GetMapID, Merchant_CollectorExchange, Other_GetPing, Pathing_GoExchangeIGRO,
;                  Pathing_GoExchangeMC
; ===============================================================================================================================
Func ExchangeRewards()
	Local $l_i_InventoryIGRO = AddOns_GetInventoryItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER)
	Local $l_i_StorageIGRO = AddOns_GetStorageItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER)

	Local $l_i_TotalIGRO = $l_i_InventoryIGRO + $l_i_StorageIGRO

	Local $l_i_PlanUseIGRO = Ceiling($GC_I_EXCHANGE_AMOUNT / $GC_I_EXCHANGE_REQ)
	If $l_i_PlanUseIGRO > $l_i_TotalIGRO Then $l_i_PlanUseIGRO = $l_i_TotalIGRO

	Local $l_i_MissingIGRO = $l_i_PlanUseIGRO - $l_i_InventoryIGRO
	If $l_i_MissingIGRO < 0 Then $l_i_MissingIGRO = 0
	If $l_i_MissingIGRO > $l_i_StorageIGRO Then $l_i_MissingIGRO = $l_i_StorageIGRO
	If $l_i_MissingIGRO > 0 Then
		AddOns_WithdrawItemsFromStorage($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER, -1, $l_i_MissingIGRO)
	EndIf

	Local $l_i_RequiredMC = $GC_I_EXCHANGE_AMOUNT - ($l_i_PlanUseIGRO * $GC_I_EXCHANGE_REQ)
	If $l_i_RequiredMC < 0 Then $l_i_RequiredMC = 0

	Local $l_i_InventoryMC = AddOns_GetInventoryItemCountbyModelID($GC_I_MODELID_MINISTERIAL_COMMENDATION)
	Local $l_i_StorageMC = AddOns_GetStorageItemCountbyModelID($GC_I_MODELID_MINISTERIAL_COMMENDATION)

	Local $l_i_MissingMC = $l_i_RequiredMC - $l_i_InventoryMC
	If $l_i_MissingMC < 0 Then $l_i_MissingMC = 0
	If $l_i_MissingMC > $l_i_StorageMC Then 
		$g_i_Count_MinisterialCommendation = AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_MINISTERIAL_COMMENDATION)
		$g_i_Count_MinisterialCommendation += (AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER) * $GC_I_EXCHANGE_REQ)
		Return SetError(1, 0, False)
	EndIf
	If $l_i_MissingMC > 0 Then
		AddOns_WithdrawItemsFromStorage($GC_I_MODELID_MINISTERIAL_COMMENDATION, -1, $l_i_MissingMC)
	EndIf

	Local $l_i_Map = Map_GetMapID()
	If $l_i_Map <> $GC_I_MAP_ID_OUTPOST And $l_i_Map <> $GC_I_MAP_ID_OUTPOST_EVENT Then AddOns_RndTravel($GC_I_MAP_ID_OUTPOST)

	If Not Pathing_GoExchangeMC($GC_I_MAP_ID_OUTPOST) Then Return SetError(2, 0, False)

	Local $l_i_Ping = Other_GetPing()
	Local $l_b_MCSuccess = False
	If $l_i_RequiredMC > 0 Then
		Do 
			$l_b_MCSuccess = Merchant_CollectorExchange($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER, $GC_I_EXCHANGE_REQ, $GC_I_MODELID_MINISTERIAL_COMMENDATION)
			Sleep(50 + $l_i_Ping)
		Until Not $l_b_MCSuccess
	EndIf

	Sleep(250 + $l_i_Ping)
	
	If AddOns_GetInventoryItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER) < Ceiling($GC_I_EXCHANGE_AMOUNT / $GC_I_EXCHANGE_REQ) Then 
		Return SetError(3, 0, False)
	EndIf

	If Not Pathing_GoExchangeIGRO($GC_I_MAP_ID_OUTPOST) Then Return SetError(4, 0, False)

	Local $l_b_IGROSuccess = False
	If GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeGuard) Then
        AddOns_Out("[INFO] Exchanging Imperial Guard Requisition Orders for Imperial Guard Reinforcement Orders")
		Do 
			$l_b_IGROSuccess = Merchant_CollectorExchange($GC_AI_MODELIDS_EXCHANGE_MC[0], $GC_I_EXCHANGE_REQ, $GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER)
			Sleep(50 + $l_i_Ping)
		Until Not $l_b_IGROSuccess
    ElseIf GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeSeal) Then
        AddOns_Out("[INFO] Exchanging Imperial Guard Requisition Orders for Seals of the Dragon Empire")
		Do 
			$l_b_IGROSuccess = Merchant_CollectorExchange($GC_AI_MODELIDS_EXCHANGE_MC[1], $GC_I_EXCHANGE_REQ, $GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER)
			Sleep(50 + $l_i_Ping)
		Until Not $l_b_IGROSuccess
    ElseIf GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_ExchangeLockbox) Then
        AddOns_Out("[INFO] Exchanging Imperial Guard Requisition Orders for Imperial Guard Lockboxes")
		Do 
			$l_b_IGROSuccess = Merchant_CollectorExchange($GC_AI_MODELIDS_EXCHANGE_MC[2], $GC_I_EXCHANGE_REQ, $GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER)
			Sleep(50 + $l_i_Ping)
		Until Not $l_b_IGROSuccess
    Else
        AddOns_Out("[ERR] Invalid item for Ministerial Commendation exchange")
        Return SetError(5, 0, False)
    EndIf

	AddOns_WithdrawItemsFromStorage($GC_I_MODELID_MINISTERIAL_COMMENDATION, -1, -1, 2)
	For $i = 0 To UBound($GC_AI_MODELIDS_EXCHANGE_MC) -1
		AddOns_DepositItemsToStorage($GC_AI_MODELIDS_EXCHANGE_MC[$i])
	Next

	$g_i_Count_MinisterialCommendation = AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_MINISTERIAL_COMMENDATION)
	$g_i_Count_MinisterialCommendation += (AddOns_GetTotalItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_REQUISITION_ORDER) * $GC_I_EXCHANGE_REQ)

	Return True
EndFunc   ;==>ExchangeRewards
#EndRegion RewardExchange

#Region QuestEntry
; #FUNCTION# ====================================================================================================================
; Name...........: PrepareHeroSkillbarsForQuest
; Description....: Toggles selected hero skills before picking up a quest.
; Syntax.........: PrepareHeroSkillbarsForQuest ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Ping-aware pacing for skill toggles.
;                  - Hero 1: disable skills 6..8.
;                  - Hero 2: disable 6, enable 7, disable 8.
;                  - Hero 3: disable skills 1..7.
;                  - Hero 5: disable 1..3; enable 4..8.
;                  - Hero 6: disable 1, 2, 7, 8.
;                  - Hero 7: enable 1; disable 2..8.
;                  - Hero 4 is intentionally untouched.
; Related........: AddOns_SetHeroSkillState, EnterQuest, Other_GetPing
; ===============================================================================================================================
Func PrepareHeroSkillbarsForQuest()
    Local $l_i_Ping = Other_GetPing()

    ; Hero 1
	For $skill = 6 To 8
		AddOns_SetHeroSkillState(False, 1, $skill, $l_i_Ping)
	Next

    ; Hero 2
    AddOns_SetHeroSkillState(False, 2, 6, $l_i_Ping)
    AddOns_SetHeroSkillState(True, 2, 7, $l_i_Ping)
    AddOns_SetHeroSkillState(False, 2, 8, $l_i_Ping)

    ; Hero 3
    For $skill = 1 To 7
        AddOns_SetHeroSkillState(False, 3, $skill, $l_i_Ping)
    Next

    ; Hero 5
	For $skill = 1 To 3
        AddOns_SetHeroSkillState(False, 5, $skill, $l_i_Ping)
    Next
    For $skill = 4 To 8
        AddOns_SetHeroSkillState(True, 5, $skill, $l_i_Ping)
    Next

    ; Hero 6
    AddOns_SetHeroSkillState(False, 6, 1, $l_i_Ping)
	AddOns_SetHeroSkillState(False, 6, 2, $l_i_Ping)
    AddOns_SetHeroSkillState(False, 6, 7, $l_i_Ping)
    AddOns_SetHeroSkillState(False, 6, 8, $l_i_Ping)

    ; Hero 7
    AddOns_SetHeroSkillState(True, 7, 1, $l_i_Ping)
    For $skill = 2 To 8
        AddOns_SetHeroSkillState(False, 7, $skill, $l_i_Ping)
    Next
EndFunc   ;==>PrepareHeroSkillbarsForQuest

; #FUNCTION# ====================================================================================================================
; Name...........: EnterQuest
; Description....: Prepares hero skillbars, moves to Herald, and triggers the quest dialog. Disables rendering checkbox during load.
; Syntax.........: EnterQuest ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Move to the Herald failed.
; Author.........: KleuTSchi, ZupaBlahq
; Remarks........: - Dialog ID is fixed (0x84); caller should ensure correct quest context.
; Related........: AddOns_DialogLoad, Pathing_GoHerald, PrepareHeroSkillbarsForQuest
; ===============================================================================================================================
Func EnterQuest()
	PrepareHeroSkillbarsForQuest()
	If Not Pathing_GoHerald($GC_I_MAP_ID_OUTPOST) Then Return SetError(1, 0, False)

	GUICtrlSetState($g_i_CtrlID_CBX_Rendering, $GUI_DISABLE)
	Local $l_b_DialogRet = AddOns_DialogLoad(0x84)
	GUICtrlSetState($g_i_CtrlID_CBX_Rendering, $GUI_ENABLE)

	Return $l_b_DialogRet
EndFunc   ;==>EnterQuest
#EndRegion QuestEntry

#Region FightPreparation
; #FUNCTION# ====================================================================================================================
; Name...........: PrepareHeroSkillbarsForFight
; Description....: Enables the subset of hero skills needed for the opening fight.
; Syntax.........: PrepareHeroSkillbarsForFight ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Only touches listed slots; leaves others unchanged.
;                  - Hero 2: enable skill 7.
;                  - Hero 3: enable skills 1 through 7.
;                  - Hero 4: enable skills 1 and 6.
;                  - Hero 6: enable skills 7 and 8.
;                  - Hero 7: enable skills 2 through 7.
; Related........: AddOns_SetHeroSkillState, Other_GetPing, PrepareToFight
; ===============================================================================================================================
Func PrepareHeroSkillbarsForFight()
	Local $l_i_Ping = Other_GetPing()

	; Hero 2
	AddOns_SetHeroSkillState(True, 2, 7, $l_i_Ping)

	; Hero 3
	For $skill = 1 To 7
		AddOns_SetHeroSkillState(True, 3, $skill, $l_i_Ping)
	Next

	; Hero 4
	AddOns_SetHeroSkillState(True, 4, 1, $l_i_Ping)
	AddOns_SetHeroSkillState(True, 4, 6, $l_i_Ping)

	; Hero 6
	AddOns_SetHeroSkillState(True, 6, 7, $l_i_Ping)
	AddOns_SetHeroSkillState(True, 6, 8, $l_i_Ping)

	; Hero 7
	For $skill = 2 To 7
		AddOns_SetHeroSkillState(True, 7, $skill, $l_i_Ping)
	Next
EndFunc   ;==>PrepareHeroSkillbarsForFight

; #FUNCTION# ====================================================================================================================
; Name...........: CommandStartingPositions
; Description....: Issues initial movement commands to place each hero at their designated starting coordinates.
; Syntax.........: CommandStartingPositions ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Hard-coded coordinates tuned for the specific map layout.
;                  - Assumes player is in the correct map instance and heroes are present in party.
; Related........: Ui_CommandHero, PrepareToFight
; ===============================================================================================================================
Func CommandStartingPositions()
	Ui_CommandHero(1, -6362, -4967)
	Ui_CommandHero(2, -6060, -5168)
	Ui_CommandHero(3, -6245, -5232)
	Ui_CommandHero(4, -6362, -4967)
	Ui_CommandHero(5, -5691, -5195)
	Ui_CommandHero(6, -5606, -4747)
	Ui_CommandHero(7, -5452, -4380)
EndFunc    ;==>CommandStartingPositions

; #FUNCTION# ====================================================================================================================
; Name...........: PrepareToFight
; Description....: Executes the pre-pull routine for the first encounter: buffs, trap setups at multiple spots, spirit placement, 
;                  hero positioning, and player opening burst.
; Syntax.........: PrepareToFight ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Uses latency-aware waits to avoid interrupting long casts.
; Related........: AddOns_GetIsCasting, AddOns_GetIsMoving, AddOns_GetIsQueued, AddOns_MoveTo,
;                  AddOns_UseSkillEx, Skill_UseHeroSkill, Ui_CommandHero, Ui_SetHeroBehavior, Agent_GetAgentInfo,
;                  CommandStartingPositions, PrepareHeroSkillbarsForFight, TimerDiff, TimerInit
; ===============================================================================================================================
Func PrepareToFight()
	AddOns_UpdatePartyPtrs()

	Skill_UseHeroSkill(2, 6) ; Earth Ele - "Fall Back!"
	CommandStartingPositions()
	AddOns_MoveTo(-6232, -5392)
	Ui_SetHeroBehavior(5, 1) ; SoS - Fight

	; First Trapper spot
	Skill_UseHeroSkill(3, 7) ; Trapper - Serpent's Quickness
	Sleep(500)
	Skill_UseHeroSkill(3, 3) ; Trapper - Dust Trap
	Skill_UseHeroSkill(5, 1) ; SoS - SoS
	Skill_UseHeroSkill(6, 1, $GC_I_HERO_ID_3) ; BiP Resto - BiP - Trapper
	Sleep(2500)
	Skill_UseHeroSkill(3, 1) ; Trapper - Spike Trap
	Skill_UseHeroSkill(5, 6) ; SoS - Agony
	Skill_UseHeroSkill(6, 1, $GC_I_HERO_ID_5) ; BiP Resto - BiP - SoS
	Sleep(2500)
	Skill_UseHeroSkill(3, 2) ; Trapper - Flame Trap
	Skill_UseHeroSkill(6, 7) ; BiP Resto - Kaolai
	Sleep(2500)
	Skill_UseHeroSkill(3, 6) ; Trapper - Destruction
	Skill_UseHeroSkill(5, 8) ; SoS - Rejuvenation
	Sleep(1250)

	$l_h_Timeout = TimerInit()
	While (AddOns_GetIsCasting($g_p_Hero_3) Or AddOns_GetIsQueued(3)) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	; Second Trapper spot
	Ui_CommandHero(1, -6517, -5129) ; Fire Ele - Move to corner for initial burst
	Ui_CommandHero(3, -6311, -5635) ; Trapper - Move to 2nd spot for traps
	Sleep(1500)

	$l_h_Timeout = TimerInit()
	While AddOns_GetIsMoving($g_p_Hero_3) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	Skill_UseHeroSkill(3, 4) ; Trapper - Barbed Trap
	Sleep(2500)
	Skill_UseHeroSkill(3, 5) ; Trapper - Piercing Trap
	Skill_UseHeroSkill(7, 5) ; ST Rit - Boon of Creation
	Sleep(2500)
	Skill_UseHeroSkill(3, 1) ; Trapper - Spike Trap
	Skill_UseHeroSkill(7, 4) ; ST Rit - Displacement
	Sleep(2500)

	$l_h_Timeout = TimerInit()
	While (AddOns_GetIsCasting($g_p_Hero_3) Or AddOns_GetIsQueued(3)) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	; Third Trapper spot
	Ui_CommandHero(1, -6480, -5258) ; Fire Ele - Move to corner for initial burst
	Ui_CommandHero(3, -6503, -5937) ; Trapper - Move to 3rd spot for traps
	Skill_UseHeroSkill(6, 2) ; BiP Resto - Recovery
	Skill_UseHeroSkill(7, 1) ; ST Rit - Soul Twisting
	Sleep(1500)

	$l_h_Timeout = TimerInit()
	While AddOns_GetIsMoving($g_p_Hero_3) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	Skill_UseHeroSkill(3, 2) ; Trapper - Flame Trap
	Skill_UseHeroSkill(6, 8) ; BiP Resto - Life
	Skill_UseHeroSkill(7, 2) ; ST Rit - Shelter
	Sleep(2500)
	Skill_UseHeroSkill(3, 3) ; Trapper - Dust Trap
	Skill_UseHeroSkill(7, 3) ; ST Rit - Union
	Sleep(1250)
	Skill_UseHeroSkill(5, 2, $GC_I_MIKU_ID) ; SoS - Splinter Weapon - Miku
	Skill_UseHeroSkill(6, 1, $GC_I_HERO_ID_5) ; BiP Resto - BiP - SoS
	Sleep(1500)
	Skill_UseHeroSkill(1, 6) ; Fire Ele - Fire Attunement
	Skill_UseHeroSkill(2, 8) ; Earth Ele - Earth Attunement
	Skill_UseHeroSkill(7, 6) ; ST Rit - Earthbind

	$l_h_Timeout = TimerInit()
	While (AddOns_GetIsCasting($g_p_Hero_3) Or AddOns_GetIsQueued(3)) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	; Back to Second Trapper spot
	Ui_CommandHero(3, -6311, -5635)
	Ui_CommandHero(6, -5795, -4942)
	Sleep(1000)

	$l_h_Timeout = TimerInit()
	While AddOns_GetIsMoving($g_p_Hero_3) And TimerDiff($l_h_Timeout) < 3000
		Sleep(100)
	WEnd

	AddOns_UseSkillEx(1) ; Player - Dwarven Stability
	Skill_UseHeroSkill(1, 7) ; Fire Ele - Glyph of Sacrifice
	Skill_UseHeroSkill(3, 4) ; Trapper - Barbed Trap
	Skill_UseHeroSkill(5, 7) ; SoS - Recuperation
	Skill_UseHeroSkill(6, 1, $GC_I_HERO_ID_3) ; BiP Resto - BiP - Trapper
	Skill_UseHeroSkill(7, 7) ; ST Rit - Armor of Unfeeling
	Sleep(1500)
	Ui_CommandHero(5, -5984, -5524)
	AddOns_UseSkillEx(7) ; Player - Honor
	AddOns_MoveTo(-6306, -5260)
	Skill_UseHeroSkill(1, 8, 198) ; Fire Ele - Meteorshower , 199
	Skill_UseHeroSkill(3, 1) ; Trapper - Spike Trap
	Skill_UseHeroSkill(5, 2, $GC_I_PLAYER_ID) ; SoS - Splinter Weapon - Miku
	Skill_UseHeroSkill(7, 8, $GC_I_PLAYER_ID) ; ST Rit - Inspirational Speech

	PrepareHeroSkillbarsForFight()

	$l_h_Timeout = TimerInit()

	Do
		Sleep (100)
	Until TimerDiff($l_h_Timeout) > 7500 Or Agent_GetAgentInfo(63, "Allegiance") = 0x3

	AddOns_UseSkillEx(2) ; Player - 100B
	AddOns_UseSkillEx(3) ; Player - "To the Limit!"
	Sleep(100)
	AddOns_UseSkillEx(4, AddOns_GetNearestAgent_EnemyLiving_NoSM($g_p_Player))
EndFunc   ;==>PrepareToFight
#EndRegion FightPreparation

#Region Fight
; #FUNCTION# ====================================================================================================================
; Name...........: PrepareHeroSkillbarsForJourney
; Description....: Disables all skills for heroes 5 and 7 before movement phase.
; Syntax.........: PrepareHeroSkillbarsForJourney ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Prevents unwanted casts during long moves.
; Related........: AddOns_SetHeroSkillState, Other_GetPing, Fight
; ===============================================================================================================================
Func PrepareHeroSkillbarsForJourney()
	Local $l_i_Ping = Other_GetPing()

	; Hero 5
	For $skill = 1 To 8
		AddOns_SetHeroSkillState(False, 5, $skill, $l_i_Ping)
	Next

	; Hero 7
	For $skill = 1 To 8
		AddOns_SetHeroSkillState(False, 7, $skill, $l_i_Ping)
	Next

	$g_b_JourneyReady = True
EndFunc   ;==>PrepareHeroSkillbarsForJourney

; #FUNCTION# ====================================================================================================================
; Name...........: MoveToSafeSpot
; Description....: Moves the player to a safe position near the starting area, using current coordinates and distance checks
;                  to choose an intermediate waypoint to avoid getting stuck.
; Syntax.........: MoveToSafeSpot ( )
; Parameters.....: None
; Return values..: None (procedure; returns early if position read fails)
; Author.........: KleuTSchi
; Remarks........: - Uses squared distances for cheap proximity checks.
; Related........: AddOns_ComputePseudoDistance, AddOns_GetXY_, AddOns_MoveTo, Agent_CancelAction, Map_Move, Speedboost
; ===============================================================================================================================
Func MoveToSafeSpot()
	Agent_CancelAction()
	Sleep(250)

    Local $LC_I_DISTANCE_THRESHOLD = 600 * 600
    Local $l_af_Coords = AddOns_GetXY_()
	If @error Or $l_af_Coords = 0 Then Return

	Local $l_f_PosX = $l_af_Coords[0], $l_f_PosY = $l_af_Coords[1]

	Speedboost()
	If AddOns_ComputePseudoDistance($l_f_PosX, $l_f_PosY, -7364, -5803) < $LC_I_DISTANCE_THRESHOLD Then
		AddOns_MoveTo(-6845, -5618)
	ElseIf AddOns_ComputePseudoDistance($l_f_PosX, $l_f_PosY, -6834, -6471) < $LC_I_DISTANCE_THRESHOLD Then
		AddOns_MoveTo(-6433, -6095)
	EndIf
	Map_Move(-6080, -5020, 0)
EndFunc   ;==>MoveToSafeSpot

; #FUNCTION# ====================================================================================================================
; Name...........: LockBacklineTarget
; Description....: Scans a list of foes, identifies a valid backline (ranged/caster) target, and locks heroes 1-3 onto it.
; Syntax.........: LockBacklineTarget ( $a_ap_Foes )
; Parameters.....: $a_ap_Foes - Array : Countless list of foe pointers; 0 entries are ignored.
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Reads effects and weaponType via ReadProcessMemory; reuses a static DllStruct for speed.
;                  - Skips dead foes; requires weaponType ≥ 8 (ranged/caster heuristic).
;                  - Locks the first qualifying foe for heroes 1..3 and stops; no error reporting.
; Related........: Ui_LockHeroTarget, BitAND, DllCall, DllStructCreate, DllStructGetData, DllStructGetSize
; ===============================================================================================================================
Func LockBacklineTarget($a_ap_Foes)
	Local Const $GC_I_OFFSET_AGENT_EFFECTS = 0x138
	Local Const $GC_I_OFFSET_AGENT_WEAPON_TYPE = 0x1B2

	Static $l_d_AgentStruct = DllStructCreate( _
		"byte[" & $GC_I_OFFSET_AGENT_EFFECTS  & "];dword effects;" & _
		"byte[" & ($GC_I_OFFSET_AGENT_WEAPON_TYPE - ($GC_I_OFFSET_AGENT_EFFECTS + 4)) & "];short weaponType" _
	)
	Static $l_i_AgentStructSize = DllStructGetSize($l_d_AgentStruct)
	
	For $foe In $a_ap_Foes
		If $foe = 0 Then ContinueLoop
			
		DllCall($g_h_Kernel32, "bool", "ReadProcessMemory", _
			"handle", $g_h_GWProcess, _
			"ptr", $foe, _
			"struct*", $l_d_AgentStruct, _
			"ulong_ptr", $l_i_AgentStructSize, _
			"ulong_ptr*", 0 _
		)

		Local $l_i_Effects = DllStructGetData($l_d_AgentStruct, "effects")
		Local $l_i_WeaponType = DllStructGetData($l_d_AgentStruct, "weaponType")

		If Not (BitAND($l_i_Effects, 0x10) > 0) And $l_i_WeaponType >= 8 Then
			Ui_LockHeroTarget(1, $foe)
			Ui_LockHeroTarget(2, $foe)
			Ui_LockHeroTarget(3, $foe)
			ExitLoop
		EndIf
	Next
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: WeaponSupport
; Description....: Maintains Splinter Weapon on prioritized allies.
; Syntax.........: WeaponSupport ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Skips dead targets and targets that already have a weapon spell applied to them.
; Related........: AddOns_GetIsRecharged, AddOns_GetQueuedSkill, Memory_Read, Skill_UseHeroSkill
; ===============================================================================================================================
Func WeaponSupport()
	Local $l_i_QueuedSkill_SoS = AddOns_GetQueuedSkill(5)
	If $l_i_QueuedSkill_SoS = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_SoS, 5) Then
		If ($l_i_QueuedSkill_SoS <> 2) And AddOns_GetIsRecharged(2, 5) Then
			Local $l_ai_Priority = [ _
				[$GC_I_MIKU_ID, $g_p_Miku], _
				[$GC_I_PLAYER_ID, $g_p_Player], _
				[$GC_I_HERO_ID_3, $g_p_Hero_3] _
			]
			For $i = 0 To UBound($l_ai_Priority, $UBOUND_ROWS) - 1
				If $i = 1 And Not $g_b_PlayerAssistance Then ContinueLoop
				Local $l_i_Effect = Memory_Read($l_ai_Priority[$i][1] + $GC_I_OFFSET_AGENT_EFFECTS, "dword")
				If Not (BitAND($l_i_Effect, 0x8010) > 0) Then
					Skill_UseHeroSkill(5, 2, $l_ai_Priority[$i][0])
					ExitLoop
				EndIf
			Next
		EndIf
	EndIf
EndFunc   ;==>WeaponSupport

; #FUNCTION# ====================================================================================================================
; Name...........: ManagePartyEnergy
; Description....: Uses BiP on a selected ally when energy is below threshold.
; Syntax.........: ManagePartyEnergy ( $a_i_BiPDelayIndex )
; Parameters.....: $a_i_BiPDelayIndex - Integer : Target index (1..N).
; Return values..: True  - BiP used.
;                  False - No action.
; Author.........: KleuTSchi
; Remarks........: - Reads agent energy/effects directly; avoids casting if flagged.
; Related........: Skill_UseHeroSkill, DllCall
; ===============================================================================================================================
Func ManagePartyEnergy($a_i_BiPDelayIndex)
    Static $s_d_AgentStruct = DllStructCreate( _
        "byte[" & $GC_I_OFFSET_AGENT_ENERGY_PERCENT & "];float energyPercent;" & _
        "byte[" & ($GC_I_OFFSET_AGENT_EFFECTS - ($GC_I_OFFSET_AGENT_ENERGY_PERCENT + 4)) & "];dword effects" _
    )
    Static $s_i_AgentStructSize = DllStructGetSize($s_d_AgentStruct)

	Local $l_av2_Heroes[][] = [ _
		[$g_p_Hero_4, $GC_I_HERO_ID_4], _
		[$g_p_Hero_5, $GC_I_HERO_ID_4], _
		[$g_p_Hero_2, $GC_I_HERO_ID_5], _
		[$g_p_Hero_1, $GC_I_HERO_ID_1], _
		[$g_p_Hero_3, $GC_I_HERO_ID_3] _
	]

	Local $l_i_HeroIdx = $a_i_BiPDelayIndex - 1
    Local $l_p_Hero = $l_av2_Heroes[$l_i_HeroIdx][0]
    Local $l_i_HeroID = $l_av2_Heroes[$l_i_HeroIdx][1]
	Local $l_f_EnergyThreshold = 0.6

    DllCall( _
        $g_h_Kernel32, "bool", "ReadProcessMemory", _
        "handle", $g_h_GWProcess, _
        "ptr", $l_p_Hero, _
        "struct*", $s_d_AgentStruct, _
        "ulong_ptr", $s_i_AgentStructSize, _
        "ulong_ptr*", 0 _
    )

	Local $l_i_Effects = DllStructGetData($s_d_AgentStruct, "effects")
	If BitAND($l_i_Effects, 0x10) > 0 Then Return False

    Local $l_f_EnergyPercent = DllStructGetData($s_d_AgentStruct, "energyPercent")
	If $l_f_EnergyPercent < $l_f_EnergyThreshold Then
        Skill_UseHeroSkill(6, 1, $l_i_HeroID)
        Return True
    EndIf

    Return False
EndFunc   ;==>ManagePartyEnergy

; #FUNCTION# ====================================================================================================================
; Name...........: BiPSupport
; Description....: Coordinates BiP usage with per-target cooldowns.
; Syntax.........: BiPSupport ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Skips active queue/recharge; respects $g_ai_BiPDelays windows.
; Related........: AddOns_GetHP, AddOns_GetIsRecharged, AddOns_GetQueuedSkill, ManagePartyEnergy
; ===============================================================================================================================
Func BiPSupport()
	If AddOns_GetHP($g_p_Hero_6) < 0.9 Then
	    For $hero = 1 To $GC_I_BIP_TARGETS
			If $g_ai_BiPDelays[$hero] > 0 Then
				$g_ai_BiPDelays[$hero] -= 1
			EndIf
		Next
	Else
		Local $l_i_QueuedSkill_BiP = AddOns_GetQueuedSkill(6)
		If $l_i_QueuedSkill_BiP = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_BiP, 6) Then
			Local $l_b_SkillUsed = False
			For $hero = 1 To $GC_I_BIP_TARGETS
				If $g_ai_BiPDelays[$hero] > 0 Then
					$g_ai_BiPDelays[$hero] -= 1
				Else
					If Not $l_b_SkillUsed And ManagePartyEnergy($hero) Then
						$g_ai_BiPDelays[$hero] = $GC_I_MAXIMUM_BIP_DELAY
						$l_b_SkillUsed = True
					EndIf
				EndIf
			Next
		EndIf
	EndIf
EndFunc   ;==>BiPSupport

; #FUNCTION# ====================================================================================================================
; Name...........: ResetBiPDelay
; Description....: Clears all BiP per-target delay counters.
; Syntax.........: ResetBiPDelay ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Initializes $g_ai_BiPDelays to zero.
; Related........: BiPSupport
; ===============================================================================================================================
Func ResetBiPDelay()
	For $hero = 1 To $GC_I_BIP_TARGETS
		$g_ai_BiPDelays[$hero] = 0
	Next
EndFunc   ;==>ResetBiPDelay

; #FUNCTION# ====================================================================================================================
; Name...........: SpiritSupport
; Description....: Maintains ST spirits, ensuring Shelter, Union, and Displacement are active when recharged and
;                  not already present.
; Syntax.........: SpiritSupport ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Casts one spirit per tick to reduce overlap and queue conflicts.
; Related........: AddOns_GetHasEffect, AddOns_GetIsQueued, AddOns_GetIsRecharged, Skill_UseHeroSkill
; ===============================================================================================================================
Func SpiritSupport()
	If Not AddOns_GetIsQueued(7) Then
		Local $l_ai2_Spirits = [ _
			[2, $GC_I_SKILL_ID_SHELTER], _ 
			[3, $GC_I_SKILL_ID_UNION], _
			[4, $GC_I_SKILL_ID_DISPLACEMENT] _
		]

		For $i = 0 To UBound($l_ai2_Spirits, $UBOUND_ROWS) - 1
			Local $l_i_Slot = $l_ai2_Spirits[$i][0]
			Local $l_i_Effect = $l_ai2_Spirits[$i][1]

			If AddOns_GetIsRecharged($l_i_Slot, 7) And Not AddOns_GetHasEffect($l_i_Effect, $g_p_Hero_7) Then
				Skill_UseHeroSkill(7, $l_i_Slot)
				ExitLoop
			EndIf
		Next
	EndIf
EndFunc   ;==>SpiritSupport

; #FUNCTION# ====================================================================================================================
; Name...........: ProtAndHealSupport
; Description....: Provides targeted protection and healing with simple priorities.
; Syntax.........: ProtAndHealSupport ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Respects queued skill and recharge; avoids duplicate buffs/effects.
; Related........: AddOns_GetHasEffect, AddOns_GetHP, AddOns_GetIsEnchanted, AddOns_GetIsRecharged, AddOns_GetQueuedSkill,
;                  Skill_UseHeroSkill
; ===============================================================================================================================
Func ProtAndHealSupport()
    ; Miku support
    If AddOns_GetHP($g_p_Miku) < 0.7 Then
        ; Martyr Mes - Spirit Bond if not already active
		Local $l_i_QueuedSkill_Martyr = AddOns_GetQueuedSkill(4)
		If $l_i_QueuedSkill_Martyr = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_Martyr, 4) Then
			If ($l_i_QueuedSkill_Martyr <> 7) And AddOns_GetIsRecharged(7, 4) And Not AddOns_GetIsEnchanted($g_p_Miku) Then
				Skill_UseHeroSkill(4, 7, $GC_I_MIKU_ID)
			EndIf
		EndIf
        ; SoS - Mend Body and Soul, Spirit Light
		Local $l_i_QueuedSkill_SoS = AddOns_GetQueuedSkill(5)
		If $l_i_QueuedSkill_SoS = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_SoS, 5) Then
			If ($l_i_QueuedSkill_SoS <> 5) And AddOns_GetIsRecharged(5, 5) Then
				Skill_UseHeroSkill(5, 5, $GC_I_MIKU_ID)
			EndIf
		EndIf
        ; BiP Resto - Spirit Light, MBaS, Transfer
		Local $l_i_QueuedSkill_BiP = AddOns_GetQueuedSkill(6)
		If $l_i_QueuedSkill_BiP = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_BiP, 6) Then
			If ($l_i_QueuedSkill_BiP <> 6) And AddOns_GetIsRecharged(6, 6) Then
				Skill_UseHeroSkill(6, 6, $GC_I_MIKU_ID)
			ElseIf ($l_i_QueuedSkill_BiP <> 5) And AddOns_GetIsRecharged(5, 6) Then
				Skill_UseHeroSkill(6, 5, $GC_I_MIKU_ID)
			ElseIf ($l_i_QueuedSkill_BiP <> 4) And AddOns_GetIsRecharged(4, 6) Then
				Skill_UseHeroSkill(6, 4, $GC_I_MIKU_ID)
			EndIf
		EndIf
	EndIf

    ; Party member support: Player, Fire Ele, SoS Resto
    Local $l_ap_PartyPtrs = [$g_p_Player, $g_p_Hero_1, $g_p_Hero_5]
    Local $l_ai_PartyIDs = [$GC_I_PLAYER_ID, $GC_I_HERO_ID_1, $GC_I_HERO_ID_5]
    Local $l_f_HPThreshold = 0.6

    For $i = 0 To 2
        Local $l_p_Agent = $l_ap_PartyPtrs[$i]
		Local $l_i_HP = AddOns_GetHP($l_p_Agent)
        If $l_i_HP < $l_f_HPThreshold And $l_i_HP > 0 Then
			; Martyr Mes - Spirit Bond if not already active
			Local $l_i_QueuedSkill_Martyr = AddOns_GetQueuedSkill(4)
			If $l_i_QueuedSkill_Martyr = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_Martyr, 4) Then
				If ($l_i_QueuedSkill_Martyr <> 7) And AddOns_GetIsRecharged(7, 4) And Not AddOns_GetHasEffect($GC_I_SKILL_ID_SPIRIT_BOND, $l_p_Agent) Then
					Skill_UseHeroSkill(4, 7, $l_ai_PartyIDs[$i])
				EndIf
			EndIf
			; SoS - Mend Body and Soul, Spirit Light
			Local $l_i_QueuedSkill_SoS = AddOns_GetQueuedSkill(5)
			If $l_i_QueuedSkill_SoS = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_SoS, 5) Then
				If ($l_i_QueuedSkill_SoS <> 5) And AddOns_GetIsRecharged(5, 5) Then
					Skill_UseHeroSkill(5, 5, $l_ai_PartyIDs[$i])
				EndIf
			EndIf
			; BiP Resto - Spirit Light, MBaS, Transfer
			Local $l_i_QueuedSkill_BiP = AddOns_GetQueuedSkill(6)
			If $l_i_QueuedSkill_BiP = 0 Or Not AddOns_GetIsRecharged($l_i_QueuedSkill_BiP, 6) Then
				If ($l_i_QueuedSkill_BiP <> 6) And AddOns_GetIsRecharged(6, 6) Then
					Skill_UseHeroSkill(6, 6, $l_ai_PartyIDs[$i])
				ElseIf ($l_i_QueuedSkill_BiP <> 5) And AddOns_GetIsRecharged(5, 6) Then
					Skill_UseHeroSkill(6, 5, $l_ai_PartyIDs[$i])
				ElseIf ($l_i_QueuedSkill_BiP <> 4) And AddOns_GetIsRecharged(4, 6) Then
					Skill_UseHeroSkill(6, 4, $l_ai_PartyIDs[$i])
				EndIf
			EndIf
        EndIf
    Next
EndFunc   ;==>ProtAndHealSupport()

; #FUNCTION# ====================================================================================================================
; Name...........: SupportRoutine
; Description....: Periodic support tick combining protection/heals, ST spirit upkeep, BiP energy support, and Splinter
;                  Weapon casts.
; Syntax.........: SupportRoutine ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Intended for AdlibRegister usage around ~750 ms.
; Related........: BiPSupport, ProtAndHealSupport, SpiritSupport, WeaponSupport
; ===============================================================================================================================
Func SupportRoutine()
	ProtAndHealSupport()
	SpiritSupport()
	BiPSupport()
    WeaponSupport()
EndFunc   ;==>SupportRoutine()

; #FUNCTION# ====================================================================================================================
; Name...........: RefreshFoeCount
; Description....: Iterates $g_ap_Foes and returns the living count.
; Syntax.........: RefreshFoeCount ( )
; Parameters.....: None
; Return values..: Integer - Count of living foes.
; Author.........: KleuTSchi
; Remarks........: - Treats index 0 as capacity; prunes dead entries to 0.
; Related........: AddOns_GetIsDead
; ===============================================================================================================================
Func RefreshFoeCount()
    Local $l_i_Max = $g_ap_Foes[0]
    Local $l_p_Foe, $l_i_Count = 0

    For $i = 1 To $l_i_Max
        $l_p_Foe = $g_ap_Foes[$i]
        If $l_p_Foe = 0 Then ContinueLoop

        If AddOns_GetIsDead($l_p_Foe) Then
            $g_ap_Foes[$i] = 0
        Else
            $l_i_Count += 1
        EndIf
    Next
    Return $l_i_Count
EndFunc   ;==>RefreshFoeCount()

; #FUNCTION# ====================================================================================================================
; Name...........: Fight
; Description....: Coordinates the first fight: registers periodic support, selects targets, manages state-based behavior,
;                  repositions heroes, locks targets, handles timeouts, and transitions to the journey phase.
; Syntax.........: Fight ( )
; Parameters.....: None
; Return values..: None (procedure; may return early on timeout or stop condition)
; Author.........: KleuTSchi
; Remarks........: - Uses simple state machine (high/medium foe counts).
;                  - Frequent safety checks (CanContinue, timeouts).
; Related........: AddOns_GetHP, AddOns_GetIsDead, AddOns_GetNearestAgent_EnemyLiving_NoSM, AddOns_GetNumberOfAgent_EnemyLiving_NoSM,
;                  AddOns_GetPseudoDistanceToXY, AddOns_MoveTo, AddOns_Out, AddOns_UseSkillEx, Skill_UseHeroSkill, Ui_CancelHero,
;                  Ui_CommandHero, Ui_DisableHeroSkill, Ui_LockHeroTarget, Ui_SetHeroBehavior, AdlibRegister, AdlibUnRegister,
;                  Agent_CallTarget, Agent_GetAgentPtr, CanContinue, MoveToSafeSpot, PlayerAssistance, PlayerSustain,
;                  PrepareHeroSkillbarsForJourney, ResetBiPDelay, TimerDiff, TimerInit
; ===============================================================================================================================
Func Fight()
    $g_b_JourneyReady = False
	$g_b_PlayerAssistance = True

	Local Const $LC_I_FIGHT_TIMEOUT = 120000
	Local Const $LC_I_STATE_HIGH_FOE_COUNT = 0
	Local Const $LC_I_STATE_MEDIUM_FOE_COUNT = 1
    Local $l_i_State = $LC_I_STATE_HIGH_FOE_COUNT

	Local $l_i_RemainingFoes = 0
    Local $l_p_HeroTarget = 0, $l_p_PlayerTarget = 0
    Local $l_b_RenewedSoS = False, $l_b_HeroesRepositioned = False
	Local $l_b_MartyrDisabled = False
    Local $l_b_CanContinue = CanContinue()
	Local $l_b_TimedOut = False, $l_h_Timeout = TimerInit()

	Local Const $LC_I_DISTANCE_THRESHOLD_100 = 100 * 100
	Local Const $LC_I_DISTANCE_THRESHOLD_1750 = 1750 * 1750

    Local $l_ai2_RepositionCoords[][] = [ _
		[-6601, -5251], _ ; Hero 1 (unused)
		[-6174, -5601], _ ; Hero 2
		[-6718, -6037], _ ; Hero 3 (unused)
		[-6071, -5237], _ ; Hero 4
		[-6236, -5905], _ ; Hero 5
		[-6309, -5021], _ ; Hero 6
		[-5974, -4869] _ ; Hero 7
	]

	$g_p_Miku = Agent_GetAgentPtr($GC_I_MIKU_ID)

    Local $l_p_Foe1 = Agent_GetAgentPtr(62), $l_p_Foe2 = Agent_GetAgentPtr(63)
	Local $l_p_Foe3 = Agent_GetAgentPtr(193), $l_p_Foe4 = Agent_GetAgentPtr(194)
	Local $l_p_Foe5 = Agent_GetAgentPtr(195), $l_p_Foe6 = Agent_GetAgentPtr(196)
    Local $l_p_Foe7 = Agent_GetAgentPtr(197), $l_p_Foe8 = Agent_GetAgentPtr(198)
	Local $l_p_Foe9 = Agent_GetAgentPtr(199), $l_p_Foe10 = Agent_GetAgentPtr(200)

    Local $l_ap_FoesTemp[] = [10, _
		$l_p_Foe1, $l_p_Foe2, $l_p_Foe3, $l_p_Foe4, $l_p_Foe5, _
		$l_p_Foe6, $l_p_Foe7, $l_p_Foe8, $l_p_Foe9, $l_p_Foe10 _
	]
    $g_ap_Foes = $l_ap_FoesTemp
	Local $l_ap_BacklineFoes = [$l_p_Foe4, $l_p_Foe5, $l_p_Foe6]

    ResetBiPDelay()
	AdlibRegister("SupportRoutine", 750)

    Do
        $l_i_RemainingFoes = RefreshFoeCount()
		If $l_i_RemainingFoes <= 1 Then 
			AdlibUnRegister("SupportRoutine")
			ExitLoop
		EndIf

        If $l_i_RemainingFoes > 5 Then
            $l_i_State = $LC_I_STATE_HIGH_FOE_COUNT
        Else
            $l_i_State = $LC_I_STATE_MEDIUM_FOE_COUNT
        EndIf

        Switch $l_i_State
            Case $LC_I_STATE_HIGH_FOE_COUNT
				If AddOns_GetIsDead($l_p_PlayerTarget) Or $l_p_PlayerTarget = 0 Then
					$l_p_PlayerTarget = AddOns_GetNearestAgent_EnemyLiving_NoSM(-2, -1, True, -6306, -5260, $g_ap_Foes)
				EndIf			
				PlayerAssistance(True, $l_p_PlayerTarget)

            Case $LC_I_STATE_MEDIUM_FOE_COUNT
				If Not $l_b_HeroesRepositioned Then
					$l_b_HeroesRepositioned = True
					Ui_CommandHero(2, $l_ai2_RepositionCoords[1][0], $l_ai2_RepositionCoords[1][1])
					Ui_CommandHero(4, $l_ai2_RepositionCoords[3][0], $l_ai2_RepositionCoords[3][1])
					Ui_CommandHero(5, $l_ai2_RepositionCoords[4][0], $l_ai2_RepositionCoords[4][1])
					Ui_CommandHero(6, $l_ai2_RepositionCoords[5][0], $l_ai2_RepositionCoords[5][1])
					Ui_CommandHero(7, $l_ai2_RepositionCoords[6][0], $l_ai2_RepositionCoords[6][1])
				EndIf

				If Not $l_b_RenewedSoS And $l_b_HeroesRepositioned _
				And AddOns_GetPseudoDistanceToXY($l_ai2_RepositionCoords[4][0], $l_ai2_RepositionCoords[4][1], $g_p_Hero_5) <= $LC_I_DISTANCE_THRESHOLD_100 Then
					$l_b_RenewedSoS = True
					Skill_UseHeroSkill(5, 1)
				EndIf

				If AddOns_GetIsDead($l_p_HeroTarget) Or $l_p_HeroTarget = 0 Then
					$l_p_HeroTarget = AddOns_GetNearestAgent_EnemyLiving_NoSM(-2, -1, True, -7043, -5966, $g_ap_Foes)
					Agent_CallTarget($l_p_HeroTarget)
				EndIf

				LockBacklineTarget($l_ap_BacklineFoes)

				If $g_b_PlayerAssistance Then
					If $l_i_RemainingFoes <= 2 Then
						$g_b_PlayerAssistance = False
						MoveToSafeSpot()
					Else
						If $l_i_RemainingFoes >= 4 Then AddOns_UseSkillEx(7)
						If AddOns_GetIsDead($l_p_PlayerTarget) Or $l_p_PlayerTarget = 0 Then
							$l_p_PlayerTarget = AddOns_GetNearestAgent_EnemyLiving_NoSM(-2, -1, True, -6306, -5260, $g_ap_Foes)
						EndIf
						PlayerAssistance(True, $l_p_PlayerTarget)
					EndIf
				Else
					PlayerAssistance()
				EndIf

				If Not $l_b_MartyrDisabled Then 
					$l_b_MartyrDisabled = True
					Ui_DisableHeroSkill(4, 1)
				EndIf
        EndSwitch

		Sleep(250)

		$l_b_TimedOut = (TimerDiff($l_h_Timeout) >= $LC_I_FIGHT_TIMEOUT)
    	$l_b_CanContinue = CanContinue()
    Until $l_b_TimedOut Or Not $l_b_CanContinue

	If $l_b_TimedOut Or Not $l_b_CanContinue Then
		AdlibUnRegister("SupportRoutine")
		Return
	EndIf

    Skill_UseHeroSkill(2, 6) ; Earth Ele - "Fall Back!"

	Speedboost()
    Map_Move(-4800, -3700, 0)

	Local $l_i_SoSQueuedSkill = AddOns_GetQueuedSkill(5)
	If $l_i_SoSQueuedSkill <> 0 Then Skill_CancelHeroSkill(5, $l_i_SoSQueuedSkill)

	Ui_SetHeroBehavior(5, 2)
	Ui_CommandHero(5, -4770, -3330)
    Ui_CommandHero(7, -4770, -3330)

	PrepareHeroSkillbarsForJourney()

	Local $l_p_LastEnemy = AddOns_GetNearestAgent_EnemyLiving_NoSM(-2, -1, True, -6554, -5207, $g_ap_Foes)
    Local $l_b_LastEnemyNearExit = False

	If $l_p_LastEnemy <> 0 Then
		Local $l_i_Counter = 0, $l_i_Interval = 10
		Do
			If AddOns_GetIsDead($l_p_LastEnemy) Or $l_p_LastEnemy = 0 Then ExitLoop
			If Mod($l_i_Counter, $l_i_Interval) = 0 Then Agent_CallTarget($l_p_LastEnemy)
			$l_i_Counter += 1

			If Not $l_b_LastEnemyNearExit And AddOns_GetPseudoDistanceToXY(-4800, -3700, $l_p_LastEnemy) <= $LC_I_DISTANCE_THRESHOLD_1750 Then
				$l_b_LastEnemyNearExit = True
				Ui_CancelHero(1)
				Ui_CancelHero(2)
				Ui_CancelHero(3)
				Ui_CancelHero(4)
				Ui_CancelHero(6)
			EndIf	

			Sleep(250)

			$l_b_TimedOut = (TimerDiff($l_h_Timeout) >= $LC_I_FIGHT_TIMEOUT)
    		$l_b_CanContinue = CanContinue()
		Until $l_b_TimedOut Or Not $l_b_CanContinue

		If $l_b_TimedOut Or Not $l_b_CanContinue Then Return
	EndIf
		
    If Not $l_b_LastEnemyNearExit Then
        Ui_CancelHero(1)
        Ui_CancelHero(2)
        Ui_CancelHero(3)
        Ui_CancelHero(4)
        Ui_CancelHero(6)
    EndIf

	Ui_DisableHeroSkill(6, 7) ; BiP Resto - Kaolai

    $g_ap_Foes = $GC_A_NULL
EndFunc  ;==>Fight
#EndRegion Fight

#Region Journey
; #FUNCTION# ====================================================================================================================
; Name...........: RunToStairs
; Description....: Flags party from fight area onto the ship, handles Miku wait, then moves the player and accompanying heroes to stairs.
; Syntax.........: RunToStairs ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Uses squared-distance gates; includes a short stuck handler for Miku.
;                  - Drops/cancels Recall as needed during the move.
; Related........: AddOns_GetHasEffect, AddOns_GetNumberOfAgent_EnemyLiving_NoSM, AddOns_GetPseudoDistanceToXY, AddOns_GetQueuedSkill,
;                  AddOns_MoveTo, Ui_CommandAll, Ui_CommandHero, Agent_ChangeTarget, CanContinue, Effect_DropBuff, Map_Move,
;                  Quest_GetQuestInfo, Skill_CancelHeroSkill, Skill_UseHeroSkill, TimerDiff, TimerInit                 
; ===============================================================================================================================
Func RunToStairs()
	Ui_CommandAll(-7047, -2651)

	If AddOns_GetHP($g_p_Hero_6) > 0.5 Then Skill_UseHeroSkill(6, 1, $GC_I_HERO_ID_5) ; BiP Resto - BiP - SoS Resto

	Ui_CommandHero(5, -2195, 33)
    Ui_CommandHero(7, -2195, 33)

	Skill_UseHeroSkill(5, 3, $GC_I_HERO_ID_7) ; SoS Resto - Recall - ST

	Local Const $LC_I_DISTANCE_THRESHOLD_EXIT = 2500 * 2500
	Local Const $LC_I_DISTANCE_THRESHOLD_REIKO = 600 * 600

	If AddOns_GetPseudoDistanceToXY(-4800, -3700, $g_p_Player) > $LC_I_DISTANCE_THRESHOLD_EXIT Then
		Speedboost()
		If AddOns_GetPseudoDistanceToXY(-7364, -5803, $g_p_Player) < $LC_I_DISTANCE_THRESHOLD_REIKO Then AddOns_MoveTo(-6845, -5618)
		Map_Move(-4800, -3700, 0)
	EndIf

	Local $l_h_Timeout = TimerInit()
	While True
		If Not CanContinue() Then Return
		If AddOns_GetPseudoDistanceToXY(-4800, -3700, $g_p_Miku) <= $LC_I_DISTANCE_THRESHOLD_EXIT Then ExitLoop
		If TimerDiff($l_h_Timeout) >= 15000 Then
			AddOns_Out("[WARN] Miku is stuck")
			Agent_ChangeTarget($GC_I_MIKU_ID)
			$g_i_Count_MikuFails += 1
			$g_b_CanContinue = False
			Return
		EndIf
		Sleep(250)
	WEnd

	Skill_UseHeroSkill(4, 1) ; Prot Mesmer - Martyr

	AddOns_MoveTo(-4658, -757, "Speedboost")
	Map_Move(-3135, 628, 0)

	Ui_CommandHero(5, -766, -3262)
	Ui_CommandHero(7, -766, -3262)

	AddOns_MoveTo(-3135, 628, "Speedboost")

	$l_h_Timeout = TimerInit()
	While True
		If Not CanContinue() Then Return
		If AddOns_GetNumberOfAgent_EnemyLiving_NoSM($g_p_Player, 2500) > 0 Then ExitLoop
		If Quest_GetQuestInfo($GC_I_QUEST_ID_ACHANCEENCOUNTER, "MarkerX") = -674 And Quest_GetQuestInfo($GC_I_QUEST_ID_ACHANCEENCOUNTER, "MarkerY") = -3454 Then ExitLoop
		If TimerDiff($l_h_Timeout) >= 7500 Then ExitLoop
		Sleep(250)
	WEnd

	If AddOns_GetHasEffect($GC_I_SKILL_ID_RECALL, $g_p_Hero_5) Then
		Effect_DropBuff($GC_I_SKILL_ID_RECALL, $GC_I_HERO_ID_5)
	Else
		If AddOns_GetQueuedSkill(5) = 3 Then Skill_CancelHeroSkill(5, 3)
	EndIf

	AddOns_MoveTo(-2127, -1224, "Speedboost")
	Map_Move(-878, -1854, 0)

	Ui_CommandHero(4, -5606, -2916)	; Move Prot Mesmer into Party Healing Range
	Ui_CommandHero(6, -5606, -2916)	; Move BiP Resto into Party Healing Range
	Ui_CommandHero(5, -1119, -4683) ; Move SoS Resto into PlaceSpirits() position
	Ui_CommandHero(7, -1665, -6015) ; Move ST into PlaceSpirits() position

	AddOns_MoveTo(-878, -1854, "Speedboost")
	
	$l_h_Timeout = TimerInit()
	While True
		If Not CanContinue() Then Return
		If AddOns_GetNumberOfAgent_EnemyLiving_NoSM($g_p_Player, 2500) > 0 Then ExitLoop
		If TimerDiff($l_h_Timeout) >= 7500 Then ExitLoop
		Sleep(250)
	WEnd

	AddOns_MoveTo(-766, -3262, "Speedboost")
	Map_Move(-687, -3780, 0)

	Skill_UseHeroSkill(6, 7) ; BiP Resto - Kaolai
	Skill_UseHeroSkill(7, 8, $GC_I_PLAYER_ID) ; ST Rit - Inspirational Speech - Player

	AddOns_MoveTo(-687, -3780)
EndFunc   ;==>RunToStairs
#EndRegion Journey

#Region Spike
; #FUNCTION# ====================================================================================================================
; Name...........: HeroesIdle
; Description....: Returns True when SoS (5) and ST (7) are both idle.
; Syntax.........: HeroesIdle ( )
; Parameters.....: None
; Return values..: True  - Both idle.
;                  False - One or both busy.
; Author.........: KleuTSchi
; Remarks........: - Combines move/cast checks to reduce race conditions.
; Related........: AddOns_GetIsCasting, AddOns_GetIsMoving, PlaceSpirits
; ===============================================================================================================================
Func HeroesIdle()
    Return (Not AddOns_GetIsCasting($g_p_Hero_5) _
    And Not AddOns_GetIsMoving($g_p_Hero_5)) _
    And (Not AddOns_GetIsCasting($g_p_Hero_7) _
    And Not AddOns_GetIsMoving($g_p_Hero_7))
EndFunc   ;==>HeroesIdle

; #FUNCTION# ====================================================================================================================
; Name...........: PlaceSpirits
; Description....: Lightweight state machine to place ST/SoS spirits once staged.
; Syntax.........: PlaceSpirits ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Starts only when heroes are in the correct position and idle; exits on state 4 or stop.
; Related........: AddOns_GetIsDead, AddOns_GetPseudoDistanceToXY, Skill_UseHeroSkill, Ui_CommandHero, AdlibUnRegister,
;                  CanContinue, HeroesIdle
; ===============================================================================================================================
Func PlaceSpirits()
	Static $s_b_Hero5_Alive, $s_b_Hero7_Alive
	Static $s_i_DistanceThreshold = 150 * 150	
	Static $s_i_NextState = 0
	
	If $s_i_NextState = 0 Then
		$s_b_Hero5_Alive = Not AddOns_GetIsDead($g_p_Hero_5)
		$s_b_Hero7_Alive = Not AddOns_GetIsDead($g_p_Hero_7)
	
		If (($s_b_Hero5_Alive Or $s_b_Hero7_Alive) _
		And (Not $s_b_Hero5_Alive Or AddOns_GetPseudoDistanceToXY(-1119, -4683, $g_p_Hero_5) < $s_i_DistanceThreshold) _
		And (Not $s_b_Hero7_Alive Or AddOns_GetPseudoDistanceToXY(-1665, -6015, $g_p_Hero_7) < $s_i_DistanceThreshold)) _
		Then
			$g_b_PlaceSpirits = True
		EndIf
	EndIf

	If HeroesIdle() And $g_b_PlaceSpirits Then
		Switch $s_i_NextState
			Case 0
				Skill_UseHeroSkill(5, 8) ; SoS Resto - Rejuvenation
				Skill_UseHeroSkill(7, 1) ; ST Rit - ST
				Skill_UseHeroSkill(7, 2) ; ST Rit - Shelter
				$s_i_NextState = 1
			Case 1
				Ui_CommandHero(5, -997, -4976)
				Skill_UseHeroSkill(5, 3, $GC_I_HERO_ID_7) ; SoS Resto - Recall
				Skill_UseHeroSkill(7, 3) ; ST Rit - Union
				$s_i_NextState = 2
			Case 2
				Skill_UseHeroSkill(7, 7) ; ST Rit - Armor of Unfeeling
				$s_i_NextState = 3
			Case 3					
				Ui_CommandHero(7, -4950, -7955)
				Skill_UseHeroSkill(5, 7) ; SoS Resto - Recuperation
				$s_i_NextState = 4
			Case 4
				If $s_b_Hero5_Alive And Not $s_b_Hero7_Alive Then Ui_CommandHero(5, -4950, -7955)
		EndSwitch
	EndIf

	If $s_i_NextState = 4 Or Not CanContinue() Then					
		AdlibUnRegister("PlaceSpirits")
		$g_b_PlaceSpirits = False
		$s_i_NextState = 0
	EndIf
EndFunc   ;==>HeroesIdle

; #FUNCTION# ====================================================================================================================
; Name...........: FindSeenFoe
; Description....: Finds a pointer in a count-prefixed array; returns its index.
; Syntax.........: FindSeenFoe ( ByRef $a_ap_Seen, $a_p_Agent )
; Parameters.....: $a_ap_Seen - Array : Count at [0], items at [1..N].
;                  $a_p_Agent - Ptr   : Pointer to search.
; Return values..: Integer - Index if found, else 0.
; Author.........: KleuTSchi
; Remarks........: - Simple linear scan; intended for small sets (≤60).
; Related........: AddSeenFoe
; ===============================================================================================================================
Func FindSeenFoe(ByRef $a_ap_Seen, $a_p_Agent)
    Local $l_i_Count_Seen = $a_ap_Seen[0]
    For $i = 1 To $l_i_Count_Seen
        If $a_ap_Seen[$i] = $a_p_Agent Then Return $i
    Next
    Return 0
EndFunc   ;==>FindSeenFoe

; #FUNCTION# ====================================================================================================================
; Name...........: AddSeenFoe
; Description....: Inserts a new pointer into the seen set (≤60) and refreshes its timer.
; Syntax.........: AddSeenFoe ( ByRef $a_ap_Seen, ByRef $a_h_LastNewSeen, $a_p_Agent )
; Parameters.....: $a_ap_Seen       - Array  : Count/pointer set.
;                  $a_h_LastNewSeen - Handle : Updated via TimerInit().
;                  $a_p_Agent       - Ptr    : Pointer to insert.
; Return values..: Integer - Index used (or existing index). 0 if full.
; Author.........: KleuTSchi
; Remarks........: - Skips duplicates; bumps "no-arrival" timer on insert.
; Related........: FindSeenFoe, TimerInit
; ===============================================================================================================================
Func AddSeenFoe(ByRef $a_ap_Seen, ByRef $a_h_LastNewSeen, $a_p_Agent)
    Local $l_i_Idx = FindSeenFoe($a_ap_Seen, $a_p_Agent)
    If $l_i_Idx Then Return $l_i_Idx
    If $a_ap_Seen[0] < 60 Then
        $a_ap_Seen[0] += 1
        $l_i_Idx = $a_ap_Seen[0]
        $a_ap_Seen[$l_i_Idx] = $a_p_Agent
        $a_h_LastNewSeen = TimerInit()
        Return $l_i_Idx
    EndIf
    Return 0
EndFunc   ;==>AddSeenFoe

; #FUNCTION# ====================================================================================================================
; Name...........: WaitForFoes
; Description....: Holds position, manages sustain, and exits when waves are resolved.
; Syntax.........: WaitForFoes ( )
; Parameters.....: None
; Return values..: None (procedure; returns early if out of position)
; Author.........: KleuTSchi
; Remarks........: - Uses dwell and arrival-gate logic to avoid infinite waiting.
; Related........: AddOns_GetAgentArray_EnemyLiving_NoSM, AddOns_GetHasEffect, AddOns_GetHP, AddOns_GetIsQueued, AddOns_GetIsRecharged,
;                  AddOns_GetNumberOfAgent_EnemyLiving_NoSM, AddOns_UseSkillEx, Skill_UseHeroSkill, Ui_DropHeroBundle, AdlibRegister,
;                  AddSeenFoe, FindSeenFoe, PlaceSpirits, PlayerDefensives, TimerDiff, TimerInit
; ===============================================================================================================================
Func WaitForFoes()
	If AddOns_GetPseudoDistanceToXY(-687, -3780, $g_p_Player) > (25 * 25) Then
        AddOns_Out("[WARN] Player not in position")
        $g_b_CanContinue = False
        Return
    EndIf

	AddOns_UpdatePartyPtrs()

    Local $l_h_Start = TimerInit()
    Do
        Sleep(500)
    Until AddOns_GetNumberOfAgent_EnemyLiving_NoSM($g_p_Player, 1000) >= 4 _
    Or AddOns_GetIsDead($g_p_Player) _
    Or TimerDiff($l_h_Start) >= 30000

	AdlibRegister("PlaceSpirits", 500)

    Local Const $LC_I_TICK_MS = 500
    Local Const $LC_I_NO_ARRIVAL_MS = 18000 ; inter-pack gap + small buffer
    Local Const $LC_F_RESOLVE_RATIO = 0.98 ; 0.95 - 0.98 depending on tolerance
    Local Const $LC_I_SEEN_TARGET = 60 ; skip no-arrivals wait once ≥ this many uniques were seen
    Local Const $LC_I_DWELL_MS = 12000 ; how long (ms) to tolerate foes dwelling outside of 200 once entering 1000
    Local Const $LC_I_DWELL_TICKS = Ceiling($LC_I_DWELL_MS / $LC_I_TICK_MS)

    Local $l_ap_Seen1000[61] = [0] ; ever seen within 1000
    Local $l_ab_Stuck200[61] = [0] ; has been in 200 at least once
    Local $l_ab_In1000Now[61] = [0] ; scratch bitmap per tick
    Local $l_ai_Dwell1000Not200[61] = [0] ; tick counter per foe

    Local $l_h_LastNewSeen = TimerInit()
    Local $l_h_Timeout = TimerInit()

    Local $l_f_PlayerHP, $l_b_MartyrUsed = False, $l_i_Counter_Martyr = 0

    Do
		StayAlive(True)

        If Not $l_b_MartyrUsed Then
            If Not AddOns_GetIsQueued(4) _
            And (AddOns_GetHasEffect($GC_I_SKILL_ID_BURNING, $g_p_Player) Or AddOns_GetHasEffect($GC_I_SKILL_ID_DEEP_WOUND, $g_p_Player)) Then
                $l_b_MartyrUsed = True
                Skill_UseHeroSkill(4, 1) ; Prot Mes - Martyr
            EndIf
        Else
            $l_i_Counter_Martyr += 1
            If $l_i_Counter_Martyr = 10 Then
                $l_i_Counter_Martyr = 0
                $l_b_MartyrUsed = False
            EndIf
        EndIf

        Local $l_ap_FoesIn1000 = AddOns_GetAgentArray_EnemyLiving_NoSM($g_p_Player, 1000, True, -88, -3180)
        Local $l_ap_FoesIn200 = AddOns_GetAgentArray_EnemyLiving_NoSM($g_p_Player, 200, False, 0, 0, $l_ap_FoesIn1000)

        For $i = 1 To $l_ap_Seen1000[0]
            $l_ab_In1000Now[$i] = 0
        Next

        For $i = 1 To $l_ap_FoesIn1000[0]
            Local $l_p_Foe = $l_ap_FoesIn1000[$i]
            If $l_p_Foe = 0 Then ContinueLoop

            Local $l_i_Idx1000 = AddSeenFoe($l_ap_Seen1000, $l_h_LastNewSeen, $l_p_Foe)
            If $l_i_Idx1000 = 0 Then ContinueLoop
            $l_ab_In1000Now[$l_i_Idx1000] = 1
        Next

        For $i = 1 To $l_ap_FoesIn200[0]
            Local $a_p_Agent200 = $l_ap_FoesIn200[$i]
            If $a_p_Agent200 = 0 Then ContinueLoop
            Local $l_i_Idx200 = FindSeenFoe($l_ap_Seen1000, $a_p_Agent200)
            If $l_i_Idx200 Then $l_ab_Stuck200[$l_i_Idx200] = 1
        Next

        For $i = 1 To $l_ap_Seen1000[0]
            If $l_ab_In1000Now[$i] And Not $l_ab_Stuck200[$i] Then
                $l_ai_Dwell1000Not200[$i] += 1
            Else
                $l_ai_Dwell1000Not200[$i] = 0
            EndIf
        Next

        Local $l_i_Count_Seen = $l_ap_Seen1000[0], $l_iResolved = 0
        For $i = 1 To $l_i_Count_Seen
            If $l_ab_Stuck200[$i] _
            Or ($l_ab_In1000Now[$i] = 0) _
            Or ($l_ai_Dwell1000Not200[$i] >= $LC_I_DWELL_TICKS) Then
                $l_iResolved += 1
            EndIf
        Next

        Local $l_b_SeenTargetReached = ($l_i_Count_Seen >= $LC_I_SEEN_TARGET)
        Local $l_b_NoArrivalsGate = $l_b_SeenTargetReached Or (TimerDiff($l_h_LastNewSeen) >= $LC_I_NO_ARRIVAL_MS)

        If $l_i_Count_Seen > 0 _
        And $l_b_NoArrivalsGate _
        And ($l_iResolved >= Int($l_i_Count_Seen * $LC_F_RESOLVE_RATIO)) Then
            ExitLoop
        EndIf

        If AddOns_GetIsDead($g_p_Player) Then ExitLoop
        If TimerDiff($l_h_Timeout) >= 60000 Then ExitLoop

        Sleep($LC_I_TICK_MS)
    Until False
EndFunc   ;==>WaitForFoes

; #FUNCTION# ====================================================================================================================
; Name...........: Spike
; Description....: Buffs, primes, and executes a Whirlwind Attack spike; evaluates outcome.
; Syntax.........: Spike ( )
; Parameters.....: None
; Return values..: Success - True when spike conditions met and foes reduced.
;                  Failure - False on abort/timeout.
; Author.........: KleuTSchi, ZupaBlahq
; Remarks........: - Requires allies to be out of compass range and 100B primed; times out after short window.
; Related........: AddOns_GetAdrenaline, AddOns_GetAgentArray_EnemyLiving_NoSM, AddOns_GetCurrentEnergy, AddOns_GetHasEffect,
;                  AddOns_GetHP, AddOns_GetNearestAgent_EnemyLiving_NoSM, AddOns_UseSkillEx, Effect_DropBuff, Other_PingSleep,
;                  Skill_UseHeroSkill, Ui_CommandHero, CalculateFoeCount, CalculateRuntime, CanContinue
; ===============================================================================================================================
Func Spike()
	$g_b_SpikeSuccess = False
	Local $l_b_WeaponActive = False
	Local $l_b_HonorActive = False
	Local $l_b_AlliesInRange = True
	Local $l_b_TargetDead = False

	Ui_CommandHero(4, -6341, -2751)
	Ui_CommandHero(6, -6341, -2751)

	Local $l_h_Timeout = TimerInit()
	Do
		If Not $l_b_WeaponActive And AddOns_GetIsRecharged(4,5) Then
			Skill_UseHeroSkill(5, 4, $GC_I_PLAYER_ID)
		Else
			$l_b_WeaponActive = True
			Ui_CommandHero(5, -4950, -7955)
			If AddOns_GetHasEffect($GC_I_SKILL_ID_RECALL, $g_p_Hero_5) Then Effect_DropBuff($GC_I_SKILL_ID_RECALL, $GC_I_HERO_ID_5)
		EndIf

		StayAlive()

		If Not $l_b_HonorActive Then
			If AddOns_UseSkillEx(7) Then $l_b_HonorActive = True			
		EndIf

		If $l_b_AlliesInRange Then
			Local $l_ap_Allies[] = [4, _
				Agent_GetAgentPtr($GC_I_HERO_ID_4), _
				Agent_GetAgentPtr($GC_I_HERO_ID_5), _
				Agent_GetAgentPtr($GC_I_HERO_ID_6), _
				Agent_GetAgentPtr($GC_I_HERO_ID_7) _
			]
			$l_b_AlliesInRange = AddOns_GetNumberOfAgent_AllyLiving($g_p_Player, -1, False, 0, 0, $l_ap_Allies) > 0
		EndIf

		Sleep(500)

		If Not CanContinue() Then Return False
	Until (AddOns_GetAdrenaline(4) >= 130 And AddOns_GetCurrentEnergy($g_p_Player) >= 5 And $l_b_WeaponActive And $l_b_HonorActive And $l_b_AlliesInRange = False) _
	Or TimerDiff($l_h_Timeout) >= 15000
		
	Local $l_ap_FoesToSpike[] = [0], $l_p_TargetFoe
	$l_h_Timeout = TimerInit()
	Do
		If Not AddOns_GetHasEffect($GC_I_SKILL_ID_HUNDRED_BLADES, $g_p_Player) Then
			AddOns_UseSkillEx(2)
		Else
			$l_ap_FoesToSpike = AddOns_GetAgentArray_EnemyLiving_NoSM($g_p_Player, 200)
			$l_p_TargetFoe = AddOns_GetNearestAgent_EnemyLiving_NoSM($g_p_Player, -1, False, 0, 0, $l_ap_FoesToSpike)

			AddOns_Out("[INFO] Foes to spike: " & $l_ap_FoesToSpike[0])
			If AddOns_UseSkillEx(4, $l_p_TargetFoe) Then 
				$g_i_Count_SpikedFoes = $l_ap_FoesToSpike[0]
				ExitLoop
			EndIf
		EndIf

		Sleep(500)

		If Not CanContinue() Then Return False
	Until TimerDiff($l_h_Timeout) >= 15000

	$l_h_Timeout = TimerInit()
    Do 
		$l_b_TargetDead = AddOns_GetIsDead($l_p_TargetFoe)
        If $l_b_TargetDead Then ExitLoop
        Sleep(250)
    Until $g_b_SpikeSuccess Or TimerDiff($l_h_Timeout) >= 5000

	If $l_b_TargetDead And CanContinue() Then
		$g_b_SpikeSuccess = True

		CalculateRuntime($g_h_Runtime)
		CalculateFoeCount()

		Ui_CommandHero(4, -5606, -2916)

		PostSpikeDefensives()
	EndIf
EndFunc   ;==>Spike
#EndRegion Spike

#Region Loot
; #FUNCTION# ====================================================================================================================
; Name...........: CreatePickupSet
; Description....: Builds a modelID → rule map based on GUI loot options. Each value packs a statistics tracker (high 16 bits)
;                  and a required extraID (low 16 bits).
; Syntax.........: CreatePickupSet ( )
; Parameters.....: None
; Return values..: Map - Keys: model IDs. Values: (tracker << 16) | requiredExtraID.
; Author.........: KleuTSchi
; Remarks........: - Always includes Gold Coins and Ministerial Commendations.
;                  - Uses GUI checkboxes to conditionally include Lockpicks, Black Dye, Tomes, PCons, Event Tokens, and TP items.
;                  - Relies on array constants (e.g., *_LOOT_TOMES) to expand categories.
; Related........: GUI_GUICtrlIsChecked, BitAND, BitOR, BitShift, UBound
; ===============================================================================================================================
Func CreatePickupSet()
    Local $l_b_LPChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootLP)
    Local $l_b_BDChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootBD)
	Local $l_b_TomeChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootTome)
    Local $l_b_PConChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootPCon)
    Local $l_b_EventTokenChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootEventToken)
    Local $l_b_TPItemChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_LootTPItem)

    Local $l_m_PickUpSet[]

    $l_m_PickUpSet[$GC_I_MODELID_GOLD_COIN] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_NONE, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
    $l_m_PickUpSet[$GC_I_MODELID_MINISTERIAL_COMMENDATION] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_MINISTERIAL_COMMENDATION, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))

    If $l_b_LPChecked Then
        $l_m_PickUpSet[$GC_I_MODELID_LOCKPICK] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_LOCKPICK, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
    EndIf

    If $l_b_BDChecked Then
        $l_m_PickUpSet[$GC_I_MODELID_DYE] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_BLACK_DYE, -16), BitAND($GC_I_EXTRAID_DYE_BLACK, 0xFFFF))
    EndIf

	If $l_b_TomeChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_LOOT_TOMES) - 1
            $l_m_PickUpSet[$GC_AI_MODELIDS_LOOT_TOMES[$i]] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_NONE, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
        Next
    EndIf

    If $l_b_PConChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_LOOT_PCONS) - 1
            $l_m_PickUpSet[$GC_AI_MODELIDS_LOOT_PCONS[$i]] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_NONE, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
        Next
    EndIf

    If $l_b_EventTokenChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_LOOT_EVENT_TOKENS) - 1
            $l_m_PickUpSet[$GC_AI_MODELIDS_LOOT_EVENT_TOKENS[$i]] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_NONE, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
        Next
    EndIf

    If $l_b_TPItemChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_LOOT_TPITEMS) - 1
            $l_m_PickUpSet[$GC_AI_MODELIDS_LOOT_TPITEMS[$i]] = BitOR(BitShift($GC_I_STATISTICS_TRACKER_NONE, -16), BitAND($GC_I_EXTRAID_ANY, 0xFFFF))
        Next
    EndIf

    Return $l_m_PickUpSet
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: CanPickUp
; Description....: Determines if an item matches the pickup rules; returns True and sets @extended to the statistics
;                  tracker code when accepted.
; Syntax.........: CanPickUp ( $a_p_Item, $a_m_PickUpSet )
; Parameters.....: $a_p_Item     - Ptr : Item pointer.
;                  $a_m_PickUpSet - Map : From CreatePickupSet().
; Return values..: Success - True  with @extended = tracker code.
;                  Failure - False with @error set to:
;                            1 -> ReadProcessMemory failed.
; Author.........: KleuTSchi
; Remarks........: - Treats gold-rarity items as auto-accept (golden item tracker).
;                  - Reads extraID, modelID, and rarity via one cached DllStruct plus a follow-up Memory_Read for rarity.
;                  - Matches by modelID and optional extraID; packed rule encodes both.
; Related........: BitAND, BitShift, DllCall, DllStructCreate, DllStructGetData, DllStructGetSize, MapExists, Memory_Read,
;                  SetError, SetExtended
; ===============================================================================================================================
Func CanPickUp($a_p_Item, $a_m_PickUpSet)
	Static $s_d_PickUpStruct = DllStructCreate( _
		"byte[" & $GC_I_OFFSET_ITEM_EXTRA_ID  & "];byte extraID;" & _
		"byte[" & ($GC_I_OFFSET_ITEM_MODEL_ID - ($GC_I_OFFSET_ITEM_EXTRA_ID + 1)) & "];dword modelID;" & _
		"byte[" & ($GC_I_OFFSET_ITEM_RARITY - ($GC_I_OFFSET_ITEM_MODEL_ID + 4)) & "];ptr rarity" _
	)
	Static $s_i_PickUpStructSize = DllStructGetSize($s_d_PickUpStruct)

	Local $l_av_Call = DllCall($g_h_Kernel32, "bool", "ReadProcessMemory", _
		"handle", $g_h_GWProcess, _
		"ptr", $a_p_Item, _
		"struct*", $s_d_PickUpStruct, _
		"ulong_ptr", $s_i_PickUpStructSize, _
		"ulong_ptr*", 0 _
	)
	If @error Or Not $l_av_Call[0] Then Return SetError(1, 0, 0)

	Local $l_i_ExtraID = DllStructGetData($s_d_PickUpStruct, "extraID")
    Local $l_i_ModelID = DllStructGetData($s_d_PickUpStruct, "modelID")
    Local $l_i_Rarity = Memory_Read(DllStructGetData($s_d_PickUpStruct, "rarity"), "ushort")

	If $l_i_Rarity = $GC_I_RARITY_GOLD Then 
		Return SetExtended($GC_I_STATISTICS_TRACKER_GOLDEN_ITEM, True)
	EndIf

	If MapExists($a_m_PickUpSet, $l_i_ModelID) Then
        Local $l_i_Packed = $a_m_PickUpSet[$l_i_ModelID]
        Local $l_i_ReqExtraID = BitAND($l_i_Packed, 0xFFFF)
        Local $l_i_ExtendedValue = BitShift($l_i_Packed, 16)

        If ($l_i_ReqExtraID = $GC_I_EXTRAID_ANY) Or ($l_i_ReqExtraID = $l_i_ExtraID) Then
            Return SetExtended($l_i_ExtendedValue, True)
        EndIf
    EndIf

	Return False
EndFunc   ;==>CanPickUp

; #FUNCTION# ====================================================================================================================
; Name...........: PickUpLoot
; Description....: Scans nearby owned item agents, filters with CanPickUp, moves into interact range, and attempts pickups
;                  with short retries.
; Syntax.........: PickUpLoot ( [$a_i_PickUpRange = 1000 [, $a_b_WaitForRevive = False]] )
; Parameters.....: $a_i_PickUpRange  - Integer : Radius (units). -1 to ignore distance.
;                  $a_b_WaitForRevive - Bool   : If True, waits briefly while dead.
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Uses squared distances for cheap range checks; interact range ≈ 143².
;                  - Optional revive wait (≤ 90s) before each pickup attempt.
;                  - Moves to item XY if outside interact range, then retries pickup for
;                    ~1.5s, verifying by agentID change.
;                  - On success, updates counters based on @extended from CanPickUp.
; Related........: AddOns_GetAgentArray_ItemOwned, AddOns_GetIsDead, AddOns_GetPseudoDistance, AddOns_GetXY_, AddOns_MoveTo,
;                  CreatePickupSet, Item_GetItemPtr, Item_PickUpItem, Memory_Read, Other_PingSleep, Party_GetPartyContextInfo,
;                  CanPickUp, TimerDiff, TimerInit
; ===============================================================================================================================
Func PickUpLoot($a_i_PickUpRange = 1000, $a_b_WaitForRevive = False)
	Local $l_m_PickUpSet = CreatePickupSet()
    Local $l_ap_ItemAgents = AddOns_GetAgentArray_ItemOwned($g_p_Player, $a_i_PickUpRange)
    Local $l_i_MaxInteractRange = 143 * 143
    Local $l_i_PickUpRange = $a_i_PickUpRange * $a_i_PickUpRange
    Local $l_p_Item, $l_i_ItemID, $l_i_Distance, $l_h_Timeout, $l_i_AgentID, $l_i_AgentIDCheck

	Local $l_b_MartyrUsed = False
    For $i = 1 To $l_ap_ItemAgents[0]
		If Not $l_b_MartyrUsed And Agent_GetAgentPtr($GC_I_HERO_ID_4) <> 0 Then
			$l_b_MartyrUsed = True
			Skill_UseHeroSkill(4, 1)
		EndIf

        $l_p_Agent = $l_ap_ItemAgents[$i]
		If $l_p_Agent = 0 Then ContinueLoop
		
		$l_i_ItemID = Memory_Read($l_p_Agent + 0xC8, "dword")
        $l_p_Item = Item_GetItemPtr($l_i_ItemID)
		If $l_p_Item = 0 Then ContinueLoop

		$l_i_Distance = AddOns_GetPseudoDistance($l_p_Agent)
		If $a_i_PickUpRange <> -1 And $l_i_Distance > $l_i_PickUpRange Then
			ContinueLoop
		EndIf

        If CanPickUp($l_p_Item, $l_m_PickUpSet) Then
			Local $l_i_Extended = @extended

            If $a_b_WaitForRevive Then
                $l_h_Timeout = TimerInit()
                While AddOns_GetIsDead($g_p_Player) And TimerDiff($l_h_Timeout) < 90000 And Not Party_GetPartyContextInfo("IsDefeated")
                    Sleep(500)
                WEnd
            EndIf

			Local $l_af_Coords = AddOns_GetXY_($l_p_Agent)
			If @error Or $l_af_Coords = 0 Then Return

			Local $l_f_PosX = $l_af_Coords[0]
			Local $l_f_PosY = $l_af_Coords[1]

            If $l_i_Distance > $l_i_MaxInteractRange Then AddOns_MoveTo($l_f_PosX, $l_f_PosY)

            $l_h_Timeout = TimerInit()
            $l_i_AgentID = Memory_Read($l_p_Item + 0x4, "dword")
            
			Local $l_b_PickedUp = False
            Do
				Item_PickUpItem($l_i_AgentID)
                Other_PingSleep(150)
                $l_i_AgentIDCheck = Memory_Read($l_p_Item + 0x4, "dword")
				$l_b_PickedUp = $l_i_AgentID <> $l_i_AgentIDCheck
            Until $l_b_PickedUp Or TimerDiff($l_h_Timeout) > 1500 Or AddOns_GetIsDead($g_p_Player)

			If $l_b_PickedUp Then
				Switch $l_i_Extended
					Case 1
						$g_i_Count_GoldItem += 1
					Case 2
						$g_i_Count_MinisterialCommendationLooted += 1
						$g_i_Count_MinisterialCommendation += 1
					Case 3
						$g_i_Count_Lockpick += 1
					Case 4
						$g_i_Count_BlackDye += 1
				EndSwitch
			EndIf
        EndIf
    Next
EndFunc   ;==>PickUpLoot
#EndRegion Loot

#Region Performance
; #FUNCTION# ====================================================================================================================
; Name...........: CalculateRuntime
; Description....: Updates running average and fastest runtime using the given timer handle.
; Syntax.........: CalculateRuntime ( $a_h_Timer )
; Parameters.....: $a_h_Timer - Handle : Timer handle obtained from TimerInit().
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Uses only successful runs ($g_i_Count_Runs - $g_i_Count_Fails) to update the average.
;                  - Stores average as seconds (float) and also as minutes/minutesMod (rounded).
;                  - Updates fastest runtime when the current run is strictly lower.
; Related........: Mod, Round, TimerDiff, TimerInit
; ===============================================================================================================================
Func CalculateRuntime($a_h_Timer)
    Local $l_i_Count_Success = $g_i_Count_Runs - $g_i_Count_Fails

	Local $l_f_RuntimeSeconds = TimerDiff($a_h_Timer) / 1000
    $g_i_AvgRuntimeSeconds = (($g_i_AvgRuntimeSeconds * $l_i_Count_Success) + $l_f_RuntimeSeconds) / ($l_i_Count_Success + 1)

    Local $l_i_AvgRuntimeSecondsRounded = Round($g_i_AvgRuntimeSeconds)
    $g_i_AvgRuntimeMinutesMod = Mod($l_i_AvgRuntimeSecondsRounded, 60)
    $g_i_AvgRuntimeMinutes = ($l_i_AvgRuntimeSecondsRounded - $g_i_AvgRuntimeMinutesMod) / 60

    If $l_f_RuntimeSeconds < $g_f_FastestRuntimeSeconds Then
        $g_f_FastestRuntimeSeconds = $l_f_RuntimeSeconds
        Local $l_i_FastestRuntimeSecondsRounded = Round($l_f_RuntimeSeconds)
        $g_i_FastestRuntimeMinutesMod = Mod($l_i_FastestRuntimeSecondsRounded, 60)
        $g_i_FastestRuntimeMinutes = ($l_i_FastestRuntimeSecondsRounded - $g_i_FastestRuntimeMinutesMod) / 60
    EndIf
EndFunc   ;==>CalculateRuntime

; #FUNCTION# ====================================================================================================================
; Name...........: CalculateFoeCount
; Description....: Updates the running average of spiked foes using the latest spike count.
; Syntax.........: CalculateFoeCount ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Averages over successful runs only; rounds the stored average to 3 decimals.
;                  - Reads the current spike count from $g_i_Count_SpikedFoes.
; Related........: CalculateRuntime, Round
; ===============================================================================================================================
Func CalculateFoeCount()
	Local $l_i_Count_Success = $g_i_Count_Runs - $g_i_Count_Fails

	Local $l_i_OldAvgFoeCount = $g_i_Count_AvgSpikedFoes
	Local $l_i_NewAvgFoeCount = Round((($l_i_OldAvgFoeCount * $l_i_Count_Success) + $g_i_Count_SpikedFoes) / ($l_i_Count_Success + 1), 3)

	$g_i_Count_AvgSpikedFoes = $l_i_NewAvgFoeCount
EndFunc   ;==>CalculateFoeCount
#EndRegion Performance

#Region Quest18
; #FUNCTION# ====================================================================================================================
; Name...........: CanContinue
; Description....: Checks whether the run should proceed based on player death, defeat state, journey readiness,
;                  and the global continue flag.
; Syntax.........: CanContinue ( )
; Parameters.....: None
; Return values..: True  - Continue running.
;                  False - Stop (no @error is set).
; Author.........: KleuTSchi
; Remarks........: - If the player is dead after the journey is marked ready, the run halts.
;                  - Relies on $g_b_CanContinue and $g_b_JourneyReady global flags.
; Related........: AddOns_GetIsDead, Party_GetPartyContextInfo
; ===============================================================================================================================
Func CanContinue()
    Local $l_b_IsDead = AddOns_GetIsDead($g_p_Player)
    If @error Then Return False

    Local $l_b_IsDefeated = Party_GetPartyContextInfo("IsDefeated")
    Local $l_b_JourneyPrepared = $g_b_JourneyReady

    Return $g_b_CanContinue _
        And Not $l_b_IsDefeated _
        And Not ($l_b_IsDead And $l_b_JourneyPrepared)
EndFunc   ;==>CanContinue

; #FUNCTION# ====================================================================================================================
; Name...........: Quest18
; Description....: Orchestrates a full quest run via heartbeat steps to detect game crashes:
;                  inventory preparation, optional reward exchange, enter, fight, travel, wait, spike, loot, and
;                  return to outpost with logging and metrics.
; Syntax.........: Quest18 ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> A required step failed (see logs).
;                            2 -> Was on wrong map; traveled to outpost and exited early.
; Author.........: KleuTSchi
; Remarks........: - Uses CanContinue() gates after major phases to abort safely.
;                  - Exchanges rewards only when MC count and free slots thresholds meet.
;                  - Updates run counters; fastest/average time is recorded elsewhere.
; Related........: AddOns_GetEmptyInventorySlotCount, AddOns_Out, Ui_ToggleRendering, Map_GetMapID, Memory_Clear,
;                  Memory_Read, CalculateFoeCount, CalculateRuntime, CanContinue, Fight, HeartbeatEnterQuest,
;                  HeartbeatStep, HeartbeatTravel, PickUpLoot, PrepareToFight, RunToStairs, Spike, WaitForFoes        
; ===============================================================================================================================
Func Quest18()
    AddOns_PurgeHook()

	If Not HeartbeatStep("Inventory", "Inventory") Then Return SetError(1, 0, False)

    If $g_i_Count_MinisterialCommendation >= $GC_I_EXCHANGE_AMOUNT Then
        AddOns_Out("[INFO] Collected enough Ministerial Commendations to exchange for rewards")
        If Not HeartbeatStep("ExchangeRewards", "ExchangeRewards") Then Return SetError(1, 0, False)
    EndIf

	Local $l_i_MapID = Map_GetMapID()
    If $l_i_MapID <> $GC_I_MAP_ID_OUTPOST And $l_i_MapID <> $GC_I_MAP_ID_OUTPOST_EVENT Then
		AddOns_Out("[WARN] Player located on wrong map: " & $g_as_MapLabels[$l_i_MapID])
        AddOns_Out("[INFO] Travelling to Kaineng Center")
        If Not HeartbeatTravel($GC_I_MAP_ID_OUTPOST) Then Return SetError(1, 0, False)
    EndIf

    AddOns_Out("[INFO] Starting run #" & ($g_i_Count_Runs + 1))

    AddOns_Out("[INFO] Entering quest area")
    If Not HeartbeatEnterQuest() Then Return SetError(1, 0, False)
        
    If Map_GetMapID() = $GC_I_MAP_ID_EXPLORABLE Then
        $g_b_CanContinue = True
        $g_h_Runtime = TimerInit()

        AddOns_Out("[INFO] Preparing for initial fight")
        If Not HeartbeatStep("PrepareToFight", "PrepareToFight") Then Return SetError(1, 0, False)

        If CanContinue() Then
            AddOns_Out("[INFO] Engaging in battle")
            If Not HeartbeatStep("Fight", "Fight") Then Return SetError(1, 0, False)
        EndIf

        If CanContinue() Then
            AddOns_Out("[INFO] Moving to stairs")
            If Not HeartbeatStep("RunToStairs", "RunToStairs") Then Return SetError(1, 0, False)
        EndIf

        If CanContinue() Then
            AddOns_Out("[INFO] Waiting for foes to ball")
            If Not HeartbeatStep("WaitForFoes", "WaitForFoes") Then Return SetError(1, 0, False)
        EndIf

        If CanContinue() Then
            AddOns_Out("[INFO] Preparing to spike foes")
            If Not HeartbeatStep("Spike", "Spike") Then Return SetError(1, 0, False)
        EndIf

		If CanContinue() Then
			If $g_b_SpikeSuccess Then
				AddOns_Out("[INFO] Spike successful, picking up loot")
				If Not HeartbeatStep("PickUpLoot", "PickUpLoot") Then Return SetError(1, 0, False)
			Else
				AddOns_Out("[WARN] Spike unsuccessful")
			EndIf
        EndIf

        $g_i_Count_Runs += 1

		If Not (CanContinue() And $g_b_SpikeSuccess) Then
            AddOns_Out("[WARN] Run failed")
            $g_i_Count_Fails += 1
        EndIf
    Else
        FailHeartbeat("EnterQuest → Failed to enter quest area")
        Return SetError(1, 0, False)
    EndIf

    AddOns_Out("[INFO] Travelling to Kaineng Center")
    If Not HeartbeatTravel($GC_I_MAP_ID_OUTPOST) Then Return SetError(1, 0, False)
	
    Return True
EndFunc   ;==>Quest18
#EndRegion Quest18

#Region OpenLockboxes
; #FUNCTION# ====================================================================================================================
; Name...........: EnsureFreeInventorySlot
; Description....: Ensures at least the requested number of inventory slots are free by destroying
;                  junk and depositing keep-items to storage.
; Syntax.........: EnsureFreeInventorySlot ( $a_i_Slots, $a_ai_JunkItems, $a_ai_KeepItems )
; Parameters.....: $a_i_Slots      - Integer : Required free slot count.
;                  $a_ai_JunkItems - Array   : ModelIDs to destroy.
;                  $a_ai_KeepItems - Array   : ModelIDs to deposit to storage.
; Return values..: Success - True
;                  Failure - False
; Author.........: KleuTSchi
; Remarks........: - Tries DestroyLockboxJunk() first; then deposits keep-items.
;                  - Lockpicks are deposited with a "full stacks only" behavior.
; Related........: AddOns_DepositItemsToStorage, AddOns_GetEmptyInventorySlotCount, DestroyLockboxJunk
; ===============================================================================================================================
Func EnsureFreeInventorySlot($a_i_Slots, $a_ai_JunkItems, $a_ai_KeepItems)
    If AddOns_GetEmptyInventorySlotCount() >= $a_i_Slots Then Return True

    DestroyLockboxJunk($a_ai_JunkItems)
    If AddOns_GetEmptyInventorySlotCount() >= $a_i_Slots Then Return True

    For $modelID In $a_ai_KeepItems
        If $modelID = $GC_I_MODELID_LOCKPICK Then
            AddOns_DepositItemsToStorage($modelID, -1, 1)
        Else
            AddOns_DepositItemsToStorage($modelID)
        EndIf

        If AddOns_GetEmptyInventorySlotCount() >= $a_i_Slots Then Return True
    Next

    Return False
EndFunc   ;==>EnsureFreeInventorySlot

; #FUNCTION# ====================================================================================================================
; Name...........: DestroyLockboxJunk
; Description....: Destroys all inventory items whose model IDs are in the given list.
; Syntax.........: DestroyLockboxJunk ( $a_ai_JunkItems )
; Parameters.....: $a_ai_JunkItems - Array : ModelIDs to destroy.
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Builds a temp lookup map for O(1) membership checks.
;                  - Sleeps 50 ms + ping between destroys to reduce UI churn.
;                  - Irreversible action; ensure the junk list is correct.
; Related........: Item_DestroyItem, Item_GetInventoryArray, Other_GetPing, MapExists, UBound
; ===============================================================================================================================
Func DestroyLockboxJunk($a_ai_JunkItems)
    Local $l_m_Junk[]
    For $i = 0 To UBound($a_ai_JunkItems) - 1
        $l_m_Junk[$a_ai_JunkItems[$i]] = True
    Next

    Local $l_i_Ping = Other_GetPing()
    Local $l_av2_InvArray = Item_GetInventoryArray()
    Local $l_i_InvArraySize = UBound($l_av2_InvArray, $UBOUND_ROWS)

    For $i = 0 To $l_i_InvArraySize - 1
        Local $l_i_ModelID = $l_av2_InvArray[$i][$GC_I_INVENTORY_MODELID]
        If MapExists($l_m_Junk, $l_i_ModelID) Then
            Local $l_i_ItemID = $l_av2_InvArray[$i][$GC_I_INVENTORY_ITEMID]
            Item_DestroyItem($l_i_ItemID)
            Sleep(50 + $l_i_Ping)
        EndIf
    Next
EndFunc   ;==>DestroyLockboxJunk

; #FUNCTION# ====================================================================================================================
; Name...........: OpenLockboxCleanup
; Description....: Post-open tidy up: destroys junk and deposits keep-items to storage.
; Syntax.........: OpenLockboxCleanup ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Lockpicks are deposited with a "full stacks only" behavior.
; Related........: AddOns_DepositItemsToStorage, DestroyLockboxJunk
; ===============================================================================================================================
Func OpenLockboxCleanup()
	DestroyLockboxJunk($GC_AI_MODELIDS_OPEN_JUNK)
    For $modelID In $GC_AI_MODELIDS_OPEN_KEEP
        If $modelID = $GC_I_MODELID_LOCKPICK Then
            AddOns_DepositItemsToStorage($modelID, -1, 1)
            ContinueLoop
        EndIf
        AddOns_DepositItemsToStorage($modelID)
    Next
EndFunc   ;==>OpenLockboxCleanup

; #FUNCTION# ====================================================================================================================
; Name...........: OpenLockboxes
; Description....: Opens Imperial Guard Lockboxes, withdrawing from storage as needed, while maintaining free inventory slots
;                  and honoring GUI bot state.
; Syntax.........: OpenLockboxes ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Process not alive
;                            2 -> Not enough free slots and no boxes to open
;                            3 -> Withdraw from storage failed (see @extended)
;                            4 -> No free slots after cleanup
; Author.........: KleuTSchi
; Remarks........: - Ensures a minimal free slot threshold before each open.
;                  - Aborts cleanly if GUI stop/resume is requested.
;                  - Uses short sleeps (50 ms + ping) after each open for stability.
; Related........: AddOns_GetEmptyInventorySlotCount, AddOns_GetInventoryItemCountbyModelID, AddOns_GetStorageItemCountbyModelID,
;                  AddOns_Out, AddOns_WithdrawItemsFromStorage, GUI_BotIsOpening, GUI_SetBotState, Item_GetInventoryArray,
;                  Item_UseItem, Memory_Read, Other_GetPing, EnsureFreeInventorySlot, IsAlive, OpenLockboxCleanup, ProcessWaitClose
; ===============================================================================================================================
Func OpenLockboxes()
	If Not IsAlive("OpenLockboxes") Then Return SetError(1, 0, False)

    Local Const $LC_I_FREE_SLOT_THRESHOLD = 1

    If AddOns_GetInventoryItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX) <= 0 _
    And AddOns_GetEmptyInventorySlotCount() <= $LC_I_FREE_SLOT_THRESHOLD Then
        AddOns_Out("[ERR] Not enough free inventory slots for opening containers")
        If GUI_BotIsOpening() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
        Return SetError(2, 0, False)
    EndIf

    While True
        Local $l_i_InvItemCount = AddOns_GetInventoryItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX)
        If $l_i_InvItemCount <= 0 Then
            Local $l_i_StgItemCount = AddOns_GetStorageItemCountbyModelID($GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX)
            If $l_i_StgItemCount <= 0 Then
                AddOns_Out("[INFO] All available lockboxes have been opened")
                OpenLockboxCleanup()
                If GUI_BotIsOpening() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
                Return True
            EndIf

            If Not AddOns_WithdrawItemsFromStorage($GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX) Then
                Local $l_i_Err = @error
                AddOns_Out("[ERR] Withdrawal of item failed (ERR:" & $l_i_Err & ")")
                If GUI_BotIsOpening() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
                Return SetError(3, $l_i_Err, False)
            EndIf
        EndIf

        Local $l_i_Ping = Other_GetPing()
        Local $l_av2_InvArray = Item_GetInventoryArray()
        Local $l_i_InvArraySize = UBound($l_av2_InvArray, $UBOUND_ROWS)

        For $i = 0 To $l_i_InvArraySize - 1
            If $l_av2_InvArray[$i][$GC_I_INVENTORY_MODELID] <> $GC_I_MODELID_IMPERIAL_GUARD_LOCKBOX Then ContinueLoop

            Local $l_i_ItemID = $l_av2_InvArray[$i][$GC_I_INVENTORY_ITEMID]
            Local $l_i_Qty = $l_av2_InvArray[$i][$GC_I_INVENTORY_QUANTITY]

            For $j = 1 To $l_i_Qty
                If Not GUI_BotIsOpening() Or $g_b_ResumeRequested Then
                    OpenLockboxCleanup()
                    Return True
                EndIf

                If Not EnsureFreeInventorySlot($LC_I_FREE_SLOT_THRESHOLD, $GC_AI_MODELIDS_OPEN_JUNK, $GC_AI_MODELIDS_OPEN_KEEP) Then
					ProcessWaitClose($g_i_GWProcessId, 500)
					If Not IsAlive("OpenLockboxes") Then Return SetError(1, 0, False)

                    AddOns_Out("[ERR] No free slots after cleanup")
                    If GUI_BotIsOpening() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
                    Return SetError(4, 0, False)
                EndIf

                Item_UseItem($l_i_ItemID)
                Sleep(50 + $l_i_Ping)
            Next
        Next
    WEnd
EndFunc   ;==>OpenLockboxes
#EndRegion OpenLockboxes

#Region TradeMode
; #FUNCTION# ====================================================================================================================
; Name...........: CreateTradeSet
; Description....: Builds a modelID → requiredExtraID map from GUI trade options.
; Syntax.........: CreateTradeSet ( )
; Parameters.....: None
; Return values..: Map - Keys: model IDs. Values: required extraID (or $GC_I_EXTRAID_ANY).
; Author.........: KleuTSchi
; Remarks........: - Expands categories (tomes, pcons, tokens, TP items) via constant arrays.
;                  - Black Dye requires the dye-black extraID; others use ANY.
; Related........: GUI_GUICtrlIsChecked, UBound
; ===============================================================================================================================
Func CreateTradeSet()
    Local $l_b_GuardChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeGuard)
    Local $l_b_SealChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeSeal)
	Local $l_b_TenguChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeTengu)
    Local $l_b_MCChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeMC)
    Local $l_b_EctoChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeEcto)
    Local $l_b_ObbyChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeObby)
	Local $l_b_LPChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeLP)
    Local $l_b_BDChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeBD)
	Local $l_b_TomeChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeTome)
    Local $l_b_PConChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradePCon)
    Local $l_b_EventTokenChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeEventToken)
    Local $l_b_IcedTeaChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeIcedTea)
	Local $l_b_DCakeChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeDCake)
	Local $l_b_BeaconChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeBeacon)
	Local $l_b_TPItemChecked = GUI_GUICtrlIsChecked($g_i_CtrlID_CBX_TradeTPItem)

    Local $l_m_TradeSet[]

    If $l_b_GuardChecked Then
        $l_m_TradeSet[$GC_I_MODELID_IMPERIAL_GUARD_REINFORCEMENT_ORDER] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_SealChecked Then
        $l_m_TradeSet[$GC_I_MODELID_SEAL_OF_THE_DRAGON_EMPIRE] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_TenguChecked Then
        $l_m_TradeSet[$GC_I_MODELID_TENGU_SUPPORT_FLARE] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_MCChecked Then
        $l_m_TradeSet[$GC_I_MODELID_MINISTERIAL_COMMENDATION] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_EctoChecked Then
        $l_m_TradeSet[$GC_I_MODELID_GLOB_OF_ECTOPLASM] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_ObbyChecked Then
        $l_m_TradeSet[$GC_I_MODELID_OBSIDIAN_SHARD] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_LPChecked Then
        $l_m_TradeSet[$GC_I_MODELID_LOCKPICK] = $GC_I_EXTRAID_ANY
    EndIf

    If $l_b_BDChecked Then
        $l_m_TradeSet[$GC_I_MODELID_DYE] = $GC_I_EXTRAID_DYE_BLACK
    EndIf

	If $l_b_TomeChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_TRADE_TOMES) - 1
            $l_m_TradeSet[$GC_AI_MODELIDS_TRADE_TOMES[$i]] = $GC_I_EXTRAID_ANY
        Next
    EndIf

    If $l_b_PConChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_TRADE_PCONS) - 1
            $l_m_TradeSet[$GC_AI_MODELIDS_TRADE_PCONS[$i]] = $GC_I_EXTRAID_ANY
        Next
    EndIf

    If $l_b_EventTokenChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_TRADE_EVENT_TOKENS) - 1
            $l_m_TradeSet[$GC_AI_MODELIDS_TRADE_EVENT_TOKENS[$i]] = $GC_I_EXTRAID_ANY
        Next
    EndIf

	If $l_b_IcedTeaChecked Then
        $l_m_TradeSet[$GC_I_MODELID_BATTLE_ISLE_ICED_TEA] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_DCakeChecked Then
        $l_m_TradeSet[$GC_I_MODELID_DELICIOUS_CAKE] = $GC_I_EXTRAID_ANY
    EndIf

	If $l_b_BeaconChecked Then
        $l_m_TradeSet[$GC_I_MODELID_PARTY_BEACON] = $GC_I_EXTRAID_ANY
    EndIf

    If $l_b_TPItemChecked Then
        For $i = 0 To UBound($GC_AI_MODELIDS_TRADE_TPITEMS) - 1
            $l_m_TradeSet[$GC_AI_MODELIDS_TRADE_TPITEMS[$i]] = $GC_I_EXTRAID_ANY
        Next
    EndIf

    Return $l_m_TradeSet
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: OfferItemFromInventory
; Description....: Offers up to 7 eligible items from inventory to the trade window.
; Syntax.........: OfferItemFromInventory ( ByRef $a_i_ItemsOffered, ByRef $a_m_Offered, _
;                  $a_m_TradeSet )
; Parameters.....: $a_i_ItemsOffered - ByRef Int : Accumulator of offered items (0..7).
;                  $a_m_Offered      - ByRef Map : Tracks itemIDs already offered.
;                  $a_m_TradeSet     - Map       : From CreateTradeSet().
; Return values..: Success - True
;                  Failure - False (trade closed or bot not trading)
; Author.........: KleuTSchi
; Remarks........: - Skips duplicates via $a_m_Offered; waits 500 ms + ping after offering.
;                  - Respects required extraID; stops early when 7 items are queued.
; Related........: GUI_BotIsTrading, Item_GetInventoryArray, Other_GetPing, Trade_GetTradeInfo, Trade_OfferItem, MapExists, UBound
; ===============================================================================================================================
Func OfferItemFromInventory(ByRef $a_i_ItemsOffered, ByRef $a_m_Offered, $a_m_TradeSet)
    Local $l_i_Ping = Other_GetPing()
    Local $l_av2_InvArray = Item_GetInventoryArray()
    Local $l_i_InvArraySize = UBound($l_av2_InvArray, $UBOUND_ROWS)

    For $i = 0 To $l_i_InvArraySize - 1
        If Not GUI_BotIsTrading() Then Return False
        If Trade_GetTradeInfo("IsTradeClosed") Then Return False
        If $a_i_ItemsOffered >= 7 Then Return True

        Local $l_i_ModelID = $l_av2_InvArray[$i][$GC_I_INVENTORY_MODELID]
        If Not MapExists($a_m_TradeSet, $l_i_ModelID) Then ContinueLoop

        Local $l_i_ReqExtraID = $a_m_TradeSet[$l_i_ModelID]
        Local $l_i_ExtraID = $l_av2_InvArray[$i][$GC_I_INVENTORY_EXTRAID]
        If ($l_i_ReqExtraID <> $GC_I_EXTRAID_ANY) And ($l_i_ReqExtraID <> $l_i_ExtraID) Then ContinueLoop

        Local $l_i_ItemID = $l_av2_InvArray[$i][$GC_I_INVENTORY_ITEMID]
        If MapExists($a_m_Offered, $l_i_ItemID) Then ContinueLoop

        Trade_OfferItem($l_i_ItemID, $l_av2_InvArray[$i][$GC_I_INVENTORY_QUANTITY])
        Sleep(500 + $l_i_Ping)

        $a_m_Offered[$l_i_ItemID] = True
        $a_i_ItemsOffered += 1
        If $a_i_ItemsOffered >= 7 Then Return True
    Next

    Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: TradeCleanup
; Description....: Deposits all tradeable items (per trade set) to storage.
; Syntax.........: TradeCleanup ( $a_m_TradeSet )
; Parameters.....: $a_m_TradeSet - Map : From CreateTradeSet().
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Uses extraID = -1 to mean "any" when depositing.
; Related........: AddOns_DepositItemsToStorage, MapKeys
; ===============================================================================================================================
Func TradeCleanup($a_m_TradeSet)
    Local $l_ai_TradeModelIDs = MapKeys($a_m_TradeSet)
    For $modelID In $l_ai_TradeModelIDs
		Local $l_i_ReqExtraID = $a_m_TradeSet[$modelID]
		If $l_i_ReqExtraID = $GC_I_EXTRAID_ANY Then $l_i_ReqExtraID = -1

        AddOns_DepositItemsToStorage($modelID, $l_i_ReqExtraID)
    Next
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: LeaveTradeSpot
; Description....: Leaves the trade area by pathing to the chest.
; Syntax.........: LeaveTradeSpot ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Pathing to chest failed
; Author.........: KleuTSchi
; Remarks........: - Requires a route for the given map to be added to the Route Table.
;                  - Uses current map ID to select the correct chest location.
; Related........: Map_GetMapID, Pathing_GoChest
; ===============================================================================================================================
Func LeaveTradeSpot()
    Local $l_i_MapID = Map_GetMapID()
    If Not Pathing_GoChest($l_i_MapID) Then Return SetError(1, 0, False)
    Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: AutoTrade
; Description....: Automates trading of selected items: prepares set, moves to trade spot, offers items from inventory/storage,
;                  and handles accept/cleanup.
; Syntax.........: AutoTrade ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False with @error set to:
;                            1 -> Process not alive
;                            2 -> Not enough free slots (no items in inv)
;                            3 -> Navigation to trade spot failed
;                            4 -> Storage withdrawal failed (see logs)
; Author.........: KleuTSchi
; Remarks........: - Honors GUI trading state and resume requests; cancels trade on abort.
;                  - Limits to 7 items per trade; requires partner counter-offer before accept.
;                  - Resets readiness flag when all trade items are depleted.
; Related........: AddOns_ConvertPlayerNumber, AddOns_GetEmptyInventorySlotCount, AddOns_GetTotalItemCountbyModelID, AddOns_Out,
;                  AddOns_WithdrawItemsFromStorage, Pathing_GoChest, Pathing_GoTradeSpot, Map_GetMapID, Trade_AcceptTrade, 
;                  Trade_CancelTrade, Trade_GetTradeInfo, Trade_GetTradePartner, Trade_InitiateTrade, Trade_SubmitOffer
;                  CreateTradeSet, IsAlive, MapExists, MapKeys, OfferItemFromInventory, TradeCleanup      
; ===============================================================================================================================
Func AutoTrade()
	If Not IsAlive("AutoTrade") Then Return SetError(1, 0, False)

    Local $l_m_TradeSet = CreateTradeSet()
	Local $l_ai_TradeModelIDs = MapKeys($l_m_TradeSet)

    Local $l_b_TradeableInInv = False
    Local $l_av2_InvArray = Item_GetInventoryArray()
    Local $l_i_InvArraySize = UBound($l_av2_InvArray, $UBOUND_ROWS)

    For $i = 0 To $l_i_InvArraySize - 1
        Local $l_i_InvModelID = $l_av2_InvArray[$i][$GC_I_INVENTORY_MODELID]
        If MapExists($l_m_TradeSet, $l_i_InvModelID) Then
            Local $l_i_InvReqExtraID = $l_m_TradeSet[$l_i_InvModelID]
            If $l_i_InvReqExtraID = $GC_I_EXTRAID_ANY Or $l_i_InvReqExtraID = $l_av2_InvArray[$i][$GC_I_INVENTORY_EXTRAID] Then
                $l_b_TradeableInInv = True
                ExitLoop
            EndIf
        EndIf
    Next

    Local Const $LC_I_FREE_SLOT_THRESHOLD = 1
    If Not $l_b_TradeableInInv And AddOns_GetEmptyInventorySlotCount() < $LC_I_FREE_SLOT_THRESHOLD Then
        AddOns_Out("[ERR] Not enough free inventory slots for trading")
        If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
        Return SetError(2, 0, False)
    EndIf

    Local $l_m_StorageStacks[]
    Local $l_av2_StgArray = Item_GetStorageArray()
    Local $l_i_StgArraySize = UBound($l_av2_StgArray, $UBOUND_ROWS)
    Local $l_i_StorageStacksTotal = 0

    For $i = 0 To $l_i_StgArraySize - 1
        Local $l_i_StgModelID = $l_av2_StgArray[$i][$GC_I_INVENTORY_MODELID]
        If MapExists($l_m_TradeSet, $l_i_StgModelID) Then
            Local $l_i_StgReqExtraID = $l_m_TradeSet[$l_i_StgModelID]
            If $l_i_StgReqExtraID = $GC_I_EXTRAID_ANY Or $l_i_StgReqExtraID = $l_av2_StgArray[$i][$GC_I_INVENTORY_EXTRAID] Then
                If MapExists($l_m_StorageStacks, $l_i_StgModelID) Then
                    $l_m_StorageStacks[$l_i_StgModelID] = $l_m_StorageStacks[$l_i_StgModelID] + 1
                Else
                    $l_m_StorageStacks[$l_i_StgModelID] = 1
                EndIf
                $l_i_StorageStacksTotal += 1
            EndIf
        EndIf
    Next

    If Not $l_b_TradeableInInv And $l_i_StorageStacksTotal = 0 Then
        AddOns_Out("[INFO] No tradeable items have been found")
        If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
        Return True
    EndIf

    Local $l_i_MapID = Map_GetMapID()
    If Not $g_b_AutoTradeReady Then
        $g_b_AutoTradeReady = True
        If Not Pathing_GoTradeSpot($l_i_MapID) Then
            If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
            Return SetError(3, 0, False)
        EndIf
    EndIf

    Do
		If Not IsAlive("AutoTrade") Then Return SetError(1, 0, False)
        If Not GUI_BotIsTrading() Or $g_b_ResumeRequested Then Return TradeCleanup($l_m_TradeSet)
        Sleep(250)
    Until Trade_GetTradeInfo("IsTradeInitiated")

    Local $l_i_TradePartner = AddOns_ConvertPlayerNumber(Trade_GetTradePartner(), "AgentID")
    Trade_InitiateTrade($l_i_TradePartner)

    Local $l_i_ItemsOffered = 0
    Local $l_m_OfferedItems[]

    While $l_i_ItemsOffered < 7
		If Not IsAlive("AutoTrade") Then Return SetError(1, 0, False)
        If Not GUI_BotIsTrading() Or $g_b_ResumeRequested Then
            Trade_CancelTrade()
            Return TradeCleanup($l_m_TradeSet)
        EndIf

        If Not OfferItemFromInventory($l_i_ItemsOffered, $l_m_OfferedItems, $l_m_TradeSet) Then
            Return TradeCleanup($l_m_TradeSet)
        EndIf

        If $l_i_ItemsOffered >= 7 Then ExitLoop

        Local $l_b_WithdrawnThisPass = False
        For $modelID In $l_ai_TradeModelIDs
            If Not MapExists($l_m_StorageStacks, $modelID) Then ContinueLoop
            If $l_m_StorageStacks[$modelID] <= 0 Then ContinueLoop
			
			Local $l_i_ReqExtraID = $l_m_TradeSet[$modelID]
			If $l_i_ReqExtraID = $GC_I_EXTRAID_ANY Then $l_i_ReqExtraID = -1

            If Not AddOns_WithdrawItemsFromStorage($modelID, $l_i_ReqExtraID, -1, 0, False) Then
                Switch @error
                    Case 1 ; no free inv slot (no merge target)
                        ContinueLoop
                    Case 3 ; no matching items found (deplete counter)
                        $l_m_StorageStacks[$modelID] = 0
                        ContinueLoop
                    Case Else
                        AddOns_Out("[ERR] Withdrawal failed (ERR:" & @error & ")")
                        If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
                        Return SetError(4, 0, False)
                EndSwitch
            EndIf

            $l_m_StorageStacks[$modelID] -= 1
            $l_b_WithdrawnThisPass = True
            ExitLoop
        Next

        If Not $l_b_WithdrawnThisPass Then ExitLoop
    WEnd

    If $l_i_ItemsOffered = 0 Then
        Trade_CancelTrade()
        AddOns_Out("[ERR] Failed to offer any items")
        If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
        Return SetError(5, 0, False)
    EndIf

    Trade_SubmitOffer()

    Local $l_b_Counter = False
    Do
		If Not IsAlive("AutoTrade") Then Return SetError(1, 0, False)
        If Not GUI_BotIsTrading() Or $g_b_ResumeRequested Then
            Trade_CancelTrade()
            Return TradeCleanup($l_m_TradeSet)
        EndIf
        If Trade_GetTradeInfo("IsTradeClosed") Then Return TradeCleanup($l_m_TradeSet)
        Sleep(250)
        $l_b_Counter = (Trade_GetTradeInfo("PartnerGold") > 0 Or Trade_GetTradeInfo("PartnerItemsPtr") <> 0)
    Until $l_b_Counter

    Trade_AcceptTrade()

    Do
		If Not IsAlive("AutoTrade") Then Return SetError(1, 0, False)
        If Not GUI_BotIsTrading() Or $g_b_ResumeRequested Then
            Trade_CancelTrade()
            Return TradeCleanup($l_m_TradeSet)
        EndIf
        Sleep(250)
    Until Trade_GetTradeInfo("IsTradeClosed")

	Local $l_i_CountRemaining = 0
	For $modelID In $l_ai_TradeModelIDs
		$l_i_CountRemaining += AddOns_GetTotalItemCountbyModelID($modelID)
	Next

    If $l_i_CountRemaining = 0 Then
        $g_b_AutoTradeReady = False
        AddOns_Out("[INFO] All available reward items have been traded")
        Pathing_GoChest($l_i_MapID)
        If GUI_BotIsTrading() Then GUI_SetBotState($GC_I_BOTSTATE_IDLE)
        Return True
    EndIf

    TradeCleanup($l_m_TradeSet)
    Return True
EndFunc
#EndRegion TradeMode

#Region PlayerActions
; #FUNCTION# ====================================================================================================================
; Name...........: PlayerAssistance
; Description....: Provides on-demand self-sustain and combat actions for the player. Heals or sustains based on profession and
;                  health thresholds; optionally engages in combat.
; Syntax.........: PlayerAssistance ( $a_b_Fight = False, $a_i_Target = 0 )
; Parameters.....: $a_b_Fight - If True, performs combat actions (buffs/attacks) after survival checks.
;                  $a_i_Target - Target AgentID for targeted skills/attacks (ignored when $a_b_Fight = False).
; Return values..: None (no explicit return value).
; Author.........: KleuTSchi
; Remarks........: - Base HP threshold is 0.70; Necromancer uses 0.85. Caster professions avoid casting heals while affected
;                    by Backfire.
;                  - When fighting: uses Dwareven Stability/Feel No Pain (Slot 1), Frigid Armor for Elementalist (Slot 6), 
;                    auto-attacks if not attacking, builds adrenaline with "To the Limit!" (Slot 3) if needed, 
;                    and executes Hundred Blades (Slot 2) and Whirlwind Attack (Slot 4) toward $a_i_Target.
;                  - Uses profession-specific self-sustain on slot 6 (e.g., Shadow Refuge / Conviction / Troll Unguent / Healing
;                    Signet / MBaS / Blood Renewal / Ether Feast).
; Related........: AddOns_GetAdrenaline, AddOns_GetHasEffect, AddOns_GetHP, AddOns_GetIsAttacking,
;                  AddOns_GetNumberOfAgent_EnemyLiving_NoSM, AddOns_UseSkillEx, Agent_Attack
; ===============================================================================================================================
Func PlayerAssistance($a_b_Fight = False, $a_i_Target = 0)
	Local $l_f_PlayerHP = AddOns_GetHP($g_p_Player)
	Local $l_f_HPThreshold = 0.7

	If $g_i_PlayerProfession = $GC_I_PROFESSION_NECROMANCER Then $l_f_HPThreshold = 0.85

	If $l_f_PlayerHP < $l_f_HPThreshold Then 
		Switch $g_i_PlayerProfession
			Case $GC_I_PROFESSION_ASSASSIN, $GC_I_PROFESSION_DERVISH, $GC_I_PROFESSION_RANGER, $GC_I_PROFESSION_WARRIOR, $GC_I_PROFESSION_PARAGON
				AddOns_UseSkillEx(6) ; Player - Shadow Refuge/Conviction/Troll Unguent/Healing Signet/Healing Signet
				
			Case $GC_I_PROFESSION_RITUALIST, $GC_I_PROFESSION_MONK
				If Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - MBaS/Healing Breeze
			
			Case $GC_I_PROFESSION_NECROMANCER
				If $l_f_PlayerHP >= 0.7 And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - Blood Renewal

			Case $GC_I_PROFESSION_MESMER
				If $a_b_Fight And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6, $a_i_Target) ; Player - Ether Feast - $a_i_Target
		EndSwitch
	EndIf

	If $a_b_Fight Then 
		AddOns_UseSkillEx(1) ; Player - Dwarven Stability/Feel No Pain	
		If $g_i_PlayerProfession = $GC_I_PROFESSION_ELEMENTALIST Then AddOns_UseSkillEx(6) ; Player - Frigid Armor

		If Not AddOns_GetIsAttacking($g_p_Player) Then Agent_Attack($a_i_Target)
		If AddOns_GetAdrenaline(4) < 130 And AddOns_GetNumberOfAgent_EnemyLiving_NoSM($g_p_Player, 900, False, 0, 0, $g_ap_Foes) >= 1 Then
			AddOns_UseSkillEx(3) ; Player - "To the Limit!"
		EndIf

		AddOns_UseSkillEx(2) ; Player - Hundred Blades
		AddOns_UseSkillEx(4, $a_i_Target) ; Player - Whirlwind Attack - $a_i_Target
	EndIf
Endfunc

; #FUNCTION# ====================================================================================================================
; Name...........: HeroSupport
; Description....: Micro-manages Resto heroes: casts priority skills when ready and drops Kaolai when active.
; Syntax.........: HeroSupport ( )
; Parameters.....: None
; Return values..: None
; Author.........: KleuTSchi
; Remarks........: - Drops Kaolai if the bundle effect is present on BiP Resto (Hero 6).
; Related........: AddOns_GetHasEffect, AddOns_GetIsQueued, AddOns_GetIsRecharged, Skill_UseHeroSkill, Ui_DropHeroBundle
; ===============================================================================================================================
Func HeroSupport()
	If Not AddOns_GetIsQueued(5) Then
		If AddOns_GetIsRecharged(5, 5) Then
			Skill_UseHeroSkill(5, 5, $GC_I_PLAYER_ID) ; Sos Resto - MBaS
		EndIf
	EndIf
	If Not AddOns_GetIsQueued(6) And AddOns_GetIsRecharged(7, 6) Then
		Skill_UseHeroSkill(6, 7) ; BiP Resto - Kaolai
	Else
		If AddOns_GetHasEffect($GC_I_SKILL_ID_PROTECTIVE_WAS_KAOLAI, $g_p_Hero_6) Then Ui_DropHeroBundle(6)
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: SurvivalTriage
; Description....: Triage loop for player survivability. Triggers emergency heals, optional hero support, and weapon spell
;                  application; reports whether the player is at maximum HP.
; Syntax.........: SurvivalTriage ( $l_f_PlayerHP, $a_b_HeroSupport )
; Parameters.....: $l_f_PlayerHP  - Player HP ratio (0.0..1.0).
;                  $a_b_HeroSupport - If True, allows calling HeroSupport() around 85% HP.
; Return values..: Success - True  -> Player is at maximum HP (≥ 1.0).
;                  Failure - False -> Player is below maximum HP.
; Author.........: KleuTSchi
; Remarks........: - Uses emergency heals at ≤ 70% HP.
;                  - At ≤ 85% HP and when $a_b_HeroSupport is True, calls HeroSupport() to assist stabilizing player HP.
;                  - If below max HP and no spirits are being placed, ensures Resilient Weapon is applied.
; Related........: AddOns_GetHasWeaponSpell, AddOns_GetIsQueued, AddOns_UseSkillEx, HeroSupport, Skill_UseHeroSkill
; ===============================================================================================================================
Func SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
	If $l_f_PlayerHP <= 0.7 Then AddOns_UseSkillEx(8) ; Player - "I Will Survive!"/Healing Spring/Grenth's Aura
	If $l_f_PlayerHP <= 0.85 And $a_b_HeroSupport Then HeroSupport()

	Local $l_b_MaxHP = True
	If $l_f_PlayerHP < 1.0 Then
		$l_b_MaxHP = False
		If Not $g_b_PlaceSpirits And Not AddOns_GetIsQueued(5) And Not AddOns_GetHasWeaponSpell($g_p_Player) Then
			Skill_UseHeroSkill(5, 4, $GC_I_PLAYER_ID)
		EndIf
	EndIf

	Return $l_b_MaxHP
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: ApplyDefensiveBuffs
; Description....: Applies profession-appropriate defensive buffs; ensures Dark Escape is chained under Dwarven Stability
;                  for Assassin, and uses core defensive skills for other professions.
; Syntax.........: ApplyDefensiveBuffs ( )
; Parameters.....: None
; Return values..: None
; Author.........: KleuTSchi
; Remarks........: - Assassin: if Dwarven Stability is active, fires Dark Escape; otherwise casts Stability (Slot 1), waits briefly
;                    for the effect, then uses Dark Escape (Slot 5).
;                  - Elementalist: casts Feel No Pain (Slot 1) and Frigid Armor (Slot 6) if not hexed with Backfire.
;                  - Others: casts Feel No Pain (Slot 1).
; Related........: AddOns_GetHasEffect, AddOns_UseSkillEx
; ===============================================================================================================================
Func ApplyDefensiveBuffs()
	Switch $g_i_PlayerProfession
		Case $GC_I_PROFESSION_ASSASSIN
			If AddOns_GetHasEffect($GC_I_SKILL_ID_DWARVEN_STABILITY, $g_p_Player) Then
				AddOns_UseSkillEx(5) ; Player - Dark Escape
			Else
				If AddOns_UseSkillEx(1) Then ; Player - Dwarven Stability
					Local $l_h_Timeout = TimerInit()
					While Not AddOns_GetHasEffect($GC_I_SKILL_ID_DWARVEN_STABILITY, $g_p_Player) And TimerDiff($l_h_Timeout) < 250
						Sleep(50)
					WEnd
					AddOns_UseSkillEx(5) ; Player - Dark Escape
				EndIf
			EndIf

		Case $GC_I_PROFESSION_ELEMENTALIST
			AddOns_UseSkillEx(1) ; Player - Feel No Pain
			If Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - Frigid Armor

		Case Else
			AddOns_UseSkillEx(1) ; Player - Feel No Pain
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: StayAlive
; Description....: High-level sustain routine. Opens with adrenaline utility, applies defensive buffs, then performs profession-
;                  specific healing/triage using SurvivalTriage() and targeted self-heals.
; Syntax.........: StayAlive ( $a_b_HeroSupport = False )
; Parameters.....: $a_b_HeroSupport - If True, SurvivalTriage may trigger hero micro for additional support.
; Return values..: None
; Author.........: KleuTSchi
; Remarks........: - Always uses "To the Limit!" (Slot 3) first and ApplyDefensiveBuffs().
;                  - Per-profession handling:
;                    * Assassin/Dervish/Ranger: run SurvivalTriage(); if not at max HP, cast Slot 6 self-sustain.
;                    * Warrior/Paragon: triage; at ≤ 90% HP use Healing Signet (Slot 6).
;                    * Ritualist: triage; at ≤ 90% HP and not Backfired, use MBaS (Slot 6).
;                    * Monk: triage; if not at max HP and not Backfired, use Healing Breeze (Slot 6).
;                    * Mesmer: triage; at ≤ 90% HP and not Backfired, Ether Feast on nearest enemy (uses nearest-enemy helper).
;                    * Necromancer: triage; if not at max HP and HP ≥ 90% and not Backfired, Blood Renewal (Slot 6).
;                    * Elementalist: triage only.
; Related........: AddOns_GetHasEffect, AddOns_GetHP, AddOns_GetNearestAgent_EnemyLiving_NoSM, AddOns_UseSkillEx,
;                  ApplyDefensiveBuffs, SurvivalTriage
; ===============================================================================================================================
Func StayAlive($a_b_HeroSupport = False)
	AddOns_UseSkillEx(3) ; Player - "To the Limit!"
	ApplyDefensiveBuffs()

	Local $l_f_PlayerHP = AddOns_GetHP($g_p_Player)

	Switch $g_i_PlayerProfession
		Case $GC_I_PROFESSION_ASSASSIN, $GC_I_PROFESSION_DERVISH, $GC_I_PROFESSION_RANGER, $GC_I_PROFESSION_WARRIOR
			Local $l_b_MaxHP = SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
			If Not $l_b_MaxHP Then AddOns_UseSkillEx(6) ; Player - Shadow Refuge/Conviction/Troll Unguent/Conviction

        Case $GC_I_PROFESSION_PARAGON
            SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
            If $l_f_PlayerHP <= 0.9 Then AddOns_UseSkillEx(6) ; Player - Healing Signet  

		Case $GC_I_PROFESSION_RITUALIST
			SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
			If $l_f_PlayerHP <= 0.9 And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - MBaS

		Case $GC_I_PROFESSION_MONK
			Local $l_b_MaxHP = SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
			If Not $l_b_MaxHP Then
				If Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - Healing Breeze
			EndIf

		Case $GC_I_PROFESSION_MESMER
			SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
			If $l_f_PlayerHP <= 0.9 And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then
				AddOns_UseSkillEx(6, AddOns_GetNearestAgent_EnemyLiving_NoSM($g_p_Player)) ; Player - Ether Feast
			EndIf

		Case $GC_I_PROFESSION_NECROMANCER
			Local $l_b_MaxHP = SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
			If Not $l_b_MaxHP Then
				If $l_f_PlayerHP >= 0.9 And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - Blood Renewal
			EndIf

		Case $GC_I_PROFESSION_ELEMENTALIST
			SurvivalTriage($l_f_PlayerHP, $a_b_HeroSupport)
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: PostSpikeDefensives
; Description....: Applies immediate defensive skills after a spike to mitigate the risk of dying post spike.
; Syntax.........: PostSpikeDefensives ( )
; Parameters.....: None
; Return values..: None
; Author.........: KleuTSchi
; Remarks........: - Uses profession-specific sustain skills, caster professions check for Backfire where necessary.
; Related........: AddOns_GetHasEffect, AddOns_GetHP, AddOns_UseSkillEx
; ===============================================================================================================================
Func PostSpikeDefensives()
	Switch $g_i_PlayerProfession
		Case $GC_I_PROFESSION_ASSASSIN
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			AddOns_UseSkillEx(5) ; Player - Dark Escape
			AddOns_UseSkillEx(6) ; Player - Shadow Refuge
			
		Case $GC_I_PROFESSION_DERVISH
			AddOns_UseSkillEx(6) ; Player - Conviction
			AddOns_UseSkillEx(1) ; Player - Feel No Pain

		Case $GC_I_PROFESSION_RANGER
			If Not AddOns_UseSkillEx(8) Then AddOns_UseSkillEx(6)  ; Player - Healing Spring/Troll Unguent
			AddOns_UseSkillEx(1) ; Player - Feel No Pain
		
		Case $GC_I_PROFESSION_WARRIOR
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			AddOns_UseSkillEx(6) ; Player - Conviction
			AddOns_UseSkillEx(1) ; Player - Feel No Pain

		Case $GC_I_PROFESSION_PARAGON
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			AddOns_UseSkillEx(1) ; Player - Feel No Pain
			AddOns_UseSkillEx(6) ; Player - Healing Signet

		Case $GC_I_PROFESSION_RITUALIST, $GC_I_PROFESSION_MONK
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			If Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - MBaS/Healing Breeze
			AddOns_UseSkillEx(1) ; Player - Feel No Pain

		Case $GC_I_PROFESSION_ELEMENTALIST, $GC_I_PROFESSION_MESMER
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			AddOns_UseSkillEx(1) ; Player - Feel No Pain

		Case $GC_I_PROFESSION_NECROMANCER
			AddOns_UseSkillEx(8) ; Player - "I Will Survive!"
			AddOns_UseSkillEx(1) ; Player - Feel No Pain
			If AddOns_GetHP($g_p_Player) >= 0.7 And Not AddOns_GetHasEffect($GC_I_SKILL_ID_BACKFIRE, $g_p_Player) Then AddOns_UseSkillEx(6) ; Player - Blood Renewal
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: Speedboost
; Description....: Applies movement-speed boost according to profession. Assassin chains Dark Escape under Dwarven Stability;
;                  others use Soldier's Speed while upkeeping "To the Limit!"
; Syntax.........: Speedboost ( )
; Parameters.....: None
; Return values..: None
; Author.........: KleuTSchi
; Remarks........: - Assassin: if Dark Escape already active, returns True. Otherwise, if Dwarven Stability (Slot 1) is active 
;                    use Dark Escape (Slot 5); else, when Dark Escape is recharged, cast Dwarven Stability , wait briefly for
;                    the effect, then Dark Escape.
;                  - Others: uses "To the Limit!" (Slot 3) and Soldier's Speed (Slot 5) as generic speed boosts.
; Related........: AddOns_GetHasEffect, AddOns_GetIsRecharged, AddOns_UseSkillEx
; ===============================================================================================================================
Func Speedboost()
	Switch $g_i_PlayerProfession
		Case $GC_I_PROFESSION_ASSASSIN
			If AddOns_GetHasEffect($GC_I_SKILL_ID_DARK_ESCAPE, $g_p_Player) Then Return
			If AddOns_GetHasEffect($GC_I_SKILL_ID_DWARVEN_STABILITY, $g_p_Player) Then
				AddOns_UseSkillEx(5)
			Else
				If AddOns_GetIsRecharged(5) And AddOns_UseSkillEx(1) Then
					$l_h_Timeout = TimerInit()
					While Not AddOns_GetHasEffect($GC_I_SKILL_ID_DWARVEN_STABILITY, $g_p_Player) And TimerDiff($l_h_Timeout) < 250
						Sleep(50)
					WEnd
					AddOns_UseSkillEx(5)
				EndIf
			EndIf
		Case Else
			AddOns_UseSkillEx(3)
			AddOns_UseSkillEx(5)
	EndSwitch
EndFunc   ;==>Speedboost
#EndRegion PlayerActions

#Region Heartbeat
; #FUNCTION# ====================================================================================================================
; Name...........: FailHeartbeat
; Description....: Handles fatal heartbeat failures: logs, flags error state, disables hooks,
;                  and terminates the game process if still present.
; Syntax.........: FailHeartbeat ( $a_s_Where )
; Parameters.....: $a_s_Where - String : Context/location for the failure log.
; Return values..: Success - False
; Author.........: KleuTSchi
; Remarks........: - Clears initialization and heartbeat flags before cleanup.
;                  - Waits up to 5s for the process to close.
; Related........: AddOns_Out, GUI_SetBotState, DisableWinEventHook, ProcessClose, ProcessExists, ProcessWaitClose
; ===============================================================================================================================
Func FailHeartbeat($a_s_Where)
	$g_b_BotInitialized = False
    $g_b_Heartbeat = False

    AddOns_Out("[ERR] Heartbeat failure at: " & $a_s_Where)
	GUI_SetBotState($GC_I_BOTSTATE_ERROR)
    DisableWinEventHook()

    If ProcessExists($g_i_GWProcessId) Then
        ProcessClose($g_i_GWProcessId)
        ProcessWaitClose($g_i_GWProcessId, 5000)
    EndIf

    Return False
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: IsAlive
; Description....: Verifies the game process is running; on failure triggers FailHeartbeat.
; Syntax.........: IsAlive ( $a_s_Where )
; Parameters.....: $a_s_Where - String : Context used if a failure is reported.
; Return values..: Success - True
;                  Failure - False
; Author.........: KleuTSchi
; Remarks........: - Uses AddOns_GWRunning() as the single source of truth.
; Related........: AddOns_GWRunning, FailHeartbeat
; ===============================================================================================================================
Func IsAlive($a_s_Where)
    $g_b_Heartbeat = AddOns_GWRunning()
    If $g_b_Heartbeat Then Return True
    Return FailHeartbeat($a_s_Where)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: HeartbeatStep
; Description....: Invokes a named zero-arg function, validates liveness afterward, and logs
;                  any function error using the provided context label.
; Syntax.........: HeartbeatStep ( $a_s_Func, $a_s_Context )
; Parameters.....: $a_s_Func    - String : Function name to Call().
;                  $a_s_Context - String : Context for error reporting.
; Return values..: Success - True
;                  Failure - False (post-check failed or target function set @error)
; Author.........: KleuTSchi
; Remarks........: - Uses Call() for late binding; any non-zero @error from the target is logged.
;                  - Validates liveness via IsAlive() after the call; recovery is handled by the
;                    caller (e.g., main loop) based on the False return.
; Related........: AddOns_Out, Call, IsAlive
; ===============================================================================================================================
Func HeartbeatStep($a_s_Func, $a_s_Context)
    Call($a_s_Func)
	Local $l_i_Err = @error
    If Not IsAlive($a_s_Context & " (Post)") Then Return False
	If $l_i_Err Then 
		AddOns_Out("[ERR]" & $a_s_Context & " → Function call failed (" & $l_i_Err & ")")
		Return False
	EndIf
    Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: HeartbeatTravel
; Description....: Travels to the target map and confirms liveness post-travel. Disables rendering checkbox during load.
; Syntax.........: HeartbeatTravel ( $a_i_MapID )
; Parameters.....: $a_i_MapID - Integer : Destination map ID.
; Return values..: Success - True
;                  Failure - False
; Author.........: KleuTSchi, ZupaBlahq
; Remarks........: - Treats a travel timeout as fatal and reports via FailHeartbeat.
; Related........: AddOns_RndTravel, FailHeartbeat, GUICtrlSetState, IsAlive
; ===============================================================================================================================
Func HeartbeatTravel($a_i_MapID)
	GUICtrlSetState($g_i_CtrlID_CBX_Rendering, $GUI_DISABLE)
	Local $l_b_TravelRet = AddOns_RndTravel($a_i_MapID)
	GUICtrlSetState($g_i_CtrlID_CBX_Rendering, $GUI_ENABLE)
	
    If Not $l_b_TravelRet Then Return FailHeartbeat("RndTravel → Timeout")
    If Not IsAlive("RndTravel (Post)") Then Return False
    Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: HeartbeatEnterQuest
; Description....: Enters the quest area and confirms liveness afterward.
; Syntax.........: HeartbeatEnterQuest ( )
; Parameters.....: None
; Return values..: Success - True
;                  Failure - False
; Author.........: KleuTSchi
; Remarks........: - If EnterQuest() fails, reports via FailHeartbeat.
; Related........: EnterQuest, FailHeartbeat, IsAlive
; ===============================================================================================================================
Func HeartbeatEnterQuest()
    If Not EnterQuest() Then Return FailHeartbeat("EnterQuest → Failed to enter quest area")
    If Not IsAlive("EnterQuest (Post)") Then Return False
    Return True
EndFunc
#EndRegion Heartbeat

#Region ErrorHook
; #FUNCTION# ====================================================================================================================
; Name...........: EnableWinEventHook
; Description....: Installs a WinEvent hook for EVENT_OBJECT_SHOW and stores the hook handle.
; Syntax.........: EnableWinEventHook ( )
; Parameters.....: None
; Return values..: Success - 2  (hook created)
;                  No-op   - 1  (already active)
;                  Failure - 0  with @error set to:
;                            1 -> SetWinEventHook failed
; Author.........: KleuTSchi
; Remarks........: - Registers WinEventProc as a callback and marks $g_b_HookActive True.
;                  - Out-of-context, skip-own-process flags are used for the hook.
; Related........: AddOns_Out, DisableWinEventHook, DllCallbackGetPtr, DllCallbackRegister, WinEventProc
; ===============================================================================================================================
Func EnableWinEventHook()
    If $g_h_WinEventHook_Show Then Return 1
    $g_h_Callback = DllCallbackRegister("WinEventProc", "none", "handle;dword;hwnd;long;long;dword;dword")
    Local $l_p_Callback = DllCallbackGetPtr($g_h_Callback)

    Local $l_av_Call = DllCall("user32.dll", "handle", "SetWinEventHook", _
        "uint", $EVENT_OBJECT_SHOW, _
        "uint", $EVENT_OBJECT_SHOW, _
        "ptr", 0, _
        "ptr", $l_p_Callback, _
        "dword", 0, _
        "dword", 0, _
        "uint", BitOR($WINEVENT_OUTOFCONTEXT, $WINEVENT_SKIPOWNPROCESS))

    If @error Or Not $l_av_Call[0] Then
        AddOns_Out("SetWinEventHook failed. @error = " & @error)
        Return SetError(1, 0, 0)
    EndIf

    $g_h_WinEventHook_Show = $l_av_Call[0]
	$g_b_HookActive = True
    Return 2
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: DisableWinEventHook
; Description....: Unhooks the WinEvent hook and frees the registered callback.
; Syntax.........: DisableWinEventHook ( )
; Parameters.....: None
; Return values..: Success - 2  (hook removed)
;                  No-op   - 1  (no active hook)
; Author.........: KleuTSchi
; Remarks........: - Sets $g_b_HookActive False, calls UnhookWinEvent, then DllCallbackFree.
;                  - Clears global handles to avoid reuse.
; Related........: DllCallbackFree, EnableWinEventHook
; ===============================================================================================================================
Func DisableWinEventHook()
    If Not $g_h_WinEventHook_Show Then Return 1
	$g_b_HookActive = False
    DllCall("user32.dll", "bool", "UnhookWinEvent", "handle", $g_h_WinEventHook_Show)
    $g_h_WinEventHook_Show = 0
    If $g_h_Callback Then 
        DllCallbackFree($g_h_Callback)
        $g_h_Callback = 0
    EndIf
    Return 2
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: WinEventProc
; Description....: Hook callback for window-show events. Detects the game crash dialog and closes its process if it
;                  belongs to this automation.
; Syntax.........: WinEventProc ( $a_h_Hook, $a_i_Event, $a_h_Wnd, $a_i_ObjectID, $a_i_ChildID, $a_i_EventThread, $a_i_EventTime )
; Parameters.....: $a_h_Hook        - Handle : Hook handle (unused).
;                  $a_i_Event       - DWord  : Event ID (expects EVENT_OBJECT_SHOW).
;                  $a_h_Wnd         - HWnd   : Window handle.
;                  $a_i_ObjectID    - Long   : Object identifier (expects OBJID_WINDOW).
;                  $a_i_ChildID     - Long   : Child ID (expects 0).
;                  $a_i_EventThread - DWord  : Origin thread (unused).
;                  $a_i_EventTime   - DWord  : Timestamp (unused).
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Returns immediately if hook not active or window checks fail.
;                  - Verifies class name and title match known crash dialog values.
;                  - Ensures the dialog's parent PID equals @AutoItPID before closing.
; Related........: _WinAPI_GetParentProcess, _WinAPI_IsWindow, DllCall, ProcessClose
; ===============================================================================================================================
Func WinEventProc($a_h_Hook, $a_i_Event, $a_h_Wnd, $a_i_ObjectID, $a_i_ChildID, $a_i_EventThread, $a_i_EventTime)
    If Not $g_b_HookActive Then Return
    If Not _WinAPI_IsWindow($a_h_Wnd) Then Return

    If $a_h_Wnd = $g_h_GWWindow And Ui_GetRenderDisabled() Then
        WinSetState($g_h_GWWindow, "", @SW_HIDE)
		Memory_Clear()
        Return
    EndIf

    If $a_i_ObjectID <> $OBJID_WINDOW Or $a_i_ChildID <> 0 Then Return

    DllCall("user32.dll", "int", "GetClassNameW", "hwnd", $a_h_Wnd, "ptr", $g_p_ClassBuffer, "int", 256)
    If DllStructGetData($g_d_ClassBuffer, 1) <> $GC_S_CRASH_CLASS Then Return
	
	Local $l_av_LenCall = DllCall("user32.dll", "int", "GetWindowTextLengthW", "hwnd", $a_h_Wnd)
	If @error Then Return
	Local $l_i_Len = $l_av_LenCall[0]
	If $l_i_Len <> $GC_I_CRASH_TITLE_LEN Then Return

    DllCall("user32.dll", "int", "GetWindowTextW", "hwnd", $a_h_Wnd, "ptr", $g_p_TitleBuffer, "int", 256)
	If DllStructGetData($g_d_TitleBuffer, 1) <> $GC_S_CRASH_TITLE Then Return

    Local $l_av_PIDCall = DllCall("user32.dll", "dword", "GetWindowThreadProcessId", "hwnd", $a_h_Wnd, "dword*", 0)
    If @error Then Return
    Local $l_i_PID = $l_av_PIDCall[2]
    If $l_i_PID <= 0 Then Return

    Local $l_i_PPID = _WinAPI_GetParentProcess($l_i_PID)
    If @error Then Return
		
	If $l_i_PPID <> @AutoItPID Then Return

    ProcessClose($l_i_PID)
EndFunc
#EndRegion ErrorHook

#Region RestartGW
; #FUNCTION# ====================================================================================================================
; Name...........: ResetVariables
; Description....: Reinitializes global runtime state to defaults, including pointers, caches, indices, and last-action trackers.
; Syntax.........: ResetVariables ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Sets the client base address to a fixed constant
;                  - Clears assertion/label caches and last-* trackers to avoid stale reads.
; Related........: RestartGW
; ===============================================================================================================================
Func ResetVariables()
	$g_p_GWBaseAddress = 0x00C50000

	$g_amx_AssertionCache = 0
	Dim $g_amx_AssertionCache[0][3]

	$g_ai2_Sections = 0
	Dim $g_ai2_Sections[5][2]

	$g_amx2_Labels = 0
	Dim $g_amx2_Labels[1][2]
	$g_amx2_Labels[0][0] = 0
	$g_amx2_Labels[0][1] = 0

	$g_i_LastSkillUsed = 0
	$g_i_LastSkillTarget = 0
	$g_i_LastStatus = 0
	$g_i_LastAttributeModified = -1
	$g_i_LastAttributeValue = -1
	$g_i_LastTransactionType = -1
	$g_i_LastItemID = 0
	$g_i_LastQuantity = 0
	$g_i_LastPrice = 0
	$g_i_LastTargetID = 0
	$g_f_LastMoveX = 0
	$g_f_LastMoveY = 0
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: RestartGW
; Description....: Restarts the bot and game session after a delay, reinitializes globals, reinstalls crash hook,
;                  and performs initial party setup.
; Syntax.........: RestartGW ( )
; Parameters.....: None
; Return values..: None (procedure). Uses @error from GUI_StartBot on failure.
; Author.........: KleuTSchi
; Remarks........: - Waits 15s before restarting; tracks attempts with a static counter.
;                  - On failure, closes any child Gw.exe processes owned by this script.
;                  - Respects a GUI “Rendering” toggle; hook is enabled before GUI title set.
; Related........: AddOns_Out, Ui_ToggleRendering, GUI_GUICtrlIsChecked, GUI_RenderingCheck, GUI_SetBotState, GUI_StartBot,
;                  GUICtrlRead, EnableWinEventHook, HeartbeatStep, ProcessClose, ProcessList, ProcessWaitClose, ResetVariables,
;                  SetupEncounter, Sleep, WinSetTitle, _WinAPI_GetParentProcess
; ===============================================================================================================================
Func RestartGW()
	Static $s_i_RestartAttempts = 0
	Local Const $LC_I_DELAY = 15000

	AddOns_Out("[INFO] Restarting account after a short delay (" & ($LC_I_DELAY / 1000) & " Seconds)")
	Sleep($LC_I_DELAY)

	ResetVariables()
	
	Local $l_s_Character = GUI_StripCharacterEnum(GUICtrlRead($g_i_CtrlID_Combo_CharInput))
	If GUI_StartBot($l_s_Character, True) Then
        $g_b_BotInitialized = True
        $g_b_PauseRequested = False
        $g_b_ResumeRequested = False
        $g_b_AutoTradeReady = False
        $g_b_AutoTradeLeave = False
		$s_i_RestartAttempts = 0

		EnableWinEventHook()
        WinSetTitle($g_h_MainGUI, "", "Encounter Re:Built - " & $l_s_Character)

		GUI_RenderingCheck()
		GUI_SetBotState($GC_I_BOTSTATE_RUN)

		AddOns_Out("[INFO] Preparing party setup")
		HeartbeatStep("SetupEncounter", "SetupEncounter")
    Else
		Local $l_i_Err = @error
		$s_i_RestartAttempts += 1
        AddOns_Out("[ERR] Restart of bot failed (ERR:" & $l_i_Err & "), attempt #" & $s_i_RestartAttempts)

		Local $l_av_ProcessList = ProcessList("Gw.exe")
        If $l_av_ProcessList[0][0] > 0 Then
            For $i = 1 To $l_av_ProcessList[0][0]
                Local $l_i_PID = $l_av_ProcessList[$i][1]
                If $l_i_PID <= 0 Then ContinueLoop

                Local $l_i_PPID = _WinAPI_GetParentProcess($l_i_PID)
                If $l_i_PPID = 0 Or @error Then ContinueLoop

                If $l_i_PPID = @AutoItPID Then ProcessClose($l_i_PID)
            Next
        EndIf

		Sleep($LC_I_DELAY)
    EndIf
EndFunc
#EndRegion RestartGW

#Region Main
; #FUNCTION# ====================================================================================================================
; Name...........: Main
; Description....: Entry point. Initializes UI and tables, waits for bot init, performs initial setup, then runs the main loop 
;                  to handle heartbeat, trading, opening, running, and idling.
; Syntax.........: Main ( )
; Parameters.....: None
; Return values..: None (procedure)
; Author.........: KleuTSchi
; Remarks........: - Blocks on $g_b_BotInitialized before first SetupEncounter.
;                  - Uses a 250 ms tick; RestartGW() is invoked if heartbeat stops.
;                  - Honors pause/resume and auto-trade-leave flags; state-driven via GUI_GetBotState().
; Related........: AddOns_Out, GUI_CreateMainGUI, GUI_GetBotState, GUI_LoadBotSettingsFromINI, GUI_SetBotState, GUI_UpdateStatistics,
;                  ItemFilter_InitPatterns, Pathing_CreateRouteTable, AutoTrade, HeartbeatStep, LeaveTradeSpot, OpenLockboxes,
;                  Quest18, RestartGW
; ===============================================================================================================================
Func Main()
    GUI_CreateMainGUI()
    ItemFilter_InitPatterns()
    Pathing_CreateRouteTable()

    While Not $g_b_BotInitialized
        Sleep(1000)
    WEnd

	AddOns_Out("[INFO] Preparing party setup")
    HeartbeatStep("SetupEncounter", "SetupEncounter")
	If $g_b_PauseRequested Then
		$g_b_PauseRequested = False
		GUI_SetBotState($GC_I_BOTSTATE_IDLE)
	EndIf

    While True
        If Not $g_b_Heartbeat Then
            RestartGW()
            ContinueLoop
        EndIf

        If $g_b_AutoTradeLeave Then
			$g_b_AutoTradeLeave = False
            LeaveTradeSpot()
            ContinueLoop
        EndIf

        Switch GUI_GetBotState()
			Case $GC_I_BOTSTATE_RUN
				Quest18()
				GUI_UpdateStatistics()
				If $g_b_PauseRequested Then
					$g_b_PauseRequested = False
					GUI_SetBotState($GC_I_BOTSTATE_IDLE)
				EndIf
				ContinueLoop

            Case $GC_I_BOTSTATE_OPEN
                OpenLockboxes()
                If $g_b_ResumeRequested Then
                    $g_b_ResumeRequested = False
                    GUI_SetBotState($GC_I_BOTSTATE_RUN)
                    ContinueLoop
                EndIf
                ContinueLoop

            Case $GC_I_BOTSTATE_TRADE
                AutoTrade()
                If $g_b_ResumeRequested Then
                    $g_b_ResumeRequested = False
                    GUI_SetBotState($GC_I_BOTSTATE_RUN)
                    ContinueLoop
                EndIf
                ContinueLoop

            Case $GC_I_BOTSTATE_IDLE
				; Idle
                If $g_b_ResumeRequested Then
                    $g_b_ResumeRequested = False
                    GUI_SetBotState($GC_I_BOTSTATE_RUN)
                    ContinueLoop
                EndIf
        EndSwitch

		Sleep(250)
    WEnd
EndFunc
#EndRegion Main

; #SCRIPT ENTRY# ================================================================================================================
Main()