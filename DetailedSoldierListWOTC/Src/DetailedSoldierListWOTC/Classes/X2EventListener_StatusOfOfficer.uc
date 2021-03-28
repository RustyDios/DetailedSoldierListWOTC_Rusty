//*******************************************************************************************
//  FILE:  Officer Add On	REMOVED LW ASPECT NOT WORKING   UNABLE TO CONFIRM UNIT STATUS AS AN OFFICER             
//  
//	File created	11/01/21    12:20
//	LAST UPDATED    12/01/21    10:50
//
//  This listener uses a CHL event to set the status in the barracks correctly
//  uses CHL issue #322 
//
//*******************************************************************************************
class X2EventListener_StatusOfOfficer extends X2EventListener config (Game);

var localized string strOfficerAlreadySelectedStatus;

//setup the template
static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateListenerTemplate_StatusOfOfficer());
	
	return Templates; 
}

//create the listener template
static function CHEventListenerTemplate CreateListenerTemplate_StatusOfOfficer()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'StatusOfOfficer');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OverridePersonnelStatus', OnStatusOfOfficer, ELD_Immediate, 22);

	return Template;
}

//create the listener return
static function EventListenerReturn OnStatusOfOfficer(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
    local XComLWTuple					Tuple;
    local XComGameState_Unit			UnitState, SquadMember;
	local int i;

	local bool bOfficerInSquad, bUnitIsOfficer, bLogs;

    Tuple = XComLWTuple(EventData);
    UnitState = XComGameState_Unit(EventSource);

	bOfficerInSquad = false;
	bUnitIsOfficer = false;

	bLogs = class'UIPersonnel_SoldierListItemDetailed'.default.bRustyEnableDSLLogging;

	//check if unit is an officer
	/*if (UnitState != none && UnitState != UnitState.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) ) )
	{
		bUnitIsOfficer = true;
		`LOG("Officer status for" @UnitState.GetName(eNameType_Full) @" was: "@bUnitIsOfficer, bLogs, 'DSLRusty_Unit');
		`LOG(string(UnitState.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) )) @":" @string(UnitState), bLogs, 'DSLRusty_Unit');
	}
	else
	{
		bUnitIsOfficer = false;
		`LOG("Officer status for" @UnitState.GetName(eNameType_Full) @" was: "@bUnitIsOfficer, bLogs, 'DSLRusty_Unit');
		`LOG(string(UnitState.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) )) @":" @string(UnitState), bLogs, 'DSLRusty_Unit');
	}*/

	if (UnitState.HasAbilityFromAnySource('Leadership'))
	{
		bUnitIsOfficer = true;
	}


	//bail if the squad is empty or unit not an officer
	if (`XCOMHQ.Squad.Length <= 0 || !bUnitIsOfficer)
	{
		`LOG("Officer status Bailout : EmptySquad or not an Officer" , bLogs, 'DSLRusty');
		return ELR_NoInterrupt;
	}

	//check the squad for an officer
	for(i = 0; i < `XCOMHQ.Squad.Length; i++)
	{
		SquadMember = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.Squad[i].ObjectID));

		/*if(SquadMember != none && SquadMember != SquadMember.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) ) )
		{
			bOfficerInSquad = true;
			`LOG("Officer status for SquadMember" @SquadMember.GetName(eNameType_Full) @" was: "@bOfficerInSquad, bLogs, 'DSLRusty_Squad');
			`LOG(string(SquadMember.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) )) @":" @string(SquadMember), bLogs, 'DSLRusty_Squad');
		}
		else
		{
			bOfficerInSquad = false;
			`LOG("Officer status for SquadMember" @SquadMember.GetName(eNameType_Full) @" was: "@bOfficerInSquad, bLogs, 'DSLRusty_Squad');
			`LOG(string(SquadMember.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ) )) @":" @string(SquadMember), bLogs, 'DSLRusty_Squad');
		}*/

		if (SquadMember.HasAbilityFromAnySource('Leadership'))
		{
			if (!bOfficerInSquad)
			{
				bOfficerInSquad = true;
			}
		}

	}

	`LOG("Overwrite status:" @bUnitIsOfficer @":" @bOfficerInSquad, bLogs, 'DSLRusty');

    //if (UnitState != none && !bUnitInSquad && class'LWOfficerUtilities'.static.IsOfficer(Unit) && class'LWOfficerUtilities'.static.HasOfficerInSquad() && !bAllowWoundedSoldiers)
	//already have an officer and this guy is an officer too... set red flag
    if (bOfficerInSquad && bUnitIsOfficer )
	{
        Tuple.Data[0].s = default.strOfficerAlreadySelectedStatus; //Officer In Squad
        Tuple.Data[1].s = "---";                               //time string y
        Tuple.Data[2].s = "";                               //time value override z?
        Tuple.Data[3].i = 0;                                //time number, days/hrs
        Tuple.Data[4].i = eUIState_Bad;		                //eUIState_Bad;                //colour from EUI State - see UI Utilities_Colours
        Tuple.Data[5].b = true;                             //Indicates whether you should display the time value and label or not. false means don't hide it || display it. true means hide.
        Tuple.Data[6].b = false;                            //convert time to hours
    }

	return ELR_NoInterrupt;
}

/*
//FOR REF/INFO ONLY called in UiUtilities_Strategy 
static function TriggerOverridePersonnelStatus(XComGameState_Unit Unit,	out string Status, out EUIState eState,	out string TimeLabel, out string TimeValueOverride,	out int TimeNum, out int HideTime, out int DoTimeConversion)
{
	local XComLWTuple OverrideTuple;

	OverrideTuple = new class'XComLWTuple';
	OverrideTuple.Id = 'OverridePersonnelStatus';
	OverrideTuple.Data.Add(7);
	OverrideTuple.Data[0].s = Status;
	OverrideTuple.Data[1].s = TimeLabel;
	OverrideTuple.Data[2].s = TimeValueOverride;
	OverrideTuple.Data[3].i = TimeNum;
	OverrideTuple.Data[4].i = int(eState);
	OverrideTuple.Data[5].b = HideTime != 0;
	OverrideTuple.Data[6].b = DoTimeConversion != 0;

	`XEVENTMGR.TriggerEvent('OverridePersonnelStatus', OverrideTuple, Unit);

}
*/
