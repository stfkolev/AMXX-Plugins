/*
 * Чисто раб под ником "дензел" делал саньку666 микс систему за сотку..
 * Но санек666 не может даже поменять коллор в коде, при этом имеет сервер уже больше 5-ти лет..
 * Санька несколько раз опускали, но он продолжает защищаться..
 * Для меня хайднсик умир, если кому-то нужна помощь по установки микс системы, то пишите vk.com/dzsad (за сотку все сделаю!)
*/

/* Прикрутил LANG файл для мультиязычности, остальное лень делать */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif
#include <colorchat>
#include <hamsandwich>
#include <fakemeta_util>
#include <fakemeta>
#include <fun>
#include <engine>
#include <player_settings_saver> // Впринципе, это можно вырезать, ибо все равно этот модуль баганный..

#include <js_natives>

#define PLUGIN "hns Match System"
#define VERSION "1.09b"
#define AUTHOR "Tranquility" // картер не имеет никакого отношения к системе

#define FASTLEAVETIMER 300.0
const m_bHasChangeTeamThisRound = 125;
const m_iNumRespawns = 365;

#define canExecuteReplace(%1) ((g_CurrentMode == e_gMix && !is_user_alive(%1)) || g_CurrentMode == e_gPaused)
#define isValidTeamTransfer(%1,%2) ((%1 == CS_TEAM_CT || %1 == CS_TEAM_T) != (%2 == CS_TEAM_CT || %2 == CS_TEAM_T) && %1 != CS_TEAM_UNASSIGNED)
#define resetHasChangedTeamThisRound(%1) (set_pdata_int(%1, m_bHasChangeTeamThisRound, get_pdata_int(%1, m_bHasChangeTeamThisRound) &~ (1 << 8)))
/* -------------------------------Настройки микс системы------------------------------- */

#define hns_ACESS ADMIN_LEVEL_F // флаг доступа. Дефолт: флаг r

new const hns_tag[16] = "HLDS"; // свой префикс для системы

#define HOOK_R 5	// Цвет хука. RED

#define HOOK_G 255	// Цвет хука. GREEN

#define HOOK_B 255	// Цвет хука. BLUE

new const g_szUseSound[] = "buttons/blip1.wav"; //	Пикалка на Е для терров, можно заменить на свой звук, но если он сторонний, то надо прекешить

/* -------------------------------Настройки микс системы------------------------------- */

#define m_bJustConnected 480
#define MAX_PLAYERS 32
#define SETTING_KNIFES "KNIFE" // Скрытие ножа
#define SETTING_EMITSOUND "EMITSOUND" // Звуки после смерти (можно вырезать)
#define SECURE_NAME_LEN 31 * 2 + 1 // Twice as long as name (31 * 2 + zero terminator) in case all 31 characters are insecure
new Float:g_flRoundTime
// new g_Captime;
new bool:SoundFx;
new bool:Survival
new bool:GameStarted;
new iCurrentSW
new iSurvivalRounds;
new Float:flSidesTime[2];
new Float:flPlayerTime[33];
new Float:flPlayerRoundTime[33];
new Float:flPlayerDisconnectTime[33];
new g_entCountDown, Float:g_flFreq, Float:g_flTimeleft
new Float:PlayNoPlay[33];
new g_pRoundTime;
new g_bShowSpeed[33 char];
new pID[33][22]
new Float:RingWidth
//new bool:SlowMo; // Если хотите, то тут можно реснуть слоумо после микса.
new disconnectedUserMenu;

enum _:SaveData
{
	save_team,
	SteamID[32],
	Float:Origin[3],
	Float:Velocity[3],
	Float:Angles[3],
	health,
	Flags,
	flashnum,
	smokenum
}

new Array:SavedState;

new bool:GameSaved;
new bool:CaptainSort;
new CaptainSide;
new Captain1;
new Captain2;
new CaptainWinner;

new Float:StartRoundTime;
new SavedTime;
new SavedFreezeTime;
#define TIME 15
#define TASK_MENUCLOSE 9001
#define TASK_PLAYERSLIST 9002
#define ROUNDENDTASK 10003
#define RINGTASK 10004
#define LEAVERTASK 20004
enum
{
	e_gTraining = 0,
	e_gCaptain,
	e_gPaused,
	e_gKnife,
	e_gMix,
	e_gPub
}

enum
{
	mode_mr,
	mode_timebased,
	mode_winter
}

new current_mode;
new gmsgMoney;

new const g_szDefaultEntities[][] = {
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"armoury_entity",
	"monster_scentist"
}

new ring_cvar;
new g_iGiveNadesTo;
new const snd_denyselect[] = "common/wpn_denyselect.wav";
new const g_szNewNadesMenu[] = "\yNeed nades?^n^n\r1. \wYes^n\r2. \wNo";
// new const g_szNewReplaceChoice[] = "\yReplace the player?^n^n\r1. \wYes^n\r2. \wNo";
/* hns_Hook_Integration */
new bool:hns_hooked[32]
new hookorigin[32][3]
/* /hns_Hook_Integration */


static const knifemodel[] = "models/v_knife.mdl" 
new alloc_KnifeModel;

const m_pPlayer = 41;
new bool:gOnOff[33];
new bool:gEmitSound[33];

const EXTRAOFFSET_WEAPONS = 4;
const m_flNextPrimaryAttack = 46;
const m_flNextSecondaryAttack = 47;

new HamHook:Player_Killed_Pre;
new Float:gCheckpoints[MAX_PLAYERS+1][2][3];

new g_CurrentMode
new g_iScore[2]
new g_iSecondHalf
new g_iMaxPlayers

new bool:g_bFreezePeriod
new bool:g_bCheckpointAlternate[MAX_PLAYERS+1];
new bool:g_bLastFlash
new bool:ishooked[MAX_PLAYERS+1];
new bool:plr_noplay[MAX_PLAYERS+1];

new Sbeam = 0
new bool:g_Spec[MAX_PLAYERS+1];
//new hDeath[MAX_PLAYERS+1] 
new CsTeams:hTeam[MAX_PLAYERS+1];

new cvarTeam[2]
new cvarMaxRounds
new cvarMaxSurRounds
new cvarFlashNum
new cvarSmokeNum
new cvarSemiclip
new cvarDefaultMode

new g_iHostageEnt, g_iRegisterSpawn
new m_spriteTexture;
new SyncHud[2]

public plugin_precache() {

	m_spriteTexture = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr");
	
	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
	g_iRegisterSpawn = register_forward(FM_Spawn, "fwdSpawn", 1)
	precache_sound( g_szUseSound );
	precache_sound("buttons/spark4.wav");
	Sbeam = precache_model("sprites/laserbeam.spr");
}

new g_msgScreenFade;
new g_msg_showtimer
new g_msg_roundtime

new iFwd_MixFinished

/*! 
 * Start Natives
 */
public plugin_natives() {
	register_library("transmix");

	register_native("isMix", "native_is_mix");
	register_native("get_current_mode", "native_get_current_mode");
	register_native("get_hiders_captain", "native_get_hiders_captain");
}
/*! 
 * End Natives
 */
public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)	
	//OrpheuRegisterHook(OrpheuGetFunction("PM_Move"),"OnPM_move");  

	g_pRoundTime 	= 	get_cvar_pointer( "mp_roundtime" );
	iFwd_MixFinished = CreateMultiForward("MixFinished_Fwd", ET_IGNORE);
	SavedState = ArrayCreate(SaveData);
	register_clcmd("say",                   "sayHandle");
	
	// g_Captime = register_cvar( "hns_wintime", "15");
	
	/* Mode */
	register_concmd("say /pub", "hns_pub", hns_ACESS)
	register_concmd("say /def", "hns_pub_off", hns_ACESS)
	
	/* Settings Commands*/
	register_concmd("say /skill", "hns_skill", hns_ACESS )
	register_concmd("say /boost", "hns_boost", hns_ACESS )
	register_concmd("say /aa10", "hns_aa10", hns_ACESS )
	register_concmd("say /aa100", "hns_aa100", hns_ACESS )
	//register_concmd("say /mr5", "hns_mr5", hns_ACESS )
	//register_concmd("say /mr7", "hns_mr7", hns_ACESS )
	//register_concmd("say /mr9", "hns_mr9", hns_ACESS )
	
	register_clcmd( "say /rr", "CmdRestartRound",  hns_ACESS )
	register_clcmd( "say /swap", "hns_swap_teams",  hns_ACESS)
	register_clcmd("say /replace", "cmdReplace");
		
	/* hns_Hook_Integration */
	register_clcmd("+hook","hns_hook_on")
	register_clcmd("-hook","hns_hook_off")

	/* HideNSeek Commands */
	register_clcmd ( "say /knife", "cmdShowKnife");
	register_clcmd ( "say /showknife", "cmdShowKnife");
	register_clcmd ( "say /hideknife", "cmdShowKnife");
	
	/* Pause / UnPause */
	register_clcmd( "say /pause", "hns_startpause", hns_ACESS );
	//register_clcmd( "say /live", "hns_unpause", hns_ACESS );

	register_clcmd ( "say /mix", "dang_mix_menu", hns_ACESS )
	register_clcmd ( "say /cw", "dang_mix_menu", hns_ACESS )
	//register_clcmd ( "say /mr", "hns_mr_menu", hns_ACESS )
	register_clcmd ( "say /settime", "hns_timer_menu", hns_ACESS )
	register_clcmd ( "say /aa", "hns_aa_menu", hns_ACESS )
	register_clcmd ( "say /type", "hns_semi_menu", hns_ACESS )
	register_clcmd ( "say /trans", "hns_trans_menu", hns_ACESS )
	register_clcmd ( "say /mode", "hns_mode_menu", hns_ACESS )
	register_clcmd ( "say /mod", "hns_mod_menu", hns_ACESS )

	register_clcmd( "chooseteam", "BlockCmd" ); /* block cmd case team completed */
	register_clcmd( "jointeam", "BlockCmd" );
	register_clcmd( "joinclass", "BlockCmd" );
	
	fnRegisterSayCmd("protraction", "protractionmod", "hns_timer", hns_ACESS, "Protraction mode");
	fnRegisterSayCmd("normal", "normalmod", "hns_normal", hns_ACESS, "Normal mode");
	fnRegisterSayCmd("winter", "wintt", "hns_wintt", hns_ACESS, "Normal mode");	
	fnRegisterSayCmd("specall", "specall", "hns_transfer_spec", hns_ACESS, "Spec Transfer")
	fnRegisterSayCmd("ttall", "ttall", "hns_transfer_tt", hns_ACESS, "TT Transfer")
	fnRegisterSayCmd("ctall", "ctall", "hns_transfer_ct", hns_ACESS, "CT Transfer")
	fnRegisterSayCmd("score", "s", "Score", 0, "Starts Round")
	fnRegisterSayCmd("ps", "personalscore", "PersonalScore", 0, "Personal Time")
	fnRegisterSayCmd("startmix", "start", "cmdStartRound", hns_ACESS, "Starts Round");
	fnRegisterSayCmd("kniferound", "kf", "cmdKnifeRound", hns_ACESS, "Knife Round");
	fnRegisterSayCmd("captain", "cap", "CaptainCmd", hns_ACESS, "Captain Mode");
	fnRegisterSayCmd("stopcaptain", "stopcap", "StopCaptainCmd", hns_ACESS, "Captain Mode");
	fnRegisterSayCmd("stop", "stop", "cmdStop", hns_ACESS, "Stop Current Mode");
	fnRegisterSayCmd("live", "unpause", "hns_unpause", hns_ACESS, "UnPause");
	fnRegisterSayCmd("checkpoint", "cp", "cmdCheckpoint", 0, "Save checkpoint");
	//fnRegisterSayCmd("savegame", "sg", "cmdsavegame", hns_ACESS, "Save game");
	//fnRegisterSayCmd("loadgame", "lg", "cmdloadgame", hns_ACESS, "Load saved game");
	fnRegisterSayCmd("gocheck", "gc", "cmdGoCheck", 0, "Go to checkpoint");
	fnRegisterSayCmd("teleport", "tp", "cmdGoCheck", 0, "Go to checkpoint");	
	fnRegisterSayCmd("pick", "pick", "captain_menu", 0, "Pick player");
	//fnRegisterSayCmd( "\yНазад", "spec", "team_spec", 0, "Spec/Back player");
	//fnRegisterSayCmd("myrank", "rank", "CmdRank", 0, "Starts Round")
	//fnRegisterSayCmd("newpts", "npts", "CmdPrognoz", 0, "New Pts")
	//fnRegisterSayCmd("b", "balance", "CmdBalance", 0, "Balance Pts")
	fnRegisterSayCmd("np", "noplay", "CmdNoPlay", 0, "No play")
	fnRegisterSayCmd("ip", "play", "CmdPlay", 0, "Play play")
	fnRegisterSayCmd("play", "play", "CmdPlay", 0, "Play play")
	//fnRegisterSayCmd("dontcap", "nocap", "CmdNoCaptain", 0, "Balance Pts")	
	//fnRegisterSayCmd("pts", "top", "Show_Top", 0, "Show Top")
	
	alloc_KnifeModel	 = engfunc(EngFunc_AllocString, knifemodel)
	
	ring_cvar 		 = register_cvar("hns_ring", "0", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarTeam[0] 		 = register_cvar("hns_team1", "CT", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarTeam[1] 		 = register_cvar("hns_team2", "TT", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarFlashNum 		 = register_cvar("hns_flash", "2", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarSmokeNum		 = register_cvar("hns_smoke", "1", FCVAR_ARCHIVE|FCVAR_SERVER) 
	cvarMaxRounds		 = register_cvar("hns_rounds", "6", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarMaxSurRounds     = register_cvar("hns_surv_rounds", "10", FCVAR_ARCHIVE|FCVAR_SERVER)
	cvarSemiclip 	     	 = register_cvar("hns_semiclip", "0", FCVAR_ARCHIVE|FCVAR_SERVER) 
	cvarDefaultMode		 = register_cvar("hns_defaultmode", "0", FCVAR_ARCHIVE|FCVAR_SERVER) 
	register_event("CurWeapon", "eCurWeapon", "be", "1!0")		
	//gisterControl( RC_RoundEnd, "eEndRound", 0 );
	register_event("SendAudio","eEndRound","a","2=%!MRAD_terwin","2=%!MRAD_ctwin")
	register_event("HLTV", "ePreFT", "a", "1=0", "2=0") // Detect freezetime started
	register_logevent("ePostFT", 2, "0=World triggered", "1=Round_Start") // Detect freezetime ended	
	
	Player_Killed_Pre = RegisterHam( Ham_Killed, "player", "fwd_PlayerKilled_Pre", 0 );
	RegisterHam( Ham_Spawn, "player", "CBasePlayer_Spawn_Post", true)	
	RegisterHam( Ham_Item_Deploy, "weapon_knife", "FwdDeployKnife", 1 )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_knife", "FwdKnifePrim" );
	register_forward(FM_Voice_SetClientListening, "Forward_SetClientListening");
	register_forward( FM_EmitSound, "fwd_EmitSound_Pre", 0 );
	
	unregister_forward(FM_Spawn, g_iRegisterSpawn, 1)

	register_forward(FM_PlayerPreThink, "preThink")
	register_forward(FM_PlayerPostThink, "postThink")

	register_forward(FM_AddToFullPack, "addToFullPack", 1)
	register_menucmd( register_menuid( "NadesMenu" ), 3, "HandleNadesMenu" );
	
	g_msg_showtimer	= get_user_msgid("ShowTimer")
	g_msg_roundtime	= get_user_msgid("RoundTime")

	g_iMaxPlayers = get_maxplayers()
	SyncHud[0] = CreateHudSyncObj()
	SyncHud[1] = CreateHudSyncObj()

	register_message( get_user_msgid( "ShowMenu" ), "message_show_menu" );
	register_message( get_user_msgid( "VGUIMenu" ), "message_vgui_menu" );
	g_msgScreenFade = get_user_msgid("ScreenFade");
	register_message( g_msgScreenFade, "msg_ScreenFade" );
	register_message( get_user_msgid( "TextMsg" ), "msgTextMsg" );
	
	set_msg_block(get_user_msgid("HudTextArgs"),BLOCK_SET);

	register_mode();
	ePreFT();
	PrepareMode(e_gPub);
	
	set_msg_block(gmsgMoney = get_user_msgid("Money"), BLOCK_SET);
	set_task(0.1, "ShowSpeedAsMoney", 15671983, .flags="b");
	
	if(!(get_pcvar_num(cvarDefaultMode)))
	{
		current_mode = mode_timebased
	}
	else
	{
		current_mode = mode_mr
	}
	register_dictionary("mixsystem.txt")
}

/*! 
 * Start Natives
 */

 public native_is_mix(iPlugin, iParams) {
	 return g_CurrentMode == e_gMix;
 }

 public native_get_current_mode(iPlugin, iParams) {
	 return cvarSemiclip;
 }

 public native_get_hiders_captain(iPlugin, iParams) {
	 if(is_user_connected(Captain1) || is_user_connected(Captain2)) 
		return (cs_get_user_team(Captain1) == CS_TEAM_T ? Captain1 : Captain2);
 }

public ClCmd_Speed(id)
{
	g_bShowSpeed{id} = !g_bShowSpeed{id};
}

public ShowSpeedAsMoney()
{
	if(Survival)
	{
		static players[32], num, id
		get_players(players, num, "a");
		for(--num; num>=0; num--)
		{
			id = players[num];

			if( g_bShowSpeed{id} )
			{		
				message_begin(MSG_ONE, gmsgMoney, .player=id);
				//write_long( floatround((get_pcvar_float(g_Captime)*60.0)-flSidesTime[iCurrentSW], floatround_floor) );
				write_long(floatround(flSidesTime[iCurrentSW], floatround_floor));
				write_byte(0);
				message_end();
			}
		}
	}
}

/*! Replace */

public cmdReplace(const id)
{
	if (g_CurrentMode != e_gMix)
	{
		return PLUGIN_CONTINUE;
	}
   
	if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	{
		client_print_color(id, print_team_red, "^3You can not execute this command as a spectator");
	}
	else if (!canExecuteReplace(id))
	{
		client_print_color(id, print_team_red, "^3You must be dead or the game must be paused in order to replace");
	}
	else
	{
		displayReplaceMenu(id);
	}
   
	return PLUGIN_HANDLED;
}


displayReplaceMenu(const id)
{
	new hMenu = menu_create("\rSelect a player to replace with:", "replaceMenuHandler");
	new disableCallBack = menu_makecallback("replaceMenuCallBack");
	menu_additem(hMenu, "Refresh menu", "R", 0, _);
   
	new aPlayers[MAX_PLAYERS], iPlayerCount;
	get_players(aPlayers, iPlayerCount, "ch");
   
	for (new i; i < iPlayerCount; i++)
	{
		static szUserName[48], szUserId[32];
		new playerId = aPlayers[i];
	   
		if (cs_get_user_team(playerId) != CS_TEAM_SPECTATOR)
		{
			continue;
		}
	   
		get_user_name(playerId, szUserName, charsmax(szUserName));
	   
		if (plr_noplay[playerId])
		{
			formatex(szUserName, charsmax(szUserName), "%s[Not playing]", szUserName);
		}
	   
		formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(playerId));
 
		menu_additem(hMenu, szUserName, szUserId, 0, disableCallBack);
	}
   
	menu_display(id, hMenu, 0);
}
 
public replaceMenuHandler(const id, const hMenu, const item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}
   
	new selectedPlayerId = getSelectedPlayerInMenu(hMenu, item);
	new selectedCharacter = getSelectedCharacter(hMenu, item);
	menu_destroy(hMenu);
   
	new CsTeams:iNewTeam = cs_get_user_team(id);
   
	if (iNewTeam == CS_TEAM_SPECTATOR || !canExecuteReplace(id))
	{
		static szName[32];
		get_user_name(id, szName, charsmax(szName));
		client_print_color(id, print_team_grey, "Sent replace request to ^3%s", szName);
	   
		return PLUGIN_HANDLED;
	}
   
	if (selectedCharacter == 'R')
	{
	}
	else if (selectedPlayerId && isValidTeamTransfer(cs_get_user_team(selectedPlayerId), iNewTeam))
	{
		static szName[32];
		get_user_name(selectedPlayerId, szName, charsmax(szName));
		client_print_color(id, print_team_grey, "Sent replace request to ^3%s", szName);
	   
		displayReplaceRequestMenu(selectedPlayerId, id);
		return PLUGIN_HANDLED;
	}
	else
	{
		client_print_color(id, print_team_red, "^3Can not replace with the selected player");
	}
   
	displayReplaceMenu(id);
   
	return PLUGIN_HANDLED;
}
 
public replaceMenuCallBack(const id, const hMenu, const item)
{
	getSelectedPlayerInMenu(hMenu, item);
   
	return ITEM_ENABLED;
}
 
displayReplaceRequestMenu(const id, const replaceWithId)
{
	static szMenuTitle[32], szUserId[32];
   
	get_user_name(replaceWithId, szUserId, charsmax(szUserId));
	formatex(szMenuTitle, charsmax(szMenuTitle), "\rReplace %s?", szUserId);
   
	formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(replaceWithId));
   
	new hMenu = menu_create(szMenuTitle, "replaceRequestMenuHandler");
   
	menu_additem(hMenu, "Accept", szUserId, 0);
	menu_additem(hMenu, "Reject", szUserId, 0);
   
	menu_display(id, hMenu, 0);
}
 
public replaceRequestMenuHandler(const id, const hMenu, const item)
{
	new selectedPlayerId = getSelectedPlayerInMenu(hMenu, item);
	menu_destroy(hMenu);
   
	if (item == MENU_EXIT || !selectedPlayerId)
	{
		return PLUGIN_HANDLED;
	}
   
	new CsTeams:iNewTeam = cs_get_user_team(selectedPlayerId);
   
	if (!isValidTeamTransfer(cs_get_user_team(id), iNewTeam) || !isValidTeamTransfer(iNewTeam, CS_TEAM_SPECTATOR) || !canExecuteReplace(selectedPlayerId))
	{
		return PLUGIN_HANDLED;
	}
	else if (item == 1)
	{
		static szName[32];
		get_user_name(id, szName, charsmax(szName));
		client_print_color(selectedPlayerId, print_team_red, "^3%s rejected your replace request", szName);
	   
		return PLUGIN_HANDLED;
	}
   
	instantPlayerTransfer(id, iNewTeam, 0);
	instantPlayerTransfer(selectedPlayerId, CS_TEAM_SPECTATOR, 0);
   
	new szName1[32], szName2[32];
	get_user_name(id, szName1, charsmax(szName1));
	get_user_name(selectedPlayerId, szName2, charsmax(szName2));
   
	ColorChat(0, getTeamColor(iNewTeam), "^3%s ^1replaced ^3%s", szName1, szName2);
   
	return PLUGIN_HANDLED;
}
/*! End Replace */

public hns_timer(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED;

	if(g_CurrentMode == e_gTraining)
	{		
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "MODE_TIMER", hns_tag, sz_name);
		current_mode = mode_timebased;
		iSurvivalRounds = 1;
		set_pcvar_num(cvarDefaultMode, 0);
	}
	else
	{
		client_print_color(id, id, "%L", LANG_PLAYER, "MODE_CANNOT", hns_tag);
	}
	
	return PLUGIN_CONTINUE;
}

