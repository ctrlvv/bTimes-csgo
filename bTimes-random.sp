#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
    name = "[bTimes] Random",
    author = "blacky",
    description = "Handles events and modifies them to fit bTimes' needs",
    version = VERSION,
    url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <bTimes-timer>
#include <bTimes-zones>
#include <bTimes-random>
#include <clientprefs>

/*
#undef REQUIRE_PLUGIN
#include <bTimes-gunjump>
*/

#define HUD_OFF (1<<0|1<<3|1<<4|1<<8)
#define HUD_ON  0
#define HUD_FUCK (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9|1<<10|1<<11)
 
new    g_Settings[MAXPLAYERS+1] = {AUTO_BHOP},
    bool:g_bHooked;
    
new     Float:g_fMapStart;
    
new     Handle:g_hSettingsCookie;

new     g_iSoundEnts[2048];
new     g_iNumSounds;

// Settings
new     Handle:g_hAllowKnifeDrop,
    Handle:g_WeaponDespawn,
    Handle:g_hNoDamage,
    Handle:g_HideChatTriggers,
    Handle:g_hAllowHide;
    
new    Handle:g_MessageStart,
    Handle:g_MessageVar,
    Handle:g_MessageText,
    Handle:g_fwdChatChanged;
    
new     String:g_msg_start[128] = {""};
new     String:g_msg_varcol[128] = {"\x07B4D398"};
new     String:g_msg_textcol[128] = {"\x01"};

//new bool:g_TimerGunJump;

