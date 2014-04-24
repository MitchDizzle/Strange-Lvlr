
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Strange Lvlr
	This plugin will teleport any idle players to a single location
	and respawn them instantly.
	This is useful for Strange levelling servers.
	Hate me, because I ruined the strange quality items,
	they are now meaningless counts.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

#pragma semicolon 1
#include <sdktools>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.2.0"

public Plugin:myinfo = {
	name = "Strange Lvlr",
	author = "Mitchell",
	description = "Making strange a useless quality in tf2, since 2014 (tm)",
	version = PLUGIN_VERSION,
	url = "SnBx.info"
}
//Global vars
new bool:isIdlePlayer[MAXPLAYERS+1];
new Float:spawnpoints[2][3];
new idlecolors[2][4];

//Config vars and handles.
new Handle:g_hEnabled;
new bool:g_bEnabled = true;

new Float:g_fIdleTime = 60.0; // This is the default!

#define SLVLR_None            			0
#define SLVLR_DisableMovement			(1 << 0)
#define SLVLR_RemoveWeapons				(1 << 1)
#define SLVLR_KillPlayerOnIdle			(1 << 2)
#define SLVLR_RespawnPlayerOnReturn		(1 << 3)
#define SLVLR_ColorIdlePlayer			(1 << 4)
new StrangeIdleConfig;

