#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#include <hns/core_const>

#define MAXPLAYERS 32

enum _:TOTAL_FORWARDS {
    FW_USER_LAST_HIDER,
    FW_USER_LAST_SEEKER,
    FW_USER_SPAWN_POST,
}

#define flag_get(%1,%2)             (%1 & (1 << (%2 & 31)))
#define flag_get_bool(%1,%2)        (flag_get(%1,%2) ? true : false)
#define flag_set(%1,%2)             (%1 |= (1 << (%2 & 31)))
#define flag_unset(%1,%2)           (%1 &= ~(1 << (%2 & 31)))

new g_MaxPlayers;
new g_IsHider;
new g_IsLastHider;
new g_IsLastHiderForwardCalled;
new g_IsLastSeeker;
new g_IsLastSeekerForwardCalled;
new g_ForwardResult;
new g_Forwards[TOTAL_FORWARDS];

public plugin_init() {
    register_plugin("[HNS] Core/Engine", HNS_VERSION_STRING, "trans");

    g_Forwards[FW_USER_LAST_HIDER]      = CreateMultiForward("hns_fw_core_last_hider", ET_IGNORE, FP_CELL);
    g_Forwards[FW_USER_LAST_SEEKER]     = CreateMultiForward("hns_fw_core_last_seeker", ET_IGNORE, FP_CELL);
    g_Forwards[FW_USER_SPAWN_POST]      = CreateMultiForward("hns_fw_core_spawn_post", ET_IGNORE, FP_CELL);

    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1);
    RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1);

    register_forward(FM_ClientDisconnect, "fw_ClientDisconnect_Post", 1);

    g_MaxPlayers = get_maxplayers();

    register_cvar("hns_version", HNS_VERSION_STR_LONG, FCVAR_SERVER|FCVAR_SPONLY);
    set_cvar_string("hns_version", HNS_VERSION_STR_LONG);
}

public plugin_natives() {
    register_library("hns_core");

    register_native("hns_core_is_hider", "native_core_is_hider");
    register_native("hns_core_is_last_hider", "native_core_is_last_hider");
    register_native("hns_core_is_last_seeker", "native_core_is_last_seeker");

    register_native("hns_core_get_hiders_count", "native_core_get_hiders_count");
    register_native("hns_core_get_seekers_count", "native_core_get_seekers_count");
}


/*! 
 * Calls
 */

public fw_PlayerSpawn_Post(id) {

	// Not alive or didn't join a team yet
	if (!is_user_alive(id) || !cs_get_user_team(id))
		return;
	
	// Spawn Forward
	ExecuteForward(g_Forwards[FW_USER_SPAWN_POST], g_ForwardResult, id)
}

// Ham Player Killed Post Forward
public fw_PlayerKilled_Post()
{
	CheckLastHiderOrSeeker()
}

public fw_ClientDisconnect_Post(id)
{
	// Reset flags AFTER disconnect (to allow checking if the player was hider before disconnecting)
	flag_unset(g_IsHider, id)
	
	// This should be called AFTER client disconnects (post forward)
	CheckLastHiderOrSeeker()
}

/*! 
 * Natives
 */

public native_core_is_hider(plugin_id, num_params) {
    new id = get_param(1);

    if(!is_user_connected(id)) {
        log_error(AMX_ERR_NATIVE, "[HNS] Invalid Player (%d)", id);

        return -1;
    }

    return flag_get_bool(g_IsHider, id);
}

public native_core_is_last_hider(plugin_id, num_params) {
    new id = get_param(1);

    if(!is_user_connected(id)) {
        log_error(AMX_ERR_NATIVE, "[HNS] Invalid Player (%d)", id);

        return -1;
    }

    return flag_get_bool(g_IsLastHider, id);
}

public native_core_is_last_seeker(plugin_id, num_params) {
    new id = get_param(1);

    if(!is_user_connected(id)) {
        log_error(AMX_ERR_NATIVE, "[HNS] Invalid Player (%d)", id);

        return -1;
    }

    return flag_get_bool(g_IsLastSeeker, id);
}

public native_core_get_hiders_count(plugin_id, num_params) {
    return GetHidersCount();
}

public native_core_get_seekers_count(plugin_id, num_params) {
    return GetSeekersCount();
}

/*!
 * Stocks
 */
stock GetHidersCount() {
    new iHiders, id;

    for(id = 1; id <= g_MaxPlayers; id++) {
        if(is_user_alive(id) && flag_get(g_IsHider, id))
            iHiders++;
    }

    return iHiders
}

stock GetSeekersCount() {
    new iSeekers, id;

    for(id = 1; id <= g_MaxPlayers; id++) {
        if(is_user_alive(id) && !flag_get(g_IsHider, id))
            iSeekers++;
    }

    return iSeekers
}

stock CheckLastHiderOrSeeker() {
    new id, last_hider_id, last_seeker_id;
    new hiders_count = GetHidersCount();
    new seekers_count = GetHidersCount();

    if(hiders_count == 1) {
        for(id = 1; id <= g_MaxPlayers; id++) {

            /*! Last Hider */
            if(is_user_alive(id) && flag_get(g_IsHider, id)) {
                flag_set(g_IsLastHider, id);
                last_hider_id = id;
            } else {
                flag_unset(g_IsLastHider, id);
            }
        }
    } else {
        g_IsLastHiderForwardCalled = false;

        for(id = 1; id <= g_MaxPlayers; id++) {
            flag_unset(g_IsLastHider, id);
        }
    }

    if(last_hider_id > 0 && !g_IsLastHiderForwardCalled) {
        ExecuteForward(g_Forwards[FW_USER_LAST_HIDER], g_ForwardResult, last_hider_id);
        g_IsLastHiderForwardCalled = true;
    }

    /*! Seekers Time */
    
    if(seekers_count == 1) {
        for(id = 1; id <= g_MaxPlayers; id++) {

            /*! Last Seeker */
            if(is_user_alive(id) && !flag_get(g_IsHider, id)) {
                flag_set(g_IsLastSeeker, id);
                last_seeker_id = id;
            } else {
                flag_unset(g_IsLastSeeker, id);
            }
        }
    } else {
        g_IsLastSeekerForwardCalled = false;

        for(id = 1; id <= g_MaxPlayers; id++) {
            flag_unset(g_IsLastSeeker, id);
        }
    }

    if(last_seeker_id > 0 && !g_IsLastSeekerForwardCalled) {
        ExecuteForward(g_Forwards[FW_USER_LAST_SEEKER], g_ForwardResult, last_seeker_id);
        g_IsLastSeekerForwardCalled = true;
    }
}