public OnPluginStart()
{
    // Server settings
    g_hAllowKnifeDrop  = CreateConVar("timer_allowknifedrop", "1", "Allows players to drop any weapons (including knives and grenades)", 0, true, 0.0, true, 1.0);
    g_WeaponDespawn    = CreateConVar("timer_weapondespawn", "1", "Kills weapons a second after spawning to prevent flooding server.", 0, true, 0.0, true, 1.0);
    g_hNoDamage        = CreateConVar("timer_nodamage", "1", "Blocks all player damage when on", 0, true, 0.0, true, 1.0);
    g_hAllowHide       = CreateConVar("timer_allowhide", "1", "Allows players to use the !hide command", 0, true, 0.0, true, 1.0);
    
    g_HideChatTriggers	= CreateConVar("timer_hidechatcmds", "1", "Hide any chat triggers", 0, true, 0.0, true, 1.0);

    g_MessageStart     = CreateConVar("timer_msgstart", "{default}[ {green}Timer{default} ] - ", "Sets the start of all timer messages. (Always keep the ^A after the first color code)");
    g_MessageVar       = CreateConVar("timer_msgvar", "{lightblue}", "Sets the color of variables in timer messages such as player names.");
    g_MessageText      = CreateConVar("timer_msgtext", "{grey}", "Sets the color of general text in timer messages.");
    
    // Hook specific convars
    HookConVarChange(g_MessageStart, OnMessageStartChanged);
    HookConVarChange(g_MessageVar, OnMessageVarChanged);
    HookConVarChange(g_MessageText, OnMessageTextChanged);
    HookConVarChange(g_hNoDamage, OnNoDamageChanged);
    HookConVarChange(g_hAllowHide, OnAllowHideChanged);
    
    // Create config file if it doesn't exist
    AutoExecConfig(true, "random", "timer");
    
    // Event hooks
    //HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    AddNormalSoundHook(NormalSHook);
    AddAmbientSoundHook(AmbientSHook);
    AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
    
    AddCommandListener(DropItem, "drop");
    AddCommandListener(HookPlayerChat, "say");
    AddCommandListener(HookPlayerChat, "say_team");
    AddCommandListener(Command_Jointeam, "jointeam");

    AddCommandListener( Command_Radio, "radio1" );
    AddCommandListener( Command_Radio, "radio2" );
    AddCommandListener( Command_Radio, "radio3" );
    
    AddCommandListener( Command_Radio, "coverme" );
    AddCommandListener( Command_Radio, "enemydown" );
    AddCommandListener( Command_Radio, "enemyspot" );
    AddCommandListener( Command_Radio, "fallback" );
    AddCommandListener( Command_Radio, "followme" );
    AddCommandListener( Command_Radio, "getout" );
    AddCommandListener( Command_Radio, "go" );
    AddCommandListener( Command_Radio, "holdpos" );
    AddCommandListener( Command_Radio, "inposition" );
    AddCommandListener( Command_Radio, "needbackup" );
    AddCommandListener( Command_Radio, "negative" );
    AddCommandListener( Command_Radio, "regroup" );
    AddCommandListener( Command_Radio, "report" );
    AddCommandListener( Command_Radio, "reportingin" );
    AddCommandListener( Command_Radio, "roger" );
    AddCommandListener( Command_Radio, "sectorclear" );
    AddCommandListener( Command_Radio, "sticktog" );
    AddCommandListener( Command_Radio, "stormfront" );
    AddCommandListener( Command_Radio, "takepoint" );
    AddCommandListener( Command_Radio, "takingfire" );
    
    AddCommandListener( Command_Radio, "cheer" );
    AddCommandListener( Command_Radio, "compliment" );
    AddCommandListener( Command_Radio, "thanks" );

    RegConsoleCmdEx("sm_hide", SM_Hide, "Toggles hide");
    RegConsoleCmdEx("sm_hidewep", SM_Hidewep, "Toogles hide weapon");
    RegConsoleCmdEx("sm_spec", SM_Spec, "Be a spectator");
    RegConsoleCmdEx("sm_spectate", SM_Spec, "Be a spectator");
    RegConsoleCmdEx("sm_maptime", SM_Maptime, "Shows how long the current map has been on.");
    RegConsoleCmdEx("sm_sound", SM_Sound, "Choose different sounds to stop when they play.");
    RegConsoleCmdEx("sm_sounds", SM_Sound, "Choose different sounds to stop when they play.");
    RegConsoleCmdEx("sm_specinfo", SM_Specinfo, "Shows who is spectating you.");
    RegConsoleCmdEx("sm_specs", SM_Specinfo, "Shows who is spectating you.");
    RegConsoleCmdEx("sm_speclist", SM_Specinfo, "Shows who is spectating you.");
    RegConsoleCmdEx("sm_spectators", SM_Specinfo, "Shows who is spectating you.");
    RegConsoleCmdEx("sm_normalspeed", SM_Normalspeed, "Sets your speed to normal speed.");
    RegConsoleCmdEx("sm_speed", SM_Speed, "Changes your speed to the specified value.");
    RegConsoleCmdEx("sm_setspeed", SM_Speed, "Changes your speed to the specified value.");
    RegConsoleCmdEx("sm_slow", SM_Slow, "Sets your speed to slow (0.5)");
    RegConsoleCmdEx("sm_fast", SM_Fast, "Sets your speed to fast (2.0)");
    RegConsoleCmdEx("sm_lowgrav", SM_Lowgrav, "Lowers your gravity.");
    RegConsoleCmdEx("sm_normalgrav", SM_Normalgrav, "Sets your gravity to normal.");
    
    // Admin commands
    RegAdminCmd("sm_hudfuck", SM_Hudfuck, ADMFLAG_GENERIC, "Removes a player's hud so they can only leave the server/game through task manager (Use only on players who deserve it)");
    
    // Client settings
    g_hSettingsCookie = RegClientCookie("timer", "Timer settings", CookieAccess_Public);
    
    // Makes FindTarget() work properly..
    LoadTranslations("common.phrases");
    
    AddTempEntHook("EffectDispatch", TE_OnEffectDispatch);
    AddTempEntHook("World Decal", TE_OnWorldDecal);

}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Native functions
    CreateNative("GetClientSettings", Native_GetClientSettings);
    CreateNative("SetClientSettings", Native_SetClientSettings);
    
    // Forwards
    g_fwdChatChanged = CreateGlobalForward("OnTimerChatChanged", ET_Event, Param_Cell, Param_String);
    
    return APLRes_Success;
}

