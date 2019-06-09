#pragma semicolon 1

// Sourcemod includes
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

// Third party includes
#include <smlib> // https://github.com/bcserv/smlib

#define PLUGIN_VERSION "1.6.1"

// that's what GetLanguageCount() got me
#define MAX_LANGUAGES 27

#define PREFIX "\x04Hide and Seek \x01> \x03"

// plugin cvars
ConVar g_cvVersion;
ConVar g_cvEnable;
ConVar g_cvFreezeCTs;
ConVar g_cvFreezeTime;
ConVar g_cvChangeLimit;
ConVar g_cvChangeLimittime;
ConVar g_cvAutoChoose;
ConVar g_cvWhistle;
ConVar g_cvWhistleSet;
ConVar g_cvWhistleTimes;
ConVar g_cvWhistleDelay;
ConVar g_cvWhistleAuto;
ConVar g_cvWhistleAutoTimer;
ConVar g_cvAntiCheat;
ConVar g_cvCheatPunishment;
ConVar g_cvHiderWinFrags;
ConVar g_cvSlaySeekers;
ConVar g_cvHPSeekerEnable;
ConVar g_cvHPSeekerDec;
ConVar g_cvHPSeekerInc;
ConVar g_cvHPSeekerBonus;
ConVar g_cvOpacityEnable;
ConVar g_cvHiderSpeed;
ConVar g_cvDisableRightKnife;
ConVar g_cvDisableDucking;
ConVar g_cvAutoThirdPerson;
ConVar g_cvHiderFreezeMode;
ConVar g_cvHideBlood;
ConVar g_cvShowHideHelp;
ConVar g_cvShowProgressBar;
ConVar g_cvCTRatio;
ConVar g_cvDisableUse;
ConVar g_cvHiderFreezeInAir;
ConVar g_cvRemoveShadows;
ConVar g_cvUseTaxedInRandom;
ConVar g_cvHidePlayerLocation;

// primary enableswitch
bool g_bEnableHnS;

// config and menu handles
Handle g_hModelMenu[MAX_LANGUAGES] = {INVALID_HANDLE, ...};
char g_sModelMenuLanguage[MAX_LANGUAGES][4];
Handle kv;

// offsets
int g_Render;
int g_flFlashDuration;
int g_flFlashMaxAlpha;
int g_Freeze;
int g_iHasNightVision;
int g_flLaggedMovementValue;
int g_flProgressBarStartTime;
int g_iProgressBarDuration;
int g_iAccount;

bool g_bInThirdPersonView[MAXPLAYERS+1] = {false,...};
bool g_bIsFreezed[MAXPLAYERS+1] = {false,...};
Handle g_hRoundTimeTimer = INVALID_HANDLE;
Handle g_iRoundTime = INVALID_HANDLE;
int g_iRoundStartTime = 0;

int g_iFirstCTSpawn = 0;
int g_iFirstTSpawn = 0;
Handle g_hShowCountdownTimer = INVALID_HANDLE;
Handle g_hSpamCommandsTimer = INVALID_HANDLE;
bool g_bRoundEnded = false;
bool g_bFirstSpawn[MAXPLAYERS+1] = {true,...};

// Cheat cVar part
Handle g_hCheckVarTimer[MAXPLAYERS+1] = {INVALID_HANDLE,...};
char cheat_commands[][] = {"cl_radaralpha", "r_shadows"};
bool g_bConVarViolation[MAXPLAYERS+1][2]; // 2 = amount of cheat_commands. update if you add one.
int g_iConVarMessage[MAXPLAYERS+1][2]; // 2 = amount of cheat_commands. update if you add one.
Handle g_hCheatPunishTimer[MAXPLAYERS+1] = {INVALID_HANDLE};

// Terrorist Modelchange stuff
int g_iTotalModelsAvailable = 0;
int g_iModelChangeCount[MAXPLAYERS+1] = {0,...};
bool g_bAllowModelChange[MAXPLAYERS+1] = {true,...};
Handle g_hAllowModelChangeTimer[MAXPLAYERS+1] = {INVALID_HANDLE,...};

// Model ground fix
float g_iFixedModelHeight[MAXPLAYERS+1] = {0.0,...};
bool g_bClientIsHigher[MAXPLAYERS+1] = {false,...};
int g_iLowModelSteps[MAXPLAYERS+1] = {0,...};

bool g_bIsCTWaiting[MAXPLAYERS+1] = {false,...};
Handle g_hFreezeCTTimer[MAXPLAYERS+1] = {INVALID_HANDLE,...};
Handle g_hUnfreezeCTTimer[MAXPLAYERS+1] = {INVALID_HANDLE,...};

// protected server cvars
char protected_cvars[][] = {
					"mp_flashlight",
				  	"sv_footsteps",
				  	"mp_limitteams",
				  	"mp_autoteambalance",
				  	"mp_freezetime",
				  	"sv_nonemesis",
				  	"sv_nomvp",
				  	"sv_nostats",
				  	"mp_playerid",
				 	"sv_allowminmodels",
				  	"sv_turbophysics",
				  	"mp_teams_unbalance_limit",
				  	"mp_show_voice_icons"
				};
int forced_values[] = {
					0, // mp_flashlight
					0, // sv_footsteps
					0, // mp_limitteams
					0, // mp_autoteambalance
					0, // mp_freezetime
					1, // sv_nonemesis
					1, // sv_nomvp
					1, // sv_nostats
					1, // mp_playerid
					0, // sv_allowminmodels
					1, // sv_turbophysics
					0, // mp_teams_unbalance_limit
					0 // mp_show_voice_icons
			};

int previous_values[13] = {0,...}; // save previous values when forcing above, so we can restore the config if hns is disabled midgame. !same as comment next line!
Handle g_hProtectedConvar[13] = {INVALID_HANDLE,...}; // 13 = amount of protected_cvars. update if you add one.
Handle g_hForceCamera = INVALID_HANDLE;

// whistle sounds variables
#define WHISTLE_SOUNDS_MAX 7
int g_iWhistleCount[MAXPLAYERS+1] = {0,...};
Handle g_hWhistleDelay = INVALID_HANDLE;
Handle g_hWhistleAuto = INVALID_HANDLE;
bool g_bWhistlingAllowed;
char WhistleSoundPath[WHISTLE_SOUNDS_MAX][PLATFORM_MAX_PATH];

// Teambalance
int g_iLastJoinedCT = -1;
bool g_bCTToSwitch[MAXPLAYERS+1] = {false,...};

// AFK check
float g_fSpawnPosition[MAXPLAYERS+1][3];

public Plugin myinfo =
{
	name = "Hide and Seek",
	author = "Maintainer: blackdevil72 | Credit to: Selax & Peace-Maker",
	description = "Terrorists set a model and hide, CT seek terrorists.",
	version = PLUGIN_VERSION,
	url = "https://github.com/blackdevil72/-Cs-S-SM-Hide-and-Seek"
};

