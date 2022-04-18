#if defined _mix_natives_included
	#endinput
#endif

#define _mix_natives_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib mix_natives
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib mix_natives
	#endif
#else
	#pragma library mix_natives
#endif

/*
 * An enumeration of game modes
 */
enum {
	e_gTraining = 0,
	e_gPaused,
	e_gKnife,
	e_gCaptain,
	e_gMix,
	e_gPub
}

/* 
 * Gets the finishing state of the mix
 * 
 * @return	int
 * 
 */
native get_game_finish_status();

/* 
 * Gets the current survival state of the mix
 * 
 * @return	boolean
 * 
 */
native is_survival();

/* 
 * Sets the current game mode of the mix
 * 
 * @param	gameMode - enumeration of game modes, look @GameMode
 * 
 * @note	Use this precatiously
 * 
 */
native set_mode(GameMode: gameMode);

/* 
 * Gets the current game mode of the mix
 * 
 * @return	GameMode enumeration, look @GameMode
 * 
 */
native get_mode();

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
