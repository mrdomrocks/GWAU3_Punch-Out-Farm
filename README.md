MrDomRocks Presents - Kilroy Stonekin's Punch Out Farm - GWAU3 version

With thanks to GWAU3 Community I have put together a working and for the most part fully functional Kilroy Stoneskin Punch Out Farm This farm uses the Smartcast system to use the Brawling Skills used in the Fronis Instance. It's not perfect but it works.

The farm is designed to loop, pick up the initial quest, fight all mobs within the instance once final boss is defeated map to Gunnars Hold and accept the rewards. Once your reach limited capacity with only 4 slots left in bags 1-4. The bot will identify all drops and vendor then accept the Golds. This can be toggled on via the GUI of the bot itself.

I have also included a Hard Mode option, please be advised it is recommended that Stalwart Insignias and Weapon Mods are used when running Hard Mode. (I have included a handy notice when HM is selected as a reminder)


<img width="531" height="261" alt="image" src="https://github.com/user-attachments/assets/8ed39e8d-e2c8-43ab-baa4-3a89f02e572b" />

I will be actively working on additional features for this bot. Including a check that if downed too many times in a row for the bot to move the character out of agro range to allow Kilroy to revive.

As ever use at your own risk. Happy Farming!

## installation

Download the repo zip. Extract to your GwAu3-main folder location. I have listed the includes below for reference to file placement and adjustments to includes if required.

#include "..\API\_GwAu3.au3"

#include "AddOns\GwAu3_AddOns_Punch_Out_Farm.au3"

#include "GUI\GUI_Punch_Out_Farm.au3"

#include "..\API\SmartCast\_UtilityAI.au3"

#include "..\API\Pathfinding\Pathfinder_Movements.au3"


Coded using TRAE, GUI made using KODA GUI.
Once again thanks for the support GwAu3 Community. <3
