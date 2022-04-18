/* Here you can edit gstrafe detection settings */

#define DUCK_SESSION 100

/* Ground Equal [g] */

#define MAX_GE_DUCKS_IAR 15
#define MAX_GE_DUCKS_PERCENT 70.0
#define MAX_GE_DUCKS_SESSION 8

#define MAX_DUCK_WARNINGS 3

/* NSD (no slow down) [n] */
#define MAX_NSD_WARNINGS 5

/* Duck Command IAR (+duck spam) [s] */
#define MAX_DUCK_CMDS_IAR 200

/* Here you stop */

new g_iDucks[MAX_PLAYERS_ARR];

// NSD
new g_iMsec[MAX_PLAYERS_ARR];

new g_iNsdWarns[MAX_PLAYERS_ARR];

/* Ground Equal

 * ARRAY - FOG
 *   0   -  1
 *   1   -  2
 *   2   -  3, 4, 5
 */
new g_iDucksFOG[MAX_PLAYERS_ARR][3];

new Float:g_flGE_DucksPercent[MAX_PLAYERS_ARR][3];
new g_iGE_DucksIAR[MAX_PLAYERS_ARR][3];
new g_iGE_DucksIAR_Sessions[MAX_PLAYERS_ARR][3];
new g_iGE_DucksWarns[MAX_PLAYERS_ARR];

new g_iDuckWarns[MAX_PLAYERS_ARR];

new g_iDuckCmdsIAR[MAX_PLAYERS_ARR];

ac_gstrafe_init()
{
	register_clcmd("ac_duck_stats", "ClCmdDuckStats");
}

ac_gstrafe_disconnect(id)
{
	g_iDucks[id] = 0;
	
	g_iNsdWarns[id] = 0;
	
	for (new i = 0; i < 3; i++)
	{
		g_iDucksFOG[id][i] = 0;
		g_flGE_DucksPercent[id][i] = 0.0;
		g_iGE_DucksIAR[id][i] = 0;
		g_iGE_DucksIAR_Sessions[id][i] = 0;
	}
	g_iGE_DucksWarns[id] = 0;
	
	g_iDuckCmdsIAR[id] = 0;
}

ac_gstrafe_CmdStart(id, uc_handle)
{
	g_iMsec[id] = get_uc(uc_handle, UC_Msec);
}

