#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
    name = "[bTimes] Timer",
    author = "blacky",
    description = "The timer portion of the bTimes plugin",
    version = VERSION,
    url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <bTimes-zones>
#include <bTimes-timer>
#include <bTimes-ranks>
#include <bTimes-random>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <cstrike>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <bTimes-ghost>

// database
new    Handle:g_DB;

// Current map info
new String:g_sMapName[64],
    Handle:g_MapList;

// Player timer info
new Float:g_fCurrentTime[MAXPLAYERS + 1],
    bool:g_bTiming[MAXPLAYERS + 1];

new g_StyleConfig[32][StyleConfig];
new g_TotalStyles;

new g_Type[MAXPLAYERS + 1];
new g_Style[MAXPLAYERS + 1][MAX_TYPES];
    
new    bool:g_bTimeIsLoaded[MAXPLAYERS + 1],
    Float:g_fTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES],
    String:g_sTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][64];

new     g_Strafes[MAXPLAYERS + 1],
    g_Jumps[MAXPLAYERS + 1],
    g_SWStrafes[MAXPLAYERS + 1][2],
    Float:g_HSWCounter[MAXPLAYERS + 1],
    Float:g_fSpawnTime[MAXPLAYERS + 1];
    
new    Float:g_fNoClipSpeed[MAXPLAYERS + 1];

new g_Buttons[MAXPLAYERS + 1],
    g_UnaffectedButtons[MAXPLAYERS + 1];


new    bool:g_bPaused[MAXPLAYERS + 1],
    Float:g_fPauseTime[MAXPLAYERS + 1],
    Float:g_fPausePos[MAXPLAYERS + 1][3];
    
new    String:g_msg_start[128],
    String:g_msg_varcol[128],
    String:g_msg_textcol[128];

// Sync measurement
new    Float:g_fOldAngle[MAXPLAYERS + 1],
    g_totalSync[MAXPLAYERS + 1],
    g_goodSync[MAXPLAYERS + 1],
    g_goodSyncVel[MAXPLAYERS + 1];
    
// Hint text
new     Float:g_ServerRecord[MAX_TYPES][MAX_STYLES];
new     String:g_sRecord[MAX_TYPES][MAX_STYLES][64];

// Cvars
new     Handle:g_hTimerDisplay,
    Handle:g_hHintSpeed,
    Handle:g_hAllowYawspeed,
    Handle:g_hAllowPause,
    Handle:g_hChangeClanTag,
    Handle:g_hTimerChangeClanTag,
    Handle:g_hAllowNoClip,
    Handle:g_hVelocityCap,
    bool:g_bAllowVelocityCap,
    Handle:g_hAllowAuto,
    bool:g_bAllowAuto,
    Handle:g_hJumpInStartZone,
    bool:g_bJumpInStartZone,
    Handle:g_hAutoStopsTimer,
    bool:g_bAutoStopsTimer;
    
// All map times
new    Handle:g_hTimes[MAX_TYPES][MAX_STYLES],
    Handle:g_hTimesUsers[MAX_TYPES][MAX_STYLES],
    bool:g_bTimesAreLoaded;
    
// Forwards
new    Handle:g_fwdOnTimerFinished_Pre,
    Handle:g_fwdOnTimerFinished_Post,
    Handle:g_fwdOnTimerStart_Pre,
    Handle:g_fwdOnTimerStart_Post,
    Handle:g_fwdOnTimesDeleted,
    Handle:g_fwdOnTimesUpdated,
    Handle:g_fwdOnStylesLoaded,
    Handle:g_fwdOnTimesLoaded,
    Handle:g_fwdOnStyleChanged;
    
new Handle:g_ConVar_AirAccelerate,
    Handle:g_ConVar_EnableBunnyhopping;
    
ConVar g_ConVar_Autobunnyhopping = null;

// Admin
new    bool:g_bIsAdmin[MAXPLAYERS + 1];

bool JumpButtonsFix[65] = false;

float g_flNextSpammingTime[MAXPLAYERS + 1];
bool g_bIsSpamming[MAXPLAYERS + 1];

char g_finishsounds[][] =
{
	"buttons/button16.wav",
	"player/vo/sas/onarollbrag13.wav",
	"player/vo/sas/onarollbrag03.wav",
	"player/vo/phoenix/onarollbrag11.wav",
	"player/vo/anarchist/onarollbrag13.wav",
	"player/vo/separatist/onarollbrag01.wav",
	"player/vo/seal/onarollbrag08.wav"	
};

char g_wrsounds[][] =
{
	"radio/legacy_thats_the_way.wav",
	"radio/legacy_this_is_my_house.wav",
	"radio/legacy_very_nice.wav",
	"radio/legacy_way_to_be_team.wav",
	"radio/legacy_well_done.wav",
	"radio/legacy_who_wants_some.wav",
	"radio/legacy_whoo.wav",
	"radio/legacy_yea_baby.wav",
	"radio/legacy_yesss.wav",
	"radio/legacy_yesss2.wav"
};

public OnPluginStart()
{
    // Connect to the database
    DB_Connect();
    
    // Server cvars
    g_hHintSpeed       = CreateConVar("timer_hintspeed", "0.1", "Changes the hint text update speed (bottom center text)", 0, true, 0.1);
    g_hAllowYawspeed   = CreateConVar("timer_allowyawspeed", "0", "Lets players use +left/+right commands without stopping their timer.", 0, true, 0.0, true, 1.0);
    g_hAllowPause      = CreateConVar("timer_allowpausing", "1", "Lets players use the !pause/!unpause commands.", 0, true, 0.0, true, 1.0);
    g_hChangeClanTag   = CreateConVar("timer_changeclantag", "1", "Means player clan tags will show their current timer time.", 0, true, 0.0, true, 1.0);
    g_hAllowNoClip     = CreateConVar("timer_noclip", "1", "Allows players to use the !p commands to noclip themselves.", 0, true, 0.0, true, 1.0);
    g_hVelocityCap     = CreateConVar("timer_velocitycap", "1", "Allows styles with a max velocity cap to cap player velocity.", 0, true, 0.0, true, 1.0);
    g_hJumpInStartZone = CreateConVar("timer_allowjumpinstart", "1", "Allows players to jump in the start zone. (This is not exactly anti-prespeed)", 0, true, 0.0, true, 1.0);
    g_hAllowAuto       = CreateConVar("timer_allowauto", "1", "Allows players to use auto bunnyhop.", 0, true, 0.0, true, 1.0);
    g_hAutoStopsTimer  = CreateConVar("timer_autostopstimer", "0", "Players can't get times with autohop on.");
    
    HookConVarChange(g_hHintSpeed, OnTimerHintSpeedChanged);
    HookConVarChange(g_hChangeClanTag, OnChangeClanTagChanged);
    HookConVarChange(g_hVelocityCap, OnVelocityCapChanged);
    HookConVarChange(g_hAutoStopsTimer, OnAutoStopsTimerChanged);
    HookConVarChange(g_hAllowAuto, OnAllowAutoChanged);
    HookConVarChange(g_hJumpInStartZone, OnAllowJumpInStartZoneChanged);
    
    AutoExecConfig(true, "timer", "timer");
    
    // Event hooks
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
    HookEvent("player_jump", Event_PlayerJump, EventHookMode_Pre);
    HookEvent("player_jump", Event_PlayerJump_Post, EventHookMode_Post);
    
    // Admin commands
    RegAdminCmd("sm_delete", SM_Delete, ADMFLAG_CHEATS, "Deletes map times.");
    RegAdminCmd("sm_spj", SM_SPJ, ADMFLAG_GENERIC, "Check the strafes per jump ratios for any player.");
    RegAdminCmd("sm_enablestyle", SM_EnableStyle, ADMFLAG_RCON, "Enables a style for players to use. (Resets to default setting on map change)");
    RegAdminCmd("sm_disablestyle", SM_DisableStyle, ADMFLAG_RCON, "Disables a style so players can no longer use it. (Resets to default setting on map change)");
    
    // Player commands
    RegConsoleCmdEx("sm_stop", SM_StopTimer, "Stops your timer.");
    RegConsoleCmdEx("sm_style", SM_Style, "Change your style.");
    RegConsoleCmdEx("sm_mode", SM_Style, "Change your style.");
    RegConsoleCmdEx("sm_bstyle", SM_BStyle, "Change your bonus style.");
    RegConsoleCmdEx("sm_bmode", SM_BStyle, "Change your bonus style.");
    RegConsoleCmdEx("sm_practice", SM_Practice, "Puts you in noclip. Stops your timer.");
    RegConsoleCmdEx("sm_p", SM_Practice, "Puts you in noclip. Stops your timer.");
    RegConsoleCmdEx("sm_noclipme", SM_Practice, "Puts you in noclip. Stops your timer.");
    RegConsoleCmdEx("sm_truevel", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
    RegConsoleCmdEx("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
    RegConsoleCmdEx("sm_pause", SM_Pause, "Pauses your timer and freezes you.");
    RegConsoleCmdEx("sm_auto", SM_Auto, "Toggles auto bunnyhop.");
    RegConsoleCmdEx("sm_bhop", SM_Auto, "Toggles auto bunnyhop.");
    RegConsoleCmdEx("sm_move", SM_Move, "For getting players out of places they are stuck in");
    RegAdminCmd("sm_reloadstyle", SM_ReloadStyle, ADMFLAG_ROOT, "Reload Style Config.");
        
    // Makes FindTarget() work properly
    LoadTranslations("common.phrases");
    
    for(new Type; Type < MAX_TYPES; Type++)
    {
        for(new Style; Style < MAX_STYLES; Style++)
        {
            g_hTimes[Type][Style]      = CreateArray(2);
            g_hTimesUsers[Type][Style] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
        }
    }
    
    g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" );
    
    if ( g_ConVar_AirAccelerate == INVALID_HANDLE )
        SetFailState( "Unable to find cvar handle for sv_airaccelerate!" );
    
    new flags = GetConVarFlags( g_ConVar_AirAccelerate );
    
    flags &= ~FCVAR_NOTIFY;
    //flags &= ~FCVAR_REPLICATED;
    
    SetConVarFlags( g_ConVar_AirAccelerate, flags );
    
    g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" );
    
    if ( g_ConVar_EnableBunnyhopping == INVALID_HANDLE )
        SetFailState( "Unable to find cvar handle for sv_enablebunnyhopping!" );
    
    flags = GetConVarFlags( g_ConVar_EnableBunnyhopping );
    
    flags &= ~FCVAR_NOTIFY;
    flags &= ~FCVAR_REPLICATED;
    
    SetConVarFlags( g_ConVar_EnableBunnyhopping, flags );

    g_ConVar_Autobunnyhopping = FindConVar("sv_autobunnyhopping");
    g_ConVar_Autobunnyhopping.Flags &= ~FCVAR_NOTIFY;
}

public OnAllPluginsLoaded()
{
	ReadStyleConfig();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Natives
    CreateNative("StartTimer", Native_StartTimer);
    CreateNative("StopTimer", Native_StopTimer);
    CreateNative("IsBeingTimed", Native_IsBeingTimed);
    CreateNative("FinishTimer", Native_FinishTimer);
    CreateNative("GetClientStyle", Native_GetClientStyle);
    CreateNative("IsTimerPaused", Native_IsTimerPaused);
    CreateNative("GetStyleName", Native_GetStyleName);
    CreateNative("GetStyleAbbr", Native_GetStyleAbbr);
    CreateNative("Style_IsEnabled", Native_Style_IsEnabled);
    CreateNative("Style_IsTypeAllowed", Native_Style_IsTypeAllowed);
    CreateNative("Style_IsFreestyleAllowed", Native_Style_IsFreestyleAllowed);
    CreateNative("Style_GetTotal", Native_Style_GetTotal);
    CreateNative("Style_CanUseReplay", Native_Style_CanUseReplay);
    CreateNative("Style_CanReplaySave", Native_Style_CanReplaySave);
    CreateNative("GetTypeStyleFromCommand", Native_GetTypeStyleFromCommand);
    CreateNative("GetClientTimerType", Native_GetClientTimerType);
    //CreateNative("Style_GetConfig", Native_GetStyleConfig);
    CreateNative("Timer_GetButtons", Native_GetButtons);
    //CreateNative("Timer_OpenStatsMenu", Native_OpenStatsMenu);
    
    // Forwards
    g_fwdOnTimerStart_Pre     = CreateGlobalForward("OnTimerStart_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnTimerStart_Post    = CreateGlobalForward("OnTimerStart_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnTimerFinished_Pre  = CreateGlobalForward("OnTimerFinished_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnTimerFinished_Post = CreateGlobalForward("OnTimerFinished_Post", ET_Event, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnTimesDeleted       = CreateGlobalForward("OnTimesDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Any);
    g_fwdOnTimesUpdated       = CreateGlobalForward("OnTimesUpdated", ET_Event, Param_String, Param_Cell, Param_Cell, Param_Any);
    g_fwdOnStylesLoaded       = CreateGlobalForward("OnStylesLoaded", ET_Event);
    g_fwdOnTimesLoaded        = CreateGlobalForward("OnMapTimesLoaded", ET_Event);
    g_fwdOnStyleChanged       = CreateGlobalForward("OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    
    return APLRes_Success;
}

public OnMapStart()
{
    // Set the map id
    GetCurrentMap(g_sMapName, sizeof(g_sMapName));
    
    for ( int i = 0; i < sizeof( g_finishsounds ); i++ )
	{
		FakePrecacheSound( g_finishsounds[i] );
	}
    
    for ( int i = 0; i < sizeof( g_wrsounds ); i++ )
	{
		FakePrecacheSound( g_wrsounds[i] );
	}
    
    FakePrecacheSound("buttons/buttons11.wav");
    
    if(g_MapList != INVALID_HANDLE)
    {
        CloseHandle(g_MapList);
    }
    
    g_MapList = ReadMapList();
    
    g_bTimesAreLoaded = false;
    
    decl String:sTypeAbbr[32], String:sStyleAbbr[32];
    
    for(new Type; Type < MAX_TYPES; Type++)
    {
        GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
        
        for(new Style; Style < g_TotalStyles; Style++)
        {
            GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
            
            FormatEx(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%sSR%s: No Record", sTypeAbbr, sStyleAbbr);
        }
    }
    
}

public OnStylesLoaded()
{
    RegConsoleCmdPerStyle("sr", SM_ServerRecord, "Show the server record info for {Type} timer on {Style} style.");
    RegConsoleCmdPerStyle("time", SM_Time, "Show your time for {Type} timer on {Style} style.");
    
    decl String:sType[32], String:sStyle[32], String:sTypeAbbr[32], String:sStyleAbbr[32], String:sCommand[64], String:sDescription[256];
    
    for(new Type; Type < MAX_TYPES; Type++)
    {
        GetTypeName(Type, sType, sizeof(sType));
        GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
        
        for(new Style; Style < g_TotalStyles; Style++)
        {
            if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
            {
                GetStyleName(Style, sStyle, sizeof(sStyle));
                GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
                
                FormatEx(sCommand, sizeof(sCommand), "sm_%s%s", sTypeAbbr, sStyleAbbr);
                FormatEx(sDescription, sizeof(sDescription), "Set your style to %s on the %s timer.", sStyle, sType);
                
                if(Type == TIMER_MAIN)
                    RegConsoleCmdEx(sCommand, SM_SetStyle, sDescription);
                else if(Type == TIMER_BONUS)
                    RegConsoleCmdEx(sCommand, SM_SetBonusStyle, sDescription);
            }
        }
    }
}

public OnStyleChanged(client, oldStyle, newStyle, type)
{
    new oldAA = g_StyleConfig[oldStyle][AirAcceleration];
    new newAA = g_StyleConfig[newStyle][AirAcceleration];
    
    if(oldAA != newAA)
    {
        CPrintToChat(client, "%s%sYour airacceleration has been set to %s%d%s.",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol,
            newAA,
            g_msg_textcol);
    }
}

public OnConfigsExecuted()
{
    // Reset temporary enabled and disabled styles
    for(new Style; Style < g_TotalStyles; Style++)
    {
        g_StyleConfig[Style][TempEnabled] = g_StyleConfig[Style][Enabled];
    }
    
    if(GetConVarInt(g_hChangeClanTag) == 0)
    {
        KillTimer(g_hTimerChangeClanTag);
    }
    else
    {
        g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }

    
    g_hTimerDisplay = CreateTimer(GetConVarFloat(g_hHintSpeed), Timer_DrawHintText, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    
    g_bAllowVelocityCap = GetConVarBool(g_hVelocityCap);
    g_bAllowAuto        = GetConVarBool(g_hAllowAuto);
    g_bAutoStopsTimer   = GetConVarBool(g_hAutoStopsTimer);
    g_bJumpInStartZone  = GetConVarBool(g_hJumpInStartZone);
    
    ExecMapConfig();
}

public bool:OnClientConnect(client)
{
    for(new Type; Type < MAX_TYPES; Type++)
    {
        for(new Style; Style < MAX_STYLES; Style++)
        {
            g_fTime[client][Type][Style] = 0.0;
            FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "Best: N/A");
        }
    }
    
    // Set player times to null
    g_bTimeIsLoaded[client] = false;
    
    // Unpause timers
    g_bPaused[client] = false;
    
    // Reset noclip speed
    g_fNoClipSpeed[client] = 1.0;
    
    // Set style to first available style for each timer type
    for(new Type; Type < MAX_TYPES; Type++)
    {
        for(new Style; Style < MAX_STYLES; Style++)
        {
            if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
            {
                g_Style[client][Type] = Style;
                break;
            }
        }
    }
    
    g_bIsAdmin[client] = false;
    
    g_fNoClipSpeed[client] = 1.0;
    
    g_flNextSpammingTime[client] = 0.0;
    
    g_bIsSpamming[client] = false;
    
    return true;
}

public OnClientPutInServer(client)
{    
    SDKHook(client, SDKHook_PreThink, Hook_PreThink);
}

public Hook_PreThink(client)
{
    if(!IsFakeClient(client))
    {
        SetConVarInt(g_ConVar_AirAccelerate, g_StyleConfig[g_Style[client][g_Type[client]]][AirAcceleration]);
        SetConVarBool(g_ConVar_EnableBunnyhopping, g_StyleConfig[g_Style[client][g_Type[client]]][EnableBunnyhopping]);
        SetConVarBool(g_ConVar_Autobunnyhopping, g_StyleConfig[g_Style[client][g_Type[client]]][Auto]);
    }
}

public OnClientPostAdminCheck(client)
{
    g_bIsAdmin[client] = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
}

public OnPlayerIDLoaded(client)
{
    if(g_bTimesAreLoaded == true)
    {
        DB_LoadPlayerInfo(client);
    }
}

public OnTimerChatChanged(MessageType, String:Message[])
{
    if(MessageType == 0)
    {
        Format(g_msg_start, sizeof(g_msg_start), Message);
    }
    else if(MessageType == 1)
    {
        Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
    }
    else if(MessageType == 2)
    {
        Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
    }
}

public OnZonesLoaded()
{    
    DB_LoadTimes(true);
}

public OnTimerHintSpeedChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    KillTimer(g_hTimerDisplay);
    
    g_hTimerDisplay = CreateTimer(GetConVarFloat(convar), Timer_DrawHintText, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public OnChangeClanTagChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if(GetConVarInt(convar) == 0)
    {
        KillTimer(g_hTimerChangeClanTag);
    }
    else
    {
        g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }
}

public OnVelocityCapChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bAllowVelocityCap = bool:StringToInt(newValue);
}

public OnAutoStopsTimerChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if(StringToInt(newValue) == 1)
    {
        for(new client = 1; client <= MaxClients; client++)
        {
            if(IsClientInGame(client) && IsBeingTimed(client, TIMER_ANY) && (GetClientSettings(client) & AUTO_BHOP))
            {
                StopTimer(client);
            }
        }
    }
}

public OnAllowJumpInStartZoneChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bJumpInStartZone = bool:StringToInt(newValue);
}

public OnAllowAutoChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bAllowAuto = bool:StringToInt(newValue);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // Player timers should stop when they die
    StopTimer(client);
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // Player timers should stop when they switch teams
    StopTimer(client);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // Anti-time-cheat
    g_fSpawnTime[client] = GetEngineTime();
    
    // Player timers should stop when they spawn
    StopTimer(client);
}

public Action:Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // Increase jump count for the hud hint text, it resets to 0 when StartTimer for the client is called
    if(g_bTiming[client] == true)
    {
        g_Jumps[client]++;
    }
    
    new Style = g_Style[client][g_Type[client]];
    
    if(g_StyleConfig[Style][EzHop] == true)
    {
        SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
    }
    else if(g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_EzHop])
    {
        if(Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1)
        {
            SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
        }
    }
}

