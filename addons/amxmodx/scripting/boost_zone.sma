#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <xs>

#include <transmix>

#define PLUGIN "Boost Zone"
#define VERSION "1.04a"
#define AUTHOR "trans"

#define POST_FORWARD 1
#define PRE_FORWARD 0

#define FM_TEAM_OFFSET 114
#define fm_get_user_team(%1) get_pdata_int(%1, FM_TEAM_OFFSET)

#define MENU_ACCESS ADMIN_BAN

#define TASK_SHOWZONE_ID 144690
#define TASK_SHOWAV_ID 290661

#define MAX_BOOST_ZONES 25

#define _FASTVIS

new const g_szTeamNames[][] = {
    
    "Spectator",
    "Terrorist",
    "Counter-Terrorist",
    "Spectator"
};
new const g_szRadioCode[][] = {
    
    "#Cover_me",
    "#Enemy_spotted",
    "#Need_backup",
    "#Sector_clear",
    "#In_position",
    "#Reporting_in",
    "#Get_out_of_there",
    "#Negative",
    "#Enemy_down",
    "#Go_go_go",
    "#Team_fall_back",
    "#Stick_together_team",
    "#Get_in_position_and_wait",
    "#Storm_the_front",
    "#Report_in_team",
    "#You_take_the_point",
    "#Hold_this_position",
    "#Follow_me",
    "#Taking_fire",
    "#Roger_that",
    "#Affirmative",
    "#Regroup_Team"
};
new const g_szRadioText[][] = {
    
    "Cover Me!",
    "Enemy spotted.",
    "Need backup.",
    "Sector clear.",
    "I'm in position.",
    "Reporting in.",
    "Get out of there, it's gonna blow!",
    "Negative.",
    "Enemy down.",
    "Go go go!",
    "Team, fall back!",
    "Stick together, team.",
    "Get in position and wait for my go.",
    "Storm the Front!",
    "Report in, team.",
    "You Take the Point.",
    "Hold This Position.",
    "Follow Me.",
    "Taking Fire...Need Assistance!",
    "Roger that.",
    "Affirmative.",
    "Regroup Team."
};

enum {
    IZ_FIRST_POINT = 0,
    IZ_SECOND_POINT
};

new g_iMainMenu;

new g_iMaxPlayers;
new g_iBeamSprite;
new g_pBeamSprite;
new g_iZones;
new g_iCaptain;

new g_iCurrentEnt[33];
new g_szTouchedInfo[33][32];
new g_iBuildStage[33];
new g_iZoneNames[MAX_BOOST_ZONES][33];
new Float:g_fLastTouch[33];
new Float:g_fOriginBox[33][2][3];
new Float:g_fOrigins[MAX_BOOST_ZONES][3];
new bool:g_bInBuild[33];

new g_pBoost;
new g_pHoldTime;

new g_iColor[3] = { 0, 255, 255 };

const TASK_POINT = 1337;
new const g_szIzClassName[] = "boost_zone";
new const SPRITE_ARROW[] = "sprites/arrow2.spr";
new const SPRITE_POINT[] = "sprites/3dmflared.spr";

public plugin_init() {
    
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_clcmd("say /bz", "clcmdMainMenu", MENU_ACCESS, "");
    register_clcmd("say /bzmenu", "clcmdMainMenu", MENU_ACCESS, "");
    register_clcmd("say /pick", "boostChoiceMenu", MENU_ACCESS, "");
    register_clcmd("set_boost_zone", "clcmdBoostZone", MENU_ACCESS, "");
    register_clcmd("say_team", "clcmdSayTeam", -1, "");

    register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
    
    register_forward(FM_Touch, "Fwd_Touch", PRE_FORWARD);
    register_forward(FM_PlayerPreThink, "Fwd_PlayerPreThink", POST_FORWARD);
    register_event("HLTV", "RoundStart", "a", "1=0", "2=0");

    g_pHoldTime = register_cvar("bz_holdtime", "30");
    
    g_iMainMenu = menu_create("\yBoost Zones Menu", "menuMainHandle", 0);
    menu_additem(g_iMainMenu, "New boost zone", "1", 0, -1);
    menu_additem(g_iMainMenu, "Delete boost zone", "2", 0, -1);
    menu_additem(g_iMainMenu, "Select boost zone", "3", 0, -1);
    menu_additem(g_iMainMenu, "Rename boost zone", "4", 0, -1);
    menu_addblank(g_iMainMenu, 0);
    menu_additem(g_iMainMenu, "Show/Hide boost zones", "5", 0, -1);
    menu_addblank(g_iMainMenu, 0);
    menu_additem(g_iMainMenu, "Delete all boost zones", "6", 0, -1);
    menu_additem(g_iMainMenu, "Save boost zones", "7", 0, -1);
    menu_addblank(g_iMainMenu, 0);
    
    g_iMaxPlayers = global_get(glb_maxClients);
    g_iCaptain = get_hiders_captain();
    g_pBoost = get_cvar_pointer("hns_semiclip");
}

