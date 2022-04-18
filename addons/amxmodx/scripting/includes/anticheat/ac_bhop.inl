/* Here you can edit bhop detection settings */

#define BHOP_SESSION 100

#define BUNNYJUMP_MAX_SPEED_FACTOR 1.2
//#define ACT_HOP 6

// Ground Equal [g]
#define MAX_GE_BHOPS_IAR 19
#define MAX_GE_BHOPS_PERCENT 72.0

// Perfect Bhops [p]
#define MAX_PERFECTBHOPS_IAR 19
#define MAX_PERFECTBHOPS_SESSION_PERCENT 72.0

// Ideally Distributed Bhops [d]
#define MAX_DISTR_BHOPS_PERCENT 93.0

#define MAX_BHOP_WARNINGS 3

// Jump Commands IAR (+jump spam) [s]
#define MAX_JUMP_CMDS_IAR 200

// Jump Command Ratio [c]
#define MIN_JUMP_CMDS_RATIO 2.5

/* Here you stop */

/*
 *
 */

/* Total Bhops */
new g_iBhops[MAX_PLAYERS_ARR];

/* Ground Equal

 * ARRAY - FOG
 *   0   -  1
 *   1   -  2
 *   2   -  3, 4, 5
 */
new g_iBhopsFOG[MAX_PLAYERS_ARR][3];

new Float:g_flGE_BhopsPercent[MAX_PLAYERS_ARR][3];
new g_iGE_BhopsIAR[MAX_PLAYERS_ARR][3];
new g_iGE_BhopsWarns[MAX_PLAYERS_ARR];

/* Perfect Bhops */
new g_iPerfectBhops[MAX_PLAYERS_ARR];
new Float:g_flPerfectBhopsPercent[MAX_PLAYERS_ARR];
new g_iPerfectBhopsIAR[MAX_PLAYERS_ARR];
new g_iPerfectBhopsWarns[MAX_PLAYERS_ARR];

/* Ideally Distributed Bhops */
new g_bDistrBhopCheck;
new g_iDistrBhopFrames[MAX_PLAYERS_ARR];
new g_iDistrBhops[MAX_PLAYERS_ARR];
new Float:g_flDistrBhopsPercent[MAX_PLAYERS_ARR];
new g_iDistrBhopsWarns[MAX_PLAYERS_ARR];

/*
 * Ground Bhops Warnings
 * Perfect Bhops Warnings
 * Ideally distributed bhops Warnings
 */
new g_iBhopWarns[MAX_PLAYERS_ARR];

/* Jump Commands IAR (+jump spam) */
new g_iJumpCmdsIAR[MAX_PLAYERS_ARR];
new g_iMaxJumpCmdsIAR[MAX_PLAYERS_ARR];

/* Jump Commands Ratio */
new g_iJumpCmds[MAX_PLAYERS_ARR];

new Float:g_flJumpCmdsRatio[MAX_PLAYERS_ARR];

ac_bhop_init()
{
	register_clcmd("ac_bhop_stats", "ClCmdBhopStats");
}

ac_bhop_disconnect(id)
{
	g_iBhops[id] = 0;
	
	for (new i = 0; i < 3; i++)
	{
		g_iBhopsFOG[id][i] = 0;
		g_flGE_BhopsPercent[id][i] = 0.0;
		g_iGE_BhopsIAR[id][i] = 0;
	}
	g_iGE_BhopsWarns[id] = 0;
	
	g_iPerfectBhops[id] = 0;
	g_flPerfectBhopsPercent[id] = 0.0;
	g_iPerfectBhopsIAR[id] = 0;
	g_iPerfectBhopsWarns[id] = 0;
	
	clr_bit(g_bDistrBhopCheck, id);
	g_iDistrBhopFrames[id] = 0;
	g_iDistrBhops[id] = 0;
	g_flDistrBhopsPercent[id] = 0.0;
	g_iDistrBhopsWarns[id] = 0;
	
	g_iBhopWarns[id] = 0;
	
	g_iJumpCmdsIAR[id] = 0;
	g_iMaxJumpCmdsIAR[id] = 0;
	g_iJumpCmds[id] = 0;
	g_flJumpCmdsRatio[id] = 0.0;
}