public Action:Event_PlayerJump_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Check max velocity on player jump event rather than OnPlayerRunCmd, rewards better strafing
    if(g_bAllowVelocityCap == true)
    {
        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        
        new Style = g_Style[client][g_Type[client]];
        
        if(g_bAllowVelocityCap == true && g_StyleConfig[Style][MaxVel] != 0.0)
        {
            // Has to be on next game frame, TeleportEntity doesn't seem to work in event player_jump
            CreateTimer(0.0, Timer_CheckVel, client);
        }
    }
}

public Action:Timer_CheckVel(Handle:timer, any:client)
{
    new Style = g_Style[client][g_Type[client]];
    
    new Float:fVel = GetClientVelocity(client, true, true, false);
        
    if(fVel > g_StyleConfig[Style][MaxVel])
    {
        new Float:vVel[3];
        Entity_GetAbsVelocity(client, vVel);
        
        new Float:fTemp = vVel[2];
        ScaleVector(vVel, g_StyleConfig[Style][MaxVel]/fVel);
        vVel[2] = fTemp;
        
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
    }
}

// Auto bhop
public Action:SM_Auto(client, args)
{
    if(!client) return Plugin_Handled;

    if(g_bAllowAuto == true)
    {
        if (args < 1)
        {
            SetClientSettings(client, GetClientSettings(client) ^ AUTO_BHOP);
            
            if(g_bAutoStopsTimer && (GetClientSettings(client) & AUTO_BHOP))
            {
                StopTimer(client);
            }
            
            if(GetClientSettings(client) & AUTO_BHOP)
            {
                CPrintToChat(client, "%s%sAuto bhop %senabled",
                    g_msg_start,
                    g_msg_textcol,
                    g_msg_varcol);
            }
            else
            {
                CPrintToChat(client, "%s%sAuto bhop %sdisabled",
                    g_msg_start,
                    g_msg_textcol,
                    g_msg_varcol);
            }
        }
        else if (args == 1)
        {
            decl String:TargetArg[128];
            GetCmdArgString(TargetArg, sizeof(TargetArg));
            new TargetID = FindTarget(client, TargetArg, true, false);
            if(TargetID != -1)
            {
                decl String:TargetName[128];
                GetClientName(TargetID, TargetName, sizeof(TargetName));
                if(GetClientSettings(TargetID) & AUTO_BHOP)
                {
                    CPrintToChat(client, "%s%sPlayer %s%s%s has auto bhop %senabled",
                        g_msg_start,
                        g_msg_textcol,
                        g_msg_varcol,
                        TargetName,
                        g_msg_textcol,
                        g_msg_varcol);
                }
                else
                {
                    CPrintToChat(client, "%s%sPlayer %s%s%s has auto bhop %sdisabled",
                        g_msg_start,
                        g_msg_textcol,
                        g_msg_varcol,
                        TargetName,
                        g_msg_textcol,
                        g_msg_varcol);
                }
            }
        }
    }
    
    return Plugin_Handled;
}

// Toggles between 2d vector and 3d vector velocity
public Action:SM_TrueVelocity(client, args)
{
    if(!client) return Plugin_Handled;
	
    SetClientSettings(client, GetClientSettings(client) ^ SHOW_2DVEL);
    
    if(GetClientSettings(client) & SHOW_2DVEL)
    {
        CPrintToChat(client, "%s%sShowing %strue %svelocity",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol,
            g_msg_textcol);
    }
    else
    {
        CPrintToChat(client, "%s%sShowing %snormal %svelocity",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol,
            g_msg_textcol);
    }
    
    return Plugin_Handled;
}

public Action:SM_SPJ(client, args)
{
    // Get target
    decl String:sArg[255];
    GetCmdArgString(sArg, sizeof(sArg));
    
    // Write data to send to query callback
    new Handle:pack = CreateDataPack();
    WritePackCell(pack, GetClientUserId(client));
    WritePackString(pack, sArg);
    
    // Do query
    decl String:query[512];
    Format(query, sizeof(query), "SELECT User, SPJ, SteamID, MStrafes, MJumps FROM (SELECT t2.User, t2.SteamID, AVG(t1.Strafes/t1.Jumps) AS SPJ, SUM(t1.Strafes) AS MStrafes, SUM(t1.Jumps) AS MJumps FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID  AND t1.Style=0 GROUP BY t1.PlayerID ORDER BY AVG(t1.Strafes/t1.Jumps) DESC) AS x WHERE MStrafes > 100");
    SQL_TQuery(g_DB, SPJ_Callback, query, pack);
    
    return Plugin_Handled;
}

public SPJ_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
    if(hndl != INVALID_HANDLE)
    {
        // Get data from command arg
        decl String:sTarget[MAX_NAME_LENGTH];
        
        ResetPack(pack);
        new client = GetClientOfUserId(ReadPackCell(pack));
        ReadPackString(pack, sTarget, sizeof(sTarget));
        
        new len = strlen(sTarget);
        
        decl String:item[255], String:info[255], String:sAuth[32], String:sName[MAX_NAME_LENGTH];
        new     Float:SPJ, Strafes, Jumps;
        
        // Create menu
        new Handle:menu = CreateMenu(Menu_ShowSPJ);
        SetMenuTitle(menu, "Showing strafes per jump\nSelect an item for more info\n ");
        
        new     rows = SQL_GetRowCount(hndl);
        for(new i=0; i<rows; i++)
        {
            SQL_FetchRow(hndl);
            
            SQL_FetchString(hndl, 0, sName, sizeof(sName));
            SPJ = SQL_FetchFloat(hndl, 1);
            SQL_FetchString(hndl, 2, sAuth, sizeof(sAuth));
            Strafes = SQL_FetchInt(hndl, 3);
            Jumps = SQL_FetchInt(hndl, 4);
            
            if(StrContains(sName, sTarget) != -1 || len == 0)
            {
                Format(item, sizeof(item), "%.1f - %s",
                    SPJ,
                    sName);
                
                Format(info, sizeof(info), "%s <%s> SPJ: %.1f, Strafes: %d, Jumps: %d",
                    sName,
                    sAuth,
                    SPJ,
                    Strafes,
                    Jumps);
                    
                AddMenuItem(menu, info, item);
            }
        }
        
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(pack);
}

