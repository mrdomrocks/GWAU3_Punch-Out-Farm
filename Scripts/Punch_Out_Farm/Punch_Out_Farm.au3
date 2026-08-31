#cs
;;; Punch Out Farmer = Created by MrDomRocks
; Hard Mode and Normal Mode
: Punch and Run
#ce
#RequireAdmin

; === Initialization (must run before GUI/control creation for OnEvent handlers) ===
Opt("GUIOnEventMode", True)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

#Region Includes
#include "..\..\API\_GwAu3.au3"
#include "GwAu3_AddOns_Punch_Out_Farm.au3"
#include "GUI_Punch_Out_Farm.au3"
#include "..\..\API\Plugins\UtilityAI\_UtilityAI.au3"
#include "Security.au3"
#include "PunchOut_Launcher.au3"
#include "GwAu3_PunchOut_GUI_Logic.au3"
#EndRegion Includes

#Region Global Constants & Variables
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
Global $g_i_Successes = 0
Global $g_i_Fails = 0
Global $g_i_Ales = 0
Global $g_i_StartTime = TimerInit()
Global $g_h_EditText = $ConsoleEdit ; Link to GUI control

; Initialize Character List
GUI_LoadCharacterList()
#EndRegion Global Constants & Variables

#Region Event Handlers
; =================================================================================================
; GUI Event Handlers
; Functions related to GUI interaction (Start/Stop, Refresh, Close)
; =================================================================================================

GUISetOnEvent($GUI_EVENT_CLOSE, "CloseBot", $Form1)
GUICtrlSetOnEvent($Start, "ToggleBot")
GUICtrlSetOnEvent($gHardModeCheckbox, "OnHardModeToggle")
GUICtrlSetOnEvent($gRenderingCheckbox, "OnRenderingToggle")

; Registered Characters Events
GUICtrlSetOnEvent($g_i_CtrlID_Button_Add, "GUI_Main_OnAdd")
GUICtrlSetOnEvent($g_i_CtrlID_Button_Edit, "GUI_Main_OnEdit")
GUICtrlSetOnEvent($g_i_CtrlID_Button_Remove, "GUI_Main_OnRemove")

Func ToggleBot()
    If Not $BotRunning Then
        Local $sChar = GUICtrlRead($CharacterChoiceCombo)
        If $sChar = "No character selected" Or $sChar = "" Then
            MsgBox(0, "Error", "Please select a character first!")
            Return
        EndIf

        If Not $Bot_Core_Initialized Then
            Local $bInitialized = False
            
            ; 1. Try to initialize as running client
            Local $l_a_GwProcesses = ProcessList("gw.exe")
            If IsArray($l_a_GwProcesses) And $l_a_GwProcesses[0][0] > 0 Then
                If Core_Initialize($sChar, True) Then
                    $bInitialized = True
                EndIf
            EndIf

            If Not $bInitialized Then
                ; 2. If not running, check if it is a registered character and launch it
                Update("Character not found running. Checking registered list...")
                
                ; Check if character exists in INI
                Local $sIniFile = $GC_S_CHARACTERS_INI_PATH
                Local $sEmail = IniRead($sIniFile, $sChar, "Email", "")
                
                If $sEmail <> "" Then
                    Update("Launching character: " & $sChar)
                    Local $iPID = Launch_LaunchAccountFromINI($sIniFile, $sChar)
                    If $iPID <> 0 Then
                        Sleep(2000) ; Wait for initialization
                        If Core_Initialize($iPID) Then
                            $bInitialized = True
                        Else
                            MsgBox(0, "Error", "Launched but failed to attach to: " & $sChar)
                        EndIf
                    Else
                        MsgBox(0, "Error", "Failed to launch character: " & $sChar)
                    EndIf
                Else
                    MsgBox(0, "Error", "Character not found (Running or Registered): " & $sChar)
                EndIf
            EndIf

            If Not $bInitialized Then Return
            
            $Bot_Core_Initialized = True
            $g_s_MainCharName = $sChar

            If Not PunchOut_AutoEnterSelectedCharacter($sChar) Then Return
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

