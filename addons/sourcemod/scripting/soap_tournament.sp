#pragma semicolon 1
#include <sourcemod>

// ====[ CONSTANTS ]===================================================
#define PLUGIN_NAME		"SOAP Tournament"
#define PLUGIN_AUTHOR		"Lange"
#define PLUGIN_VERSION		"3.4"
#define PLUGIN_CONTACT		"http://steamcommunity.com/id/langeh/"
#define RED 0
#define BLU 1
#define TEAM_OFFSET 2

// ====[ PLUGIN ]======================================================
public Plugin:myinfo =
{
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description	= "Automatically loads and unloads plugins when a mp_tournament match goes live or ends.",
	version		= PLUGIN_VERSION,
	url				= PLUGIN_CONTACT
};

// ====[ VARIABLES ]===================================================

new bool:teamReadyState[2] = { false, false },
	bool:g_dm = false;

ConVar g_cvReadyModeCountdown;
ConVar g_cvEnforceReadyModeCountdown;


// ====[ FUNCTIONS ]===================================================

/* OnPluginStart()
 *
 * When the plugin starts up.
 * -------------------------------------------------------------------------- */

public OnPluginStart()
{
	LoadTranslations("soap_tf2dm.phrases");
	// Game restart
	//HookEvent("teamplay_restart_round", GameRestartEvent);

	// Win conditions met (maxrounds, timelimit)
	HookEvent("teamplay_game_over", GameOverEvent);

	// Win conditions met (windifference)
	HookEvent("tf_game_over", GameOverEvent);

	// Hook into mp_tournament_restart
	RegServerCmd("mp_tournament_restart", TournamentRestartHook);
	
	//HookEvent("teamplay_round_restart_seconds", Event_TeamplayRestartSeconds);
	HookEvent("tournament_stateupdate", Event_TournamentStateupdate); 

	//Hook for event spammed when mp_tournament_readymode 1
	//There doesn't seem to be any way players can cancel the countdown once it starts, so no need to worry about reloading SOAP if that happens
	HookEvent("tournament_enablecountdown", Event_TournamentEnableCountdown, EventHookMode_PostNoCopy);

	g_cvEnforceReadyModeCountdown = CreateConVar("soap_enforce_readymode_countdown", "1", "Set as 1 to keep mp_tournament_readymode_countdown 5 so P-Rec works properly", _, true, 0.0, true, 1.0);
	g_cvReadyModeCountdown = FindConVar("mp_tournament_readymode_countdown");
	SetConVarInt(g_cvReadyModeCountdown, 5, true, true);
	HookConVarChange(g_cvEnforceReadyModeCountdown, handler_ConVarChange);
	HookConVarChange(g_cvReadyModeCountdown, handler_ConVarChange);
	
	StartDeathmatching();
}

/* OnMapStart()
 *
 * When the map starts.
 * -------------------------------------------------------------------------- */
public OnMapStart()
{
	teamReadyState[0] = false;
	teamReadyState[1] = false;
	StartDeathmatching();
}

/* StopDeathmatching()
 *
 * Executes soap_live.cfg if it hasn't already been executed..
 * -------------------------------------------------------------------------- */
StopDeathmatching()
{
	if(g_dm == true)
	{
		ServerCommand("exec sourcemod/soap_live.cfg");
		PrintToChatAll("[SOAP] %t", "Plugins unloaded");
		g_dm = false;
	}
}

/* StartDeathmatching()
 *
 * Executes soap_notlive.cfg if it hasn't already been executed..
 * -------------------------------------------------------------------------- */
StartDeathmatching()
{
	if(g_dm == false)
	{
		ServerCommand("exec sourcemod/soap_notlive.cfg");
		PrintToChatAll("[SOAP] %t", "Plugins reloaded");
		g_dm = true;
	}
}

// ====[ CALLBACKS ]===================================================

public Event_TournamentStateupdate(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	new team = GetClientTeam(GetEventInt(event, "userid")) - TEAM_OFFSET;
	new bool:nameChange = GetEventBool(event, "namechange");
	new bool:readyState = GetEventBool(event, "readystate");

	if (!nameChange)
	{
		teamReadyState[team] = readyState;

		// If both teams are ready, StopDeathmatching.
		if (teamReadyState[RED] && teamReadyState[BLU])
		{
			StopDeathmatching();
		} else { // One or more of the teams isn't ready, StartDeathmatching.
			StartDeathmatching();
		}
	}
}

public Event_TournamentEnableCountdown(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_dm == true)
	{
		StopDeathmatching();
	}
}

public GameOverEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	teamReadyState[0] = false;
	teamReadyState[1] = false;
	StartDeathmatching();
}

public Action:TournamentRestartHook(args)
{
	teamReadyState[0] = false;
	teamReadyState[1] = false;
	StartDeathmatching();
	return Plugin_Continue;
}

public handler_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == g_cvReadyModeCountdown && GetConVarBool(g_cvEnforceReadyModeCountdown))
	{
		SetConVarInt(g_cvReadyModeCountdown, 5, true, true);
	}
	if(convar == g_cvEnforceReadyModeCountdown && StringToInt(newValue) == 1)
	{
		SetConVarInt(g_cvReadyModeCountdown, 5, true, true);
	}
}
