#include <amxmodx>
#include <amxmisc>
#include <dhudmessage>
#include <cstrike>
#include <transmix>

#define PLUGIN "Boost Recommender"
#define VERSION "1.0"
#define AUTHOR "trans"

new g_szLine[64][33];
new g_szLinesCount;
new szPlayers[32];
new szCaptain;

public plugin_init() {
    register_plugin(PLUGIN, AUTHOR, VERSION);
    register_event("HLTV", "RoundStart", "a", "1=0", "2=0");

    read_sample();

    szCaptain = get_hiders_captain();
}

public boostChoiceMenu( id )
 {
    new menu = menu_create( "\rPick a boost!:", "menu_handler" );

    for(new i = 0; i < g_szLinesCount; i++) {
        menu_additem(menu, g_szLine[i], g_szLine[i], 0);
    }

    menu_setprop( menu, MPROP_EXIT, MEXIT_ALL );
    menu_display( id, menu, 0 );
 }

 public menu_handler( id, menu, item )
 {

     if(item == MENU_EXIT) {
         menu_destroy(menu);
         return PLUGIN_HANDLED;
     }

    new access, callback, szData[33];
    menu_item_getinfo(menu, item, access, szData, charsmax(szData), _, _, callback);

    new spot = str_to_num(szData);
    
    new count;
    get_players(szPlayers, count, "e", "TERRORIST");
    
    for(new i = 0; i < count; i++) {
        set_dhudmessage( 0 , 100 , 255 , -1.0 , 0.1 , 0 , 0.0 , 6.0 , 0.01 , 0.0 );
        show_dhudmessage(szPlayers[i], "GO %s", spot);
    }
    
    menu_destroy( menu );
    return PLUGIN_HANDLED;
 }

public read_sample() {
    new path[128];
    new map[33];

    get_mapname(map, 32);
    get_configsdir(path, charsmax(path));

    format(path, charsmax(path), "%s/trans/%s.txt", path, map);

    if(file_exists(path)) {
        new szData[33], szSample[33], iTextLength, iLine;

        while(read_file(path, iLine, szData, charsmax(szData), iTextLength) != 0) {
            if(iLine > charsmax(g_szLine[]))
                break;
            
            parse(szData, szSample, charsmax(szSample));

            if(szSample[0] == ';' || !szSample[0]) {
                iLine++;
                continue;
            }

            g_szLine[iLine] = szSample;

            iLine++;
            g_szLinesCount = iLine;
        }
    }

    return PLUGIN_HANDLED;
}

public RoundStart() {
        console_print(0, "%d", szCaptain);
        if(is_user_connected(szCaptain))
            if(cs_get_user_team(szCaptain) == CS_TEAM_T)
              boostChoiceMenu(szCaptain)
}