public plugin_precache() {
    g_iBeamSprite = precache_model("sprites/dot.spr");
    g_pBeamSprite = precache_model(SPRITE_ARROW);

    precache_model(SPRITE_POINT);
}


public RoundStart() {
    if(get_pcvar_num(g_pBoost) == 1) {
        new iPlayers[32];
        new iNum;

        get_players(iPlayers, iNum, "aceh", "TERRORIST");

        if(iNum) {
            new iRand = random_num(1, iNum);

            client_print(iRand, print_chat, "You have been chosen to pick the boost!");
            boostChoiceMenu(iRand);
        }
    }
}


public boostChoiceMenu(id) {
    new menu = menu_create( "\rPick boost:", "menu_handler" ); 

    for(new i = 0; i < g_iZones; i++) {
        new szOrigin[33];
        formatex(szOrigin, charsmax(szOrigin), "%.1f %.1f %.1f", g_fOrigins[i][0], g_fOrigins[i][1], g_fOrigins[i][2]);
        
        menu_additem(menu, g_iZoneNames[i], szOrigin, 0);
    }
     
    menu_setprop( menu, MPROP_EXIT, MEXIT_ALL ); 
    menu_display( id, menu, 0 ); 

    return PLUGIN_HANDLED;
}

public menu_handler(id, menu, item) {
    
    if ( item == MENU_EXIT ) { 
        menu_destroy( menu ); 
        return PLUGIN_HANDLED; 
    } 
    new szData[33], szName[33], szOrigin[3][33], fOrigin[3]; 
    new _access, item_callback; 

    menu_item_getinfo( menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), item_callback ); 
    parse(szData, szOrigin[0], charsmax(szOrigin[]), szOrigin[1], charsmax(szOrigin[]), szOrigin[2], charsmax(szOrigin[]));

    fOrigin[0] = floatround(str_to_float(szOrigin[0]), floatround_round);
    fOrigin[1] = floatround(str_to_float(szOrigin[1]), floatround_round);
    fOrigin[2] = floatround(str_to_float(szOrigin[2]), floatround_round);

    new iPlayers[32], iNum;
    get_players(iPlayers, iNum);

    for(new pId = 1; pId <= iNum; pId++) {
        if(is_user_connected(pId) && is_user_alive(pId) && cs_get_user_team(pId) == cs_get_user_team(id)) {
            static vOrigin_start[3];

            get_user_origin(pId, vOrigin_start);            // Start point
            
            UTIL_VisualizeVector(pId,
                //.vStart = vOrigin_start,
                .vEnd = fOrigin,
                .time = get_pcvar_num(g_pHoldTime),
                .width = 50
            );

            set_dhudmessage( 0 , 100 , 255 , -1.0 , 0.1 , 0 , 0.0 , 6.0 , 0.01 , 0.0 );
            show_dhudmessage(pId, "GO %s", szName);
        }
    }

    menu_destroy( menu ); 
    return PLUGIN_HANDLED; 
}