public hns_wintt(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED;

	if(g_CurrentMode == e_gTraining)
	{		
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "MODE_ONEXONE", hns_tag, sz_name)
		current_mode = mode_winter
		set_pcvar_num(cvarDefaultMode, 0);
		set_pcvar_num(cvarMaxRounds, 3);
	}
	else
	{
		client_print_color(id, id, "%L", LANG_PLAYER, "MODE_CANNOT", hns_tag);
	}
	
	return PLUGIN_CONTINUE;
}

public hns_normal(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED;
		
	if(g_CurrentMode == e_gTraining)
	{		
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "MODE_MR", hns_tag, sz_name)
		current_mode = mode_mr
		set_pcvar_num(cvarDefaultMode, 1);
	}
	else
	{
		client_print_color(id, id, "%L", LANG_PLAYER, "MODE_CANNOT", hns_tag);
	}
	
	return PLUGIN_CONTINUE;
}

public CmdNoPlay(id)
{
	//if(get_gametime() > PlayNoPlay[id])
	if(!plr_noplay[id])
	{
		//PlayNoPlay[id] = get_gametime()+60.0;
		plr_noplay[id] = true;
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "STATUS_NOPLAY", hns_tag, sz_name)
	}
}

public CmdPlay(id)
{
	//if(get_gametime() > PlayNoPlay[id])
	if(plr_noplay[id])
	{	
	//	PlayNoPlay[id] = get_gametime()+60.0;
		plr_noplay[id] = false;
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "STATUS_PLAY", hns_tag, sz_name);
	}
}


public sayHandle(id)
{
	new szArgs[64];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);
	
	if ( !szArgs[0] )
		return PLUGIN_HANDLED;
	
	if ( szArgs[0] != '/' )
		return PLUGIN_CONTINUE;
	
	
	//Command
	new szTarget[32];
	
	parse(szArgs,\
	szArgs, charsmax(szArgs),\
	szTarget, charsmax(szTarget));
	if ( equali(szArgs, "/namett", 6) )
	{
		trim(szTarget);
		
		if(!(get_user_flags(id) & hns_ACESS))
			return PLUGIN_HANDLED;
			
		
		set_pcvar_string(cvarTeam[1], szTarget);
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "SET_NAMETT", hns_tag, sz_name, szTarget);			
	
		return PLUGIN_CONTINUE;
	}
	if ( equali(szArgs, "/namect", 6) )
	{
		trim(szTarget);
		
		if(!(get_user_flags(id) & hns_ACESS))
			return PLUGIN_HANDLED;
			
		
		set_pcvar_string(cvarTeam[0], szTarget);
		new sz_name[64]; get_user_name(id, sz_name, 63);
		client_print_color(0, print_team_red, "%L", LANG_PLAYER, "SET_NAMECT", hns_tag, sz_name, szTarget);			
	
		return PLUGIN_CONTINUE;
	}
	if ( equali(szArgs, "/mr", 2) )
	{
		trim(szTarget);
		
		if(!(get_user_flags(id) & hns_ACESS))
			return PLUGIN_HANDLED;
			
		if(is_str_num(szTarget))
		{
			set_pcvar_num(cvarMaxRounds, str_to_num(szTarget));
			new sz_name[64]; get_user_name(id, sz_name, 63);
			client_print_color(0, print_team_red, "%L", LANG_PLAYER, "SET_MR", hns_tag, sz_name, str_to_num(szTarget));			
		}
		return PLUGIN_CONTINUE;
	}
	if ( equali(szArgs, "/srounds", 7) )
	{
		trim(szTarget);
		
		if(!(get_user_flags(id) & hns_ACESS))
			return PLUGIN_HANDLED;
			
		if(is_str_num(szTarget))
		{
			if(str_to_num(szTarget) % 2 == 0) {

				set_pcvar_num(cvarMaxSurRounds, str_to_num(szTarget));

				new sz_name[64]; get_user_name(id, sz_name, 63);

				client_print_color(0, print_team_red, "%L", LANG_PLAYER, "SET_ROUNDS", hns_tag, sz_name, str_to_num(szTarget));		
			} else {
				client_print_color(id, print_team_red, "^1The rounds must be an ^4even number^1! ^1Example:^4 20 ^1-^4 16 ^1...");	
			}	
		}
		return PLUGIN_CONTINUE;
	}
	
	if ( !equali(szArgs, "/rank", 4) )
		return PLUGIN_CONTINUE;
	//Command
	
	
	//Delay
	new Float:fCommandDelay = 5.0;
	
	static Float:fCommandUsed[MAX_PLAYERS+1];
	
	if ( fCommandUsed[id] > get_gametime() )
	{
		return PLUGIN_HANDLED;
	}
	//Delay
	
	fCommandUsed[id] = get_gametime()+fCommandDelay;
	//Display
	
	
	return PLUGIN_CONTINUE;
}

public msg_ScreenFade( iMsgId, iMsgDest, id )
{
	if(is_user_connected(id))
	{
		if( get_msg_arg_int( 4 ) == 255 && get_msg_arg_int( 5 ) == 255 && get_msg_arg_int( 6 ) == 255)
		{
			if((cs_get_user_team(id) == CS_TEAM_T) || (cs_get_user_team(id) == CS_TEAM_SPECTATOR))
			{
				return PLUGIN_HANDLED;
			}
		}
	}
	return PLUGIN_CONTINUE;
}

public message_show_menu( msgid, dest, id )
{
	if ( !should_autojoin( id ) )
		return(PLUGIN_CONTINUE);

	static	team_select[] = "#Team_Select";
	static	menu_text_code[sizeof team_select];
	get_msg_arg_string( 4, menu_text_code, sizeof menu_text_code - 1 );
	if ( !equal( menu_text_code, team_select ) )
		return(PLUGIN_CONTINUE);
	
	set_force_team_join_task( id, msgid );
	
	return(PLUGIN_HANDLED);
}


public message_vgui_menu( msgid, dest, id )
{
	if ( get_msg_arg_int( 1 ) != 2 || !should_autojoin( id ) )
		return(PLUGIN_CONTINUE);

	set_force_team_join_task( id, msgid );	

	return(PLUGIN_HANDLED);
}


bool:should_autojoin( id )
{
	return(!get_user_team( id ) && !task_exists( id ) );
}


set_force_team_join_task( id, menu_msgid )
{
	static param_menu_msgid[2];
	param_menu_msgid[0] = menu_msgid;
	set_task( 0.1, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid );
}


public task_force_team_join( menu_msgid[], id )
{
	if ( get_user_team( id ) )
		return;

	force_team_join( id, menu_msgid[0], "5", "5" );
}


stock force_team_join( id, menu_msgid, /* const */ team[] = "5", /* const */ class[] = "0" )
{
	static jointeam[] = "jointeam";
	if ( class[0] == '0' )
	{
		engclient_cmd( id, jointeam, team );
		return;
	}

	static msg_block, joinclass[] = "joinclass";
	msg_block = get_msg_block( menu_msgid );
	set_msg_block( menu_msgid, BLOCK_SET );
	engclient_cmd( id, jointeam, team );
	engclient_cmd( id, joinclass, class );
	set_msg_block( menu_msgid, msg_block );
	respawn_player( id );
}


public respawn_player( id )
{
	if ( is_user_connected( id ) )
	{
		/* Make the engine think he is spawning */
		set_pev( id, pev_deadflag, DEAD_RESPAWNABLE );
		set_pev( id, pev_iuser1, 0 );
		dllfunc( DLLFunc_Think, id );

		/* Move his body so if corpse is created it is not in map */
		engfunc( EngFunc_SetOrigin, id, Float:{ -4800.0, -4800.0, -4800.0 } );

		/* Actual Spawn */
		set_task(0.1, "spawnagain", id);
	}
}

public spawnagain( id )
{
	/* Make sure he didn't disconnect in the 0.5 seconds that have passed. */
	if ( is_user_connected( id ) )
	{
		new bool:SortTeams = false;
		/* Spawn player */
		if(g_CurrentMode != e_gPub)
		{
			spawn( id );
			dllfunc( DLLFunc_Spawn, id );
		}
		if((file_exists("addons/amxmodx/data/playerslist.ini")))
		{
			new szMap[64]
			get_mapname(szMap, 63);
			if(containi(szMap, "valkyrie") != -1)
			{
				SortTeams = false;
			}
			else
			{
				SortTeams = true;
				if(task_exists(92271))
					remove_task(92271)
					
				set_task(5.0, "remove_file", 92271);
			}
		}
		if(( g_CurrentMode != e_gTraining && g_CurrentMode != e_gPub ) || SortTeams)
		{
			if(!CheckPlayer(id))
			{
				user_silentkill( id );
				cs_set_user_team( id, CS_TEAM_SPECTATOR );
			}
			else
			{
				spawn( id );
				dllfunc( DLLFunc_Spawn, id );
			}
		}


		/*
		 * After 1.0 the player will be spawned fully and you can mess with the ent (give weapons etc)
		 * set_task(1.0,"player_fully_spawned",id)
		 */
	}
}
public remove_file( )
{
	if(file_exists("addons/amxmodx/data/playerslist.ini"))
		delete_file("addons/amxmodx/data/playerslist.ini");
}

public BlockCmd(id)
{
	if ( g_CurrentMode != e_gTraining )
	{
		return(PLUGIN_HANDLED);
	}
	return(PLUGIN_CONTINUE);
}

public msgTextMsg( const MsgId, const MsgDest, const MsgEntity )
{ 
	static szMessage[ 9 ];
	get_msg_arg_string( 2, szMessage, 8 );

	if( szMessage[ 1 ] == 'C' ) // #CTs_Win
	{
		for( new i = 1; i <= 32; i++ )
		{
			if( g_Spec[i] )
			{
				if( hTeam[i] == CS_TEAM_CT ) hTeam[i] = CS_TEAM_T;
				else hTeam[i] = CS_TEAM_CT;
			}
		}
	}
}

/*public team_spec(id)
{
	if(g_CurrentMode != e_gPub)
		return PLUGIN_HANDLED;
		
	if (g_Spec[id])
	{
		cs_set_user_team(id, hTeam[id]);
		cs_set_user_deaths(id, hDeath[id]);
		g_Spec[id] = false
	}
	else
	{
		if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
			return PLUGIN_HANDLED;
			
		hDeath[id] = cs_get_user_deaths(id);
		hTeam[id] = cs_get_user_team(id);
		if (is_user_alive(id))
			cs_set_user_deaths(id, hDeath[id] - 1);
		cs_set_user_team(id, CS_TEAM_SPECTATOR);
		user_silentkill(id);
		g_Spec[id] = true
	}

	return PLUGIN_HANDLED;
}*/