public OnMapStart()
{
    //set map start time
    ServerCommand("mp_restartgame 1");
    g_fMapStart = GetEngineTime();
}

public OnClientPutInServer(client)
{
    // for !hide
    if(GetConVarBool(g_hAllowHide))
    {
        SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
    }
    
    // prevents damage
    if(GetConVarBool(g_hNoDamage))
    {
        SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
    }
    
    SDKHook(client, SDKHook_WeaponDrop, Hook_OnWeaponDrop);
    
}

public OnNoDamageChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            if(newValue[0] == '0')
            {
                SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
            }
            else
            {
                SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
            }
        }
    }
}

public OnAllowHideChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{    
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            if(newValue[0] == '0')
            {
                SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
            }
            else
            {
                SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
            }
        }
    }
}

public OnClientDisconnect_Post(client)
{
    CheckHooks();
}

public OnClientCookiesCached(client)
{    
    // get client settings
    decl String:cookies[16];
    GetClientCookie(client, g_hSettingsCookie, cookies, sizeof(cookies));
    
    if(strlen(cookies) == 0)
    {
        g_Settings[client] = AUTO_BHOP;
    }
    else
    {
        g_Settings[client] = StringToInt(cookies);
    }
    
    
    if((g_Settings[client] & STOP_GUNS) && g_bHooked == false)
    {
        g_bHooked = true;
    }
}

public OnConfigsExecuted()
{
    // load timer message colors
    GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(0);
    Call_PushString(g_msg_start);
    Call_Finish();
    
    GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(1);
    Call_PushString(g_msg_varcol);
    Call_Finish();
    
    GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(2);
    Call_PushString(g_msg_textcol);
    Call_Finish();
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

public OnMessageStartChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(0);
    Call_PushString(g_msg_start);
    Call_Finish();
}

public OnMessageVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(1);
    Call_PushString(g_msg_varcol);
    Call_Finish();
}

public OnMessageTextChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
    Call_StartForward(g_fwdChatChanged);
    Call_PushCell(2);
    Call_PushString(g_msg_textcol);
    Call_Finish();
}

public Action:Timer_StopMusic(Handle:timer, any:data)
{
    new ientity, String:sSound[128];
    for (new i = 0; i < g_iNumSounds; i++)
    {
        ientity = EntRefToEntIndex(g_iSoundEnts[i]);
        
        if (ientity != INVALID_ENT_REFERENCE)
        {
            for(new client=1; client<=MaxClients; client++)
            {
                if(IsClientInGame(client))
                {
                    if(g_Settings[client] & STOP_MUSIC)
                    {
                        GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
                        EmitSoundToClient(client, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
                    }
                }
            }
        }
    }
}

// Credits to GoD-Tony for everything related to stopping gun sounds
public Action:CSS_Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay)
{
    if(!g_bHooked)
        return Plugin_Continue;
    
    // Check which clients need to be excluded.
    decl newClients[MaxClients], client, i;
    new newTotal = 0;
    
    for (i = 0; i < numClients; i++)
    {
        client = Players[i];
        
        if (!(g_Settings[client] & STOP_GUNS))
        {
            newClients[newTotal++] = client;
        }
    }
    
    // No clients were excluded.
    if (newTotal == numClients)
        return Plugin_Continue;
    
    // All clients were excluded and there is no need to broadcast.
    else if (newTotal == 0)
        return Plugin_Stop;
    
    // Re-broadcast to clients that still need it.
    decl Float:vTemp[3];
    TE_Start("Shotgun Shot");
    TE_ReadVector("m_vecOrigin", vTemp);
    TE_WriteVector("m_vecOrigin", vTemp);
    TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
    TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
    TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
    TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
    TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
    TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
    TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
    TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
    TE_Send(newClients, newTotal, delay);
    
    return Plugin_Stop;
}