public Menu_ShowSPJ(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:info[255];
        GetMenuItem(menu, param2, info, sizeof(info));
        PrintToChat(param1, info);
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

// Admin command for deleting times
public Action:SM_Delete(client, args)
{
    if(args == 0)
    {
        if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
            PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
    }
    else if(args == 1)
    {
        decl String:input[128];
        GetCmdArgString(input, sizeof(input));
        new value = StringToInt(input);
        if(value != 0)
        {
            AdminCmd_DeleteRecord(client, value, value);
        }
    }
    else if(args == 2)
    {
        decl String:sValue0[128], String:sValue1[128];
        GetCmdArg(1, sValue0, sizeof(sValue0));
        GetCmdArg(2, sValue1, sizeof(sValue1));
        AdminCmd_DeleteRecord(client, StringToInt(sValue0), StringToInt(sValue1));
    }
    
    return Plugin_Handled;
}

AdminCmd_DeleteRecord(client, value1, value2)
{
    new Handle:menu = CreateMenu(AdminMenu_DeleteRecord);
    
    if(value1 == value2)
        SetMenuTitle(menu, "Delete record %d", value1);
    else
        SetMenuTitle(menu, "Delete records %d to %d", value1, value2);
    
    decl String:sDisplay[64], String:sInfo[32], String:sStyle[32], String:sType[32];
    
    for(new Type; Type < MAX_TYPES; Type++)
    {
        GetTypeName(Type, sType, sizeof(sType));
        
        for(new Style; Style < g_TotalStyles; Style++)
        {
            if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
            {
                Format(sInfo, sizeof(sInfo), "%d;%d;%d;%d", value1, value2, Type, Style);
                
                GetStyleName(Style, sStyle, sizeof(sStyle));
                
                FormatEx(sDisplay, sizeof(sDisplay), "%s (%s)", sStyle, sType);
                
                AddMenuItem(menu, sInfo, sDisplay);
            }
        }
    }
    
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_DeleteRecord(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        decl String:info[32], String:sTypeStyle[4][8];
        GetMenuItem(menu, param2, info, sizeof(info));
        
        if(StrContains(info, ";") != -1)
        {
            ExplodeString(info, ";", sTypeStyle, 4, 8);
            
            new RecordOne = StringToInt(sTypeStyle[0]);
            new RecordTwo = StringToInt(sTypeStyle[1]);
            new Type      = StringToInt(sTypeStyle[2]);
            new Style     = StringToInt(sTypeStyle[3]);
            
            DB_DeleteRecord(param1, Type, Style, RecordOne, RecordTwo);
            //DB_UpdateRanks(g_sMapName, Type, Style);
        }
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

public Action:SM_StopTimer(client, args)
{
    StopTimer(client);
    
    return Plugin_Handled;
}

public Action:SM_ServerRecord(client, args)
{
    new Type, Style;
    if(GetTypeStyleFromCommand("sr", Type, Style))
    {
        if(!IsSpamming(client))
        {
            SetIsSpamming(client, 1.0);
            
            if(args == 0)
            {
                DB_DisplayRecords(client, g_sMapName, Type, Style);
            }
            else if(args == 1)
            {
                decl String:arg[64];
                GetCmdArgString(arg, sizeof(arg));
                if(FindStringInArray(g_MapList, arg) != -1)
                {
                    DB_DisplayRecords(client, arg, Type, Style);
                }
                else
                {
                    CPrintToChat(client, "%s%sNo map found named %s%s",
                        g_msg_start,
                        g_msg_textcol,
                        g_msg_varcol,
                        arg);
                }
            }
        }
    }
    
    return Plugin_Handled;
}

public Action:SM_Time(client, args)
{
    if(!client) return Plugin_Handled;
	
    new Type, Style;
    if(GetTypeStyleFromCommand("time", Type, Style))
    {
        if(!IsSpamming(client))
        {
            SetIsSpamming(client, 1.0);
            
            if(args == 0)
            {
                DB_ShowTime(client, client, g_sMapName, Type, Style);
            }
            else if(args == 1)
            {
                decl String:arg[250];
                GetCmdArgString(arg, sizeof(arg));
                if(arg[0] == '@')
                {
                    ReplaceString(arg, 250, "@", "");
                    DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), Type, Style);
                }
                else
                {
                    new target = FindTarget(client, arg, true, false);
                    new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
                    if(mapValid == true)
                    {
                        DB_ShowTime(client, client, arg, Type, Style);
                    }
                    if(target != -1)
                    {
                        DB_ShowTime(client, target, g_sMapName, Type, Style);
                    }
                    if(!mapValid && target == -1)
                    {
                        CPrintToChat(client, "%s%sNo map or player found named %s%s",
                            g_msg_start,
                            g_msg_textcol,
                            g_msg_varcol,
                            arg);
                    }
                }
            }
        }
    }
    
    return Plugin_Handled;
}

public Action:SM_Style(client, args)
{
    if(!client) return Plugin_Handled;
	
    new Handle:menu = CreateMenu(Menu_Style);
    
    SetMenuTitle(menu, "Change Style");
    decl String:sStyle[32], String:sInfo[16];
    
    for(new Style; Style < g_TotalStyles; Style++)
    {
        if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_MAIN])
        {
            GetStyleName(Style, sStyle, sizeof(sStyle));
            
            FormatEx(sInfo, sizeof(sInfo), "%d;%d", TIMER_MAIN, Style);
            
            AddMenuItem(menu, sInfo, sStyle);
        }
    }
    
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public Action:SM_BStyle(client, args)
{
    if(!client) return Plugin_Handled;
	
    new Handle:menu = CreateMenu(Menu_Style);
    
    SetMenuTitle(menu, "Change Bonus Style");
    decl String:sStyle[32], String:sInfo[16];
    
    for(new Style; Style < g_TotalStyles; Style++)
    {
        if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_BONUS])
        {
            GetStyleName(Style, sStyle, sizeof(sStyle));
            
            FormatEx(sInfo, sizeof(sInfo), "%d;%d", TIMER_BONUS, Style);
            
            AddMenuItem(menu, sInfo, sStyle);
        }
    }
    
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public Action:SM_SetStyle(client, args)
{
    decl String:sCommand[64];
    GetCmdArg(0, sCommand, sizeof(sCommand));
    ReplaceStringEx(sCommand, sizeof(sCommand), "sm_", "");
    
    decl String:sStyle[32];
    for(new Style; Style < g_TotalStyles; Style++)
    {
        if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_MAIN])
        {
            GetStyleAbbr(Style, sStyle, sizeof(sStyle));
            
            if(StrEqual(sCommand, sStyle))
            {
                SetStyle(client, TIMER_MAIN, Style);
            }
        }
    }
    
    return Plugin_Handled;
}

public Action:SM_SetBonusStyle(client, args)
{
    decl String:sCommand[64];
    GetCmdArg(0, sCommand, sizeof(sCommand));
    ReplaceStringEx(sCommand, sizeof(sCommand), "sm_b", "");
    
    decl String:sStyle[32];
    for(new Style; Style < g_TotalStyles; Style++)
    {
        if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_BONUS])
        {
            GetStyleAbbr(Style, sStyle, sizeof(sStyle));
            
            if(StrEqual(sCommand, sStyle))
            {
                SetStyle(client, TIMER_BONUS, Style);
            }
        }
    }
    
    return Plugin_Handled;
}

public Menu_Style(Handle:menu, MenuAction:action, client, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        
        if(StrContains(info, ";") != -1)
        {
            decl String:sInfoExplode[2][16];
            ExplodeString(info, ";", sInfoExplode, sizeof(sInfoExplode), sizeof(sInfoExplode[]));
            
            SetStyle(client, StringToInt(sInfoExplode[0]), StringToInt(sInfoExplode[1]));
        }
    }
    else if(action == MenuAction_End)
        CloseHandle(menu);
}

SetStyle(client, Type, Style)
{
    new OldStyle = g_Style[client][Type];
    
    g_Style[client][Type] = Style;
    
    if (!IsPlayerAlive(client))
    {
        CS_RespawnPlayer(client);
    }
    
    if(GetClientTeam(client) == 1)
    {
        ChangeClientTeam(client, GetRandomInt(2, 3));
        CS_RespawnPlayer(client);
    }
    
    if(Type == TIMER_MAIN)
        Timer_TeleportToZone(client, MAIN_START, 0, true);
    else if(Type == TIMER_BONUS)
        Timer_TeleportToZone(client, BONUS_START, 0, true);
    
    Call_StartForward(g_fwdOnStyleChanged);
    Call_PushCell(client);
    Call_PushCell(OldStyle);
    Call_PushCell(Style);
    Call_PushCell(Type);
    Call_Finish();
}

public Action:SM_Practice(client, args)
{
    if(GetConVarBool(g_hAllowNoClip))
    {
    	
    	if(!client)
    	    return Plugin_Handled;
    	
    	if(!IsPlayerAlive(client))
    	    return Plugin_Handled;
    	    
        if(args == 0)
        {
            StopTimer(client);
            
            new MoveType:movetype = GetEntityMoveType(client);
            if (movetype != MOVETYPE_NOCLIP)
            {
                SetEntityMoveType(client, MOVETYPE_NOCLIP);
                SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fNoClipSpeed[client]);
            }
            else
            {
                SetEntityMoveType(client, MOVETYPE_WALK);
                SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
            }
        }
        else
        {
            decl String:sArg[250];
            GetCmdArgString(sArg, sizeof(sArg));
            
            new Float:fSpeed = StringToFloat(sArg);
            
            if(!(0 <= fSpeed <= 10))
            {
                CPrintToChat(client, "%s%sYour noclip speed must be between 0 and 10",
                    g_msg_start,
                    g_msg_textcol);
                    
                return Plugin_Handled;
            }
            
            g_fNoClipSpeed[client] = fSpeed;
        
            CPrintToChat(client, "%s%sNoclip speed changed to %s%f%s%s",
                g_msg_start,
                g_msg_textcol,
                g_msg_varcol,
                fSpeed,
                g_msg_textcol,
                (fSpeed != 1.0)?" (Default is 1)":" (Default)");
                
            if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
            {
                SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
            }
        }
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action:SM_Pause(client, args)
{
    if(!client) return Plugin_Handled;
	
    if(GetConVarBool(g_hAllowPause))
    {
        if(Timer_InsideZone(client, MAIN_START, -1) == -1 && Timer_InsideZone(client, BONUS_START, -1) == -1)
        {
            if(g_bTiming[client] == true)
            {
                if(g_bPaused[client] == false)
                {
                    if(GetClientVelocity(client, true, true, true) == 0.0)
                    {
                        GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_fPausePos[client]);
                        g_fPauseTime[client] = g_fCurrentTime[client];
                        g_bPaused[client]      = true;
                        
                        CPrintToChat(client, "%s%sTimer paused.",
                            g_msg_start,
                            g_msg_textcol);
                    }
                    else
                    {
                        CPrintToChat(client, "%s%sYou can't pause while moving.",
                            g_msg_start,
                            g_msg_textcol);
                    }
                }
                else
                {
                    // Teleport player to the position they paused at
                    TeleportEntity(client, g_fPausePos[client], NULL_VECTOR, Float:{0, 0, 0});
                
                    // Set their new start time
                    g_fCurrentTime[client] = g_fPauseTime[client];
                
                    // Unpause
                    g_bPaused[client] = false;
                
                    CPrintToChat(client, "%s%sTimer unpaused.",
                        g_msg_start,
                        g_msg_textcol);
                }
            }
            else
            {
                CPrintToChat(client, "%s%sYou have no timer running.",
                    g_msg_start,
                    g_msg_textcol);
            }
        }
        else
        {
            CPrintToChat(client, "%s%sYou can't pause while inside a starting zone.",
                g_msg_start,
                g_msg_textcol);
        }
    }
    
    return Plugin_Handled;
}

public Action:SM_EnableStyle(client, args)
{
    if(args == 1)
    {
        decl String:sArg[32];
        GetCmdArg(1, sArg, sizeof(sArg));
        new Style = StringToInt(sArg);
        
        if(0 <= Style < g_TotalStyles)
        {
            g_StyleConfig[Style][TempEnabled] = true;
            ReplyToCommand(client, "[Timer] - Style '%d' has been enabled.", Style);
        }
        else
        {
            ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be enabled.", Style);
        }
    }
    else
    {
        ReplyToCommand(client, "[Timer] - Example: \"sm_enablestyle 1\" will enable the style with number value of 1 in the styles.cfg");
    }
    
    return Plugin_Handled;
}

public Action:SM_DisableStyle(client, args)
{
    if(args == 1)
    {
        decl String:sArg[32];
        GetCmdArg(1, sArg, sizeof(sArg));
        new Style = StringToInt(sArg);
        
        if(0 <= Style < g_TotalStyles)
        {
            g_StyleConfig[Style][TempEnabled] = false;
            ReplyToCommand(client, "[Timer] - Style '%d' has been disabled.", Style);
        }
        else
        {
            ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be disabled.", Style);
        }
    }
    else
    {
        ReplyToCommand(client, "[Timer] - Example: \"sm_disablestyle 1\" will disable the style with number value of 1 in the styles.cfg");
    }
    
    return Plugin_Handled;
}

public Action SM_ReloadStyle(int client, int args)
{
	ReadStyleConfig();
		
	return Plugin_Handled;
}

public Action:SM_Move(client, args)
{
	if(!client)	return Plugin_Handled;
	
	if(Timer_InsideZone(client, MAIN_START) != -1 || Timer_InsideZone(client, BONUS_START) != -1)
	{
        CPrintToChat(client, "%s%sYou cant use this command when you're in start zone.",
		            g_msg_start,
                    g_msg_textcol);

        return Plugin_Handled;
    }
    
	if(IsSpammingCommand(client, GetRandomFloat(1.0, 4.0)))
	{
		CPrintToChat(client, "%s%sStop Spamming.", g_msg_start,
					g_msg_textcol);
		return Plugin_Handled;
	}
    
	new Float:angles[3], Float:pos[3];
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, angles, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

	for(new i=0; i<3; i++)
		pos[i] += (angles[i] * 50);

	TeleportEntity(client, pos, NULL_VECTOR, Float:{0.0, 0.0, 0.0});

	g_fCurrentTime[client] += GetRandomFloat(30.1337, 60.1337);

	return Plugin_Handled;
}

public Action:SetClanTag(Handle:timer, any:data)
{
    decl String:sTag[32];
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            if(IsPlayerAlive(client) && !IsFakeClient(client))
            {
                GetClanTagString(client, sTag, sizeof(sTag));
                CS_SetClientClanTag(client, sTag);
            }
        }
    }
}

GetClanTagString(client, String:tag[], maxlength)
{
    if(g_bTiming[client] == true)
    {
        if(Timer_InsideZone(client, MAIN_START, -1) != -1 || Timer_InsideZone(client, BONUS_START, -1) != -1)
        {
            FormatEx(tag, maxlength, "START");
            StringToUpper(tag);
            return;
        }
        else if(g_bPaused[client])
        {
            FormatEx(tag, maxlength, "PAUSED");
            StringToUpper(tag);
            return;
        }
        else
        {
            GetTypeAbbr(g_Type[client], tag, maxlength, true);
            Format(tag, maxlength, "%s%s :: ", tag, g_StyleConfig[g_Style[client][g_Type[client]]][Name_Short]);
            StringToUpper(tag);
            
            decl String:sTime[32];
            new Float:fTime = GetClientTimer(client);
            FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
            SplitString(sTime, ".", sTime, sizeof(sTime));
            Format(tag, maxlength, "%s%s", tag, sTime);
        }
    }
    else
    {
        FormatEx(tag, maxlength, "NO TIMER");
    }
}

public Action:Timer_DrawHintText(Handle:timer, any:data)
{
	decl String:sHintMessage[256];
	
	new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
	SpecCountToArrays(SpecCount, AdminSpecCount);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			new Time = RoundToFloor(g_fTime[client][TIMER_MAIN][0]);
			if(g_fTime[client][TIMER_MAIN][0] == 0.0 || g_fTime[client][TIMER_MAIN][0] > 2000.0)
				Time = 2000;
			SetEntProp(client, Prop_Data, "m_iFrags", Time);
			
			if(GetHintMessage(client, sHintMessage, sizeof(sHintMessage), SpecCount, AdminSpecCount))
			{
				PrintHintText(client, sHintMessage);
			}
		}
	}
}