public fwd_EmitSound_Pre( id, iChannel, szSample[], Float:volume, Float:attenuation, fFlags, pitch )
{
	if( equal( szSample, "weapons/knife_deploy1.wav") )
	{
		return FMRES_SUPERCEDE;
	}
			
	if( is_user_alive( id ) && cs_get_user_team(id) == CS_TEAM_T && equal( szSample, snd_denyselect ) )
	{
		emit_sound( id, iChannel, g_szUseSound, volume, attenuation, fFlags, pitch );
		return FMRES_SUPERCEDE;
	} 
	else if(is_user_alive( id ) && cs_get_user_team( id ) == CS_TEAM_CT && equal( szSample, snd_denyselect )) 
	{
		emit_sound(id, iChannel, "buttons/spark4.wav", volume, attenuation, fFlags, pitch);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public fwd_PlayerKilled_Pre( id )
{

	if( cs_get_user_team(id) != CS_TEAM_T )
		return;
		
	new players[32], num, index;

	flPlayerTime[id] += 0.25;
	flPlayerRoundTime[id] += 0.25;

	get_players(players, num, "ae", "TERRORIST");
	if( num == 1 )
	{
		g_bLastFlash = true;
		index = players[0];
		g_iGiveNadesTo = index;
		show_menu( index, 3, g_szNewNadesMenu, -1, "NadesMenu" );
		DisableHamForward( Player_Killed_Pre );
	}
}

public HandleNadesMenu( id, key )
{
	if( !g_bLastFlash || id != g_iGiveNadesTo || !is_user_alive( id ) ) 
		return;
		
	if( !key )
	{
		
		if( user_has_weapon( id, CSW_SMOKEGRENADE ) )
		{
			ExecuteHam( Ham_GiveAmmo, id, 1, "SmokeGrenade", 1024 );
		}
		else
			give_item(id, "weapon_smokegrenade");

		if( user_has_weapon( id, CSW_FLASHBANG ) )
		{
			ExecuteHam( Ham_GiveAmmo, id, 2, "Flashbang", 1024 );
		}
		else
			give_item(id, "weapon_flashbang");
	}
	g_bLastFlash = false;
	g_iGiveNadesTo = 0;
	
}

public fwdSpawn(entid) {	
	static szClassName[32];
	if(pev_valid(entid)) 	
	{
		pev(entid, pev_classname, szClassName, 31);
		if(equal(szClassName, "func_buyzone")) engfunc(EngFunc_RemoveEntity, entid);
		
		for(new i = 0; i < sizeof g_szDefaultEntities; i++) 		
		{
			if(equal(szClassName, g_szDefaultEntities[i]))			
			{
				engfunc(EngFunc_RemoveEntity, entid);
				break;
			}
		}
	}
}

public register_mode()
{
	g_iHostageEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"));
	set_pev(g_iHostageEnt, pev_origin, Float:{ 0.0, 0.0, -55000.0 });
	set_pev(g_iHostageEnt, pev_size, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
	dllfunc(DLLFunc_Spawn, g_iHostageEnt);	
}

public hns_hud_paused() 
{	
	if(g_CurrentMode == e_gPaused)
	{
		Task_Hud(0, 1.0, 1, 240, 105, 0, 0.5, "MATCH PAUSED");
	}
}

public hns_startpause(id, level, cid) 
{
	if(cmd_access(id, level, cid, 1) && g_CurrentMode == e_gMix && g_CurrentMode != e_gPaused) 
	{	
		g_CurrentMode = e_gPaused
		
		if(current_mode != mode_mr)
		{
			if(GameStarted)
			{
				flSidesTime[iCurrentSW] -= g_flRoundTime;
				flPlayerTime[id] -= g_flRoundTime;
				flPlayerRoundTime[id] == g_flRoundTime;

				new szName[64]
				get_user_name(id, szName, 63)
				client_print_color (0, print_team_red, "%L", LANG_PLAYER, "GAME_PAUSED", hns_tag, szName);
				server_cmd("sv_restart 1")
				Survival = false;
				GameStarted = false;	
			}
			else
			{
				client_print_color (id, print_team_red, "%L", LANG_PLAYER, "GAME_NOTSTARTED", hns_tag);
			}
		}
		
		set_task(0.5, "hns_hud_paused", _, _, _, "b")

		//server_cmd("amxx unpause uq_jumpstats.amxx")
		//server_cmd("amxx unpause training_menu.amxx")
		server_cmd("sv_restart 1")
		//server_cmd("hns_alltalk 1");
		server_cmd("mp_freezetime 0")		
	}
	return PLUGIN_HANDLED
}

public hns_unpause(id, level, cid) 
{
	if(cmd_access(id, level, cid, 1) && g_CurrentMode == e_gPaused) 
	{	
		g_CurrentMode = e_gMix		
		if(current_mode != mode_mr)
			GameStarted = true;
		
		Task_Hud(0, 2.0, 1, 0, 100, 240, 3.0, "LIVE LIVE LIVE");
		
		server_cmd("sv_restart 1")
		//server_cmd("amxx pause training_menu.amxx")
		//server_cmd("hns_alltalk 0");
		server_cmd("mp_freezetime 15")
		remove_hook(id)
	}
	return PLUGIN_HANDLED
}

public hns_swap_teams(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hns_name[32]
	get_user_name(id, hns_name, charsmax(hns_name))
	client_print_color(0, id, "%L", LANG_PLAYER, "GAME_SWAP", hns_tag, hns_name)
	
	SwitchTeams()
	server_cmd("sv_restart 1")
	
	return PLUGIN_HANDLED
}

public CmdRestartRound(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	client_print_color(0, id, "%L", LANG_PLAYER, "GAME_RESTART", hns_tag, hns_name)
	RingWidth = 2300.0;
	RestartRound();

	return PLUGIN_HANDLED
}


/* Commands for management */
/* Commands for management */
/* Commands for management */
public hns_pub(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	
	if(g_CurrentMode != e_gPub) 
	{
		if(g_CurrentMode != e_gMix && g_CurrentMode != e_gKnife) {
			PrepareMode(e_gPub);
			client_print_color(0, id, "%L", LANG_PLAYER, "MODE_PUB", hns_tag, hns_name)
		}
	} else 
	client_print_color(id, id, "%L", LANG_PLAYER, "PUB_ALREADY", hns_tag, hns_name)
	
	remove_hook(id)
	
	return PLUGIN_HANDLED
}

public hns_pub_off(id, level, cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	
	if(g_CurrentMode == e_gPub) 
	{
		if(g_CurrentMode != e_gMix && g_CurrentMode != e_gKnife) {
			g_CurrentMode = e_gTraining;
			
			//server_cmd("semiclip_option team 0")
			server_cmd("mp_forcechasecam 2")
			server_cmd("mp_forcecamera 2")
			server_cmd("hns_switch 0")
			server_cmd("hns_training 1")
			server_cmd("hns_footsteps 0")
			server_cmd("mp_roundtime 3")
			server_cmd("mp_freezetime 0")
			server_cmd("hns_flash 3")
			server_cmd("mp_autoteambalance 0")
			server_cmd("hns_join_team 1")
			server_cmd("hns_block_change 0")
			server_cmd("sv_restart 1")
			
			client_print_color(0, id, "%L", LANG_PLAYER, "PUB_DISABLED", hns_tag, hns_name)
		}
	} else 
	client_print_color(id, id, "%L", LANG_PLAYER, "PUB_NOTRUNNING", hns_tag, hns_name)
	
	remove_hook(id)
	
	return PLUGIN_HANDLED
}

public hns_transfer_spec(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED
	
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	client_print_color( 0, id, "%L", LANG_PLAYER, "TRANSF_SPEC", hns_tag, hns_name )
	/*new Players[32], Num; get_players(Players, Num, "h")
	   
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_SPECTATOR)
		cs_set_user_team(Players[i], CS_TEAM_SPECTATOR, CS_DONTCHANGE)
	}*/
	
	safe_transfer( CS_TEAM_SPECTATOR );
	return PLUGIN_HANDLED
}

public hns_transfer_tt(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED
		
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	client_print_color( 0, print_team_red, "%L", LANG_PLAYER, "TRANSF_TT", hns_tag, hns_name )
	new Players[32], Num; get_players(Players, Num, "h")
	/*
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_T)
		cs_set_user_team(Players[i], CS_TEAM_T, CS_T_ARCTIC)
	}
	*/
	safe_transfer( CS_TEAM_T );
	return PLUGIN_HANDLED
}

public hns_transfer_ct(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED
		
	new hns_name[32]
	get_user_name(id, hns_name, 31)
	client_print_color( 0, print_team_blue, "%L", LANG_PLAYER, "TRANSF_CT", hns_tag, hns_name )
	new Players[32], Num; get_players(Players, Num, "h")
	/*
	for(new i = 0; i < Num; i++)
	{
		if(is_user_alive(Players[i]))
		user_kill(Players[i], 0)
		if(cs_get_user_team(Players[i]) != CS_TEAM_CT)
		cs_set_user_team(Players[i], CS_TEAM_CT, CS_CT_GIGN)
	}
	*/
	safe_transfer( CS_TEAM_CT );
	return PLUGIN_HANDLED
}


public hns_skill(id,level,cid) {
	if(!cmd_access(id, level, cid, 1 )) return PLUGIN_HANDLED
	new hns_name[32]
	get_user_name(id,hns_name, 31)
	client_print_color(0, id, "%L", LANG_PLAYER, "SEMECLIP_ON", hns_tag, hns_name)
	
	server_cmd("hns_semiclip 0")
	server_cmd("hns_flash 1");
	//server_cmd("semiclip_option semiclip 1"); // on
	
	return PLUGIN_HANDLED
}

public hns_boost(id,level,cid) {
	if(!cmd_access(id, level, cid, 1))
	 return PLUGIN_HANDLED
	
	new hns_name[32]
	get_user_name(id,hns_name, 31)
	
	client_print_color(0, print_team_red, "%L", LANG_PLAYER, "SEMECLIP_OFF", hns_tag, hns_name)
	
	server_cmd("hns_semiclip 1")
	server_cmd("hns_flash 2");
	//server_cmd("semiclip_option semiclip 0"); // off
	
	return PLUGIN_HANDLED
}

public hns_aa10(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED	
	new hns_name[32]
	get_user_name(id,hns_name, 31)
	client_print_color(0, id, "%L", LANG_PLAYER, "AA_DESYATKA", hns_tag, hns_name)

	// server_cmd("sv_airaccelerate 10")
	kz_set_airaccelerate(10.0);

	return PLUGIN_HANDLED
}

public hns_aa100(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED	
	new hns_name[32]
	get_user_name(id,hns_name, 31)
	client_print_color(0, id, "%L", LANG_PLAYER, "AA_SOTKA", hns_tag, hns_name)

	//server_cmd("sv_airaccelerate 100")
	kz_set_airaccelerate(100.0);

	return PLUGIN_HANDLED
}

const m_pActiveItem = 373;

public change_setting_value ( id, const setting[], const value[] )
{
	if ( !strcmp ( setting, SETTING_KNIFES ) )
		gOnOff[id] = bool:str_to_num ( value )
		
	if ( !strcmp ( setting, SETTING_EMITSOUND ) )
		gEmitSound[id] = bool:str_to_num ( value )
}

public cmdShowKnife(id)
{			
	//gOnOff[id] = !gOnOff[id];
	gOnOff[id] = gOnOff[id] ? false : true
	set_setting_bool ( id, SETTING_KNIFES, gOnOff[id] )
	client_print_color(id, print_team_red, "%L", LANG_PLAYER, "KNIFE_SHOW", hns_tag, gOnOff[id] ? "^3in" : "^4" );
	
	if( !is_user_alive( id ) )
		return PLUGIN_HANDLED;
	
	if( get_user_weapon( id ) == CSW_KNIFE  )
	{
		if( gOnOff[id] )
			set_pev( id, pev_viewmodel, 0 );
		else
		{
			new weapon = get_pdata_cbase( id, m_pActiveItem, 5 );
			if( weapon != -1 )
				ExecuteHamB( Ham_Item_Deploy, weapon );
		}
	}
	
	return PLUGIN_CONTINUE;
	
}

public ShowTimers(id)
{
	if(GameStarted || g_CurrentMode == e_gPaused)
	{
		new TimeToWin[2][24]	
		new szTeam[2][64]
		fnConvertTime(flSidesTime[iCurrentSW], TimeToWin[0], 23 );		
		get_pcvar_string(cvarTeam[iCurrentSW], szTeam[0], 63)
		//fnConvertTime( (get_pcvar_float(g_Captime)*60.0)-flSidesTime[!iCurrentSW], TimeToWin[1], 23 );	
		fnConvertTime(flSidesTime[!iCurrentSW], TimeToWin[1], 23 );		
		get_pcvar_string(cvarTeam[!iCurrentSW], szTeam[1], 63)	

		if(!iCurrentSW) {
			
			if(iSurvivalRounds <= get_pcvar_num(cvarMaxSurRounds))
				if(iSurvivalRounds == get_pcvar_num(cvarMaxSurRounds))
					client_print_color(id, print_team_red,	"%L", LANG_PLAYER, "GAME_SCORE_FINAL", hns_tag, TimeToWin[iCurrentSW], TimeToWin[!iCurrentSW])
				else
					client_print_color(id, print_team_red,	"%L", LANG_PLAYER, "GAME_SCORE", hns_tag, iSurvivalRounds, get_pcvar_num(cvarMaxSurRounds), TimeToWin[iCurrentSW], TimeToWin[!iCurrentSW])
			else {
				client_print_color(id, print_team_red, "[^4%s^1] Calculating differences...", hns_tag);
				set_cvar_num("mp_freezetime", 0);
				//server_cmd("sv_restart 1");
			}
		}	
		else {
			
			if(iSurvivalRounds <= get_pcvar_num(cvarMaxSurRounds))
				if(iSurvivalRounds == get_pcvar_num(cvarMaxSurRounds))
					client_print_color(id,print_team_red, "%L", LANG_PLAYER, "GAME_SCORE_FINAL", hns_tag, TimeToWin[!iCurrentSW], TimeToWin[iCurrentSW])
				else
					client_print_color(id,print_team_red, "%L", LANG_PLAYER, "GAME_SCORE", hns_tag, iSurvivalRounds, get_pcvar_num(cvarMaxSurRounds), TimeToWin[!iCurrentSW], TimeToWin[iCurrentSW])
			else {
				client_print_color(id, print_team_red, "[^4%s^1] Calculating differences...", hns_tag);
				set_cvar_num("mp_freezetime", 0);
				server_cmd("sv_restart 1");
			}
		}		
	}
	else client_print_color (id, print_team_red, "%L", LANG_PLAYER, "GAME_NOTSTART", hns_tag)
}

public client_putinserver(id)
{	
	g_bShowSpeed{id} = true;
	//gOnOff[id] = false // hns mode
	gOnOff[id] = get_setting_bool ( id, SETTING_KNIFES, false ) //knife
	gEmitSound[id] = get_setting_bool ( id, SETTING_EMITSOUND, false ) //sound death
	
	// if(is_user_bot(id) || (get_user_flags(id) & ADMIN_IMMUNITY))
	// 	return PLUGIN_HANDLED;

	// new ip[22];
	// get_user_ip(id, ip, 22);

	// for(new i = 0; i < MAX_PLAYERS; i++) {
	// 	if(equal(ip, pID[i], 21)) {
	// 		new name[34];
	// 		new uID[1];

	// 		get_user_name(id, name, 33);
	// 		uID[0] = get_user_userid(id);

			
	// 		set_task(1.0, "cleanID", (id + MAX_PLAYERS), uID, 1);
	// 		break;
	// 	}
	// }

	return PLUGIN_HANDLED;
}

public cleanID(i[]) {
	pID[i[0]][0] = 0
}

public client_disconnected(id)
{	
	if(CaptainWinner == id) 
		CaptainWinner = 0;
		
	if(CaptainSide == id)
		CaptainSide = 0;	
	if(Captain1 == id)
		Captain1 = 0;
	if(Captain2 == id)
		Captain2 = 0;
	
	PlayNoPlay[id] = get_gametime()+60.0;
	
	if(get_user_team(id) == 1 || get_user_team(id) == 2)
		SaveState(id);

	// if(is_user_bot(id) && (get_user_flags(id) & ADMIN_IMMUNITY))
	// 	return PLUGIN_HANDLED;

	// new ip[22];
	// get_user_ip(id, ip, 21);
	// new found = 0;

	// for(new i = 0; i < MAX_PLAYERS; i++) {
	// 	if(equal(ip, pID[i], 21)) {
	// 		found = 1;
	// 		break;
	// 	}
	// }

	// if(found == 0) {
	// 	for(new i = 0; i < MAX_PLAYERS; i++) {
	// 		if(pID[i][0] == 0) {
	// 			get_user_ip(id, pID[i], 21);
	// 			MakeCountdown(600.0);
	// 		}
	// 	}
	// }

	return PLUGIN_HANDLED;
}

/* Menu (say /mix) */
/* Menu (say /mix) */
/* Menu (say /mix) */
public dang_mix_menu(id) 
{ 
	new i_Menu = menu_create("\rHide'N'Seek Match System", "dang_mix_menu_code")  

	// Капитан мод
	if(g_CurrentMode != e_gCaptain && CaptainSort == false )
	menu_additem(i_Menu, "\yStart \wcaptains choosing", "1", ADMIN_MENU)
	else
	menu_additem(i_Menu, "\rStop \wchoosing captains", "1", ADMIN_MENU)
	// Старт кнайфраунда
	if( g_CurrentMode == e_gKnife )
	menu_additem(i_Menu, "\rStop \wknife round", "2", ADMIN_MENU) 
	else
	menu_additem(i_Menu, "\yStart \wKnife Round", "2", ADMIN_MENU) 
	// Открыть меню чтобы выбрать мод игры микса
	menu_additem(i_Menu, "\yMix \wmode menu", "3", ADMIN_MENU)
	// Рестарт раунда
	menu_additem(i_Menu, "\yRestart \wthe round", "4", ADMIN_MENU) 
	// Старт и стоп матча
	if(g_CurrentMode != e_gMix) 
	menu_additem(i_Menu, "\yStart \wthe mix", "5", ADMIN_MENU) 
	else
	menu_additem(i_Menu, "\rStop \wthe mix", "5", ADMIN_MENU) 
	// Старт Паузы
	if(g_CurrentMode != e_gPaused) 
	menu_additem(i_Menu, "\yPause \wthe mix", "6", ADMIN_MENU)
	else 
	menu_additem(i_Menu, "\rContinue \wthe mix", "6", ADMIN_MENU)
	// Открыть меню чтобы выбрать мод игры
	menu_additem(i_Menu, "\wGame modes", "7", ADMIN_MENU)
	// Сменить команды местами 
	menu_additem(i_Menu, "\wSwitch teams", "8", ADMIN_MENU) 
	// Открыть меню чтобы перевести игроков
	menu_additem(i_Menu, "\wLoad Settings^n", "9", ADMIN_MENU)
	
	menu_additem(i_Menu, "\yExit", "MENU_EXIT" )
	
	menu_setprop(i_Menu, MPROP_PERPAGE, 0)
	menu_display(id, i_Menu, 0)
	
	return PLUGIN_HANDLED 
} 
/* /Menu (say /mix) */
/* /Menu (say /mix) */
/* /Menu (say /mix) */



/* Menu Functions (say /mix) */
/* Menu Functions (say /mix) */
/* Menu Functions (say /mix) */
public dang_mix_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 
	
	switch(i_Key) 
	{ 
		case 1: 
		{ 
			if(g_CurrentMode != e_gCaptain && CaptainSort == false )
			client_cmd(id, "say /cap")
			else 
			menu_verif(id)
		} 
		case 2: 
		{ 
			if( g_CurrentMode == e_gKnife )
			client_cmd(id, "say /stop")
			else
			client_cmd(id, "say /kf")
		} 
		case 3: 
		{ 
			client_cmd(id, "say /mod")
		}
		case 4: 
		{ 
			client_cmd(id, "say /rr")
			dang_mix_menu(id) 
		}  
		case 5: 
		{ 
			if(g_CurrentMode != e_gMix)
			client_cmd(id, "say /start")
			else
			menu_verif(id)
		} 
		case 6:
		{
			if(g_CurrentMode != e_gPaused)
			client_cmd(id, "say /pause")
			else
			client_cmd(id, "say /live")
		}
		case 7:
		{
			client_cmd(id, "say /mode")
		}
		case 8: 
		{ 
			client_cmd(id, "say /swap")
			dang_mix_menu(id) 
		} 
		case 9: 
		{ 
			hns_menu_choose(id)
		} 
	} 

	menu_destroy(menu) 
	return PLUGIN_HANDLED
}

public menu_verif(id)
{
// Сперва необходимо создать переменную для меню, с которой мы будем взаимодействовать в дальнейшем
	new i_Menu = menu_create("\rConfirmation^n^n\dDo you want to stop the mode?:", "menu_verif_handler")

// Теперь добавим некоторые опции для меню
	menu_additem(i_Menu, "\wYES", "1", 0)
	menu_additem(i_Menu, "\wNO", "2", 0)

// Устанавливаем свойства меню
	menu_setprop(i_Menu, MPROP_EXIT, MEXIT_ALL)

// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

// Создадим теперь функцию обработки действий меню
public menu_verif_handler(id, menu, item, level, cid)
{
// Если игрок нажал выход из меню
	if (item == MENU_EXIT)
	{
		// Уничтожение меню
		menu_destroy(menu)

		return PLUGIN_HANDLED
	}

// Теперь создадим переменные, необходимые для получения информации о меню и нажатой опции
	new s_Data[6], s_Name[64], i_Access, i_Callback

// Получаем информацию об опции
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)

// Если посмотреть раньше на использовании menu_additem, то можно увидеть, что мы посылали некоторую информацию
// В данном случае вся информация - целочисленная
	new i_Key = str_to_num(s_Data)

// Теперь найдем, какая именно опция была использована
	switch(i_Key)
	{
	case 1:
	{
		if(g_CurrentMode != e_gCaptain && CaptainSort == false )
			cmdStop(id)
		else
			StopCaptainCmd(id,level,cid)
	}
	case 2:
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	}

// Уничтожение меню
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public hns_menu_choose(id) { 
	new i_Menu = menu_create("Hide'N'Seek Default Settings", "hns_menu_choose_code") 

	menu_additem(i_Menu, "\yLoad default settings for \rBoost game", "1", 0) 
	menu_additem(i_Menu, "\yLoad default settings for \rSkill game", "2", 0) 

	menu_display(id, i_Menu, 0)
	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\yBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\yExit");
	return PLUGIN_HANDLED 
}

public hns_menu_choose_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{ 
		case 1: 
		{ 
			set_cvar_num("mp_freezetime", 15);
			set_cvar_float("mp_roundtime", 3.5)
			set_cvar_num("hns_semiclip", 1);
			//set_pcvar_num(cvarMaxSurRounds, 10);
			set_pcvar_num(cvarFlashNum, 3);
			set_pcvar_num(cvarSmokeNum, 1);
			client_print(id, print_center, "Loading default BOOST settings")
			server_cmd("sv_restart 1")
		} 
		case 2: 
		{ 
			set_cvar_num("mp_freezetime", 7);
			set_cvar_float("mp_roundtime", 2.5)
			set_cvar_num("hns_semiclip", 0);
			//set_pcvar_num(cvarMaxSurRounds, 20);
			set_pcvar_num(cvarFlashNum, 1);
			set_pcvar_num(cvarSmokeNum, 1);
			client_print(id, print_center, "Loading default SKILL settings")
			server_cmd("sv_restart 1")
		} 
	}
	
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

/*public hns_mr_menu(id) { 
	new i_Menu = menu_create("Hide'N'Seek MR", "hns_mr_menu_code") 

	menu_additem(i_Menu, "\yMR5", "1", 0) 
	menu_additem(i_Menu, "\yMR7", "2", 0) 
	menu_additem(i_Menu, "\yMR9", "3", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "\yВернуться назад", "9", 0)

	menu_display(id, i_Menu, 0)
	menu_additem(i_Menu, "\yВыход", "MENU_EXIT" )

	return PLUGIN_HANDLED 
} 

public hns_mr_menu_code(id, menu, item, level, cid) 
{ 
	if (item == MENU_EXIT) 
	{ 
		menu_destroy(menu) 
		return PLUGIN_HANDLED 
	} 
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /mr5")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /mr7")
		} 
		case 3: 
		{ 
			client_cmd(id, "say /mr9")
		} 
		case 9: 
		{ 
			hns_mod_menu(id)
		}
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}*/

public hns_semi_menu(id) { 
	new i_Menu = menu_create("Hide'N'Seek TYPE", "hns_semi_menu_code") 

	menu_additem(i_Menu, "\yBoost", "1", 0) 
	menu_additem(i_Menu, "\ySkill", "2", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "\yGo back", "9", 0)

	menu_display(id, i_Menu, 0)
	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\yBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\yExit");
	return PLUGIN_HANDLED 
}

public hns_semi_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{ 
		case 1: 
		{ 
			client_cmd(id, "say /boost")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /skill") 
		} 
		case 9: 
		{ 
			dang_mix_menu(id)
		} 
	}
	
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_aa_menu(id) { 
	if(get_user_flags(id) & hns_ACESS) {
		new i_Menu = menu_create("Hide'N'Seek AA", "hns_aa_menu_code") 

		menu_additem(i_Menu, "\y100aa", "1", 0) 
		menu_additem(i_Menu, "\y10aa", "2", 0) 
		menu_addblank(i_Menu, 0)
		menu_additem(i_Menu, "\yGo back", "9", 0)

		menu_display(id, i_Menu, 0)
		menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
		menu_setprop(i_Menu, MPROP_BACKNAME, "\yBack");
		menu_setprop(i_Menu, MPROP_EXITNAME, "\yExit");
	} else
		ColorChat(0, getTeamColor(cs_get_user_team(id)), "^1[^4%s^1] ^3The current airaccelerate is ^4%d^3!", hns_tag, floatround(get_cvar_num("sv_airaccelerate")));

	return PLUGIN_HANDLED 
} 

public hns_aa_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /aa100")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /aa10")
		} 
		case 9: 
		{ 
			dang_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_trans_menu(id) { 
	new i_Menu = menu_create("Hide'N'Seek Transfer", "hns_trans_menu_code") 
	menu_additem(i_Menu, "\yAll to \wSpectators ", "1", 0) 
	menu_additem(i_Menu, "\yAll to \rTerrorist ", "2", 0) 
	menu_additem(i_Menu, "\yAll to \wCounter-Terrorist", "3", 0) 
	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "\rGo back", "9", 0)

	menu_display(id, i_Menu, 0)
	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	return PLUGIN_HANDLED 
} 

public hns_trans_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{ 
		case 1: 
		{ 
			client_cmd(id, "say /specall")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /ttall")
		} 
		case 3: 
		{ 
			client_cmd(id, "say /ctall")
		} 
		case 9: 
		{ 
			dang_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_mode_menu(id) { 
	new i_Menu = menu_create("Hide'N'Seek Mode", "hns_mode_menu_code") 

	if(g_CurrentMode == e_gPub) 
	{
	menu_additem(i_Menu, "\dPublic HNS mode \d(\rrunning\d)", "1", 0) 
	menu_additem(i_Menu, "Training + Matches", "2", 0)
	} else {
	menu_additem(i_Menu, "\yPublic HNS mode", "1", 0) 
	menu_additem(i_Menu, "\dTraining + Matches \d(\rrunning\d)", "2", 0)
	}
	menu_additem(i_Menu, "\rGo back", "9", 0)

	menu_display(id, i_Menu, 0)
	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	return PLUGIN_HANDLED 
} 

public hns_mode_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /pub")
		} 
		case 2: 
		{ 
			client_cmd(id, "say /def")
		} 
		case 9: 
		{ 
			dang_mix_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_mod_menu(id) { 
	new i_Menu = menu_create("Hide'N'Seek Match Mode^nChoose game mode:", "hns_mod_menu_code") 

	menu_additem(i_Menu, "\yProtraction mode", "1", 0) 
	menu_additem(i_Menu, "\rRound-robin mode", "2", 0)
	menu_additem(i_Menu, "\wBattle mode", "3", 0)
	menu_additem(i_Menu, "\yRound time (for every mode)", "4", 0)

	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	menu_display(id, i_Menu, 0);
	return PLUGIN_HANDLED 
} 

public hns_mod_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			if(g_CurrentMode == e_gTraining)
			{
				client_cmd(id, "say /protraction")
				hns_timer_menu(id)
			}
		} 
		case 2: 
		{ 
			if(g_CurrentMode == e_gTraining)
			{
				client_cmd(id, "say /normal")
				//hns_mr_menu(id)
			}
		} 
		case 3: 
		{ 
			if(g_CurrentMode == e_gTraining)
			{
				client_cmd(id, "say /wintt")
				hns_1x1_menu(id)
			}
			else hns_1x1_menu(id)
		} 
		case 4: 
		{ 
			hns_timeround_menu(id)
		}
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_1x1_menu(id) { 
	new i_Menu = menu_create("Battle Menu:", "hns_1x1_menu_code") 

	menu_additem(i_Menu, "\yTransfer all to spectators", "1", 0) 
	menu_additem(i_Menu, "\wSilent mode (listen to your team)", "2", 0)
	menu_additem(i_Menu, "\rNormal mode (listen to all)", "3", 0)
	if(g_CurrentMode != e_gMix) 
		menu_additem(i_Menu, "\yStart \wDuel", "4", 0)
	else
		menu_additem(i_Menu, "\rStop \wDuel", "4", 0)
	if(g_CurrentMode != e_gKnife)
		menu_additem(i_Menu, "\yStart \wknife round", "5", 0)
	else
		menu_additem(i_Menu, "\rStop \wknife round", "5", 0)
	menu_additem(i_Menu, "\wRestart round", "6", 0)

	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	menu_display(id, i_Menu, 0);
	return PLUGIN_HANDLED 
} 

public hns_1x1_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;
	
	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 
	new szName[64]
	get_user_name(id, szName, 63)

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /specall")
			hns_1x1_menu(id)
		} 
		case 2: 
		{ 
			server_cmd("sv_alltalk 0")
			client_print_color(0, print_team_red, "%L", LANG_SERVER, "DISABLED_ALLTALK", hns_tag, szName)
			hns_1x1_menu(id)
		} 
		case 3: 
		{ 
			server_cmd("sv_alltalk 1")
			client_print_color(0, print_team_red, "%L", LANG_SERVER, "ACTIVAED_ALLTALK", hns_tag, szName)
			hns_1x1_menu(id)
		}
		case 4: 
		{ 
			 if(g_CurrentMode != e_gMix)
			client_cmd(id, "say /start")
			else
			menu_verif(id)
		}
		case 5: 
		{ 
			 if(g_CurrentMode != e_gKnife)
			client_cmd(id, "say /kf")
			else
			menu_verif(id)
		}
		case 6:
		{
			client_cmd(id, "say /rr")
			hns_1x1_menu(id)
		}
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_timeround_menu(id) { 
	new i_Menu = menu_create("Choose round time:", "hns_timeround_menu_code") 

	menu_additem(i_Menu, "\y1:30", "1", 0) 
	menu_additem(i_Menu, "\r2:00", "2", 0)
	menu_additem(i_Menu, "\w2:30", "3", 0)
	menu_additem(i_Menu, "\y3:00", "4", 0)
	menu_additem(i_Menu, "\r3:30", "5", 0)
	menu_additem(i_Menu, "\w4:00", "6", 0)

	menu_addblank(i_Menu, 0)
	menu_additem(i_Menu, "\rGo back", "9", 0)

	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	menu_display(id, i_Menu, 0);
	return PLUGIN_HANDLED 
} 

public hns_timeround_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 
	new szName[64]
	get_user_name(id, szName, 63)

	switch(i_Key) 
	{  
		case 1: 
		{ 
			server_cmd("mp_roundtime 1.5")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 1:30", hns_tag, szName)
			hns_timeround_menu(id)
		} 
		case 2: 
		{ 
			server_cmd("mp_roundtime 2")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 2:00", hns_tag, szName)
			hns_timeround_menu(id)
		} 
		case 3: 
		{ 
			server_cmd("mp_roundtime 2.5")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 2:30", hns_tag, szName)
			hns_timeround_menu(id)
		}
		case 4: 
		{ 
			server_cmd("mp_roundtime 3")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 3:00", hns_tag, szName)
			hns_timeround_menu(id)
		}
		case 5: 
		{ 
			server_cmd("mp_roundtime 3.5")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 3:30", hns_tag, szName)
			hns_timeround_menu(id)
		}
		case 6: 
		{ 
			server_cmd("mp_roundtime 4")
			client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1set the round time to 4:00", hns_tag, szName)
			hns_timeround_menu(id)
		}
		case 9: 
		{ 
			hns_mod_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}

public hns_timer_menu(id) { 
	new i_Menu = menu_create("Choose protraction rounds:", "hns_timer_menu_code") 

	menu_additem(i_Menu, "\y10 rounds", "1", 0) 
	menu_additem(i_Menu, "\r16 rounds", "2", 0)
	menu_additem(i_Menu, "\w20 rounds", "3", 0)

	menu_additem(i_Menu, "\rGo back", "9", 0)

	menu_setprop(i_Menu, MPROP_NEXTNAME, "\yNext");
	menu_setprop(i_Menu, MPROP_BACKNAME, "\wBack");
	menu_setprop(i_Menu, MPROP_EXITNAME, "\rExit");
	menu_display(id, i_Menu, 0);
	return PLUGIN_HANDLED 
} 

public hns_timer_menu_code(id, menu, item, level, cid) 
{ 
	if( item < 0 ) return PLUGIN_CONTINUE;

	new s_Data[6], s_Name[64], i_Access, i_Callback 
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback) 
	new i_Key = str_to_num(s_Data) 

	switch(i_Key) 
	{  
		case 1: 
		{ 
			client_cmd(id, "say /srounds 10")
			hns_timer_menu(id)
		} 
		case 2: 
		{ 
			client_cmd(id, "say /srounds 15")
			hns_timer_menu(id)
		} 
		case 3: 
		{ 
			client_cmd(id, "say /srounds 20")
			hns_timer_menu(id)
		}
		case 9: 
		{ 
			hns_mod_menu(id)
		} 
	}
	menu_destroy(menu) 
	return PLUGIN_HANDLED 
}
/* /Menu Functions (say /mix) */
/* /Menu Functions (say /mix) */
/* /Menu Functions (say /mix) */

/* Training start */

/* Hook */
/* Hook */
/* Hook */
public hns_hook_on(id)
{
	if ( g_CurrentMode > e_gPaused )
		return PLUGIN_HANDLED
		
	if( !is_user_alive(id) )
		return PLUGIN_HANDLED
		
	get_user_origin(id,hookorigin[id],3)
	hns_hooked[id] = true
	set_task(0.1,"hns_hook_task",id+9999,"",0,"ab")
	hns_hook_task(id+9999)
	
	return PLUGIN_HANDLED
}

public is_hooked(id) 
{
	return hns_hooked[id]
}

public hns_hook_off(id) 
{
	remove_hook(id)
	
	return PLUGIN_HANDLED
}

public hns_hook_task(id) 
{
	id -= 9999;
	if(!is_user_connected(id) || !is_user_alive(id) || g_CurrentMode > e_gPaused)
		remove_hook(id)
	
	remove_beam(id)
	draw_hook(id)

	new origin[3], Float:velocity[3]
	get_user_origin(id,origin)
	new distance = get_distance(hookorigin[id],origin)
	if(distance > 60)
	{
		velocity[0] = (hookorigin[id][0] - origin[0]) * (2.0 * 500 / distance)
		velocity[1] = (hookorigin[id][1] - origin[1]) * (2.0 * 500 / distance)
		velocity[2] = (hookorigin[id][2] - origin[2]) * (2.0 * 500 / distance)
		entity_set_vector(id,EV_VEC_velocity,velocity)
	}
	else 
	{
		entity_set_vector(id,EV_VEC_velocity,Float:{0.0,0.0,0.0})
		entity_set_float(id, EV_FL_gravity, 0.00000001);
	}
	entity_set_int(id, EV_INT_sequence, 55);
	entity_set_float(id,EV_FL_frame, 0.0);
}

public draw_hook(id)
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(1)				// TE_BEAMENTPOINT
	write_short(id)				// entid
	write_coord(hookorigin[id][0])	// origin
	write_coord(hookorigin[id][1])	// origin
	write_coord(hookorigin[id][2])	// origin
	write_short(Sbeam)			// sprite index
	write_byte(0)				// start frame
	write_byte(0)				// framerate
	write_byte(100)				// life
	write_byte(10)				// width
	write_byte(0)				// noise
	write_byte(HOOK_R)				// r
	write_byte(HOOK_G)				// g
	write_byte(HOOK_B)				// b
	write_byte(250)				// brightness
	write_byte(0)				// speed
	message_end()
}