CheckHooks()
{
    new bool:bShouldHook = false;
    
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            if(g_Settings[i] & STOP_GUNS)
            {
                bShouldHook = true;
                break;
            }
        }
    }
    
    // Fake (un)hook because toggling actual hooks will cause server instability.
    g_bHooked = bShouldHook;
}

public Action:AmbientSHook(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay)
{
    // Stop music next frame
    CreateTimer(0.0, Timer_StopMusic);
}
 
public Action:NormalSHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    if(IsValidEntity(entity) && IsValidEdict(entity))
    {
        decl String:sClassName[128];
        GetEntityClassname(entity, sClassName, sizeof(sClassName));
        
        new iSoundType;
        if(StrEqual(sClassName, "func_door"))
            iSoundType = STOP_DOORS;
        else if(strncmp(sample, "weapons", 7) == 0 || strncmp(sample[1], "weapons", 7) == 0)
            iSoundType = STOP_GUNS;
        else
            return Plugin_Continue;
        
        for (new i = 0; i < numClients; i++)
        {
            if(g_Settings[clients[i]] & iSoundType)
            {
                // Remove the client from the array.
                for (new j = i; j < numClients-1; j++)
                {
                    clients[j] = clients[j+1];
                }
                numClients--;
                i--;
            }
        }
        
        return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
    }
    
    if( ( StrContains( sample, "physics/flesh/flesh_impact_bullet" ) != -1 ) || ( StrContains( sample, "player/kevlar" ) != -1 )
        || ( StrContains( sample, "player/headshot" ) != -1 ) || ( StrContains( sample, "player/bhit_helmet" ) != -1 ) )
    {
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
    if(GetConVarBool(g_WeaponDespawn) == true)
    {
        if(IsValidEdict(entity) && IsValidEntity(entity))
        {
            CreateTimer(0.2, KillEntity, EntIndexToEntRef(entity));
        }
    }
}
 
public Action:KillEntity(Handle:timer, any:ref)
{
    // anti-weapon spam
    new ent = EntRefToEntIndex(ref);
    if(IsValidEdict(ent) && IsValidEntity(ent))
    {
        decl String:entClassname[128];
        GetEdictClassname(ent, entClassname, sizeof(entClassname));
        if(StrContains(entClassname, "weapon_") != -1 || StrContains(entClassname, "item_") != -1)
        {
            new m_hOwnerEntity = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
            if(m_hOwnerEntity == -1)
                AcceptEntityInput(ent, "Kill");
        }
    }
}

public Action:Event_PlayerSpawn_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    // no block
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
    

    SetEntProp(client, Prop_Data, "m_bDrawViewmodel", g_Settings[client] & HIDE_WEAPONS ? '0' : 1);
        
        
    return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsClientInGame(iClient))
    {
        new iEntity = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
        if (iEntity > MaxClients && IsValidEdict(iEntity))
        {
            CreateTimer(0.0, f_Dissolve, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
        }
	}
}

public Action:f_Dissolve(Handle:hTimer, any:ref)  
{  
    new iEntity = EntRefToEntIndex(ref);
    if(iEntity != INVALID_ENT_REFERENCE) AcceptEntityInput(iEntity, "Kill");
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Ents are recreated every round.
    g_iNumSounds = 0;
    
    // Find all ambient sounds played by the map.
    decl String:sSound[PLATFORM_MAX_PATH];
    new entity = INVALID_ENT_REFERENCE;
    
    while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
        
        new len = strlen(sSound);
        if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
        {
            g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
        }
    }
}