public plugin_cfg()
{
    new szFile[64], szMapName[32];
    get_datadir(szFile, sizeof szFile - 1);
    get_mapname(szMapName, sizeof szMapName - 1);
    
    add(szFile, sizeof szFile - 1, "/boost_zone");
    
    if(!dir_exists(szFile))
        mkdir(szFile);
    
    format(szFile, sizeof szFile - 1, "%s/boost_zone_%s.ini", szFile, szMapName);
    
    new iFile = fopen(szFile, "at+");
    
    new szBuffer[256];
    new szTargetName[32], szOrigin[64], szMins[64], szMaxs[64];
    new szTemp1[3][32], szTemp2[3][32], szTemp3[3][32];
    
    while(!feof(iFile))
    {
        fgets(iFile, szBuffer, sizeof szBuffer - 1);
        
        if(!szBuffer[0])
            continue;
        
        parse(szBuffer, szTargetName, sizeof szTargetName - 1, szOrigin, sizeof szOrigin - 1, szMins, sizeof szMins - 1, szMaxs, sizeof szMaxs - 1);
        
        str_piece(szOrigin, szTemp1, sizeof szTemp1, sizeof szTemp1[] - 1, ';');
        str_piece(szMins, szTemp2, sizeof szTemp2, sizeof szTemp2[] - 1, ';');
        str_piece(szMaxs, szTemp3, sizeof szTemp3, sizeof szTemp3[] - 1, ';');
        
        static Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
        fOrigin[0] = str_to_float(szTemp1[0]);
        fOrigin[1] = str_to_float(szTemp1[1]);
        fOrigin[2] = str_to_float(szTemp1[2]);

        
        g_fOrigins[g_iZones][0] = fOrigin[0];
        g_fOrigins[g_iZones][1] = fOrigin[1];
        g_fOrigins[g_iZones][2] = fOrigin[2];
        console_print(0, "%f %f %f", g_fOrigins[g_iZones][0],  g_fOrigins[g_iZones][1], g_fOrigins[g_iZones][2]);

        fMins[0] = str_to_float(szTemp2[0]);
        fMins[1] = str_to_float(szTemp2[1]);
        fMins[2] = str_to_float(szTemp2[2]);
        
        fMaxs[0] = str_to_float(szTemp3[0]);
        fMaxs[1] = str_to_float(szTemp3[1]);
        fMaxs[2] = str_to_float(szTemp3[2]);
        
        g_iZoneNames[g_iZones] = szTargetName;

        fm_create_boost_zone(fOrigin, fMins, fMaxs, szTargetName);
        
        g_iZones++;
        
        if(g_iZones >= MAX_BOOST_ZONES)
        {
            fclose(iFile);
            return;
        }
    }
    fclose(iFile);
}

public clcmdBoostZone(id)
{
    if(!(get_user_flags(id) & MENU_ACCESS))
        return 1;
    
    new szArgs[32];
    read_argv(1, szArgs, sizeof szArgs - 1);
    
    if(szArgs[0] && pev_valid(g_iCurrentEnt[id]))
    {
        set_pev(g_iCurrentEnt[id], pev_targetname, szArgs);
        
        client_printg(id, "Successfully set the Boost Zone name ^"%s^".", szArgs);
    }
    return 1;
}

public clcmdMainMenu(id)
{
    if(!(get_user_flags(id) & MENU_ACCESS))
        return 1;
    
    menu_display(id, g_iMainMenu, 0);
    
    set_hudmessage(42, 85, 255, -1.0, 0.7, 0, 6.0, 5.0, 0.5, 0.5, -1);
    show_hudmessage(id, "Current Boost zones num: '%d'^nMax Boost zones num: '%d'", g_iZones, MAX_BOOST_ZONES);
    
    return 0;
}