bool:GetHintMessage(client, String:buffer[], maxlength, SpecCount[], AdminSpecCount[])
{
	new target;

	if(IsPlayerAlive(client))
	{
		target = client;
	}
	else
	{
		target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
			return false;
		
		if(IsFakeClient(target))
			return false;
	}

	new settings = GetClientSettings(client);
	new Style = g_Style[target][g_Type[target]];
	new buttons = GetClientButtons(target);

	if(Timer_InsideZone(target, MAIN_START) != -1 || Timer_InsideZone(target, BONUS_START) != -1)
	{
		if(Timer_InsideZone(target, MAIN_START) != -1)
		{
			FormatEx(buffer, maxlength, "");

			if(strlen(g_StyleConfig[Style][Name]) <= 5)
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			else
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			
			Format(buffer, maxlength, "%s<font color=\"#06db49\">Main Start\n</font>", buffer);
			
			if(!IsFakeClient(client))
			{
				if(strlen(g_sTime[target][g_Type[target]][GetStyle(target)]) <= 40)
				{
					Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
				else
				{
					Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
			}
			
			if(!IsFakeClient(client))
			{
				Format(buffer, maxlength, "%s%s\n", buffer, g_sRecord[g_Type[target]][GetStyle(target)]);
			}
			
			Format(buffer, maxlength, "%sSpecs: %d\t      %s\t\t", buffer, (g_bIsAdmin[client])?AdminSpecCount[target]:SpecCount[target], buttons & IN_FORWARD ? "W":"_");
			
			Format(buffer, maxlength, "%sSpeed: %d\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, (settings & SHOW_2DVEL) == 0)));
		
			char keys[32];
			GetKeysMessage(target, keys, sizeof(keys));
			Format(buffer, maxlength, "%s%s", buffer, keys);
			
			Format(buffer, maxlength, "<font size='16'>%s</font>", buffer);
		}
		else if(Timer_InsideZone(target, BONUS_START) != -1)
		{
			FormatEx(buffer, maxlength, "");

			if(strlen(g_StyleConfig[Style][Name]) <= 5)
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			else
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			
			Format(buffer, maxlength, "%s<font color=\"#06db49\">Bonus Start\n</font>", buffer);
			
			if(!IsFakeClient(client))
			{
				if(strlen(g_sTime[target][g_Type[target]][GetStyle(target)]) <= 40)
				{
					Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
				else
				{
					Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
			}
			
			if(!IsFakeClient(client))
			{
				Format(buffer, maxlength, "%s%s\n", buffer, g_sRecord[g_Type[target]][GetStyle(target)]);
			}
			
			Format(buffer, maxlength, "%sSpecs: %d\t      %s\t\t", buffer, (g_bIsAdmin[client])?AdminSpecCount[target]:SpecCount[target], buttons & IN_FORWARD ? "W":"_");
			
			Format(buffer, maxlength, "%sSpeed: %d\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, (settings & SHOW_2DVEL) == 0)));
			
			char keys[32];
			GetKeysMessage(target, keys, sizeof(keys));
			Format(buffer, maxlength, "%s%s", buffer, keys);
			
			Format(buffer, maxlength, "<font size='16'>%s</font>", buffer);
		}
	}
	else
	{
		if(g_bTiming[target])
		{
			if(g_bPaused[target] == false)
			{
				GetTimerAdvancedString(target, buffer, maxlength, client, SpecCount, AdminSpecCount);
			}
			else
			{
				GetTimerPauseString(target, buffer, maxlength, client, SpecCount, AdminSpecCount);
			}
		}
		else
		{
			FormatEx(buffer, maxlength, "");
			
			if(strlen(g_StyleConfig[Style][Name]) <= 5)
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			else
			{
				Format(buffer, maxlength, "%sStyle: %s\t\t", buffer, g_StyleConfig[Style][Name]);
			}
			
			Format(buffer, maxlength, "%s<font color=\"#f72d0e\">Timer Stopped\n</font>", buffer);
			
			if(!IsFakeClient(client))
			{
				if(strlen(g_sTime[target][g_Type[target]][GetStyle(target)]) <= 40)
				{
					Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
				else
				{
					Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[target][g_Type[target]][GetStyle(target)]);
				}
			}
			
			Format(buffer, maxlength, "%sSync: %.1f\n", buffer, GetClientSync(target));
			
			Format(buffer, maxlength, "%sSpecs: %d\t      %s\t\t", buffer, (g_bIsAdmin[client])?AdminSpecCount[target]:SpecCount[target], buttons & IN_FORWARD ? "W":"_");
			
			Format(buffer, maxlength, "%sSpeed: %d\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, (settings & SHOW_2DVEL) == 0)));

			char keys[32];
			GetKeysMessage(target, keys, sizeof(keys));
			Format(buffer, maxlength, "%s%s", buffer, keys);
			
			Format(buffer, maxlength, "<font size='16'>%s</font>", buffer);
		}
	}
	
	return true;
}

GetTimerAdvancedString(client, String:sResult[], maxlength, ward, SpecCount[], AdminSpecCount[])
{	
	FormatEx(sResult, maxlength, "");
	
	new Style    = g_Style[client][g_Type[client]];
	new buttons  = GetClientButtons(client);
	int settings = GetClientSettings(client);
	
	if(strlen(g_StyleConfig[Style][Name]) <= 5)
	{
		Format(sResult, maxlength, "%sStyle: %s\t\t\t", sResult, g_StyleConfig[Style][Name]);
	}
	else
	{
		Format(sResult, maxlength, "%sStyle: %s\t\t", sResult, g_StyleConfig[Style][Name]);
	}

	new Float:fTime = GetClientTimer(client);
	decl String:sTime[32], String:sColor[7];
	FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
	GetTimeColor(fTime, g_ServerRecord[g_Type[client]][Style], sColor, sizeof(sColor));
	Format(sResult, maxlength, "%sTime: <font color='#%s'>%s</font> #%d\n", sResult, sColor, sTime, GetPlayerPosition(fTime, g_Type[client], Style));
	
	if(!IsFakeClient(client))
	{
		if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 10)
		{
			Format(sResult, maxlength, "%s%s\t\t", sResult, g_sTime[client][g_Type[client]][GetStyle(client)]);
		}
		else
		{
			Format(sResult, maxlength, "%s%s\t\t\t", sResult, g_sTime[client][g_Type[client]][GetStyle(client)]);
		}
	}

	Format(sResult, maxlength, "%sSync: %.1f\n", sResult, GetClientSync(client));

	Format(sResult, maxlength, "%sSpecs: %d\t      %s\t\t", sResult, (g_bIsAdmin[ward])?AdminSpecCount[client]:SpecCount[client], buttons & IN_FORWARD ? "W":"_");
	
	Format(sResult, maxlength, "%sSpeed: %d\n", sResult, RoundToFloor(GetClientVelocity(client, true, true, (settings & SHOW_2DVEL) == 0)));
	
	char keys[32];
	GetKeysMessage(client, keys, sizeof(keys));
	Format(sResult, maxlength, "%s%s", sResult, keys);
	
	Format(sResult, maxlength, "<font size='16'>%s</font>", sResult);
}

GetTimerPauseString(client, String:buffer[], maxlength, ward, SpecCount[], AdminSpecCount[])
{
	new Float:fTime = g_fPauseTime[client];
	new Style    = g_Style[client][g_Type[client]];
	new buttons  = GetClientButtons(client);

	decl String:sTime[32];
	FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);

	FormatEx(buffer, maxlength, "");
	
	Format(buffer, maxlength, "%s<font color=\"#f7a90d\">\t\t  Pause</font>\n", buffer);

	if(!IsFakeClient(client))
	{
		if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
		{
			Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
		}
		else
		{
			Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
		}
	}
	
	Format(buffer, maxlength, "%sTime: %s\n", buffer, sTime);

	Format(buffer, maxlength, "%sSpecs: %d\t      %s\t\t", buffer, (g_bIsAdmin[ward])?AdminSpecCount[client]:SpecCount[client], buttons & IN_FORWARD ? "W":"_");

	Format(buffer, maxlength, "%sStyle: %s\n", buffer, g_StyleConfig[Style][Name]);

	char keys[32];
	GetKeysMessage(client, keys, sizeof(keys));
	Format(buffer, maxlength, "%s%s", buffer, keys);
	
	Format(buffer, maxlength, "<font size='16'>%s</font>", buffer);
}

void GetTimeColor(float time, float wr, char[] color, int maxlength)
{
	if (wr == 0.0) 
	{
		FormatEx(color, maxlength, "00FF00");
		return;
	}

	float ratio = time / wr;
	if (ratio < 1.0)
	{
		if (ratio <= 0.5)
			FormatEx(color, maxlength, "%02XFF00", RoundFloat(510.0 * ratio));
		else
			FormatEx(color, maxlength, "FF%02X00", RoundFloat(510.0 * (1.0 - ratio))); // 255 - 510 * (ratio - 0.5)
	}
	else
		FormatEx(color, maxlength, "0066CC");
}

void GetKeysMessage(int client, char[] keys, int maxlen)
{
	new buttons = GetClientButtons(client);

	Format(keys, maxlen, "");

	if(buttons & IN_JUMP && JumpButtonsFix[client])
		Format(keys, maxlen, "%sJump\t\t   ", keys);
	else
		Format(keys, maxlen, "%s    \t\t   ", keys);
	
	if(buttons & IN_MOVELEFT)
		Format(keys, maxlen, "%sA", keys);
	else
		Format(keys, maxlen, "%s_ ", keys);

	if(buttons & IN_BACK)
		Format(keys, maxlen, "%sS", keys);
	else
		Format(keys, maxlen, "%s_ ", keys);

	if(buttons & IN_MOVERIGHT)
		Format(keys, maxlen, "%sD\t\t", keys);
	else
		Format(keys, maxlen, "%s_\t\t", keys);

	if(buttons & IN_DUCK)
		Format(keys, maxlen, "%sDuck", keys);
	else
		Format(keys, maxlen, "%s", keys);

	Format(keys, maxlen, "%s", keys);
}

GetPlayerPosition(const Float:fTime, Type, Style)
{    
    if(g_bTimesAreLoaded == true)
    {
        new iSize = GetArraySize(g_hTimes[Type][Style]);
        
        for(new idx; idx < iSize; idx++)
        {
            if(fTime <= GetArrayCell(g_hTimes[Type][Style], idx, 1))
            {
                return idx + 1;
            }
        }
        
        return iSize + 1;
    }
    
    return 0;
}

GetPlayerPositionByID(PlayerID, Type, Style)
{
    if(g_bTimesAreLoaded == true)
    {
        new iSize = GetArraySize(g_hTimes[Type][Style]);
        
        for(new idx = 0; idx < iSize; idx++)
        {
            if(PlayerID == GetArrayCell(g_hTimes[Type][Style], idx, 0))
            {
                return idx + 1;
            }
        }
        
        return iSize + 1;
    }
    
    return 0;
}

SpecCountToArrays(clients[], admins[])
{
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            if(!IsPlayerAlive(client))
            {
                new Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
                new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
                if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
                {
                    if(g_bIsAdmin[client] == false)
                        clients[Target]++;
                    admins[Target]++;
                }
            }
        }
    }
}

Float:GetClientSync(client)
{
    if(g_totalSync[client] == 0)
        return 0.0;
    
    return float(g_goodSync[client])/float(g_totalSync[client]) * 100.0;
}

Float:GetClientSync2(client)
{
    if(g_totalSync[client] == 0)
        return 0.0;
    
    return float(g_goodSyncVel[client])/float(g_totalSync[client]) * 100.0;
}

public Action:OnTimerStart_Pre(client, Type, Style)
{
    if(!IsClientInGame(client))
    {
        return Plugin_Handled;
    }
        
    if(!IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }
    
    // Fixes a bug for players to completely cheat times by spawning in weird parts of the map
    if(GetEngineTime() < (g_fSpawnTime[client] + 0.1))
    {
        return Plugin_Handled;
    }
    
    // Don't start if their speed isn't default
    if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
    {
        return Plugin_Handled;
    }
    
    // Don't start if they are in noclip
    if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
    {
        return Plugin_Handled;
    }
    
    // Don't start if they are a fake client
    if(IsFakeClient(client))
    {
        return Plugin_Handled;
    }
    
    if(!g_StyleConfig[Style][AllowType][Type] || !Style_IsEnabled(Style))
    {
        return Plugin_Handled;
    }
    
    if((GetClientSettings(client) & AUTO_BHOP) && g_bAutoStopsTimer)
    {
        return Plugin_Handled;
    }
    
    CheckPrespeed(client, Style);
    
    if(!(GetEntityFlags(client) & FL_ONGROUND))
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public OnTimerStart_Post(client, Type, Style)
{
    // For an always convenient starting jump
    SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
    
    if(g_StyleConfig[Style][RunSpeed] != 0.0)
    {
        SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", g_StyleConfig[Style][RunSpeed]);
    }
    
    // Set to correct gravity
    if(GetEntityGravity(client) != g_StyleConfig[Style][Gravity])
    {
        SetEntityGravity(client, g_StyleConfig[Style][Gravity]);
    }
}

public Native_StartTimer(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new Type   = GetNativeCell(2);
    new Style  = g_Style[client][Type];
    
    Call_StartForward(g_fwdOnTimerStart_Pre);
    Call_PushCell(client);
    Call_PushCell(Type);
    Call_PushCell(Style);
    
    new Action:fResult;
    Call_Finish(fResult);
    
    if(fResult != Plugin_Handled)
    {        
        g_Jumps[client]          = 0;
        g_Strafes[client]        = 0;
        g_SWStrafes[client][0]   = 1;
        g_SWStrafes[client][1]   = 1;
        g_bPaused[client]        = false;
        g_totalSync[client]      = 0;
        g_goodSync[client]       = 0;
        g_goodSyncVel[client]    = 0;
        
        g_Type[client]         = Type;
        g_bTiming[client]      = true;
        g_fCurrentTime[client] = 0.0;
        
        Call_StartForward(g_fwdOnTimerStart_Post);
        Call_PushCell(client);
        Call_PushCell(Type);
        Call_PushCell(Style);
        Call_Finish();
    }
}

CheckPrespeed(client, Style)
{    
    if(g_StyleConfig[Style][PreSpeed] != 0.0)
    {
        new Float:fVel = GetClientVelocity(client, true, true, true);
        
        if(fVel > g_StyleConfig[Style][PreSpeed])
        {
            new Float:vVel[3];
            Entity_GetAbsVelocity(client, vVel);
            ScaleVector(vVel, g_StyleConfig[Style][SlowedSpeed]/fVel);
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
        }
    }
}

public Native_StopTimer(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    
    // stop timer
    if(0 < client <= MaxClients)
    {
        g_bTiming[client] = false;
        g_bPaused[client] = false;
        
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            if(GetEntityMoveType(client) == MOVETYPE_NONE)
            {
                SetEntityMoveType(client, MOVETYPE_WALK);
            }
        }
    }
}

public Native_IsBeingTimed(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new Type   = GetNativeCell(2);
    
    if(g_bTiming[client] == true)
    {
        if(Type == TIMER_ANY)
        {
            return true;
        }
        else
        {
            return g_Type[client] == Type;
        }
    }
    
    return false;
}

public Action:OnTimerFinished_Pre(client, Type, Style)
{
    if(g_bTimeIsLoaded[client] == false)
    {
        return Plugin_Handled;
    }
    
    if(GetPlayerID(client) == 0)
    {
        return Plugin_Handled;
    }
    
    if(g_bPaused[client] == true)
    {
        return Plugin_Handled;
    }

    // Anti-cheat sideways
    if(g_StyleConfig[Style][Special] == true)
    {
        if(StrEqual(g_StyleConfig[Style][Special_Key], "sw"))
        {
            new Float:WSRatio = float(g_SWStrafes[client][0])/float(g_SWStrafes[client][1]);
            if((WSRatio > 2.0) || (g_Strafes[client] < 10))
            {
                CPrintToChat(client, "%s%sThat time did not count because you used W-Only too much",
                    g_msg_start,
                    g_msg_textcol);
                StopTimer(client);
                return Plugin_Handled;
            }
        }
    }
    
    if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public OnTimerFinished_Post(client, Float:Time, Type, Style, bool:NewTime, OldPosition, NewPosition)
{
	PlayFinishSound(client, NewTime, NewPosition);
}

PlayFinishSound(client, bool:NewTime, Position)
{
	if(NewTime == true)
	{
		int sound = GetRandomInt(1, sizeof(g_finishsounds) - 1);
		EmitSoundToClient(client, g_finishsounds[sound]);
	}
	else if(NewTime == false)
	{
		EmitSoundToClient(client, "buttons/button11.wav");
	}
	else if(NewTime == true && Position == 1)
	{
		int sound = GetRandomInt(1, sizeof(g_wrsounds) - 1);
		EmitSoundToAll(g_wrsounds[sound]);
	}
}

public Native_FinishTimer(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new Type   = g_Type[client];
    new Style  = g_Style[client][Type];
    
    Call_StartForward(g_fwdOnTimerFinished_Pre);
    Call_PushCell(client);
    Call_PushCell(Type);
    Call_PushCell(Style);
    
    new Action:fResult;
    Call_Finish(fResult);
    
    if(fResult != Plugin_Handled)
    {
        StopTimer(client);
        
        new Float:fTime = GetClientTimer(client);
        decl String:sTime[32];
        FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 1); 
        
        decl String:sType[32];

        GetTypeName(Type, sType, sizeof(sType), false);
        
        decl String:sStyle[32];

        GetStyleName(Style, sStyle, sizeof(sStyle), false);
        

        new OldPosition, NewPosition, bool:NewTime = false;
        
        if(fTime < g_fTime[client][Type][Style] || g_fTime[client][Type][Style] == 0.0)
        {
            NewTime = true;
            
            if(g_fTime[client][Type][Style] == 0.0)
                OldPosition = 0;
            else
                OldPosition = GetPlayerPositionByID(GetPlayerID(client), Type, Style);
            
            NewPosition = DB_UpdateTime(client, Type, Style, fTime, g_Jumps[client], g_Strafes[client], GetClientSync(client), GetClientSync2(client));
            
            g_fTime[client][Type][Style] = fTime;
            
            FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "Best: %s", sTime);
            
            if(NewPosition == 1)
            {
                g_ServerRecord[Type][Style] = fTime;
                
                Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "SR: %s", sTime); 
                
                CPrintToChatAll("%s%sNew %s%s %sRecord by %s%N %son %s%s %sin %s%s%s.",
                g_msg_start,
                g_msg_textcol,
                g_msg_varcol,
                sType,
                g_msg_textcol,
                g_msg_varcol,
                client,
                g_msg_textcol,
                g_msg_varcol,
                sStyle,
                g_msg_textcol,
                g_msg_varcol,
                sTime,
                g_msg_textcol);
                
                
            }
            else
            {
                CPrintToChatAll("%s%s%N %sfinished in %s%s%s (%s#%d%s) on the %s%s %stimer using %s%s %sstyle.", 
					g_msg_start,
					g_msg_varcol,
					client, 
					g_msg_textcol,
					g_msg_varcol,
					sTime,
					g_msg_textcol,
					g_msg_varcol,
					NewPosition,
					g_msg_textcol,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle,
					g_msg_textcol);
            }
        }
        else
        {
            OldPosition = GetPlayerPositionByID(GetPlayerID(client), Type, Style);
            NewPosition = OldPosition;
            
            decl String:sPersonalBest[32];
            FormatPlayerTime(g_fTime[client][Type][Style], sPersonalBest, sizeof(sPersonalBest), false, 1);
            
            CPrintToChat(client, "%s%s You finished [%s%s%s - %s%s%s] in %s%s%s, but you didn't improve on your previous time of %s%s%s.",
                g_msg_start,
                g_msg_textcol,
                g_msg_varcol,
                sType,
                g_msg_textcol,
                g_msg_varcol,
                g_StyleConfig[Style][Name],
                g_msg_textcol,
                g_msg_varcol,
                sTime,
                g_msg_textcol,
                g_msg_varcol,
                sPersonalBest,
                g_msg_textcol);
                
            CPrintToChatObservers(client, "%s%s %N %sfinished [%s%s%s - %s%s%s] in %s%s%s, but %s%N%s didn't improve on his previous time of %s%s%s.",
                g_msg_start,
                g_msg_varcol,
                client,
                g_msg_textcol,
                g_msg_varcol,
                sType,
                g_msg_textcol,
                g_msg_varcol,
                g_StyleConfig[Style][Name],
                g_msg_textcol,
                g_msg_varcol,
                sTime,
                g_msg_textcol,
                g_msg_varcol,
                client,
                g_msg_textcol,
                g_msg_varcol,
                sPersonalBest,
                g_msg_textcol);

        }
        
        Call_StartForward(g_fwdOnTimerFinished_Post);
        Call_PushCell(client);
        Call_PushFloat(fTime);
        Call_PushCell(Type);
        Call_PushCell(Style);
        Call_PushCell(NewTime);
        Call_PushCell(OldPosition);
        Call_PushCell(NewPosition);
        Call_Finish();
    }
}

GetStyle(client)
{
    return g_Style[client][g_Type[client]];
}

Float:GetClientTimer(client)
{
    return g_fCurrentTime[client];
}

ReadStyleConfig()
{
    decl String:sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/styles.cfg");
    
    new Handle:kv = CreateKeyValues("Styles");
    FileToKeyValues(kv, sPath);
    
    if(kv != INVALID_HANDLE)
    {
        new Key, bool:KeyExists = true, String:sKey[32];
        
        do
        {
            IntToString(Key, sKey, sizeof(sKey));
            KeyExists = KvJumpToKey(kv, sKey);
            
            if(KeyExists == true)
            {
                KvGetString(kv, "name", g_StyleConfig[Key][Name], 32);
                KvGetString(kv, "abbr", g_StyleConfig[Key][Name_Short], 32);
                g_StyleConfig[Key][Enabled]                = bool:KvGetNum(kv, "enable");
                g_StyleConfig[Key][AllowType][TIMER_MAIN]  = bool:KvGetNum(kv, "main");
                g_StyleConfig[Key][AllowType][TIMER_BONUS] = bool:KvGetNum(kv, "bonus");
                g_StyleConfig[Key][Freestyle]              = bool:KvGetNum(kv, "freestyle");
                g_StyleConfig[Key][Freestyle_Unrestrict]   = bool:KvGetNum(kv, "freestyle_unrestrict");
                g_StyleConfig[Key][Freestyle_EzHop]        = bool:KvGetNum(kv, "freestyle_ezhop");
                g_StyleConfig[Key][Freestyle_Auto]         = bool:KvGetNum(kv, "freestyle_auto");
                g_StyleConfig[Key][Auto]                   = bool:KvGetNum(kv, "auto");
                g_StyleConfig[Key][EzHop]                  = bool:KvGetNum(kv, "ezhop");
                g_StyleConfig[Key][Gravity]                = KvGetFloat(kv, "gravity");
                g_StyleConfig[Key][RunSpeed]               = KvGetFloat(kv, "runspeed");
                g_StyleConfig[Key][MaxVel]                 = KvGetFloat(kv, "maxvel");
                g_StyleConfig[Key][CalcSync]               = bool:KvGetNum(kv, "sync");
                g_StyleConfig[Key][Prevent_Left]           = bool:KvGetNum(kv, "prevent_left");
                g_StyleConfig[Key][Prevent_Right]          = bool:KvGetNum(kv, "prevent_right");
                g_StyleConfig[Key][Prevent_Back]           = bool:KvGetNum(kv, "prevent_back");
                g_StyleConfig[Key][Prevent_Forward]        = bool:KvGetNum(kv, "prevent_forward");
                g_StyleConfig[Key][Require_Left]           = bool:KvGetNum(kv, "require_left");
                g_StyleConfig[Key][Require_Right]          = bool:KvGetNum(kv, "require_right");
                g_StyleConfig[Key][Require_Back]           = bool:KvGetNum(kv, "require_back");
                g_StyleConfig[Key][Require_Forward]        = bool:KvGetNum(kv, "require_forward");
                g_StyleConfig[Key][Count_Left_Strafe]      = bool:KvGetNum(kv, "count_left_strafe");
                g_StyleConfig[Key][Count_Right_Strafe]     = bool:KvGetNum(kv, "count_right_strafe");
                g_StyleConfig[Key][Count_Back_Strafe]      = bool:KvGetNum(kv, "count_back_strafe");
                g_StyleConfig[Key][Count_Forward_Strafe]   = bool:KvGetNum(kv, "count_forward_strafe");
                g_StyleConfig[Key][Ghost_Use][0]           = bool:KvGetNum(kv, "ghost_use");
                g_StyleConfig[Key][Ghost_Save][0]          = bool:KvGetNum(kv, "ghost_save");
                g_StyleConfig[Key][Ghost_Use][1]           = bool:KvGetNum(kv, "ghost_use_b");
                g_StyleConfig[Key][Ghost_Save][1]          = bool:KvGetNum(kv, "ghost_save_b");
                g_StyleConfig[Key][PreSpeed]               = KvGetFloat(kv, "prespeed");
                g_StyleConfig[Key][SlowedSpeed]            = KvGetFloat(kv, "slowedspeed");
                g_StyleConfig[Key][Special]                = bool:KvGetNum(kv, "special");
                KvGetString(kv, "specialid", g_StyleConfig[Key][Special_Key], 32);
                g_StyleConfig[Key][AirAcceleration]       = KvGetNum(kv, "aa", 1000);
                g_StyleConfig[Key][EnableBunnyhopping]    = bool:KvGetNum(kv, "enablebhop", true);
                
                KvGoBack(kv);
                Key++;
            }
        }
        while(KeyExists == true && Key < MAX_STYLES);
            
        CloseHandle(kv);
    
        g_TotalStyles = Key;
        
        // Reset temporary enabled and disabled styles
        for(new Style; Style < g_TotalStyles; Style++)
        {
            g_StyleConfig[Style][TempEnabled] = g_StyleConfig[Style][Enabled];
        }
        
        Call_StartForward(g_fwdOnStylesLoaded);
        Call_Finish();
    }
    else
    {
        LogError("Something went wrong reading from the styles.cfg file.");
    }
}

ExecMapConfig()
{
    decl String:sPath[PLATFORM_MAX_PATH];
    FormatEx(sPath, sizeof(sPath), "cfg/timer/maps");
    
    if(DirExists(sPath))
    {
        FormatEx(sPath, sizeof(sPath), "cfg/timer/maps/%s.cfg", g_sMapName);
        
        if(FileExists(sPath))
        {
            ServerCommand("exec timer/maps/%s.cfg", g_sMapName);
        }
    }
    else
    {
        CreateDirectory(sPath, 511);
    }
}

DB_Connect()
{
    if(g_DB != INVALID_HANDLE)
    {
        CloseHandle(g_DB);
    }
    
    decl String:error[255];
    g_DB = SQL_Connect("timer", true, error, sizeof(error));
    
    if(g_DB == INVALID_HANDLE)
    {
        LogError(error);
        CloseHandle(g_DB);
    }
}

DB_LoadPlayerInfo(client)
{
    new PlayerID = GetPlayerID(client);
    if(IsClientConnected(client) && PlayerID != 0)
    {
        if(!IsFakeClient(client))
        {
            new iSize;
            for(new Type; Type < MAX_TYPES; Type++)
            {
                for(new Style; Style < MAX_STYLES; Style++)
                {
                    if(g_StyleConfig[Style][AllowType][Type])
                    {
                        FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "Best: N/A");
                        
                        iSize = GetArraySize(g_hTimes[Type][Style]);
                        
                        for(new idx = 0; idx < iSize; idx++)
                        {
                            if(GetArrayCell(g_hTimes[Type][Style], idx) == PlayerID)
                            {
                                g_fTime[client][Type][Style] = GetArrayCell(g_hTimes[Type][Style], idx, 1);
                                FormatPlayerTime(g_fTime[client][Type][Style], g_sTime[client][Type][Style], sizeof(g_sTime[][][]), false, 1);
                                Format(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "Best: %s", g_sTime[client][Type][Style]);
                            }
                        }
                    }
                }
            }
            
            g_bTimeIsLoaded[client] = true;
        }
    }
}

