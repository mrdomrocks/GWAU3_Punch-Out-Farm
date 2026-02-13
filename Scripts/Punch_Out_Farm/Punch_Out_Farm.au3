#cs
;;; Punch Out Farmer = Created by MrDomRocks
; Hard Mode and Normal Mode
: Punch and Run
#ce
#RequireAdmin

#Region Includes
#include "..\..\API\_GwAu3.au3"
#include "GwAu3_AddOns_Punch_Out_Farm.au3"
#include "GUI_Punch_Out_Farm.au3"
#include "..\..\API\Plugins\UtilityAI\_UtilityAI.au3"
#include "..\..\API\Plugins\Pathfinder\Pathfinder_Movements.au3"
#EndRegion Includes

#Region Global Constants & Variables
; === Pathfinding DLL ===
Global $DLL_PATH = "..\..\API\Pathfinding\GWPathfinder.dll"

; === Bot Settings ===
Global Const $BotTitle = "Punch Out Farmer by MrDomRocks"
Global $ProcessID = ""
Global $BotRunning = False
Global $Bot_Core_Initialized = False
Global $g_s_MainCharName = ""

; === Map & Quest Constants ===
Global Const $MAP_ID_GUUNAR = 644
Global Const $MAP_ID_EoTN = 642
Global Const $FRONIS_QUEST = 856
Global Const $MAP_ID_FRONIS = 704
Global Const $QuestStateIncomplete = 0x000000001
Global Const $QuestStateComplete = 0x000000003

; === Dialog IDs ===
Global Const $Dialog_Intro = 0x835803
Global Const $Dialog_AcceptQuest = 0x835801
Global Const $Dialog_Enter = 0x85
Global Const $Dialog_Accept = 0x835807

; === Skill & Stats ===
Global Const $maxAllowdEnergy = 120
Global Const $intAdrenaline[7] = [0, 0, 0, 100, 250, 175, 0]
Global $g_i_Runs = 0
Global $g_i_Fails = 0
Global $g_i_Ales = 0
Global $g_i_StartTime = TimerInit()
Global $g_h_EditText = $ConsoleEdit ; Link to GUI control

; === Initialization ===
Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

; Populate Character Combo on Load
Local $sLogedChars = Scanner_GetLoggedCharNames()
If $sLogedChars <> "" Then
    GUICtrlSetData($CharacterChoiceCombo, $sLogedChars, StringSplit($sLogedChars, "|")[1])
EndIf
#EndRegion Global Constants & Variables

#Region Event Handlers
; =================================================================================================
; GUI Event Handlers
; Functions related to GUI interaction (Start/Stop, Refresh, Close)
; =================================================================================================

GUISetOnEvent($GUI_EVENT_CLOSE, "CloseBot", $Form1)
GUICtrlSetOnEvent($Start, "ToggleBot")
GUICtrlSetOnEvent($RefreshButton, "RefreshCharacters")
GUICtrlSetOnEvent($gHardModeCheckbox, "OnHardModeToggle")

Func RefreshCharacters()
    Local $sLogedChars = Scanner_GetLoggedCharNames()
    If $sLogedChars <> "" Then
        GUICtrlSetData($CharacterChoiceCombo, "|" & $sLogedChars, StringSplit($sLogedChars, "|")[1])
        Update("Character list refreshed")
    Else
        Update("No characters found")
    EndIf
EndFunc

Func ToggleBot()
    If Not $BotRunning Then
        Local $sChar = GUICtrlRead($CharacterChoiceCombo)
        If $sChar = "No character selected" Or $sChar = "" Then
            MsgBox(0, "Error", "Please select a character first!")
            Return
        EndIf

        If Not $Bot_Core_Initialized Then
            If Not Core_Initialize($sChar) Then
                MsgBox(0, "Error", "Failed to initialize bot core with character: " & $sChar)
                Return
            EndIf
            $Bot_Core_Initialized = True
            $g_s_MainCharName = $sChar
        EndIf

        $BotRunning = True
        GUICtrlSetData($Start, "Pause")
        Update("BotStarted")
    Else
        $BotRunning = False
        GUICtrlSetData($Start, "Start")
        Update("Paused")
    EndIf
EndFunc

Func CloseBot()
    Exit
EndFunc

