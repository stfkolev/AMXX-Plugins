/* Here you can edit main settings */

#define BHOP_DETECTION
#define DUCK_DETECTION
//#define STRAFE_DETECTION
#define FPS_DETECTION
#define CMDS_DETECTION

#define LOGGING

#define g_szPrefix "^1[^4AntiCheat^1]"

#define ADMIN_ACCESS ADMIN_BAN

#define HOST "sql7.freemysqlhosting.net"
#define USER "sql7308978"
#define PASS "XSQ2VPDYfX"
#define BASE "sql7308978"

/* Ban System
 *
 * 0 - Default  (amx_ban <#userid> <minutes> [reason])
 * 1 - Custom (*_ban <minutes> <#userid> [reason])
 */

#define BAN_SYSTEM 0

/* Here you stop */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <nvault>
#include <sqlx>

#if AMXX_VERSION_NUM < 183
	#include "colorchat"

	#define MAX_PLAYERS 32
	#define MAX_NAME_LENGTH 32
#else
	#define client_disconnect client_disconnected
#endif

#define MAX_PLAYERS_ARR MAX_PLAYERS+1

#pragma semicolon 1
#pragma tabsize 4

#define set_bit(%1,%2) (%1 |= (1<<(%2&31)))
#define get_bit(%1,%2) (%1 & (1<<(%2&31)))
#define clr_bit(%1,%2) (%1 &= ~(1<<(%2&31)))

enum _:AC_FILES
{
	Bhop,
	Gstrafe,
	Commands
}

#if defined LOGGING
	new g_szLogFile[AC_FILES][64];

	new const AC_FILES_NAME[AC_FILES][] =
	{
		"Bhop",
		"Gstrafe",
		"Commands"
	};
#endif

new g_iVault;

new g_iFlags[MAX_PLAYERS_ARR], g_iButtons[MAX_PLAYERS_ARR], g_iOldButtons[MAX_PLAYERS_ARR];
new g_bBot, g_bPunished;

// DB
new Handle:g_SqlTuple;
new g_Error[512];

new Array:authIDs;
new txtlen, bMysqld;
// -------------------

#if defined BHOP_DETECTION
#include <anticheat/ac_bhop.inl>
#endif

#if defined DUCK_DETECTION
#include <anticheat/ac_gstrafe.inl>
#endif

#if defined STRAFE_DETECTION
#include <anticheat/ac_strafe.inl>
#endif

#if defined FPS_DETECTION
#include <anticheat/ac_fps.inl>
#endif

#if defined CMDS_DETECTION
#include <anticheat/ac_commands.inl>
#endif

#define PLUGIN "[KZ] Anti Cheat"

#define VERSION "1.0"
#define AUTHOR "deniS & Fame"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar("ac_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	set_cvar_string("ac_version", VERSION);

	register_forward(FM_CmdStart, "fwdCmdStart");

	register_forward(FM_PlayerPreThink, "fwdPlayerPreThink");
	register_forward(FM_PlayerPostThink, "fwdPlayerPostThink");
	
	bMysqld = true;

	#if defined BHOP_DETECTION
		ac_bhop_init();
	#endif

	#if defined DUCK_DETECTION
		ac_gstrafe_init();
	#endif

	#if defined CMDS_DETECTION
		ac_cmds_init();
	#endif

	set_task(1.0, "MySql_Init");
}

public plugin_cfg()
{
	#if defined LOGGING
		new szLogsDir[64];
		get_localinfo("amxx_logs", szLogsDir, charsmax(szLogsDir));

		add(szLogsDir, charsmax(szLogsDir), "/anticheat");

		if (!dir_exists(szLogsDir))
			mkdir(szLogsDir);

		for (new i = 0; i < AC_FILES; i++)
			formatex(g_szLogFile[i], charsmax(g_szLogFile[]), "%s/%s.log", szLogsDir, AC_FILES_NAME[i]);
	#endif

	g_iVault = nvault_open("ac_stats");

	if (g_iVault == INVALID_HANDLE)
		log_amx("anticheat.sma: plugin_cfg:: can't open file ^"ac_stats.vault^"!");

	#if defined CMDS_DETECTION
		ac_cmds_cfg();
	#endif
}