public Native_GetClientStyle(Handle:plugin, numParams)
{
    return GetStyle(GetNativeCell(1));
}

public Native_IsTimerPaused(Handle:plugin, numParams)
{
    return g_bPaused[GetNativeCell(1)];
}

public Native_GetStyleName(Handle:plugin, numParams)
{
    new Style     = GetNativeCell(1);
    new maxlength = GetNativeCell(3);
    
    if(Style == 0 && GetNativeCell(4) == true)
    {
        SetNativeString(2, "", maxlength);
        return;
    }
    
    SetNativeString(2, g_StyleConfig[Style][Name], maxlength);
}

public Native_GetStyleAbbr(Handle:plugin, numParams)
{
    new Style     = GetNativeCell(1);
    new maxlength = GetNativeCell(3);
    
    if(Style == 0 && GetNativeCell(4) == true)
    {
        SetNativeString(2, "", maxlength);
        return;
    }
    
    SetNativeString(2, g_StyleConfig[Style][Name_Short], maxlength);
}
/*
public Native_GetStyleConfig(Handle:plugin, numParams)
{
	new Style = GetNativeCell(1);
	
	if(Style < g_TotalStyles)
	{
		SetNativeArray(2, g_StyleConfig[Style], StyleConfig);
		return true;
	}
	else
	{
		return false;
	}
}*/

public Native_Style_IsEnabled(Handle:plugin, numParams)
{
    // Return 'TempEnabled' value because styles can be dynamically changed, 'Enabled' holds the setting from the config always
    return g_StyleConfig[GetNativeCell(1)][TempEnabled];
}

public Native_Style_IsTypeAllowed(Handle:plugin, numParams)
{
    return g_StyleConfig[GetNativeCell(1)][AllowType][GetNativeCell(2)];
}

public Native_Style_IsFreestyleAllowed(Handle:plugin, numParams)
{
    return g_StyleConfig[GetNativeCell(1)][Freestyle];
}

public Native_Style_GetTotal(Handle:plugin, numParams)
{
    return g_TotalStyles;
}

public Native_Style_CanUseReplay(Handle:plugin, numParams)
{
    return g_StyleConfig[GetNativeCell(1)][Ghost_Use][GetNativeCell(2)];
}

public Native_Style_CanReplaySave(Handle:plugin, numParams)
{
    return g_StyleConfig[GetNativeCell(1)][Ghost_Save][GetNativeCell(2)];
}