public remove_hook(id) 
{
	if(task_exists(id+9999))
		remove_task(id+9999)
		
	remove_beam(id)
	entity_set_float(id, EV_FL_gravity, 1.0);
	ishooked[id] = false
}

public remove_beam(id)
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(99) // TE_KILLBEAM
	write_short(id)
	message_end()
}
/* /Hook */
/* /Hook */
/* /Hook */


// Commands
public cmdCheckpoint(plr)
{
	if( g_CurrentMode > e_gPaused )
	{
		client_print(plr, print_chat, "Checkpoints are disabled.");
		return PLUGIN_HANDLED;
	}
	else if( !is_user_alive(plr) )
	{
		client_print(plr, print_chat, "You can't do that while dead.");
		return PLUGIN_HANDLED;
	}

	pev(plr, pev_origin, gCheckpoints[plr][g_bCheckpointAlternate[plr] ? 1 : 0]);
	g_bCheckpointAlternate[plr] = !g_bCheckpointAlternate[plr];
	
	return PLUGIN_HANDLED;
}

public cmdGoCheck(plr)
{
	if( g_CurrentMode > e_gPaused )
	{
		client_print(plr, print_chat, "Checkpoints are disabled.");
		return PLUGIN_HANDLED;
	}
	else if( !is_user_alive(plr) )
	{
		client_print(plr, print_chat, "You can't do that while dead.");
		return PLUGIN_HANDLED;
	}
	else if( !gCheckpoints[plr][0][0] )
	{
		client_print(plr, print_chat, "%L", plr, "You don't have any checkpoints.");
		return PLUGIN_HANDLED;
	}
	
	set_pev(plr, pev_velocity, Float:{0.0, 0.0, 0.0});
	set_pev(plr, pev_flags, pev(plr, pev_flags) | FL_DUCKING)
	engfunc(EngFunc_SetOrigin, plr, gCheckpoints[plr][!g_bCheckpointAlternate[plr]]);
	
	return PLUGIN_HANDLED;
}
/* Training end */

