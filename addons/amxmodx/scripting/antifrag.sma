#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <frostnades_fix>

#define PLUGIN      "Simple Anti-Frag"
#define VERSION     "0.5"
#define AUTHOR      "Autumn Shade"

#define MAX_PLAYERS     32

new g_bPlayerHealth[MAX_PLAYERS + 1];
new bool:g_bPlayerSlowed[MAX_PLAYERS + 1]
new bool:g_bPlayerKilled[MAX_PLAYERS + 1]
new bool:g_bPlayerHit[MAX_PLAYERS + 1]

new g_bCvarTime;
new g_bCvarIgnore;
new g_bCvarSlow;

public plugin_init() {

    register_plugin(PLUGIN, VERSION, AUTHOR)

    RegisterHam(Ham_TakeDamage, "player", "fwTakeDamage")
    register_event( "DeathMsg", "fwPlayerKilled", "a", "1>0", "3=1" );

    register_forward(FM_PlayerPreThink, "fwPlayerPreThink", 0);

    g_bCvarTime     = register_cvar("af_slow_time", "1.0");
    g_bCvarIgnore   = register_cvar("af_ignore_time", "3.0");
    g_bCvarSlow     = register_cvar("af_slow_substraction", "80.0");
}

public fwPlayerKilled() {
    new iAttacker = read_data(1);
    new iVictim = read_data(2);
    new iHeadshot = read_data(3);

    if(!is_user_connected(iAttacker) || !is_user_alive(iAttacker))
        return PLUGIN_HANDLED;

    if(iHeadshot) {
        g_bPlayerKilled[iVictim] = true;
    }

    return PLUGIN_HANDLED;
}

public fwTakeDamage(iVictim, iEntity, iAttacker, Float:flDamage, iDamagebits) {
    if (!is_user_connected(iVictim) || !is_user_connected(iAttacker) || iVictim == iAttacker)
        return HAM_IGNORED

    new Float:g_iTime = get_pcvar_float(g_bCvarTime);

    if (get_user_team(iAttacker) == 2 && get_user_team(iVictim) == 1) {
        if(g_bPlayerHealth[iVictim] > 65 && !g_bPlayerKilled[iVictim]) {
            g_bPlayerHealth[iVictim] = get_user_health(iVictim);

            if (!g_bPlayerSlowed[iAttacker]) {
                new iChillDuration = fn_get_chill_duration();

                g_bPlayerSlowed[iAttacker] = true;

                if(fn_is_user_chilled(iAttacker)) {
                    new Float:iCalcTime = floatmul(floatadd(floatround(iChillDuration), g_iTime), 0.7);
                    
                    set_task(iCalcTime, "cmdOffStop", iAttacker);
                } else 
                    set_task(g_iTime, "cmdOffStop", iAttacker);
            }
        }

        if(!g_bPlayerHit[iVictim]) {
            g_bPlayerHit[iVictim] = true;
            new Float:iTime = get_pcvar_float(g_bCvarIgnore);
            client_print(0, print_chat, "%f", iTime);
            set_task(iTime, "fwRemoveIgnore", iVictim);
            
        } else
            return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public client_disconnected(id) {
    remove_task(id)
}

public fwRemoveIgnore(id) {
    g_bPlayerHit[id] = false;
}

public cmdOffStop(id) {
    g_bPlayerSlowed[id] = false;
    
    if(!fn_is_user_chilled(id))
        engfunc(EngFunc_SetClientMaxspeed, id, 250.0);
}

public fwPlayerPreThink(id) {
    g_bPlayerHealth[id] = get_user_health(id);

    if (g_bPlayerSlowed[id]) {
        new Float:iSlowRatio = get_pcvar_float(g_bCvarSlow);
        new iPlayerChillSpeed = fn_get_user_chillspeed(id);
        
        engfunc(EngFunc_SetClientMaxspeed, id, floatsub(iPlayerChillSpeed, iSlowRatio));
    }

    return FMRES_IGNORED;
}