ac_bhop_PlayerPreThink(id)
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

	static Float:vVelocity[3], Float:flSpeed, Float:flOldSpeed[MAX_PLAYERS_ARR], Float:flMaxSpeed, Float:flMaxPreStrafe;
	pev(id, pev_velocity, vVelocity);
	vVelocity[2] = 0.0;
	flSpeed = vector_length(vVelocity);
	pev(id, pev_maxspeed, flMaxSpeed);
	flMaxPreStrafe = flMaxSpeed * BUNNYJUMP_MAX_SPEED_FACTOR;
	
	static iGroundFrames[MAX_PLAYERS_ARR], iOldGroundFrames[MAX_PLAYERS_ARR];
	
	if (g_iFlags[id] & FL_ONGROUND)
	{
		iGroundFrames[id]++;
		
		if (g_iButtons[id] & IN_JUMP && ~g_iOldButtons[id] & IN_JUMP)
			iOldGroundFrames[id] = iGroundFrames[id];
		
		if (iGroundFrames[id] <= 5 && g_iButtons[id] & IN_JUMP && ~g_iOldButtons[id] & IN_JUMP)
		{
			g_iBhops[id]++;
			
			switch (iGroundFrames[id])
			{
				case 1:
				{
					g_iBhopsFOG[id][0]++;
					
					g_iGE_BhopsIAR[id][0]++;
					
					if (g_iGE_BhopsIAR[id][0] >= MAX_GE_BHOPS_IAR)
					{
						g_iGE_BhopsWarns[id]++;
						g_iBhopWarns[id]++;
						
						if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
						{
							PunishPlayer(id, "BhopHack");
							return;
						}
						
						g_iGE_BhopsIAR[id][0] = 0;
					}
					
					if (g_iGE_BhopsIAR[id][1])
						g_iGE_BhopsIAR[id][1] = 0;
					
					if (g_iGE_BhopsIAR[id][2])
						g_iGE_BhopsIAR[id][2] = 0;
				}
				case 2:
				{
					g_iBhopsFOG[id][1]++;
					
					g_iGE_BhopsIAR[id][1]++;
					
					if (g_iGE_BhopsIAR[id][1] >= MAX_GE_BHOPS_IAR)
					{
						g_iGE_BhopsWarns[id]++;
						g_iBhopWarns[id]++;
						
						if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
						{
							PunishPlayer(id, "BhopHack");
							return;
						}
						
						g_iGE_BhopsIAR[id][1] = 0;
					}
					
					if (g_iGE_BhopsIAR[id][0])
						g_iGE_BhopsIAR[id][0] = 0;
					
					if (g_iGE_BhopsIAR[id][2])
						g_iGE_BhopsIAR[id][2] = 0;
				}
				case 3, 4, 5:
				{
					g_iBhopsFOG[id][2]++;
					
					g_iGE_BhopsIAR[id][2]++;
					
					if (g_iGE_BhopsIAR[id][2] >= MAX_GE_BHOPS_IAR)
					{
						g_iGE_BhopsWarns[id]++;
						g_iBhopWarns[id]++;
						
						if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
						{
							PunishPlayer(id, "BhopHack");
							return;
						}
						
						g_iGE_BhopsIAR[id][2] = 0;
					}
					
					if (g_iGE_BhopsIAR[id][0])
						g_iGE_BhopsIAR[id][0] = 0;
					
					if (g_iGE_BhopsIAR[id][1])
						g_iGE_BhopsIAR[id][1] = 0;
				}
			}
			
			for (new i = 0; i < 3; i++)
				g_flGE_BhopsPercent[id][i] = float(g_iBhopsFOG[id][i]) / float(g_iBhops[id]) * 100.0;
			
			if (!get_bit(g_bDistrBhopCheck, id))
				set_bit(g_bDistrBhopCheck, id);
			
			if (flSpeed < flMaxPreStrafe && (iGroundFrames[id] == 1 || iGroundFrames[id] >= 2 && flOldSpeed[id] > flMaxPreStrafe))
			{
				g_iPerfectBhops[id]++;
				
				g_iPerfectBhopsIAR[id]++;
				
				if (g_iPerfectBhopsIAR[id] % MAX_PERFECTBHOPS_IAR == 0)
				{
					g_iPerfectBhopsWarns[id]++;
					g_iBhopWarns[id]++;
					
					if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
					{
						PunishPlayer(id, "BhopHack");
						return;
					}
				}
			}
			else
			{
				if (g_iPerfectBhopsIAR[id])
					g_iPerfectBhopsIAR[id] = 0;
			}
			
			g_flPerfectBhopsPercent[id] = float(g_iPerfectBhops[id]) / float(g_iBhops[id]) * 100.0;
			
			g_flDistrBhopsPercent[id] = float(g_iDistrBhops[id]) / float(g_iBhops[id]) * 100.0;
			
			g_flJumpCmdsRatio[id] = float(g_iJumpCmds[id]) / float(g_iBhops[id]);
			
			if (g_iBhops[id] >= BHOP_SESSION)
			{
				for (new i = 0; i < 3; i++)
				{
					if (g_flGE_BhopsPercent[id][i] >= MAX_GE_BHOPS_PERCENT)
					{
						g_iGE_BhopsWarns[id]++;
						g_iBhopWarns[id]++;
						
						if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
						{
							PunishPlayer(id, "BhopHack");
							return;
						}
					}
				}
				
				if (g_flPerfectBhopsPercent[id] >= MAX_PERFECTBHOPS_SESSION_PERCENT)
				{
					g_iPerfectBhopsWarns[id]++;
					g_iBhopWarns[id]++;
					
					if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
					{
						PunishPlayer(id, "BhopHack");
						return;
					}
				}
				
				if (g_flDistrBhopsPercent[id] >= MAX_DISTR_BHOPS_PERCENT)
				{
					g_iDistrBhopsWarns[id]++;
					g_iBhopWarns[id]++;
					
					if (g_iBhopWarns[id] >= MAX_BHOP_WARNINGS)
					{
						PunishPlayer(id, "BhopHack");
						return;
					}
				}
				
				if (!g_iBhopsFOG[id][2])
				{
					if (g_flDistrBhopsPercent[id] <= 20.0 && g_flJumpCmdsRatio[id] >= 4.5)//dc
						g_iBhopWarns[id]++;
					
					if (g_flJumpCmdsRatio[id] <= MIN_JUMP_CMDS_RATIO)//c
					{
						PunishPlayer(id, "BhopHack");
						return;
					}
				}
				
				for (new i = 0; i < 3; i++)
				{
					g_iBhopsFOG[id][i] = 0;
					g_flGE_BhopsPercent[id][i] = 0.0;
					g_iGE_BhopsIAR[id][i] = 0;
				}
				
				g_flPerfectBhopsPercent[id] = 0.0;
				
				if (g_iPerfectBhops[id])
					g_iPerfectBhops[id] = 0;
				
				g_flDistrBhopsPercent[id] = 0.0;
				
				g_iDistrBhops[id] = 0;
				
				g_iJumpCmds[id] = 0;
				
				g_flJumpCmdsRatio[id] = 0.0;
				
				g_iMaxJumpCmdsIAR[id] = 0;
				
				g_iBhops[id] = 0;
			}
		}
	}
	else
	{
		if (iGroundFrames[id])
			iGroundFrames[id] = 0;
	}
	
	static iFramesWithoutJumpCmds[MAX_PLAYERS_ARR];
	
	if (g_iButtons[id] & IN_JUMP && ~g_iOldButtons[id] & IN_JUMP)
	{
		if (iFramesWithoutJumpCmds[id])
			iFramesWithoutJumpCmds[id] = 0;
		
		g_iJumpCmdsIAR[id]++;
		
		if (g_iJumpCmdsIAR[id] > g_iMaxJumpCmdsIAR[id])
			g_iMaxJumpCmdsIAR[id] = g_iJumpCmdsIAR[id];
		
		if (g_iJumpCmdsIAR[id] >= MAX_JUMP_CMDS_IAR)
		{
			PunishPlayer(id, "BhopHack");
			return;
		}
		
		if (iOldGroundFrames[id] && iOldGroundFrames[id] <= 5)
			g_iJumpCmds[id]++;
	}
	else
	{
		iFramesWithoutJumpCmds[id]++;
		
		if (iFramesWithoutJumpCmds[id] >= 5)
		{
			if (g_iJumpCmdsIAR[id])
				g_iJumpCmdsIAR[id] = 0;
		}
	}
	
	if (iFramesWithoutJumpCmds[id] <= 1)
	{
		g_iDistrBhopFrames[id]++;
		
		if (iOldGroundFrames[id] && iOldGroundFrames[id] <= 5 && get_bit(g_bDistrBhopCheck, id) && g_iDistrBhopFrames[id] >= 8)
		{
			g_iDistrBhops[id]++;
			clr_bit(g_bDistrBhopCheck, id);
			g_iDistrBhopFrames[id] = 0;
		}
	}
	else
	{
		if (g_iDistrBhopFrames[id])
			g_iDistrBhopFrames[id] = 0;
	}
	
	flOldSpeed[id] = flSpeed;
}

