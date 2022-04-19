#if defined _hns_core_included
    #endinput
#endif

#define _hns_core_included

#include <hns/core_const>

#if AMXX_VERSION_NUM >= 175
    #pragma reqlib hns_core
    #if !defined AMXXMOD_NOAUTOLOAD
        #pragma loadlib hns_core
    #endif
#else
    #pragma library hns_core
#endif

/**
 * Returns whether the player is a hider.
 *
 * @param id        Player Index
 *
 * @return          True if the player is hider, false otherwise
 */

native hns_core_is_hider(id);

/**
 * Returns whether the player is the last hider.
 *
 * @param id        Player Index
 *
 * @return          True if the player is the last hider, false otherwise
 */

native hns_core_is_last_hider(id);

/**
 * Returns whether the player is the last seeker.
 *
 * @param id        Player Index
 *
 * @return          True if the player is the last seeker, false otherwise
 */

native hns_core_is_last_seeker(id);

/**
 * Returns number of alive hiders.
 *
 * @return		Hiders count.
 */
native hns_core_get_hiders_count();

/**
 * Returns number of alive seekers.
 *
 * @return		Seekers count.
 */
native hns_core_get_seekers_count();