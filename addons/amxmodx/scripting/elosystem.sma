#include <amxmodx>
#include <nvault>
#include <colorchat>
#include <cstrike>

#define PLUGIN_NAME     "Elo Rating System"
#define PLUGIN_VERSION  "1.0"
#define PLUGIN_AUTHOR   "TakeADayTrip"

#define MAXPLAYERS  32
#define HIDERS      0
#define SEEKERS     1

/*! Cvars */
new g_cStartingPoints;
new g_cMinimumFallDamage;
new g_cMaximumFallDamage;
new g_cFallDamageRatio;
new g_cSuicideRatio;
new g_cSurviveRoundRatio;
new g_cLoseRoundRatio;

/*! Vault */
new g_Vault;

/*! Player Variables */
new g_PlayerRating[MAXPLAYERS + 1];
new g_PlayerWins[MAXPLAYERS + 1];
new g_PlayerLosses[MAXPLAYERS + 1];

/*! Team Variables */
new g_TeamRating[2];

/*! Plugin Initialization */
public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    /*! Commands */
    register_clcmd("say /rating",           "cmdRating");
    register_clcmd("say_team /rating",      "cmdRating");
    register_clcmd("say /teamrating",       "cmdTeamRating");
    register_clcmd("say_team /teamrating",  "cmdTeamRating");

    register_clcmd("say /reset",            "cmdReset");

    register_clcmd("ers_setrating",         "cmdSetRating", ADMIN_ALL, " <player> <rating>");
    
    /*! Cvars */
    g_cStartingPoints           = register_cvar("ers_starting_points",      "1000");
    g_cMinimumFallDamage        = register_cvar("ers_min_fall_damage",      "35");
    g_cMaximumFallDamage        = register_cvar("ers_max_fall_damage",      "65");
    g_cFallDamageRatio          = register_cvar("ers_fall_damage_ratio",    "0.225");
    g_cSuicideRatio             = register_cvar("ers_suicide_ratio",        "0.473");
    g_cSurviveRoundRatio        = register_cvar("ers_survive_round_ratio",  "0.473");
    g_cLoseRoundRatio           = register_cvar("ers_lose_round_ratio",     "0.473");

    /*! Events */
    register_event("Damage", "fwFallDamage", "b", "2>0");
    register_event("DeathMsg", "fwSuicide", "a");
    register_message(get_user_msgid("TextMsg"),    "fwSurvivedRound");

    register_logevent("fwRoundEnd", 2, "1=Round_End") 

    /*! NVault */
    nvault_open("eloratingsystem")
}

/*! Commands */
public cmdRating(id) {
    ColorChat(id, NORMAL, "^3Your rating is ^4%d ^3with ^4%d ^3wins and ^4%d ^3losses!", g_PlayerRating[id], g_PlayerWins[id], g_PlayerLosses[id]);

    return PLUGIN_HANDLED;
}

public cmdTeamRating(id) {
    CalculateRating();
    ColorChat(id, BLUE, "^1Team ratings -- ^3Hiders:^4%d^1 | ^3Seekers: ^4%d", g_TeamRating[HIDERS], g_TeamRating[SEEKERS]);

    return PLUGIN_HANDLED;
}

public cmdReset(id) {
    g_PlayerRating[id] = get_pcvar_num(g_cStartingPoints);
    ColorChat(id, NORMAL, "^3Your rating has been reset to ^4%d^3!", g_PlayerRating[id]);

    return PLUGIN_HANDLED;
}

public cmdSetRating() {
    new iName[MAXPLAYERS], iRating[MAXPLAYERS];

    read_argv(1, iName, sizeof(iName) - 1);
    read_argv(2, iRating, sizeof(iRating) - 1);
    
    new iPlayerRating = str_to_num(iRating);
    new iPlayer = find_player("a", iName)

    if(!iPlayer) 
        return PLUGIN_CONTINUE;

    g_PlayerRating[iPlayer] = iPlayerRating;
    ColorChat(iPlayer, NORMAL, "Player rating has been set to %d", g_PlayerRating[iPlayer]);

    return PLUGIN_HANDLED;
}

/*! Events */
public fwFallDamage(id) {
    new iFallDamage     = read_data(2);
    new iMinFallDamage  = get_pcvar_num(g_cMinimumFallDamage);

    if(read_data(4) != 0 || read_data(5) != 0 || read_data(6) != 0) 
        return PLUGIN_CONTINUE;

    if(iFallDamage >= iMinFallDamage && iFallDamage < 100) {
        new iPoints = floatround(floatmul(floatdiv(float(g_PlayerRating[id]), floatsub(float(iMinFallDamage), float(iFallDamage / 10))), get_pcvar_float(g_cFallDamageRatio)), floatround_floor);
        
        if(iFallDamage > get_pcvar_num(g_cMaximumFallDamage))
            iPoints *= 2;

        g_PlayerRating[id] -= iPoints;
        
        set_hudmessage(255, 0, 0, 0.85, 0.9, 0, 2.0, 2.0, 0.2)
        show_hudmessage(id, "Damage taken: -%d rating", iPoints);
    }

    return PLUGIN_HANDLED;
}

public fwSuicide() {
    new iVictim = read_data(2);
    new iKiller[MAXPLAYERS + 1];

    read_data(4, iKiller, MAXPLAYERS);

    if(equal(iKiller, "worldspawn")) {
        new iPoints = floatround(floatmul(floatdiv(float(g_PlayerRating[iVictim]), get_pcvar_float(g_cMinimumFallDamage)), get_pcvar_float(g_cSuicideRatio)));

        g_PlayerRating[iVictim] -= iPoints;
        set_hudmessage(255, 0, 0, 0.85, 0.9, 0, 2.0, 2.0, 0.2)
        show_hudmessage(iVictim, "Suicide: -%d rating", iPoints);
   }
}

