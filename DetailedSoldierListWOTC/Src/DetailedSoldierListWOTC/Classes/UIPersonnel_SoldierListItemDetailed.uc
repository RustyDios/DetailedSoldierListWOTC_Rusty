//*******************************************************************************************
//  FILE:  SoldierListItemDetailed                                
//  
//	File created	08/12/20    02:00
//	LAST UPDATED    12/01/21    10:50
//
//  This listener uses a CHL event to set the status in the barracks correctly
//  uses CHL issue #322 
//
//*******************************************************************************************
class UIPersonnel_SoldierListItemDetailed extends UIPersonnel_SoldierListItem config(Game);

var config int NUM_HOURS_TO_DAYS;
var config bool ROOKIE_SHOW_PSI, ALWAYS_SHOW_PSI, bRustyEnableDSLLogging;
var config array<string> APColours;

var bool bIsFocussed, bShouldHideBonds, bShouldShowBondProgress, bRustyOfficerIconPositionTest;

var UIImage AimIcon,    HealthIcon,     MobilityIcon,   WillIcon,   HackIcon,   DodgeIcon,  DefenseIcon,    PsiIcon,    PCSIcon; 
var UIText  AimValue,   HealthValue,    MobilityValue,  WillValue,  HackValue,  DodgeValue, DefenseValue,   PsiValue,   PCSValue;
var UIText  DetailedData;

var UIIcon APIcon, 	OfficerIcon;
var UIText APValue;

var float IconXPos, IconYPos, IconXDelta, IconScale, IconToValueOffsetX, IconToValueOffsetY, IconXDeltaSmallValue, DisabledAlpha;

var UIProgressBar BondProgress;
var float BondBarX, BondBarY, BondWidth, BondHeight;

var UIPanel BadTraitPanel, BonusAbilityPanel;
var array<UIIcon> BadTraitIcon;
var array<UIIcon> BonusAbilityIcon;

var float TraitIconX, AbilityIconX;

var string strUnitName, strClassName;

////////////////////////////////////////////////
//  INFORMATION GATHERING
///////////////////////////////////////////////

//construct 'second page' details
simulated function string GetDetailedText(XComGameState_Unit Unit)
{
    local string strMissions, strKills, strXP, strArmor, strShields;

    //Kills ... class'UISoldierHeader'.default.m_strKillsLabel
    strKills = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_AlienAlertIcon, 16, 20, -18) $ "</img>" @ string(Unit.GetNumKills());

    //Mission ... class'UISoldierHeader'.default.m_strMissionsLabel
    strMissions = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_ObjectivesIcon, 16, 20, -6) $ "</img>" @ string(Unit.GetNumMissions());

    //Armor
    strArmor = class'UIUtilities_Text'.static.InjectImage("img:///UILibrary_RustyDSL.UIFlag_Armor", 16, 20, -18) $ "</img>" @ 
        string(int(Unit.GetCurrentStat(eStat_ArmorMitigation)) + Unit.GetUIStatFromAbilities(eStat_ArmorMitigation));

	//Shields
	strShields = class'UIUtilities_Text'.static.InjectImage("img:///UILibrary_RustyDSL.UIFlag_Shield", 16, 20, -18) $ "</img>" @ 
        string(int(Unit.GetCurrentStat(eStat_ShieldHP)) + Unit.GetUIStatFromAbilities(eStat_ShieldHP));

    //Promotion Progress
    strXP = GetPromotionProgress(Unit);

    //detailed list data
	return  strMissions @ strKills @ strXP @ strArmor @ strShields;			
}

//find the units xp and next rank xp threshold
simulated function string GetPromotionProgress(XComGameState_Unit Unit)
{
	local string promoteProgress;
	local int NumKills;
	local X2SoldierClassTemplate ClassTemplate;

	if (Unit.IsSoldier())
	{
		ClassTemplate = Unit.GetSoldierClassTemplate();
	}
	else
	{
		return "";
	}

	if (ClassTemplate == none || ClassTemplate.GetMaxConfiguredRank() <= Unit.GetSoldierRank() || ClassTemplate.bBlockRankingUp)
	{
		return "";
	}

	NumKills = Round(Unit.KillCount * ClassTemplate.KillAssistsPerKill);

	// Increase kills for WetWork bonus if appropriate - DEPRECATED
	NumKills += Round(Unit.WetWorkKills * class'X2ExperienceConfig'.default.NumKillsBonus * ClassTemplate.KillAssistsPerKill);

	// Add in bonus kills
	NumKills += Round(Unit.BonusKills * ClassTemplate.KillAssistsPerKill);

	//  Add number of kills from assists
	NumKills += Round(Unit.KillAssistsCount);

	// Add required kills of StartingRank
	NumKills += class'X2ExperienceConfig'.static.GetRequiredKills(Unit.StartingRank) * ClassTemplate.KillAssistsPerKill;

	// Add Non-tactical kills (from covert actions)
	NumKills += Unit.NonTacticalKills * ClassTemplate.KillAssistsPerKill;

	promoteProgress = NumKills $ "/" $ class'X2ExperienceConfig'.static.GetRequiredKills(Unit.GetSoldierRank() + 1) * ClassTemplate.KillAssistsPerKill;

	return class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_PromotionIcon, 16, 20, -6) $ "</img>" @ promoteProgress;
}

//construct status display time value
static function GetTimeLabelValue(int Hours, out int TimeValue, out string TimeLabel)
{	
	if (Hours < 0 || Hours > 24 * 30 * 12) // Ignore year long missions
	{
		TimeValue = 0;
		TimeLabel = "";
		return;
	}
	if (Hours > default.NUM_HOURS_TO_DAYS)
	{
		Hours = FCeil(float(Hours) / 24.0f);
		TimeValue = Hours;
		TimeLabel = class'UIUtilities_Text'.static.GetDaysString(Hours);
	}
	else
	{
		TimeValue = Hours;
		TimeLabel = class'UIUtilities_Text'.static.GetHoursString(Hours);
	}
}