Func OnRenderingToggle()
    If GUICtrlRead($gRenderingCheckbox) = $GUI_CHECKED Then
        Ui_DisableRendering()
        Update("Rendering Disabled")
    Else
        Ui_EnableRendering()
        Update("Rendering Enabled")
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
    ; Update("Handling Outpost Logic")

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
        PunchOut_IssueMove($l_f_KilroyX, $l_f_KilroyY)
        Sleep(500)
        Return
    EndIf

    Update("Preparing for Quest")
    
    ; 2. Leave Party
    Party_KickAllHeroes()

    ; 3. Check Quest State
    Local $l_i_QuestState = Quest_GetQuestInfo($FRONIS_QUEST, "LogState")
    ; Update("Quest State: " & $l_i_QuestState)
    
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
; Inventory bags used by identify/sell (Backpack, Belt Pouch, Bag 1, Bag 2).
; Uses Item_GetBagItemArray / Item_GetInventoryArray so bag scanning matches current GwAu3.
Func PunchOut_InventoryBags()
    Local $l_ai_Bags[4] = [$GC_I_INVENTORY_BACKPACK, $GC_I_INVENTORY_BELT_POUCH, $GC_I_INVENTORY_BAG1, $GC_I_INVENTORY_BAG2]
    Return $l_ai_Bags
EndFunc

Func PunchOut_IsKeepItem($a_i_ModelID, $a_i_Type = 0)
    If $a_i_Type = $GC_I_TYPE_KIT Or $a_i_Type = $GC_I_TYPE_DYE Then Return True
    If $a_i_ModelID = $GC_I_MODELID_IDENTIFICATION_KIT Then Return True
    If $a_i_ModelID = $GC_I_MODELID_SUPERIOR_IDENTIFICATION_KIT Then Return True
    If $a_i_ModelID = 22751 Then Return True ; Lockpicks
    If $a_i_ModelID = 27044 Then Return True ; Stone Summit Emblem
    If $a_i_ModelID = 5585 Then Return True ; Dwarven Ale
    If $a_i_ModelID = 24593 Then Return True ; Aged Dwarven Ale
    If IsCraftingMaterial($a_i_ModelID) Then Return True
    Return False
EndFunc

; Gear that can actually be identified. Skipping trophies/kits/materials avoids
; Item_IdentifyItem waiting ~2.5s per item that will never become identified.
Func PunchOut_CanIdentifyItem($a_i_Type, $a_i_ModelID, $a_i_Rarity)
    If PunchOut_IsKeepItem($a_i_ModelID, $a_i_Type) Then Return False
    Switch $a_i_Type
        Case $GC_I_TYPE_KIT, $GC_I_TYPE_DYE, $GC_I_TYPE_MATERIAL_AND_ZCOINS, $GC_I_TYPE_GOLD_COINS, _
                $GC_I_TYPE_TROPHY, $GC_I_TYPE_TROPHY_2, $GC_I_TYPE_USABLE, $GC_I_TYPE_KEY, _
                $GC_I_TYPE_QUEST_ITEM, $GC_I_TYPE_BAG, $GC_I_TYPE_SCROLL, $GC_I_TYPE_PRESENT, _
                $GC_I_TYPE_MINIPET, $GC_I_TYPE_BOOKS
            Return False
    EndSwitch
    Switch $a_i_Rarity
        Case $GC_I_RARITY_WHITE, $GC_I_RARITY_BLUE, $GC_I_RARITY_PURPLE, $GC_I_RARITY_GOLD
            Return True
    EndSwitch
    Return False
EndFunc

