/*
 *
 * HNS Block Return
 *
 * Copyright 2016 Garey <garey@ya.ru>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

new Array:g_arFlPlayerOrigin[33]
new Array:g_arFlPlayerAngle[33]
new bool:g_bIsTouched[33];
new bool:g_bIsBlocked[33];
new iToucher[33];
new g_iMaxPlayers;
new cvarFX;

public plugin_precache()
{
	precache_sound("ambience/rewind.wav")
}

public plugin_init()
{
	register_plugin("Block Return", "0.1", "Garey");

	cvarFX = register_cvar("hns_block_fx", "1");

	g_iMaxPlayers = get_maxplayers();

	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		g_arFlPlayerOrigin[i] = ArrayCreate(3);
		g_arFlPlayerAngle[i] = ArrayCreate(3);
	}

	RegisterHam( Ham_Player_PreThink, "player", "fwd_PlayerPreThink", 0 );
	RegisterHam( Ham_Touch, "player", "fwd_TouchPlayer", 0 );
	RegisterHam( Ham_TakeDamage, "player", "Ham_TakeDamagePlayer" );
}

public fwd_TouchPlayer( id, entity )
{
	if( get_user_team( id ) != 2 || !is_user_alive( entity ))
		return;

	if( get_user_team( entity ) != 1 )
		return;

	new flVelocity[3]
	pev(id, pev_velocity, flVelocity);
	// Check if player was in Air
	if(flVelocity[2] != 0.0)
	{
		g_bIsTouched[id] = true;
		iToucher[id] = entity;
	}
}


public Ham_TakeDamagePlayer(iVictim, iInflictor, iAttacker, Float:flDamage, iDamageBits)
{
	if( is_user_alive(iVictim) && flDamage >= 50.0 && iDamageBits & DMG_FALL )
	{
		if( get_user_team(iVictim) == 2 )
		{
			if(g_bIsTouched[iVictim] && is_user_alive(iToucher[iVictim]))
			{
				iToucher[iVictim] = 0;
				g_bIsBlocked[iVictim] = true;
				if(get_pcvar_num(cvarFX))
				emit_sound(iVictim, CHAN_AUTO, "ambience/rewind.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
				set_pev(iVictim, pev_movetype, MOVETYPE_NOCLIP)
				return HAM_SUPERCEDE;
			}
		}
	}
	return HAM_IGNORED;
}

public fwd_PlayerPreThink( id )
{
	static flPlayerOrigin[3], flPlayerAngles[3], LastFrames[33]

	if(is_user_alive(id))
	{
		if(!g_bIsBlocked[id])
		{
			pev(id, pev_origin, flPlayerOrigin);
			pev(id, pev_v_angle, flPlayerAngles);

			if((pev(id, pev_flags) & FL_ONGROUND) || pev(id, pev_movetype) == MOVETYPE_FLY)
			{
				if(LastFrames[id] > 10)
				{
					g_bIsTouched[id] = false;
					ArrayClear(g_arFlPlayerOrigin[id]);
					ArrayClear(g_arFlPlayerAngle[id]);
					LastFrames[id] = 0;
				}
				else
				{
					ArrayPushArray(g_arFlPlayerOrigin[id], flPlayerOrigin);
					ArrayPushArray(g_arFlPlayerAngle[id], flPlayerAngles);
					LastFrames[id]++;
				}
			}
			else
			{
				ArrayPushArray(g_arFlPlayerOrigin[id], flPlayerOrigin);
				ArrayPushArray(g_arFlPlayerAngle[id], flPlayerAngles);
			}
		}
		else
		{
			new Length = ArraySize(g_arFlPlayerOrigin[id])-1;

			if(Length)
			{
				ArrayGetArray(g_arFlPlayerOrigin[id], Length, flPlayerOrigin);
				ArrayGetArray(g_arFlPlayerAngle[id], Length, flPlayerAngles);

				ArrayDeleteItem(g_arFlPlayerOrigin[id], Length);
				ArrayDeleteItem(g_arFlPlayerAngle[id], Length);

				set_pev(id, pev_origin, flPlayerOrigin)
				set_pev(id, pev_angles, flPlayerAngles)
				set_pev(id, pev_fixangle, 1)
			}
			else
			{
				set_pev(id,pev_movetype,MOVETYPE_WALK)
				set_pev(id,pev_velocity,Float:{0.0,0.0,0.0})
				set_pev(id,pev_flags,pev(id,pev_flags)|FL_DUCKING)
				g_bIsBlocked[id] = false;
			}
		}
	}
	else
	{
		LastFrames[id] = 0;
	}
}