public menuMainHandle(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        if(task_exists(id + TASK_SHOWAV_ID))
            remove_task(id + TASK_SHOWAV_ID);
        
        g_bInBuild[id] = false;
        
        return 1;
    }
    
    new szData[6], iAccess, iCallBack;
    menu_item_getinfo(menu, item, iAccess, szData, sizeof szData - 1, _, _, iCallBack);
    
    new iKey = str_to_num(szData);
    
    switch(iKey)
    {
        case 1 :
        {
            if(g_bInBuild[id])
            {
                menu_display(id, menu, 0);
                return 1;
            }
            
            if(g_iZones >= MAX_BOOST_ZONES)
            {
                client_printg(id, "> Sorry, limit of Boost zones is reached (%d).", MAX_BOOST_ZONES);
                menu_display(id, menu, 0);
                
                return 1;
            }
            g_bInBuild[id] = true;
            
            if(!task_exists(id + TASK_SHOWAV_ID))
                set_task(0.5, "taskShowAimVector", id + TASK_SHOWAV_ID, "", 0, "b", 0);
            
            client_printg(id, "> Set the origin for the top right corner of the box.");
            
            menu_display(id, menu, 0);
        }
        case 2 : 
        {
            if(pev_valid(g_iCurrentEnt[id]))
            {	
                new szTargetName[32];
                pev(g_iCurrentEnt[id], pev_targetname, szTargetName, sizeof szTargetName - 1);
                
                engfunc(EngFunc_RemoveEntity, g_iCurrentEnt[id]);
                
                client_printg(id, "> Successfully removed Boost zone ^"%s^".", szTargetName);
                
                g_iZones--;
                
                menu_display(id, menu, 0);
            }
            else
            {
                client_printg(id, "> Invalid Boost zone ent index.");
                
                menu_display(id, menu, 0);
            }
        }
        case 3 :
        {
            new iMenu = menu_create("\yBoost Zone : Select", "menuSelectHandle", 0);
            
            new iEnt = -1;
            while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", g_szIzClassName)) != 0)
            {
                static szTargetName[32];
                pev(iEnt, pev_targetname, szTargetName, sizeof szTargetName - 1);
                
                menu_additem(iMenu, szTargetName, "", 0, -1);
            }
            if(menu_items(iMenu) > 0)
                menu_addblank(iMenu, 0);
            
            menu_display(id, iMenu, 0);
        }
        case 4 :
        {
            if(pev_valid(g_iCurrentEnt[id]))
            {
                client_cmd(id, "messagemode set_boost_zone");
                
                menu_display(id, menu, 0);
            }
            else
            {
                client_printg(id, "> Invalid Boost zone ent index.");
                
                menu_display(id, menu, 0);
            }
        }
        case 5 :
        {
            if(!task_exists(TASK_SHOWZONE_ID + id) && g_iZones)
                set_task(1.0, "taskShowZones", TASK_SHOWZONE_ID + id, "", 0, "b", 0);
            else
                remove_task(TASK_SHOWZONE_ID + id);
            
            menu_display(id, menu, 0);
        }
        case 6 :
        {
            new iEnt = -1;
            while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", g_szIzClassName)) != 0)
                engfunc(EngFunc_RemoveEntity, iEnt);
            
            client_printg(id, "> Successfully deleted all boost zones.");
            
            g_iZones = 0;
            
            menu_display(id, menu, 0);
            
        }
        case 7 :
        {
            new szFile[64], szMapName[32];
            get_datadir(szFile, sizeof szFile - 1);
            get_mapname(szMapName, sizeof szMapName - 1);
            
            format(szFile, sizeof szFile - 1, "%s/boost_zone/boost_zone_%s.ini", szFile, szMapName);
            
            new iFile = fopen(szFile, "wt+");
            
            new iEnt = -1;
            while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", g_szIzClassName)) != 0)
            {
                static szTargetName[32], Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
                
                pev(iEnt, pev_targetname, szTargetName, sizeof szTargetName - 1);
                pev(iEnt, pev_mins, fMins);
                pev(iEnt, pev_maxs, fMaxs);
                pev(iEnt, pev_origin, fOrigin);
                
                fprintf(iFile, "^"%s^" ^"%.1f;%.1f;%.1f^" ^"%.1f;%.1f;%.1f^" ^"%.1f;%.1f;%.1f^"^n", szTargetName, fOrigin[0], fOrigin[1], fOrigin[2], fMins[0], fMins[1], fMins[2], fMaxs[0], fMaxs[1], fMaxs[2]);
            }
            fclose(iFile);
            
            client_printg(0, "> Successfully saved all Boost Zones (%d).", g_iZones);
        }
    }
    return 1;
}

