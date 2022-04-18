#if defined _kz_buttons_included
	#endinput
#endif
#define _kz_buttons_included

#pragma reqlib kz_buttons

#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib kz_buttons
#endif

#define START	0
#define STOP	1
#define BUTTONS	2

forward client_use_button(index, button)