// drop any weapon
public Action:DropItem(client, const String:command[], argc)
{
    new weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

    if(GetConVarBool(g_hAllowKnifeDrop) || IsFakeClient(client))
    {
        if(weaponIndex != -1)
        {
            CS_DropWeapon(client, weaponIndex, true, false);
        }
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public void Hook_OnWeaponDrop(int client, int entity)
{
    if(IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "kill");
    }
}

public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char[] arg1 = new char[8];
	GetCmdArg(1, arg1, 8);

	int iTeam = StringToInt(arg1);

	// client is trying to join the same team he's in now.
	// i'll let the game handle it.
	if(GetClientTeam(client) == iTeam)
	{
		return Plugin_Continue;
	}

	switch(iTeam)
	{
		case CS_TEAM_T:
		{
			// if T spawns are available in the map
			CS_SwitchTeam(client, CS_TEAM_T);
			CS_RespawnPlayer(client);
		}

		case CS_TEAM_CT:
		{
			CS_SwitchTeam(client, CS_TEAM_CT);
			CS_RespawnPlayer(client);
		}

		// if they chose to spectate, i'll force them to join the spectators
		case CS_TEAM_SPECTATOR:
		{
			CS_SwitchTeam(client, CS_TEAM_SPECTATOR);
		}

		default:
		{
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

public Action:HookPlayerChat(int client, const String:command[], int args)
{
	if(GetConVarBool(g_HideChatTriggers))
	{
		decl String:text[2];
		GetCmdArg(1, text, 2);
		return text[0] == '!' || text[0] == '/' ? Plugin_Handled:Plugin_Continue;
	}
	return Plugin_Continue;
}

// kill weapon and weapon attachments on drop
public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
    if(weaponIndex != -1)
    {
        AcceptEntityInput(weaponIndex, "KillHierarchy");
        AcceptEntityInput(weaponIndex, "Kill");
    }
}

// Tells a player who is spectating them
public Action:SM_Specinfo(client, args)
{
    if(IsPlayerAlive(client))
    {
        ShowSpecinfo(client, client);
    }
    else
    {
        new Target       = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
            
        if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
        {
            ShowSpecinfo(client, Target);
        }
        else
        {
            CPrintToChat(client, "%s%sYou are not spectating anyone.",
                g_msg_start,
                g_msg_textcol);
        }
    }
    
    return Plugin_Handled;
}

ShowSpecinfo(client, target)
{
    decl String:sNames[MaxClients + 1][MAX_NAME_LENGTH];
    new index;
    new bool:bClientHasAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
    
    for(new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            if(!bClientHasAdmin && GetAdminFlag(GetUserAdmin(i), Admin_Generic, Access_Effective))
            {
                continue;
            }
                
            if(!IsPlayerAlive(i))
            {
                new iTarget      = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
                new ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
                
                if((ObserverMode == 4 || ObserverMode == 5) && (iTarget == target))
                {
                    GetClientName(i, sNames[index++], MAX_NAME_LENGTH);
                }
            }
        }
    }
    
    decl String:sTarget[MAX_NAME_LENGTH];
    GetClientName(target, sTarget, sizeof(sTarget));
    
    if(index != 0)
    {
        new Handle:menu = CreatePanel();
        
        decl String:sTitle[64];
        Format(sTitle, sizeof(sTitle), "Spectating %s", sTarget);
        DrawPanelText(menu, sTitle);
        DrawPanelText(menu, " ");
        
        for(new i = 0; i < index; i++)
        {
            DrawPanelText(menu, sNames[i]);
        }
        
        DrawPanelText(menu, " ");
        DrawPanelText(menu, "0. Close");
        
        SendPanelToClient(menu, client, Menu_SpecInfo, 10);
    }
    else
    {
        CPrintToChat(client, "%s%s%s%s has no spectators.",
            g_msg_start,
            g_msg_varcol,
            sTarget,
            g_msg_textcol);
    }
}

public Menu_SpecInfo(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_End)
        CloseHandle(menu);
}

public Action Command_Radio(int client, const char[] command, int args)
{
    return Plugin_Continue;
}