public MySql_Init()
{
	g_SqlTuple = SQL_MakeDbTuple(HOST, USER, PASS, BASE);
	new ErrorCode,Handle:SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, charsmax(g_Error));
	
	if(SqlConnection == Empty_Handle)
		set_fail_state(g_Error);
	
	new Handle:Queries;
	Queries = SQL_PrepareQuery(SqlConnection,"CREATE TABLE IF NOT EXISTS cheaters (id INT(11) AUTO_INCREMENT UNIQUE, nickname varchar(191), steam_id varchar(191), ip varchar(191), cheat_type varchar(191), PRIMARY KEY(id))");
	
	if(!SQL_Execute(Queries))
	{
		SQL_QueryError(Queries,g_Error,charsmax(g_Error));
		set_fail_state(g_Error);
	}

	SQL_FreeHandle(Queries);
	SQL_FreeHandle(SqlConnection);
}

public client_putinserver(id)
{
	if (is_user_bot(id))
		set_bit(g_bBot, id);

	if (!get_bit(g_bBot, id) && g_iVault != INVALID_HANDLE)
	{
		new szAuthID[32];
		get_user_authid(id, szAuthID, charsmax(szAuthID));

		new szData[256], iTimeStamp;

		if (nvault_lookup(g_iVault, szAuthID, szData, charsmax(szData), iTimeStamp))
		{
			new szBhops[3], szBhopsFOG[3][3], szGE_BhopsIAR[3][3], szPerfectBhops[3], szDistrBhops[3];
			new szGE_BhopsWarns[2], szPerfectBhopsWarns[2], szDistrBhopsWarns[2], szBhopWarns[2];

			new szDucks[3], szDucksFOG[3][3], szGE_DucksIAR[3][3], szGE_DucksIAR_Sessions[3][2];
			new szNsdWarns[2], szGE_DucksWarns[2], szDuckWarns[2];

			parse(szData,
				szBhops, charsmax(szBhops),
				szBhopsFOG[0], charsmax(szBhopsFOG[]), szGE_BhopsIAR[0], charsmax(szGE_BhopsIAR[]),
				szBhopsFOG[1], charsmax(szBhopsFOG[]), szGE_BhopsIAR[1], charsmax(szGE_BhopsIAR[]),
				szBhopsFOG[2], charsmax(szBhopsFOG[]), szGE_BhopsIAR[2], charsmax(szGE_BhopsIAR[]),
				szPerfectBhops, charsmax(szPerfectBhops),
				szDistrBhops, charsmax(szDistrBhops),
				szGE_BhopsWarns, charsmax(szGE_BhopsWarns),
				szPerfectBhopsWarns, charsmax(szPerfectBhopsWarns),
				szDistrBhopsWarns, charsmax(szDistrBhopsWarns),
				szBhopWarns, charsmax(szBhopWarns),
				szDucks, charsmax(szDucks),
				szDucksFOG[0], charsmax(szDucksFOG[]), szGE_DucksIAR[0], charsmax(szGE_DucksIAR[]), szGE_DucksIAR_Sessions[0], charsmax(szGE_DucksIAR_Sessions[]),
				szDucksFOG[1], charsmax(szDucksFOG[]), szGE_DucksIAR[1], charsmax(szGE_DucksIAR[]), szGE_DucksIAR_Sessions[1], charsmax(szGE_DucksIAR_Sessions[]),
				szDucksFOG[2], charsmax(szDucksFOG[]), szGE_DucksIAR[2], charsmax(szGE_DucksIAR[]), szGE_DucksIAR_Sessions[2], charsmax(szGE_DucksIAR_Sessions[]),
				szNsdWarns, charsmax(szNsdWarns),
				szGE_DucksWarns, charsmax(szGE_DucksWarns),
				szDuckWarns, charsmax(szDuckWarns));

			g_iBhops[id] = str_to_num(szBhops);

			for (new i = 0; i < 3; i++)
			{
				g_iBhopsFOG[id][i] = str_to_num(szBhopsFOG[i]);
				g_iGE_BhopsIAR[id][i] = str_to_num(szGE_BhopsIAR[i]);
				g_flGE_BhopsPercent[id][i] = float(g_iBhopsFOG[id][i]) / float(g_iBhops[id]) * 100.0;
			}

			g_iPerfectBhops[id] = str_to_num(szPerfectBhops);
			g_flPerfectBhopsPercent[id] = float(g_iPerfectBhops[id]) / float(g_iBhops[id]) * 100.0;
			g_iDistrBhops[id] = str_to_num(szDistrBhops);
			g_flDistrBhopsPercent[id] = float(g_iDistrBhops[id]) / float(g_iBhops[id]) * 100.0;

			g_iDucks[id] = str_to_num(szDucks);

			for (new i = 0; i < 3; i++)
			{
				g_iDucksFOG[id][i] = str_to_num(szDucksFOG[i]);
				g_iGE_DucksIAR[id][i] = str_to_num(szGE_DucksIAR[i]);
				g_iGE_DucksIAR_Sessions[id][i] = str_to_num(szGE_DucksIAR_Sessions[i]);
				g_flGE_DucksPercent[id][i] = float(g_iDucksFOG[id][i]) / float(g_iDucks[id]) * 100.0;
			}

			if ((get_systime() - iTimeStamp) / 86400 < 1)
			{
				g_iGE_BhopsWarns[id] = str_to_num(szGE_BhopsWarns);
				g_iPerfectBhopsWarns[id] = str_to_num(szPerfectBhopsWarns);
				g_iDistrBhopsWarns[id] = str_to_num(szDistrBhopsWarns);
				g_iBhopWarns[id] = str_to_num(szBhopWarns);

				g_iNsdWarns[id] = str_to_num(szNsdWarns);
				g_iGE_DucksWarns[id] = str_to_num(szGE_DucksWarns);
				g_iDuckWarns[id] = str_to_num(szDuckWarns);
			}

			nvault_remove(g_iVault, szAuthID);
		}
	}
}

