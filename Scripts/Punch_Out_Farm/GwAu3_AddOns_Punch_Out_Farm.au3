#cs
;;; Punch Out Farmer = Created by MrDomRocks
; Hard Mode and Normal Mode
: Punch and Run
#ce
#include-once

; === Constants ===
Global Const $RARITY_Gold = 2624
Global Const $RARITY_Purple = 2626
Global Const $RARITY_Blue = 2623
Global Const $RARITY_White = 2621
Global Const $ITEM_ID_Lockpicks = 22751
Global Const $ITEM_ID_Dyes = 146
Global Const $ITEM_ExtraID_BlackDye = 10
Global Const $ITEM_ExtraID_WhiteDye = 12

; === Global Variables ===
Global $g_h_EditText
Global $g_s_LastLogMessage = ""

#Region Other
Func GetIsDead($aAgent = -2)
    Return Agent_GetAgentInfo($aAgent, "IsDead")
EndFunc   ;==>GetIsDead

Func GetPartyDead()
    ; Simplified to just check player since heroes are kicked
    Return GetIsDead(-2)
EndFunc   ;==>GetPartyDead
#EndRegion Other

#Region Gui
;~ Description: Print to console with timestamp
Func Out($TEXT)
    If $TEXT = $g_s_LastLogMessage Then Return
    $g_s_LastLogMessage = $TEXT

    Local $TEXTLEN = StringLen($TEXT)
    Local $CONSOLELEN = _GUICtrlEdit_GetTextLen($g_h_EditText)
    If $TEXTLEN + $CONSOLELEN > 30000 Then GUICtrlSetData($g_h_EditText, StringRight(_GUICtrlEdit_GetText($g_h_EditText), 30000 - $TEXTLEN - 1000))
    _GUICtrlRichEdit_SetCharColor($g_h_EditText, $COLOR_BLACK)
    _GUICtrlEdit_AppendText($g_h_EditText, @CRLF & $TEXT)
    _GUICtrlEdit_Scroll($g_h_EditText, 1)
EndFunc

#EndRegion Gui

#Region Combat
Func Brawling_ComputeDistance($x1, $y1, $x2, $y2)
    Return Sqrt(($x2 - $x1) ^ 2 + ($y2 - $y1) ^ 2)
EndFunc

Func Brawling_GetDistance($aAgent1, $aAgent2)
    Return Brawling_ComputeDistance(Agent_GetAgentInfo($aAgent1, 'X'), Agent_GetAgentInfo($aAgent1, 'Y'), Agent_GetAgentInfo($aAgent2, 'X'), Agent_GetAgentInfo($aAgent2, 'Y'))
EndFunc

Func Brawling_IsRecharged($aSkill)
    Return Skill_GetSkillbarInfo($aSkill, "IsRecharged")
EndFunc

Func Brawling_UseSkillEx($aSkill, $aTgt = -2, $aTimeout = 400)
    If GetIsDead(-2) Then Return False
    If Not Brawling_IsRecharged($aSkill) Then Return False

    Local $lDeadlock = TimerInit()
    Skill_UseSkill($aSkill, $aTgt)
    Sleep(50) ; Wait for cast start

    Do
        Sleep(10)
        If GetIsDead(-2) Then Return False
    Until (Not Brawling_IsRecharged($aSkill)) Or (TimerDiff($lDeadlock) > $aTimeout)

    If Not Brawling_IsRecharged($aSkill) Then Return True
    Return False
EndFunc

Func Brawling_EnemyFilter($aAgentPtr)
    If Agent_GetAgentInfo($aAgentPtr, 'Allegiance') <> 3 Then Return False
    If Agent_GetAgentInfo($aAgentPtr, 'HP') <= 0 Then Return False
    If Agent_GetAgentInfo($aAgentPtr, 'IsDead') > 0 Then Return False
    Return True
EndFunc

Func GetNumberOfFoesInRangeOfAgent($aAgentID = -2, $aRange = 1200, $aType = $GC_I_AGENT_TYPE_LIVING, $aReturnMode = 0, $aCustomFilter = "Brawling_EnemyFilter")
    Return GetAgents($aAgentID, $aRange, $aType, $aReturnMode, $aCustomFilter)
EndFunc

Func GetNearestEnemyToAgent($aAgentID = -2, $aRange = 1320, $aType = $GC_I_AGENT_TYPE_LIVING, $aReturnMode = 1, $aCustomFilter = "Brawling_EnemyFilter")
    Return GetAgents($aAgentID, $aRange, $aType, $aReturnMode, $aCustomFilter)
EndFunc

