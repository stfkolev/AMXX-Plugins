#pragma reqlib "frostnades_fix"

/*
 * Checks if the player is chilled
 * 
 * @param		id - Player ID
 * 
 * @return		bool
 * 
 */
native bool:fn_is_user_chilled(id);

/*
 * Checks if the player is frozen
 * 
 * @param		id - Player ID
 * 
 * @return		bool
 * 
 */
native bool:fn_is_user_frozen(id);

/*
 * Returns the chillspeed set on player
 * 
 * @param		id - Player ID
 * 
 * @return		Float
 * 
 */
native Float:fn_get_user_chillspeed(id);

/*
 * Returns the chill duration
 * 
 * @param		id - Player ID
 * 
 * @return		Float
 * 
 */
native Float:fn_get_chill_duration();

