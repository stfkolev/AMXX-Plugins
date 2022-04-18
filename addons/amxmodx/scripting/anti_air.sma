/*
	Flashbang Things - by Misz (c) 2016
	
	Includes:
	- Anti Noflash
	- Anti Airflash
	- Chat message when somebody is full flashed (with duration)
	- HUD message for spectators showing how much the player is flashed in %%
	
	Credits to:
	ConnorMcLeod - Nades API (hooking flashbang explosion)
	Rul4 - Anti NoFlash
*/

#include < amxmodx >
#include < cstrike >
#include < fakemeta >
#include < hamsandwich >
#include < colorchat >
#include < engine >

#pragma ctrlchar '\'
#define IsOnLadder(%1) (pev(%1, pev_movetype) == MOVETYPE_FLY)

const m_pfnThink = 4;
const m_usEvent_Grenade = 228;
new const Source[3] = {255, 0, 0};  // green
new const Target[3] = {0, 0, 0};  // red

const FL_ONGROUND2 = (FL_CONVEYOR|FL_ONGROUND|FL_PARTIALGROUND|FL_INWATER|FL_FLOAT);  

new think_Detonate;

#define GetThink(%0) get_pdata_int(%0, m_pfnThink, 0)

#define HUDMSG_CHANNEL 1
#define HUDMSG_UPDATE_TIME 0.05

new g_iMaxPlayers;

new Float:g_flFlashUntil[33];
new Float:g_flUpdateTime[33];
new Float:g_flFlashDuration[33];
new Float:g_flFlashHoldTime[33];

new g_iCurrentFlasher,g_msgScreenFade, g_iSprite;

public plugin_init()
{ 
	register_plugin( "Flashbang Things", "0.5b", "trans" );
	
	state initializing;

	g_iMaxPlayers = get_maxplayers();
	
	register_event( "ScreenFade", "event_blinded", "be", "4=255", "5=255", "6=255", "7=255" );
	
	register_forward( FM_PlayerPreThink, "fwd_PlayerPreThink", 0 );
	register_forward( FM_AddToFullPack, "fwd_AddToFullPack", 0 );
	
	RegisterHam( Ham_Think, "grenade", "fwd_GrenadeThink", false );
	
	g_msgScreenFade = get_user_msgid("ScreenFade")
}

public plugin_precache() {
	g_iSprite = precache_model("sprites/effects/flashed.spr");
}

public client_putinserver( id )
{
	g_flFlashUntil[id] = g_flUpdateTime[id] = g_flFlashDuration[id] = g_flFlashHoldTime[id] = 0.0;
}

public client_disconnected( id )
{
	g_flFlashUntil[id] = g_flUpdateTime[id] = g_flFlashDuration[id] = g_flFlashHoldTime[id] = 0.0;
}

public fwd_PlayerPreThink( id ) <initializing> { return FMRES_IGNORED; }

public fwd_PlayerPreThink( id ) <initialized>
{
	if( !is_user_alive(id) || cs_get_user_team(id) != CS_TEAM_CT ) return FMRES_IGNORED;
	
	if(!(pev(id, pev_flags) & FL_ONGROUND2) && !IsOnLadder(id))
		return FMRES_IGNORED;
	
	static Float:gametime; gametime = get_gametime();
	
	if( g_flFlashUntil[id] > gametime && g_flUpdateTime[id] < gametime )
	{
		new percent;
		if( g_flFlashHoldTime[id] > gametime )
		{
			percent = 100;
		}
		else 
		{
			percent = floatround( ((g_flFlashUntil[id]-gametime)/(g_flFlashUntil[id] - g_flFlashHoldTime[id]))*100, floatround_tozero );
		}
		
		new MyColour[3];
		
		MyColour = Source;
		
		MyColour[0] = Source[0]   + (((Target[0]   - Source[0])   * percent) / 100);
		MyColour[1] = Source[1] + (((Target[1] - Source[1]) * percent) / 100);
		MyColour[2] = Source[2]  + (((Target[2]  - Source[2])  * percent) / 100);
		
		set_hudmessage( MyColour[0], MyColour[1], MyColour[2], 0.04, 0.5, 0, 0.0, 0.5+HUDMSG_UPDATE_TIME, 0.1, 0.1, HUDMSG_CHANNEL );
		
		for( new i = 1; i <= g_iMaxPlayers; i++ )
		{
			if( is_user_spectating_player(i,id) || i == 1)
			{
				show_hudmessage( i, "Flashed: %d\%", percent );
			}
		}
		g_flUpdateTime[id] = gametime + HUDMSG_UPDATE_TIME;
	}
	return FMRES_IGNORED;
}

public fwd_AddToFullPack( es, e, ent, host, flags, player, set ) <initializing> { return FMRES_IGNORED; }