Func OnHardModeToggle()
    If GUICtrlRead($gHardModeCheckbox) = $GUI_CHECKED Then
        MsgBox(64, "Hard Mode Advice", "For best performance your character should have:" & @CRLF & _
        "5x Stalwart Insignias" & @CRLF & _
        "Secondary Profession Assassin for Dagger Mastery" & @CRLF & _
        "Thunderfist Brass Knuckles with Sundering or Furious Mods" & @CRLF & _
        "Dagger Handle of Shelter" & @CRLF & _
        "Brawn over Brains Inscription")
    EndIf
EndFunc
#EndRegion Event Handlers

#Region Main Loop
; =================================================================================================
; Main Logic Loop
; Handles state switching between Outpost and Instance
; =================================================================================================

While 1
    If $BotRunning Then
        MainBotLoop()
    EndIf
    Sleep(100) ; Reduce CPU usage
WEnd

Func MainBotLoop()
    UpdateGUIStats()

    Local $l_i_CurrentMapID = Map_GetCharacterInfo("MapID")

    Switch $l_i_CurrentMapID
        Case $MAP_ID_GUUNAR
            HandleOutpost()
        Case $MAP_ID_FRONIS
            HandleInstance()
        Case Else
            Update("Traveling to Gunnar's Hold")
            Map_TravelTo($MAP_ID_GUUNAR)
            Sleep(5000)
        EndSwitch
EndFunc
#EndRegion Main Loop

#Region Outpost Logic
; =================================================================================================
; Outpost Logic
; Handles preparation, quest acceptance, and reward claiming
; =================================================================================================

Func HandleOutpost()
    Update("Handling Outpost Logic")

    ; Hard Mode Logic
    Local $bHardMode = (GUICtrlRead($gHardModeCheckbox) = $GUI_CHECKED)
    Local $bCurrentHM = Party_GetPartyContextInfo("IsHardMode")

    If $bHardMode And Not $bCurrentHM Then
        Update("Switching to Hard Mode")
        Game_SwitchMode(1)
        Sleep(3000) ; Wait for switch
    ElseIf Not $bHardMode And $bCurrentHM Then
        Update("Switching to Normal Mode")
        Game_SwitchMode(0)
        Sleep(3000) ; Wait for switch
    EndIf

    If CheckBagsFull() Then
        HandleMerchant()
    EndIf

    ; 1. Move to Kilroy
    Local $l_f_KilroyX = 17341.00
    Local $l_f_KilroyY = -4796.00
    
    If Agent_GetDistanceToXY($l_f_KilroyX, $l_f_KilroyY) > 250 Then
        Update("Moving to Kilroy...")
        Pathfinder_MoveTo($l_f_KilroyX, $l_f_KilroyY)
        Sleep(500)
        Return
    EndIf

    Update("Preparing for Quest")
    
    ; 2. Leave Party
    Party_KickAllHeroes()

    ; 3. Check Quest State
    Local $l_i_QuestState = Quest_GetQuestInfo($FRONIS_QUEST, "LogState")
    Update("Quest State: " & $l_i_QuestState)
    
    If $l_i_QuestState = $QuestStateComplete Then
        Update("Quest Completed - Claiming Reward")
        Local $KilroyID = GetNearestNPC($l_f_KilroyX, $l_f_KilroyY)
        If $KilroyID <> 0 Then
            Agent_ChangeTarget($KilroyID)
            Agent_GoNPC($KilroyID)
            Sleep(500)
            Game_Dialog($Dialog_Intro) ; Open dialog
            Sleep(500)
        EndIf
        ClaimReward()
        Return ; Restart logic
    EndIf

    ; 4. Handle Quest/Dialog Logic
    If Not EnterInstance($FRONIS_QUEST) Then
        Update("Failed to enter instance, retrying...")
        Sleep(1000)
    Else
        ; Wait for map change
        Update("Waiting for instance entry...")
        Local $timer = TimerInit()
        While Map_GetCharacterInfo("MapID") = $MAP_ID_GUUNAR
            Sleep(500)
            If TimerDiff($timer) > 15000 Then ExitLoop
        WEnd
    EndIf
EndFunc

Func EnterInstance($QuestID)
    Local $l_f_KilroyX = 17341.00
    Local $l_f_KilroyY = -4796.00
    
    Local $KilroyID = GetNearestNPC($l_f_KilroyX, $l_f_KilroyY)
    If $KilroyID = 0 Then
        Update("Kilroy not found!")
        Return False
    EndIf
    
    Agent_ChangeTarget($KilroyID)
    Agent_GoNPC($KilroyID)
    Sleep(1000)
    
    Update("Accepting Quest...")
    ; 1. Intro Dialog
    Game_Dialog($Dialog_Intro)
    Sleep(500)
    
    ; 2. Accept Quest
    Game_Dialog($Dialog_AcceptQuest)
    Update("Quest Accepted")
    Sleep(500)
    
    ; 3. Enter Instance
    Game_Dialog($Dialog_Enter)
    Sleep(1000)
    
    Return True