public taskShowZones(id)
{
    id -= TASK_SHOWZONE_ID;
    
    if(!is_user_connected(id))
    {
        remove_task(TASK_SHOWZONE_ID + id);
        return;
    }
    
    new iEnt = fm_get_nearest_iz(id);
    
    new Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
    
    pev(iEnt, pev_mins, fMins);
    pev(iEnt, pev_maxs, fMaxs);
    pev(iEnt, pev_origin, fOrigin);
    
    fMins[0] += fOrigin[0];
    fMins[1] += fOrigin[1];
    fMins[2] += fOrigin[2];
    fMaxs[0] += fOrigin[0];
    fMaxs[1] += fOrigin[1];
    fMaxs[2] += fOrigin[2];
    
    fm_draw_line(id, fMaxs[0], fMaxs[1], fMaxs[2], fMins[0], fMaxs[1], fMaxs[2], g_iColor);
    fm_draw_line(id, fMaxs[0], fMaxs[1], fMaxs[2], fMaxs[0], fMins[1], fMaxs[2], g_iColor);
    fm_draw_line(id, fMaxs[0], fMaxs[1], fMaxs[2], fMaxs[0], fMaxs[1], fMins[2], g_iColor);
    fm_draw_line(id, fMins[0], fMins[1], fMins[2], fMaxs[0], fMins[1], fMins[2], g_iColor);
    fm_draw_line(id, fMins[0], fMins[1], fMins[2], fMins[0], fMaxs[1], fMins[2], g_iColor);
    fm_draw_line(id, fMins[0], fMins[1], fMins[2], fMins[0], fMins[1], fMaxs[2], g_iColor);
    fm_draw_line(id, fMins[0], fMaxs[1], fMaxs[2], fMins[0], fMaxs[1], fMins[2], g_iColor);
    fm_draw_line(id, fMins[0], fMaxs[1], fMins[2], fMaxs[0], fMaxs[1], fMins[2], g_iColor);
    fm_draw_line(id, fMaxs[0], fMaxs[1], fMins[2], fMaxs[0], fMins[1], fMins[2], g_iColor);
    fm_draw_line(id, fMaxs[0], fMins[1], fMins[2], fMaxs[0], fMins[1], fMaxs[2], g_iColor);
    fm_draw_line(id, fMaxs[0], fMins[1], fMaxs[2], fMins[0], fMins[1], fMaxs[2], g_iColor);
    fm_draw_line(id, fMins[0], fMins[1], fMaxs[2], fMins[0], fMaxs[1], fMaxs[2], g_iColor);
}

public taskShowAimVector(id)
{
    id -= TASK_SHOWAV_ID;
    
    if(!is_user_connected(id))
    {
        remove_task(TASK_SHOWAV_ID + id);
        return;
    }
    
    static Float:vAim[3];
    velocity_by_aim(id, 64, vAim);
    
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);
    
    vOrigin[0] += vAim[0];
    vOrigin[1] += vAim[1];
    
    if(!(pev(id, pev_flags) & FL_DUCKING))
        vOrigin[2] += (vAim[2] + 16.0);
    else
        vOrigin[2] += (vAim[2] + 12.0);
    
    static Float:vOrigin2[3];
    
    vOrigin2[0] = vOrigin[0];
    vOrigin2[1] = vOrigin[1];
    vOrigin2[2] = vOrigin[2];
    
    vOrigin[0] += 16.0;
    fm_draw_line(id, vOrigin[0], vOrigin[1], vOrigin[2], vOrigin2[0], vOrigin2[1], vOrigin2[2], {255, 0, 0});
    
    vOrigin[0] -= 16.0;
    vOrigin[1] += 16.0;
    fm_draw_line(id, vOrigin[0], vOrigin[1], vOrigin[2], vOrigin2[0], vOrigin2[1], vOrigin2[2], {0, 0, 255});
    
    vOrigin[1] -= 16.0;
    vOrigin[2] += 16.0;
    fm_draw_line(id, vOrigin[0], vOrigin[1], vOrigin[2], vOrigin2[0], vOrigin2[1], vOrigin2[2], {0, 255, 0});
}

public menuSelectHandle(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_display(id, g_iMainMenu, 0);
        return 1;
    }
    
    new iAccess, szName[32], iCallback;
    menu_item_getinfo(menu, item, iAccess, "", 0, szName, sizeof szName - 1, iCallback);
    
    new iEnt = -1;
    while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "targetname", szName)) != 0)
    {
        if(pev_valid(iEnt))
            g_iCurrentEnt[id] = iEnt;
    }
    
    client_printg(id, "> Successfully selected Boost zone ^"%s^".", szName);
    
    menu_display(id, g_iMainMenu, 0);
    return 1;
}

public Fwd_Touch(Ent, id)
{
    if(!is_user_alive(id))
        return FMRES_IGNORED;
    
    static szClassName[32];
    pev(Ent, pev_classname, szClassName, sizeof szClassName - 1);
    
    static Float:fGameTime;
    fGameTime = get_gametime();
    
    if(equal(szClassName, g_szIzClassName) && (fGameTime - g_fLastTouch[id]) > 0.1)
    {
        static szTargetName[32];
        pev(Ent, pev_targetname, szTargetName, sizeof szTargetName - 1);
        
        if(!equal(g_szTouchedInfo[id], szTargetName))
            formatex(g_szTouchedInfo[id], sizeof g_szTouchedInfo[] - 1, szTargetName);
        
        g_fLastTouch[id] = fGameTime;
    }
    return FMRES_IGNORED;
}