public fwSurvivedRound()
{
    static iTextMsg[22]
    get_msg_arg_string(2, iTextMsg, 21)
    
    //T Win
    if(equal(iTextMsg, "#Terrorists_Win"))
    {
        for(new id = 1; id <= get_maxplayers(); id++)
        {
            if(is_user_connected(id) && is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T)
            {
                new iPoints = floatround(floatmul(floatdiv(float(g_PlayerRating[id]), get_pcvar_float(g_cMinimumFallDamage)), get_pcvar_float(g_cSurviveRoundRatio)));
                
                g_PlayerRating[id] += iPoints;
                set_hudmessage(0, 255, 0, 0.85, 0.9, 0, 2.0, 2.0, 0.2)
                show_hudmessage(id, "Survivor: +%d rating", iPoints);

                g_PlayerWins[id]++;
            }
        }
    } else if(equal(iTextMsg, "#CTs_Win")) {
        for(new id = 1; id <= get_maxplayers(); id++)
        {
            if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_T && !is_user_alive(id)) {
                new iPoints = floatround(floatmul(floatdiv(float(g_PlayerRating[id]), get_pcvar_float(g_cMinimumFallDamage)), get_pcvar_float(g_cLoseRoundRatio)));
                
                g_PlayerRating[id] -= iPoints;
                set_hudmessage(255, 0, 0, 0.85, 0.9, 0, 2.0, 2.0, 0.2)
                show_hudmessage(id, "Perisher: -%d rating", iPoints);

                g_PlayerLosses[id]++;
            }
        }
    }
}


public fwRoundEnd() {
    new iPlayers[MAXPLAYERS], iNum;

    get_players(iPlayers, iNum, "ch");
    CalculateRating();

    if(iNum > 0)
        ColorChat(0, RED, "^3Hiders Rating: ^4%d^1 | ^3Seekers Rating: ^4%d", g_TeamRating[HIDERS], g_TeamRating[SEEKERS]);

    if(g_TeamRating[HIDERS] > (g_TeamRating[SEEKERS] + 200)) {
        
    }

    return PLUGIN_HANDLED;
}

/*! NVault */
public client_disconnected(id)
{
    SaveData(id);
}
 
public client_connect(id)
{
    LoadData(id);
}
 
public SaveData(id)
{
    new SteamID[32]
    get_user_authid(id, SteamID, charsmax(SteamID))
   
    new vaultkey[64], vaultdata[256]
   
    format(vaultkey, charsmax(vaultkey), "%s-ers", SteamID)
    format(vaultdata, charsmax(vaultdata), "%i#%i#%i#", g_PlayerRating[id], g_PlayerWins[id], g_PlayerLosses[id])
    
    nvault_set(g_Vault, vaultkey, vaultdata)

    return PLUGIN_CONTINUE
}
 
public LoadData(id)
{  
    new SteamID[32]
    get_user_authid(id, SteamID, charsmax(SteamID))
   
    new vaultkey[64], vaultdata[256]
   
    format(vaultkey, charsmax(vaultkey), "%s-ers", SteamID)
    format(vaultdata, charsmax(vaultdata), "%i#%i#%i#", g_PlayerRating[id], g_PlayerWins[id], g_PlayerLosses[id])

    new iTimeStamp;
    new iPlayerExists = nvault_lookup(g_Vault, vaultkey, vaultdata, charsmax(vaultdata), iTimeStamp);
    
    if(!iPlayerExists) {
        g_PlayerRating[id]  = get_pcvar_num(g_cStartingPoints);
        g_PlayerWins[id]    = 0;
        g_PlayerLosses[id]  = 0;
    } else {
        nvault_get(g_Vault, vaultkey, vaultdata, charsmax(vaultdata))
   
        replace_all(vaultdata, charsmax(vaultdata), "#", " ")
    
        new iPlayerRating[MAXPLAYERS + 1];
    
        parse(vaultdata, iPlayerRating, charsmax(iPlayerRating))
    
        g_PlayerRating[id] = str_to_num(iPlayerRating);
    }

    
   
    return PLUGIN_CONTINUE;
}

/*! Stocks */
stock CountTeams(&TERRORISTS, &CTS)
{
    TERRORISTS = 0;
    CTS = 0;

    new iPlayers[MAXPLAYERS], iNum;
    get_players(iPlayers, iNum, "ch");

    for(new id = 0; id < iNum; id++) {
        switch(cs_get_user_team(iPlayers[id]))  {
            case CS_TEAM_T:
                ++TERRORISTS;
            case CS_TEAM_CT:
                ++CTS;
        }
    }
}

stock CalculateRating() {
    new iPlayers[MAXPLAYERS], iNum;
    new iSeekers, iHiders;
    new iTeamRating[2] = { 0 };

    CountTeams(iHiders, iSeekers);
    get_players(iPlayers, iNum, "ch");

    for(new id = 0; id < iNum; id++) {
        new player = iPlayers[id];

        if(cs_get_user_team(player) == CS_TEAM_T)
            iTeamRating[HIDERS] += g_PlayerRating[player];
        else if(cs_get_user_team(player) == CS_TEAM_CT)
            iTeamRating[SEEKERS] += g_PlayerRating[player];
    }

    g_TeamRating[HIDERS]    = iTeamRating[HIDERS];
    g_TeamRating[SEEKERS]   = iTeamRating[SEEKERS];

    g_TeamRating[HIDERS]    = (iHiders > 0 ? (g_TeamRating[HIDERS] / iHiders) : 0);
    g_TeamRating[SEEKERS]   = (iSeekers > 0 ? (g_TeamRating[SEEKERS] / iSeekers) : 0);
}