EndFunc
#EndRegion Outpost Logic

#Region Claim Reward Logic
Func ClaimReward()
    Game_Dialog($Dialog_Accept)
    Sleep(1000)
    Map_RndTravel($MAP_ID_GUUNAR)   
EndFunc
#EndRegion Claim Reward Logic

#Region Merchant Logic
Func CheckBagsFull()
    Local $l_i_EmptySlots = 0
    For $i = 1 To 4
        $l_i_EmptySlots += Item_GetBagInfo(Item_GetBagPtr($i), "EmptySlots")
    Next
    ; Trigger if 4 or fewer slots are empty (Covering the "3-4 empty slots" requirement)
    Return ($l_i_EmptySlots <= 4)
EndFunc

Func HandleMerchant()
    Update("Bags full, going to merchant...")
    Map_TravelTo($map_ID_EoTN)
    Sleep(2000)
    local $l_f_MerchX = -2748.00
    local $l_f_MerchY = 1019.00
   
    Local $MerchID = GetNearestNPC($l_f_MerchX, $l_f_MerchY)
    If $MerchID <> 0 Then
        Agent_ChangeTarget($MerchID)
        Agent_GoNPC($MerchID)
        Sleep(2000)
        
        If GUICtrlRead($gIdentifyCheckbox) = $GUI_CHECKED Then
            IdentifyCycle()
        EndIf
        
        If GUICtrlRead($gSellCheckbox) = $GUI_CHECKED Then
            ; Check for Identification Kit in Bag 1 Slot 2
            Local $l_p_Bag1 = Item_GetBagPtr(1)
            If $l_p_Bag1 <> 0 Then
                Local $l_p_Slot2 = Item_GetItemBySlot(1, 2)
                
                ; If slot is empty or contains wrong item, try to find one and move it there
                Local $bCorrectKit = False
                If $l_p_Slot2 <> 0 Then
                    If Item_GetItemInfoByPtr($l_p_Slot2, 'ModelID') = $GC_I_MODELID_IDENTIFICATION_KIT Then
                        $bCorrectKit = True
                    EndIf
                EndIf
                
                If Not $bCorrectKit Then
                    Update("Restocking ID Kit to Bag 1 Slot 2...")
                    ; Scan all bags for a kit
                    Local $bFound = False
                    For $b = 1 To 4
                        Local $l_p_Bag = Item_GetBagPtr($b)
                        If $l_p_Bag = 0 Then ContinueLoop
                        Local $l_i_Slots = Item_GetBagInfo($l_p_Bag, 'Slots')
                        For $s = 1 To $l_i_Slots
                            Local $l_p_Item = Item_GetItemBySlot($b, $s)
                            If $l_p_Item <> 0 And Item_GetItemInfoByPtr($l_p_Item, 'ModelID') = $GC_I_MODELID_IDENTIFICATION_KIT Then
                                Item_MoveItem($l_p_Item, 1, 2) ; Move to Bag 1 Slot 2
                                Sleep(500)
                                $bFound = True
                                ExitLoop 2
                            EndIf
                        Next
                    Next
                    
                    ; If still not found, buy one (if merchant window is open)
                    If Not $bFound Then
                        Update("Buying ID Kit...")
                        ; Assumes merchant window is open and kit is available
                        ; 2989 is the ModelID
                        Merchant_BuyItem($GC_I_MODELID_IDENTIFICATION_KIT, 1) 
                        Sleep(1000)
                        ; Try to move it again after buying
                        For $b = 1 To 4
                            Local $l_p_Bag = Item_GetBagPtr($b)
                            If $l_p_Bag = 0 Then ContinueLoop
                            Local $l_i_Slots = Item_GetBagInfo($l_p_Bag, 'Slots')
                            For $s = 1 To $l_i_Slots
                                Local $l_p_Item = Item_GetItemBySlot($b, $s)
                                If $l_p_Item <> 0 And Item_GetItemInfoByPtr($l_p_Item, 'ModelID') = $GC_I_MODELID_IDENTIFICATION_KIT Then
                                    Item_MoveItem($l_p_Item, 1, 2)
                                    Sleep(500)
                                    ExitLoop 2
                                EndIf
                            Next
                        Next
                    EndIf
                EndIf
            EndIf

            SellCycle()
        EndIf
    Else
        Update("Merchant not found!")
    EndIf