public Fwd_PlayerPreThink(id)
{
    if(!is_user_alive(id))
        return FMRES_IGNORED;
    
    static Float:fGameTime;
    fGameTime = get_gametime();
    
    if((fGameTime - g_fLastTouch[id]) > 0.5 && strlen(g_szTouchedInfo[id]))
        g_szTouchedInfo[id][0] = '^0';
    
    if(((pev(id, pev_button) & IN_ATTACK) && !(pev(id, pev_oldbuttons) & IN_ATTACK) || (pev(id, pev_button) & IN_USE && !(pev(id, pev_oldbuttons) & IN_USE))) && g_bInBuild[id])
    {
        new Float:fOrigin[3];
        
        if(pev(id, pev_button) & IN_ATTACK)
            fm_get_aim_origin(id, fOrigin);
        else
        {
            new Float:fAim[3];
            velocity_by_aim(id, 64, fAim);
            
            pev(id, pev_origin, fOrigin);
            
            fOrigin[0] += fAim[0];
            fOrigin[1] += fAim[1];
            
            if(!(pev(id, pev_flags) & FL_DUCKING))
                fOrigin[2] += (fAim[2] + 16.0);
            else
                fOrigin[2] += (fAim[2] + 12.0);
        }
        
        if(g_iBuildStage[id] == IZ_FIRST_POINT)
        {
            g_iBuildStage[id] = IZ_SECOND_POINT;
            
            g_fOriginBox[id][IZ_FIRST_POINT] = fOrigin;
            
            client_printg(id, "> Now set the origin for the bottom left corner of the box.");
        }
        else
        {
            g_iBuildStage[id] = IZ_FIRST_POINT;
            g_bInBuild[id] = false;
            
            g_fOriginBox[id][IZ_SECOND_POINT] = fOrigin;
            
            if(task_exists(id + TASK_SHOWAV_ID))
                remove_task(id + TASK_SHOWAV_ID);
            
            new Float:fCenter[3], Float:fSize[3];
            new Float:fMins[3], Float:fMaxs[3];
            
            for ( new i = 0; i < 3; i++ )
            {
                fCenter[i] = (g_fOriginBox[id][IZ_FIRST_POINT][i] + g_fOriginBox[id][IZ_SECOND_POINT][i]) / 2.0;
                
                fSize[i] = get_float_difference(g_fOriginBox[id][IZ_FIRST_POINT][i], g_fOriginBox[id][IZ_SECOND_POINT][i]);
                
                fMins[i] = fSize[i] / -2.0;	
                fMaxs[i] = fSize[i] / 2.0;
            }
            new iEnt = fm_create_boost_zone(fCenter, fMins, fMaxs, "");
            
            g_iZones++;
            
            g_iCurrentEnt[id] = iEnt;
            
            client_cmd(id, "messagemode set_boost_zone");
            
            client_printg(id, "> Enter the Boost zone name.");
        }
    }
    return FMRES_IGNORED;
}

public clcmdSayTeam(id)
{
    static szArgs[256];
    read_args(szArgs, sizeof szArgs - 1);
    
    remove_quotes(szArgs);
    
    if(!strlen(szArgs) || szArgs[0] == '@')
        return 0;
    
    if(!strlen(g_szTouchedInfo[id]))
        return 0;
    
    static szName[32];
    get_user_name(id, szName, sizeof szName - 1);
    
    static szNewMsg[256];
    formatex(szNewMsg, sizeof szNewMsg - 1, "^x01%s(%s)(^x04%s^x01)^x03 %s^x01 :  %s", is_user_alive(id) ? "" : "*DEAD*", g_szTeamNames[fm_get_user_team(id)], g_szTouchedInfo[id], szName, szArgs);
    
    for(new i = 1 ; i <= g_iMaxPlayers ; i++)
    {
        if(is_user_connected(i) && (is_user_alive(id) == is_user_alive(i)) && (fm_get_user_team(id) == fm_get_user_team(i)))
            print_SayText(id, i, szNewMsg);
    }
    return 1;
}

