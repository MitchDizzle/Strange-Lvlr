
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

#define TIMETOIDLE 60.0 //Need to make this a cvar!

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo = {
	name = "Strange Lvlr",
	author = "Mitchell",
	description = "Making stranges a useless quality in tf2, since 2014 (tm)",
	version = PLUGIN_VERSION,
	url = "SnBx.info"
}

new bool:isIdlePlayer[MAXPLAYERS+1];
new Float:spawnpoints[2][3];

new Handle:g_hEnabled;
new Handle:g_hSpawnPos[2];
new Handle:g_hIdleTime;

new bool:g_bEnabled = true;
new Float:g_fIdleTime = 60.0; // This is the default!

public OnPluginStart()
{
	g_hEnabled = CreateConVar("sm_slvlr_enabled", "1", "If non-zero Strange Lvlr will be enabled.");
	g_hIdleTime = CreateConVar("sm_slvlr_idletime", "60.0", "Time for a player to be considered idle.", _, true, 1.0);
	//0.0 0.0 0.0 to use the default method.
	g_hSpawnPos[0] = CreateConVar("sm_slvlr_spawnpos1", "0.0 0.0 0.0", "The Spawn position for anybody on team 2");
	g_hSpawnPos[1] = CreateConVar("sm_slvlr_spawnpos2", "0.0 0.0 0.0", "The Spawn position for anybody on team 3");
	
	HookConVarChange(g_hEnabled, OnCvarChanged);
	HookConVarChange(g_hIdleTime, OnCvarChanged);
	HookConVarChange(g_hSpawnPos[0], OnCvarChanged);
	HookConVarChange(g_hSpawnPos[1], OnCvarChanged);
	AutoExecConfig();//Make sure this is before the damn version, as we don't want that in our config. (rookie mistake)
	CreateConVar("sm_slvlr_version", PLUGIN_VERSION, "Strange Lvlr Version", \
														FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
}

public OnMapStart()
{
	//Empty out the spawnpoints variable and it's cells.
	for(new j = 0; j < 2; j++)
		for(new k = 0; k < 3; k++)
			spawnpoints[j][k] = 0.0;
	CreateTimer(0.1, Timer_LastInput, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	//Reset the players back to 0.0 time
	for(new i = 1; i <= MaxClients; i++)
		isIdlePlayer[i] = false;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------OnCvarChanged		(type: Convar Change)
	Basically gets the new values and saves them.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public OnCvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if(cvar == g_hEnabled)
	{
		g_bEnabled = StrEqual(newVal, "0", false) ? false : true;
	}
	else if(cvar == g_hIdleTime)
	{
		g_fIdleTime = StringToFloat(newVal);
	}
	else if(cvar == g_hSpawnPos[0] || cvar == g_hSpawnPos[1])
	{
		new String:sExploded[3][8];
		//Split the string into a vector
		ExplodeString(newVal, " ", sExploded, 3, 8);
		new sp = (cvar == g_hSpawnPos[0]) ? 0 : 1;
		spawnpoints[sp][0] = StringToFloat(sExploded[0]);
		spawnpoints[sp][1] = StringToFloat(sExploded[1]);
		spawnpoints[sp][2] = StringToFloat(sExploded[2]);
	}
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
	static lastbuttons[MAXPLAYERS+1];
	static Float:lastInput[MAXPLAYERS+1];
	new currentbuttons;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) > 1)
			{
				currentbuttons = GetClientButtons(i);
				if(lastbuttons[i] != currentbuttons)
				{
					if(isIdlePlayer[i])
					{
						isIdlePlayer[i] = false;
						lastbuttons[i] = currentbuttons;
						lastInput[i] = 0.0;
					}
				}
				else 
				{
					if(!isIdlePlayer[i])
					{
						lastInput[i] += 0.1;
						if(lastInput[i] > g_fIdleTime)
							isIdlePlayer[i] = true;
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
		{
			TF2_RespawnPlayer(client); //This may need to be a 0.0 timer..
			TeleportEntity(client, spawnpoints[team], Float:{0.0,0.0,0.0}, NULL_VECTOR);
		}
	}
	
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
	return Plugin_Continue;
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