public Native_GetClientTimerType(Handle:plugin, numParams)
{
    return g_Type[GetNativeCell(1)];
}

public Native_GetTypeStyleFromCommand(Handle:plugin, numParams)
{
    decl String:sCommand[64];
    GetCmdArg(0, sCommand, sizeof(sCommand));
    ReplaceStringEx(sCommand, sizeof(sCommand), "sm_", "");
    
    new DelimiterLen;
    GetNativeStringLength(1, DelimiterLen);
    
    decl String:sDelimiter[DelimiterLen + 1];
    GetNativeString(1, sDelimiter, DelimiterLen + 1);
    
    decl String:sTypeStyle[2][64];
    ExplodeString(sCommand, sDelimiter, sTypeStyle, 2, 64);
    
    if(StrEqual(sTypeStyle[0], ""))
    {
        SetNativeCellRef(2, TIMER_MAIN);
    }
    else if(StrEqual(sTypeStyle[0], "b"))
    {
        SetNativeCellRef(2, TIMER_BONUS);
    }
    else
    {
        return false;
    }
    
    for(new Style; Style < g_TotalStyles; Style++)
    {
        if(Style_IsEnabled(Style))
        {
            if(StrEqual(sTypeStyle[1], g_StyleConfig[Style][Name_Short]) || (Style == 0 && StrEqual(sTypeStyle[1], "")))
            {
                SetNativeCellRef(3, Style);
                return true;
            }
        }
    }
    
    return false;
}

public Native_GetButtons(Handle:plugin, numParams)
{
    return g_UnaffectedButtons[GetNativeCell(1)];
}

// Adds or updates a player's record on the map
DB_UpdateTime(client, Type, Style, Float:Time, Jumps, Strafes, Float:Sync, Float:Sync2)
{
    new PlayerID = GetPlayerID(client);
    if(PlayerID != 0)
    {
        if(!IsFakeClient(client))
        {
            new Handle:data = CreateDataPack();
            WritePackString(data, g_sMapName);
            WritePackCell(data, client);
            WritePackCell(data, PlayerID);
            WritePackCell(data, Type);
            WritePackCell(data, Style);
            WritePackFloat(data, Time);
            WritePackCell(data, Jumps);
            WritePackCell(data, Strafes);
            WritePackFloat(data, Sync);
            WritePackFloat(data, Sync2);
            
            decl String:query[256];
            Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d",
                g_sMapName,
                Type,
                Style,
                PlayerID);
            SQL_TQuery(g_DB, DB_UpdateTime_Callback1, query, data);
            
            // Get player position
            new iSize = GetArraySize(g_hTimes[Type][Style]), Position = -1;
            
            for(new idx = 0; idx < iSize; idx++)
            {
                if(GetArrayCell(g_hTimes[Type][Style], idx) == PlayerID)
                {
                    Position = idx;
                    break;
                }
            }
            
            // Remove existing time from array if position exists
            if(Position != -1)
            {
                RemoveFromArray(g_hTimes[Type][Style], Position);
                RemoveFromArray(g_hTimesUsers[Type][Style], Position);
            }
            
            iSize = GetArraySize(g_hTimes[Type][Style]);
            Position = -1;
            
            for(new idx = 0; idx < iSize; idx++)
            {
                if(Time < GetArrayCell(g_hTimes[Type][Style], idx, 1))
                {
                    Position = idx;
                    break;
                }
            }
            
            if(Position == -1)
                Position = iSize;
            
            if(Position >= iSize)
            {
                ResizeArray(g_hTimes[Type][Style], Position + 1);
                ResizeArray(g_hTimesUsers[Type][Style], Position + 1);
            }
            else
            {
                ShiftArrayUp(g_hTimes[Type][Style], Position);
                ShiftArrayUp(g_hTimesUsers[Type][Style], Position);
            }
                
            SetArrayCell(g_hTimes[Type][Style], Position, PlayerID, 0);
            SetArrayCell(g_hTimes[Type][Style], Position, Time, 1);
            
            decl String:sName[MAX_NAME_LENGTH];
            GetClientName(client, sName, sizeof(sName));
            SetArrayString(g_hTimesUsers[Type][Style], Position, sName);
            
            return Position + 1;
        }
    }
    
    return 0;
}

public DB_UpdateTime_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if(hndl != INVALID_HANDLE)
    {
        decl String:sMapName[64];
        
        ResetPack(data);
        ReadPackString(data, sMapName, sizeof(sMapName));
        ReadPackCell(data);
        new PlayerID     = ReadPackCell(data);
        new Type         = ReadPackCell(data);
        new Style        = ReadPackCell(data);
        new Float:Time   = ReadPackFloat(data);
        new Jumps        = ReadPackCell(data);
        new Strafes      = ReadPackCell(data);
        new Float:Sync   = ReadPackFloat(data);
        new Float:Sync2  = ReadPackFloat(data);
        
        decl String:query[512];
        Format(query, sizeof(query), "INSERT INTO times (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Points, Timestamp, Sync, SyncTwo) VALUES ((SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1), %d, %d, %d, %f, %d, %d, 0, %d, %f, %f)", 
            sMapName,
            Type,
            Style,
            PlayerID,
            Time,
            Jumps,
            Strafes,
            GetTime(),
            Sync,
            Sync2);
        SQL_TQuery(g_DB, DB_UpdateTime_Callback2, query, data);
    }
    else
    {
        CloseHandle(data);
        LogError(error);
    }
}

public DB_UpdateTime_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if(hndl != INVALID_HANDLE)
    {
        ResetPack(data);
        
        decl String:sMapName[64];
        ReadPackString(data, sMapName, sizeof(sMapName));
        ReadPackCell(data);
        ReadPackCell(data);
        new Type  = ReadPackCell(data);
        new Style = ReadPackCell(data);
        
        Call_StartForward(g_fwdOnTimesUpdated);
        Call_PushString(sMapName);
        Call_PushCell(Type);
        Call_PushCell(Style);
        Call_PushCell(g_hTimes[Type][Style]);
        Call_Finish();
        //DB_UpdateRanks(sMapName, Type, Style);
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(data);
}

// Opens a menu that displays the records on the given map
DB_DisplayRecords(client, String:sMapName[], Type, Style)
{
    new Handle:pack = CreateDataPack();
    WritePackCell(pack, client);
    WritePackCell(pack, Type);
    WritePackCell(pack, Style);
    WritePackString(pack, sMapName);
    
    decl String:query[512];
    Format(query, sizeof(query), "SELECT Time, User, Jumps, Strafes, Points, Timestamp, T.PlayerID, Sync, SyncTwo FROM times AS T JOIN players AS P ON T.PlayerID=P.PlayerID AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d ORDER BY Time, Timestamp",
        sMapName,
        Type,
        Style);
    SQL_TQuery(g_DB, DB_DisplayRecords_Callback1, query, pack);
}

public DB_DisplayRecords_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
    if(hndl != INVALID_HANDLE)
    {        
        ResetPack(data);
        new client = ReadPackCell(data);
        new Type   = ReadPackCell(data);
        new Style  = ReadPackCell(data);
        
        decl String:sMapName[64];
        ReadPackString(data, sMapName, sizeof(sMapName));
        
        new rowcount = SQL_GetRowCount(hndl);
        if(rowcount != 0)
        {    
            decl String:name[(MAX_NAME_LENGTH*2)+1], String:title[128], String:item[256], String:info[256], String:sTime[32];
            new Float:time, Float:points, jumps, strafes, timestamp, PlayerID, Float:ClientTime, MapRank, Float:Sync[2];
            
            new Handle:menu = CreateMenu(Menu_ServerRecord);    
            new RowCount = SQL_GetRowCount(hndl);
            for(new i = 1; i <= RowCount; i++)
            {
                SQL_FetchRow(hndl);
                time      = SQL_FetchFloat(hndl, 0);
                SQL_FetchString(hndl, 1, name, sizeof(name));
                jumps     = SQL_FetchInt(hndl, 2);
                FormatPlayerTime(time, sTime, sizeof(sTime), false, 1);
                strafes   = SQL_FetchInt(hndl, 3);
                points    = SQL_FetchFloat(hndl, 4);
                timestamp = SQL_FetchInt(hndl, 5);
                PlayerID  = SQL_FetchInt(hndl, 6);
                Sync[0]   = SQL_FetchFloat(hndl, 7);
                Sync[1]   = SQL_FetchFloat(hndl, 8);
                
                if(PlayerID == GetPlayerID(client))
                {
                    ClientTime    = time;
                    MapRank        = i;
                }
                
                Format(info, sizeof(info), "%d;%d;%d;%s;%.1f;%d;%d;%d;%d;%d;%s;%f;%f",
                    PlayerID,
                    Type,
                    Style,
                    sTime,
                    points,
                    i,
                    rowcount,
                    timestamp,
                    jumps,
                    strafes,
                    sMapName,
                    Sync[0],
                    Sync[1]);
                    
                Format(item, sizeof(item), "#%d: %s - %s",
                    i,
                    sTime,
                    name);
                
                if((i % 7) == 0 || i == RowCount)
                    Format(item, sizeof(item), "%s\n--------------------------------------", item);
                
                AddMenuItem(menu, info, item);
            }
            
            decl String:sType[32];
            GetTypeName(Type, sType, sizeof(sType));
            
            decl String:sStyle[32];
            GetStyleName(Style, sStyle, sizeof(sStyle));
            
            if(ClientTime != 0.0)
            {
                decl String:sClientTime[32];
                FormatPlayerTime(ClientTime, sClientTime, sizeof(sClientTime), false, 1);
                FormatEx(title, sizeof(title), "%s records [%s] - [%s]\n \nYour time: %s ( %d / %d )\n--------------------------------------",
                    sMapName,
                    sType,
                    sStyle,
                    sClientTime,
                    MapRank,
                    rowcount);
            }
            else
            {
                FormatEx(title, sizeof(title), "%s records [%s] - [%s]\n \n%d total\n--------------------------------------",
                    sMapName,
                    sType,
                    sStyle,
                    rowcount);
            }
            
            SetMenuTitle(menu, title);
            SetMenuExitButton(menu, true);
            DisplayMenu(menu, client, MENU_TIME_FOREVER);
        }
        else
        {
            if(Type == TIMER_MAIN)
                CPrintToChat(client, "%s%sNo one has beaten the map yet",
                    g_msg_start,
                    g_msg_textcol);
            else
                CPrintToChat(client, "%s%sNo one has beaten the bonus on this map yet.",
                    g_msg_start,
                    g_msg_textcol);
        }
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(data);
}