EndFunc

Func IdentifyCycle()
    Update("Identifying items...")
    Local $l_a_Bags = [1, 2, 3, 4]
    For $bagIndex In $l_a_Bags
        Local $l_p_Bag = Item_GetBagPtr($bagIndex)
        If $l_p_Bag = 0 Then ContinueLoop
        Local $l_i_Slots = Item_GetBagInfo($l_p_Bag, 'Slots')
        For $slot = 1 To $l_i_Slots
            Local $l_p_Item = Item_GetItemBySlot($bagIndex, $slot)
            If $l_p_Item = 0 Then ContinueLoop
            
            Local $l_b_Identified = Item_GetItemInfoByPtr($l_p_Item, 'IsIdentified')
            If Not $l_b_Identified Then
                Item_IdentifyItem($l_p_Item, "Normal")
                Sleep(250)
            EndIf
        Next
    Next
EndFunc

Func SellCycle()
    Update("Selling items...")
    Local $l_a_Bags = [1, 2, 3, 4] 
    For $bagIndex In $l_a_Bags
        Local $l_p_Bag = Item_GetBagPtr($bagIndex)
        If $l_p_Bag = 0 Then ContinueLoop
        Local $l_i_Slots = Item_GetBagInfo($l_p_Bag, 'Slots')
        For $slot = 1 To $l_i_Slots
            Local $l_p_Item = Item_GetItemBySlot($bagIndex, $slot)
            If $l_p_Item = 0 Then ContinueLoop
            
            Local $l_b_Identified = Item_GetItemInfoByPtr($l_p_Item, 'IsIdentified')
            Local $l_i_Rarity = Item_GetItemInfoByPtr($l_p_Item, 'Rarity')
            
            ; Only sell White, Blue, Purple
            If $l_b_Identified And ($l_i_Rarity = $GC_I_RARITY_WHITE Or $l_i_Rarity = $GC_I_RARITY_BLUE Or $l_i_Rarity = $GC_I_RARITY_PURPLE) Then
                 ; Exclude Kits and Dyes
                 Local $l_i_Type = Item_GetItemInfoByPtr($l_p_Item, 'ItemType')
                 Local $l_i_ModelID = Item_GetItemInfoByPtr($l_p_Item, 'ModelID')
                 
                 If $l_i_Type <> $GC_I_TYPE_KIT And $l_i_Type <> $GC_I_TYPE_DYE Then
                    ; Exclude Lockpicks, Stone Summit Emblems, Dwarven Ales, and Superior Identification Kits
                    If $l_i_ModelID <> 22751 And $l_i_ModelID <> 27044 And $l_i_ModelID <> 5585 And $l_i_ModelID <> 24593 And $l_i_ModelID <> $GC_I_MODELID_SUPERIOR_IDENTIFICATION_KIT And $l_i_ModelID <> $GC_I_MODELID_IDENTIFICATION_KIT Then

                        Merchant_SellItem($l_p_Item)
                        Sleep(250)
                    EndIf
                 EndIf
            EndIf
        Next
    Next
EndFunc
#EndRegion Merchant Logic
; =================================================================================================
; Instance Logic
; Handles the main farming sequence inside Fronis Irontoe's Lair
; =================================================================================================

Func HandleInstance()
    RunPunchOutSequence()
EndFunc