public cmdStartRound(id)
{
	if(get_user_flags(id) & hns_ACESS)
	{
		if(g_CurrentMode > e_gKnife)
		{
			client_print_color(id, id, "[^4%s^1] Please ^4disable ^1other modes before starting mix", hns_tag);
		}
		else
		{
			if(current_mode == mode_timebased)
				StartSMCmd(id)
			else if(current_mode == mode_winter)
				pf_Scrim1(id)
			else
				pf_Scrim(id);
		}
	}
}

public StartSMCmd(id) {
	
	if(!GameStarted)
	{		
		Task_Hud(0, 2.0, 1, 0, 100, 240, 3.0, "PROTRACTION MODE STARTS IN 3 SECONDS")
		set_task(3.0, "StartSM");
	}
	else
	{
		client_print(id, print_chat, "[%s] Protraction Mode is already started, to stop it say /stop", hns_tag);
	}
	return PLUGIN_HANDLED
}

public StopSMCmd(id) {	
	if(GameStarted)
	{
		GameStarted = false
		Survival = false;
		new szName[64]
		get_user_name(id, szName, 63)
		//client_print_color(0, print_team_red, "[^4%s^1] ^4%s ^1stoped Survival Mode", hns_tag, szName);
	}
	return PLUGIN_HANDLED
}

public StartSM()
{
	PrepareMode(e_gMix);

	new iPlayers[32], iNum;
	get_players(iPlayers, iNum);

	for(new id = 0; id < iNum; id++) {
		flPlayerTime[id] = 0.0;
		flPlayerRoundTime[id] = 0.0;
	}

	flSidesTime[0] = 0.0
	flSidesTime[1] = 0.0

	iSurvivalRounds = 1;
	iCurrentSW = 1;
	GameStarted = true;
	server_cmd("sv_restart 1")	
	//set_task(2.0, "LiveMessage");
}

public cmdStop(id)
{
	if(get_user_flags(id) & hns_ACESS)
	{
		switch(g_CurrentMode)
		{
			case e_gPaused:
			{
				client_print_color(0, id, "%L", LANG_SERVER, "STOP_MIX", hns_tag, GetName(id))			
			}
			case e_gKnife:
			{
				client_print_color(0, id, "%L", LANG_SERVER, "STOP_KNIFE", hns_tag, GetName(id))			
			}
			case e_gMix:
			{
				client_print_color(0, id, "%L", LANG_SERVER, "STOP_MIX", hns_tag, GetName(id))				
			}
			case e_gPub:
			{
				client_print_color(0, id, "%L", LANG_SERVER, "STOP_PUB", hns_tag, GetName(id))			
			}			
		}
		
		//server_cmd("amxx unpause uq_jumpstats.amxx")
		StopSMCmd(id);
		if(g_CurrentMode)
		{
			PrepareMode(e_gTraining);
		}		
	}
}
public cmdKnifeRound(id)
{
	if(get_user_flags(id) & hns_ACESS)
	{
		if(g_CurrentMode > e_gKnife)
		{
			client_print_color(id, id, "[^4%s^1] Please ^4disable ^1other mode before start knife", hns_tag);
		}
		else
		{
			pf_KnifeRound(id)
			remove_hook(id)
		}
	}
}

public pf_Scrim(id)
{		
	set_task(4.5, "PrepareMode", e_gMix);
	set_task(5.0, "RestartRound");
	Task_Hud(0, 0.0, 1, 244, 170, 66, 3.0, "GOING LIVE IN 5 SECONDS")	
	Task_Hud(0, 7.0, 1, 92, 65, 244, 5.0, "LIVE LIVE LIVE^nGood Luck & Have Fun")	
	
	client_print_color(0, id, "[^4%s^1] ^3%s ^1started ^4Mix!", hns_tag, GetName(id));
}

public pf_Scrim1(id)
{		
	set_task(4.5, "PrepareMode", e_gMix);
	set_task(5.0, "RestartRound");
	Task_Hud(0, 0.0, 1, 244, 170, 66, 3.0, "GOING LIVE IN 5 SECONDS")	
	Task_Hud(0, 7.0, 1, 92, 65, 244, 5.0, "LIVE LIVE LIVE^nGood Luck & Have Fun")	
	
	client_print_color(0, id, "[^4%s^1] ^3%s ^1started ^4Duel!", hns_tag, GetName(id));
}

public pf_KnifeRound(id)
{		
	new szMapName[64]
	get_mapname(szMapName, 63);
	PrepareMode(e_gKnife);	
	RingWidth = 2300.0;
	if(get_pcvar_num(ring_cvar))
		set_task(0.1, "RingTask", RINGTASK, .flags = "b");
	Task_Hud(0, 2.0, 1, 244, 77, 65, 3.0, "Knife Round Started!");
	client_print_color(0, id, "[^4%s^1] ^3%s ^1started ^4Knife Round!", hns_tag, GetName(id));
	
	return PLUGIN_HANDLED
}

public PersonalScore(id) {
	if(current_mode == mode_timebased)
	{	
		new sTime[24], rTime[24];

		fnConvertTime( flPlayerTime[id], sTime, 23 );
		fnConvertTime( flPlayerRoundTime[id], rTime, 23);

		client_print_color(id, print_team_red, "^1[^4%s^1] ^3Personal survival time: ^4%s^1 | ^3Current round survival time: ^4%s", hns_tag, sTime, rTime);
		return PLUGIN_CONTINUE
	}

	return PLUGIN_CONTINUE;
}

public Score(id)
{	
	new teamname[2][32]
	if(current_mode == mode_timebased && g_CurrentMode == e_gMix)
	{
		ShowTimers(id)	
		return PLUGIN_CONTINUE
	}
	else if(current_mode == mode_mr)
	{
		get_pcvar_string(cvarTeam[0], teamname[0], 31)
		get_pcvar_string(cvarTeam[1], teamname[1], 31)
		//teamname[0] = "CT";
		//teamname[1] = "TT";
	}
	else
	{
		/*new players[32], num;	
		get_players(players, num, "e", "CT");
		get_user_name(players[0], teamname[0], 31);
		get_players(players, num, "e", "TERRORIST");
		get_user_name(players[0], teamname[1], 31);*/

		teamname[0] = "CT";
		teamname[1] = "TT";
	}
	

	if(!g_iSecondHalf)
		client_print_color(id, print_team_blue,"^1[^4%s^1] Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MR%d^1)", hns_tag, teamname[0], g_iScore[0], g_iScore[1], teamname[1], get_pcvar_num(cvarMaxRounds))	
	else 
		client_print_color(id, print_team_blue,"^1[^4%s^1] Score: ^4%s ^3%d^1:^3%d ^4%s ^1(^3MR%d^1)", hns_tag, teamname[1], g_iScore[1], g_iScore[0], teamname[0], get_pcvar_num(cvarMaxRounds))	
		
	return PLUGIN_CONTINUE
}

public eCurWeapon(id)
{
	if(g_CurrentMode == e_gKnife)
	{
		engclient_cmd(id, "weapon_knife")
	}

	if(!g_bFreezePeriod)
		return
		
	if (cs_get_user_team(id) == CS_TEAM_T)
	cs_reset_user_maxspeed(id)
}

public cs_reset_user_maxspeed(id) {
	engfunc(EngFunc_SetClientMaxspeed, id, 250.0);
	set_pev(id, pev_maxspeed, 250.0)
	return PLUGIN_HANDLED
}

#define TASK_ROUNDTIME 8888

public ePreFT() {
	if(task_exists(ROUNDENDTASK))
		remove_task(ROUNDENDTASK);
	if(task_exists(TASK_ROUNDTIME))
		remove_task(TASK_ROUNDTIME);
		
		
	if(GameStarted)
	{		
		ShowTimers(0);
	}
	
	g_flRoundTime = 0.0;

	new iPlayers[32], iNum;
	for(new id = 0; id < iNum; id++)
		flPlayerRoundTime[id] = 0.0;

	RingWidth = 2300.0;
	EnableHamForward( Player_Killed_Pre );
	g_bLastFlash = false;
	g_bFreezePeriod = true;
	
	set_task(0.1, "TaskDestroyBreakables");
}
public ePostFT() {
	StartRoundTime = get_gametime();
	g_bFreezePeriod = false;
	
	if(current_mode == mode_timebased) 
	{
		if(GameStarted)
			Survival = true
			
		set_task(0.25, "RoundEnd", TASK_ROUNDTIME,. flags = "b");
	}
}


public RoundEnd()
{
	g_flRoundTime += 0.25;

	if(Survival)
	{
		new Float:difference;
		new roundDifference;

		roundDifference = get_pcvar_num(cvarMaxSurRounds) - iSurvivalRounds;

		flSidesTime[iCurrentSW] += 0.25;

		new iPlayers[32], iNum;
		get_players(iPlayers, iNum);

		for(new i = 0; i < iNum; i++) {
			if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
				flPlayerTime[i] += 0.25;
				flPlayerRoundTime[i] = 0.25;
		}
		
		if(iCurrentSW)
			difference = flSidesTime[0] - flSidesTime[iCurrentSW];
		else
			difference = flSidesTime[1] - flSidesTime[iCurrentSW];

		if(iSurvivalRounds > get_pcvar_float(cvarMaxSurRounds) || (roundDifference < 3 && difference > (get_pcvar_float( g_pRoundTime ) * 60.0) * 2))
		{
			
			EndMatch()
		}
		else if(!SoundFx)
		{
			EndSoundFx(1);
			SoundFx = true;
		}
	}
	if((g_flRoundTime / 60.0) >= get_pcvar_float( g_pRoundTime ))
	{
		if(GameStarted)
			Survival = false;
		//RoundTerminating(0.5)

		// iSurvivalRounds += 1;
		// iCurrentSW = !iCurrentSW;
		
		remove_task(TASK_ROUNDTIME)
	}
}


public EndSoundFx( toggle )
{	
	if(toggle)
		client_cmd ( 0 , "spk ambience/endgame.wav" )
	else	
	for( new i = 1; i <= g_iMaxPlayers; i++ )
	{
		if(is_user_connected(i))
		client_cmd(i, "stopsound");
	}
	
}

public TTWin()
{
	new winner = 2;
	if(g_CurrentMode == e_gMix)
	{
		if(!g_iSecondHalf)
		{
			if(winner == 1)
			{
				g_iScore[0]++
			}
			if(winner == 2)
			{
				g_iScore[1]++
			}
		}
		else
		{
			if(winner == 1)
			{
				g_iScore[1]++
			}
			if(winner == 2)
			{
				g_iScore[0]++
			}			
		}					
	}
	server_cmd("sv_restart 1");
}

//public eEndRound( RoundControlWin:teamWins, numWins, RoundEvent:eventRound/*, bool:bHasExpired*/ )

public eEndRound()
{
	if(task_exists(ROUNDENDTASK))
		remove_task(ROUNDENDTASK);
		
	new msg[32], winner;
	read_data(2,msg,32)
	
	if(task_exists(RINGTASK))
		remove_task(RINGTASK)
		
	if(containi(msg,"ct") != -1) 
	{
		winner = 1		
	}
	
	else if(contain(msg,"ter") != -1) 
	{
		winner = 2;
		
	}	
	
	if(g_CurrentMode == e_gPub)
	{		
		Survival = false;
		if(winner == 1)
		{
			iCurrentSW = !iCurrentSW;
			SwitchTeams();
		}
	}
	else if(g_CurrentMode == e_gMix && current_mode == mode_timebased) {
		Survival = false;
		iSurvivalRounds += 1;
		iCurrentSW = !iCurrentSW;
		SwitchTeams();
	}
	else if(g_CurrentMode == e_gMix && current_mode == mode_mr)
	{
		if(!g_iSecondHalf)
		{
			if(winner == 1)
			{
				g_iScore[0]++
			}
			if(winner == 2)
			{
				g_iScore[1]++
			}
		}
		else
		{
			if(winner == 1)
			{
				g_iScore[1]++
			}
			if(winner == 2)
			{
				g_iScore[0]++
			}			
		}
		CheckScore()	
	}
	else if(g_CurrentMode == e_gMix && current_mode == mode_winter)
	{
					
		if(winner == 2)
		{
			if(!g_iSecondHalf)
				g_iScore[1]++
			else
				g_iScore[0]++
		}
		else
		{
			g_iSecondHalf = !g_iSecondHalf;
			SwitchTeams();
		}
		
		CheckScore2()
	}
	else if(g_CurrentMode == e_gKnife)
	{
		if(winner == 1)
		{			
			Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "KNIFE ROUND WIN COUNTER-TERRORISTS");
		}			
		if(winner == 2)
		{
			Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "KNIFE ROUND WIN TERRORISTS");			
		}
		
		if(CaptainWinner == 3)
		{			
			if(winner == 1)
				CaptainSide = Captain1;
			else
				CaptainSide = Captain2;
			set_task(1.5, "captain_menu", CaptainSide);
			//set_task(0.2, "PlayersList", TASK_PLAYERSLIST, _, _, "b");
			CaptainWinner = 0;
			CaptainSort = true
			PrepareMode(e_gCaptain);
		}
		else	
			PrepareMode(e_gTraining);
			
		SavePlayers();
	}	
}

public CheckScore2()
{
	new Rounds = get_pcvar_num(cvarMaxRounds)
	
	Score(0);
		
	new teamname[32]
	if(g_iScore[0] >= Rounds)
	{
		get_pcvar_string(cvarTeam[0], teamname, 31)
		Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nWINNER: %s",teamname);			
		//Enable_SlowMo();
		//set_task(4.0, "Disable_SlowMo");
		EndMatch();
		return 1;
	}
	else if(g_iScore[1] >= Rounds)
	{
		get_pcvar_string(cvarTeam[1], teamname, 31)
		Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nWINNER: %s",teamname);
		//Enable_SlowMo();
		//set_task(4.0, "Disable_SlowMo");
		EndMatch();
		return 1;
	}
	else if((g_iScore[0]+g_iScore[1]) == (Rounds*2))
	{
		Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nDRAW DRAW DRAW");		
		//Enable_SlowMo();
		//set_task(4.0, "Disable_SlowMo");
		EndMatch();
		return 1;
	}		
		
	
	
	return 0;
}
public CheckScore()
{
	new Rounds = get_pcvar_num(cvarMaxRounds)
	
	Score(0);
	
	if(!g_iSecondHalf)
	{
		if(g_iScore[0]+g_iScore[1] == Rounds)
		{
			g_iSecondHalf = true;
			SwitchTeams();
			Task_Hud(0, 2.0, 1, 65, 105, 225, 6.0, "1ST HALF %d:%d^nSWITCHING SIDES...^n2ND HALF IN 5 SECONDS", g_iScore[0], g_iScore[1])
			Task_Hud(0, 9.0, 1, 255, 153, 0, 5.0, "LIVE LIVE LIVE");
			set_task(7.0, "RestartRound");
			
		}
	}
	else
	{
		new teamname[32]
		if(g_iScore[0] > Rounds)
		{
			get_pcvar_string(cvarTeam[0], teamname, 31)
			Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nWINNER: %s",teamname);			
			//Enable_SlowMo();
			//set_task(15.0, "Disable_SlowMo");
			EndMatch();
			return 1;
		}
		else if(g_iScore[1] > Rounds)
		{
			get_pcvar_string(cvarTeam[1], teamname, 31)
			Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nWINNER: %s",teamname);
			//Enable_SlowMo();
			//set_task(15.0, "Disable_SlowMo");
			EndMatch();
			return 1;
		}
		else if((g_iScore[0]+g_iScore[1]) == (Rounds*2))
		{
			Task_Hud(0, 2.0, 1, 65, 105, 225, 3.0, "MATCH FINISHED^nDRAW DRAW DRAW");		
			//Enable_SlowMo();
			//set_task(15.0, "Disable_SlowMo");
			EndMatch();
			return 1;
		}		
		
	}
	
	return 0;
}