public Menu_ServerRecord(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        decl String:sInfo[256];
        GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
        
        ShowRecordInfo(param1, sInfo);
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

/*
PlayerID, 0
Type, 1
Style, 2
sTime, 3
points, 4
map rank, 5
total map ranks, 6
timestamp, 7
jumps, 8
strafes, 9
sMapName, 10
Sync[0], 11
Sync[1] 12
*/

ShowRecordInfo(client, const String:sInfo[256])
{
    decl String:sInfoExploded[13][64];
    ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
    
    new Handle:menu = CreateMenu(Menu_ShowRecordInfo);
    
    new PlayerID = StringToInt(sInfoExploded[0]);
    decl String:sName[MAX_NAME_LENGTH];
    GetNameFromPlayerID(PlayerID, sName, sizeof(sName));
    
    decl String:sTitle[256];
    FormatEx(sTitle, sizeof(sTitle), "Record details of %s\n \n", sName);
    
    Format(sTitle, sizeof(sTitle), "%sMap: %s\n \n", sTitle, sInfoExploded[10]);
    
    Format(sTitle, sizeof(sTitle), "%sTime: %s (%s / %s)\n \n", sTitle, sInfoExploded[3], sInfoExploded[5], sInfoExploded[6]);
    
    Format(sTitle, sizeof(sTitle), "%sPoints: %s\n \n", sTitle, sInfoExploded[4]);
    
    new Type = StringToInt(sInfoExploded[1]);
    decl String:sType[32];
    GetTypeName(Type, sType, sizeof(sType));
    
    new Style = StringToInt(sInfoExploded[2]);
    decl String:sStyle[32];
    GetStyleName(Style, sStyle, sizeof(sStyle));
    
    Format(sTitle, sizeof(sTitle), "%sTimer: %s\nStyle: %s\n \n", sTitle, sType, sStyle);
    
    if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
    {
        Format(sTitle, sizeof(sTitle), "%sJumps/Strafes: %s/%s\n \n", sTitle, sInfoExploded[8], sInfoExploded[9]);
    }
    else
    {
        Format(sTitle, sizeof(sTitle), "%sJumps: %s\n \n", sTitle, sInfoExploded[8]);
    }
    
    decl String:sTimeStamp[32];
    FormatTime(sTimeStamp, sizeof(sTimeStamp), "%x %X", StringToInt(sInfoExploded[7]));
    Format(sTitle, sizeof(sTitle), "%sDate: %s\n \n", sTitle, sTimeStamp);
    
    if(g_StyleConfig[Style][CalcSync])
    {
        if(g_bIsAdmin[client] == true)
        {
            Format(sTitle, sizeof(sTitle), "%sSync 1: %.3f%%\n", sTitle, StringToFloat(sInfoExploded[11]));
            Format(sTitle, sizeof(sTitle), "%sSync 2: %.3f%%\n \n", sTitle, StringToFloat(sInfoExploded[12]));
        }
        else
        {
            Format(sTitle, sizeof(sTitle), "%sSync: %.3f%%\n \n", sTitle, StringToFloat(sInfoExploded[11]));
        }
    }
    
    SetMenuTitle(menu, sTitle);
    
    decl String:sItemInfo[32];
    FormatEx(sItemInfo, sizeof(sItemInfo), "%d;%d;%d", PlayerID, Type, Style);
    
    AddMenuItem(menu, sItemInfo, "Show player stats");
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_ShowRecordInfo(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:sInfo[32];
        GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
        
        decl String:sInfoExploded[3][16];
        ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
        
        Timer_OpenStatsMenu(param1, StringToInt(sInfoExploded[0]), StringToInt(sInfoExploded[1]), StringToInt(sInfoExploded[2]));
    }
    if(action == MenuAction_End)
        CloseHandle(menu);
}

DB_ShowTimeAtRank(client, const String:MapName[], rank, Type, Style)
{        
    if(rank < 1)
    {
        CPrintToChat(client, "%s%s%d%s is not a valid rank.",
            g_msg_start,
            g_msg_varcol,
            rank,
            g_msg_textcol);
            
        return;
    }
    
    new Handle:pack = CreateDataPack();
    WritePackCell(pack, client);
    WritePackCell(pack, rank);
    WritePackCell(pack, Type);
    WritePackCell(pack, Style);
    
    decl String:query[512];
    Format(query, sizeof(query), "SELECT t2.User, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp FROM times AS t1, players AS t2 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1",
        MapName,
        Type,
        Style,
        rank-1);
    SQL_TQuery(g_DB, DB_ShowTimeAtRank_Callback1, query, pack);
}

public DB_ShowTimeAtRank_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
    if(hndl != INVALID_HANDLE)
    {        
        ResetPack(pack);
        new client = ReadPackCell(pack);
        ReadPackCell(pack);
        new Type   = ReadPackCell(pack);
        new Style  = ReadPackCell(pack);
        
        if(SQL_GetRowCount(hndl) == 1)
        {
            decl String:sUserName[MAX_NAME_LENGTH], String:sTimeStampDay[255], String:sTimeStampTime[255], String:sfTime[255];
            new Float:fTime, iJumps, iStrafes, Float:fPoints, iTimeStamp;
            
            SQL_FetchRow(hndl);
            
            SQL_FetchString(hndl, 0, sUserName, sizeof(sUserName));
            fTime      = SQL_FetchFloat(hndl, 1);
            iJumps     = SQL_FetchInt(hndl, 2);
            iStrafes   = SQL_FetchInt(hndl, 3);
            fPoints    = SQL_FetchFloat(hndl, 4);
            iTimeStamp = SQL_FetchInt(hndl, 5);
            
            FormatPlayerTime(fTime, sfTime, sizeof(sfTime), false, 1);
            FormatTime(sTimeStampDay, sizeof(sTimeStampDay), "%x", iTimeStamp);
            FormatTime(sTimeStampTime, sizeof(sTimeStampTime), "%X", iTimeStamp);
            
            decl String:sType[32];
            GetTypeName(Type, sType, sizeof(sType));
            
            decl String:sStyle[32];
            GetStyleName(Style, sStyle, sizeof(sStyle));
            
            if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
            {
                CPrintToChat(client, "%s%s[%s] %s-%s [%s] %s%s has time %s%s%s\n(%s%d%s jumps, %s%.1f%s points)\nDate: %s%s %s%s.",
                    g_msg_start,
                    g_msg_varcol,
                    sType,
                    g_msg_textcol,
                    g_msg_varcol,
                    sStyle,
                    sUserName,
                    g_msg_textcol,
                    g_msg_varcol,
                    sfTime,
                    g_msg_textcol,
                    g_msg_varcol,
                    iJumps,
                    g_msg_textcol,
                    g_msg_varcol,
                    fPoints,
                    g_msg_textcol,
                    g_msg_varcol,
                    sTimeStampDay,
                    sTimeStampTime,
                    g_msg_textcol);
            }
            else
            {
                CPrintToChat(client, "%s%s[%s] %s-%s [%s] %s%s has time %s%s%s\n(%s%d%s jumps, %s%d%s strafes, %s%.1f%s points)\nDate: %s%s %s%s.",
                    g_msg_start,
                    g_msg_varcol,
                    sType,
                    g_msg_textcol,
                    g_msg_varcol,
                    sStyle,
                    sUserName,
                    g_msg_textcol,
                    g_msg_varcol,
                    sfTime,
                    g_msg_textcol,
                    g_msg_varcol,
                    iJumps,
                    g_msg_textcol,
                    g_msg_varcol,
                    iStrafes,
                    g_msg_textcol,
                    g_msg_varcol,
                    fPoints,
                    g_msg_textcol,
                    g_msg_varcol,
                    sTimeStampDay,
                    sTimeStampTime,
                    g_msg_textcol);
            }
        }
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(pack);
}

DB_ShowTime(client, target, const String:MapName[], Type, Style)
{
    new Handle:pack = CreateDataPack();
    WritePackCell(pack, client);
    WritePackCell(pack, target);
    WritePackCell(pack, Type);
    WritePackCell(pack, Style);
    
    new PlayerID = GetPlayerID(target);
    
    decl String:query[800];
    FormatEx(query, sizeof(query), "SELECT (SELECT count(*) FROM times WHERE Time<=(SELECT Time FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d) AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Rank, (SELECT count(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Timescount, Time, Jumps, Strafes, Points, Timestamp FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d", 
        MapName, 
        Type, 
        Style, 
        PlayerID, 
        MapName, 
        Type, 
        Style, 
        MapName, 
        Type, 
        Style, 
        MapName, 
        Type, 
        Style, 
        PlayerID);    
    SQL_TQuery(g_DB, DB_ShowTime_Callback1, query, pack);
}

public DB_ShowTime_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
    if(hndl != INVALID_HANDLE)
    {
        ResetPack(pack);
        new client    = ReadPackCell(pack);
        new target    = ReadPackCell(pack);
        new Type        = ReadPackCell(pack);
        new Style     = ReadPackCell(pack);
        
        new TargetID = GetPlayerID(target);
        
        if(IsClientInGame(client) && IsClientInGame(target) && TargetID)
        {
            decl String:sTime[32], String:sDate[32], String:sDateDay[32], String:sName[MAX_NAME_LENGTH];
            GetClientName(target, sName, sizeof(sName));
            
            decl String:sType[32];
            GetTypeName(Type, sType, sizeof(sType));
            
            decl String:sStyle[32];
            GetStyleName(Style, sStyle, sizeof(sStyle));
            
            if(SQL_GetRowCount(hndl) == 1)
            {
                SQL_FetchRow(hndl);
                new Rank          = SQL_FetchInt(hndl, 0);
                new Timescount        = SQL_FetchInt(hndl, 1);
                new Float:Time      = SQL_FetchFloat(hndl, 2);
                new Jumps          = SQL_FetchInt(hndl, 3);
                new Strafes           = SQL_FetchInt(hndl, 4);
                new Float:Points      = SQL_FetchFloat(hndl, 5);
                new TimeStamp      = SQL_FetchInt(hndl, 6);
                
                FormatPlayerTime(Time, sTime, sizeof(sTime), false, 1);
                FormatTime(sDate, sizeof(sDate), "%x", TimeStamp);
                FormatTime(sDateDay, sizeof(sDateDay), "%X", TimeStamp);
                
                if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
                {
                    CPrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas time %s%s%s (%s%d%s / %s%d%s)",
                        g_msg_start,
                        g_msg_varcol,
                        sType,
                        g_msg_textcol,
                        g_msg_varcol,
                        sStyle,
                        sName,
                        g_msg_textcol,
                        g_msg_varcol,
                        sTime,
                        g_msg_textcol,
                        g_msg_varcol,
                        Rank,
                        g_msg_textcol,
                        g_msg_varcol,
                        Timescount,
                        g_msg_textcol);
                    
                    CPrintToChat(client, "%sDate: %s%s %s",
                        g_msg_textcol,
                        g_msg_varcol,
                        sDate,
                        sDateDay);
                    
                    CPrintToChat(client, "%s(%s%d%s jumps, %s%d%s strafes, and %s%4.1f%s points)",
                        g_msg_textcol,
                        g_msg_varcol,
                        Jumps,
                        g_msg_textcol,
                        g_msg_varcol,
                        Strafes,
                        g_msg_textcol,
                        g_msg_varcol,
                        Points,
                        g_msg_textcol);
                }
                else
                {
                    CPrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas time %s%s%s (%s%d%s / %s%d%s)",
                        g_msg_start,
                        g_msg_varcol,
                        sType,
                        g_msg_textcol,
                        g_msg_varcol,
                        sStyle,
                        sName,
                        g_msg_textcol,
                        g_msg_varcol,
                        sTime,
                        g_msg_textcol,
                        g_msg_varcol,
                        Rank,
                        g_msg_textcol,
                        g_msg_varcol,
                        Timescount,
                        g_msg_textcol);
                    
                    CPrintToChat(client, "%sDate: %s%s %s",
                        g_msg_textcol,
                        g_msg_varcol,
                        sDate,
                        sDateDay);
                    
                    CPrintToChat(client, "%s(%s%d%s jumps and %s%4.1f%s points)",
                        g_msg_textcol,
                        g_msg_varcol,
                        Jumps,
                        g_msg_textcol,
                        g_msg_varcol,
                        Points,
                        g_msg_textcol);
                }
            }
            else
            {
                if(GetPlayerID(client) != TargetID)
                {
                    CPrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas no time on the map.",
                        g_msg_start,
                        g_msg_varcol,
                        sType,
                        g_msg_textcol,
                        g_msg_varcol,
                        sStyle,
                        sName,
                        g_msg_textcol);
                }
                else
                    CPrintToChat(client, "%s%s[%s] %s-%s [%s] %sYou have no time on the map.",
                        g_msg_start,
                        g_msg_varcol,
                        sType,
                        g_msg_textcol,
                        g_msg_varcol,
                        sStyle,
                        g_msg_textcol);
            }
        }
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(pack);
}

DB_DeleteRecord(client, Type, Style, RecordOne, RecordTwo)
{
    new Handle:data = CreateDataPack();
    WritePackCell(data, client);
    WritePackCell(data, Type);
    WritePackCell(data, Style);
    WritePackCell(data, RecordOne);
    WritePackCell(data, RecordTwo);
    
    decl String:query[512];
    Format(query, sizeof(query), "SELECT COUNT(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d",
        g_sMapName,
        Type,
        Style);
    SQL_TQuery(g_DB, DB_DeleteRecord_Callback1, query, data);
}

public DB_DeleteRecord_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
    if(hndl != INVALID_HANDLE)
    {
        ResetPack(data);
        new client        = ReadPackCell(data);
        new Type          = ReadPackCell(data);
        new Style            = ReadPackCell(data);
        new RecordOne     = ReadPackCell(data);
        new RecordTwo     = ReadPackCell(data);
        
        SQL_FetchRow(hndl);
        new timesCount = SQL_FetchInt(hndl, 0);
        
        decl String:sInfo[32];
        if(Type == TIMER_BONUS)
        {
            GetTypeName(Type, sInfo, sizeof(sInfo), true);
            StringToUpper(sInfo);
            Format(sInfo, sizeof(sInfo), "[%s] ", sInfo);
        }
        else if(Style != 0)
        {
            GetStyleName(Style, sInfo, sizeof(sInfo), true);
            StringToUpper(sInfo);
            Format(sInfo, sizeof(sInfo), "[%s] ", sInfo);
        }
        
        if(RecordTwo > timesCount)
        {
            CPrintToChat(client, "%s%s%s%sThere is no record %s%d%s.", 
                g_msg_start,
                g_msg_varcol,
                sInfo, 
                g_msg_textcol,
                g_msg_varcol,
                RecordTwo,
                g_msg_textcol);
                
            PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
            
            return;
        }
        if(RecordOne < 1)
        {
            CPrintToChat(client, "%s%sThe minimum record number is 1.",
                g_msg_start,
                g_msg_textcol);
                
            PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
            
            return;
        }
        if(RecordOne > RecordTwo)
        {
            CPrintToChat(client, "%s%sRecord 1 can't be larger than record 2.",
                g_msg_start,
                g_msg_textcol);
                
            PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
            
            return;
        }
        
        decl String:query[700];
        Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND Time BETWEEN (SELECT t1.Time FROM (SELECT * FROM times) AS t1 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1) AND (SELECT t2.Time FROM (SELECT * FROM times) AS t2 WHERE t2.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t2.Type=%d AND t2.Style=%d ORDER BY t2.Time LIMIT %d, 1)",
            g_sMapName,
            Type,
            Style,
            g_sMapName,
            Type,
            Style,
            RecordOne-1,
            g_sMapName,
            Type,
            Style,
            RecordTwo-1);
        SQL_TQuery(g_DB, DB_DeleteRecord_Callback2, query, data);
    }
    else
    {
        CloseHandle(data);
        LogError(error);
    }
}

public DB_DeleteRecord_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
    if(hndl != INVALID_HANDLE)
    {
        ResetPack(data);
        ReadPackCell(data);
        new Type      = ReadPackCell(data);
        new Style     = ReadPackCell(data);
        new RecordOne = ReadPackCell(data);
        new RecordTwo = ReadPackCell(data);
        
        new PlayerID;
        for(new client = 1; client <= MaxClients; client++)
        {
            PlayerID = GetPlayerID(client);
            if(GetPlayerID(client) != 0 && IsClientInGame(client))
            {
                for(new idx = RecordOne - 1; idx < RecordTwo; idx++)
                {
                    if(GetArrayCell(g_hTimes[Type][Style], idx, 0) == PlayerID)
                    {
                        g_fTime[client][Type][Style] = 0.0;
                        Format(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "Best: N/A");
                    }
                }
            }
        }
        
        // Start the OnTimesDeleted forward
        Call_StartForward(g_fwdOnTimesDeleted);
        Call_PushCell(Type);
        Call_PushCell(Style);
        Call_PushCell(RecordOne);
        Call_PushCell(RecordTwo);
        Call_PushCell(g_hTimes[Type][Style]);
        Call_Finish();
        
        // Reload the times because some were deleted
        DB_LoadTimes(false);
    }
    else
    {
        LogError(error);
    }
    
    CloseHandle(data);
}

DB_LoadTimes(bool:FirstTime)
{    
    #if defined DEBUG
        LogMessage("Attempting to load map times");
    #endif
    
    decl String:query[512];
    Format(query, sizeof(query), "SELECT t1.rownum, t1.MapID, t1.Type, t1.Style, t1.PlayerID, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp, t2.User FROM times AS t1, players AS t2 WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID ORDER BY t1.Type, t1.Style, t1.Time, t1.Timestamp",
        g_sMapName);
        
    new    Handle:pack = CreateDataPack();
    WritePackCell(pack, FirstTime);
    WritePackString(pack, g_sMapName);
    
    SQL_TQuery(g_DB, LoadTimes_Callback, query, pack);
}

public LoadTimes_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
    if(hndl != INVALID_HANDLE)
    {
        #if defined DEBUG
            LogMessage("Loading times successful");
        #endif
        
        ResetPack(pack);
        new    bool:FirstTime = bool:ReadPackCell(pack);
        
        decl String:sMapName[64];
        ReadPackString(pack, sMapName, sizeof(sMapName));
        
        if(StrEqual(g_sMapName, sMapName))
        {
            for(new Type; Type < MAX_TYPES; Type++)
            {
                for(new Style; Style < g_TotalStyles; Style++)
                {
                    ClearArray(g_hTimes[Type][Style]);
                    ClearArray(g_hTimesUsers[Type][Style]);
                }
            }
            
            new rows = SQL_GetRowCount(hndl), Type, Style, iSize, String:sUser[MAX_NAME_LENGTH];
            for(new i = 0; i < rows; i++)
            {
                SQL_FetchRow(hndl);
                
                Type  = SQL_FetchInt(hndl, SQL_Column_Type);
                Style = SQL_FetchInt(hndl, SQL_Column_Style);
                
                iSize = GetArraySize(g_hTimes[Type][Style]);
                ResizeArray(g_hTimes[Type][Style], iSize + 1);
                
                SetArrayCell(g_hTimes[Type][Style], iSize, SQL_FetchInt(hndl, SQL_Column_PlayerID), 0);
                
                SetArrayCell(g_hTimes[Type][Style], iSize, SQL_FetchFloat(hndl, SQL_Column_Time), 1);
                
                SQL_FetchString(hndl, 10, sUser, sizeof(sUser));
                PushArrayString(g_hTimesUsers[Type][Style], sUser);
            }
            
            LoadServerRecordInfo();
            
            g_bTimesAreLoaded  = true;
            
            Call_StartForward(g_fwdOnTimesLoaded);
            Call_Finish();
            
            if(FirstTime)
            {
                for(new client = 1; client <= MaxClients; client++)
                {
                    DB_LoadPlayerInfo(client);
                }
            }
        }
    }
    else
    {
        LogError(error);
    }
}