Func RunPunchOutSequence()
    ; Move to safe start position
    Pathfinder_MoveTo(-16919.56, -13485.12)
    Sleep(500)
    
    ; Cache skills ONCE at start
    UAI_CacheSkillBar()

    ; Fight initial spawns
    Update("Fighting at start position")
    Brawling_ClearArea(1500)
    Update("Started")
    PickUpLoot()
    Local $aWaypoints[10][2] = [ _
        [-15115.72, -15375.61], _
        [-11299.54, -16402.40], _
        [-7284.53, -16235.58], _
        [-4397.42, -16123.15], _
        [-1385.20, -14400.23], _
        [505.33, -14073.99], _
        [2959.12, -15991.76], _
        [5740.82, -15543.48], _
        [7157.02, -15755.44], _
        [12249.79, -16291.74]]
        
    For $i = 0 To UBound($aWaypoints) - 1
        Local $tX = $aWaypoints[$i][0]
        Local $tY = $aWaypoints[$i][1]
        
        ; Move with automated combat check
        Local $timer = TimerInit()
        Local $bReached = False
        
        While True
            ; Check if we are close enough (Manual check to fix false timeouts)
            Local $fDist = Agent_GetDistanceToXY($tX, $tY)
            If $fDist < 150 Then
                $bReached = True
                ExitLoop
            EndIf
            
            ; Move command
            Pathfinder_MoveTo($tX, $tY)
            
            ; Check for loot if safe
            If GetNumberOfFoesInRangeOfAgent(-2, 1000) < 1 Then
                PickUpLoot()
            EndIf
            
            ; Timeout check
            If TimerDiff($timer) > 25000 Then 
                Update("Failed to reach waypoint " & $i + 1 & " - Timeout")
                ExitLoop
            EndIf
                       
            ; Explicit combat check during movement
            If GetNearestEnemyToCoords(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), 1000) <> 0 Then
                ; Attempt to use Skill 1 (Sprint/Block) while moving if available
                If Brawling_IsRecharged(1) Then
                    Brawling_UseSkillEx(1, -2, 200)
                EndIf
                
                Brawling_ClearArea(1500)
            EndIf        
            Sleep(500)
               WEnd
        
        ; Clear area at waypoint
        ; Update("Fighting at waypoint " & $i + 1)
        Brawling_ClearArea(1500)
              
        ; Pause based on health
        Local $fHP = Agent_GetAgentInfo(-2, "HP")
        If $fHP < 1.0 Then
             Update("Resting until full health...")
             Do
                 Sleep(500)
                                  $fHP = Agent_GetAgentInfo(-2, "HP")
             Until $fHP >= 0.95 ; Wait until 95%+ health
             Update("Health recovered. Resuming...")
        EndIf
    Next
    
    Sleep(100)
    Update("Opening final chest")
    
    ; Move to and interact with final signpost
    Local $l_i_SignpostID = GetNearestSignpostToCoords(13275, -16039)
    If $l_i_SignpostID <> 0 Then
        Update("Interacting with final signpost")
        Agent_ChangeTarget($l_i_SignpostID)
        Pathfinder_MoveTo(Agent_GetAgentInfo($l_i_SignpostID, "X"), Agent_GetAgentInfo($l_i_SignpostID, "Y"))
        
        ; Loot check at final signpost
        If GetNumberOfFoesInRangeOfAgent(-2, 1000) < 1 Then
            PickUpLoot()
        EndIf
        
        Sleep(500)
        
        ; Keep trying to open chest until it's open (Gadget State changes)
        Local $l_timerChest = TimerInit()
        Do
            Agent_GoSignpost($l_i_SignpostID)
            Sleep(1000)
        Until TimerDiff($l_timerChest) > 5000 
    Else
        Update("Signpost not found! Checking alternative location...")
    EndIf
    
    Sleep(2000)
    Update("Fronis Instance Completed")
    Update("Picking up ale")   
    
    ; Loop until no more relevant loot is found
    Local $l_timerLoot = TimerInit()
    While True
        PickUpLoot()
        Sleep(500)
        
        ; Check if there is any lootable item left nearby
        Local $bLootLeft = False
        Local $lAgentArray = Item_GetItemArray()
        Local $maxitems = $lAgentArray[0]
        
        For $i = 1 To $maxitems
            Local $aItemPtr = $lAgentArray[$i]
            If CanPickUp($aItemPtr) Then
                $bLootLeft = True
                ExitLoop
            EndIf
        Next
        
        If Not $bLootLeft Then ExitLoop
        If TimerDiff($l_timerLoot) > 10000 Then ExitLoop ; Safety timeout 10s
    WEnd

    $g_i_Runs += 1
    $g_i_Ales += 1 ; Increment count (Assuming success)
    UpdateGUIStats()
    
    Update("Run complete. Resigning...")
    Map_TravelTo($MAP_ID_GUUNAR)
    
    Sleep(5000)
EndFunc
#Region Helper Functions
; =================================================================================================
; Helper Functions
; General utility functions for finding targets, updating GUI, etc.
; =================================================================================================

Func Update($sText)
    _GUICtrlStatusBar_SetText($StatusBar1, $sText, 0)
    Out($sText)
EndFunc