// Hide other players
public Action:SM_Hide(client, args)
{
    SetClientSettings(client, GetClientSettings(client) ^ HIDE_PLAYERS);
    
    if(g_Settings[client] & HIDE_PLAYERS)
    {
        CPrintToChat(client, "%s%sPlayers are now %sinvisible",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol);
    }
    else
    {
        CPrintToChat(client, "%s%sPlayers are now %svisible",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol);
    }
    
    return Plugin_Handled;
}

public Action:SM_Hidewep(client, args)
{
	SetClientSettings(client, GetClientSettings(client) ^ HIDE_WEAPONS);
	
	if(g_Settings[client] & HIDE_WEAPONS)
	{
		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 0);
		CPrintToChat(client, "%s%sYour weapon is now %sinvisible",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol);
	}	
	else
	{
		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 1);
		CPrintToChat(client, "%s%sYour weapon is now %svisible",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol);
	}
}

// Spectate command
public Action:SM_Spec(client, args)
{
    StopTimer(client);
    ForcePlayerSuicide(client);
    ChangeClientTeam(client, 1);
    if(args != 0)
    {
        decl String:arg[128];
        GetCmdArgString(arg, sizeof(arg));
        new target = FindTarget(client, arg, false, false);
        if(target != -1)
        {
            if(client != target)
            {
                if(IsPlayerAlive(target))
                {
                    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
                }
                else
                {
                    decl String:name[MAX_NAME_LENGTH];
                    GetClientName(target, name, sizeof(name));
                    CPrintToChat(client, "%s%s%s %sis not alive.", 
                        g_msg_start,
                        g_msg_varcol,
                        name,
                        g_msg_textcol);
                }
            }
            else
            {
                CPrintToChat(client, "%s%sYou can't spectate yourself.",
                    g_msg_start,
                    g_msg_textcol);
            }
        }
    }
    return Plugin_Handled;
}

// Punish players
public Action:SM_Hudfuck(client, args)
{
    decl String:arg[250];
    GetCmdArgString(arg, sizeof(arg));
    
    new target = FindTarget(client, arg, false, false);
    
    if(target != -1)
    {
        SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);
        
        decl String:targetname[MAX_NAME_LENGTH];
        GetClientName(target, targetname, sizeof(targetname));
        CPrintToChatAll("%s%s%s %shas been HUD-FUCKED for their negative actions", 
            g_msg_start,
            g_msg_varcol,
            targetname,
            g_msg_textcol);
        
        // Log the hudfuck event
        LogMessage("%L executed sm_hudfuck command on %L", client, target);
    }
    else
    {
        new Handle:menu = CreateMenu(Menu_HudFuck);
        SetMenuTitle(menu, "Select player to HUD FUCK");
        
        decl String:sAuth[32], String:sDisplay[64], String:sInfo[8];
        for(new iTarget = 1; iTarget <= MaxClients; iTarget++)
        {
            if(IsClientInGame(iTarget))
            {
                //GetClientAuthString(iTarget, sAuth, sizeof(sAuth));
                GetClientAuthId(iTarget, AuthId_Steam2, sAuth,  sizeof(sAuth));
                Format(sDisplay, sizeof(sDisplay), "%N <%s>", iTarget, sAuth);
                IntToString(GetClientUserId(iTarget), sInfo, sizeof(sInfo));
                AddMenuItem(menu, sInfo, sDisplay);
            }
        }
        
        SetMenuExitBackButton(menu, true);
        SetMenuExitButton(menu, true);
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    }
    return Plugin_Handled;
}

public Menu_HudFuck(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        decl String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        
        new target = GetClientOfUserId(StringToInt(info));
        if(target != 0)
        {
            CPrintToChatAll("%s%s%N %shas been HUD-FUCKED for their negative actions", 
                g_msg_start,
                g_msg_varcol,
                target,
                g_msg_textcol);
            SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);
            
            // Log the hudfuck event
            LogMessage("%L executed sm_hudfuck command on %L", param1, target);
        }
        else
        {
            CPrintToChat(param1, "%s%sTarget not in game",
                g_msg_start,
                g_msg_textcol);
        }
    }
    else if(action == MenuAction_End)
        CloseHandle(menu);
}