public OnPluginStart()
{
	g_hEnabled = CreateConVar("sm_slvlr_enabled", "1", "If non-zero Strange Lvlr will be enabled.");
	HookConVarChange(g_hEnabled, OnCvarChanged);

	CreateConVar("sm_slvlr_version", PLUGIN_VERSION, "Strange Lvlr Version", \
														FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
	HookEvent("player_death", Event_Death_Block, EventHookMode_Pre);
}

public OnMapStart()
{
	//Empty out the spawnpoints variable and it's cells.
	for(new j = 0; j < 2; j++)
		for(new k = 0; k < 3; k++)
			spawnpoints[j][k] = 0.0;
	LoadConfig(); // Make sure we load the config after the empty spawnpoints!
	CreateTimer(0.1, Timer_LastInput, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	//Reset the players back to 0.0 time
	for(new i = 1; i <= MaxClients; i++)
		isIdlePlayer[i] = false;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Timer_LastInput		(type: Timer)
	This will check if a player has press any buttons since the last
	check and will add up on their individual timers if they have not,
	if they have then it will reset the time variable back to zero.
	Why don't I use OnPlayerRunCmd and just store the last time? idk.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:Timer_LastInput(Handle:timer)
{
	//Keeps the timer going, but doesn't do anything too harmful to the server
	if(!g_bEnabled)
		return Plugin_Continue;
	static Float:lastInput[MAXPLAYERS+1];
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) > 1 && IsPlayerAlive(i))
			{
				if(GetClientButtons(i) > 0)
				{
					lastInput[i] = 0.0;
					if(isIdlePlayer[i])
					{
						isIdlePlayer[i] = false;
						if(StrangeIdleConfig & SLVLR_RespawnPlayerOnReturn)
							TF2_RespawnPlayer(i);
					}
				}
				else 
				{
					if(isIdlePlayer[i])
						continue;
					lastInput[i] += 0.1;
					if(lastInput[i] > g_fIdleTime)
					{
						isIdlePlayer[i] = true;
						if(StrangeIdleConfig & SLVLR_KillPlayerOnIdle)
							ForcePlayerSuicide(i);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Event_Death		(type: Event)
	When a player dies it will check their last input time, if it is
	past the time for the idle method then the player will be instantly
	respawned and teleported to the first known spawn point 
	for the opposite of the player's team.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bEnabled)
		return Plugin_Continue;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//Check if the player is considered idling.
	if(isIdlePlayer[client])
	{
		new team = GetClientTeam(client);
		// This will get the opposite team.
		// If the player is not on a team, then it will return -1.
		team = (team > 1) ? (team == 2) ? 1 : 0 : -1;
		//Team is greater than -1, means he is still on a team!
		// Checks to make sure there are valid spawn points still!
		// This also makes sure that the Event_Spawn doesn't bug out.
		if(team >= 0 && !IsVectorEmpty(spawnpoints[team]))
			CreateTimer(0.01, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Continue;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Timer_Respawn		(type: Timer)
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:Timer_Respawn(Handle:timer, any:data)
{
	new client = GetClientOfUserId(data);
	if(client)
		TF2_RespawnPlayer(client);
}
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Event_Death_Block		(type: Event)
	This method is to block the kill feed from any idle kills,
	this hopefully will clear up spam from people killing the idles.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

public Action:Event_Death_Block(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bEnabled)
		return Plugin_Continue;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(isIdlePlayer[client])
		SetEventBroadcast(event, true);
	return Plugin_Continue;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Event_Spawn		(type: Event)
	This method checks the first player to spawn on each team and sets
	the spawn point as the teleport location for each team's idle position,
	this will only fire once per team after a new map has started.
	this could be replaced by finding an entity, but I like to try new things!	
	Need to add a cvar that can override this...
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bEnabled)
		return Plugin_Continue;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client))
		return Plugin_Continue;
	if(!IsPlayerAlive(client))
		return Plugin_Continue;

	new team = GetClientTeam(client);
	if(IsVectorEmpty(spawnpoints[team-2]))
		GetClientAbsOrigin(client, spawnpoints[team-2]);
	//Reset the player's movement, if he can't move :<
	if(GetEntityMoveType(client) == MOVETYPE_NONE)
		SetEntityMoveType(client, MOVETYPE_NONE);
	//Reset a player's color
	if(StrangeIdleConfig & SLVLR_ColorIdlePlayer)
	{
		SetEntityRenderColor(client, 255,255,255,255);
		SetEntityRenderMode(client,  RENDER_NORMAL);
	}
	//Idle player Attributes applied when the player is spawned
	if(isIdlePlayer[client])
	{
		team = (team > 1) ? (team == 2) ? 1 : 0 : -1;
		TeleportEntity(client, spawnpoints[team], Float:{0.0,0.0,0.0}, NULL_VECTOR);
		//Color Idle Player team corrective.
		if(StrangeIdleConfig & SLVLR_ColorIdlePlayer)
		{
			SetEntityRenderColor(client, idlecolors[team][0], \
										 idlecolors[team][1], \
										 idlecolors[team][2], \
										 idlecolors[team][3]);
			SetEntityRenderMode(client, (idlecolors[team][3] < 255) ? RENDER_TRANSALPHA : RENDER_NORMAL);
		}
		//Disable Movement:
		if(StrangeIdleConfig & SLVLR_DisableMovement)
			SetEntityMoveType(client, MOVETYPE_NONE);
		//Remove all teh weapons!
		if(StrangeIdleConfig & SLVLR_RemoveWeapons)
			TF2_RemoveAllWeapons(client);
	}
	return Plugin_Continue;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------OnCvarChanged		(type: Convar Change)
	Basically gets the new values and saves them.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public OnCvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_bEnabled = StrEqual(newVal, "0", false) ? false : true;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------LoadConfig		(type: Public Function)
	Loads the config from
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public LoadConfig()
{
	new Handle:SMC = SMC_CreateParser(); 
	SMC_SetReaders(SMC, NewSection, KeyValue, EndSection); 
	decl String:sPaths[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPaths, sizeof(sPaths),"configs/strange_lvlr_config.txt");
	StrangeIdleConfig = SLVLR_None;
	SMC_ParseFile(SMC, sPaths);
	CloseHandle(SMC);
}
public SMCResult:NewSection(Handle:smc, const String:name[], bool:opt_quotes) { }
public SMCResult:EndSection(Handle:smc) {
	//Just makes so we dont color people when they have this disabled...
	new bool:notdefault = false;
	for(new j = 0; j < 2; j++)
		for(new k = 0; k < 4; k++)
			if( idlecolors[j][k] != 255 )
				notdefault = true;
	if(!notdefault)
		StrangeIdleConfig &= ~SLVLR_ColorIdlePlayer;
}  
public SMCResult:KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) 
{
	if(StrEqual(key, "Idle Time", false))
		g_fIdleTime = StringToFloat(value);
	else if(StrContains(key, "Spawn Location") != -1)
	{
		new String:sExploded[3][8];
		//Split the string into a vector
		ExplodeString(value, " ", sExploded, 3, 8);
		new sp = (StrEqual(key, "Spawn Location 2", false)) ? 1 : 0;
		spawnpoints[sp][0] = StringToFloat(sExploded[0]);
		spawnpoints[sp][1] = StringToFloat(sExploded[1]);
		spawnpoints[sp][2] = StringToFloat(sExploded[2]);
	}

	if(StrEqual(key, "Disable Movement", false) && StringToInt(value))
		StrangeIdleConfig |= SLVLR_DisableMovement;
	else if(StrEqual(key, "Remove Weapons", false) && StringToInt(value))
		StrangeIdleConfig |= SLVLR_RemoveWeapons;
	else if(StrEqual(key, "Kill Players", false) && StringToInt(value))
		StrangeIdleConfig |= SLVLR_KillPlayerOnIdle;
	else if(StrEqual(key, "Respawn Player On Return", false) && StringToInt(value))
		StrangeIdleConfig |= SLVLR_RespawnPlayerOnReturn;
	else if(StrEqual(key, "Color Idle Players", false) && StringToInt(value))
		StrangeIdleConfig |= SLVLR_ColorIdlePlayer;
	if(StrContains(key, "Idle Color") != -1)
	{
		new String:sColorExplode[4][8];
		//Split the string into a color vector
		ExplodeString(value, " ", sColorExplode, 4, 8);
		new clr = (StrEqual(key, "Idle Color 2", false)) ? 0 : 1;
		idlecolors[clr][0] = StringToInt(sColorExplode[0]);
		idlecolors[clr][1] = StringToInt(sColorExplode[1]);
		idlecolors[clr][2] = StringToInt(sColorExplode[2]);
		idlecolors[clr][3] = StringToInt(sColorExplode[3]);
	}
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------IsVectorEmpty		(type: Stock Function)
	Simple rip from SMLib, it was simplfied to make it find the distance
	from 0.0,0.0,0.0 point. If there is a spawn point at this location
	then the map was never optimized, and horribly created, and you 
	should feel ashamed at your self for even hosting a shit map.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
stock bool:IsVectorEmpty(Float:fVector[3])
{
	return GetVectorDistance(fVector, Float:{0.0, 0.0, 0.0}) <= 0.1;
}