public client_disconnect(id)
{
	if (get_bit(g_bBot, id))
	{
		clr_bit(g_bBot, id);
		return PLUGIN_CONTINUE;
	}

	if (!get_bit(g_bPunished, id) && g_iVault != INVALID_HANDLE)
	{
		new szAuthID[32];
		get_user_authid(id, szAuthID, charsmax(szAuthID));

		new szData[256];
		formatex(szData, charsmax(szData),
			"^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^"\
			^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^" ^"%d^"",
			g_iBhops[id],
			g_iBhopsFOG[id][0], g_iGE_BhopsIAR[id][0],
			g_iBhopsFOG[id][1], g_iGE_BhopsIAR[id][1],
			g_iBhopsFOG[id][2], g_iGE_BhopsIAR[id][2],
			g_iPerfectBhops[id],
			g_iDistrBhops[id],
			g_iGE_BhopsWarns[id],
			g_iPerfectBhopsWarns[id],
			g_iDistrBhopsWarns[id],
			g_iBhopWarns[id],
			g_iDucks[id],
			g_iDucksFOG[id][0], g_iGE_DucksIAR[id][0], g_iGE_DucksIAR_Sessions[id][0],
			g_iDucksFOG[id][1], g_iGE_DucksIAR[id][1], g_iGE_DucksIAR_Sessions[id][1],
			g_iDucksFOG[id][2], g_iGE_DucksIAR[id][2], g_iGE_DucksIAR_Sessions[id][2],
			g_iNsdWarns[id],
			g_iGE_DucksWarns[id],
			g_iDuckWarns[id]);

		nvault_set(g_iVault, szAuthID, szData);
	}

	#if defined BHOP_DETECTION
		ac_bhop_disconnect(id);
	#endif

	#if defined DUCK_DETECTION
		ac_gstrafe_disconnect(id);
	#endif

	#if defined FPS_DETECTION
		ac_fps_disconnected(id);
	#endif

	if (get_bit(g_bPunished, id))
		clr_bit(g_bPunished, id);

	return PLUGIN_CONTINUE;
}

public fwdCmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id) || get_bit(g_bBot, id) || get_bit(g_bPunished, id))
		return FMRES_IGNORED;

	#if defined DUCK_DETECTION
		ac_gstrafe_CmdStart(id, uc_handle);
	#endif

	#if defined STRAFE_DETECTION
		ac_strafe_CmdStart(id, uc_handle);
	#endif

	#if defined FPS_DETECTION
		ac_fps_CmdStart(id, uc_handle);
	#endif

	return FMRES_IGNORED;
}

public fwdPlayerPreThink(id)
{
	
	if (!is_user_alive(id) || get_bit(g_bBot, id) || get_bit(g_bPunished, id))
		return FMRES_IGNORED;

	g_iFlags[id] = pev(id, pev_flags);
	g_iButtons[id] = pev(id, pev_button);
	g_iOldButtons[id] = pev(id, pev_oldbuttons);

	#if defined BHOP_DETECTION
		ac_bhop_PlayerPreThink(id);
	#endif

	#if defined DUCK_DETECTION
		ac_gstrafe_PlayerPreThink(id);
	#endif

	return FMRES_IGNORED;
}

public fwdPlayerPostThink(id)
{
	if (!is_user_alive(id) || get_bit(g_bBot, id) || get_bit(g_bPunished, id))
		return FMRES_IGNORED;

	#if defined FPS_DETECTION
		ac_fps_PlayerPostThink(id);
	#endif

	return FMRES_IGNORED;
}

public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	SQL_FreeHandle(Query);
	
	return PLUGIN_HANDLED;
}