// Display current map session time
public Action:SM_Maptime(client, args)
{
    new Float:mapTime = GetEngineTime() - g_fMapStart;
    new hours, minutes, seconds;
    hours    = RoundToFloor(mapTime/3600);
    mapTime -= (hours * 3600);
    minutes  = RoundToFloor(mapTime/60);
    mapTime -= (minutes * 60);
    seconds  = RoundToFloor(mapTime);
    
    CPrintToChat(client, "%sMaptime: %s%d%s %s, %s%d%s %s, %s%d%s %s", 
        g_msg_textcol,
        g_msg_varcol,
        hours,
        g_msg_textcol,
        (hours==1)?"hour":"hours", 
        g_msg_varcol,
        minutes,
        g_msg_textcol,
        (minutes==1)?"minute":"minutes", 
        g_msg_varcol,
        seconds, 
        g_msg_textcol,
        (seconds==1)?"second":"seconds");
}

// Open sound control menu
public Action:SM_Sound(client, args)
{
    new Handle:menu = CreateMenu(Menu_StopSound);
    SetMenuTitle(menu, "Control Sounds");
    
    decl String:sInfo[16];
    IntToString(STOP_DOORS, sInfo, sizeof(sInfo));
    AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_DOORS)?"Door sounds: Off":"Door sounds: On");
    
    IntToString(STOP_GUNS, sInfo, sizeof(sInfo));
    AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_GUNS)?"Gun sounds: Off":"Gun sounds: On");
    
    IntToString(STOP_MUSIC, sInfo, sizeof(sInfo));
    AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_MUSIC)?"Music: Off":"Music: On");

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

public Menu_StopSound(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        
        new setting = StringToInt(info);
        SetClientSettings(param1, GetClientSettings(param1) ^ setting);
        
        if(setting == STOP_GUNS)
            CheckHooks();
        
        if(setting == STOP_MUSIC && (g_Settings[param1] & STOP_MUSIC))
        {
            new ientity, String:sSound[128];
            for (new i = 0; i < g_iNumSounds; i++)
            {
                ientity = EntRefToEntIndex(g_iSoundEnts[i]);
                
                if (ientity != INVALID_ENT_REFERENCE)
                {
                    GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
                    EmitSoundToClient(param1, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
                }
            }
        }
        
        FakeClientCommand(param1, "sm_sound");
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public Action:SM_Speed(client, args)
{
    if(args == 1)
    {
        // Get the specified speed
        decl String:sArg[250];
        GetCmdArgString(sArg, sizeof(sArg));
        
        new Float:fSpeed = StringToFloat(sArg);
        
        // Check if the speed value is in a valid range
        if(!(0 <= fSpeed <= 100))
        {
            CPrintToChat(client, "%s%sYour speed must be between 0 and 100",
                g_msg_start,
                g_msg_textcol);
            return Plugin_Handled;
        }
        
        StopTimer(client);
        
        // Set the speed
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
        
        // Notify them
        CPrintToChat(client, "%s%sSpeed changed to %s%f%s%s",
            g_msg_start,
            g_msg_textcol,
            g_msg_varcol,
            fSpeed,
            g_msg_textcol,
            (fSpeed != 1.0)?" (Default is 1)":" (Default)");
    }
    else
    {
        // Show how to use the command
        CPrintToChat(client, "%s%sExample: sm_speed 2.0",
            g_msg_start,
            g_msg_textcol);
    }
    
    return Plugin_Handled;
}

public Action:SM_Fast(client, args)
{
    StopTimer(client);
    
    // Set the speed
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);
    
    return Plugin_Handled;
}

public Action:SM_Slow(client, args)
{
    StopTimer(client);
    
    // Set the speed
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5);
    
    return Plugin_Handled;
}