public OnPluginStart()
{
	// Hide and Seek Versiion cvar
	g_cvVersion = 				CreateConVar("sm_hns_version", PLUGIN_VERSION, "Hide and Seek Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// Config cvars
	g_cvEnable = 				CreateConVar("sm_hns_enable", "1", "Enable the Hide and Seek Mod?", 0, true, 0.0, true, 1.0);
	g_cvFreezeCTs = 			CreateConVar("sm_hns_freezects", "1", "Should CTs get freezed and blinded on spawn?", 0, true, 0.0, true, 1.0);
	g_cvFreezeTime = 			CreateConVar("sm_hns_freezetime", "25.0", "How long should the CTs are freezed after spawn?", 0, true, 1.00, true, 120.00);
	g_cvChangeLimit = 			CreateConVar("sm_hns_changelimit", "2", "How often a T is allowed to choose his model ingame? 0 = unlimited", 0, true, 0.00);
	g_cvChangeLimittime = 		CreateConVar("sm_hns_changelimittime", "30.0", "How long should a T be allowed to change his model again after spawn?", 0, true, 0.00);
	g_cvAutoChoose = 			CreateConVar("sm_hns_autochoose", "0", "Should the plugin choose models for the hiders automatically?", 0, true, 0.0, true, 1.0);
	g_cvWhistle = 				CreateConVar("sm_hns_whistle", "1", "Are terrorists allowed to whistle?", _, true, 0.0, true, 1.0);
	g_cvWhistleSet =			CreateConVar("sm_hns_whistle_set", "0", "Wich whistle set to use. 0 = Default / 1 = Whistle / 2 = Birds / 3 = Custom", 0, true, 0.0, true, 3.0);
	g_cvWhistleTimes = 			CreateConVar("sm_hns_whistle_times", "5", "How many times a hider is allowed to whistle per round?", _, true, 0.0, true, 100.0);
	g_cvWhistleDelay =			CreateConVar("sm_hns_whistle_delay", "25.0", "How long after spawn should we delay the use of whistle?", 0, true, 0.00, true, 120.00);
	g_cvWhistleAuto =			CreateConVar("sm_hns_whistle_auto", "0", "Makes Terrorists automaticly whistle on a set timer.", 0, true, 0.00, true, 1.00);
	g_cvWhistleAutoTimer = 		CreateConVar("sm_hns_whistle_auto_timer", "120", "How often the Auto-Whistle setting will trigger (in seconds)", 0, true, 60.0, true, 300.0);
	g_cvAntiCheat = 			CreateConVar("sm_hns_anticheat", "0", "Check player cheat convars, 0 = off/1 = on.", 0, true, 0.0, true, 1.0);
	g_cvCheatPunishment = 		CreateConVar("sm_hns_cheat_punishment", "1", "How to punish players with wrong cvar values after 15 seconds? 0: Disabled. 1: Switch to Spectator. 2: Kick", 0, true, 0.00, true, 2.00);
	g_cvHiderWinFrags = 		CreateConVar("sm_hns_hider_win_frags", "5", "How many frags should surviving terrorists gain?", 0, true, 0.00, true, 10.00);
	g_cvSlaySeekers = 			CreateConVar("sm_hns_slay_seekers", "0", "Should we slay all seekers on round end and there are still some hiders alive?", 0, true, 0.0, true, 1.0);
	g_cvHPSeekerEnable = 		CreateConVar("sm_hns_hp_seeker_enable", "1", "Should CT lose HP when shooting, 0 = off/1 = on.", 0, true, 0.0, true, 1.0);
	g_cvHPSeekerDec = 			CreateConVar("sm_hns_hp_seeker_dec", "5", "How many hp should a CT lose on shooting?", 0, true, 0.00);
	g_cvHPSeekerInc = 			CreateConVar("sm_hns_hp_seeker_inc", "15", "How many hp should a CT gain when hitting a hider?", 0, true, 0.00);
	g_cvHPSeekerBonus = 		CreateConVar("sm_hns_hp_seeker_bonus", "50", "How many hp should a CT gain when killing a hider?", 0, true, 0.00);
	g_cvOpacityEnable = 		CreateConVar("sm_hns_opacity_enable", "0", "Should T get more invisible on low hp, 0 = off/1 = on.", 0, true, 0.0, true, 1.0);
	g_cvHiderSpeed  = 			CreateConVar("sm_hns_hidersspeed", "1.00", "Hiders speed.", 0, true, 1.00, true, 3.00);
	g_cvDisableRightKnife =		CreateConVar("sm_hns_disable_rightknife", "1", "Disable rightclick for CTs with knife? Prevents knifing without losing heatlh.", 0, true, 0.00, true, 1.00);
	g_cvDisableDucking =		CreateConVar("sm_hns_disable_ducking", "1", "Disable ducking: 0 = Disabled / 1 = Every one / 2 = Only Terrorists", 0, true, 0.00, true, 2.00);
	g_cvAutoThirdPerson =		CreateConVar("sm_hns_auto_thirdperson", "1", "Enable thirdperson view for hiders automatically.", 0, true, 0.00, true, 1.00);
	g_cvHiderFreezeMode =		CreateConVar("sm_hns_hider_freeze_mode", "2", "0: Disables /freeze command for hiders, 1: Only freeze on position, be able to move camera, 2: Freeze completely (no cameramovements)", 0, true, 0.00, true, 2.00);
	g_cvHideBlood =				CreateConVar("sm_hns_hide_blood", "1", "Hide blood on hider damage.", 0, true, 0.00, true, 1.00);
	g_cvShowHideHelp =			CreateConVar("sm_hns_show_hidehelp", "1", "Show helpmenu explaining the game on first player spawn.", 0, true, 0.00, true, 1.00);
	g_cvShowProgressBar =		CreateConVar("sm_hns_show_progressbar", "1", "Show progressbar for last 15 seconds of freezetime.", 0, true, 0.00, true, 1.00);
	g_cvCTRatio =				CreateConVar("sm_hns_ct_ratio", "3", "The ratio of hiders to 1 seeker. 0 to disables teambalance.", 0, true, 1.00, true, 64.00);
	g_cvDisableUse =			CreateConVar("sm_hns_disable_use", "1", "Disable CTs pushing things.", 0, true, 0.00, true, 1.00);
	g_cvHiderFreezeInAir =		CreateConVar("sm_hns_hider_freeze_inair", "0", "Are hiders allowed to freeze in the air?", 0, true, 0.00, true, 1.00);
	g_cvRemoveShadows =			CreateConVar("sm_hns_remove_shadows", "1", "Remove shadows from players and physic models?", 0, true, 0.00, true, 1.00);
	g_cvUseTaxedInRandom =		CreateConVar("sm_hns_use_taxed_in_random", "0", "Include taxed models when using random model choice?", 0, true, 0.00, true, 1.00);
	g_cvHidePlayerLocation=		CreateConVar("sm_hns_hide_player_locations", "1", "Hide the location info shown next to players name on voice chat and teamsay?", 0, true, 0.00, true, 1.00);

	g_bEnableHnS = GetConVarBool(g_cvEnable);
	HookConVarChange(g_cvEnable, Cfg_OnChangeEnable);
	HookConVarChange(FindConVar("mp_restartgame"), RestartGame);

	if (g_bEnableHnS)
	{
		// !ToDo: Exclude hooks and other EnableHnS dependand functions into one seperate function.
		// Now you need to add the hooks to the Cfg_OnChangeEnable callback too..
		HookConVarChange(g_cvHiderSpeed, OnChangeHiderSpeed);
		HookConVarChange(g_cvAntiCheat, OnChangeAntiCheat);

		// Hooking events
		HookEvent("player_spawn", Event_OnPlayerSpawn);
		HookEvent("weapon_fire", Event_OnWeaponFire);
		HookEvent("player_death", Event_OnPlayerDeath);
		HookEvent("player_blind", Event_OnPlayerBlind);
		HookEvent("round_start", Event_OnRoundStart);
		HookEvent("round_end", Event_OnRoundEnd);
		HookEvent("player_team", Event_OnPlayerTeam);
		HookEvent("item_pickup", Event_OnItemPickup);
	}

	// Register console commands
	RegConsoleCmd("hide", Menu_SelectModel, "Opens a menu with different models to choose as hider.");
	RegConsoleCmd("hidemenu", Menu_SelectModel, "Opens a menu with different models to choose as hider.");
	RegConsoleCmd("tp", Toggle_ThirdPerson, "Toggles the view to thirdperson for hiders.");
	RegConsoleCmd("thirdperson", Toggle_ThirdPerson, "Toggles the view to thirdperson for hiders.");
	RegConsoleCmd("third", Toggle_ThirdPerson, "Toggles the view to thirdperson for hiders.");
	RegConsoleCmd("+3rd", Enable_ThirdPerson, "Set the view to thirdperson for hiders.");
	RegConsoleCmd("-3rd", Disable_ThirdPerson, "Set the view to firstperson for hiders.");
	RegConsoleCmd("jointeam", Command_JoinTeam);
	RegConsoleCmd("whistle", Play_Whistle, "Plays a random sound from the hiders position to give the seekers a hint.");
	RegConsoleCmd("whoami", Display_ModelName, "Displays the current models description in chat.");
	RegConsoleCmd("hidehelp", Display_Help, "Displays a panel with informations how to play.");
	RegConsoleCmd("freeze", Freeze_Cmd, "Toggles freezing for hiders.");

	RegConsoleCmd("overview_mode", Block_Cmd);

	RegAdminCmd("sm_hns_force_whistle", ForceWhistle, ADMFLAG_CHAT, "Force a player to whistle");
	RegAdminCmd("sm_hns_reload_models", ReloadModels, ADMFLAG_RCON, "Reload the modellist from the map config file.");
	RegAdminCmd("sm_hns_plugin_version", PrintHnsVersion, ADMFLAG_CHAT, "Print Hide and Seek plugin version.");

	// Loading translations
	LoadTranslations("hide_and_seek.phrases");
	LoadTranslations("common.phrases"); // for FindTarget()

	// set the default values for cvar checking
	for (int CountDefValClient = 1; CountDefValClient <= MaxClients; CountDefValClient++)
	{
		for (int CountDefVal = 0; CountDefVal < sizeof(cheat_commands); CountDefVal++)
		{
			g_bConVarViolation[CountDefValClient][CountDefVal] = false;
			g_iConVarMessage[CountDefValClient][CountDefVal] = 0;
		}

		if (IsClientInGame(CountDefValClient))
			OnClientPutInServer(CountDefValClient);
	}

	if (g_bEnableHnS)
	{
		// start advertising spam
		g_hSpamCommandsTimer = CreateTimer(120.0, SpamCommands, 0);
	}

	// hook cvars
	g_hForceCamera =  FindConVar("mp_forcecamera");
	g_iRoundTime =  FindConVar("mp_roundtime");

	// get the offsets
	// for transparency
	g_Render = FindSendPropInfo("CAI_BaseNPC", "m_clrRender");
	if (g_Render == -1)
		SetFailState("Couldnt find the m_clrRender offset!");

	// for hiding players on radar
	g_flFlashDuration = FindSendPropInfo("CCSPlayer", "m_flFlashDuration");
	if (g_flFlashDuration == -1)
		SetFailState("Couldnt find the m_flFlashDuration offset!");

	g_flFlashMaxAlpha = FindSendPropInfo("CCSPlayer", "m_flFlashMaxAlpha");
	if (g_flFlashMaxAlpha == -1)
		SetFailState("Couldnt find the m_flFlashMaxAlpha offset!");
	
	g_Freeze = FindSendPropInfo("CBasePlayer", "m_fFlags");
	if (g_Freeze == -1)
		SetFailState("Couldnt find the m_fFlags offset!");

	g_iHasNightVision = FindSendPropInfo("CCSPlayer", "m_bHasNightVision");
	if (g_iHasNightVision == -1)
		SetFailState("Couldnt find the m_bHasNightVision offset!");

	g_flLaggedMovementValue = FindSendPropInfo("CCSPlayer", "m_flLaggedMovementValue");
	if (g_flLaggedMovementValue == -1)
		SetFailState("Couldnt find the m_flLaggedMovementValue offset!");

	g_flProgressBarStartTime = FindSendPropInfo("CCSPlayer", "m_flProgressBarStartTime");
	if (g_flProgressBarStartTime == -1)
		SetFailState("Couldnt find the m_flProgressBarStartTime offset!");

	g_iProgressBarDuration = FindSendPropInfo("CCSPlayer", "m_iProgressBarDuration");
	if (g_iProgressBarDuration == -1)
		SetFailState("Couldnt find the m_iProgressBarDuration offset!");

	g_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount");
	if (g_iAccount == -1)
		SetFailState("Couldnt find the m_iAccount offset!");

	AutoExecConfig(true, "plugin.hide_and_seek");
}

public OnPluginEnd()
{
	if (g_bEnableHnS)
		ServerCommand("mp_restartgame 1");
}

public OnConfigsExecuted()
{
	//Load Whistle Set form config
	LoadWhistleSet();

	if (g_bEnableHnS)
	{
		// set bad server cvars
		for (int a = 0; a < sizeof(protected_cvars); a++)
		{
			g_hProtectedConvar[a] = FindConVar(protected_cvars[a]);
			if (g_hProtectedConvar[a] == INVALID_HANDLE)
				continue;

			previous_values[a] = GetConVarInt(g_hProtectedConvar[a]);
			SetConVarInt(g_hProtectedConvar[a], forced_values[a], true);
			HookConVarChange(g_hProtectedConvar[a], OnCvarChange);
		}
	}
}

/*
*
* Generic Events
*
*/

public OnMapStart()
{
	if (!g_bEnableHnS)
		return;

	BuildMainMenu();

	PrecacheSound("radio/go.wav", true);
	PrecacheSound("buttons/weapon_cant_buy.wav", true);

	// prevent us from bugging after mapchange
	g_iFirstCTSpawn = 0;
	g_iFirstTSpawn = 0;

	if (g_hShowCountdownTimer != INVALID_HANDLE)
	{
		KillTimer(g_hShowCountdownTimer);
		g_hShowCountdownTimer = INVALID_HANDLE;
	}

	bool foundHostageZone = false;

	// check if there is a hostage rescue zone
	char eName[64];

	for (int CountEntMapStart = MaxClients; CountEntMapStart < GetMaxEntities(); CountEntMapStart++)
	{
		if (IsValidEdict(CountEntMapStart) && IsValidEntity(CountEntMapStart))
		{
			GetEdictClassname(CountEntMapStart, eName, sizeof(eName));
			if (StrContains(eName, "func_hostage_rescue") != -1)
			{
				foundHostageZone = true;
			}
		}
	}

	// add a hostage rescue zone if there isn't one, so T will win after round time
	if(!foundHostageZone)
	{
		int ent = CreateEntityByName("func_hostage_rescue");

		if (ent > 0)
		{
			float orign[3] = {-1000.0,...};
			DispatchKeyValue(ent, "targetname", "hidenseek_roundend");
			DispatchKeyValueVector(ent, "orign", orign);
			DispatchSpawn(ent);
		}
	}

	// Remove shadows
	// Thanks to Bacardi and Leonardo @ http://forums.alliedmods.net/showthread.php?t=154269
	if (GetConVarBool(g_cvRemoveShadows))
	{
		bool bShadowDisabled = false;
		int ent = -1;

		while ((ent = FindEntityByClassname(ent, "shadow_control")) != -1)
		{
			SetVariantInt(1);
			AcceptEntityInput(ent, "SetShadowsDisabled");
			bShadowDisabled = true;
		}

		// Some maps don't have a shadow_control entity, so we create one.
		// Thanks to zipcore's suggestion http://forums.alliedmods.net/showpost.php?p=1811214&postcount=16
		if (!bShadowDisabled)
		{
			ent = CreateEntityByName("shadow_control");
			
			if (ent != -1)
			{
				SetVariantInt(1);
				AcceptEntityInput(ent, "SetShadowsDisabled");
			}
		}
	}
}

public OnMapEnd()
{
	if (!g_bEnableHnS)
		return;

	CloseHandle(kv);

	for (int CountLangMapEnd = 0; CountLangMapEnd < MAX_LANGUAGES; CountLangMapEnd++)
	{
		if (g_hModelMenu[CountLangMapEnd] != INVALID_HANDLE)
		{
			CloseHandle(g_hModelMenu[CountLangMapEnd]);
			g_hModelMenu[CountLangMapEnd] = INVALID_HANDLE;
		}
		Format(g_sModelMenuLanguage[CountLangMapEnd], 4, "");
	}

	g_iFirstCTSpawn = 0;
	g_iFirstTSpawn = 0;

	if (g_hShowCountdownTimer != INVALID_HANDLE)
	{
		KillTimer(g_hShowCountdownTimer);
		g_hShowCountdownTimer = INVALID_HANDLE;
	}

	if (g_hRoundTimeTimer != INVALID_HANDLE)
	{
		KillTimer(g_hRoundTimeTimer);
		g_hRoundTimeTimer = INVALID_HANDLE;
	}

	if (g_hWhistleDelay != INVALID_HANDLE)
	{
		KillTimer(g_hWhistleDelay);
		g_hWhistleDelay = INVALID_HANDLE;
	}

	if (g_hWhistleAuto != INVALID_HANDLE)
	{
		KillTimer(g_hWhistleAuto);
		g_hWhistleAuto = INVALID_HANDLE;
	}
}

public OnClientPutInServer(int client)
{
	if (!g_bEnableHnS)
		return;

	if (!IsFakeClient(client) && GetConVarBool(g_cvAntiCheat))
		g_hCheckVarTimer[client] = CreateTimer(1.0, StartVarChecker, client, TIMER_REPEAT);

	// Hook weapon pickup
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponCanUse);

	// Hook attackings to hide blood
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);

	// Hide player location info
	SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

public OnClientDisconnect(int client)
{
	if (!g_bEnableHnS)
		return;

	// set the default values for cvar checking
	if (!IsFakeClient(client))
	{
		for (int CountClientCvarOnDc = 0; CountClientCvarOnDc < sizeof(cheat_commands); CountClientCvarOnDc++)
		{
			g_bConVarViolation[client][CountClientCvarOnDc] = false;
			g_iConVarMessage[client][CountClientCvarOnDc] = 0;
		}

		g_bInThirdPersonView[client] = false;
		g_bIsFreezed[client] = false;
		g_iModelChangeCount[client] = 0;
		g_bIsCTWaiting[client] = false;
		g_iWhistleCount[client] = 0;
		
		if (g_hCheatPunishTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hCheatPunishTimer[client]);
			g_hCheatPunishTimer[client] = INVALID_HANDLE;
		}
		
		if (g_bAllowModelChange[client] && g_hAllowModelChangeTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hAllowModelChangeTimer[client]);
			g_hAllowModelChangeTimer[client] = INVALID_HANDLE;
		}
		
		if (g_hFreezeCTTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hFreezeCTTimer[client]);
			g_hFreezeCTTimer[client] = INVALID_HANDLE;
		}
		
		if (g_hUnfreezeCTTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hUnfreezeCTTimer[client]);
			g_hUnfreezeCTTimer[client] = INVALID_HANDLE;
		}
	}

	g_bAllowModelChange[client] = true;
	g_bFirstSpawn[client] = true;

	g_bClientIsHigher[client] = false;
	g_iFixedModelHeight[client] = 0.0;
	g_iLowModelSteps[client] = 0;

	// Teambalancer
	g_bCTToSwitch[client] = false;
	CreateTimer(0.1, Timer_ChangeTeam, client, TIMER_FLAG_NO_MAPCHANGE);

	// AFK check
	for (int CountAfk = 0; CountAfk < 3; CountAfk++)
	{
		g_fSpawnPosition[client][CountAfk] = 0.0;
	}

	/*if (g_hCheckVarTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hCheckVarTimer[client]);
		g_hCheckVarTimer[client] = INVALID_HANDLE;
	}*/
}