public SwitchTeams()
{
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_connected( i ) )
		{
			switch( cs_get_user_team( i ) )
			{
			case CS_TEAM_T: cs_set_user_team( i, CS_TEAM_CT )        
			case CS_TEAM_CT: cs_set_user_team( i, CS_TEAM_T )
			}
		}
	}	
}

public CBasePlayer_Spawn_Post(id) {

	if (!is_user_alive(id))
		return;

	//set_pdata_bool(id, m_bJustConnected, false);
	if(g_CurrentMode <= 1)
		set_user_godmode(id, 1)

	SetRole(id)
}

public SetRole(id) {
	new CsTeams:team = cs_get_user_team(id)
	strip_user_weapons(id)
	set_user_freeze(id, 0);
	if(g_CurrentMode > e_gKnife )
	{
		switch (team)
		{
			case CS_TEAM_T:
			{
				set_user_footsteps(id, 1);
				give_item(id, "weapon_knife")
				if( get_pcvar_num( cvarFlashNum ) >= 1 )
				{
					give_item( id, "weapon_flashbang" );
					cs_set_user_bpammo( id, CSW_FLASHBANG, get_pcvar_num( cvarFlashNum ) );
				}
				if( get_pcvar_num( cvarSmokeNum ) >= 1 )
				{
					give_item( id, "weapon_smokegrenade" );
					cs_set_user_bpammo( id, CSW_SMOKEGRENADE, get_pcvar_num( cvarSmokeNum ) );
				}
			}
			case CS_TEAM_CT:
			{
				set_user_footsteps(id, 0);
				give_item(id, "weapon_knife")
			}
		}
	}
	else
	{
		give_item(id, "weapon_knife")
	}
}

public GetName(id)
{
	new szName[128]
	get_user_name(id, szName, charsmax(szName))
	return szName
}

/*public CheckCvars(mode)
{
	switch(mode)
	{
		case 0:
		{
			
		}
		case 3:
		{
			server_cmd( "hns_hns 1" )
			server_cmd( "hns_footsteps 1" )
			server_cmd( "mp_forcechasecam 2")
			server_cmd( "mp_forcecamera 2")			
			server_cmd( "hns_alltalk 0" )
			server_cmd( "mp_timelimit 0" )
		}
	}
}*/

public PrepareMode(mode)
{	
		
	switch(mode)
	{
		case e_gTraining:
		{
			if(task_exists(RINGTASK))
				remove_task(RINGTASK);
				
			server_cmd( "mp_timelimit 0" )
			server_cmd( "mp_roundtime 9" )
			server_cmd( "mp_freezetime 0" )
			//server_cmd("amxx unpause training_menu.amxx")
			//server_cmd("semiclip_option team 0")
			//server_cmd("semiclip_option semiclip 1")
			//server_cmd( "hns_alltalk 1" )
			server_cmd( "sv_alltalk 1" )
			g_CurrentMode = e_gTraining;
		}
		case e_gKnife:
		{
			//server_cmd("amxx pause training_menu.amxx")
			server_cmd("mp_freezetime 0")
			/*if(g_CurrentMode == e_gCaptain && CaptainSort == true )
			server_cmd("hns_alltalk 1")
			else
			server_cmd("hns_alltalk 0")*/
			server_cmd("mp_timelimit 0")
			//server_cmd("semiclip_option semiclip 0")
			server_cmd("mp_forcechasecam 2")
			server_cmd("mp_forcecamera 2")
			g_CurrentMode = e_gKnife;
		}
		case e_gMix:
		{
			if(task_exists(RINGTASK))
				remove_task(RINGTASK);
				
			//LoadMapCFG();
			g_iScore[0] = 0;
			g_iScore[1] = 0;
			g_iSecondHalf = false;			
			//server_cmd("amxx pause training_menu.amxx")
			if(current_mode == mode_winter)
			{			
				server_cmd("hns_hns 1" )
				//server_cmd("hns_flash 2")
				server_cmd( "hns_footsteps 1" )
				server_cmd("mp_forcechasecam 2")
				server_cmd("mp_forcecamera 2")
				
				//server_cmd( "mp_roundtime 2.5" )
				//server_cmd( "mp_freezetime 5" )
				//server_cmd("semiclip_option semiclip 0")
				//server_cmd("semiclip_option team 3")
				//server_cmd( "hns_alltalk 0" )
			}
			else
			{
				server_cmd("hns_hns 1" )
				//server_cmd("hns_flash 3")
				server_cmd( "hns_footsteps 1" )
				server_cmd("mp_forcechasecam 2")
				server_cmd("mp_forcecamera 2")
				//server_cmd( "mp_freezetime 15" )
				//server_cmd( "hns_alltalk 0" )
			}
			server_cmd( "mp_timelimit 0" )			
			g_CurrentMode = e_gMix;
		}
		case e_gPub:
		{
			g_CurrentMode = e_gPub;
			
			//server_cmd("amxx pause training_menu.amxx")
			server_cmd("mp_forcechasecam 0")
			server_cmd("mp_forcecamera 0")
			server_cmd("hns_switch 1")
			server_cmd("hns_footsteps 1")
			server_cmd("mp_autoteambalance 1")
			server_cmd("mp_roundtime 2.5")
			server_cmd("mp_freezetime 3")
			server_cmd("hns_flash 1")
			server_cmd("hns_block_change 0")
			server_cmd("hns_training 0")
			server_cmd("hns_checkpoints 1")
			server_cmd("hns_hook 1")
			//server_cmd("semiclip_option semiclip 1")
			//server_cmd("semiclip_option team 3")

		}
		case e_gCaptain:
		{
			//server_cmd("amxx pause training_menu.amxx")
			//server_cmd("amxx pause training_menu.amxx")
			//server_cmd("semiclip_option semiclip 0")
			g_CurrentMode = e_gCaptain;			
		}
	}
	
	RestartRound();	
}
public RestartRound()
{
	Survival = false;
	flSidesTime[iCurrentSW] -= g_flRoundTime;
	server_cmd("sv_restart 1");	
}


public FwdKnifePrim( const iPlayer )
{
	if( g_CurrentMode )
	{
		ExecuteHamB( Ham_Weapon_SecondaryAttack, iPlayer );
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}


public FwdDeployKnife( const iEntity )
{
	new iClient = get_pdata_cbase( iEntity, m_pPlayer, EXTRAOFFSET_WEAPONS );
		
	if(gOnOff[iClient] )
	{
		set_pev(iClient, pev_viewmodel, 0)
	}
	else
	{
		set_pev(iClient, pev_viewmodel, alloc_KnifeModel)
	}
	
	if(get_user_team(iClient) == 1 && g_CurrentMode != e_gKnife)
	{
		set_pdata_float( iEntity, m_flNextPrimaryAttack, 9999.0, EXTRAOFFSET_WEAPONS );
		set_pdata_float( iEntity, m_flNextSecondaryAttack, 9999.0, EXTRAOFFSET_WEAPONS );
	}
	return HAM_IGNORED;
}

public Task_Hud(id, Float:Time ,Dhud, Red, Green, Blue, Float:HoldTime, const Text[], any: ... )
{
	new message[128]; vformat( message, charsmax( message ), Text, 9 );
	new Args[7];
	Args[0] = id;
	Args[1] = EncodeText(message);
	Args[2] = Red
	Args[3] = Green
	Args[4] = Blue
	Args[5] = Dhud
	Args[6] = _:HoldTime
	if(Time > 0.0)
	set_task(Time, "Hud_Message", 89000, Args, 7)
	else
	Hud_Message(Args)
}

public Hud_Message(Params[])
{
	new id, Text[128], RRR, GGG, BBB, dhud, Float:HoldTime
	id = Params[0]
	DecodeText(Params[1], Text, charsmax(Text))	
	RRR = Params[2]
	GGG = Params[3]
	BBB = Params[4]
	dhud = Params[5]
	HoldTime = Float:Params[6]
	
	if(!id || is_user_connected(id))
	{
		if(dhud)
		{			
			set_dhudmessage(RRR, GGG, BBB, -1.0, 0.60, 0, 0.0, HoldTime, 0.1, 0.1)
			
			show_dhudmessage(id, Text)
		}
		else
		{
			set_hudmessage(RRR, GGG, BBB, -1.0, 0.60, 0, 0.0, HoldTime, 0.1, 0.1, -1);
			show_hudmessage(id, Text)
		}
	}
}

// Functions
stock fnRegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "")
{
	new szTemp[65], szInfoLang[65];
	format(szInfoLang, 64, "%L", LANG_SERVER, szInfo);
	
	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	
	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);
	
	return PLUGIN_HANDLED;
}

stock EncodeText( const text[] )
{
	return engfunc( EngFunc_AllocString, text )
}

stock DecodeText( const text, string[], const length )
{
	global_get( glb_pStringBase, text, string, length )
}

new bool:plrSolid[MAX_PLAYERS+1]
new bool:plrRestore[MAX_PLAYERS+1]
new plrTeam[MAX_PLAYERS+1]

public addToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if(get_pcvar_num(cvarSemiclip))
		return FMRES_IGNORED;
		
	if(player)
	{
		static Float:flDistance 
		flDistance = entity_range(host, ent) 
		
		if(plrSolid[host] && plrSolid[ent] && plrTeam[host] == plrTeam[ent] && get_user_team(host) != 3 && flDistance < 512.0)
		{
			set_es(es, ES_Solid, SOLID_NOT)
			set_es(es, ES_RenderMode, kRenderTransAlpha)
			set_es(es, ES_RenderAmt, floatround(flDistance)/1)
		}
	}
	
	return FMRES_IGNORED;
}

FirstThink()
{
	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(!is_user_alive(i))
		{
			plrSolid[i] = false
			continue
		}

		plrTeam[i] = get_user_team(i)
		
		plrSolid[i] = pev(i, pev_solid) == SOLID_SLIDEBOX ? true : false
	}
}

public preThink(id)
{
	if(get_pcvar_num(cvarSemiclip))
		return FMRES_IGNORED;
		
	static i, LastThink
	
	if(LastThink > id)
	{
		FirstThink()
	}
	LastThink = id

	
	if(!plrSolid[id]) return FMRES_IGNORED
	
	for(i = 1; i <= g_iMaxPlayers; i++)
	{
		if(!plrSolid[i] || id == i) continue
		
		if(plrTeam[i] == plrTeam[id])
		{
			set_pev(i, pev_solid, SOLID_NOT)
			plrRestore[i] = true
		}
	}
	
	return FMRES_IGNORED;
}

public postThink(id)
{
	if(get_pcvar_num(cvarSemiclip))
		return FMRES_IGNORED;
		
	static i
	
	for(i = 1; i <= g_iMaxPlayers; i++)
	{
		if(plrRestore[i])
		{
			set_pev(i, pev_solid, SOLID_SLIDEBOX)
			plrRestore[i] = false
		}
	}
	return FMRES_IGNORED;
}

public CaptainCmd(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	if(g_CurrentMode != e_gTraining)
		return PLUGIN_HANDLED
		
	g_CurrentMode = e_gCaptain;
	
	new hns_name[32]
	get_user_name(id, hns_name, charsmax(hns_name))
	new iPlayers[32], iNum;
	get_players(iPlayers, iNum);
	
	Captain1 = Captain2 = 0;
	
	for(new i; i < iNum; i++)
	{
		user_silentkill(iPlayers[i]);
		cs_set_user_team(iPlayers[i], 3);
	}
	
	//PrepareMode(e_gKnife);	
	
	client_print_color(0, id, "%L", LANG_SERVER, "GAME_CAP", hns_tag, hns_name);

	//server_cmd("amxx pause training_menu.amxx")
	
	CaptainMenu(id);
	
	return PLUGIN_HANDLED;
}

public StopCaptainCmd(id,level,cid) {
	if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	if(g_CurrentMode == e_gMix || g_CurrentMode == e_gPaused)
		return PLUGIN_HANDLED
		
	new hns_name[32]
	get_user_name(id, hns_name, charsmax(hns_name))
	
	CaptainWinner = CaptainSide = 0;
	Captain1 = Captain2 = 0;
	CaptainSort = false;
	if(task_exists(TASK_MENUCLOSE))
		remove_task(TASK_MENUCLOSE)
		
	if(task_exists(TASK_PLAYERSLIST))
		remove_task(TASK_PLAYERSLIST)
			
	PrepareMode(e_gTraining);	
	
	client_print_color(0, id, "%L", LANG_SERVER, "STOP_CAP", hns_tag, hns_name);
		
	return PLUGIN_HANDLED;
}


// public ReplaceMenu( id )
// {
// 	if(is_user_alive(id) || cs_get_user_team(id) == CS_TEAM_SPECTATOR)
// 	 	return PLUGIN_HANDLED;
	
// 	new menu = menu_create("Choose player:", "replaceMenuHandler")
// 	new callback = menu_makecallback("playermenu_callback");
// 	//set_task(11.5, "menu_task", id + TASK_MENUCLOSE);
	
// 	new players[32], pnum, tempid;
// 	new szName[32], szTempid[10];
	
// 	get_players(players, pnum);
	
// 	if(pnum == 0)
// 	{
// 		remove_task(id+TASK_MENUCLOSE)

// 		if(task_exists(TASK_PLAYERSLIST))
// 			remove_task(TASK_PLAYERSLIST);
		
// 		//client_print(0, print_chat, "%s Closing Captain Sort. Missing players.", hns_tag);
// 		return PLUGIN_HANDLED;
// 	}

// 	new totalnum = 0;
// 	new items = 1;

// 	for(new i; i<pnum; i++)
// 	{
// 		tempid = players[i];
		
// 		if(cs_get_user_team(tempid) != CS_TEAM_SPECTATOR)
// 		{
// 			totalnum++;
// 			continue;
// 		}
		
// 		get_user_name(tempid, szName, charsmax(szName));
// 		num_to_str(tempid, szTempid, charsmax(szTempid));
			
			
// 		if(items && items % 7 == 0)
// 		{		
// 			items++
// 			menu_additem( menu, "\rRefresh playerlist", "*", 0 );
// 		}

// 		items++
		
// 		if(plr_noplay[tempid])
// 		{
// 			add(szName, charsmax(szName), " [Not playing]");
// 			menu_additem( menu, szName, szTempid, 0, callback );	
// 		}
// 		else
// 			menu_additem( menu, szName, szTempid, 0	);
// 	}	

// 	items = menu_items(menu)+1;	
	
// 	if(items % 7 != 0)
// 	{
// 		while(items % 7 != 0)
// 		{
// 			items++;
// 			menu_addblank(menu);					
// 		}
// 	}

// 	menu_additem( menu, "Refresh", "*", 0 );
// 	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	
	
	
// 	menu_display(id, menu, 0);
// 	return PLUGIN_HANDLED;
// }

// public replaceMenuHandler(id, menu, item) {
// 	 if(is_user_alive(id))
// 	 	return PLUGIN_HANDLED
		
// 	if(item == MENU_EXIT)
// 	{
// 		menu_display(id, menu, 0)
// 		return PLUGIN_HANDLED;
// 	}

// 	new data[6], szName[64];
// 	new access, callback;
// 	menu_item_getinfo(menu, item, access, data, charsmax(data), szName, charsmax(szName), callback);
	
// 	if(data[0] == '*')
// 	{
// 		ReplaceMenu(id)
// 		return PLUGIN_HANDLED
// 	}

// 	new tempid = str_to_num(data)
// 	new name[35], namec[35];

// 	get_user_name(tempid, name, charsmax(name));
// 	get_user_name(id, namec, charsmax(namec));
	
// 	cs_set_user_team(tempid, cs_get_user_team(id));
// 	cs_set_user_team(id, CS_TEAM_SPECTATOR);
// 	client_print_color (0, print_team_red, "%L", LANG_SERVER, "PLAYER_REPLACE", hns_tag, namec, name);
	
// 	remove_task(id + TASK_MENUCLOSE)
	
// 	new iPlayers[32], pnum

// 	get_players(iPlayers,pnum, "h")

// 	new bool:has_spec
// 	new totalplayers;

// 	for(new i; i < pnum; i++)
// 	{
// 		if(cs_get_user_team(iPlayers[i]) == CS_TEAM_SPECTATOR)
// 		{
// 			has_spec = true
// 		}
// 		else
// 		{
// 			totalplayers++;
// 		}
// 	}

// 	if(!has_spec || totalplayers == 10)
// 	{
// 		if(task_exists(TASK_PLAYERSLIST))
// 			remove_task(TASK_PLAYERSLIST);
			
// 		return PLUGIN_HANDLED;
// 	}

// 	menu_destroy(menu)
// 	return PLUGIN_HANDLED
// }