public Action:SM_Normalspeed(client, args)
{
    StopTimer(client);
    
    // Set the speed
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    
    return Plugin_Handled;
}

public Action:SM_Lowgrav(client, args)
{
    StopTimer(client);
    
    SetEntityGravity(client, 0.6);
    
    CPrintToChat(client, "%s%sUsing low gravity. Use !normalgrav to switch back to normal gravity.",
        g_msg_start,
        g_msg_textcol);
}

public Action:SM_Normalgrav(client, args)
{
    SetEntityGravity(client, 0.0);
    
    CPrintToChat(client, "%s%sUsing normal gravity.",
        g_msg_start,
        g_msg_textcol);
}

public Action:Hook_SetTransmit(entity, client)
{
	
    if(entity > 0 && entity <= MaxClients || client == entity)
        return Plugin_Handled;

    if(g_Settings[client] & HIDE_PLAYERS)
        return Plugin_Handled;
        
    if(!IsPlayerAlive(client) && GetClientObserverTarget(client) == entity)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    SetEntPropVector(victim, Prop_Send, "m_viewPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
    SetEntPropVector(victim, Prop_Send, "m_aimPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
    SetEntPropVector(victim, Prop_Send, "m_aimPunchAngleVel", view_as<float>({0.0, 0.0, 0.0}));
    return Plugin_Handled;
}

//Credits to Bara
public Action TE_OnEffectDispatch(const char[] te_name, const Players[], int numClients, float delay)
{
	int iEffectIndex = TE_ReadNum("m_iEffectName");
	int nHitBox = TE_ReadNum("m_nHitBox");
	char sEffectName[64];

	GetEffectName(iEffectIndex, sEffectName, sizeof(sEffectName));

	if(StrEqual(sEffectName, "csblood"))
	{
		return Plugin_Handled;
	}
		
	if(StrEqual(sEffectName, "ParticleEffect"))
	{
			
		char sParticleEffectName[64];
		GetParticleEffectName(nHitBox, sParticleEffectName, sizeof(sParticleEffectName));
		
		if(StrEqual(sParticleEffectName, "impact_helmet_headshot") || StrEqual(sParticleEffectName, "impact_physics_dust"))
		{
			return Plugin_Handled;
		}
	}


	return Plugin_Continue;
}

public Action TE_OnWorldDecal(const char[] te_name, const Players[], int numClients, float delay)
{
	float vecOrigin[3];
	int nIndex = TE_ReadNum("m_nIndex");
	char sDecalName[64];

	TE_ReadVector("m_vecOrigin", vecOrigin);
	GetDecalName(nIndex, sDecalName, sizeof(sDecalName));

	if(StrContains(sDecalName, "decals/blood") == 0 && StrContains(sDecalName, "_subrect") != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}


stock int GetParticleEffectName(int index, char[] sEffectName, int maxlen)
{
	int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");
	
	return ReadStringTable(table, index, sEffectName, maxlen);
}

stock int GetEffectName(int index, char[] sEffectName, int maxlen)
{
	int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");
	
	return ReadStringTable(table, index, sEffectName, maxlen);
}

stock int GetDecalName(int index, char[] sDecalName, int maxlen)
{
	int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("decalprecache");
	
	return ReadStringTable(table, index, sDecalName, maxlen);
}


// get a player's settings
public Native_GetClientSettings(Handle:plugin, numParams)
{
    return g_Settings[GetNativeCell(1)];
}

// set a player's settings
public Native_SetClientSettings(Handle:plugin, numParams)
{
    new client         = GetNativeCell(1);
    g_Settings[client] = GetNativeCell(2);
    
    if(AreClientCookiesCached(client))
    {
        decl String:sSettings[16];
        IntToString(g_Settings[client], sSettings, sizeof(sSettings));
        SetClientCookie(client, g_hSettingsCookie, sSettings);
    }
}

stock int GetClientObserverTarget(int client)
{
    return GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
}