Func UpdateGUIStats()
    GUICtrlSetData($RunsLabel, "Runs: " & $g_i_Runs)
    ; GUICtrlSetData($FailuresLabel, "Failures: " & $g_i_Fails)
    GUICtrlSetData($Ales, "Ales: " & $g_i_Ales)
    
    Local $iDiff = TimerDiff($g_i_StartTime)
    Local $iHours = Floor($iDiff / 3600000)
    Local $iMins = Floor(Mod($iDiff, 3600000) / 60000)
    Local $iSecs = Floor(Mod($iDiff, 60000) / 1000)
    GUICtrlSetData($TimeLabel, StringFormat("Time: %02d:%02d:%02d", $iHours, $iMins, $iSecs))
EndFunc

; Finds the nearest Gadget (Chest/Signpost) to specific coords
Func GetNearestSignpostToCoords($a_f_X, $a_f_Y)
    Local $l_i_MaxAgents = Agent_GetMaxAgents()
    Local $l_i_BestID = 0
    Local $l_f_MinDist = 500 ; Max range to search
    
    For $i = 1 To $l_i_MaxAgents
        Local $l_p_Agent = Agent_GetAgentPtr($i)
        If $l_p_Agent = 0 Then ContinueLoop
        
        ; Filter for Gadgets (0x200) only
        Local $l_i_Type = Agent_GetAgentInfo($i, "Type")
        If $l_i_Type <> 0x200 Then ContinueLoop
        
        Local $l_f_AgentX = Agent_GetAgentInfo($i, "X")
        Local $l_f_AgentY = Agent_GetAgentInfo($i, "Y")
        
        Local $l_f_Dist = Sqrt(($a_f_X - $l_f_AgentX)^2 + ($a_f_Y - $l_f_AgentY)^2)
        
        If $l_f_Dist < $l_f_MinDist Then
            $l_f_MinDist = $l_f_Dist
            $l_i_BestID = $i
        EndIf
    Next
    
    Return $l_i_BestID
EndFunc

; Finds the nearest Enemy (Allegiance 0x3)
Func GetNearestEnemyToCoords($a_f_X, $a_f_Y, $a_f_Range)
    Local $l_i_MaxAgents = Agent_GetMaxAgents()
    Local $l_i_BestID = 0
    Local $l_f_MinDist = $a_f_Range
    
    For $i = 1 To $l_i_MaxAgents
        Local $l_p_Agent = Agent_GetAgentPtr($i)
        If $l_p_Agent = 0 Then ContinueLoop
        
        If Agent_GetAgentInfo($i, "HP") <= 0 Then ContinueLoop
        If Agent_GetAgentInfo($i, "Allegiance") <> 0x3 Then ContinueLoop ; Enemy = 0x3
        
        Local $l_f_AgentX = Agent_GetAgentInfo($i, "X")
        Local $l_f_AgentY = Agent_GetAgentInfo($i, "Y")
        
        Local $l_f_Dist = Sqrt(($a_f_X - $l_f_AgentX)^2 + ($a_f_Y - $l_f_AgentY)^2)
        
        If $l_f_Dist < $l_f_MinDist Then
            $l_f_MinDist = $l_f_Dist
            $l_i_BestID = $i
        EndIf
    Next
    
    Return $l_i_BestID
EndFunc

; Finds the nearest Friendly NPC (Allegiance 0x6)
Func GetNearestNPC($a_f_X, $a_f_Y)
    Local $l_i_MaxAgents = Agent_GetMaxAgents()
    Local $l_i_BestID = 0
    Local $l_f_MinDist = 500
    
    For $i = 1 To $l_i_MaxAgents
        Local $l_p_Agent = Agent_GetAgentPtr($i)
        If $l_p_Agent = 0 Then ContinueLoop
        
        Local $l_i_Allegiance = Agent_GetAgentInfo($i, "Allegiance")
        If $l_i_Allegiance <> 0x6 Then ContinueLoop
        
        Local $l_f_AgentX = Agent_GetAgentInfo($i, "X")
        Local $l_f_AgentY = Agent_GetAgentInfo($i, "Y")
        
        Local $l_f_Dist = Sqrt(($a_f_X - $l_f_AgentX)^2 + ($a_f_Y - $l_f_AgentY)^2)
        
        If $l_f_Dist < $l_f_MinDist Then
            $l_f_MinDist = $l_f_Dist
            $l_i_BestID = $i
        EndIf
    Next
    
    Return $l_i_BestID
EndFunc
#EndRegion Helper Functions