public CaptainMenu( id )
{
	//Create a variable to hold the menu
	new menu = menu_create( "\rChoose Player:", "menu_handler" );
	
	//We will need to create some variables so we can loop through all the players
	new players[32], pnum, tempid;
	
	//Some variables to hold information about the players
	new szName[32], szUserId[32];
	
	new callback = menu_makecallback("playermenu_callback"); 
	
	//Fill players with available players
	get_players(players, pnum);
	//Start looping through all players
	new items = 1;

	for ( new i; i<pnum; i++ )
	{
		//Save a tempid so we do not re-index
		tempid = players[i];
		
		//Get the players name and userid as strings
		get_user_name( tempid, szName, charsmax( szName ) );
		//We will use the data parameter to send the userid, so we can identify which player was selected in the handler
		formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( tempid ) );	
		if(items && items%7 == 0)
		{		
			items++
			menu_additem( menu, "Refresh playerlist", "*", 0 );
		}
		if(plr_noplay[tempid] || tempid == Captain1)
		{
			if(plr_noplay[tempid])
			add(szName, charsmax(szName), " [Not playing]");
			menu_additem( menu, szName, szUserId, 0, callback );	
		}
		else menu_additem( menu, szName, szUserId, 0);
	
		items++
	}	
	items = menu_items(menu)+1;	
	if(items % 7 != 0)
	{
		while(items%7 != 0)
		{
			items++;
			menu_addblank(menu);					
		}
	}
		
	menu_additem( menu, "Refresh", "*", 0 );
	//We now have all players in the menu, lets display the menu
	menu_display( id, menu, 0 );
}


public playermenu_callback( id, menu, item )
{
	return ITEM_DISABLED;
}  

public menu_handler( id, menu, item )
{
	//Do a check to see if they exited because menu_item_getinfo ( see below ) will give an error if the item is MENU_EXIT
	if ( item == MENU_EXIT )
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	//now lets create some variables that will give us information about the menu and the item that was pressed/chosen
	new szData[6], szName[64];
	new _access, item_callback;
	//heres the function that will give us that information ( since it doesnt magicaly appear )
	menu_item_getinfo( menu, item, _access, szData,charsmax( szData ), szName,charsmax( szName ), item_callback );
	if(szData[0] == '*')
	{
		CaptainMenu(id);
		return PLUGIN_HANDLED;
	}
	//Get the userid of the player that was selected
	new userid = str_to_num( szData );
	
	//Try to retrieve player index from its userid
	new player = find_player( "k", userid ); // flag "k" : find player from userid
	
	//If player == 0, this means that the player's userid cannot be found
	//If the player is still alive ( we had retrieved alive players when formating the menu but some players may have died before id could select an item from the menu )
	if ( player )
	{
		new szName[64];
		get_user_name( player, szName, charsmax( szName ) );
	 
		if(!Captain1)
		{
			client_print_color(0, id, "%L", LANG_SERVER, "CAP_ONE", hns_tag, szName);
			Captain1 = player;
			
			CaptainMenu(id);
		}
		else
		{
			client_print_color(0, id, "%L", LANG_SERVER, "CAP_TWO", hns_tag, szName);
			Captain2 = player;
			
			cs_set_user_team(Captain1, CS_TEAM_CT);
			cs_set_user_team(Captain2, CS_TEAM_T);
			CaptainWinner = 3;
			server_cmd("sv_restart 1")
			set_task(1.5, "pf_KnifeRound", id);
		}
	}
	
	menu_destroy( menu );
	return PLUGIN_HANDLED;
}
 
public captain_menu(id)
{
	if(id != Captain1 && id != Captain2)
		return PLUGIN_HANDLED;
	
	if(id != CaptainSide)
		return PLUGIN_HANDLED
	
	new menu = menu_create("Choose player:", "captainmenu_handler")
	new callback = menu_makecallback("playermenu_callback");
	//set_task(11.5, "menu_task", id + TASK_MENUCLOSE);
	
	new players[32], pnum, tempid;
	new szName[32], szTempid[10];
	
	get_players(players, pnum);
	
	if(pnum == 0)
	{
		remove_task(id+TASK_MENUCLOSE)
		if(task_exists(TASK_PLAYERSLIST))
			remove_task(TASK_PLAYERSLIST);
		CaptainSort = false
		
		//client_print(0, print_chat, "%s Closing Captain Sort. Missing players.", hns_tag);
		return PLUGIN_HANDLED;
	}
	new totalnum = 0;
	new items = 1;
	for(new i; i<pnum; i++)
	{
		tempid = players[i];
		
		if(cs_get_user_team(tempid) != CS_TEAM_SPECTATOR)
		{
			totalnum++;
			continue;
		}
		
		get_user_name(tempid, szName, charsmax(szName));
		num_to_str(tempid, szTempid, charsmax(szTempid));
			
			
		if(items && items%7 == 0)
		{		
			items++
			menu_additem( menu, "\rRefresh playerlist", "*", 0 );
		}	
		items++
		
		if(plr_noplay[tempid])
		{
			add(szName, charsmax(szName), " [Not playing]");
			menu_additem( menu, szName, szTempid, 0, callback );	
		}
		else
			menu_additem( menu, szName, szTempid, 0	);
	}	
	items = menu_items(menu)+1;	
	if(items%7 != 0)
	{
		while(items % 7 != 0)
		{
			items++;
			menu_addblank(menu);					
		}
	}
	menu_additem( menu, "Refresh", "*", 0 );
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	
	
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public captainmenu_handler(id,menu,item)
{
	if(id != Captain1 && id != Captain2)
		return PLUGIN_HANDLED
		
	if(id != CaptainSide)
		return PLUGIN_HANDLED
		
	if(item == MENU_EXIT)
	{
		menu_display(id,menu,0)
		return PLUGIN_HANDLED;
	}
	new data[6], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), szName, charsmax(szName), callback);
	
	if(data[0] == '*')
	{
		captain_menu(id)
		return PLUGIN_HANDLED
	}
	new tempid = str_to_num(data)
	
	new name[35], namec[35];
	get_user_name(tempid, name, charsmax(name));
	get_user_name(id, namec, charsmax(namec));
	
	cs_set_user_team(tempid, cs_get_user_team(id));
	client_print_color (0, print_team_red, "%L", LANG_SERVER, "CAP_CHOOSE", hns_tag, namec, name);
	
	set_cvar_num("sv_restart",1)
	
	remove_task(id+TASK_MENUCLOSE)
	
	new iPlayers[32],pnum
	get_players(iPlayers,pnum,"h")
	new bool:has_spec
	new totalplayers;
	for(new i; i < pnum; i++)
	{
		if(cs_get_user_team(iPlayers[i]) == CS_TEAM_SPECTATOR)
		{
			has_spec = true
		}
		else
		{
			totalplayers++;
		}
	}
	if(!has_spec || totalplayers == 10)
	{
		if(task_exists(TASK_PLAYERSLIST))
			remove_task(TASK_PLAYERSLIST);
		CaptainSort = false;
		CaptainWinner = CaptainSide = 0;
		Captain1 = Captain2 = 0;
	
		PrepareMode(e_gTraining);
		return PLUGIN_HANDLED;
	}
	if(is_user_connected(Captain1) && is_user_connected(Captain2))
	{
		if(id == Captain1)
			CaptainSide = Captain2
		else
			CaptainSide = Captain1
		set_task(1.5,"captain_menu", CaptainSide)
	}
	else
	{
		set_task(5.0,"CheckCaptainJoin",id == Captain1 ? Captain1 : Captain2)
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public menu_task(id)
{
	id -= TASK_MENUCLOSE
	
	new players[32], pnum;
	get_players(players, pnum, "h");
	
	new randomnum = random(pnum)
	new bool:has_spec
	new totalplayers;
	for(new i; i < pnum; i++)
	{
		if(cs_get_user_team(players[i]) == CS_TEAM_SPECTATOR)
		{
			has_spec = true
		}
		else
		{
			totalplayers++;
		}
	}
	if(!has_spec || totalplayers == 10)
	{
		if(task_exists(TASK_PLAYERSLIST))
			remove_task(TASK_PLAYERSLIST);
		
		PrepareMode(e_gTraining);
		CaptainSort = false;
		return;
	}
	while(cs_get_user_team(players[randomnum]) != CS_TEAM_SPECTATOR)
	{
		randomnum = random(pnum)
	}
	if(is_user_connected(id))
	{
		set_cvar_num("sv_restart",1)
		cs_set_user_team(players[randomnum],cs_get_user_team(id))
		
		set_task(1.5, "captain_menu", id == Captain1 ? Captain2 : Captain1);
	}
	else
	{
		set_task(5.0, "CheckCaptainJoin", id == Captain1 ? Captain2 : Captain1);
		
		client_print(0, print_chat, "%s Awaiting the arrival of a new Captain.", hns_tag);
	}
	show_menu(id, 0, "^n", 1);
}

public CheckCaptainJoin(NextCaptainMenu)
{
	if(is_user_connected(Captain1) && is_user_connected(Captain2))
	{
		set_task(1.5, "captain_menu", NextCaptainMenu)
	}
	else
	{
		set_task(5.0, "CheckCaptainJoin", NextCaptainMenu)
	}
}

public PlayersList()
{
	new iPlayers[32], iNum;
	get_players(iPlayers, iNum, "h");
	
	new posTR, posCT, posSPEC;
	new HudTextTR[512], HudTextCT[512], HudTextSPEC[512];
	new szName[38], name[38];
	
	for(new i; i < iNum; i++)
	{
		get_user_name(iPlayers[i], szName, charsmax(szName));
		
		if(iPlayers[i] == Captain1 || iPlayers[i] == Captain2)
		{
			formatex(name, charsmax(name), "%s [Captain]", szName);
		}
		else
		{
			name = szName;
		}
		if(cs_get_user_team(iPlayers[i]) == CS_TEAM_T)
		{
			posTR += formatex(HudTextTR[posTR], 511-posTR,"%s^n", name);
		}
		else if(cs_get_user_team(iPlayers[i]) == CS_TEAM_CT)
		{
			posCT += formatex(HudTextCT[posCT], 511-posCT, "%s^n", name);
		}
		else
		{
			posSPEC += formatex(HudTextSPEC[posSPEC], 511-posSPEC, "%s^n", name);
		}
	}
	for(new i; i < iNum; i++)
	{
		
		set_hudmessage(	180, 40, 40, 0.70, 0.16, 0, 0.0, 0.2, 0.2, 0.2, -1);
		ShowSyncHudMsg(iPlayers[i], SyncHud[0], "Hiders:^n%s", HudTextTR);
		
		set_hudmessage(40, 80, 150, 0.70, 0.51, 0, 0.0, 0.2, 0.2, 0.2, -1);
		ShowSyncHudMsg(iPlayers[i], SyncHud[1], "Seekers:^n%s", HudTextCT);
	}
}

public LoadMapCFG()
{
	new szMap[64]
	get_mapname(szMap, 63);	
	new szPath[128]
	get_configsdir(szPath, 127);
	format(szPath, 127, "%s/hns", szPath);
	if(!dir_exists(szPath))	
		mkdir(szPath);
	format(szPath, 127, "%s/mapcfg", szPath);	
	if(!dir_exists(szPath))	
		mkdir(szPath);
		
	format(szPath, 127, "%s/%s.cfg", szPath, szMap);
	if(file_exists(szPath))
	{
		server_cmd("exec %s", szPath);
	}
	else
	{
		server_cmd("mp_roundtime 3.5");
	}
}

public bool:CheckPlayer(id)
{
	new szSteam[64];
	get_user_authid(id, szSteam, 63);
	new szMap[64]
	get_mapname(szMap, 63);
	if(containi(szMap, "valkyrie") != -1)
	{
		return false;
	}
	new string[128];
	new side;
	new exploded[2][64]
	
	new PlayersFile = fopen("addons/amxmodx/data/playerslist.ini", "r");
	
	if(PlayersFile)
	{
		while(!feof(PlayersFile))
		{
			fgets(PlayersFile, string, 127)
			if(containi(string, szSteam) != -1)
			{
				ExplodeString(exploded,2,63,string, ' ' );
				side = str_to_num(exploded[1]);
				break;
			}
		}
		
		fclose(PlayersFile);
	}	
	
	if(side == 1)
	{
		cs_set_user_team(id, CS_TEAM_T);
	}
	else if(side == 2)
	{
		cs_set_user_team(id, CS_TEAM_CT);
	}
	else
	{
		cs_set_user_team(id, CS_TEAM_SPECTATOR);
		return false;
	}
	
	return true;
}

public SavePlayers()
{
	if(file_exists("addons/amxmodx/data/playerslist.ini"))
		delete_file("addons/amxmodx/data/playerslist.ini");
		
	new PlayersFile = fopen("addons/amxmodx/data/playerslist.ini", "w");
	new players[MAX_PLAYERS], num;	
	get_players(players, num, "ae", "TERRORIST");
	
	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(!is_user_connected(i))
			continue;
		
		new szString[128];
		new Steam[64]
		get_user_authid(i, Steam, 63);
		if(!num)
		{
			if(get_user_team(i) == 1)
				format(szString, 127, "%s %d^r^n", Steam, 2)
			else if(get_user_team(i) == 2)
				format(szString, 127, "%s %d^r^n", Steam, 1)
			else
				format(szString, 127, "%s %d^r^n", Steam, get_user_team(i))
		}
		else
			format(szString, 127, "%s %d^r^n", Steam, get_user_team(i))
					
		fputs(PlayersFile, szString);
	}
	
	fclose(PlayersFile);
}


public TaskDestroyBreakables( ) 
{
	new iEntity = -1;
	while ((iEntity = find_ent_by_class(iEntity, "func_breakable" )))
	{
		if(entity_get_float(iEntity , EV_FL_takedamage)) 
		{			
			entity_set_vector(iEntity, EV_VEC_origin, Float:{10000.0, 10000.0, 10000.0})			
		}
	}
}

public Forward_SetClientListening(iReceiver, iSender, bool:bListen)
{	
	if(g_CurrentMode <= e_gPaused || g_CurrentMode == e_gCaptain || g_CurrentMode == e_gPub)
	{
		engfunc(EngFunc_SetClientListening, iReceiver, iSender, true)
		forward_return(FMV_CELL, true)
		return FMRES_SUPERCEDE
	}
	
	if(is_user_connected(iReceiver) && is_user_connected(iSender))
	{
		if(get_user_team(iReceiver) == get_user_team(iSender))
		{
			engfunc(EngFunc_SetClientListening, iReceiver, iSender, true)
			forward_return(FMV_CELL, true)
			return FMRES_SUPERCEDE
		}
		else if(get_user_team(iReceiver) != 1 && get_user_team(iReceiver) != 2 )
		{
			engfunc(EngFunc_SetClientListening, iReceiver, iSender, true)
			forward_return(FMV_CELL, true)
			return FMRES_SUPERCEDE
		}
	}
	
	engfunc(EngFunc_SetClientListening, iReceiver, iSender, false)
	forward_return(FMV_CELL, false)
	return FMRES_SUPERCEDE
}

#define SAFETRANSFERTASK 7832

public safe_transfer( CsTeams:iTeam)
{
	new Float:flTime
	new iPlayers[ 32 ], iPlayersNum
	get_players( iPlayers, iPlayersNum, "h");
	for(new i = 0; i < iPlayersNum; i++)
	{
		new id = iPlayers[i];
		if(is_user_connected(id))
		{
			switch(id)
			{
				case 1..8: flTime = 0.1;
				case 9..16: flTime = 0.2;
				case 17..24: flTime = 0.3;
				case 25..32: flTime = 0.4;
			}
			
			new task_params[2];
			task_params[0] = id;
			task_params[1] = _:iTeam;
	
			if(task_exists(SAFETRANSFERTASK+id))
				remove_task(SAFETRANSFERTASK+id)
				
			set_task(flTime, "task_to_team", SAFETRANSFERTASK+id, task_params, sizeof task_params);
		}
	}
}

public task_to_team( Params[] )
{	
	new id = Params[0];
	new team = Params[1];
	if(is_user_connected(id))
	{
		if(is_user_alive(id))
			user_kill(id, 0)
		if(get_user_team(id) != team)
		{
			cs_set_user_team(id, team);
		}		
	}
}


public SaveState(id)
{
	new temp_array[SaveData];
	temp_array[save_team] = get_user_team(id);
	get_user_authid(id, temp_array[SteamID], 31);
	pev(id, pev_origin, temp_array[Origin]);
	pev(id, pev_velocity, temp_array[Velocity]);
	pev(id, pev_v_angle, temp_array[Angles]);
	temp_array[Flags] = pev(id, pev_flags);
	if(is_user_alive(id))
		temp_array[health] = get_user_health(id);
	else
		temp_array[health] = 0;
	
	new clip,ammo
	get_user_ammo(id,CSW_FLASHBANG,clip,ammo);
	temp_array[flashnum] = ammo;
	get_user_ammo(id,CSW_SMOKEGRENADE,clip,ammo);
	temp_array[smokenum] = ammo;
	ArrayPushArray(SavedState, temp_array);	
}

public LoadState(id, temp_array[SaveData])
{
	strip_user_weapons(id)
	Timer(id, SavedTime);
	set_user_footsteps(id, 1);
	
	set_pev(id, pev_origin, temp_array[Origin]);
	set_pev(id, pev_velocity, temp_array[Velocity]);
	set_pev(id, pev_angles, temp_array[Angles]);
	set_pev(id, pev_fixangle, 1);
	set_pev(id, pev_flags, temp_array[Flags]);
	if(temp_array[health])
		set_user_health(id, temp_array[health]);
	else if(is_user_alive(id))
	{
		user_silentkill(id);
	}
	
	give_item(id, "weapon_knife")
	if(temp_array[smokenum])
	{
		give_item( id, "weapon_flashbang" );
		cs_set_user_bpammo( id, CSW_FLASHBANG, temp_array[flashnum] );
	}
	if(temp_array[smokenum])
	{
		give_item( id, "weapon_smokegrenade" );
		cs_set_user_bpammo( id, CSW_SMOKEGRENADE, temp_array[smokenum] );
	}
	ArrayPushArray(SavedState, temp_array);	
}