public fwd_AddToFullPack( es, e, ent, host, flags, player, set ) <initialized>
{	
	if ( !is_user_alive(host) )
		return FMRES_IGNORED;
		
	if( cs_get_user_team(host) != CS_TEAM_CT )
		return FMRES_IGNORED;

	if(player)
	{
		if( !is_user_alive(ent) || ent == host )
			return FMRES_IGNORED;
	} 
	else 
	{	
		if(pev_valid(ent))
		{
			static Classname[33];
			pev(ent, pev_classname, Classname,32);
			new is_grenade = equal(Classname,"grenade");
	
			if( !is_grenade || pev( ent, pev_owner ) == host )		
				return FMRES_IGNORED;
	
		} else return FMRES_IGNORED;
	}
	if( get_gametime() < g_flFlashHoldTime[host] )
	{
		forward_return(FMV_CELL, 0);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

public fwd_GrenadeThink( ent ) <initialized>
{
	if( GetThink(ent) == think_Detonate )
	{
		g_iCurrentFlasher = pev(ent, pev_owner);
	}
	return HAM_IGNORED;
}

public fwd_GrenadeThink( ent ) <initializing>
{
	static thinkNum;
	if( isFlashBang2( ent ) == false ) return HAM_IGNORED;
		
	if( thinkNum != 0 && GetThink(ent) != thinkNum )
	{
		think_Detonate = GetThink(ent);
		g_iCurrentFlasher = pev(ent, pev_owner);
		state initialized;
	}
	thinkNum = GetThink(ent);
	return HAM_IGNORED;
}

public event_blinded( const id ) <initializing> { return PLUGIN_CONTINUE; }

public event_blinded(const id) <initialized>
{
	if(!is_user_alive(id) || !is_user_connected(g_iCurrentFlasher) || id == g_iCurrentFlasher)
		return PLUGIN_HANDLED;
 
	if( cs_get_user_team(g_iCurrentFlasher) != CS_TEAM_T || cs_get_user_team(id) != CS_TEAM_CT)
		return PLUGIN_CONTINUE;
		
	if(!(pev(id, pev_flags) & FL_ONGROUND2) && !IsOnLadder(id) && distance_to_ground(id) > 150.0)
	{
			message_begin(MSG_ONE, g_msgScreenFade, {0,0,0}, id)
			write_short(1)
			write_short(1)
			write_short(1)
			write_byte(0)
			write_byte(0)
			write_byte(0)
			write_byte(255)
			message_end()

			message_begin(MSG_BROADCAST, SVC_TEMPENTITY, {0, 0, 0}, id)
			write_short(TE_PLAYERATTACHMENT)
			write_entity(id)
			write_coord(32)
			write_short(g_iSprite)
			write_short(floatround((read_data(1)/4096.0) * 10))
			message_end()
			
			return PLUGIN_CONTINUE;
	}

	new flasher[32], name[32];
	get_user_name(g_iCurrentFlasher, flasher, 31);
	get_user_name(id, name, 31);

	g_flFlashDuration[id] = read_data(1)/4096.0;
	g_flFlashUntil[id] = get_gametime() + g_flFlashDuration[id];
	g_flFlashHoldTime[id] = get_gametime() + read_data(2)/4096.0;
	
	for( new i = 1; i <= g_iMaxPlayers; i++ )
	{
		if( !is_user_connected(i) ) continue;
		if( i == id )
			ColorChat(i,NORMAL, "Player\x04 %s\x01 flashed\x04 you", flasher);
		else
			ColorChat(i,NORMAL, "Player\x04 %s\x01 flashed\x04 %s\x01 for \x04%.2f\x01 seconds", flasher,name, read_data(2)/4096.0 );
	}
		
	return PLUGIN_CONTINUE
}

stock is_user_spectating_player(spectator, player)
{
        if( !is_user_connected(spectator) || !is_user_connected(player) )
                return 0;
        if( is_user_alive(spectator) || !is_user_alive(player) )
                return 0;
        if( pev(spectator, pev_deadflag) != 2 )
                return 0;
       
        static specmode;
        specmode = pev(spectator, pev_iuser1);
        if( specmode == 3 )
                return 0;
       
        if( pev(spectator, pev_iuser2) == player )
                return 1;
       
        return 0;
}

stock bool:isFlashBang2( ent )
{
	new iBits = get_pdata_int(ent, 114, 5)
	if( !iBits )
	{
		return true;
	}
	return false;
}


stock Float:distance_to_ground( id ) 
{ 
    new Float:start[3], Float:end[3]; 
    entity_get_vector(id, EV_VEC_origin, start); 
    if( entity_get_int(id, EV_INT_flags) & FL_DUCKING ) 
    { 
        start[2] += 18.0; 
    } 

    end[0] = start[0]; 
    end[1] = start[1]; 
    end[2] = start[2] - 9999.0; 

    new ptr = create_tr2(); 
    engfunc(EngFunc_TraceHull, start, end, IGNORE_MONSTERS, HULL_HUMAN, id, ptr); 
    new Float:fraction; 
    get_tr2(ptr, TR_flFraction, fraction); 
    free_tr2(ptr); 

    return fraction * 9999.0; 
}  