// forbiden player actions
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	int iInitialButtons = buttons;
	int team = GetClientTeam(client);

	// don't allow ct's to shoot in the beginning of the round
	char weaponName[30];

	GetClientWeapon(client, weaponName, sizeof(weaponName));
	
	if (team == CS_TEAM_CT && g_bIsCTWaiting[client] && (buttons & IN_ATTACK || buttons & IN_ATTACK2))
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
	}
	
	// disable rightclick knifing for cts
	else if (team == CS_TEAM_CT && GetConVarBool(g_cvDisableRightKnife) && buttons & IN_ATTACK2 && !strcmp(weaponName, "weapon_knife"))
	{
		buttons &= ~IN_ATTACK2;
	}

	// Modelfix
	if (g_iFixedModelHeight[client] != 0.0 && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
	{
		float vecVelocity[3];
		vecVelocity[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
		vecVelocity[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
		vecVelocity[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");

		// Player isn't moving
		if (vecVelocity[0] == 0.0 && vecVelocity[1] == 0.0 && vecVelocity[2] == 0.0 && !(buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT || buttons & IN_JUMP))
		{
			if (!g_bClientIsHigher[client] && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
			{
				float vecClientOrigin[3];
				GetClientAbsOrigin(client, vecClientOrigin);
				vecClientOrigin[2] += g_iFixedModelHeight[client];
				TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
				SetEntityMoveType(client, MOVETYPE_NONE);
				g_bClientIsHigher[client] = true;
				g_iLowModelSteps[client] = 0;
			}
		}

		// Player is running for 60 thinks? make him visible for a short time
		else if (g_iLowModelSteps[client] == 60)
		{
			if (!g_bClientIsHigher[client] && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
			{
				float vecClientOrigin[3];
				GetClientAbsOrigin(client, vecClientOrigin);
				vecClientOrigin[2] += g_iFixedModelHeight[client];
				TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
			}

			g_iLowModelSteps[client] = 0;
		}
		
		// Player is moving
		else if (!g_bIsFreezed[client])
		{
			if (g_bClientIsHigher[client])
			{
				float vecClientOrigin[3];
				GetClientAbsOrigin(client, vecClientOrigin);
				vecClientOrigin[2] -= g_iFixedModelHeight[client];
				TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
				SetEntityMoveType(client, MOVETYPE_WALK);
				g_bClientIsHigher[client] = false;
			}

			g_iLowModelSteps[client]++;
		}

		// Always disable ducking for that kind of models.
		if (buttons & IN_DUCK)
			buttons &= ~IN_DUCK;
	}

	// disable ducking for everyone
	if (buttons & IN_DUCK && GetConVarInt(g_cvDisableDucking) == 1)
	{
		buttons &= ~IN_DUCK;
	}

	//disable ducking for Ts only
	else if (buttons & IN_DUCK && GetConVarInt(g_cvDisableDucking) == 2 && team == CS_TEAM_T)
	{
		buttons &= ~IN_DUCK;
	}

	// disable use for everyone
	if(GetConVarBool(g_cvDisableUse) && buttons & IN_USE)
		buttons &= ~IN_USE;

	if(iInitialButtons != buttons)
		return Plugin_Changed;
	else
		return Plugin_Continue;
}

// SDKHook Callbacks
public Action OnWeaponCanUse(int client, int weapon)
{
	// Allow only CTs to use a weapon
	if(g_bEnableHnS && IsClientInGame(client) && GetClientTeam(client) != CS_TEAM_CT)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// Used to block blood
// set a normal model right before death to avoid errors
public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	if (GetClientTeam(victim) == CS_TEAM_T)
	{
		int remainingHealth = GetClientHealth(victim)-RoundToFloor(damage);

		// Attacker is a human?
		if (GetConVarBool(g_cvHPSeekerEnable) && attacker > 0 && attacker <= MaxClients && IsPlayerAlive(attacker) && !IsPlayerAFK(victim))
		{
			int decrease = GetConVarInt(g_cvHPSeekerDec);

			SetEntityHealth(attacker, GetClientHealth(attacker)+GetConVarInt(g_cvHPSeekerInc)+decrease);

			// the hider died? give extra health! need to add the decreased value again, since he fired his gun and lost hp.
			// possible "bug": seeker could be slayed because weapon_fire is called earlier than player_hurt.
			if (remainingHealth < 0)
				SetEntityHealth(attacker, GetClientHealth(attacker)+GetConVarInt(g_cvHPSeekerBonus)+decrease);
		}

		// prevent errors in console because of missing death animation of prop ;)
		if (remainingHealth < 0)
		{
			//SetEntityModel(victim, "models/player/t_guerilla.mdl");
			return Plugin_Continue; // just let the damage get through
		}

		else if (GetConVarBool(g_cvOpacityEnable))
		{
			int alpha = 150 + RoundToNearest(10.5*float(remainingHealth/10));

			SetEntData(victim, g_Render+3, alpha, 1, true);
			SetEntityRenderMode(victim, RENDER_TRANSTEXTURE);
		}

		if (GetConVarBool(g_cvHideBlood))
		{
			// Simulate the damage
			SetEntityHealth(victim, remainingHealth);

			// Don't show the blood!
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Hook_OnPostThinkPost(int client)
{
	if (GetConVarBool(g_cvHidePlayerLocation))
		SetEntPropString(client, Prop_Send, "m_szLastPlaceName", "");
}

/*
*
* Hooked Events
*
*/
// Player Spawn event
public Action Event_OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetClientTeam(client);

	if (team <= CS_TEAM_SPECTATOR || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	else if (team == CS_TEAM_T) // Team T
	{
		// set the mp_forcecamera value correctly, so he can use thirdperson again
		if (!IsFakeClient(client) && GetConVarInt(g_hForceCamera) == 1)
			SendConVarValue(client, g_hForceCamera, "0");

		// reset model change count
		g_iModelChangeCount[client] = 0;
		g_bInThirdPersonView[client] = false;
		
		if (!IsFakeClient(client) && g_hAllowModelChangeTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hAllowModelChangeTimer[client]);
			g_hAllowModelChangeTimer[client] = INVALID_HANDLE;
		}
		
		g_bAllowModelChange[client] = true;

		// Reset model fix height
		g_iFixedModelHeight[client] = 0.0;
		g_bClientIsHigher[client] = false;

		// set the speed
		SetEntDataFloat(client, g_flLaggedMovementValue, GetConVarFloat(g_cvHiderSpeed), true);

		// reset the transparent
		if (GetConVarBool(g_cvOpacityEnable))
		{
			SetEntData(client,g_Render+3,255,1,true);
			SetEntityRenderMode(client, RENDER_TRANSTEXTURE);
		}

		float changeLimitTime = GetConVarFloat(g_cvChangeLimittime);

		// Assign a model to bots immediately and disable all menus or timers.
		if (IsFakeClient(client))
			g_hAllowModelChangeTimer[client] = CreateTimer(0.1, DisableModelMenu, client);
		
		else
		{
			char ClientLangId[4];
			GetClientLanguageID(client, ClientLangId, sizeof(ClientLangId));

			// only disable the menu, if it's not unlimited
			if (changeLimitTime > 0.0)
				g_hAllowModelChangeTimer[client] = CreateTimer(changeLimitTime, DisableModelMenu, client);

			// Set them to thirdperson automatically
			if (GetConVarBool(g_cvAutoThirdPerson))
				SetThirdPersonView(client, true);

			if (GetConVarBool(g_cvAutoChoose))
				SetRandomModel(client);
			
			else if (changeLimitTime > 0.0)
				DisplayMenu(g_hModelMenu[StringToInt(ClientLangId)], client, RoundToFloor(changeLimitTime));
			
			else
				DisplayMenu(g_hModelMenu[StringToInt(ClientLangId)], client, MENU_TIME_FOREVER);
		}

		g_iWhistleCount[client] = 0;
		g_bIsFreezed[client] = false;

		if (g_iFirstTSpawn == 0)
		{
			if (g_hWhistleDelay != INVALID_HANDLE)
			{
				KillTimer(g_hWhistleDelay);
				g_hWhistleDelay = INVALID_HANDLE;
			}

			if (g_hWhistleAuto != INVALID_HANDLE)
			{
				KillTimer(g_hWhistleAuto);
				g_hWhistleAuto = INVALID_HANDLE;
			}

			// Allow whistle for this round
			if (!g_bWhistlingAllowed && GetConVarBool(g_cvWhistle) && GetConVarFloat(g_cvWhistleDelay) > 0.0)
			{
				g_hWhistleDelay = CreateTimer(GetConVarFloat(g_cvWhistleDelay), Timer_AllowWhistle, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			else if (GetConVarBool(g_cvWhistleAuto) && GetConVarBool(g_cvWhistle))
			{
				g_bWhistlingAllowed = true;
				g_hWhistleAuto = CreateTimer(GetConVarFloat(g_cvWhistleAutoTimer), Timer_AutoWhistle, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			else if (GetConVarBool(g_cvWhistle))
			{
				g_bWhistlingAllowed = true;
			}
		}

		if (GetConVarBool(g_cvFreezeCTs))
			PrintToChat(client, "%s%t", PREFIX, "seconds to hide", RoundToFloor(GetConVarFloat(g_cvFreezeTime)));
		
		else
			PrintToChat(client, "%s%t", PREFIX, "seconds to hide", 0);
	}

	else if (team == CS_TEAM_CT) // Team CT
	{
		if (!IsFakeClient(client) && GetConVarInt(g_hForceCamera) == 1)
			SendConVarValue(client, g_hForceCamera, "1");

		int currentTime = GetTime();
		float freezeTime = GetConVarFloat(g_cvFreezeTime);
		
		// don't keep late spawning cts blinded longer than the others :)
		if (g_iFirstCTSpawn == 0)
		{
			if (g_hShowCountdownTimer != INVALID_HANDLE)
			{
				KillTimer(g_hShowCountdownTimer);
				g_hShowCountdownTimer = INVALID_HANDLE;
				
				if (GetConVarBool(g_cvShowProgressBar))
				{
					for (int CountCtAtSpawn = 1; CountCtAtSpawn <= MaxClients; CountCtAtSpawn++)
					{
						if (IsClientInGame(CountCtAtSpawn))
						{
							SetEntDataFloat(CountCtAtSpawn, g_flProgressBarStartTime, 0.0, true);
							SetEntData(CountCtAtSpawn, g_iProgressBarDuration, 0, 4, true);
						}
					}
				}
			}

			else if (GetConVarBool(g_cvFreezeCTs))
			{
				// show time in center
				g_hShowCountdownTimer = CreateTimer(0.01, ShowCountdown, RoundToFloor(GetConVarFloat(g_cvFreezeTime)));
			}

			g_iFirstCTSpawn = currentTime;
		}

		// only freeze spawning players if the freezetime is still running.
		if (GetConVarBool(g_cvFreezeCTs) && (float(currentTime - g_iFirstCTSpawn) < freezeTime))
		{
			g_bIsCTWaiting[client] = true;
			CreateTimer(0.05, FreezePlayer, client, TIMER_FLAG_NO_MAPCHANGE);

			// Start freezing player
			g_hFreezeCTTimer[client] = CreateTimer(2.0, FreezePlayer, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

//			if(g_hUnfreezeCTTimer[client] != INVALID_HANDLE)
//			{
//				KillTimer(g_hUnfreezeCTTimer[client]);
//				g_hUnfreezeCTTimer[client] = INVALID_HANDLE;
//			}

			// Stop freezing player
			g_hUnfreezeCTTimer[client] = CreateTimer(freezeTime-float(currentTime - g_iFirstCTSpawn), UnFreezePlayer, client, TIMER_FLAG_NO_MAPCHANGE);

			PrintToChat(client, "%s%t", PREFIX, "Wait for t to hide", RoundToFloor(freezeTime-float(currentTime - g_iFirstCTSpawn)));
		}

		// show help menu on first spawn
		if (GetConVarBool(g_cvShowHideHelp) && g_bFirstSpawn[client])
		{
			Display_Help(client, 0);
			g_bFirstSpawn[client] = false;
		}

		// Make sure CTs have a knife
		CreateTimer(2.0, Timer_CheckCTHasKnife, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	// hide radar
	// Huge thanks to GoD-Tony!
	SetEntDataFloat(client, g_flFlashDuration, 10000.0, true);
	SetEntDataFloat(client, g_flFlashMaxAlpha, 0.5, true);

	CreateTimer(0.5, Timer_SaveSpawnPosition, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

// subtract 5hp for every shot a seeker is giving
public Action Event_OnWeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	if (!GetConVarBool(g_cvHPSeekerEnable) || g_bRoundEnded)
		return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int decreaseHP = GetConVarInt(g_cvHPSeekerDec);
	int clientHealth = GetClientHealth(client);

	// he can take it
	if ((clientHealth-decreaseHP) > 0)
	{
		SetEntityHealth(client, (clientHealth-decreaseHP));
	}
	
	else // slay him
	{
		ForcePlayerSuicide(client);
	}
	
	return Plugin_Continue;
}

public Action Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	g_bRoundEnded = false;
	g_bWhistlingAllowed = false;

	// When disabling +use or "e" button open all doors on the map and keep them opened.
	bool bUse = GetConVarBool(g_cvDisableUse);

	char eName[64];
	for (int CountEntRounStart = MaxClients ; CountEntRounStart < GetMaxEntities(); CountEntRounStart++)
	{
		if ( IsValidEdict(CountEntRounStart) && IsValidEntity(CountEntRounStart) )
		{
			GetEdictClassname(CountEntRounStart, eName, sizeof(eName));

			// remove bombzones and hostages so no normal gameplay could end the round
			if ( StrContains(eName, "hostage_entity") != -1 || StrContains(eName, "func_bomb_target") != -1  || (StrContains(eName, "func_buyzone") != -1 && GetEntProp(CountEntRounStart, Prop_Data, "m_iTeamNum", 4) == CS_TEAM_T))
			{
				RemoveEdict(CountEntRounStart);
			}
			
			// Open all doors
			else if (bUse && StrContains(eName, "_door", false) != -1)
			{
				AcceptEntityInput(CountEntRounStart, "Open");
				HookSingleEntityOutput(CountEntRounStart, "OnClose", EntOutput_OnClose);
			}
		}
	}

	// Remove shadows
	// Thanks to Bacardi and Leonardo @ http://forums.alliedmods.net/showthread.php?t=154269
	if (GetConVarBool(g_cvRemoveShadows))
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "shadow_control")) != -1)
		{
			SetVariantInt(1);
			AcceptEntityInput(ent, "SetShadowsDisabled");
		}
	}

	// show the roundtime in env_hudhint entity
	g_iRoundStartTime = GetTime();
	int realRoundTime = RoundToNearest(GetConVarFloat(g_iRoundTime)*60.0);
	g_hRoundTimeTimer = CreateTimer(0.5, ShowRoundTime, realRoundTime, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

// give terrorists frags
public Action Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	// round has ended. used to not decrease seekers hp on shoot
	g_bRoundEnded = true;
	g_bWhistlingAllowed = false;

	g_iFirstCTSpawn = 0;
	g_iFirstTSpawn = 0;

	if (g_hShowCountdownTimer != INVALID_HANDLE)
	{
		KillTimer(g_hShowCountdownTimer);
		g_hShowCountdownTimer = INVALID_HANDLE;
	}

	if (g_hRoundTimeTimer != INVALID_HANDLE)
	{
		KillTimer(g_hRoundTimeTimer);
		g_hRoundTimeTimer = INVALID_HANDLE;
	}

	if (g_hWhistleDelay != INVALID_HANDLE)
	{
		KillTimer(g_hWhistleDelay);
		g_hWhistleDelay = INVALID_HANDLE;
	}

	if (g_hWhistleAuto != INVALID_HANDLE)
	{
		KillTimer(g_hWhistleAuto);
		g_hWhistleAuto = INVALID_HANDLE;
	}

	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(g_hUnfreezeCTTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hUnfreezeCTTimer[client]);
		g_hUnfreezeCTTimer[client] = INVALID_HANDLE;
	}

	int winnerTeam = GetEventInt(event, "winner");

	if (winnerTeam == CS_TEAM_T)
	{
		int increaseFrags = GetConVarInt(g_cvHiderWinFrags);

		bool aliveTerrorists = false;
		int iFrags = 0;
		
		// increase playerscore of all alive Terrorists
		for (int CountTRoundEnd = 1; CountTRoundEnd <= MaxClients; CountTRoundEnd++)
		{
			if (IsClientInGame(CountTRoundEnd) && IsPlayerAlive(CountTRoundEnd) && GetClientTeam(CountTRoundEnd) == CS_TEAM_T)
			{
				if (increaseFrags > 0)
				{
					// increase kills by x
					iFrags = GetClientFrags(CountTRoundEnd) + increaseFrags;
					SetEntProp(CountTRoundEnd, Prop_Data, "m_iFrags", iFrags, 4);
					aliveTerrorists = true;
				}

				// set godmode for the rest of the round
				SetEntProp(CountTRoundEnd, Prop_Data, "m_takedamage", 0, 1);
			}
		}

		if (aliveTerrorists)
		{
			PrintToChatAll("%s%t", PREFIX, "got frags", increaseFrags);
		}

		if (GetConVarBool(g_cvSlaySeekers))
		{
			// slay all seekers
			for (int CountCtSlay = 1; CountCtSlay <= MaxClients; CountCtSlay++)
			{
				if (IsClientInGame(CountCtSlay) && IsPlayerAlive(CountCtSlay) && GetClientTeam(CountCtSlay) == CS_TEAM_CT)
				{
					ForcePlayerSuicide(CountCtSlay);
				}
			}
		}
	}

	// Switch the flagged players to CT
	CreateTimer(0.1, Timer_SwitchTeams, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

// remove ragdolls on death...
public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_iFixedModelHeight[client] != 0.0 && g_bClientIsHigher[client])
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
		g_bClientIsHigher[client] = false;
	}

	g_iFixedModelHeight[client] = 0.0;
	g_bClientIsHigher[client] = false;

	// Show guns again.
	SetThirdPersonView(client, false);

	// set the mp_forcecamera value correctly, so he can watch his teammates
	// This doesn't work. Even if the convar is set to 0, the hiders are only able to spectate their teammates..
	if (GetConVarInt(g_hForceCamera) == 1)
	{
		if (!IsFakeClient(client) && GetClientTeam(client) != CS_TEAM_T)
			SendConVarValue(client, g_hForceCamera, "1");
		
		else if (!IsFakeClient(client))
			SendConVarValue(client, g_hForceCamera, "0");
	}

	if (!IsValidEntity(client) || IsPlayerAlive(client))
		return Plugin_Continue;

	// Unfreeze, if freezed before
	if (g_bIsFreezed[client])
	{
		if (GetConVarInt(g_cvHiderFreezeMode) == 1)
			SetEntityMoveType(client, MOVETYPE_WALK);
		
		else
		{
			SetEntData(client, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
			SetEntityMoveType(client, MOVETYPE_WALK);
		}

		g_bIsFreezed[client] = false;
	}

	if (GetClientTeam(client) == CS_TEAM_T)
		Effect_DissolvePlayerRagDoll(client, DISSOLVE_ELECTRICAL_LIGHT);
	
	else
		Effect_DissolvePlayerRagDoll(client, DISSOLVE_NORMAL);
	// Don't know if dissolve effect should be kept for team CT
	//	RemoveEdict(GetEntPropEnt(client, Prop_Send, "m_hRagdoll"));

	return Plugin_Continue;
}

public Event_OnPlayerBlind(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return;

	// Thanks to GoD-Tony!
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	float iDuration = GetEntDataFloat(client, g_flFlashDuration);
	if(iDuration > 0.1)
		iDuration -= 0.1;

	if (client && GetClientTeam(client) > 1)
		CreateTimer(iDuration, Timer_FlashEnd, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetEventInt(event, "team");
	bool disconnect = GetEventBool(event, "disconnect");

	// Handle the thirdperson view values
	// terrors are always allowed to view players in thirdperson
	if (client && !IsFakeClient(client) && GetConVarInt(g_hForceCamera) == 1)
	{
		if (team == CS_TEAM_T)
			SendConVarValue(client, g_hForceCamera, "0");
		
		else if	(team != CS_TEAM_CT)
			SendConVarValue(client, g_hForceCamera, "1");
	}

	// Player disconnected?
	if (disconnect)
		g_bCTToSwitch[client] = false;

	// Player joined spectator?
	if (!disconnect && team < CS_TEAM_T)
	{
		g_bCTToSwitch[client] = false;

		// Unblind and show weapons again
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		PerformBlind(client, 0);

		// Reset the model fix
		if (g_iFixedModelHeight[client] != 0.0 && g_bClientIsHigher[client])
		{
			SetEntityMoveType(client, MOVETYPE_OBSERVER);
		}

		g_iFixedModelHeight[client] = 0.0;
		g_bClientIsHigher[client] = false;

		// Unfreeze, if freezed before
		if (g_bIsFreezed[client])
		{
			if (GetConVarInt(g_cvHiderFreezeMode) == 1)
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			
			else
			{
				SetEntData(client, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			}

			g_bIsFreezed[client] = false;
		}
	}

	// Reset the last joined ct, if he left
	if (disconnect && g_iLastJoinedCT == client)
		g_iLastJoinedCT = -1;

	// Strip the player if joined T midround
	if (!disconnect && team == CS_TEAM_T && IsPlayerAlive(client))
	{
		StripPlayerWeapons(client);
	}

	// Ignore, if Teambalance is disabled
	if (GetConVarFloat(g_cvCTRatio) == 0.0)
		return Plugin_Continue;

	// GetTeamClientCount() doesn't handle the teamchange we're called for in player_team,
	// so wait two frames to update the counts
	CreateTimer(0.2, Timer_ChangeTeam, client, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Event_OnItemPickup(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnableHnS)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	char sItem[100];
	GetEventString(event, "item", sItem, sizeof(sItem));

	// restrict nightvision
	if(StrEqual(sItem, "nvgs", false))
		SetEntData(client, g_iHasNightVision, 0, 4, true);
}

public EntOutput_OnClose(const char[] output, caller, activator, float delay)
{
	AcceptEntityInput(caller, "Open");
}

/*
*
* Timer Callbacks
*
*/

// Freeze player function
public Action FreezePlayer(Handle timer, any client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || !g_bIsCTWaiting[client])
	{
		g_hFreezeCTTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	// Force him to watch at the ground.
	float fPlayerEyes[3];
	GetClientEyeAngles(client, fPlayerEyes);
	fPlayerEyes[0] = 180.0;
	TeleportEntity(client, NULL_VECTOR, fPlayerEyes, NULL_VECTOR);
	SetEntData(client, g_Freeze, FL_CLIENT|FL_ATCONTROLS, 4, true);
	SetEntityMoveType(client, MOVETYPE_NONE);
	PerformBlind(client, 255);

	return Plugin_Continue;
}

// Unfreeze player function
public Action UnFreezePlayer(Handle timer, any client)
{
	g_hUnfreezeCTTimer[client] = INVALID_HANDLE;

	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	SetEntData(client, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
	SetEntityMoveType(client, MOVETYPE_WALK);

	if (!IsConVarCheater(client))
		PerformBlind(client, 0);

	g_bIsCTWaiting[client] = false;

	EmitSoundToClient(client, "radio/go.wav");

	PrintToChat(client, "%s%t", PREFIX, "Go search");

	return Plugin_Stop;
}

public Action DisableModelMenu(Handle timer, any client)
{

	g_hAllowModelChangeTimer[client] = INVALID_HANDLE;

	if (!IsClientInGame(client))
		return Plugin_Stop;

	g_bAllowModelChange[client] = false;

	if (IsPlayerAlive(client))
		PrintToChat(client, "%s%t", PREFIX, "Modelmenu Disabled");

	// didn't he chose a model?
	if (GetClientTeam(client) == CS_TEAM_T && g_iModelChangeCount[client] == 0)
	{
		// give him a random one.
		PrintToChat(client, "%s%t", PREFIX, "Did not choose model");
		SetRandomModel(client);
	}

	return Plugin_Stop;
}

public Action StartVarChecker(Handle timer, any client)
{
	if (!IsClientInGame(client))
		return Plugin_Stop;

	// allow watching
	if (GetClientTeam(client) < CS_TEAM_T)
	{
		PerformBlind(client, 0);
		return Plugin_Continue;
	}

	// check all defined cvars for value "0"
	for (int CountCvarChecker = 0; CountCvarChecker < sizeof(cheat_commands); CountCvarChecker++)
		QueryClientConVar(client, cheat_commands[CountCvarChecker], ClientConVar, client);

	if (IsConVarCheater(client))
	{
		// Blind and Freeze player
		PerformBlind(client, 255);
		SetEntityMoveType(client, MOVETYPE_NONE);

		if (GetConVarInt(g_cvCheatPunishment) != 0 && g_hCheatPunishTimer[client] == INVALID_HANDLE)
		{
			g_hCheatPunishTimer[client] = CreateTimer(15.0, PerformCheatPunishment, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	else
	{
		if (g_hCheatPunishTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hCheatPunishTimer[client]);
			g_hCheatPunishTimer[client] = INVALID_HANDLE;
		}

		if (!g_bIsCTWaiting[client])
		{
			if (IsPlayerAlive(client))
				SetEntityMoveType(client, MOVETYPE_WALK);

			PerformBlind(client, 0);
		}
	}

	return Plugin_Continue;
}

public Action PerformCheatPunishment(Handle timer, any client)
{
	g_hCheatPunishTimer[client] = INVALID_HANDLE;

	if (!IsClientInGame(client) || !IsConVarCheater(client))
		return Plugin_Stop;

	int punishmentType = GetConVarInt(g_cvCheatPunishment);
	
	if (punishmentType == 1 && GetClientTeam(client) != CS_TEAM_SPECTATOR )
	{
		g_bCTToSwitch[client] = false;

		// Unblind and show weapons again
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		PerformBlind(client, 0);

		// Reset the model fix
		if (g_iFixedModelHeight[client] != 0.0 && g_bClientIsHigher[client])
		{
			SetEntityMoveType(client, MOVETYPE_OBSERVER);
		}

		g_iFixedModelHeight[client] = 0.0;
		g_bClientIsHigher[client] = false;

		// Unfreeze, if freezed before
		if (g_bIsFreezed[client])
		{
			if (GetConVarInt(g_cvHiderFreezeMode) == 1)
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			
			else
			{
				SetEntData(client, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
				SetEntityMoveType(client, MOVETYPE_OBSERVER);
			}

			g_bIsFreezed[client] = false;
		}

		if (g_iLastJoinedCT == client)
			g_iLastJoinedCT = -1;

		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		PrintToChatAll("%s%N %t", PREFIX, client, "Spectator Cheater");
	}

	else if (punishmentType == 2)
	{
		for (int CountPunishment = 0; CountPunishment < sizeof(cheat_commands); CountPunishment++)
			if (g_bConVarViolation[client][CountPunishment])
				PrintToConsole(client, "Hide and Seek: %t %s 0", "Print to console", cheat_commands[CountPunishment]);
		
		KickClient(client, "Hide and Seek: %t", "Kick bad cvars");
	}

	return Plugin_Stop;
}

// teach the players the /whistle and /tp commands
public Action SpamCommands(Handle timer, any data)
{
	if (GetConVarBool(g_cvWhistle) && data == 1)
		PrintToChatAll("%s%t", PREFIX, "T type /whistle");
	
	else if (!GetConVarBool(g_cvWhistle) || data == 0)
	{
		for (int CountSpamCmd = 1; CountSpamCmd <= MaxClients; CountSpamCmd++)
			if (IsClientInGame(CountSpamCmd) && GetClientTeam(CountSpamCmd) == CS_TEAM_T)
				PrintToChat(CountSpamCmd, "%s%t", PREFIX, "T type /tp");
	}

	g_hSpamCommandsTimer = CreateTimer(120.0, SpamCommands, (data==0?1:0));
	
	return Plugin_Stop;
}

// show all players a countdown
// CT: I'm coming!
public Action ShowCountdown(Handle timer, any freezeTime)
{
	int seconds = freezeTime - GetTime() + g_iFirstCTSpawn;
	
	PrintCenterTextAll("%d", seconds);
	
	if (seconds <= 0)
	{
		g_hShowCountdownTimer = INVALID_HANDLE;
		
		if (GetConVarBool(g_cvShowProgressBar))
		{
			for (int CountShowBar = 1; CountShowBar <= MaxClients; CountShowBar++)
			{
				if (IsClientInGame(CountShowBar))
				{
					SetEntDataFloat(CountShowBar, g_flProgressBarStartTime, 0.0, true);
					SetEntData(CountShowBar, g_iProgressBarDuration, 0, 4, true);
				}
			}
		}

		return Plugin_Stop;
	}

	// m_iProgressBarDuration has a limit of 15 seconds, so start showing the bar on 15 seconds left.
	if (GetConVarBool(g_cvShowProgressBar) && (seconds) < 15)
	{
		for (int CountShowBar2 = 1; CountShowBar2 <= MaxClients; CountShowBar2++)
		{
			if (IsClientInGame(CountShowBar2) && GetEntProp(CountShowBar2, Prop_Send, "m_iProgressBarDuration") == 0)
			{
				SetEntDataFloat(CountShowBar2, g_flProgressBarStartTime, GetGameTime(), true);
				SetEntData(CountShowBar2, g_iProgressBarDuration, seconds, 4, true);
			}
		}
	}

	g_hShowCountdownTimer = CreateTimer(0.5, ShowCountdown, freezeTime);

	return Plugin_Stop;
}

public Action ShowRoundTime(Handle timer, any roundTime)
{
	char timeLeft[10];
	int seconds = roundTime - GetTime() + g_iRoundStartTime;
	int minutes = RoundToFloor(float(seconds) / 60.0);
	int secs = seconds - minutes*60;

	if (secs < 10)
		Format(timeLeft, sizeof(timeLeft), "%d:0%d", minutes, secs);
	 else
		Format(timeLeft, sizeof(timeLeft), "%d:%d", minutes, secs);
	
	for (int CountRoundTime = 1; CountRoundTime <= MaxClients; CountRoundTime++)
	{
		if (IsClientInGame(CountRoundTime) && g_bInThirdPersonView[CountRoundTime])
		{
			Client_PrintKeyHintText(CountRoundTime, "%s", timeLeft);
		}
	}

	if (seconds > 0)
		g_hRoundTimeTimer = CreateTimer(0.5, ShowRoundTime, roundTime, TIMER_FLAG_NO_MAPCHANGE);
	
	else
		g_hRoundTimeTimer = INVALID_HANDLE;

	return Plugin_Stop;
}

public Action Timer_AllowWhistle(Handle timer, any data)
{
	g_bWhistlingAllowed = true;
	g_hWhistleDelay = INVALID_HANDLE;

	PrintToChatAll("%s%t", PREFIX, "whistle allowed");

	if (GetConVarBool(g_cvWhistleAuto))
	{
		g_hWhistleAuto = CreateTimer(GetConVarFloat(g_cvWhistleAutoTimer), Timer_AutoWhistle, data, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Stop;
}

public Action Timer_AutoWhistle(Handle time, any user)
{
	g_hWhistleAuto = INVALID_HANDLE;

	float User_Position[3];
	GetClientAbsOrigin(user, User_Position);
	User_Position[2] += 8.0;
	EmitAmbientSound(WhistleSoundPath[GetRandomInt(0, WHISTLE_SOUNDS_MAX-1)], User_Position, SOUND_FROM_WORLD, SNDLEVEL_AIRCRAFT, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
	PrintToChatAll("%s%t", PREFIX, "autowhistle");

	g_hWhistleAuto = CreateTimer(GetConVarFloat(g_cvWhistleAutoTimer), Timer_AutoWhistle, user, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Stop;
}

public Action Timer_SwitchTeams(Handle timer, any data)
{
	char sName[64];
	for (int CountSwitchTeam = 1; CountSwitchTeam <= MaxClients; CountSwitchTeam++)
	{
		if (g_bCTToSwitch[CountSwitchTeam])
		{
			if (IsClientInGame(CountSwitchTeam))
			{
				GetClientName(CountSwitchTeam, sName, sizeof(sName));
				CS_SwitchTeam(CountSwitchTeam, CS_TEAM_T);
				PrintToChatAll("%s%t", PREFIX, "switched", sName);
			}

			g_bCTToSwitch[CountSwitchTeam] = false;
		}
	}

	return Plugin_Stop;
}

public Action Timer_ChangeTeam(Handle timer, any client)
{
	int iCTCount = GetTeamClientCount(CS_TEAM_CT);
	int iTCount = GetTeamClientCount(CS_TEAM_T);
	int iToBeSwitched = 0;
	int iTeam;

	// Check, how many cts are going to get switched to terror at the end of the round
	for (int CountChangeTeam = 1; CountChangeTeam <= MaxClients; CountChangeTeam++)
	{
		// Don't care for cheaters
		if (IsConVarCheater(CountChangeTeam))
		{
			if (IsClientInGame(CountChangeTeam))
			{
				iTeam = GetClientTeam(CountChangeTeam);
				
				if (iTeam == CS_TEAM_CT)
					iCTCount--;
				
				else if (iTeam == CS_TEAM_T)
					iTCount--;
			}
		}

		else if (g_bCTToSwitch[CountChangeTeam])
		{
			iCTCount--;
			iTCount++;
			iToBeSwitched++;
		}
	}

	float fRatio = float(iCTCount) / float(iTCount);
	float fCFGRatio = 1.0 / GetConVarFloat(g_cvCTRatio);
	char sName[64];
	
	// There are more CTs than we want in the CT team and it's not the first CT
	if ((iCTCount > 0 || iTCount > 0) && iCTCount != 1 && fRatio > fCFGRatio)
	{
		// Any players flagged to be moved at the end of the round?
		if (iToBeSwitched > 0)
		{
			for (int CountToBeSwitched = 1 ; CountToBeSwitched <= MaxClients; CountToBeSwitched++)
			{
				if (g_bCTToSwitch[CountToBeSwitched])
				{
					g_bCTToSwitch[CountToBeSwitched] = false;
					iCTCount++;
					iTCount--;
					
					GetClientName(CountToBeSwitched, sName, sizeof(sName));
					PrintToChatAll("%s%t.", PREFIX, "stop switch", sName);

					// switched enough players?
					if (float(iTCount) < GetConVarFloat(g_cvCTRatio) || float(iCTCount) / float(iTCount) <= fCFGRatio)
					{
						return Plugin_Stop;
					}
				}
			}
		}

		// First check, if the last change has been from x->CT
		if (client && IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_CT)
		{
			// Reverse the change or put him in T directly
			iCTCount--;
			iTCount++;
			
			ChangeClientTeam(client, CS_TEAM_T);
			GetClientName(client, sName, sizeof(sName));
			PrintToChatAll("%s%t", PREFIX, "switched", sName);

			// switched enough players?
			if (float(iTCount) < GetConVarFloat(g_cvCTRatio) || float(iCTCount) / float(iTCount) <= fCFGRatio)
			{
				return Plugin_Stop;
			}
		}

		// Switch last joined CT
		else if (g_iLastJoinedCT != -1)
		{
			// Dead? switch directly.
			if (IsClientInGame(g_iLastJoinedCT) && !IsPlayerAlive(g_iLastJoinedCT))
			{
				iCTCount--;
				iTCount++;

				ChangeClientTeam(g_iLastJoinedCT, CS_TEAM_T);
				GetClientName(g_iLastJoinedCT, sName, sizeof(sName));
				PrintToChatAll("%s%t", PREFIX, "switched", sName);
			}

			else if (IsClientInGame(g_iLastJoinedCT))
			{
				iCTCount--;
				iTCount++;
				g_bCTToSwitch[g_iLastJoinedCT] = true;
				
				GetClientName(g_iLastJoinedCT, sName, sizeof(sName));
				PrintToChatAll("%s%t", PREFIX, "going to switch", sName);
			}

			// switched enough players?
			if (float(iTCount) < GetConVarFloat(g_cvCTRatio) || float(iCTCount) / float(iTCount) <= fCFGRatio)
			{
				return Plugin_Stop;
			}
		}

		// First search for a dead seeker, so we can switch him
		// @TODO: Take care for ranking on the scoreboard or longest playtime as CT
		for (int CountToBeSwitched2 = 1; CountToBeSwitched2 <= MaxClients; CountToBeSwitched2++)
		{
			// switched enough players?
			if (float(iTCount) < GetConVarFloat(g_cvCTRatio) || float(iCTCount) / float(iTCount) <= fCFGRatio)
			{
				return Plugin_Stop;
			}

			// Switch one ct to t immediately.
			if (IsClientInGame(CountToBeSwitched2) && !IsPlayerAlive(CountToBeSwitched2) && GetClientTeam(CountToBeSwitched2) == CS_TEAM_CT && !g_bCTToSwitch[CountToBeSwitched2])
			{
				iCTCount--;
				iTCount++;
				
				ChangeClientTeam(CountToBeSwitched2, CS_TEAM_T);
				GetClientName(CountToBeSwitched2, sName, sizeof(sName));
				PrintToChatAll("%s%t", PREFIX, "switched", sName);
			}
		}

		// Still not enough switched? Just pick a random one and switch him at the end of the round
		for (int CountToBeSwitched3 = 1; CountToBeSwitched3 <= MaxClients; CountToBeSwitched3++)
		{
			// switched enough players?
			if (float(iTCount) < GetConVarFloat(g_cvCTRatio) || float(iCTCount) / float(iTCount) <= fCFGRatio)
			{
				return Plugin_Stop;
			}

			if (IsClientInGame(CountToBeSwitched3) && GetClientTeam(CountToBeSwitched3) == CS_TEAM_CT && !g_bCTToSwitch[CountToBeSwitched3])
			{
				iCTCount--;
				iTCount++;
				g_bCTToSwitch[CountToBeSwitched3] = true;

				GetClientName(CountToBeSwitched3, sName, sizeof(sName));
				PrintToChatAll("%s%t", PREFIX, "going to switch", sName);
			}
		}
	}

	// Is the player in CT now?
	// He joined last!
	else if (client && IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_CT)
	{
		g_iLastJoinedCT = client;
	}

	return Plugin_Stop;
}

// Make sure CTs have knifes
public Action Timer_CheckCTHasKnife(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!client)
		return Plugin_Stop;

	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT)
	{
		int iWeapon = GetPlayerWeaponSlot(client, 2);
		
		if (iWeapon == -1)
		{
			iWeapon = GivePlayerItem(client, "weapon_knife");
			EquipPlayerWeapon(client, iWeapon);
		}
	}

	return Plugin_Stop;
}

// Hide the radar again after flashing
public Action Timer_FlashEnd(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (client && GetClientTeam(client) > 1)
	{
		SetEntDataFloat(client, g_flFlashDuration, 10000.0, true);
		SetEntDataFloat(client, g_flFlashMaxAlpha, 0.5, true);
	}

	return Plugin_Stop;
}

public Action Timer_SaveSpawnPosition(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client)
		return Plugin_Stop;

	GetClientAbsOrigin(client, g_fSpawnPosition[client]);
	return Plugin_Stop;
}

/*
*
* Console Command Handling
*
*/

// say /hide /hidemenu
public Action Menu_SelectModel(int client, int args)
{
	char ClientLangId[4];
	GetClientLanguageID(client, ClientLangId, sizeof(ClientLangId));

	if (!g_bEnableHnS || g_hModelMenu[StringToInt(ClientLangId)] == INVALID_HANDLE)
	{
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == CS_TEAM_T)
	{
		int changeLimit = GetConVarInt(g_cvChangeLimit);
		if (g_bAllowModelChange[client] && (changeLimit == 0 || g_iModelChangeCount[client] < (changeLimit+1)))
		{
			if (GetConVarBool(g_cvAutoChoose))
				SetRandomModel(client);
			
			else
				DisplayMenu(g_hModelMenu[StringToInt(ClientLangId)], client, RoundToFloor(GetConVarFloat(g_cvChangeLimittime)));
		}

		else
			PrintToChat(client, "%s%t", PREFIX, "Modelmenu Disabled");
	}

	else
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can select models");
	}

	return Plugin_Handled;
}

// say /tp /third /thirdperson
public Action Toggle_ThirdPerson(int client, int args)
{
	if (!g_bEnableHnS || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	// Only allow Terrorists to use thirdperson view
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
		return Plugin_Handled;
	}

	if (!g_bInThirdPersonView[client])
	{
		SetThirdPersonView(client, true);
		PrintToChat(client, "%s%t", PREFIX, "Type again for ego");
	}

	else
	{
		SetThirdPersonView(client, false);
		// remove the roundtime message
		Client_PrintKeyHintText(client, "");
	}

	return Plugin_Handled;
}

// say /+3rd
public Action Enable_ThirdPerson(int client, int args)
{
	if (!g_bEnableHnS || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	// Only allow Terrorists to use thirdperson view
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
		return Plugin_Handled;
	}

	if (!g_bInThirdPersonView[client])
	{
		SetThirdPersonView(client, true);
		PrintToChat(client, "%s%t", PREFIX, "Type again for ego");
	}

	return Plugin_Handled;
}

// say /-3rd
public Action Disable_ThirdPerson(int client, int args)
{
	if (!g_bEnableHnS || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	// Only allow Terrorists to use thirdperson view
	if( GetClientTeam(client) != CS_TEAM_T)
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
		return Plugin_Handled;
	}

	if (g_bInThirdPersonView[client])
	{
		SetThirdPersonView(client, false);
		// remove the roundtime message
		Client_PrintKeyHintText(client, "");
	}

	return Plugin_Handled;
}

// jointeam command
// handle the team sizes
public Action Command_JoinTeam(int client, int args)
{
	if (!g_bEnableHnS || !client || !IsClientInGame(client) || GetConVarFloat(g_cvCTRatio) == 0.0)
	{
		return Plugin_Continue;
	}

	char text[192];
	if (!GetCmdArgString(text, sizeof(text)))
	{
		return Plugin_Continue;
	}

	StripQuotes(text);

	// Player wants to join CT
	if (strcmp(text, "3", false) == 0)
	{
		int iCTCount = GetTeamClientCount(CS_TEAM_CT);
		int iTCount = GetTeamClientCount(CS_TEAM_T);

		// This client would be in CT if we continue.
		iCTCount++;

		// And would leave T
		if (GetClientTeam(client) == CS_TEAM_T)
			iTCount--;

		// Check, how many terrors are going to get switched to ct at the end of the round
		for (int CountJoinTeam = 1; CountJoinTeam <= MaxClients; CountJoinTeam++)
		{
			if (g_bCTToSwitch[CountJoinTeam])
			{
				iCTCount--;
				iTCount++;
			}
		}

		float fRatio = float(iCTCount) / float(iTCount);
		float fCFGRatio = 1.0 / GetConVarFloat(g_cvCTRatio);

		// There are more CTs than we want in the CT team.
		if (iCTCount > 1 && fRatio > fCFGRatio)
		{
			EmitSoundToClient(client, "buttons/weapon_cant_buy.wav");
			PrintHintText(client, "%t", "CT team is full");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

// say /whistle
// plays a random sound loudly
public Action Play_Whistle(int client, int args)
{
	// check if whistling is enabled
	if (!g_bEnableHnS || !GetConVarBool(g_cvWhistle) || !IsPlayerAlive(client))
		return Plugin_Handled;

	// only Ts are allowed to whistle
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
		return Plugin_Handled;
	}

	if (!g_bWhistlingAllowed)
	{
		PrintToChat(client, "%s%t", PREFIX, "Whistling not allowed yet");
		return Plugin_Handled;
	}

	if (g_iWhistleCount[client] < GetConVarInt(g_cvWhistleTimes))
	{
		float Client_Position[3];
		GetClientAbsOrigin(client, Client_Position);
		Client_Position[2] += 8.0;
		EmitAmbientSound(WhistleSoundPath[GetRandomInt(0, WHISTLE_SOUNDS_MAX-1)], Client_Position, SOUND_FROM_WORLD, SNDLEVEL_AIRCRAFT, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		PrintToChatAll("%s%N %t", PREFIX, client, "whistled");
		g_iWhistleCount[client]++;
		PrintToChat(client, "%s%t", PREFIX, "whistles left", (GetConVarInt(g_cvWhistleTimes)-g_iWhistleCount[client]));
	}

	else
	{
		PrintToChat(client, "%s%t", PREFIX, "whistle limit exceeded", GetConVarInt(g_cvWhistleTimes));
	}

	return Plugin_Handled;
}

// say /whoami
// displays the model name in chat again
public Action Display_ModelName(int client, int args)
{
	// only enable command, if player already chose a model
	if (!g_bEnableHnS || !IsPlayerAlive(client) || g_iModelChangeCount[client] == 0)
		return Plugin_Handled;

	// only Ts can use a model
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		PrintToChat(client, "%s%t", PREFIX, "Only terrorists can use");
		return Plugin_Handled;
	}

	char modelName[128]; 
	char langCode[4];
	GetClientModel(client, modelName, sizeof(modelName));

	if (!KvGotoFirstSubKey(kv))
	{
		return Plugin_Handled;
	}

	char name[30];
	char path[100];
	char fullPath[100];

	do
	{
		KvGetSectionName(kv, path, sizeof(path));
		FormatEx(fullPath, sizeof(fullPath), "models/%s.mdl", path);
		if (StrEqual(fullPath, modelName))
		{
			GetClientLanguageID(client, langCode, sizeof(langCode));
			KvGetString(kv, langCode, name, sizeof(name));
			PrintToChat(client, "%s%t\x01 %s.", PREFIX, "Model Changed", name);
		}

	}

	while (KvGotoNextKey(kv));
	KvRewind(kv);

	return Plugin_Handled;
}


// say /hidehelp
// Show the help menu
public Action Display_Help(int client, int args)
{
	if (!g_bEnableHnS)
		return Plugin_Handled;

	Handle menu = CreateMenu(Menu_Help);

	char buffer[512];
	Format(buffer, sizeof(buffer), "%T", "HnS Help", client);
	SetMenuTitle(menu, buffer);
	SetMenuExitButton(menu, true);

	Format(buffer, sizeof(buffer), "%T", "Running HnS", client);
	AddMenuItem(menu, "", buffer);

	Format(buffer, sizeof(buffer), "%T", "Instructions 1", client);
	AddMenuItem(menu, "", buffer);

	AddMenuItem(menu, "", "", ITEMDRAW_SPACER);

	Format(buffer, sizeof(buffer), "%T", "Available Commands", client);
	AddMenuItem(menu, "1", buffer);

	Format(buffer, sizeof(buffer), "%T", "Howto CT", client);
	AddMenuItem(menu, "2", buffer);

	Format(buffer, sizeof(buffer), "%T", "Howto T", client);
	AddMenuItem(menu, "3", buffer);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

// say /freeze
// Freeze hiders in position
public Action Freeze_Cmd(int client, int args)
{
	if (!g_bEnableHnS || !GetConVarInt(g_cvHiderFreezeMode) || GetClientTeam(client) != CS_TEAM_T || !IsPlayerAlive(client))
		return Plugin_Handled;

	if (g_bIsFreezed[client])
	{
		if (GetConVarInt(g_cvHiderFreezeMode) == 1)
		{
			if (!g_bClientIsHigher[client])
				SetEntityMoveType(client, MOVETYPE_WALK);
		}

		else
		{
			SetEntData(client, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
			
			if (!g_bClientIsHigher[client])
				SetEntityMoveType(client, MOVETYPE_WALK);
		}

		g_bIsFreezed[client] = false;
		PrintToChat(client, "%s%t", PREFIX, "Hider Unfreezed");
	}

	else if (GetConVarBool(g_cvHiderFreezeInAir) || (GetEntityFlags(client) & FL_ONGROUND || g_bClientIsHigher[client])) // only allow freezing when being on the ground!
	{
		// Don't allow fixed models to freeze while being bugged
		// Put him up before freezing
		if (g_iFixedModelHeight[client] > 0.0 && !g_bClientIsHigher[client] && GetEntityFlags(client) & FL_ONGROUND)
		{
			float vecClientOrigin[3];
			GetClientAbsOrigin(client, vecClientOrigin);
			vecClientOrigin[2] += g_iFixedModelHeight[client];
			TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
			g_bClientIsHigher[client] = true;
		}

		if( GetConVarInt(g_cvHiderFreezeMode) == 1)
			SetEntityMoveType(client, MOVETYPE_NONE); // Still able to move camera
		
		else
		{
			SetEntData(client, g_Freeze, FL_CLIENT|FL_ATCONTROLS, 4, true); // Can't move anything
			SetEntityMoveType(client, MOVETYPE_NONE);
		}

		// Stop him
		float NullVelocity[3] = {0.0,0.0,0.0};
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NullVelocity);

		g_bIsFreezed[client] = true;
		PrintToChat(client, "%s%t", PREFIX, "Hider Freezed");
	}

	return Plugin_Handled;
}

public Action Block_Cmd(int client,int args)
{
	// only block if anticheat is enabled
	if (g_bEnableHnS && GetConVarBool(g_cvAntiCheat))
		return Plugin_Handled;

	else
		return Plugin_Continue;
}

// Admin Command
// sm_hns_force_whistle
// Forces a terrorist player to whistle
public Action ForceWhistle(int client, int args)
{
	if (!g_bEnableHnS || !GetConVarBool(g_cvWhistle))
	{
		ReplyToCommand(client, "Disabled.");
		return Plugin_Handled;
	}

	if (GetCmdArgs() < 1)
	{
		ReplyToCommand(client, "Usage: sm_hns_force_whistle <#userid|steamid|name>");
		return Plugin_Handled;
	}

	char player[70];
	GetCmdArg(1, player, sizeof(player));

	int target = FindTarget(client, player);
	if (target == -1)
		return Plugin_Handled;

	if (GetClientTeam(target) == CS_TEAM_T && IsPlayerAlive(target))
	{
		float Target_Position[3];
		GetClientEyePosition(target, Target_Position);
		Target_Position[2] += 8.0;
		EmitAmbientSound(WhistleSoundPath[GetRandomInt(0, WHISTLE_SOUNDS_MAX-1)], Target_Position, SOUND_FROM_WORLD, SNDLEVEL_AIRCRAFT, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, 0.0);
		PrintToChatAll("%s%N %t", PREFIX, target, "whistled");
	}

	else
	{
		ReplyToCommand(client, "Hide and Seek: %t", "Only terrorists can use");
	}

	return Plugin_Handled;
}

public Action ReloadModels(int client, int args)
{
	if (!g_bEnableHnS)
	{
		ReplyToCommand(client, "Disabled.");
		return Plugin_Handled;
	}

	// reset the model menu
	OnMapEnd();

	// rebuild it
	BuildMainMenu();

	ReplyToCommand(client, "Hide and Seek: Reloaded config.");

	return Plugin_Handled;
}

public Action PrintHnsVersion(int client, int args)
{
	if (!g_bEnableHnS)
	{
		ReplyToCommand(client, "Disabled");
		return Plugin_Handled;
	}

	char CvarPluginVersion[PLATFORM_MAX_PATH];
	GetConVarString(g_cvVersion, CvarPluginVersion, PLATFORM_MAX_PATH);
	PrintToChatAll("\x04[HnS] \x03Hide and Seek version %s", CvarPluginVersion);
	PrintToServer("[HnS] Hide and Seek version %s", CvarPluginVersion);
	return Plugin_Handled;
}


/*
*
* Menu Handler
*
*/
public Menu_Group(Handle menu, MenuAction action, int client, int param2)
{
	// make sure again, the player is a Terrorist
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_T && g_bAllowModelChange[client])
	{
		if (action == MenuAction_Select)
		{
			char info[100];
			char info2[100];
			char sModelPath[100];
			bool found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
			if (found)
			{

				if (StrEqual(info, "random"))
				{
					SetRandomModel(client);
				}

				else
				{
					// Check for enough money
					char sTax[32];
					int iPosition;
					if ((iPosition = StrContains(info, "||t_")) != -1)
					{
						int iAccountValue = GetEntData(client, g_iAccount);

						// Stupid char information storage-.-
						int iPosition2 = StrContains(info[iPosition+4], "||hi_");
						if (iPosition2 != -1)
							strcopy(sTax, iPosition2-iPosition+3, info[iPosition+4]);
						
						else
							strcopy(sTax, sizeof(sTax), info[iPosition+4]);

						int iTax = StringToInt(sTax);
						
						// He doesn't have enough money?
						if (iTax > iAccountValue)
						{
							PrintToChat(client, "%s%t", PREFIX, "not enough money");
							// Show the menu again
							Menu_SelectModel(client, 0);
							return;
						}

						// Get the money
						SetEntData(client, g_iAccount, (iAccountValue - iTax), 4, true);

						PrintToChat(client, "%s%t", PREFIX, "tax charged", iTax);
					}

					// Put him down before changing the model again
					if (g_bClientIsHigher[client])
					{
						float vecClientOrigin[3];
						GetClientAbsOrigin(client, vecClientOrigin);
						vecClientOrigin[2] -= g_iFixedModelHeight[client];
						TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
						SetEntityMoveType(client, MOVETYPE_WALK);
						g_bClientIsHigher[client] = false;
					}

					// Modelheight fix
					if ((iPosition = StrContains(info, "||hi_")) != -1)
					{
						g_iFixedModelHeight[client] = StringToFloat(info[iPosition+5]);
						PrintToChat(client, "%s%t", PREFIX, "is heightfixed");
					}

					else
					{
						g_iFixedModelHeight[client] = 0.0;
					}

					if (SplitString(info, "||", sModelPath, sizeof(sModelPath)) == -1)
						strcopy(sModelPath, sizeof(sModelPath), info);

					SetEntityModel(client, sModelPath);
					PrintToChat(client, "%s%t \x01%s.", PREFIX, "Model Changed", info2);
				}

				g_iModelChangeCount[client]++;
			}
		}

		else if (action == MenuAction_Cancel)
		{
			PrintToChat(client, "%s%t", PREFIX, "Type !hide");
		}

		// display the help menu afterwards on first spawn
		if (GetConVarBool(g_cvShowHideHelp) && g_bFirstSpawn[client])
		{
			Display_Help(client, 0);
			g_bFirstSpawn[client] = false;
		}
	}
}

// Display the different help menus
public Menu_Help(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		int iInfo = StringToInt(info);
		switch (iInfo)
		{
			case 1:
			{
				// Available Commands
				Handle menu2 = CreateMenu(Menu_Dummy);
				char buffer[512];
				Format(buffer, sizeof(buffer), "%T", "Available Commands", param1);
				SetMenuTitle(menu2, buffer);
				SetMenuExitBackButton(menu2, true);

				Format(buffer, sizeof(buffer), "/hide, /hidemenu - %T", "cmd hide", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);
				Format(buffer, sizeof(buffer), "/tp, /third, /thirdperson - %T", "cmd tp", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);
				
				if (GetConVarBool(g_cvWhistle))
				{
					Format(buffer, sizeof(buffer), "/whistle - %T", "cmd whistle", param1);
					AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);
				}
				
				if (GetConVarInt(g_cvHiderFreezeMode))
				{
					Format(buffer, sizeof(buffer), "/freeze - %T", "cmd freeze", param1);
					AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);
				}

				Format(buffer, sizeof(buffer), "/whoami - %T", "cmd whoami", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);
				Format(buffer, sizeof(buffer), "/hidehelp - %T", "cmd hidehelp", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				DisplayMenu(menu2, param1, MENU_TIME_FOREVER);
			}

			case 2:
			{
				// Howto CT
				Handle menu2 = CreateMenu(Menu_Dummy);
				char buffer[512];
				Format(buffer, sizeof(buffer), "%T", "Howto CT", param1);
				SetMenuTitle(menu2, buffer);
				SetMenuExitBackButton(menu2, true);

				Format(buffer, sizeof(buffer), "%T", "Instructions CT 1", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				AddMenuItem(menu2, "", "", ITEMDRAW_SPACER);

				Format(buffer, sizeof(buffer), "%T", "Instructions CT 2", param1, GetConVarInt(g_cvHPSeekerDec));
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				Format(buffer, sizeof(buffer), "%T", "Instructions CT 3", param1, GetConVarInt(g_cvHPSeekerInc), GetConVarInt(g_cvHPSeekerBonus));
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				DisplayMenu(menu2, param1, MENU_TIME_FOREVER);
			}

			case 3:
			{
				// Howto T
				Handle menu2 = CreateMenu(Menu_Dummy);
				char buffer[512];
				Format(buffer, sizeof(buffer), "%T", "Howto T", param1);
				SetMenuTitle(menu2, buffer);
				SetMenuExitBackButton(menu2, true);

				Format(buffer, sizeof(buffer), "%T", "Instructions T 1", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				Format(buffer, sizeof(buffer), "%T", "Instructions T 2", param1);
				AddMenuItem(menu2, "", buffer, ITEMDRAW_DISABLED);

				DisplayMenu(menu2, param1, MENU_TIME_FOREVER);
			}
		}
	}

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_Dummy(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel && param2 != MenuCancel_Exit)
	{
		if (IsClientInGame(param1))
			Display_Help(param1, 0);
	}

	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/*
*
* Helper Functions
*
*/

// read the hide_and_seek map config
// add all models to the menus according to the language
public BuildMainMenu()
{
	g_iTotalModelsAvailable = 0;

	kv = CreateKeyValues("Models");
	char file[256];
	char map[64];
	char title[64];
	char finalOutput[100];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, file, 255, "configs/hide_and_seek/maps/%s.cfg", map);
	FileToKeyValues(kv, file);

	if (!KvGotoFirstSubKey(kv))
	{
		SetFailState("Can't parse modelconfig file for map %s.", map);
		return;
	}

	char name[30];
	char lang[4];
	char path[100];
	int langID, nextLangID = -1;
	
	do
	{
		// get the model path and precache it
		KvGetSectionName(kv, path, sizeof(path));
		FormatEx(finalOutput, sizeof(finalOutput), "models/%s.mdl", path);
		PrecacheModel(finalOutput, true);

		// Check for heightfixed models
		char sHeightFix[32];
		KvGetString(kv, "heightfix", sHeightFix, sizeof(sHeightFix), "noo");
		if (!StrEqual(sHeightFix, "noo"))
		{
			Format(finalOutput, sizeof(finalOutput), "%s||hi_%s", finalOutput, sHeightFix);
		}

		// Check for tax
		char sTax[32];
		KvGetString(kv, "tax", sTax, sizeof(sTax), "noo");
		if (!StrEqual(sTax, "noo"))
		{
			Format(finalOutput, sizeof(finalOutput), "%s||t_%s", finalOutput, sTax);
		}

		// roll through all available languages
		for (int CountLangMenu = 0; CountLangMenu < GetLanguageCount(); CountLangMenu++)
		{
			GetLanguageInfo(CountLangMenu, lang, sizeof(lang));
			// search for the translation
			KvGetString(kv, lang, name, sizeof(name));
			if (strlen(name) > 0)
			{
				// Show the tax
				if (!StrEqual(sTax, "noo"))
					Format(name, sizeof(name), "%s ($%d)", name, StringToInt(sTax));

				// language already in array, only in the wrong order in the file?
				langID = GetLanguageID(lang);

				// language new?
				if (langID == -1)
				{
					nextLangID = GetNextLangID();
					g_sModelMenuLanguage[nextLangID] = lang;
				}

				if (langID == -1 && g_hModelMenu[nextLangID] == INVALID_HANDLE)
				{
					// new language, create the menu
					g_hModelMenu[nextLangID] = CreateMenu(Menu_Group);
					Format(title, sizeof(title), "%T:", "Title Select Model", LANG_SERVER);

					SetMenuTitle(g_hModelMenu[nextLangID], title);
					SetMenuExitButton(g_hModelMenu[nextLangID], true);

					// Add random option
					Format(title, sizeof(title), "%T", "random", LANG_SERVER);
					AddMenuItem(g_hModelMenu[nextLangID], "random", title);
				}

				// add it to the menu
				if (langID == -1)
					AddMenuItem(g_hModelMenu[nextLangID], finalOutput, name);
				
				else
					AddMenuItem(g_hModelMenu[langID], finalOutput, name);
			}

		}

		g_iTotalModelsAvailable++;
	} 

	while (KvGotoNextKey(kv));
	KvRewind(kv);

	if (g_iTotalModelsAvailable == 0)
	{
		SetFailState("No models parsed in %s.cfg", map);
		return;
	}
}

public int GetLanguageID(const char[] langCode)
{
	for (int CountLangId = 0; CountLangId <MAX_LANGUAGES; CountLangId++)
	{
		if (StrEqual(g_sModelMenuLanguage[CountLangId], langCode))
			return CountLangId;
	}

	return -1;
}

public GetClientLanguageID(int client, char[] languageCode, int maxlen)
{
	char langCode[4];
	GetLanguageInfo(GetClientLanguage(client), langCode, sizeof(langCode));
	int langID = GetLanguageID(langCode);

	// is client's prefered language available?
	if (langID != -1)
	{
		strcopy(languageCode, maxlen, langCode);
		return langID; // yes.
	}

	else
	{
		GetLanguageInfo(GetServerLanguage(), langCode, sizeof(langCode));
		// is default server language available?
		langID = GetLanguageID(langCode);
		if (langID != -1)
		{
			strcopy(languageCode, maxlen, langCode);
			return langID; // yes.
		}

		else
		{
			// default to english
			for (int CountLangDefault = 0; CountLangDefault < MAX_LANGUAGES; CountLangDefault++)
			{
				if (StrEqual(g_sModelMenuLanguage[CountLangDefault], "en"))
				{
					strcopy(languageCode, maxlen, "en");
					return CountLangDefault;
				}
			}

			// english not found? happens on custom map configs e.g.
			// use the first language available
			// this should always work, since we would have SetFailState() on parse
			if (strlen(g_sModelMenuLanguage[0]) > 0)
			{
				strcopy(languageCode, maxlen, g_sModelMenuLanguage[0]);
				return 0;
			}
		}
	}

	// this should never happen
	return -1;
}

public GetNextLangID()
{
	for (int CountLangIdNext = 0; CountLangIdNext < MAX_LANGUAGES; CountLangIdNext++)
	{
		if (strlen(g_sModelMenuLanguage[CountLangIdNext]) == 0)
			return CountLangIdNext;
	}

	SetFailState("Can't handle more than %d languages. Increase MAX_LANGUAGES and recompile.", MAX_LANGUAGES);
	return -1;
}

// Check if a player has a bad convar value set
bool IsConVarCheater(int client)
{
	for (int CountIsCheater = 0; CountIsCheater < sizeof(cheat_commands); CountIsCheater++)
	{
		if (g_bConVarViolation[client][CountIsCheater])
		{
			return true;
		}
	}

	return false;
}

bool IsPlayerAFK(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	// Did he move after spawn?
	if(UTIL_VectorEqual(fOrigin, g_fSpawnPosition[client], 0.1))
		return true;

	return false;
}

stock bool UTIL_VectorEqual(const float vec1[3], const float vec2[3], const float tolerance)
{
	for (int CountVector = 0; CountVector < 3; CountVector++)
		if (vec1[CountVector] > (vec2[CountVector] + tolerance) || vec1[CountVector] < (vec2[CountVector] - tolerance))
			return false;
	
	return true;
}

// Fade a players screen to black (amount=0) or removes the fade (amount=255)
public PerformBlind(int client, int amount)
{
	int mode;
	if(amount == 0)
		mode = FFADE_PURGE;
	else
		mode = FFADE_STAYOUT;
	Client_ScreenFade(client, 1536, mode, 1536, 0, 0, 0, amount);
}

// set a random model to a client
public SetRandomModel(int client)
{
	// give him a random one.
	char ModelPath[80];
	char finalPath[100];
	char ModelName[60];
	char langCode[4];
	char sHeightFix[35];
	char sTax[32];
	int RandomNumber = GetRandomInt(0, g_iTotalModelsAvailable-1);
	int currentI = 0;
	int iTax;
	int iAccountValue = GetEntData(client, g_iAccount);
	bool bUseTaxedInRandom = GetConVarBool(g_cvUseTaxedInRandom);
	
	KvGotoFirstSubKey(kv);
	
	do
	{
		if (currentI == RandomNumber)
		{
			// Check for enough money
			KvGetString(kv, "tax", sTax, sizeof(sTax), "noo");
			if (!StrEqual(sTax, "noo"))
			{
				iTax = StringToInt(sTax);
				// He doesn't have enough money? skip this one
				if (!bUseTaxedInRandom || iTax > iAccountValue)
					continue;

				// Get the money
				SetEntData(client, g_iAccount, iAccountValue - iTax, 4, true);

				PrintToChat(client, "%s%t", PREFIX, "tax charged", iTax);
			}

			// set the model
			KvGetSectionName(kv, ModelPath, sizeof(ModelPath));

			FormatEx(finalPath, sizeof(finalPath), "models/%s.mdl", ModelPath);

			// Put him down before changing the model again
			if (g_bClientIsHigher[client])
			{
				float vecClientOrigin[3];
				GetClientAbsOrigin(client, vecClientOrigin);
				vecClientOrigin[2] -= g_iFixedModelHeight[client];
				TeleportEntity(client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
				SetEntityMoveType(client, MOVETYPE_WALK);
				g_bClientIsHigher[client] = false;
			}

			SetEntityModel(client, finalPath);

			// Check for heightfixed models
			KvGetString(kv, "heightfix", sHeightFix, sizeof(sHeightFix), "noo");
			
			if (!StrEqual(sHeightFix, "noo"))
			{
				g_iFixedModelHeight[client] = StringToFloat(sHeightFix);
				PrintToChat(client, "%s%t", PREFIX, "is heightfixed");
			}
			
			else
			{
				g_iFixedModelHeight[client] = 0.0;
			}

			if (!IsFakeClient(client))
			{
				// print name in chat
				GetClientLanguageID(client, langCode, sizeof(langCode));
				KvGetString(kv, langCode, ModelName, sizeof(ModelName));
				PrintToChat(client, "%s%t \x01%s.", PREFIX, "Model Changed", ModelName);
			}

			break;
		}

		currentI++;
	}

	while (KvGotoNextKey(kv));
	KvRewind(kv);
	g_iModelChangeCount[client]++;

	// display the help menu afterwards on first spawn
	if (GetConVarBool(g_cvShowHideHelp) && g_bFirstSpawn[client])
	{
		Display_Help(client, 0);
		g_bFirstSpawn[client] = false;
	}
}

bool SetThirdPersonView(int client, bool third)
{
	if (third && !g_bInThirdPersonView[client])
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client, Prop_Send, "m_iFOV", 120);
		g_bInThirdPersonView[client] = true;
		return true;
	}

	else if (!third && g_bInThirdPersonView[client])
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		g_bInThirdPersonView[client] = false;
		return true;
	}

	return false;
}

stock StripPlayerWeapons(int client)
{
	int iWeapon = -1;
	for (int CountWeaponSlot = CS_SLOT_PRIMARY; CountWeaponSlot <= CS_SLOT_C4; CountWeaponSlot++)
	{
		while ((iWeapon = GetPlayerWeaponSlot(client, CountWeaponSlot)) != -1)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEdict(iWeapon);
		}
	}
}

/*
*
* Handle ConVars
*
*/
// Monitor the protected cvars and... well protect them ;)
public OnCvarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnableHnS)
		return;

	char cvarName[50];
	GetConVarName(convar, cvarName, sizeof(cvarName));
	
	for (int CountCvarChange = 0; CountCvarChange < sizeof(protected_cvars); CountCvarChange++)
	{
		if (StrEqual(protected_cvars[CountCvarChange], cvarName) && StringToInt(newValue) != forced_values[CountCvarChange])
		{
			SetConVarInt(convar, forced_values[CountCvarChange]);
			PrintToServer("Hide and Seek: %T", "protected cvar", LANG_SERVER);
			break;
		}
	}
}

// directly change the hider speed on change
public OnChangeHiderSpeed(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnableHnS)
		return;

	for (int CountClientSpeed = 1; CountClientSpeed <= MaxClients; CountClientSpeed++)
	{
		if (IsClientInGame(CountClientSpeed) && IsPlayerAlive(CountClientSpeed) && GetClientTeam(CountClientSpeed) == CS_TEAM_T)
			SetEntDataFloat(CountClientSpeed, g_flLaggedMovementValue, GetConVarFloat(g_cvHiderSpeed), true);
	}
}

// directly change the hider speed on change
public OnChangeAntiCheat(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnableHnS)
		return;

	if (StrEqual(oldValue, newValue))
		return;

	// disable anticheat
	if (StrEqual(newValue, "0"))
	{
		for (int CountAntiCheat = 1; CountAntiCheat <= MaxClients; CountAntiCheat++)
		{
			if (IsClientInGame(CountAntiCheat) && !IsFakeClient(CountAntiCheat))
			{
				if (g_hCheckVarTimer[CountAntiCheat] != INVALID_HANDLE)
				{
					KillTimer(g_hCheckVarTimer[CountAntiCheat]);
					g_hCheckVarTimer[CountAntiCheat] = INVALID_HANDLE;
				}
				if (g_hCheatPunishTimer[CountAntiCheat] != INVALID_HANDLE)
				{
					KillTimer(g_hCheatPunishTimer[CountAntiCheat]);
					g_hCheatPunishTimer[CountAntiCheat] = INVALID_HANDLE;
				}
			}
		}
	}

	// enable anticheat
	else if (StrEqual(newValue, "1"))
	{
		for (int CountAntiCheat2 = 1; CountAntiCheat2 <= MaxClients; CountAntiCheat2++)
		{
			if (IsClientInGame(CountAntiCheat2) && !IsFakeClient(CountAntiCheat2) && g_hCheckVarTimer[CountAntiCheat2] == INVALID_HANDLE)
			{
				g_hCheckVarTimer[CountAntiCheat2] = CreateTimer(1.0, StartVarChecker, CountAntiCheat2, TIMER_REPEAT);
			}
		}
	}
}

// disable/enable plugin and restart round
public RestartGame(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bEnableHnS)
		return;

	// don't execute if it's unchanged
	if (StrEqual(oldValue, newValue))
		return;

	// disable - it's been enabled before.
	if (!StrEqual(newValue, "0"))
	{
		// round has ended. used to not decrease seekers hp on shoot
		g_bRoundEnded = true;

		g_iFirstCTSpawn = 0;
		g_iFirstTSpawn = 0;

		if (g_hShowCountdownTimer != INVALID_HANDLE)
		{
			KillTimer(g_hShowCountdownTimer);
			g_hShowCountdownTimer = INVALID_HANDLE;
		}

		if (g_hRoundTimeTimer != INVALID_HANDLE)
		{
			KillTimer(g_hRoundTimeTimer);
			g_hRoundTimeTimer = INVALID_HANDLE;
		}

		if (g_hWhistleDelay != INVALID_HANDLE)
		{
			KillTimer(g_hWhistleDelay);
			g_hWhistleDelay = INVALID_HANDLE;
		}

		if (g_hWhistleAuto != INVALID_HANDLE)
		{
			KillTimer(g_hWhistleAuto);
			g_hWhistleAuto = INVALID_HANDLE;
		}

		// Switch the flagged players to CT
		CreateTimer(0.1, Timer_SwitchTeams, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

// disable/enable plugin and restart round
public Cfg_OnChangeEnable(Handle convar, const char[] oldValue, const char[] newValue)
{
	// don't execute if it's unchanged
	if (StrEqual(oldValue, newValue))
		return;

	// disable - it's been enabled before.
	if (StrEqual(newValue, "0"))
	{
		UnhookConVarChange(g_cvAntiCheat, OnChangeAntiCheat);
		UnhookConVarChange(g_cvHiderSpeed, OnChangeHiderSpeed);

		// Unhooking events
		UnhookEvent("player_spawn", Event_OnPlayerSpawn);
		UnhookEvent("weapon_fire", Event_OnWeaponFire);
		UnhookEvent("player_death", Event_OnPlayerDeath);
		UnhookEvent("player_blind", Event_OnPlayerBlind);
		UnhookEvent("round_start", Event_OnRoundStart);
		UnhookEvent("round_end", Event_OnRoundEnd);
		UnhookEvent("player_team", Event_OnPlayerTeam);
		UnhookEvent("item_pickup", Event_OnItemPickup);

		// unprotect the cvars
		for (int CountCvarUnprotect = 0; CountCvarUnprotect < sizeof(protected_cvars); CountCvarUnprotect++)
		{
			// reset old cvar values
			if (g_hProtectedConvar[CountCvarUnprotect] == INVALID_HANDLE)
				continue;
			UnhookConVarChange(g_hProtectedConvar[CountCvarUnprotect], OnCvarChange);
			SetConVarInt(g_hProtectedConvar[CountCvarUnprotect], previous_values[CountCvarUnprotect], true);
		}

		// stop advertising spam
		if (g_hSpamCommandsTimer != INVALID_HANDLE)
		{
			KillTimer(g_hSpamCommandsTimer);
			g_hSpamCommandsTimer = INVALID_HANDLE;
		}

		// stop countdown
		if (g_hShowCountdownTimer != INVALID_HANDLE)
		{
			KillTimer(g_hShowCountdownTimer);
			g_hShowCountdownTimer = INVALID_HANDLE;
		}

		// stop roundtime counter
		if (g_hRoundTimeTimer != INVALID_HANDLE)
		{
			KillTimer(g_hRoundTimeTimer);
			g_hRoundTimeTimer = INVALID_HANDLE;
		}

		// close handles
		if (kv != INVALID_HANDLE)
			CloseHandle(kv);
		
		for (int CountLangChEn = 0; CountLangChEn < MAX_LANGUAGES; CountLangChEn++)
		{
			if (g_hModelMenu[CountLangChEn] != INVALID_HANDLE)
			{
				CloseHandle(g_hModelMenu[CountLangChEn]);
				g_hModelMenu[CountLangChEn] = INVALID_HANDLE;
			}

			Format(g_sModelMenuLanguage[CountLangChEn], 4, "");
		}

		for (int CountClientChEn = 1; CountClientChEn <= MaxClients; CountClientChEn++)
		{
			if (!IsClientInGame(CountClientChEn))
				continue;

			// stop cheat checking
			if (!IsFakeClient(CountClientChEn))
			{
				if (g_hCheckVarTimer[CountClientChEn] != INVALID_HANDLE)
				{
					KillTimer(g_hCheckVarTimer[CountClientChEn]);
					g_hCheckVarTimer[CountClientChEn] = INVALID_HANDLE;
				}
				
				if (g_hCheatPunishTimer[CountClientChEn] != INVALID_HANDLE)
				{
					KillTimer(g_hCheatPunishTimer[CountClientChEn]);
					g_hCheatPunishTimer[CountClientChEn] = INVALID_HANDLE;
				}
			}

			// Unhook weapon pickup
			SDKUnhook(CountClientChEn, SDKHook_WeaponCanUse, OnWeaponCanUse);

			// Unhook attacking
			SDKUnhook(CountClientChEn, SDKHook_TraceAttack, OnTraceAttack);

			// reset every players vars
			OnClientDisconnect(CountClientChEn);
		}

		g_bEnableHnS = false;
		// restart game to reset the models and scores
		ServerCommand("mp_restartgame 1");
	}

	else if (StrEqual(newValue, "1"))
	{
		// hook the convars again
		HookConVarChange(g_cvHiderSpeed, OnChangeHiderSpeed);
		HookConVarChange(g_cvAntiCheat, OnChangeAntiCheat);

		// Hook events again
		HookEvent("player_spawn", Event_OnPlayerSpawn);
		HookEvent("weapon_fire", Event_OnWeaponFire);
		HookEvent("player_death", Event_OnPlayerDeath);
		HookEvent("player_blind", Event_OnPlayerBlind);
		HookEvent("round_start", Event_OnRoundStart);
		HookEvent("round_end", Event_OnRoundEnd);
		HookEvent("player_team", Event_OnPlayerTeam);
		HookEvent("item_pickup", Event_OnItemPickup);

		// set bad server cvars
		for (int CountBadCvar = 0; CountBadCvar < sizeof(protected_cvars); CountBadCvar++)
		{
			g_hProtectedConvar[CountBadCvar] = FindConVar(protected_cvars[CountBadCvar]);
			
			if (g_hProtectedConvar[CountBadCvar] == INVALID_HANDLE)
				continue;
			
			previous_values[CountBadCvar] = GetConVarInt(g_hProtectedConvar[CountBadCvar]);
			SetConVarInt(g_hProtectedConvar[CountBadCvar], forced_values[CountBadCvar], true);
			HookConVarChange(g_hProtectedConvar[CountBadCvar], OnCvarChange);
		}

		// start advertising spam
		g_hSpamCommandsTimer = CreateTimer(120.0, SpamCommands, 0);

		for (int CountAdvSpam = 1 ; CountAdvSpam <= MaxClients; CountAdvSpam++)
		{
			if (!IsClientInGame(CountAdvSpam))
				continue;

			// start cheat checking
			if (!IsFakeClient(CountAdvSpam) && GetConVarBool(g_cvAntiCheat) && g_hCheckVarTimer[CountAdvSpam] == INVALID_HANDLE)
			{
				g_hCheckVarTimer[CountAdvSpam] = CreateTimer(1.0, StartVarChecker, CountAdvSpam, TIMER_REPEAT);
			}

			// Hook weapon pickup
			SDKHook(CountAdvSpam, SDKHook_WeaponCanUse, OnWeaponCanUse);

			// Hook attack to hide blood
			SDKHook(CountAdvSpam, SDKHook_TraceAttack, OnTraceAttack);
		}

		g_bEnableHnS = true;
		// build the menu and setup the hostage_rescue zone
		OnMapStart();

		// restart game to reset the models and scores
		ServerCommand("mp_restartgame 1");
	}
}

// check the given cheat cvars on every client
public ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (!IsClientInGame(client))
		return;

	bool match = StrEqual(cvarValue, "0");

	for (int CountClientCvar = 0; CountClientCvar < sizeof(cheat_commands); CountClientCvar++)
	{
		if (!StrEqual(cheat_commands[CountClientCvar], cvarName))
			continue;

		if (!match)
		{
			g_bConVarViolation[client][CountClientCvar] = true;
			
			// only spam the message every 5 checks
			if (g_iConVarMessage[client][CountClientCvar] == 0)
			{
				PrintToChat(client, "%s%t\x04 %s 0", PREFIX, "Print to console", cvarName);
				PrintHintText(client, "%t %s 0", "Print to console", cvarName);
			}

			g_iConVarMessage[client][CountClientCvar]++;

			if (g_iConVarMessage[client][CountClientCvar] > 5)
				g_iConVarMessage[client][CountClientCvar] = 0;
		}

		else
			g_bConVarViolation[client][CountClientCvar] = false;
	}
}



public LoadWhistleSet()
{

	if (GetConVarInt(g_cvWhistleSet) == 0)
		LoadWhistleSound("Default");

	else if (GetConVarInt(g_cvWhistleSet) == 1)
		LoadWhistleSound("Whistle");

	else if (GetConVarInt(g_cvWhistleSet) == 2)
		LoadWhistleSound("Birds");

	else if (GetConVarInt(g_cvWhistleSet) == 3)
		LoadWhistleSound("Custom");

	else
		SetFailState("CVAR sm_hns_whistle_set not correctly setup.");
}

public LoadWhistleSound(const char cvarWhistleSet[PLATFORM_MAX_PATH])
{
	char WhistleSoundSet[WHISTLE_SOUNDS_MAX][PLATFORM_MAX_PATH];
	char bufferString[PLATFORM_MAX_PATH];
	Handle SoundSetsKV = CreateKeyValues("SetsList");
	BuildPath(Path_SM,bufferString, PLATFORM_MAX_PATH, "configs/hide_and_seek/whistle/HnS_SetsList.cfg");

	if (FileToKeyValues(SoundSetsKV, bufferString))
	{
		// Default Engine Sounds
		if (StrEqual(cvarWhistleSet, "Default"))
		{
			if (KvJumpToKey(SoundSetsKV, cvarWhistleSet))
			{
				for (int CountWhistleSound = 0; CountWhistleSound < WHISTLE_SOUNDS_MAX; CountWhistleSound++)
				{
					IntToString(CountWhistleSound, bufferString, PLATFORM_MAX_PATH);
					KvGetString(SoundSetsKV, bufferString, WhistleSoundSet[CountWhistleSound], PLATFORM_MAX_PATH);
					WhistleSoundPath[CountWhistleSound] = WhistleSoundSet[CountWhistleSound];
					PrecacheSound(WhistleSoundPath[CountWhistleSound], true);
				}
			}

			else
			{
				CloseHandle(SoundSetsKV);
				SetFailState("configs/hide_and_seek/whistle/HnS_SetsList.cfg not correctly structured.");
			}
		}
		// Other packs of sounds
		else
		{
			if (KvJumpToKey(SoundSetsKV, cvarWhistleSet))
			{
				for (int CountWhistleSound = 0; CountWhistleSound < WHISTLE_SOUNDS_MAX; CountWhistleSound++)
				{
					IntToString(CountWhistleSound, bufferString, PLATFORM_MAX_PATH);
					KvGetString(SoundSetsKV, bufferString, WhistleSoundSet[CountWhistleSound], PLATFORM_MAX_PATH);

					if (StrEqual(WhistleSoundSet[CountWhistleSound],""))
					{
						CloseHandle(SoundSetsKV);
						SetFailState("configs/hide_and_seek/whistle/HnS_SetsList.cfg not correctly structured.");
					}

					else
					{
						WhistleSoundPath[CountWhistleSound] = WhistleSoundSet[CountWhistleSound];
						PrecacheSound(WhistleSoundPath[CountWhistleSound], true);
						Format(WhistleSoundSet[CountWhistleSound], PLATFORM_MAX_PATH, "sound/%s", WhistleSoundSet[CountWhistleSound]);
						AddFileToDownloadsTable(WhistleSoundSet[CountWhistleSound]);
					}
				}
			}

			else
			{
				CloseHandle(SoundSetsKV);
				SetFailState("configs/hide_and_seek/whistle/HnS_SetsList.cfg not correctly structured.");
			}
		}
	}

	else
	{
		CloseHandle(SoundSetsKV);
		SetFailState("configs/hide_and_seek/whistle/HnS_SetsList.cfg not found.");
	}
	CloseHandle(SoundSetsKV);
	PrintToServer("[SM] Hide and Seek >> Loading whistle: %s", cvarWhistleSet);
}