stock PunishPlayer(id, szHack[192], iTime = 0)
{

	new SteamID[32], IPaddr[32], iTemp[512];
	get_user_authid( id, SteamID, charsmax( SteamID ) );
	get_user_ip( id, IPaddr, charsmax( IPaddr ), 1 );

	new szName[MAX_NAME_LENGTH];
	get_user_name(id, szName, MAX_NAME_LENGTH - 1);

	client_print_color(0, id, "%s^3 %s^1 is using^3 %s", g_szPrefix, szName, szHack);

	format(iTemp, charsmax(iTemp), "INSERT INTO cheaters ( nickname, steam_id, ip , cheat_type) VALUES ('%s','%s', '%s', '%s');", szName, SteamID, IPaddr, szHack);
	SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", iTemp);

	set_bit(g_bPunished, id);

	replace_all(szHack, charsmax(szHack), "^1", "");
	replace_all(szHack, charsmax(szHack), "^3", "");
	replace_all(szHack, charsmax(szHack), "^4", "");

	#if defined LOGGING
		switch (szHack[0])
		{
			case 'B':
			{
				LogPlayer(id, Bhop,
					"^n| Bhop Stats(last session) and Warnings:^n^n\
					| Bhops: %d^n\
					| GroundFrames(1): %d|%d|%.2f%%^n\
					| GroundFrames(2): %d|%d|%.2f%%^n\
					| GroundFrames(3, 4, 5): %d|%d|%.2f%%^n\
					| Perfect Bhops: %d|%.2f%%^n\
					| Ideally Distr. Bhops: %d|%.2f%%^n\
					| Jump Cmds. Ratio: %.2f^n\
					| Max Jump Cmds. IAR: %d^n^n\
					| Ground Equal Bhops Warns: %d^n\
					| Perfect Bhops Warns: %d^n\
					| Ideally Distr. Bhops Warns: %d^n\
					| Total Bhop Warnings: %d",
					g_iBhops[id],
					g_iBhopsFOG[id][0], g_iGE_BhopsIAR[id][0], g_flGE_BhopsPercent[id][0],
					g_iBhopsFOG[id][1], g_iGE_BhopsIAR[id][1], g_flGE_BhopsPercent[id][1],
					g_iBhopsFOG[id][2], g_iGE_BhopsIAR[id][2], g_flGE_BhopsPercent[id][2],
					g_iPerfectBhops[id], g_flPerfectBhopsPercent[id],
					g_iDistrBhops[id], g_flDistrBhopsPercent[id],
					g_flJumpCmdsRatio[id],
					g_iMaxJumpCmdsIAR[id],
					g_iGE_BhopsWarns[id],
					g_iPerfectBhopsWarns[id],
					g_iDistrBhopsWarns[id],
					g_iBhopWarns[id]);
			}

			case 'G':
			{
				LogPlayer(id, Gstrafe, "^n| Duck Stats(last session) and Warnings:^n^n\
					| Ducks: %d^n\
					| GroundFrames(1): %d|%d|%d|%.2f%%^n\
					| GroundFrames(2): %d|%d|%d|%.2f%%^n\
					| GroundFrames(3, 4, 5): %d|%d|%d|%.2f%%^n\
					| NSD Warns: %d^n\
					| Ground Equal Ducks Warns: %d^n\
					| Total Duck Warnings: %d",
					g_iDucks[id],
					g_iDucksFOG[id][0], g_iGE_DucksIAR[id][0], g_iGE_DucksIAR_Sessions[id][0], g_flGE_DucksPercent[id][0],
					g_iDucksFOG[id][1], g_iGE_DucksIAR[id][1], g_iGE_DucksIAR_Sessions[id][1], g_flGE_DucksPercent[id][1],
					g_iDucksFOG[id][2], g_iGE_DucksIAR[id][2], g_iGE_DucksIAR_Sessions[id][2], g_flGE_DucksPercent[id][2],
					g_iNsdWarns[id],
					g_iGE_DucksWarns[id],
					g_iDuckWarns[id]);//useless atm
			}
			case 'c'://Restricted Commands
			{
				LogPlayer(id, Commands, "^n| Bad %s", szHack);
			}
		}
	#endif

	#if defined BAN_SYSTEM 0
		server_cmd("amx_ban #%d ^"%d^" ^"%s Detected^"", get_user_userid(id), iTime, szHack);
	#else
		server_cmd("amx_ban ^"%d^" #%d ^"%s Detected^"", iTime, get_user_userid(id), szHack);
	#endif
}

#if defined LOGGING
	stock LogPlayer(id, iLogFile, szFmt[], any: ...)
	{
		new fp = fopen(g_szLogFile[iLogFile], "at");

		if (fp)
		{
			new szTime[22], szName[MAX_NAME_LENGTH], szAuthID[32], szIP[21];
			static szMessage[512];

			get_time("%m/%d/%Y - %H:%M:%S", szTime, charsmax(szTime));
			get_user_name(id, szName, MAX_NAME_LENGTH - 1);
			get_user_authid(id, szAuthID, charsmax(szAuthID));
			get_user_ip(id, szIP, charsmax(szIP), 1);

			vformat(szMessage, charsmax(szMessage), szFmt, 4);

			fprintf(fp, "+---^n| L %s: %s<%s><%s> %s^n+---^n^n", szTime, szName, szAuthID, szIP, szMessage);
			fclose(fp);
		}
		else
			log_amx("anticheat.sma: LogPlayer():: can't open file ^"%s^"!", g_szLogFile[iLogFile]);
	}
#endif

public plugin_end()
{

	SQL_FreeHandle(g_SqlTuple);
	ac_cmds_end();

	if (g_iVault != INVALID_HANDLE)
		nvault_close(g_iVault);
}