//constuct status display message string
static function GetStatusStringsSeparate(XComGameState_Unit Unit, out string Status, out string TimeLabel, out int TimeValue)
{
	local bool bProjectExists;
	local int iHours;
	local LWTuple Tuple;

	Tuple = new class'LWTuple';
	Tuple.Id = 'CustomizeStatusStringsSeparate';
	Tuple.Data.Add(4);
	Tuple.Data[0].kind = LWTVBool;
	Tuple.Data[0].b = false;
	Tuple.Data[1].kind = LWTVString;
	Tuple.Data[1].s = Status;
	Tuple.Data[2].kind = LWTVString;
	Tuple.Data[2].s = TimeLabel;
	Tuple.Data[3].kind = LWTVInt;
	Tuple.Data[3].i = TimeValue;

	`XEVENTMGR.TriggerEvent('CustomizeStatusStringsSeparate', Tuple, Unit);

	if (Tuple.Data[0].b)
	{
		Status = Tuple.Data[1].s;
		TimeLabel = Tuple.Data[2].s;
		TimeValue = Tuple.Data[3].i;
		return;
	}
	
	if( Unit.IsInjured() )
	{
		Status = Unit.GetWoundStatus(iHours);
		if (Status != "")
        {
			bProjectExists = true;
        }
	}
	else if (Unit.IsOnCovertAction())
	{
		Status = Unit.GetCovertActionStatus(iHours);
		if (Status != "")
        {
			bProjectExists = true;
        }
	}
	else if (Unit.IsTraining() || Unit.IsPsiTraining() || Unit.IsPsiAbilityTraining())
	{
		Status = Unit.GetTrainingStatus(iHours);
		if (Status != "")
        {
			bProjectExists = true;
        }
	}
	else if( Unit.IsDead() )
	{
		Status = "KIA";
	}
	else
	{
		Status = "";
	}
	
	if (bProjectExists)
	{
		GetTimeLabelValue(iHours, TimeValue, TimeLabel);
	}
}

static function GetPersonnelStatusSeparate(XComGameState_Unit Unit, out string Status, out string TimeLabel, out string TimeValue, optional int FontSizeZ = -1, optional bool bIncludeMentalState = false)
{
	local EUIState eState; 
	local int TimeNum;
	local bool bHideZeroDays;

	bHideZeroDays = true;

	if(Unit.IsMPCharacter())
	{
		Status = class'UIUtilities_Strategy'.default.m_strAvailableStatus;
		eState = eUIState_Good;
		TimeNum = 0;
		Status = class'UIUtilities_Text'.static.GetColoredText(Status, eState, FontSizeZ);
		return;
	}

	// template names are set in X2Character_DefaultCharacters.uc
	if (Unit.IsScientist() || Unit.IsEngineer())
	{
		Status = class'UIUtilities_Text'.static.GetSizedText(Unit.GetLocation(), FontSizeZ);
	}
	else if (Unit.IsSoldier())
	{
		// soldiers get put into the hangar to indicate they are getting ready to go on a mission
		if(`HQPRES != none &&  `HQPRES.ScreenStack.IsInStack(class'UISquadSelect') && `XCOMHQ.IsUnitInSquad(Unit.GetReference()) )
		{
			Status = class'UIUtilities_Strategy'.default.m_strOnMissionStatus;
			eState = eUIState_Highlight;
		}
		else if (Unit.bRecoveryBoosted)
		{
			Status = class'UIUtilities_Strategy'.default.m_strBoostedStatus;
			eState = eUIState_Warning;
		}
		else if( Unit.IsInjured() || Unit.IsDead() )
		{
			GetStatusStringsSeparate(Unit, Status, TimeLabel, TimeNum);
			eState = eUIState_Bad;
		}
		else if(Unit.GetMentalState() == eMentalState_Shaken)
		{
			GetUnitMentalState(Unit, Status, TimeLabel, TimeNum);
			eState = Unit.GetMentalStateUIState();
		}
		else if( Unit.IsPsiTraining() || Unit.IsPsiAbilityTraining() )
		{
			GetStatusStringsSeparate(Unit, Status, TimeLabel, TimeNum);
			eState = eUIState_Psyonic;
		}
		else if( Unit.IsTraining() )
		{
			GetStatusStringsSeparate(Unit, Status, TimeLabel, TimeNum);
			eState = eUIState_Warning;
		}
		else if(  Unit.IsOnCovertAction() )
		{
			GetStatusStringsSeparate(Unit, Status, TimeLabel, TimeNum);
			eState = eUIState_Warning;
			bHideZeroDays = false;
		}
		else if(bIncludeMentalState && Unit.BelowReadyWillState())
		{
			GetUnitMentalState(Unit, Status, TimeLabel, TimeNum);
			eState = Unit.GetMentalStateUIState();
		}
		else
		{
			GetStatusStringsSeparate(Unit, Status, TimeLabel, TimeNum);
			if (Status == "")
			{
				Status = class'UIUtilities_Strategy'.default.m_strAvailableStatus;
				TimeNum = 0;
			}
			eState = eUIState_Good;
		}
	}

	Status = class'UIUtilities_Text'.static.GetColoredText(Status, eState, FontSizeZ);
	TimeLabel = class'UIUtilities_Text'.static.GetColoredText(TimeLabel, eState, FontSizeZ);
	if( TimeNum == 0 && bHideZeroDays )
    {
		TimeValue = "";
    }
	else
    {
		TimeValue = class'UIUtilities_Text'.static.GetColoredText(string(TimeNum), eState, FontSizeZ);
    }
}