LoadServerRecordInfo()
{
    decl String:sUser[MAX_NAME_LENGTH], String:sStyleAbbr[8], String:sTypeAbbr[8], iSize;
    
    for(new Type; Type < MAX_TYPES; Type++)
    {
        GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
        StringToUpper(sTypeAbbr);
        
        for(new Style; Style < MAX_STYLES; Style++)
        {
            if(g_StyleConfig[Style][AllowType][Type])
            {
                GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
                StringToUpper(sStyleAbbr);
                
                iSize = GetArraySize(g_hTimes[Type][Style]);
                if(iSize > 0)
                {
                    g_ServerRecord[Type][Style] = GetArrayCell(g_hTimes[Type][Style], 0, 1);
                    
                    FormatPlayerTime(g_ServerRecord[Type][Style], g_sRecord[Type][Style], sizeof(g_sRecord[][]), false, 1);
                    
                    GetArrayString(g_hTimesUsers[Type][Style], 0, sUser, MAX_NAME_LENGTH);
                    
                    Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%sSR%s: %s", sTypeAbbr, sStyleAbbr, g_sRecord[Type][Style]);
                }
                else
                {
                    g_ServerRecord[Type][Style] = 0.0;
                    
                    Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%sSR%s: No record", sTypeAbbr, sStyleAbbr);
                }
            }
        }
    }
}

VectorAngles(Float:vel[3], Float:angles[3])
{
    new Float:tmp, Float:yaw, Float:pitch;
    
    if (vel[1] == 0 && vel[0] == 0)
    {
        yaw = 0.0;
        if (vel[2] > 0)
            pitch = 270.0;
        else
            pitch = 90.0;
    }
    else
    {
        yaw = (ArcTangent2(vel[1], vel[0]) * (180 / 3.141593));
        if (yaw < 0)
            yaw += 360;

        tmp = SquareRoot(vel[0]*vel[0] + vel[1]*vel[1]);
        pitch = (ArcTangent2(-vel[2], tmp) * (180 / 3.141593));
        if (pitch < 0)
            pitch += 360;
    }
    
    angles[0] = pitch;
    angles[1] = yaw;
    angles[2] = 0.0;
}

GetDirection(client)
{
    new Float:vVel[3];
    Entity_GetAbsVelocity(client, vVel);
    
    new Float:vAngles[3];
    GetClientEyeAngles(client, vAngles);
    new Float:fTempAngle = vAngles[1];

    VectorAngles(vVel, vAngles);

    if(fTempAngle < 0)
        fTempAngle += 360;

    new Float:fTempAngle2 = fTempAngle - vAngles[1];

    if(fTempAngle2 < 0)
        fTempAngle2 = -fTempAngle2;
    
    if(fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
        return 1; // Forwards
    if(fTempAngle2 > 22.5 && fTempAngle2 < 67.5 || fTempAngle2 > 292.5 && fTempAngle2 < 337.5 )
        return 2; // Half-sideways
    if(fTempAngle2 > 67.5 && fTempAngle2 < 112.5 || fTempAngle2 > 247.5 && fTempAngle2 < 292.5)
        return 3; // Sideways
    if(fTempAngle2 > 112.5 && fTempAngle2 < 157.5 || fTempAngle2 > 202.5 && fTempAngle2 < 247.5)
        return 4; // Backwards Half-sideways
    if(fTempAngle2 > 157.5 && fTempAngle2 < 202.5)
        return 5; // Backwards
    
    return 0; // Unknown
}

CheckSync(client, buttons, Float:vel[3], Float:angles[3])
{
	new Direction = GetDirection(client);
	
	new flags = GetEntityFlags(client);
	new MoveType:movetype = GetEntityMoveType(client);
	
	if(GetClientVelocity(client, true, true, false) != 0)
	{    
		if(!(flags & (FL_ONGROUND|FL_INWATER)) && (movetype != MOVETYPE_LADDER))
		{
			// Normalize difference
			new Float:fAngleDiff = angles[1] - g_fOldAngle[client];
			if (fAngleDiff > 180)
				fAngleDiff -= 360;
			else if(fAngleDiff < -180)
				fAngleDiff += 360;
			
			// Add to good sync if client buttons match up
			//Too Hardcode
			if(Direction == 1)
			{
				if(fAngleDiff > 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
					{
						g_goodSync[client]++;
					}
					if(vel[1] < 0)
					{
						g_goodSyncVel[client]++;
					}
				}
				else if(fAngleDiff < 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT))
					{
						g_goodSync[client]++;
					}
					if(vel[1] > 0)
					{
						g_goodSyncVel[client]++;
					}
				}
			}
			else if(Direction == 2)
			{
				if(fAngleDiff > 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_FORWARD) && (buttons & IN_MOVELEFT)&& !(buttons & IN_MOVERIGHT))
					{
						g_goodSync[client]++;
					}
					if(vel[0] < 0 && vel[1] < 0)
					{
						g_goodSyncVel[client]++;
					}
				}
				else if(fAngleDiff < 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_FORWARD) && (buttons & IN_MOVERIGHT)&& !(buttons & IN_MOVELEFT))
					{
						g_goodSync[client]++;
					}
					if(vel[0] > 0 && vel[1] > 0)
					{
						g_goodSyncVel[client]++;
					}
				}
			}
			else if(Direction == 3)
			{
				if(fAngleDiff > 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_FORWARD) && !(buttons & IN_BACK))
					{
						g_goodSync[client]++;
					}
					if(vel[0] < 0)
					{
						g_goodSyncVel[client]++;
					}
				}
				else if(fAngleDiff < 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_BACK) && !(buttons & IN_FORWARD))
					{
						g_goodSync[client]++;
					}
					if(vel[0] > 0)
					{
						g_goodSyncVel[client]++;
					}
				}
			}
			else if(Direction == 5)
			{
				if(fAngleDiff > 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT))
					{
						g_goodSync[client]++;
					}
					if(vel[1] < 0)
					{
						g_goodSyncVel[client]++;
					}
				}
				else if(fAngleDiff < 0)
				{
					g_totalSync[client]++;
					if((buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
					{
						g_goodSync[client]++;
					}
					if(vel[1] > 0)
					{
						g_goodSyncVel[client]++;
					}
				}
			}
		}
	}
	
	g_fOldAngle[client] = angles[1];
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    g_UnaffectedButtons[client] = buttons;
    
    if(IsPlayerAlive(client))
    {
        new Style = g_Style[client][g_Type[client]];
        
        // Key restriction
        new bool:bRestrict;
        
        if(!(GetEntityFlags(client) & FL_ONGROUND))
        {
	        if(g_StyleConfig[Style][Prevent_Left] && vel[1] < 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Prevent_Right] && vel[1] > 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Prevent_Back] && vel[0] < 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Prevent_Forward] && vel[0] > 0)
	            bRestrict = true;
	        
	        if(g_StyleConfig[Style][Require_Left] && vel[1] >= 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Require_Right] && vel[1] <= 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Require_Back] && vel[0] >= 0)
	            bRestrict = true;
	        if(g_StyleConfig[Style][Require_Forward] && vel[0] <= 0)
	            bRestrict = true;
        }
        
        
        if(g_StyleConfig[Style][Special])
        {
            if(StrEqual(g_StyleConfig[Style][Special_Key], "hsw"))
            {
                if(vel[0] > 0 && vel[1] != 0)
                    g_HSWCounter[client] = GetEngineTime();
                
                if(((GetEngineTime() - g_HSWCounter[client] > 0.4) || vel[0] <= 0) && !(GetEntityFlags(client) & FL_ONGROUND))
                {
                    bRestrict = true;
                }
            }
            else if (StrEqual(g_StyleConfig[Style][Special_Key], "surfhsw-aw-sd", true))
            {
                if((vel[0] > 0.0 && vel[1] < 0.0) || (vel[0] < 0.0 && vel[1] > 0.0)) // If pressing w and a or s and d, keep unrestricted
                {
                    g_HSWCounter[client] = GetEngineTime();
                }
                else if(GetEngineTime() - g_HSWCounter[client] > 0.3) // Restrict if player hasn't held the right buttons for too long
                {
                    bRestrict = true;
                }
            }
            else if (StrEqual(g_StyleConfig[Style][Special_Key], "surfhsw-as-wd", true))
            {
                if ((vel[0] < 0.0 && vel[1] < 0.0) || (vel[0] > 0.0 && vel[1] > 0.0))
                {
                    g_HSWCounter[client] = GetEngineTime();
                }
                else if(GetEngineTime() - g_HSWCounter[client] > 0.3)
                {
                    bRestrict = true;
                }
            }
            else if (StrEqual(g_StyleConfig[Style][Special_Key], "backward", true)) //Credit to Mehis
            {
            	if(!(GetEntityFlags(client) & FL_ONGROUND))
            	{
                    decl Float:eyeangle[3];
                    decl Float:velocity[3];
                
                    GetClientEyeAngles( client, eyeangle );
                
                    eyeangle[0] = Cosine( DegToRad( eyeangle[1] ) );
                    eyeangle[1] = Sine( DegToRad( eyeangle[1] ) );
                    eyeangle[2] = 0.0;
                
                    GetEntPropVector( client, Prop_Data, "m_vecVelocity", velocity );
                
                    velocity[2] = 0.0;
                
                    float len = SquareRoot( velocity[0] * velocity[0] + velocity[1] * velocity[1] );
    
                    velocity[0] /= len;
                    velocity[1] /= len;
                
                    float val = GetVectorDotProduct( eyeangle, velocity );
                
                    if ( val > -0.8 )
                    {
                        bRestrict = true;
                    }
                }
            }
        }
        
        if(g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_Unrestrict])
            if(Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1)
                bRestrict = false;
            
        if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
            bRestrict = false;
        
        if(bRestrict == true)
        {
            if(!(GetEntityFlags(client) & FL_ATCONTROLS))
                SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
        }
        else
        {
            if(GetEntityFlags(client) & FL_ATCONTROLS)
                SetEntityFlags(client, GetEntityFlags(client) &  ~FL_ATCONTROLS);
        }
        
        // Count strafes
        if((GetEntityMoveType(client) != MOVETYPE_NOCLIP) || !(GetEntityFlags(client) & FL_ONGROUND))
        {
	        if(g_StyleConfig[Style][Count_Left_Strafe] && !(g_Buttons[client] & IN_MOVELEFT) && (buttons & IN_MOVELEFT))
	            g_Strafes[client]++;
	        if(g_StyleConfig[Style][Count_Right_Strafe] && !(g_Buttons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
	            g_Strafes[client]++;
	        if(g_StyleConfig[Style][Count_Back_Strafe] && !(g_Buttons[client] & IN_BACK) && (buttons & IN_BACK))
	            g_Strafes[client]++;
	        if(g_StyleConfig[Style][Count_Forward_Strafe] && !(g_Buttons[client] & IN_FORWARD) && (buttons & IN_FORWARD))
	            g_Strafes[client]++;
        }
        
        
        // Calculate sync
        if(g_StyleConfig[Style][CalcSync] == true)
        {
            CheckSync(client, buttons, vel, angles);
        }
        
        // Check gravity
        if(g_StyleConfig[Style][Gravity] != 0.0)
        {
            if(GetEntityGravity(client) == 0.0)
            {
                SetEntityGravity(client, g_StyleConfig[Style][Gravity]);
            }
        }
            
        if(g_bTiming[client] == true)
        {
            // Anti - +left/+right
            if(GetConVarBool(g_hAllowYawspeed) == false)
            {
                if(buttons & (IN_LEFT|IN_RIGHT))
                {
                    StopTimer(client);
                    
                    if(Timer_InsideZone(client, MAIN_START, -1) == -1 && Timer_InsideZone(client, BONUS_START, -1) == -1)
                    {
                        CPrintToChat(client, "%s%sYour timer was stopped for using +left/+right",
                            g_msg_start,
                            g_msg_textcol);
                    }
                }
            }
            
            if((vel[0] > 0.0 && (buttons & IN_FORWARD) == 0) || (vel[0] < 0.0 && (buttons & IN_BACK) == 0) ||
            (vel[1] > 0.0 && (buttons & IN_MOVERIGHT) == 0) || (vel[1] < 0.0 && (buttons & IN_MOVELEFT) == 0))
            {
                StopTimer(client);
            }
            
            if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
            {
                StopTimer(client);
            }
            
            // Pausing
            if(g_bPaused[client] == true)
            {
                if(GetEntityMoveType(client) == MOVETYPE_WALK)
                {
                    SetEntityMoveType(client, MOVETYPE_NONE);
                }
            }
            else
            {
                if(GetEntityMoveType(client) == MOVETYPE_NONE)
                {
                    SetEntityMoveType(client, MOVETYPE_WALK);
                }
            }
            
            g_fCurrentTime[client] += GetTickInterval();
        }
        
        // auto bhop check
        if(g_bAllowAuto)
        {
        	
            JumpButtonsFix[client] = bool:(buttons & IN_JUMP);
        	
            if(g_ConVar_Autobunnyhopping == null)
            {
                return;
            }

            g_ConVar_Autobunnyhopping.BoolValue = (g_StyleConfig[Style][Auto] || (g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_Auto] && Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1));
        }
        
        if(g_bJumpInStartZone == false)
        {
            if(Timer_InsideZone(client, MAIN_START, -1) != -1 || Timer_InsideZone(client, BONUS_START, -1) != -1)
            {
                buttons &= ~IN_JUMP;
            }
        }
    }
    
    g_Buttons[client] = buttons;
}

stock bool IsSpammingCommand( int client , float warningtime)
{
	if (g_flNextSpammingTime[client] > GetEngineTime())
	{
		return g_bIsSpamming[client] = true;
	}
	
	g_flNextSpammingTime[client] = GetEngineTime() + warningtime;
	
	return g_bIsSpamming[client] = false;
}

stock FakePrecacheSound( const String:szPath[] )
{
	AddToStringTable( FindStringTable( "soundprecache" ), szPath );
}