public Message_TextMsg(msg_id, dest, id)
{
    if(get_msg_args() != 5)
        return 0;
    
    static szArgs[32];
    get_msg_arg_string(3, szArgs, sizeof szArgs - 1);
    
    if(!equali(szArgs, "#Game_radio"))
        return 0;
    
    static szRadioCode[32];
    get_msg_arg_string(5, szRadioCode, sizeof szRadioCode - 1);
    
    static iRadioNum;
    iRadioNum = get_radio_num(szRadioCode);
    
    if(iRadioNum == -1)
        return 0;
    
    static szPlayer[3];
    get_msg_arg_string(2, szPlayer, sizeof szPlayer - 1);
    
    static iPlayer;
    iPlayer = str_to_num(szPlayer);
    
    if(!is_user_connected(iPlayer))
        return 0;
    
    static szName[32];
    get_msg_arg_string(4, szName, sizeof szName - 1);
    
    static szMessage[128];
    
    if(!strlen(g_szTouchedInfo[iPlayer]))
        return 0;
    else
       //formatex(szMessage, sizeof szMessage - 1, "(^x04 %s ^x01) %s (RADIO): %s", g_szTouchedInfo[iPlayer], szName, g_szRadioText[iRadioNum]);
        formatex(szMessage, sizeof szMessage - 1, "^x01(^x04%s^x01)^x03 %s^x01 (RADIO):  %s",  g_szTouchedInfo[iPlayer], szName, g_szRadioText[iRadioNum]);
    
    print_SayText(id, id, szMessage);
    return 1;
}

stock fm_get_aim_origin(index, Float:origin[3])
{
    new Float:start[3], Float:view_ofs[3];
    pev(index, pev_origin, start);
    pev(index, pev_view_ofs, view_ofs);
    
    xs_vec_add(start, view_ofs, start);
    
    new Float:dest[3];
    pev(index, pev_v_angle, dest);
    engfunc(EngFunc_MakeVectors, dest);
    global_get(glb_v_forward, dest);
    
    xs_vec_mul_scalar(dest, 9999.0, dest);
    xs_vec_add(start, dest, dest);
    
    engfunc(EngFunc_TraceLine, start, dest, 0, index, 0);
    get_tr2(0, TR_vecEndPos, origin);
    
    return 1;
}

stock fm_create_boost_zone(Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3], const szTargetName[])
{
    new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    
    if(!iEnt)
        return 0;
    
    engfunc(EngFunc_SetOrigin, iEnt, fOrigin);
    
    set_pev(iEnt, pev_classname, g_szIzClassName);
    set_pev(iEnt, pev_targetname, szTargetName);
    
    dllfunc(DLLFunc_Spawn, iEnt);
    
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY);
    set_pev(iEnt, pev_solid, SOLID_TRIGGER);
    
    engfunc(EngFunc_SetSize, iEnt, fMins, fMaxs);
    
    return iEnt;
}

stock fm_draw_line(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, g_iColor[3])
{
    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id ? id : 0);
    
    write_byte(TE_BEAMPOINTS);
    
    write_coord(floatround(x1));
    write_coord(floatround(y1));
    write_coord(floatround(z1));
    
    write_coord(floatround(x2));
    write_coord(floatround(y2));
    write_coord(floatround(z2));
    
    write_short(g_iBeamSprite);
    write_byte(1);
    write_byte(1);
    write_byte(10);
    write_byte(5);
    write_byte(0); 
    
    write_byte(g_iColor[0]);
    write_byte(g_iColor[1]); 
    write_byte(g_iColor[2]);
    
    write_byte(200); 
    write_byte(0);
    
    message_end();
}

stock client_printg(id, const message[], {Float, Sql, Resul,_}:...) {
    
    static msg[192];
    msg[0] = 0x04;
    
    vformat(msg[1], 190, message, 3);
    
    if( id > 0 && id <= g_iMaxPlayers)
    {
        message_begin(MSG_ONE, get_user_msgid("SayText"),_, id);
        write_byte(id);
        write_string(msg);
        message_end();
    }
    else if(id == 0)
    {
        for( new i = 1; i <= g_iMaxPlayers; i++ )
        {
            if(!is_user_connected(i))
                continue;
            
            message_begin(MSG_ONE, get_user_msgid("SayText"),_, i);
            write_byte(i);
            write_string(msg);
            message_end();
        }
    }
}