Func PunchOut_ShouldSellItem($a_b_Identified, $a_i_Rarity, $a_i_Type, $a_i_ModelID)
    If Not $a_b_Identified Then Return False
    If $a_i_Rarity <> $GC_I_RARITY_WHITE And $a_i_Rarity <> $GC_I_RARITY_BLUE And $a_i_Rarity <> $GC_I_RARITY_PURPLE Then Return False
    If PunchOut_IsKeepItem($a_i_ModelID, $a_i_Type) Then Return False
    Return True
EndFunc

; Prefer a normal ID kit, fall back to superior. Uses Item_GetBagItemArray (GwAu3 bag-ptr update).
Func PunchOut_FindIdentificationKit()
    Local $l_p_Normal = 0
    Local $l_p_Superior = 0
    Local $l_ai_Bags = PunchOut_InventoryBags()
    For $bag In $l_ai_Bags
        Local $l_p_Bag = Item_GetBagPtr($bag)
        If $l_p_Bag = 0 Then ContinueLoop

        Local $l_ap_Items = Item_GetBagItemArray($l_p_Bag)
        If Not IsArray($l_ap_Items) Then ContinueLoop

        For $i = 1 To $l_ap_Items[0]
            Local $l_p_Item = $l_ap_Items[$i]
            If $l_p_Item = 0 Then ContinueLoop
            Local $l_i_ModelID = Item_GetItemInfoByPtr($l_p_Item, 'ModelID')
            If $l_i_ModelID = $GC_I_MODELID_IDENTIFICATION_KIT Then
                $l_p_Normal = $l_p_Item
            ElseIf $l_i_ModelID = $GC_I_MODELID_SUPERIOR_IDENTIFICATION_KIT Then
                $l_p_Superior = $l_p_Item
            EndIf
        Next
    Next
    If $l_p_Normal <> 0 Then Return $l_p_Normal
    Return $l_p_Superior
EndFunc

Func PunchOut_EnsureIdentificationKit()
    If PunchOut_FindIdentificationKit() <> 0 Then Return True
    Update("Buying ID Kit...")
    Merchant_BuyItem($GC_I_MODELID_IDENTIFICATION_KIT, 1)
    Sleep(1000)
    Return PunchOut_FindIdentificationKit() <> 0
EndFunc

Func CheckBagsFull()
    Local $l_i_EmptySlots = 0
    Local $l_ai_Bags = PunchOut_InventoryBags()
    For $bag In $l_ai_Bags
        Local $l_p_Bag = Item_GetBagPtr($bag)
        If $l_p_Bag = 0 Then ContinueLoop
        $l_i_EmptySlots += Item_GetBagInfo($l_p_Bag, "EmptySlots")
    Next
    ; Trigger if 4 or fewer slots are empty (Covering the "3-4 empty slots" requirement)
    Return ($l_i_EmptySlots <= 4)
EndFunc

Func HandleMerchant()
    Update("Bags full, going to merchant...")
    Map_TravelTo($map_ID_EoTN)
    Sleep(2000)
    Local $l_f_MerchX = -2748.00
    Local $l_f_MerchY = 1019.00

    Local $MerchID = GetNearestNPC($l_f_MerchX, $l_f_MerchY)
    If $MerchID <> 0 Then
        Agent_ChangeTarget($MerchID)
        Agent_GoNPC($MerchID)
        Sleep(2000)

        Local $bIdentify = (GUICtrlRead($gIdentifyCheckbox) = $GUI_CHECKED)
        Local $bSell = (GUICtrlRead($gSellCheckbox) = $GUI_CHECKED)

        ; Restock kits before identifying so IdentifyCycle does not stall on empty kit search.
        If $bIdentify Or $bSell Then
            PunchOut_EnsureIdentificationKit()
        EndIf

        If $bIdentify Then
            IdentifyCycle()
        EndIf

        If $bSell Then
            SellCycle()
            PunchOut_EnsureIdentificationKit()
        EndIf
    Else
        Update("Merchant not found!")
    EndIf
EndFunc

