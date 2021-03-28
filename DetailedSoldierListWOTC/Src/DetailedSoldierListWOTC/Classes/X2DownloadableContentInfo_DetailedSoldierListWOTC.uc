//---------------------------------------------------------------------------------------
//  FILE:    X2DownloadableContentInfo.uc
//  AUTHOR:  Ryan McFall
//           
//	Mods and DLC derive from this class to define their behavior with respect to 
//  certain in-game activities like loading a saved game. Should the DLC be installed
//  to a campaign that was already started?
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_DetailedSoldierListWOTC extends X2DownloadableContentInfo;

var config bool IsRequiredCHLInstalled;

// Copied from robojumper's SquadSelect. Checks whether the Community Highlander
// is active and meets the given minimum version requirement.
static function bool IsCHLMinVersionInstalled(int iMajor, int iMinor)
{
	return class'CHXComGameVersionTemplate'.default.MajorVersion > iMajor ||
		(class'CHXComGameVersionTemplate'.default.MajorVersion == iMajor &&
		 class'CHXComGameVersionTemplate'.default.MinorVersion >= iMinor);
}

static event OnLoadedSavedGame(){}
static event OnLoadedSavedGameToStrategy(){}
static event InstallNewCampaign(XComGameState StartState){}
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState){}
static event OnPostMission(){}
static event ModifyTacticalTransferStartState(XComGameState TransferStartState){}
static event OnExitPostMissionSequence(){}

// Added in Community Highlander 1.18, so if this is called, the highlander is
// guaranteed to be loaded.
static function OnPreCreateTemplates()
{
	default.IsRequiredCHLInstalled = IsCHLMinVersionInstalled(1, 19);
}

static event OnPostTemplatesCreated(){}
static event OnDifficultyChanged(){}
static event UpdateDLC(){}
static event OnPostAlienFacilityCreated(XComGameState NewGameState, StateObjectReference MissionRef){}
static event OnPostFacilityDoomVisualization(){}
static function bool UpdateShadowChamberMissionInfo(StateObjectReference MissionRef){return false;}

/// <summary>
/// A dialogue popup used for players to confirm or deny whether new gameplay content should be installed for this DLC / Mod.
/// </summary>
static function EnableDLCContentPopup()
{
	local TDialogueBoxData kDialogData;

	kDialogData.eType = eDialog_Normal;
	kDialogData.strTitle = default.EnableContentLabel;
	kDialogData.strText = default.EnableContentSummary;
	kDialogData.strAccept = default.EnableContentAcceptLabel;
	kDialogData.strCancel = default.EnableContentCancelLabel;

	kDialogData.fnCallback = EnableDLCContentPopupCallback_Ex;
	`HQPRES.UIRaiseDialog(kDialogData);
}

simulated function EnableDLCContentPopupCallback(eUIAction eAction){}
simulated function EnableDLCContentPopupCallback_Ex(Name eAction)
{	
	switch (eAction)
	{
		case 'eUIAction_Accept':	EnableDLCContentPopupCallback(eUIAction_Accept);	break;
		case 'eUIAction_Cancel':	EnableDLCContentPopupCallback(eUIAction_Cancel);	break;
		case 'eUIAction_Closed':	EnableDLCContentPopupCallback(eUIAction_Closed);	break;
	}
}

static function bool ShouldUpdateMissionSpawningInfo(StateObjectReference MissionRef){return false;}
static function bool UpdateMissionSpawningInfo(StateObjectReference MissionRef){return false;}
static function string GetAdditionalMissionDesc(StateObjectReference MissionRef){return "";}
static function bool AbilityTagExpandHandler(string InString, out string OutString){return false;}
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay){}
static function bool DisplayQueuedDynamicPopup(DynamicPropertySet PropertySet){}