Func Brawling_Fight($x)
    If GetPartyDead() Then Return
    Local $target
    Local $distance
    Local $LocalTimer = TimerInit()
    Local $bRecoveryMode = False
    Local $hRecoveryTimer = 0
    Do
        If GetNumberOfFoesInRangeOfAgent(-2, 1500) = 0 Then ExitLoop
        If GetNumberOfFoesInRangeOfAgent(-2, 1500) = 0 Then ExitLoop
        If GetPartyDead() Then ExitLoop

        ; Recovery Logic
        Local $iEnergy = Agent_GetAgentInfo(-2, "CurrentEnergy")
        Local $iMaxEnergy = Agent_GetAgentInfo(-2, "MaxEnergy")

        If $iEnergy < 1 Then $bRecoveryMode = True

        If $bRecoveryMode Then
            Skill_UseSkill(8, -2)

            If $iEnergy >= $iMaxEnergy Then
                If $hRecoveryTimer = 0 Then $hRecoveryTimer = TimerInit()
                If TimerDiff($hRecoveryTimer) > 2000 Then
                    $bRecoveryMode = False
                    $hRecoveryTimer = 0
                EndIf
            Else
                $hRecoveryTimer = 0
            EndIf

            Sleep(1)
            ContinueLoop
        EndIf

        $target = GetNearestEnemyToAgent(-2, 1500, $GC_I_AGENT_TYPE_LIVING, 1, "Brawling_EnemyFilter")
        $target = GetNearestEnemyToAgent(-2, 1500, $GC_I_AGENT_TYPE_LIVING, 1, "Brawling_EnemyFilter")
            ExitLoop
        EndIf

        $distance = Brawling_GetDistance($target, -2)

        ; Move to target if out of range
        If $distance > 150 Then ; Brawling range is short
            Agent_ChangeTarget($target)
            Agent_Attack($target)
            Agent_Attack($target)
            Sleep(250)
            $distance = Brawling_GetDistance($target, -2)

            If $distance > 200 Then
                Map_Move(Agent_GetAgentInfo($target, 'X'), Agent_GetAgentInfo($target, 'Y'))
                Local $MoveTimer = TimerInit()
                Do
                    Sleep(100)
                    $distance = Brawling_GetDistance($target, -2)
                Until $distance < 200 Or TimerDiff($MoveTimer) > 3000 Or GetPartyDead()
                Do
                    Sleep(100)
                    $distance = Brawling_GetDistance($target, -2)
                Until $distance < 200 Or TimerDiff($MoveTimer) > 3000 Or GetPartyDead()
            EndIf
            UAI_CacheSkillBar() ; Refresh skill cache before combat
        ; Combat Loop (Cycle skills once then re-evaluate)
        If $distance < 300 Then
            UAI_CacheSkillBar() ; Refresh skill cache before combat
            For $i = 1 To 8
                If GetPartyDead() Then ExitLoop 2
                If Agent_GetAgentInfo($target, 'HP') <= 0 Then ExitLoop
                If $i = 8 Then ContinueLoop ; Skip Stand Up! in combat loop

                If Brawling_IsRecharged($i) Then
                    ; Check adrenaline requirements
                    Local $iAdrenaline = Skill_GetSkillbarInfo($i, "Adrenaline")
                    Local $iCost = Skill_GetSkillInfo(Skill_GetSkillbarInfo($i, "ID"), "Adrenaline")

                    If $iAdrenaline >= $iCost Then
                        Local $bUsed = False

                        ; Smartcast Logic for Skill 1 (Priority)
                        If $i = 1 Then
                            ; Cast regardless of range if it's a movement/charge skill or self-buff
                            ; Or if distance is very close
                            $bUsed = Brawling_UseSkillEx($i, $target, 200) ; Faster timeout
                        Else
                            $bUsed = Brawling_UseSkillEx($i, $target)
                        EndIf

                        If $bUsed Then
                            ExitLoop ; Re-evaluate after successful skill usage (GCD/Priority)
                        EndIf
                    EndIf
        EndIf

    Until Agent_GetAgentInfo($target, 'ID') = 0 Or GetPartyDead() Or TimerDiff($LocalTimer) > 180000
EndFunc

Func Brawling_ClearArea($range = 1500)
    Out("Clearing area (Range: " & $range & ")...")

    While True
        If GetPartyDead() Then Return False

        Local $target = GetNearestEnemyToAgent(-2, $range, $GC_I_AGENT_TYPE_LIVING, 1, "Brawling_EnemyFilter")

        If $target == 0 Then
            Out("Area clear.")
            Return True
        EndIf

        Out("Engaging remaining enemy: " & Agent_GetAgentInfo($target, 'ID'))
        Brawling_Fight($range)
        Sleep(500)
    WEnd
EndFunc