Func IdentifyCycle()
    Update("Identifying items...")
    If Not PunchOut_EnsureIdentificationKit() Then
        Update("No identification kit available")
        Return
    EndIf

    Local $l_av_Inventory = Item_GetInventoryArray()
    Local $l_i_Count = UBound($l_av_Inventory)
    For $i = 0 To $l_i_Count - 1
        If $l_av_Inventory[$i][$GC_I_INVENTORY_ISIDENTIFIED] Then ContinueLoop
        If Not PunchOut_CanIdentifyItem($l_av_Inventory[$i][$GC_I_INVENTORY_ITEMTYPE], $l_av_Inventory[$i][$GC_I_INVENTORY_MODELID], $l_av_Inventory[$i][$GC_I_INVENTORY_RARITY]) Then ContinueLoop

        If PunchOut_FindIdentificationKit() = 0 Then
            If Not PunchOut_EnsureIdentificationKit() Then
                Update("Ran out of identification kits")
                Return
            EndIf
        EndIf

        Item_IdentifyItem($l_av_Inventory[$i][$GC_I_INVENTORY_PTR], "Normal")
        Sleep(50)
    Next
EndFunc

Func SellCycle()
    Update("Selling items...")
    ; Re-read after identify so IsIdentified / rarity reflect kit results.
    Local $l_av_Inventory = Item_GetInventoryArray()
    Local $l_i_Count = UBound($l_av_Inventory)
    For $i = 0 To $l_i_Count - 1
        If PunchOut_ShouldSellItem($l_av_Inventory[$i][$GC_I_INVENTORY_ISIDENTIFIED], $l_av_Inventory[$i][$GC_I_INVENTORY_RARITY], $l_av_Inventory[$i][$GC_I_INVENTORY_ITEMTYPE], $l_av_Inventory[$i][$GC_I_INVENTORY_MODELID]) Then
            Merchant_SellItem($l_av_Inventory[$i][$GC_I_INVENTORY_PTR])
            Sleep(250)
        EndIf
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
    PunchOut_MoveToWait(-16919.56, -13485.12)
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
            PunchOut_IssueMove($tX, $tY)
            
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
        PunchOut_MoveToWait(Agent_GetAgentInfo($l_i_SignpostID, "X"), Agent_GetAgentInfo($l_i_SignpostID, "Y"), 100, 15000, 0)
        
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
    $g_i_Successes += 1
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

Func PunchOut_IssueMove($a_f_X, $a_f_Y, $a_f_Randomize = 0)
    Local $l_f_X = $a_f_X
    Local $l_f_Y = $a_f_Y
    If $a_f_Randomize > 0 Then
        $l_f_X += Random(-$a_f_Randomize, $a_f_Randomize)
        $l_f_Y += Random(-$a_f_Randomize, $a_f_Randomize)
    EndIf
    Map_MoveLayer($l_f_X, $l_f_Y, Agent_GetAgentInfo(-2, "Plane"))
    Return True
EndFunc