//construct status display mental state
static function GetUnitMentalState(XComGameState_Unit UnitState, out string Status, out string TimeLabel, out int TimeValue)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersProjectRecoverWill WillProject;
	local int iHours;

	History = `XCOMHISTORY;
	Status = UnitState.GetMentalStateLabel();
	TimeLabel = "";
	TimeValue = 0;

	if(UnitState.BelowReadyWillState())
	{
		foreach History.IterateByClassType(class'XComGameState_HeadquartersProjectRecoverWill', WillProject)
		{
			if(WillProject.ProjectFocus.ObjectID == UnitState.ObjectID)
			{
				iHours = WillProject.GetCurrentNumHoursRemaining();
				GetTimeLabelValue(iHours, TimeValue, TimeLabel);
				break;
			}
		}
	}
}

//constuct string for PCS value
simulated function string GetStatBoostString(XComGameState_Item ImplantToAdd)
{
	local int Index, TotalBoost, BoostValue;
	local bool bHasStatBoostBonus;
	local XComGameState_HeadquartersXCom XComHQ;

	XComHQ = `XCOMHQ;

	if (XComHQ != none)
	{
		bHasStatBoostBonus = XComHQ.SoldierUnlockTemplates.Find('IntegratedWarfareUnlock') != INDEX_NONE;
	}

	if(ImplantToAdd != none)
	{
		BoostValue = ImplantToAdd.StatBoosts[0].Boost;

		if (bHasStatBoostBonus)
		{				
			if (X2EquipmentTemplate(ImplantToAdd.GetMyTemplate()).bUseBoostIncrement)
            {
				BoostValue += class'X2SoldierIntegratedWarfareUnlockTemplate'.default.StatBoostIncrement;
            }
			else
            {
				BoostValue += Round(BoostValue * class'X2SoldierIntegratedWarfareUnlockTemplate'.default.StatBoostValue);
            }
		}
			
		Index = ImplantToAdd.StatBoosts.Find('StatType', eStat_HP);

		if (Index == 0)
		{
			if (`SecondWaveEnabled('BetaStrike'))
			{
				BoostValue *= class'X2StrategyGameRulesetDataStructures'.default.SecondWaveBetaStrikeHealthMod;
			}
		}
		TotalBoost += BoostValue;
			
	}

	if(TotalBoost != 0)
    {
		return class'UIUtilities_Text'.static.GetColoredText((TotalBoost > 0 ? "+" : "") $ string(TotalBoost), TotalBoost > 0 ? eUIState_Good : eUIState_Bad);
    }
	else
    {
		return "";
    }
}

//should we show the psi value and icon ... yes
simulated function bool ShouldShowPsi(XComGameState_Unit Unit)
{
	local LWTuple EventTup;

	EventTup = new class'LWTuple';
	EventTup.Id = 'ShouldShowPsi';
	EventTup.Data.Add(2);
	EventTup.Data[0].kind = LWTVBool;
	EventTup.Data[0].b = false;
	EventTup.Data[1].kind = LWTVName;
	EventTup.Data[1].n = nameof(Screen.class);

	EventTup.Data[0].b = false;

	if (Unit.IsPsiOperative() || Unit.GetSoldierClassTemplateName() == 'Psionic' || Unit.GetSoldierClassTemplateName() == 'RustyPsionic')
	{
		EventTup.Data[0].b = true;
	}
    else if (default.ROOKIE_SHOW_PSI && Unit.GetRank() == 0 ) //&& !Unit.CanRankUpSoldier() && `XCOMHQ.IsTechResearched('Psionics'))
   	{
		EventTup.Data[0].b = true;
	}
    else if (default.ALWAYS_SHOW_PSI)
    {
		EventTup.Data[0].b = true;
    }

	`XEVENTMGR.TriggerEvent('DSLShouldShowPsi', EventTup, Unit);

	return EventTup.Data[0].b;
}

//should we show the mental state
simulated protected function bool ShouldDisplayMentalStatus (XComGameState_Unit Unit)
{
	if (class'X2DownloadableContentInfo_DetailedSoldierListWOTC'.default.IsRequiredCHLInstalled)
	{
		// Use the Community Highlander event so that we work with mods that
		// use the mental status display override hook
		return TriggerShouldDisplayMentalStatus(Unit);
	}

	// Fallback to default logic
	return Unit.IsActive();
}

simulated protected function bool TriggerShouldDisplayMentalStatus (XComGameState_Unit Unit)
{
	local XComLWTuple Tuple;

	Tuple = new class'XComLWTuple';
	Tuple.Data.Add(2);
	Tuple.Data[0].kind = XComLWTVBool;
	Tuple.Data[0].b = Unit.IsActive();
	Tuple.Data[1].kind = XComLWTVObject;
	Tuple.Data[1].o = Unit;

	`XEVENTMGR.TriggerEvent('SoldierListItem_ShouldDisplayMentalStatus', Tuple, self);

	return Tuple.Data[0].b;
}

///////////////////////////////////////////////////////////////
//  UPDATE DATA
//  THIS IS WHERE WE UPDATE THE BASE SCREEN
///////////////////////////////////////////////////////////////

simulated function UpdateData()
{
	local XComGameState_Unit Unit;
	local string UnitLoc, status, statusTimeLabel, statusTimeValue, classIcon, rankIcon, flagIcon, mentalStatus, rankshort, classname;
	local int iRank, iTimeNum, BondLevel;
	local X2SoldierClassTemplate SoldierClass;
	local XComGameState_ResistanceFaction FactionState;
	local SoldierBond BondData;
	local StateObjectReference BondmateRef;
	local float CohesionPercent, CohesionMax;
	local array<int> CohesionThresholds;
	
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	iRank = Unit.GetRank();

	SoldierClass = Unit.GetSoldierClassTemplate();
	FactionState = Unit.GetResistanceFaction();

	flagIcon = Unit.GetCountryTemplate().FlagImage;

	// update from CHL ... ELSE ... use basegame methods
	if (class'X2DownloadableContentInfo_DetailedSoldierListWOTC'.default.IsRequiredCHLInstalled)
	{
		// Use the Community Highlander function so that we work with mods that use the unit status hooks it provides.
		class'UIUtilities_Strategy'.static.GetPersonnelStatusSeparate(Unit, status, statusTimeLabel, statusTimeValue);

		rankIcon  = Unit.GetSoldierRankIcon(iRank);
		rankshort = Unit.GetSoldierShortRankName(iRank);
		classIcon = Unit.GetSoldierClassIcon();
		classname = Unit.GetSoldierClassDisplayName();
	}
	else
	{
		GetPersonnelStatusSeparate(Unit, status, statusTimeLabel, statusTimeValue);

		rankIcon  = class'UIUtilities_Image'.static.GetRankIcon(iRank, SoldierClass.DataName);
		rankshort = `GET_RANK_ABBRV(Unit.GetRank(), SoldierClass.DataName);
		classIcon = SoldierClass.IconImage;
		classname = SoldierClass != None ? SoldierClass.DisplayName : "";
	}

	mentalStatus = "";

	if(ShouldDisplayMentalStatus(Unit))
	{
		GetUnitMentalState(Unit, mentalStatus, statusTimeLabel, iTimeNum);
		statusTimeLabel = class'UIUtilities_Text'.static.GetColoredText(statusTimeLabel, Unit.GetMentalStateUIState());

		if(iTimeNum == 0)
		{
			statusTimeValue = "";
		}
		else
		{
			statusTimeValue = class'UIUtilities_Text'.static.GetColoredText(string(iTimeNum), Unit.GetMentalStateUIState());
		}
	}

	if( statusTimeValue == "" )
    {
		statusTimeValue = "---";
    }

	// if personnel is not staffed, don't show location
	if( class'UIUtilities_Strategy'.static.DisplayLocation(Unit) )
    {
		UnitLoc = class'UIUtilities_Strategy'.static.GetPersonnelLocation(Unit);
    }
	else
    {
		UnitLoc = "";
    }

	if (BondProgress == none)
	{
		BondProgress = Spawn(class'UIProgressBar', self);
	}

	if( BondIcon == none )
	{
		BondIcon = Spawn(class'UIBondIcon', self);
		if( `ISCONTROLLERACTIVE )
        {
			BondIcon.bIsNavigable = false; 
        }
	}

	if( Unit.HasSoldierBond(BondmateRef, BondData) )
	{
		BondLevel = BondData.BondLevel;

		if( !BondIcon.bIsInited )
		{
			BondProgress.InitProgressBar('UnitBondProgress', BondBarX, BondBarY, BondWidth, BondHeight);
			BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondData.Bondmate);
		}
		if (BondLevel < 3)
		{
			CohesionThresholds = class'X2StrategyGameRulesetDataStructures'.default.CohesionThresholds;
			CohesionMax = float(CohesionThresholds[Clamp(BondLevel + 1, 0, CohesionThresholds.Length - 1)]);
			CohesionPercent = float(BondData.Cohesion) / CohesionMax;
			BondProgress.SetPercent(CohesionPercent);
			BondProgress.Show();
			bShouldShowBondProgress = true;
		}
		else
		{
			BondProgress.Hide();
		}

		BondIcon.Show();
	}
	else if( Unit.ShowBondAvailableIcon(BondmateRef, BondData) )
	{
		BondLevel = BondData.BondLevel;

		if( !BondIcon.bIsInited )
		{
			BondProgress.InitProgressBar('UnitBondProgress', BondBarX, BondBarY, BondWidth, BondHeight);
			BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondmateRef);
		}
		BondIcon.Show();
		BondProgress.Hide();
		BondIcon.AnimateCohesion(true);
		BondProgress.Hide();
	}
	else
	{
		if( !BondIcon.bIsInited )
		{
			BondProgress.InitProgressBar('UnitBondProgress', BondBarX, BondBarY, BondWidth, BondHeight);
			BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondData.Bondmate);
		}
		BondIcon.Hide();
		BondProgress.Hide();
		bShouldHideBonds = true;
		BondLevel = -1;
	}

	//UPDATE ALL ORIGINAL DATA
	AS_UpdateDataSoldier(Caps(Unit.GetName(eNameType_Full)),
					Caps(Unit.GetName(eNameType_Nick)),
					Caps(rankshort),
					rankIcon,
					Caps(classname),
					classIcon,
					status,
					statusTimeValue $"\n" $ Class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(Class'UIUtilities_Text'.static.GetSizedText( statusTimeLabel, 12)),
					UnitLoc,
					flagIcon,
					false, //todo: is disabled 
					Unit.ShowPromoteIcon(),
					false, // psi soldiers can't rank up via missions
					mentalStatus,
					BondLevel);

	AS_SetFactionIcon(FactionState.GetFactionIcon());

    //ADD OUR NEW ICONS
	AddAdditionalItems(self);

	RefreshTooltipText();

	class'MoreDetailsManager'.static.GetOrSpawnParentDM(self).IsMoreDetails = false;
}

