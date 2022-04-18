#if defined _transmix_included
	#endinput
#endif

#define _transmix_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib "transmix"
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib "transmix"
	#endif
#else
	#pragma library "transmix"
#endif

native isMix();
native getCurrentMode();
native get_hiders_captain();
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
