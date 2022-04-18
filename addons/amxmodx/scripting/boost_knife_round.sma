#include <amxmodx>
#include <cstrike>
#include <fakemeta>

#include <kz_buttons.inc>

#define PLUGIN "+ Test"
#define AUTHOR "trans"
#define VERSION "0.0.1"

new bool:battleStarted = false;
new bool:isPlayerFrozen[33] = { false };

new Float:teamTimer[2] = { 0.0 };

public plugin_init()
{
    register_plugin( "Boost Battle", "1.0", "trans" );

    register_clcmd( "say /battle", "startBattle");
    register_clcmd( "say /time", "sTime");

    /*! Init Timers 
     * 0 - TTs
     * 1 - CTs
     */
    teamTimer[0] = 0.0;
    teamTimer[1] = 0.0;
}

public startBattle(id) {
    if(battleStarted) {
        client_print(id, print_center, "A battle is already on!");

        return PLUGIN_HANDLED;
    } 

    teamTimer[0] = get_gametime();
    teamTimer[1] = get_gametime();
    battleStarted = true;

    client_print(id, print_center, "The battle has started!");

    return PLUGIN_HANDLED
}

public sTime(id) {

    if(battleStarted) {
        client_print(id, print_chat, "Gametime TTs: %f", get_gametime() - teamTimer[0]);
        client_print(id, print_chat, "Gametime CTs: %f", get_gametime() - teamTimer[1]);

        client_print(id, print_chat, "Multiplied by minutes: %02i", (get_gametime() - teamTimer[0]) - (0 * 60.0));
    }

    return PLUGIN_HANDLED;
}

public client_use_button(id, iButton)
{
    if(battleStarted) {
        if(iButton == STOP) {
            new iPlayers[32], iNum;
            new CsTeams:iTeam = cs_get_user_team(id);

            get_players(iPlayers, iNum, "ach");
        
            if(iTeam == CS_TEAM_T) {
                new currentTime = get_gametime() - teamTimer[0];
                new timeInString[32];

                ttos(currentTime, timeInString, 32);

                for(new i = 0; i < iNum; i++)
                    if(is_user_connected(i) && is_user_alive(i))
                        if(cs_get_user_team(i) == CS_TEAM_CT) {
                            isPlayerFrozen[i] = true;
                            set_pev( i, pev_flags, pev( i, pev_flags ) | FL_FROZEN );
                        }

                set_dhudmessage(255, 50, 0, -1.0, 0.83, 0, 0.0, 4.0, 2.0, 2.0);
                show_dhudmessage(0, "TTs finished the map in %s!", timeInString);

            } else if(iTeam == CS_TEAM_CT) {
                new Float:currentTime = get_gametime() - teamTimer[1];
                new timeInString[32];

                ttos(currentTime, timeInString, 32);

                for(new i = 0; i < iNum; i++)
                    if(is_user_connected(i) && is_user_alive(i))
                        if(cs_get_user_team(i) == CS_TEAM_T) {
                            isPlayerFrozen[i] = true;
                            set_pev( i, pev_flags, pev( i, pev_flags ) | FL_FROZEN );
                        }

                set_dhudmessage(255, 50, 0, -1.0, 0.83, 0, 0.0, 4.0, 2.0, 2.0);
                show_dhudmessage(0, "CTs finished the map in %s!", timeInString);

            }

            battleStarted = false;

            teamTimer[0] = 0.0;
            teamTimer[1] = 0.0;

            set_task(3.0, "removePlayerFreeze", 0, _, _, "b")
        }
    }
}

public removePlayerFreeze() {
    new iPlayers[32], iNum;

    get_players(iPlayers, iNum, "ach");

    for(new id = 0; id < iNum; id++)
        if(is_user_alive(id) && is_user_connected(id) && isPlayerFrozen[id]) {
            set_pev( id, pev_flags, pev( id, pev_flags ) & ~FL_FROZEN )
            isPlayerFrozen[id] = false;
        }
}

public ttos( Float:time, string[], len )
{
	new temp[32];
	new Float:seconds = time, minutes;

	minutes		= floatround( seconds / 60.0, floatround_floor );
	seconds		-= minutes * 60.0;

    if(minutes >= 0) {
        if(minutes > 1) 
            if(minutes == 1)
                formatex( temp, charsmax( temp ), "%i minute and %i second%s", floatround(minutes, floatround_floor), floatround(seconds, floatround_floor), seconds > 1 ? "s" : "" );
            else
                formatex( temp, charsmax( temp ), "%i minutes and %i second%s", floatround(minutes, floatround_floor), floatround(seconds, floatround_floor), seconds > 1 ? "s" : "" );
        else 
            formatex( temp, charsmax( temp ), "%i second%s", floatround(seconds, floatround_floor), seconds > 1 || seconds == 0 ? "s" : "" );
    }   

	formatex( string, len, temp );

	return(PLUGIN_HANDLED);
}