//////////////////////////////////////////////////////////
//  ADDING NEW STUFF HERE
//////////////////////////////////////////////////////////

function AddAdditionalItems(UIPersonnel_SoldierListItem ListItem)
{
	local XComGameState_Unit Unit;
	
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.UnitRef.ObjectID));

    //check language
	if(GetLanguage() == "JPN")
	{
		IconToValueOffsetY = -3.0;
	}

	//work out the units name for display
	if(Unit.GetName(eNameType_Nick) == " ")
    {
		strUnitName = CAPS(Unit.GetName(eNameType_First) @ Unit.GetName(eNameType_Last));
    }
	else
    {
		strUnitName = CAPS(Unit.GetName(eNameType_First) @ Unit.GetName(eNameType_Nick) @ Unit.GetName(eNameType_Last));
    }

    //shift old rows up to create space
    ListItem.MC.ChildSetNum("RankFieldContainer", "_y", (GetLanguage() == "JPN" ? -3 : 0));

	ListItem.MC.ChildSetString("NameFieldContainer.NameField", "htmlText", class'UIUtilities_Text'.static.GetColoredText(strUnitName, eUIState_Normal));
	ListItem.MC.ChildSetNum("NameFieldContainer.NameField", "_y", (GetLanguage() == "JPN" ? -25 :-22));

	ListItem.MC.ChildSetString("NicknameFieldContainer.NicknameField", "htmlText", " ");
	ListItem.MC.ChildSetBool("NicknameFieldContainer.NicknameField", "_visible", false);

	ListItem.MC.ChildSetNum("ClassFieldContainer", "_y", (GetLanguage() == "JPN" ? -3 : 0));

    //add icons rows per divider
    AddRankColumnIcons(Unit, ListItem);
	AddNameColumnIcons(Unit, ListItem);
	AddClassColumnIcons(Unit, ListItem);

    //update for focus
	UpdateDisabled();

	//update for initial visibility
	ShowDetailed(false);
}

