/* Here you can edit fps detection settings */

#define MAX_WRONG_FPS_WARNINGS 10

#define LAST_WARN_TIME 30.0

/* Here you stop */

new g_iCurrentFps[MAX_PLAYERS_ARR];

new g_iFpsWarns[MAX_PLAYERS_ARR];
new Float:g_flLastWarnTime[MAX_PLAYERS_ARR];

ac_fps_disconnected(id)
{
	g_iCurrentFps[id] = 0;
	g_iFpsWarns[id] = 0;
	g_flLastWarnTime[id] = 0.0;
}

ac_fps_CmdStart(id, uc_handle)
{
	g_iCurrentFps[id] = floatround(1 / (get_uc(uc_handle, UC_Msec) * 0.001));
}

ac_fps_PlayerPostThink(id)
{

	if( bMysqld ) {
		new SteamID[32], excludeSteamID[32];
		get_user_authid( id, SteamID, charsmax( SteamID ) );
		
		for(new i = 0; i < ArraySize( authIDs ); i++ ) {
			ArrayGetString( authIDs, i, excludeSteamID, charsmax( excludeSteamID ) );
			
			if( strcmp( SteamID, excludeSteamID ) == 0 ) {
				return;
			}
		}
	}


	if (g_iCurrentFps[id] >= 111)
	{
		if (get_gametime() - g_flLastWarnTime[id] <= LAST_WARN_TIME)
		{
			g_iFpsWarns[id]++;
			g_flLastWarnTime[id] = get_gametime();
			
			if (g_iFpsWarns[id] >= MAX_WRONG_FPS_WARNINGS)
			{
				new szName[32];
				get_user_name(id, szName, charsmax(szName));
				
				client_print_color(0, print_team_red, "^1[^4%s^1]^3 %s^1 is using^3 %d^1 FPS!", g_szPrefix, szName, g_iCurrentFps[id]);
				
				server_cmd("kick #%d ^"Illegal FPS(%d)^"", get_user_userid(id), g_iCurrentFps[id]);
			}
		}
		g_flLastWarnTime[id] = get_gametime();
	}
}