public ClCmdBhopStats(id)
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
	
	client_print(id, print_console, "~ BHOP STATS ~");
	client_print(id, print_console, "Player: %s | %s | %s", szName, szAuthID, szIP);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Bhops: %d", g_iBhops[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "FOG: %d|%d|%.2f%% | %d|%d|%.2f%% | %d|%d|%.2f%% | %d",
		g_iBhopsFOG[iPlayer][0], g_iGE_BhopsIAR[iPlayer][0], g_flGE_BhopsPercent[iPlayer][0],
		g_iBhopsFOG[iPlayer][1], g_iGE_BhopsIAR[iPlayer][1], g_flGE_BhopsPercent[iPlayer][1],
		g_iBhopsFOG[iPlayer][2], g_iGE_BhopsIAR[iPlayer][2], g_flGE_BhopsPercent[iPlayer][2],
		g_iGE_BhopsWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Perfect Bhops: %d|%.2f%%|%d",
		g_iPerfectBhops[iPlayer], g_flPerfectBhopsPercent[iPlayer], g_iPerfectBhopsWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Ideally Distr. Bhops: %d|%.2f%%|%d", g_iDistrBhops[iPlayer], g_flDistrBhopsPercent[iPlayer], g_iDistrBhopsWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Total Bhop Warnings: %d", g_iBhopWarns[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Jump Cmds. Ratio: %.2f", g_flJumpCmdsRatio[iPlayer]);
	client_print(id, print_console, "~");
	client_print(id, print_console, "Max Jump Cmds. IAR: %d", g_iMaxJumpCmdsIAR[iPlayer]);
	client_print(id, print_console, "~ BHOP STATS ~");
	
	return PLUGIN_HANDLED;
}