// ADD icons to rank field ... combat intelligence , LW Officer Icon... (combat intelligence, LW Officer Icon)
function AddRankColumnIcons(XComGameState_Unit Unit, UIPersonnel_SoldierListItem ListItem)
{
	//local XComGameState_BaseObject OfficerComponent;
	local bool bUnitIsOfficer;

	bUnitIsOfficer = false;

   	IconXPos = 118;

    if (APIcon == none)
    {
        APIcon = Spawn(class'UIIcon', self);
        APIcon.bAnimateOnInit = false;
        APIcon.bDisableSelectionBrackets = true;

		APIcon.InitIcon('APIcon_ListItem_LW',,false, true);

		APIcon.SetForegroundColor(class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
		APIcon.SetBGColor( APColours[int(Unit.ComInt)]);	//also done later on in focus

    	APIcon.SetScale(IconScale * 0.6);
	    APIcon.SetPosition(IconXPos - (IconToValueOffsetX * 0.1), IconYPos);

		APIcon.LoadIcon(class'UIUtilities_Image'.static.ValidateImagePath("img:///UILibrary_RustyDSL.combatIntIcon"));		//"gfxStrategyComponents.combatIntIcon"
		APIcon.LoadIconBG(class'UIUtilities_Image'.static.ValidateImagePath("img:///UILibrary_RustyDSL.combatIntIcon_bg"));
    }

    APIcon.Show();

    if (APValue == none)
    {
		APValue = Spawn(class'UIText', self);
		APValue.bAnimateOnInit = false;
		APValue.InitText('APValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	APValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(Unit.AbilityPoints), eUIState_Normal));

	//LW's Officer Icon, added to rank			-- REMOVED -- UNABLE TO CONFIRM UNIT STATUS AS AN OFFICER -- 
	//native final function XComGameState_BaseObject FindComponentObject(class<XComGameState_BaseObject> ComponentClass, optional bool FullHierarchy = true) const; 
	//	OfficerComponent = Unit.FindComponentObject(class<XComGameState_BaseObject>(class'XComEngine'.static.GetClassByName('XComGameState_Unit_LWOfficer') ), true )
	/*if ( OfficerComponent != none )
	{
		bUnitIsOfficer = true;
	}*/
	
	if (Unit.HasAbilityFromAnySource('Leadership'))
	{
		bUnitIsOfficer = true;
	}

	`LOG("Unit" @Unit.GetName(eNameType_Full) @": Is An Officer: " @bUnitIsOfficer @": RustyPositionTest :" @default.bRustyOfficerIconPositionTest, default.bRustyEnableDSLLogging, 'DSLRusty_SLI');

	if (bUnitIsOfficer || default.bRustyOfficerIconPositionTest)
	{
		if (OfficerIcon == none) 
		{
			OfficerIcon = Spawn(class'UIIcon', self);
	        OfficerIcon.bAnimateOnInit = false;
	        OfficerIcon.bDisableSelectionBrackets = true;
			
			OfficerIcon.InitIcon('OfficerIcon_ListItem_LW', "img:///UILibrary_RustyDSL.LWOfficers_Generic", false, true, 18);
		} 

		//OfficerIcon.OriginTopLeft();
		OfficerIcon.SetPosition(IconXPos - (518 * 0.1), IconYPos -18 );	//top left of the rank icon, as chosen by Arubiano 'the yellow square'
		OfficerIcon.Show();
	}
	else
	{
		if (OfficerIcon != none)
		{
			OfficerIcon.Hide();
		}
	}
}

//ADD icons to name field ... health, mobility, dodge, hack, psi, traits ... (detailed, abilities)
function AddNameColumnIcons(XComGameState_Unit Unit, UIPersonnel_SoldierListItem ListItem)
{
	local X2EventListenerTemplateManager EventTemplateManager;
	local X2TraitTemplate TraitTemplate;
	local X2AbilityTemplate AbilityTemplate;
	local int i, AWCRank;

	EventTemplateManager = class'X2EventListenerTemplateManager'.static.GetEventListenerTemplateManager();

	IconXPos = 174;

    //add detailed
	if (DetailedData == none)
	{
		DetailedData = Spawn(class'UIText', self);
		DetailedData.bAnimateOnInit = false;
		DetailedData.InitText('DetailedData_ListItem_LW').SetPosition(IconXPos, IconYPos + IconToValueOffsetY);
	}
	DetailedData.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(GetDetailedText(Unit), eUIState_Normal));

	if(HealthIcon == none)
	{
		HealthIcon = Spawn(class'UIImage', self);
		HealthIcon.bAnimateOnInit = false;
		HealthIcon.InitImage('HealthIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Health").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(HealthValue == none)
	{
		HealthValue = Spawn(class'UIText', self);
		HealthValue.bAnimateOnInit = false;
		HealthValue.InitText('HealthValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	HealthValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_HP))), eUIState_Normal));

	IconXPos += IconXDeltaSmallValue;

	if(MobilityIcon == none)
	{
		MobilityIcon = Spawn(class'UIImage', self);
		MobilityIcon.bAnimateOnInit = false;
		MobilityIcon.InitImage('MobilityIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Mobility").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(MobilityValue == none)
	{
		MobilityValue = Spawn(class'UIText', self);
		MobilityValue.bAnimateOnInit = false;
		MobilityValue.InitText('MobilityValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	MobilityValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Mobility))), eUIState_Normal));

	IconXPos += IconXDeltaSmallValue;

	if(DodgeIcon == none)
	{
		DodgeIcon = Spawn(class'UIImage', self);
		DodgeIcon.bAnimateOnInit = false;
		DodgeIcon.InitImage('DodgeIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Dodge").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(DodgeValue == none)
	{
		DodgeValue = Spawn(class'UIText', self);
		DodgeValue.bAnimateOnInit = false;
		DodgeValue.InitText('DodgeValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	DodgeValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Dodge))), eUIState_Normal));

	IconXPos += IconXDeltaSmallValue;

	if(HackIcon == none)
	{
		HackIcon = Spawn(class'UIImage', self);
		HackIcon.bAnimateOnInit = false;
		HackIcon.InitImage('HackIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Hacking").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(HackValue == none)
	{
		HackValue = Spawn(class'UIText', self);
		HackValue.bAnimateOnInit = false;
		HackValue.InitText('HackValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	HackValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Hacking))), eUIState_Normal));

	IconXPos += IconXDeltaSmallValue;

	if (ShouldShowPsi(Unit))
	{
		if(PsiIcon == none)
		{
			PsiIcon = Spawn(class'UIImage', self);
			PsiIcon.bAnimateOnInit = false;
			PsiIcon.InitImage('PsiIcon_ListItem_LW', "gfxXComIcons.promote_psi").SetScale(IconScale).SetPosition(IconXPos, IconYPos+1);
		}
		if(PsiValue == none)
		{
			PsiValue = Spawn(class'UIText', self);
			PsiValue.bAnimateOnInit = false;
			PsiValue.InitText('PsiValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
		}
		PsiValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_PsiOffense))), eUIState_Normal));
	}

    //big gap
	IconXPos += IconXDelta;

    // Bad Traits Panel spawn
	if (BadTraitPanel == none)
	{
		BadTraitPanel = Spawn(class'UIPanel', self);
		BadTraitPanel.bAnimateOnInit = false;
		BadTraitPanel.bIsNavigable = false;
		BadTraitPanel.InitPanel('BadTraitIcon_List_LW');
		BadTraitPanel.SetPosition(IconXPos, IconYPos+1);
		BadTraitPanel.SetSize(IconScale * 4, IconScale);
	}

    //bad traits panel fill
	for (i = 0; i < Unit.AcquiredTraits.Length; i++)
	{
		TraitTemplate = X2TraitTemplate(EventTemplateManager.FindEventListenerTemplate(Unit.AcquiredTraits[i]));
		if (TraitTemplate != none)
		{
			BadTraitIcon.InsertItem(i, Spawn(class'UIIcon', BadTraitPanel));
			BadTraitIcon[i].bAnimateOnInit = false;
			BadTraitIcon[i].bDisableSelectionBrackets = true;
			BadTraitIcon[i].InitIcon(name("TraitIcon_ListItem_LW_" $ i), TraitTemplate.IconImage, false, false).SetScale(IconScale).SetPosition(TraitIconX, 0);
			BadTraitIcon[i].SetForegroundColor("9acbcb");
			TraitIconX += IconToValueOffsetX;
		}
	}

	//extra little gap, cause I add a shields display
	IconXPos += IconXDeltaSmallValue;

    //detailed AWC abilities spawn
	if (BonusAbilityPanel == none)
	{
		BonusAbilityPanel = Spawn(class'UIPanel', self);
		BonusAbilityPanel.bAnimateOnInit = false;
		BonusAbilityPanel.bIsNavigable = false;
		BonusAbilityPanel.InitPanel('BonusAbilityIcon_List_LW');
		BonusAbilityPanel.SetPosition(IconXPos - (IconXDelta * 0.5), IconYPos+1);
		BonusAbilityPanel.SetSize(IconScale * 4, IconScale);
	}

    //detailed AWC fill
	if (Unit.GetSoldierClassTemplateName() != '' && Unit.bRolledForAWCAbility)
	{
		AWCRank = Unit.GetSoldierClassTemplate().AbilityTreeTitles.Length - 1;

		for (i = 1; i < Unit.GetSoldierClassTemplate().GetMaxConfiguredRank(); i++)
		{
			if (Unit.AbilityTree[i].Abilities.Length > AWCRank && Unit.HasSoldierAbility(Unit.AbilityTree[i].Abilities[AWCRank].AbilityName))
			{
				AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(Unit.AbilityTree[i].Abilities[AWCRank].AbilityName);
				BonusAbilityIcon.AddItem(Spawn(class'UIIcon', BonusAbilityPanel));
				BonusAbilityIcon[BonusAbilityIcon.Length - 1].bAnimateOnInit = false;
				BonusAbilityIcon[BonusAbilityIcon.Length - 1].bDisableSelectionBrackets = true;
				BonusAbilityIcon[BonusAbilityIcon.Length - 1].InitIcon(name("AbilityIcon_ListItem_LW_" $ i), AbilityTemplate.IconImage, false, false).SetScale(IconScale).SetPosition(AbilityIconX, 0);
				BonusAbilityIcon[BonusAbilityIcon.Length - 1].SetForegroundColor("9acbcb");
				AbilityIconX += IconToValueOffsetX;
			}
		}
	}

    //stop adding stuffs
}

//ADD icons to Class field ... Aim, will, ... (pcs, defense)
function AddClassColumnIcons(XComGameState_Unit Unit, UIPersonnel_SoldierListItem ListItem)
{
	local array<XComGameState_Item> EquippedImplants;

	IconXPos = 600;

	if (PCSIcon == none)
	{
		PCSIcon = Spawn(class'UIImage', self);
		PCSIcon.bAnimateOnInit = false;
		PCSIcon.InitImage().SetScale(IconScale * 0.5).SetPosition(IconXPos, IconYPos);
	}
	if (PCSValue == none)
	{
		PCSValue = Spawn(class'UIText', self);
		PCSValue.bAnimateOnInit = false;
		PCSValue.InitText().SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}

	EquippedImplants = Unit.GetAllItemsInSlot(eInvSlot_CombatSim);

	if (EquippedImplants.Length > 0)
	{
		PCSIcon.LoadImage(class'UIUtilities_Image'.static.GetPCSImage(EquippedImplants[0]));
		PCSValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(GetStatBoostString(EquippedImplants[0]), eUIState_Normal));
	}

	if(AimIcon == none)
	{
		AimIcon = Spawn(class'UIImage', self);
		AimIcon.bAnimateOnInit = false;
		AimIcon.InitImage('AimIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Aim").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(AimValue == none)
	{
		AimValue = Spawn(class'UIText', self);
		AimValue.bAnimateOnInit = false;
		AimValue.InitText().SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	AimValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Offense))), eUIState_Normal));

	IconXPos += IconXDelta;

	if(WillIcon == none)
	{
		WillIcon = Spawn(class'UIImage', self);
		WillIcon.bAnimateOnInit = false;
		WillIcon.InitImage('WillIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Will").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(WillValue == none)
	{
		WillValue = Spawn(class'UIText', self);
		WillValue.bAnimateOnInit = false;
		WillValue.InitText('WillValue_ListItem_LW').SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	WillValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Will))), eUIState_Normal));

	if(DefenseIcon == none)
	{
		DefenseIcon = Spawn(class'UIImage', self);
		DefenseIcon.bAnimateOnInit = false;
		DefenseIcon.InitImage('DefenseIcon_ListItem_LW', "UILibrary_RustyDSL.Image_Defense").SetScale(IconScale).SetPosition(IconXPos, IconYPos);
	}
	if(DefenseValue == none)
	{
		DefenseValue = Spawn(class'UIText', self);
		DefenseValue.bAnimateOnInit = false;
		DefenseValue.InitText().SetPosition(IconXPos + IconToValueOffsetX, IconYPos + IconToValueOffsetY);
	}
	DefenseValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(string(int(Unit.GetCurrentStat(eStat_Defense))), eUIState_Normal));
}

////////////////////////////////////////////////////////////////
//  UPDATE AND SWITCH LISTS
///////////////////////////////////////////////////////////////

function ShowDetailed(bool IsDetailed)
{
	local XComGameState_Unit Unit;
	
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

    //HIDE EVERYTHING
    APValue.Hide();         APIcon.Hide();
    
    DetailedData.Hide();

	HealthValue.Hide();     HealthIcon.Hide();
	MobilityValue.Hide();	MobilityIcon.Hide();
	DodgeValue.Hide();		DodgeIcon.Hide();
	HackValue.Hide();		HackIcon.Hide();
	PsiValue.Hide();		PsiIcon.Hide();
	BondIcon.Hide();		BondProgress.Hide();

    BadTraitPanel.Hide();   BonusAbilityPanel.Hide();

	AimValue.Hide();		AimIcon.Hide();
	WillValue.Hide();		WillIcon.Hide();
	PCSValue.Hide();        PCSIcon.Hide();	
    DefenseValue.Hide();    DefenseIcon.Hide();	

    //Show what is required
	if (IsDetailed)
	{
        APValue.Show();				APIcon.Show();

        DetailedData.Show();
        BonusAbilityPanel.Show();

        DefenseIcon.Show();			DefenseValue.Show();
        PCSIcon.Show();				PCSValue.Show();
	}
	else
	{
        APValue.Show();			APIcon.Show();

		HealthValue.Show();		HealthIcon.Show();
		MobilityValue.Show();	MobilityIcon.Show();
		DodgeValue.Show();		DodgeIcon.Show();
		HackValue.Show();       HackIcon.Show();

		if (ShouldShowPsi(Unit))
		{
			PsiValue.Show();	PsiIcon.Show();
		}

		BadTraitPanel.Show();

		if (!bShouldHideBonds)
		{
			BondIcon.Show();
			if (bShouldShowBondProgress)
			{
				BondProgress.Show();
			}
		}

		AimValue.Show();		AimIcon.Show();
		WillValue.Show();		WillIcon.Show();
	}
}
//////////////////////////////////////////////////
//  UI MANIPULATION
/////////////////////////////////////////////////

simulated function UIButton SetDisabled(bool disabled, optional string TooltipText)
{
	super.SetDisabled(disabled, TooltipText);
	UpdateDisabled();
	UpdateItemsForFocus(false);
	return self;
}

//adjust icons for disabled view (almost blacked out)
simulated function UpdateDisabled()
{
	local float UpdateAlpha;

	UpdateAlpha = (IsDisabled ? DisabledAlpha : 1.0f);

	if(HealthIcon == none)
		return;

	HealthIcon.SetAlpha(UpdateAlpha);
	MobilityIcon.SetAlpha(UpdateAlpha);
	DefenseIcon.SetAlpha(UpdateAlpha);
	DodgeIcon.SetAlpha(UpdateAlpha);
	HackIcon.SetAlpha(UpdateAlpha);
	PsiIcon.SetAlpha(UpdateAlpha);

	AimIcon.SetAlpha(UpdateAlpha);
	WillIcon.SetAlpha(UpdateAlpha);
}

//adjust text for highlight
simulated function UpdateItemsForFocus(bool Focussed)
{
	local int iUIState;
	local XComGameState_Unit Unit;
	local bool bReverse;
	local string AP, Health, Mobility, Dodge, Hack, Psi, Aim, Defense, Will;
	local UIIcon traitIcon;
	local array<XComGameState_Item> EquippedImplants;

	iUIState = (IsDisabled ? eUIState_Disabled : eUIState_Normal);

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	bIsFocussed = Focussed;
	bReverse = bIsFocussed && !IsDisabled;

	// Get Unit base stats and any stat modifications from abilities
    AP =        string(Unit.AbilityPoints);
    
   	Health =    string(int(Unit.GetCurrentStat(eStat_HP))           + Unit.GetUIStatFromAbilities(eStat_HP));
	Mobility =  string(int(Unit.GetCurrentStat(eStat_Mobility))     + Unit.GetUIStatFromAbilities(eStat_Mobility));
	Dodge =     string(int(Unit.GetCurrentStat(eStat_Dodge))        + Unit.GetUIStatFromAbilities(eStat_Dodge));
	Hack =      string(int(Unit.GetCurrentStat(eStat_Hacking))      + Unit.GetUIStatFromAbilities(eStat_Hacking));
	Psi =       string(int(Unit.GetCurrentStat(eStat_PsiOffense))   + Unit.GetUIStatFromAbilities(eStat_PsiOffense));

	Aim =       string(int(Unit.GetCurrentStat(eStat_Offense))      + Unit.GetUIStatFromAbilities(eStat_Offense));
	Defense =   string(int(Unit.GetCurrentStat(eStat_Defense))      + Unit.GetUIStatFromAbilities(eStat_Defense));
	Will =      string(int(Unit.GetCurrentStat(eStat_Will))         + Unit.GetUIStatFromAbilities(eStat_Will))      $ "/" $ string(int(Unit.GetMaxStat(eStat_Will)));
	
    //set color values
    APValue.SetHtmlText(        class'UIUtilities_Text'.static.GetColoredText(AP,           (bReverse ? -1 : iUIState)));

	APIcon.SetForegroundColor(class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
	APIcon.SetBGColor( APColours[int(Unit.ComInt)]);

	HealthValue.SetHtmlText(    class'UIUtilities_Text'.static.GetColoredText(Health,       (bReverse ? -1 : iUIState)));
	MobilityValue.SetHtmlText(  class'UIUtilities_Text'.static.GetColoredText(Mobility,     (bReverse ? -1 : iUIState)));
	DodgeValue.SetHtmlText(     class'UIUtilities_Text'.static.GetColoredText(Dodge,        (bReverse ? -1 : iUIState)));
	HackValue.SetHtmlText(      class'UIUtilities_Text'.static.GetColoredText(Hack,         (bReverse ? -1 : iUIState)));
	PsiValue.SetHtmlText(       class'UIUtilities_Text'.static.GetColoredText(Psi,          (bReverse ? -1 : iUIState)));

	AimValue.SetHtmlText(       class'UIUtilities_Text'.static.GetColoredText(Aim,          (bReverse ? -1 : iUIState)));
	DefenseValue.SetHtmlText(   class'UIUtilities_Text'.static.GetColoredText(Defense,      (bReverse ? -1 : iUIState)));
	WillValue.SetHtmlText(      class'UIUtilities_Text'.static.GetColoredText(Will,         Unit.GetMentalStateUIState()));

	DetailedData.SetHtmlText(   class'UIUtilities_Text'.static.GetColoredText(GetDetailedText(Unit), (bReverse ? -1 : iUIState)));
	
	EquippedImplants = Unit.GetAllItemsInSlot(eInvSlot_CombatSim);
	if (EquippedImplants.Length > 0)
	{
		PCSValue.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(GetStatBoostString(EquippedImplants[0]), (bReverse ? -1 : iUIState)));
	}

	foreach BadTraitIcon(traitIcon)
	{
		traitIcon.SetForegroundColor(bReverse ? "000000" : "9acbcb"); //black to cyan
	}

	foreach BonusAbilityIcon(traitIcon)
	{
		traitIcon.SetForegroundColor(bReverse ? "000000" : "9acbcb"); //black to cyan
	}
}

//makes bond icon have a flashy outline
simulated function FocusBondEntry(bool IsFocus)
{
	local XComGameState_Unit Unit;
	local UIPersonnel_SoldierListItemDetailed OtherListItem;
	local array<UIPanel> AllOtherListItem;
	local UIPanel OtherItem;
	local StateObjectReference BondmateRef;
	local SoldierBond BondData;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if( Unit.HasSoldierBond(BondmateRef, BondData) )
	{
		ParentPanel.GetChildrenOfType(class'UIPersonnel_SoldierListItemDetailed', AllOtherListItem);
		foreach AllOtherListitem(OtherItem)
		{
			OtherListItem = UIPersonnel_SoldierListItemDetailed(OtherItem);
			if (OtherListItem != none && OtherListItem.UnitRef.ObjectID == BondmateRef.ObjectID)
			{
				if (IsFocus)
				{
					OtherListItem.BondIcon.OnReceiveFocus();
				}
				else
				{
					OtherListItem.BondIcon.OnLoseFocus();
				}
			}
		}
	}
}

//refresh and update tooltips on hover over abilities and traits
simulated function RefreshTooltipText()
{
	local XComGameState_Unit Unit;
	local SoldierBond BondData;
	local StateObjectReference BondmateRef;
	local XComGameState_Unit Bondmate;
	local string textTooltip, traitTooltip;
	local X2EventListenerTemplateManager EventTemplateManager;
	local X2TraitTemplate TraitTemplate;
	local int i;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	EventTemplateManager = class'X2EventListenerTemplateManager'.static.GetEventListenerTemplateManager();

	textTooltip = "";
	traitTooltip = "";

	for (i = 0; i < Unit.AcquiredTraits.Length; i++)
	{
		TraitTemplate = X2TraitTemplate(EventTemplateManager.FindEventListenerTemplate(Unit.AcquiredTraits[i]));
		if (TraitTemplate != none)
		{
			if (traitTooltip != "")
			{
				traitTooltip $= "\n";
			}
			traitTooltip $= TraitTemplate.TraitFriendlyName @ "-" @ TraitTemplate.TraitDescription;
		}
	}

	if( Unit.HasSoldierBond(BondmateRef, BondData) )
	{
		Bondmate = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BondmateRef.ObjectID));
		textTooltip = Repl(BondmateTooltip, "%SOLDIERNAME", Caps(Bondmate.GetName(eNameType_RankFull)));
	}
	else if( Unit.ShowBondAvailableIcon(BondmateRef, BondData) )
	{
		textTooltip = class'XComHQPresentationLayer'.default.m_strBannerBondAvailable;
	}

	if (textTooltip != "")
	{
		textTooltip $= "\n\n" $ traitTooltip;
	}
	else
	{
		textTooltip = traitTooltip;
	}
	
	if (textTooltip != "")
	{
		SetTooltipText(textTooltip);
		Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	}
	else
	{
		SetTooltipText("");
	}
}

////////////////////////////////////////
//  'SCREEN' MANIPULATION
////////////////////////////////////////

simulated function OnMouseEvent(int Cmd, array<string> Args)
{
	Super(UIPanel).OnMouseEvent(Cmd, Args);
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	UpdateItemsForFocus(true);
	FocusBondEntry(true);
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	UpdateItemsForFocus(false);
	FocusBondEntry(false);
}

////////////////////////////////////////
//  DEFAULT PROPERTIES OF 'SCREEN'
////////////////////////////////////////

defaultproperties
{
	IconToValueOffsetX = 23.0f; // 26
	IconScale = 0.65f;
	IconYPos = 23.0f;
	IconXDelta = 60.0f; // 64
	IconXDeltaSmallValue = 48.0f;
	BondBarX = 488.0f;
	BondBarY = 43.0f;
	BondWidth = 36.0f;
	BondHeight = 6.0f;
	LibID = "SoldierListItem";
	DisabledAlpha = 0.5f;

	bAnimateOnInit = false;
}
