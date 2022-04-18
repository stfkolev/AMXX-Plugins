#if defined _player_settings_saver_included
	#endinput
#endif
#define _player_settings_saver_included

forward change_setting_value ( id, const setting[], const value[] )

native set_setting_value ( id, const setting[], const value[] )
native get_setting_value ( id, const setting[], {Float, _}:... )

#define set_setting_string set_setting_value

stock set_setting_int ( id, const setting[], value )
{
	new sValue[10]
	num_to_str ( value, sValue, charsmax ( sValue ) )
	return set_setting_value ( id, setting, sValue )
}

stock set_setting_float ( id, const setting[], Float:value )
{
	new sValue[18]
	float_to_str ( value, sValue, charsmax ( sValue ) )
	return set_setting_value ( id, setting, sValue )
}

stock set_setting_bool ( id, const setting[], bool:value ) { return set_setting_value ( id, setting, value ? "1" : "0" ); }
stock bool:get_setting_bool ( id, const setting[], bool:thatreturn = false )
{
	new iReturn = get_setting_value ( id, setting )
	return iReturn == -1 ? thatreturn : bool:iReturn
}