ac_gstrafe_PlayerPreThink(id)
{
	static iGroundFrames[MAX_PLAYERS_ARR], iOldGroundFrames[MAX_PLAYERS_ARR], iPrevButtons[MAX_PLAYERS_ARR];
	
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

	if (g_iFlags[id] & FL_ONGROUND)
	{
		iGroundFrames[id]++;
		
		if (g_iButtons[id] & IN_DUCK && ~g_iOldButtons[id] & IN_DUCK)
			iOldGroundFrames[id] = iGroundFrames[id];
		
		if (iGroundFrames[id] <= 5 && g_iButtons[id] & IN_DUCK && (~g_iOldButtons[id] & IN_DUCK || (g_iButtons[id] & IN_DUCK && g_iOldButtons[id] & IN_DUCK && ~iPrevButtons[id] & IN_DUCK)))
		{
			if (g_iMsec[id] == 0)
			{
				g_iNsdWarns[id]++;
				
				if (g_iNsdWarns[id] >= MAX_NSD_WARNINGS)
				{
					PunishPlayer(id, "GstrafeHack");
					return;
				}
			}
			
			g_iDucks[id]++;
			
			switch (iGroundFrames[id])
			{
				case 1:
				{
					g_iDucksFOG[id][0]++;
					
					g_iGE_DucksIAR[id][0]++;
					
					if (g_iGE_DucksIAR[id][0] % MAX_GE_DUCKS_SESSION == 0)
						g_iGE_DucksIAR_Sessions[id][0]++;
					
					if (g_iGE_DucksIAR[id][1])
						g_iGE_DucksIAR[id][1] = 0;
					
					if (g_iGE_DucksIAR[id][2])
						g_iGE_DucksIAR[id][2] = 0;
					
					if (g_iGE_DucksIAR[id][0] > MAX_GE_DUCKS_IAR)
					{
						g_iGE_DucksWarns[id]++;
						g_iDuckWarns[id]++;
						
						if (g_iDuckWarns[id] >= MAX_DUCK_WARNINGS)
						{
							PunishPlayer(id, "GstrafeHack");
							return;
						}
						
						g_iGE_DucksIAR[id][0] = 0;
					}
				}
				case 2:
				{
					g_iDucksFOG[id][1]++;
					
					g_iGE_DucksIAR[id][1]++;
					
					if (g_iGE_DucksIAR[id][1] % MAX_GE_DUCKS_SESSION == 0)
						g_iGE_DucksIAR_Sessions[id][1]++;
					
					if (g_iGE_DucksIAR[id][0])
						g_iGE_DucksIAR[id][0] = 0;
					
					if (g_iGE_DucksIAR[id][2])
						g_iGE_DucksIAR[id][2] = 0;
					
					if (g_iGE_DucksIAR[id][1] > MAX_GE_DUCKS_IAR)
					{
						g_iGE_DucksWarns[id]++;
						g_iDuckWarns[id]++;
						
						if (g_iDuckWarns[id] >= MAX_DUCK_WARNINGS)
						{
							PunishPlayer(id, "GstrafeHack");
							return;
						}
						
						g_iGE_DucksIAR[id][1] = 0;
					}
				}
				case 3:
				{
					g_iDucksFOG[id][2]++;
					
					g_iGE_DucksIAR[id][2]++;
					
					if (g_iGE_DucksIAR[id][2] % MAX_GE_DUCKS_SESSION == 0)
						g_iGE_DucksIAR_Sessions[id][2]++;
					
					if (g_iGE_DucksIAR[id][0])
						g_iGE_DucksIAR[id][0] = 0;
					
					if (g_iGE_DucksIAR[id][1])
						g_iGE_DucksIAR[id][1] = 0;
					
					if (g_iGE_DucksIAR[id][2] > MAX_GE_DUCKS_IAR)
					{
						g_iGE_DucksWarns[id]++;
						g_iDuckWarns[id]++;
						
						if (g_iDuckWarns[id] >= MAX_DUCK_WARNINGS)
						{
							PunishPlayer(id, "GstrafeHack");
							return;
						}
						
						g_iGE_DucksIAR[id][2] = 0;
					}
				}
			}
			
			for (new i = 0; i < 3; i++)
				g_flGE_DucksPercent[id][i] = float(g_iDucksFOG[id][i]) / float(g_iDucks[id]) * 100.0;
			
			if (g_iDucks[id] >= DUCK_SESSION)
			{
				for (new i = 0; i < 3; i++)
				{
					if (g_flGE_DucksPercent[id][i] >= MAX_GE_DUCKS_PERCENT && g_iGE_DucksIAR_Sessions[id][i])
					{
						g_iGE_DucksWarns[id]++;
						g_iDuckWarns[id]++;
						
						if (g_iDuckWarns[id] >= MAX_DUCK_WARNINGS)
						{
							PunishPlayer(id, "GstrafeHack");
							return;
						}
					}
				}
				
				for (new i = 0; i < 3; i++)
				{
					g_iDucksFOG[id][i] = 0;
					g_iGE_DucksIAR_Sessions[id][i] = 0;
					g_flGE_DucksPercent[id][i] = 0.0;
				}
				
				g_iDucks[id] = 0;
			}
		}
	}
	else
	{
		if (iGroundFrames[id])
			iGroundFrames[id] = 0;
	}
	
	static iFramesWithoutDuckCmds[MAX_PLAYERS_ARR];
	
	if (g_iButtons[id] & IN_DUCK && ~g_iOldButtons[id] & IN_DUCK)
	{
		if (iFramesWithoutDuckCmds[id])
			iFramesWithoutDuckCmds[id] = 0;
		
		g_iDuckCmdsIAR[id]++;
		
		if (g_iDuckCmdsIAR[id] >= MAX_DUCK_CMDS_IAR)
		{
			PunishPlayer(id, "GstrafeHack");
			return;
		}
	}
	else
	{
		iFramesWithoutDuckCmds[id]++;
		
		if (iFramesWithoutDuckCmds[id] >= 5)
		{
			if (g_iDuckCmdsIAR[id])
				g_iDuckCmdsIAR[id] = 0;
		}
	}
	
	iPrevButtons[id] = g_iButtons[id];
}

public ClCmdDuckStats(id)
{
	if (~get_user_flags(id) & ADMIN_ACCESS)
	{
		client_print(id, print_console, "You have no access to that command");
		return PLUGIN_HANDLED;
	}
	
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	
	if (szArg[0] == EOS)
		return PLUGIN_HANDLED;
	
	new iPlayer = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF | CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS);
	
	if (!iPlayer)
		return PLUGIN_HANDLED;
	
	new szName[32];
	get_user_name(iPlayer, szName, MAX_NAME_LENGTH - 1);
	new szAuthID[32];
	get_user_authid(iPlayer, szAuthID, charsmax(szAuthID));
	new szIP[21];
	get_user_ip(id, szIP, charsmax(szIP), 1);
	
	client_print(id, print_console, "~ DUCK STATS ~");
	client_print(id, print_console, "Player: %s | %s | %s", szName, szAuthID, szIP);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Ducks: %d", g_iDucks[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "NSD Warnings: %d", g_iNsdWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "FOG: %d|%d|%d|%.2f | %d|%d|%d|%.2f | %d|%d|%d|%.2f | %d",
		g_iDucksFOG[iPlayer][0], g_iGE_DucksIAR[iPlayer][0], g_iGE_DucksIAR_Sessions[iPlayer][0], g_flGE_DucksPercent[iPlayer][0],
		g_iDucksFOG[iPlayer][1], g_iGE_DucksIAR[iPlayer][1], g_iGE_DucksIAR_Sessions[iPlayer][1], g_flGE_DucksPercent[iPlayer][1],
		g_iDucksFOG[iPlayer][2], g_iGE_DucksIAR[iPlayer][2], g_iGE_DucksIAR_Sessions[iPlayer][2], g_flGE_DucksPercent[iPlayer][2],
		g_iGE_DucksWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Total Duck Warns: %d", g_iDuckWarns[iPlayer]);//useless atm
	client_print(id, print_console, "~ DUCK STATS ~");
	
	return PLUGIN_HANDLED;
}