public cmdsavegame(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED;
		
	if(g_CurrentMode != e_gMix)
	{
		client_print_color(id, id, "^1[^4%s^1] Game state can be ^4saved ^1only on live match.", hns_tag);
		return PLUGIN_HANDLED;
	}
		
	new bool:exists = true;
	static temp_array[SaveData];
	while(exists)
	{
		exists = false;
		new isize = ArraySize(SavedState)
		for(new i = 0; i < isize; i++)
		{
			ArrayGetArray(SavedState, i, temp_array);
			if(find_player("c", temp_array[SteamID]))
			{
				exists = true;
				ArrayDeleteItem(SavedState, i);
				break;
			}
		}
	}
	GameSaved = true;
	
	new players[MAX_PLAYERS], pnum;
	get_players(players, pnum);
	
	SavedTime = (get_cvar_num("mp_roundtime")*60)-floatround(get_gametime()-StartRoundTime);
	
	for(new i = 0 ; i < pnum; i++ )
	{
		new plr = players[i];
		if(get_user_team(plr) == 1 || get_user_team(plr) == 2)
			SaveState(plr);
		else
			continue;
	}
	new szName[128]
	get_user_name(id, szName, charsmax(szName))
	client_print_color(0, id, "^1[^4%s^1] ^3%s ^4saved gamestate!", hns_tag, szName);
	
	return PLUGIN_HANDLED;
}

public cmdloadgame(id)
{
	if(!(get_user_flags(id) & hns_ACESS))
		return PLUGIN_HANDLED;
		
	if(!GameSaved)
	{
		client_print_color(id, id, "^1[^4%s^1] Nothing to load... (^4Game was not saved^1)", hns_tag);
		return PLUGIN_HANDLED;
	}
		
	if(task_exists(71234))
		remove_task(71234);
	
	SavedFreezeTime = get_cvar_num("mp_freezetime");
	server_cmd("sv_restart 1");
	server_cmd("mp_freezetime 0");
	set_task(2.0, "loadgame", 71234);
	new szName[128]
	get_user_name(id, szName, charsmax(szName))
	client_print_color(0, id, "^1[^4%s^1] ^3%s ^4loaded ^1saved game!", hns_tag, szName);
	
	return PLUGIN_HANDLED;
}
public loadgame()
{		
	new players[MAX_PLAYERS], pnum;
	get_players(players, pnum);
	server_cmd("mp_freezetime %d", SavedFreezeTime);	
	loadgamefunc(1);
	
	for(new i = 0 ; i < pnum; i++ )
	{
		new id = players[i];
		if(get_user_team(id) == 1 || get_user_team(id) == 2)
		{
			Timer(id, 10);
			set_user_freeze(id, 1);
		}
	}
	
	set_task(10.0, "loadgamefunc", 0);

	
	
	return PLUGIN_HANDLED;
}

public loadgamefunc(preload)
{
	if(task_exists(ROUNDENDTASK))
		remove_task(ROUNDENDTASK);
	
	if(!preload)
	set_task(float(SavedTime), "TTWin", ROUNDENDTASK);
	new players[MAX_PLAYERS], pnum, anum;
	get_players(players, anum, "a");
	get_players(players, pnum);
	new bool:found[MAX_PLAYERS+1], foundnum;
	static sz_steam[32]
	static temp_array[SaveData];
	new isize = ArraySize(SavedState)
	for(new i = 0 ; i < pnum; i++ )
	{
		new id = players[i];
		if(get_user_team(id) != 1 && get_user_team(id) != 2)
			continue;
		
		set_user_freeze(id, 0);
		get_user_authid(id, sz_steam, 31);
		for(new i = 0; i < isize; i++)
		{
			ArrayGetArray(SavedState, i, temp_array);
			if(equal(temp_array[SteamID], sz_steam))
			{
				LoadState(id, temp_array);
				found[id] = true;
				foundnum++;
				break;
			}
		}
		/*client_print(0, print_chat, "%d", index);
		if(index != -1)
		{
			ArrayGetArray(SavedState, index, temp_array);
			LoadState(id, temp_array);
			found[id] = true;
			foundnum++;
		}*/
	}
	if(foundnum < anum)
	{		
		for(new i = 0; i < isize; i++)
		{
			if(foundnum >= anum)
				break;
				
			ArrayGetArray(SavedState, i, temp_array);
			if(find_player("c", temp_array[SteamID]))
				continue
			else
			{
				for(new i = 0 ; i < pnum; i++ )
				{
					new id = players[i];
					if(found[id])
						break;
					else if(temp_array[save_team] == get_user_team(id))
					{
						found[id] = true;
						LoadState(id, temp_array);
						foundnum++;
					}
				}
			}
		}
	}
}


stock set_user_freeze(client,freeze){
	new iFlag = pev(client,pev_flags);
	set_pev(client,pev_flags,freeze ? iFlag | FL_FROZEN:iFlag & ~FL_FROZEN);
}


public Timer(id, Time)
{
	message_begin(MSG_ONE, g_msg_showtimer, _, id)
	message_end()
	
	message_begin(MSG_ONE, g_msg_roundtime, _, id)
	write_short(Time+1)
	message_end()
}



public RingTask()
{
	static Ent1, Ent2;
	
	if(!Ent1)
	{
		Ent1 = fm_create_entity("info_target");
		fm_entity_set_model(Ent1, "sprites/laserbeam.spr");
		fm_set_rendering(Ent1, .render = kRenderTransAlpha, .amount = 0);
		
	}
		
	if(!Ent2)
	{
		Ent2 = fm_create_entity("info_target");
		fm_entity_set_model(Ent2, "sprites/laserbeam.spr");
		fm_set_rendering(Ent2, .render = kRenderTransAlpha, .amount = 0);
	}
	
	new Float:NewOrigin[3];
	NewOrigin[1] = 0.0;
	NewOrigin[2] = 50.0;
	NewOrigin[0] = RingWidth;
	set_pev(Ent1, pev_origin, NewOrigin);	
	NewOrigin[0] = -RingWidth;
	set_pev(Ent2, pev_origin, NewOrigin);
	if(RingWidth > 150.0)
	{
		RingWidth -= 5.0;
		make_tracer(Ent1, Ent2, 1);
	}
	else
	{		
		make_tracer(Ent1, Ent2, 1);
	}
	
	new Float:tempmax[3];
	new Float:tempmin[3];
	tempmin[0] = tempmin[1] = -RingWidth;
	tempmin[2] = -1000.0;
	tempmax[0] = tempmax[1] = RingWidth;
	tempmax[2] = 1000.0;
	new players[MAX_PLAYERS], pnum;
	get_players(players, pnum, "a");
	for(new i = 0; i < pnum; i++)
	{
		new id = players[i];
		new Float:origin[3];
		if(is_user_alive(id))
		{
			pev(id, pev_origin, origin);
			if(get_distance_f(Float:{0.0, 0.0, 0.0}, origin) > RingWidth)
			{
				ExecuteHam(Ham_TakeDamage, id, 0, 0, 2.0, DMG_GENERIC);
			}
		}		
	}
	
	return PLUGIN_HANDLED
	
}

public make_tracer(first, sec, life)
{
	new red, green, blue;
	dynamicColor(-2300, 0, -RingWidth, red, green, blue);
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte(TE_BEAMRING)
	write_short(first) // start
	write_short( sec) // end
	write_short(m_spriteTexture) // sprite
	write_byte(0) // starting frame
	write_byte(0) // rate
	write_byte(life) // life
	write_byte(100) // widght
	write_byte(0) // noise
	write_byte(red) // red
	write_byte(green); // green
	write_byte(blue) // blue
	write_byte(255) // bright
	write_byte(5) // 
	message_end(); 
} 


stock dynamicColor(min,max,Float:value,&red,&green,&blue)
{ //Don`t launch with max ~= min 
	#define MaxC 255
	#define MinC 0
	#define DtC 50

	if (value>=max)
	{
		red=MaxC;
		green=MinC;
		blue=MinC;
		return;
	}
	else if (value<=min)
	{
		red=MinC;
		green=MinC;
		blue=MaxC;
		return;
	}

	new Float:step = (max-min)/4.0;
	new Float:dt = value-min;

	if (dt <= step)
	{
		red   = MinC;
		green = floatround(dt*(DtC/step));
		blue  = MaxC;
	}
	else if (dt-=step, dt <= step)
	{
		red   = MinC;
		green = MaxC;
		blue  = floatround((step-dt)*(DtC/step));
	}
	else if (dt-=step, dt <= step)
	{
		red   = floatround(dt*(DtC/step));
		green = MaxC;
		blue  = MinC;
	}
	else
	{
		dt-=step;
		red   = MaxC;
		green = floatround((step-dt)*(DtC/step));
		blue  = MinC;
	}
	return;
}
// Avererage 25
// 1000 / 1300
// +32.5 / +17.5
// -17.5 / -32.5
// 16.25 / 8.75
#define DEF_RATIO 25.0


public plugin_end() {
	if(iFwd_MixFinished)
	DestroyForward(iFwd_MixFinished);
}


public ach_add_progress(id, ach)
{

}

/*
public Announce ( Type )
{
	new players[MAX_PLAYERS], pnum;
	get_players(players, pnum);
	static CTPlayers[512]
	static TTPlayers[512]
	new iLenTT, iLenCT
	for(new i = 0; i < pnum; i++)
	{
		new id = players[i];
		if(get_user_team(id) != 1 && get_user_team(id) != 2)
			continue
		
		new sz_name[64]
		get_user_name(id, sz_name, 63);
		if(get_user_team(id) == 1)
		{
			iLenTT += format(TTPlayers[iLenTT], charsmax(TTPlayers)-iLenTT, "%s [%d] ", sz_name, iPts[id]);
		}
		else
		{
			iLenCT += format(CTPlayers[iLenCT], charsmax(CTPlayers)-iLenCT, "%s [%d] ", sz_name, iPts[id]);
		}
	}
	static Message[1024];
	new sz_mapname[64]
	get_mapname(sz_mapname, 63);
	switch( Type )
	{
		case 1:
		{
			format(Message, charsmax(Message), "??????N? ???�N�?�?�N?N?! ?s?�N�N�?�: %s^n Seekers :%s ^n vs ^n Hiders: %s", sz_mapname, CTPlayers, TTPlayers);
			send_message(Message, strlen(Message));
		}
		case 2:
		{
			format(Message, charsmax(Message), "??????N? ?�?�??????N�???�N?N? N??? N?N�?�N�???? %d %d ! ?s?�N�N�?�: %s", g_iScore[0], g_iScore[1], sz_mapname);
			send_message(Message, strlen(Message));
		}
		case 3:
		{
			format(Message, charsmax(Message), "???�N�???�N�N? ??N??�??N� ????N�??????! ?s?�N�N�?�: %s (%d ????N�???????? ???� N??�N�???�N�?�) ^n steam://connect/37.230.210.230:27015", sz_mapname, pnum);
			send_message(Message, strlen(Message));
		}
	}
	
	
}*/

public fnConvertTime( Float:time, convert_time[], len )
{
	new sTemp[24];
	new Float:fSeconds = time, iMinutes;

	iMinutes		= floatround( fSeconds / 60.0, floatround_floor );
	fSeconds		-= iMinutes * 60.0;
	new intpart		= floatround( fSeconds, floatround_floor );
	new Float:decpart	= (fSeconds - intpart) * 100.0;
	intpart			= floatround( decpart );

	formatex( sTemp, charsmax( sTemp ), "%02i:%02.0f.%d", iMinutes, fSeconds, intpart );


	formatex( convert_time, len, sTemp );

	return(PLUGIN_HANDLED);
}

const INT_BYTES = 4
const BYTE_BITS = 8

stock ExplodeString( p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter )
{
	new nIdx	= 0, l = strlen( p_szInput );
	new nLen	= (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter ) );
	while ( (nLen < l) && (++nIdx < p_nMax) )
		nLen += (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter ) );
	return(nIdx);
}

public EndMatch()
{
	if(current_mode == mode_timebased)
	{
		SoundFx = false;
		GameStarted = false;
		Survival = false;

		new szTeam[64]
		new survivalTime[24];
		new Float:TimeDiff

		new iPlayers[32], iNum;
		get_players(iPlayers, iNum);

		new max = flPlayerTime[0];
		new tempId;

		for(new id = 0; id < iNum; id++) {
			
			if(max < flPlayerTime[id]) {
				max = flPlayerTime[id];
				tempId = id;
			}
		}

		fnConvertTime(max, survivalTime, 23);

		new mostName[32];
		get_user_name(tempId, mostName, charsmax(mostName));

		get_pcvar_string(cvarTeam[iCurrentSW], szTeam, 63)

		if(iCurrentSW)
			TimeDiff = flSidesTime[0] - flSidesTime[iCurrentSW];
		else
			TimeDiff = flSidesTime[1] - flSidesTime[iCurrentSW];
		
		new sTime[24];
		fnConvertTime( TimeDiff, sTime, 23 );

		 for(new i = 0 ; i < 5; i++)
		client_print_color(0,print_team_red,"^1[^4%s^1] ^3%s won the match! (%s difference)", hns_tag, szTeam, sTime)

		client_print_color(0, print_team_red, "^1[^4%s^1] ^3%s has the best survival time with ^4%s^1!", hns_tag, mostName, survivalTime);

	}
	else 
	{
		for(new i = 0 ; i < 5; i++)
			Score(0);
	}
	g_iScore[0] = 0;
	g_iScore[1] = 0;
	g_iSecondHalf = false;
	PrepareMode(e_gTraining);
}

getSelectedPlayerInMenu(const hMenu, const item)
{
	new selectedPlayerId = find_player("k", getSelectedInteger(hMenu, item));
	return selectedPlayerId && is_user_connected(selectedPlayerId) ? selectedPlayerId : 0;
}

getSelectedInteger(const hMenu, const item)
{
	static szData[6], szName[32];
	new _access, item_callback;
	menu_item_getinfo(hMenu, item, _access, szData, charsmax(szData), szName, charsmax(szName), item_callback);
	
	return str_to_num(szData);
}

getSelectedCharacter(const hMenu, const item)
{
	static szData[2], szName[32];
	new _access, item_callback;
	menu_item_getinfo(hMenu, item, _access, szData, charsmax(szData), szName, charsmax(szName), item_callback);
	
	return szData[0];
}

getTeamColor(const CsTeams:iTeam)
{
	return iTeam == CS_TEAM_T ? print_team_red : (iTeam == CS_TEAM_CT ? print_team_blue : print_team_grey);
}

instantPlayerTransfer(const id, const CsTeams:iNewTeam, const iMenuMsgId)
{
	if (is_user_connected(id))
	{
		if (is_user_alive(id))
		{
			user_kill(id, 1);
		}
		
		new CsTeams:iCurrentTeam = cs_get_user_team(id);
		
		if (iCurrentTeam != iNewTeam)
		{
			resetHasChangedTeamThisRound(id);
			
			if (iMenuMsgId)
			{
				set_msg_block(iMenuMsgId, BLOCK_SET);
			}
			
			if (iCurrentTeam == CS_TEAM_UNASSIGNED && iNewTeam == CS_TEAM_SPECTATOR)
			{
				set_pdata_int(id, m_iNumRespawns, 1);
				
				engclient_cmd(id, "jointeam", "5");
				engclient_cmd(id, "joinclass", "5");
			}
			
			switch (iNewTeam)
			{
				case CS_TEAM_SPECTATOR:
				{
					cs_set_user_team(id, CS_TEAM_SPECTATOR);
				}
				case CS_TEAM_T:
				{
					engclient_cmd(id, "jointeam", "1");
					engclient_cmd(id, "joinclass", "5");
				}
				case CS_TEAM_CT:
				{
					engclient_cmd(id, "jointeam", "2");
					engclient_cmd(id, "joinclass", "5");
				}
			}
			
			if (iMenuMsgId)
			{
				set_msg_block(iMenuMsgId, BLOCK_NOT);
			}
			
			resetHasChangedTeamThisRound(id);
		}
	}
}

MakeCountDown( Float:flTimeleft , Float:flFrequency = 1.0 )
{
	if( !g_entCountDown )
	{
		g_entCountDown = create_entity("info_target")
		new const szClass[] = "countdown"
		register_think(szClass, "CountDown")
		set_pev(g_entCountDown, pev_classname, szClass)
	}
	g_flTimeLeft = flTimeleft
	g_flFreq = flFrequency
	set_pev(g_entCountDown, pev_nextthink, get_gametime())
	call_think(g_entCountDown)
}

public CountDown( iEntity )
{
	if( iEntity != g_entCountDown )
	{
		return
	}

	set_pev(g_entCountDown, pev_nextthink, get_gametime() - g_flFreq)
	g_flTimeleft -= g_flFreq

	new iPlayers[32], iNum;
	get_players(iPlayers, iNum);

	if(g_flTimeleft == 0.0) {
		for(new id = 0; id < iNum; id++) {
			if(get_user_flags(id) & ADMIN_BAN) {

			} 
		}
	}
}  

/*public Enable_SlowMo()
{
	g_iScore[0] = 0;
	g_iScore[1] = 0;
	g_iSecondHalf = false;
	SlowMo = true;
}*/

/*public Disable_SlowMo()
{
	//RemoveBlockControl(RC_CheckWinConditions,g_pCheckWinHook);
	PrepareMode(e_gTraining);
	SlowMo = false;
}*/
/*
public OnPM_move(move,server) 
{  
	if(SlowMo)
	{
		new OrpheuStruct:cmd = OrpheuStruct:OrpheuGetParamStructMember( 1 , "cmd" ); 
		set_uc(_:cmd, UC_Msec, 2); //working (like plugin slow-mo)  
	}
}
*/
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