Func Brawling_MoveTo($aDestX, $aDestY, $aAggroRange = 1500)
    Local $lMyX, $lMyY
    
    ; Initial Path Calculation
    Pathfinder_Initialize()
    Local $lPath = _Pathfinder_GetPath(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), Agent_GetAgentInfo(-2, "Plane"), $aDestX, $aDestY, 0)
    
    If Not IsArray($lPath) Then
        Out("Path calculation failed. Moving directly.")
        Map_Move($aDestX, $aDestY)
        Return
    EndIf
    
    Local $iPathIndex = 0
    Local $lTimer = TimerInit()
    
    While True
        If GetPartyDead() Then Return
        If TimerDiff($lTimer) > 60000 Then 
            Out("Movement Timeout")
            Return
        EndIf
        
        $lMyX = Agent_GetAgentInfo(-2, "X")
        $lMyY = Agent_GetAgentInfo(-2, "Y")
        
        ; Check if reached destination
        If Agent_GetDistanceToXY($aDestX, $aDestY) < 250 Then ExitLoop
        
        ; Fight & Loot using Aggro Range
        If GetNumberOfFoesInRangeOfAgent(-2, $aAggroRange) > 0 Then
            Brawling_ClearArea($aAggroRange)
            PickUpLoot()
        EndIf
        
        ; Move along path
        If $iPathIndex < UBound($lPath) Then
            Local $lWpX = $lPath[$iPathIndex][0]
            Local $lWpY = $lPath[$iPathIndex][1]
            
            If Agent_GetDistanceToXY($lWpX, $lWpY) < 250 Then
                $iPathIndex += 1
            Else
                Map_Move($lWpX, $lWpY)
            EndIf
        Else
            Map_Move($aDestX, $aDestY)
        EndIf
        
        Sleep(100)
    WEnd
EndFunc
#EndRegion Combat

#Region Loot
Func PickUpLoot()
    Local $lAgentArray = Item_GetItemArray()
    Local $maxitems = $lAgentArray[0]

    For $i = 1 To $maxitems
        Local $aItemPtr = $lAgentArray[$i]
        Local $aItemAgentID = Item_GetItemInfoByPtr($aItemPtr, "AgentID")

        If GetIsDead(-2) Then Return
        If $aItemAgentID = 0 Then ContinueLoop ; If Item is not on the ground

        If CanPickUp($aItemPtr) Then
            Item_PickUpItem($aItemAgentID)
            Local $lDeadlock = TimerInit()
            While GetItemAgentExists($aItemAgentID)
                Sleep(100)
                If GetIsDead(-2) Then Return
                If TimerDiff($lDeadlock) > 10000 Then ExitLoop
            WEnd
        EndIf
    Next
EndFunc   ;==>PickUpLoot

;~ Description: Test if an Item agent exists.
Func GetItemAgentExists($aItemAgentID)
    Return (Agent_GetAgentPtr($aItemAgentID) > 0 And $aItemAgentID < Item_GetMaxItems())
EndFunc   ;==>GetItemAgentExists

Func CanPickUp($aItemPtr)
    Local $lModelID = Item_GetItemInfoByPtr($aItemPtr, "ModelID")
    Local $aExtraID = Item_GetItemInfoByPtr($aItemPtr, "ExtraID")
    Local $lRarity = Item_GetItemInfoByPtr($aItemPtr, "Rarity")
    
    If (($lModelID == 2511) And (Item_GetInventoryInfo("GoldCharacter") < 99000)) Then
        Return True ; gold coins (only pick if character has less than 99k in inventory)
    ElseIf ($lModelID == $ITEM_ID_Dyes) Then ; if dye
        If (($aExtraID == $ITEM_ExtraID_BlackDye) Or ($aExtraID == $ITEM_ExtraID_WhiteDye)) Then ; only pick white and black ones
            Return True
        EndIf
    Elseif ($RARITY_White == $lRarity) Then ; white items
        Return True
    Elseif ($RARITY_Blue == $lRarity) Then ;blue items
        Return True
    ElseIf ($lRarity == $RARITY_Gold) Then ; gold items
        Return True
    ElseIf ($lRarity == $RARITY_Purple) Then ; purple items
        Return True
    ElseIf ($lModelID == $ITEM_ID_Lockpicks) Then
        Return True ; Lockpicks
    ElseIf ($lModelID == 27044) Then
        Return True ; Stone Summit Emblem
    ElseIf $lModelID == 5585 Then ; Dwarven Ale
        Return True
    ElseIf ($lModelID == 24593) Then ; Aged Dwarven Ale
        Return True ; Aged Dwarven Ale
    ElseIf IsPcon($aItemPtr) Then ; ==== Pcons ==== or all event items
        Return False
    ElseIf IsRareMaterial($aItemPtr) Then ; rare Mats
        Return True
    Else
        Return False
    EndIf
EndFunc   ;==>CanPickUp

Func IsPcon($aItemPtr)
    Local $lModelID = Item_GetItemInfoByPtr($aItemPtr, "ModelID")
    For $i = 1 To $GC_AI_PCONS[0]
        If $GC_AI_PCONS[$i] = $lModelID Then Return True
    Next
    Return False
EndFunc

Func IsRareMaterial($aItemPtr)
    Return Item_GetItemIsRareMaterial($aItemPtr)
EndFunc
#EndRegion Loot