Func PunchOut_MoveToWait($a_f_X, $a_f_Y, $a_f_StopDist = 150, $a_i_TimeoutMs = 25000, $a_f_Randomize = 50)
    Local $l_i_MapID = Map_GetCharacterInfo("MapID")
    Local $l_i_InstanceType = Map_GetInstanceInfo("Type")
    Local $l_i_Layer = Agent_GetAgentInfo(-2, "Plane")

    Local $l_f_DestX = $a_f_X
    Local $l_f_DestY = $a_f_Y
    If $a_f_Randomize > 0 Then
        $l_f_DestX += Random(-$a_f_Randomize, $a_f_Randomize)
        $l_f_DestY += Random(-$a_f_Randomize, $a_f_Randomize)
    EndIf

    Map_MoveLayer($l_f_DestX, $l_f_DestY, $l_i_Layer)

    Local $l_t_Timer = TimerInit()
    While True
        If Agent_GetAgentInfo(-2, "IsDead") Then Return False
        If Map_GetCharacterInfo("MapID") <> $l_i_MapID Then Return False
        If Map_GetInstanceInfo("Type") <> $l_i_InstanceType Then Return False
        If Agent_GetDistanceToXY($a_f_X, $a_f_Y) <= $a_f_StopDist Then Return True

        If Agent_GetAgentInfo(-2, "MoveX") = 0 And Agent_GetAgentInfo(-2, "MoveY") = 0 Then
            $l_f_DestX = $a_f_X
            $l_f_DestY = $a_f_Y
            If $a_f_Randomize > 0 Then
                $l_f_DestX += Random(-$a_f_Randomize, $a_f_Randomize)
                $l_f_DestY += Random(-$a_f_Randomize, $a_f_Randomize)
            EndIf
            Map_MoveLayer($l_f_DestX, $l_f_DestY, $l_i_Layer)
            Sleep(250)
        Else
            Map_MoveLayer($l_f_DestX, $l_f_DestY, $l_i_Layer)
            Sleep(100)
        EndIf

        If $a_i_TimeoutMs > 0 And TimerDiff($l_t_Timer) > $a_i_TimeoutMs Then Return False
    WEnd
EndFunc

Func Update($sText)
    _GUICtrlStatusBar_SetText($StatusBar1, $sText, 0)
    Out($sText)
EndFunc

Func UpdateGUIStats()
    GUICtrlSetData($RunsLabel, "Runs: " & $g_i_Runs)
    GUICtrlSetData($SuccessLabel, "Success: " & $g_i_Successes)
    GUICtrlSetData($FailuresLabel, "Failures: " & $g_i_Fails)
    GUICtrlSetData($Ales, "Ales: " & $g_i_Ales)
    
    Local $iDiff = TimerDiff($g_i_StartTime)
    Local $iHours = Floor($iDiff / 3600000)
    Local $iMins = Floor(Mod($iDiff, 3600000) / 60000)
    Local $iSecs = Floor(Mod($iDiff, 60000) / 1000)
    GUICtrlSetData($TimeLabel, StringFormat("Time: %02d:%02d:%02d", $iHours, $iMins, $iSecs))
EndFunc

Func PunchOut_AutoEnterSelectedCharacter($a_s_Character)
    Local $l_h_Wnd = $g_h_GWWindow
    If $l_h_Wnd = 0 Then $l_h_Wnd = Scanner_GetHwnd($g_i_GWProcessId)
    If $l_h_Wnd = 0 Then Return False

    If PreGame_Ptr() = 0 Then Return True

    Local $l_i_CurrentIndex = PreGame_ChosenCharacter()
    Local $l_s_CurrentName = StringStripWS(PreGame_CharName($l_i_CurrentIndex), 3)

    If StringCompare($l_s_CurrentName, $a_s_Character, 0) <> 0 Then
        Local $l_i_InitialIndex = $l_i_CurrentIndex
        Local $l_i_Attempts = 0
        While $l_i_Attempts < 25
            ControlSend($l_h_Wnd, "", "", "{RIGHT}")
            Sleep(250)
            $l_i_CurrentIndex = PreGame_ChosenCharacter()
            $l_s_CurrentName = StringStripWS(PreGame_CharName($l_i_CurrentIndex), 3)
            If StringCompare($l_s_CurrentName, $a_s_Character, 0) = 0 Then ExitLoop
            $l_i_Attempts += 1
            If $l_i_Attempts > 1 And $l_i_CurrentIndex = $l_i_InitialIndex Then ExitLoop
        WEnd

        If StringCompare($l_s_CurrentName, $a_s_Character, 0) <> 0 Then
            Update("Character '" & $a_s_Character & "' not found on this account")
            Return False
        EndIf
    EndIf

    ControlSend($l_h_Wnd, "", "", "{ENTER}")
    While PreGame_Ptr() <> 0
        Sleep(500)
    WEnd
    Map_WaitMapLoading()
    Sleep(1000)
    Return True
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