stock print_SayText(sender, receiver, const szMessage[])
{
    static MSG_type, id;
    
    if(receiver > 0)
    {
        MSG_type = MSG_ONE_UNRELIABLE;
        id = receiver;
    }
    else
    {
        MSG_type = MSG_BROADCAST;
        id = sender;
    }
    
    message_begin(MSG_type, get_user_msgid("SayText"), _, id);
    write_byte(sender);
    write_string(szMessage);
    message_end();
    
    return 1;
}

stock get_radio_num(const szRadioCode[])
{
    for(new i = 0; i < sizeof g_szRadioCode; i++)
    {
        if(equali(g_szRadioCode[i], szRadioCode))
            return i;
    }
    return -1;
}

stock str_piece(const input[], output[][], outputsize, piecelen, token = '|')
{
    new i = -1, pieces, len = -1 ;
    
    while ( input[++i] != 0 )
    {
        if ( input[i] != token )
        {
            if ( ++len < piecelen )
                output[pieces][len] = input[i] ;
        }
        else
        {
            output[pieces++][++len] = 0 ;
            len = -1 ;
            
            if ( pieces == outputsize )
                return pieces ;
        }
    }
    return pieces + 1;
}

stock Float:get_float_difference(Float:num1, Float:num2)
{
    if( num1 > num2 )
        return (num1-num2);
    else if( num2 > num1 )
        return (num2-num1);
    
    return 0.0;
}

stock fm_get_nearest_iz(id)
{
    new Float:fPlrOrigin[3], Float:fNearestDist = 9999.0, iNearestEnt;
    new Float:fOrigin[3], Float:fCurDist;
    
    pev(id, pev_origin, fPlrOrigin);
    
    new iEnt = -1;
    while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", g_szIzClassName)) != 0)
    {
        pev(iEnt, pev_origin, fOrigin);
        
        fCurDist = vector_distance(fPlrOrigin, fOrigin);
        
        if(fCurDist < fNearestDist)
        {
            fNearestDist = fCurDist;
            iNearestEnt = iEnt;
        }
    }
    return iNearestEnt;
}


public UTIL_VisualizeVector(id, vEnd[3], Float: time, width)
{
    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id);
    write_byte(TE_BEAMENTPOINT);
    write_short(id | 0x1000);
    write_coord(vEnd[0]);
    write_coord(vEnd[1]);
    write_coord(vEnd[2]);
    write_short(g_pBeamSprite);
    write_byte(1);            //Стартовый кадр
    write_byte(1);            //Скорость анимации
    write_byte(floatround(time * 10));    //Время существования
    write_byte(width);        //Толщина луча
    write_byte(0);            //Amplitude
    write_byte(255);            //Цвет красный
    write_byte(0);            //Цвет зеленый
    write_byte(0);            //Цвет синий
    write_byte(1000);        //Яркость
    write_byte(5);
    message_end();

#if !defined _FASTVIS
    CreatePoint(get_user_origin(id), .time = time);
    CreatePoint(vEnd, .time = time);
#else
    // Create_Sparks(vStart);
    Create_Sparks(vEnd);
#endif
}

stock CreatePoint(vOrigin[3], Float: time)
{
    static pEnt, Float: fOrigin[3];
    pEnt = create_entity("info_target");
    IVecFVec(vOrigin, fOrigin);

    if(is_valid_ent(pEnt))
    {
        // entity_set_string(pEnt, EV_SZ_classname, "points");
        entity_set_model(pEnt, SPRITE_POINT);
        entity_set_origin(pEnt, fOrigin);
        entity_set_int(pEnt, EV_INT_solid, SOLID_NOT);
        entity_set_int(pEnt, EV_INT_movetype, MOVETYPE_NONE);
        entity_set_float(pEnt, EV_FL_scale, 0.1);
        entity_set_float(pEnt, EV_FL_nextthink, get_gametime());
        entity_set_int(pEnt, EV_INT_rendermode, kRenderTransAdd);
        entity_set_float(pEnt, EV_FL_renderamt, 100.0);
    
        set_task(time, "DeleteEnt", TASK_POINT + pEnt);
    }
}

stock Create_Sparks(vOrigin[3])
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_SPARKS);
    write_coord(vOrigin[0]);
    write_coord(vOrigin[1]);
    write_coord(vOrigin[2]);
    message_end();
}


public DeleteEnt(pEnt)
{
    pEnt -= TASK_POINT;
    if(is_valid_ent(pEnt))
        remove_entity(pEnt);
}