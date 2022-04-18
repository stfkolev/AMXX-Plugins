#include <amxmodx>
#include <cstrike>
#include <hamsandwich>

#define PLUGIN  "Best Player"
#define VERSION "1.1a"
#define AUTHOR  "Autumn Shade"

enum _:PlayerData
{
    Kills,
    Float:SurviveTime,
    Float:KillTime
}

new g_ePlayersData[33][PlayerData];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    /*! Forwards */
    register_logevent("fwRoundEnd", 2, "1=Round_End");
    register_logevent("fwRoundStart", 2, "1=Round_Start") 

    /*! Ham */
    RegisterHam(Ham_Killed, "player", "fwPlayerKilled")
}

public fwRoundStart() {
    new iPlayers[32], iNum;

    get_players(iPlayers, iNum, "ach");

    for(new index = 0; index < iNum; index++) {
        new id = iPlayers[index];

        if(!is_user_alive(id) || !is_user_connected(id))
            return PLUGIN_CONTINUE;

        if(cs_get_user_team(id) == CS_TEAM_T) {
            g_ePlayersData[id][SurviveTime] = get_gametime();
        } else if(cs_get_user_team(id) == CS_TEAM_CT) {
            g_ePlayersData[id][KillTime] = get_gametime();
            g_ePlayersData[id][Kills] = 0;
        }
    }

    return PLUGIN_HANDLED;    
}

public fwRoundEnd() {
    new iPlayers[32], iNum;

    get_players(iPlayers, iNum, "ch");

    for(new index = 0; index < iNum; index++) {
        new id = iPlayers[index];

        if(!is_user_connected(id))
            return PLUGIN_CONTINUE;

        showBestMenu(id);
    }

    return PLUGIN_HANDLED;
}

public fwPlayerKilled(iVictim, iAttacker, iCorpse) {

    if(!is_user_connected(iVictim) || !is_user_connected(iAttacker))
        return PLUGIN_CONTINUE;
        
    if(cs_get_user_team(iVictim) == CS_TEAM_T && cs_get_user_team(iAttacker) == CS_TEAM_CT) {
        g_ePlayersData[iAttacker][KillTime] =  floatsub(get_gametime(), g_ePlayersData[iAttacker][KillTime]);
        g_ePlayersData[iVictim][SurviveTime] =  floatsub(get_gametime(), g_ePlayersData[iVictim][SurviveTime]);
        g_ePlayersData[iAttacker][Kills]++;
    }

    return HAM_HANDLED;
}

/*! Menu */
stock showBestMenu(id) {
    new iMenu = menu_create("\yBest players this round:", "iHandler");

    new iBestHiderId = getBestHider();
    new iBestSeekerId = getBestSeeker();
    new iHiderName[32], iSeekerName[32], iTemp[512], iHiderTime[23], iSeekerTime[23];

    convertTime(g_ePlayersData[iBestHiderId][SurviveTime], iHiderTime, charsmax(iHiderTime));
    convertTime(g_ePlayersData[iBestSeekerId][KillTime], iSeekerTime, charsmax(iSeekerTime));

    get_user_name(iBestHiderId, iHiderName, charsmax(iHiderName));
    get_user_name(iBestSeekerId, iSeekerName, charsmax(iSeekerName));

    formatex(iTemp, charsmax(iTemp), "\rBest Hider: \w%s^n\ySurvival Time: \w%s^n^n", iHiderName, iHiderTime);
    menu_additem(iMenu, iTemp);

    formatex(iTemp, charsmax(iTemp), "\rBest Seeker: \w%s ^n\yFirst Kill: \w%s ^n\yKills: \w%d", iSeekerName, iSeekerTime, g_ePlayersData[iBestSeekerId][Kills]);
    menu_additem(iMenu, iTemp);

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    menu_display(id, iMenu, 0);
}

public iHandler(id, iMenu, iItem) {
    menu_destroy(iMenu);

    return PLUGIN_HANDLED;
}

/*! Stocks */
stock getBestHider() {
    new iPlayers[32], iNum;

    get_players(iPlayers, iNum, "ceh", "TERRORIST");

    new iBestPlayerId = iPlayers[0];

    for(new index = 0; index < iNum; index++) {
        new id = iPlayers[index];

        if(!is_user_connected(id))
            return 0;

        if(g_ePlayersData[id][SurviveTime] > g_ePlayersData[iBestPlayerId][SurviveTime]) {
            iBestPlayerId = id;
        }
    }

    return iBestPlayerId;
}

stock getBestSeeker() {
    new iPlayers[32], iNum;

    get_players(iPlayers, iNum, "ceh", "CT");

    new iBestPlayerId = iPlayers[0];

    for(new index = 0; index < iNum; index++) {
        new id = iPlayers[index];

        if(!is_user_connected(id))
            return 0;

        //  && g_ePlayersData[id][Kills] < g_ePlayersData[iBestPlayerId][Kills]
        if(g_ePlayersData[id][KillTime] < g_ePlayersData[iBestPlayerId][KillTime]) {
            iBestPlayerId = id;
        }
    }

    return iBestPlayerId;
}

stock convertTime(Float:iTime, iDest[], iLen ) {
	new iTemp[24];
	new Float:iSeconds = iTime, iMinutes;

	iMinutes		= floatround(iSeconds / 60.0, floatround_floor);
	iSeconds		-= iMinutes * 60.0;
	new intpart		= floatround(iSeconds, floatround_floor);
	new Float:decpart	= (iSeconds - intpart) * 100.0;
	intpart			= floatround(decpart);

	formatex(iTemp, charsmax(iTemp), "%02i:%02.0f.%d", iMinutes, iSeconds, intpart);
	formatex(iDest, iLen, iTemp);

	return PLUGIN_HANDLED;
}