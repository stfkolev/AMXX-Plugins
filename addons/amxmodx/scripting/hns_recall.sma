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
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

new Array:g_PlayerOrigin[33]
new Array:g_PlayerAngle[33]
new Float:g_bRecallNextUse[33];
new bool:g_bHasRecalled[33];

new g_iMaxPlayers, g_cSound, g_cCooldown, g_Status;

#define TASK_MESSAGE 398822

public plugin_precache()
{
	precache_sound("ambience/recall.wav")
}

public plugin_init()
{
	register_plugin("HNS Ability: Recall", "1.0", "Autumn Shade");
	
	register_clcmd("hnsrecall", "cmdRecall", -1, "-Recall Ability")

	g_cSound 		= register_cvar("recall_sound", "1");
	g_cCooldown 	= register_cvar("recall_cooldown", "60");

	g_iMaxPlayers 	= get_maxplayers();

	g_Status = get_user_msgid("StatusIcon");

	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		g_PlayerOrigin[i] = ArrayCreate(3);
		g_PlayerAngle[i] = ArrayCreate(3);
	}

	RegisterHam( Ham_Player_PreThink, "player", "fwd_PlayerPreThink", 0 );
}

public client_connect(id) {
	g_bRecallNextUse[id] = 0.0;
}

public cmdRecall(id) {
	new Float:iTime = halflife_time();
	
	if (iTime >= g_bRecallNextUse[id])
	{
		if(cs_get_user_team(id) == CS_TEAM_T) {
			new Float:iTimeout = get_pcvar_float(g_cCooldown);

			g_bHasRecalled[id] = true;

			if(get_pcvar_num(g_cSound))
				emit_sound(id, CHAN_AUTO, "ambience/recall.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)

			set_pev(id, pev_movetype, MOVETYPE_NOCLIP)
			g_bRecallNextUse[id] = iTime + iTimeout;
		}
	}

	return PLUGIN_HANDLED;
}

public fwd_PlayerPreThink( id )
{
	static iPlayerOrigin[3], iPlayerAngles[3], iLastFrames[33]
	new Float:iTime = halflife_time();

	if (iTime >= g_bRecallNextUse[id]) {
		if(cs_get_user_team(id) == CS_TEAM_T) {

			message_begin(MSG_ONE, g_Status, {0,0,0}, id);
			write_byte(2); // status (0=hide, 1=show, 2=flash)
			write_string("escape"); // sprite name
			write_byte(52); // red
			write_byte(152); // green
			write_byte(219); // blue
			message_end();
		}
	} else {
		if(cs_get_user_team(id) == CS_TEAM_T) {
			message_begin(MSG_ONE, g_Status, {0,0,0}, id);
			write_byte(1); // status (0=hide, 1=show, 2=flash)
			write_string("escape"); // sprite name
			write_byte(231); // red
			write_byte(76); // green
			write_byte(60); // blue
			message_end();
		}
	}

	if(is_user_alive(id))
	{
		if(!g_bHasRecalled[id])
		{
			pev(id, pev_origin, iPlayerOrigin);
			pev(id, pev_v_angle, iPlayerAngles);

			if((pev(id, pev_flags) & FL_ONGROUND) || pev(id, pev_movetype) == MOVETYPE_FLY)
			{
				if(iLastFrames[id] > 10)
				{
					ArrayClear(g_PlayerOrigin[id]);
					ArrayClear(g_PlayerAngle[id]);
					iLastFrames[id] = 0;
				}
				else
				{
					ArrayPushArray(g_PlayerOrigin[id], iPlayerOrigin);
					ArrayPushArray(g_PlayerAngle[id], iPlayerAngles);
					iLastFrames[id]++;
				}
			}
			else
			{
				ArrayPushArray(g_PlayerOrigin[id], iPlayerOrigin);
				ArrayPushArray(g_PlayerAngle[id], iPlayerAngles);
			}
		}
		else
		{
			new Length = ArraySize(g_PlayerOrigin[id]) - 1;

			if(Length)
			{
				ArrayGetArray(g_PlayerOrigin[id], Length, iPlayerOrigin);
				ArrayGetArray(g_PlayerAngle[id], Length, iPlayerAngles);

				ArrayDeleteItem(g_PlayerOrigin[id], Length);
				ArrayDeleteItem(g_PlayerAngle[id], Length);

				set_pev(id, pev_origin, iPlayerOrigin)
				set_pev(id, pev_angles, iPlayerAngles)
				set_pev(id, pev_fixangle, 1)
			}
			else
			{
				set_pev(id,pev_movetype,MOVETYPE_WALK)
				set_pev(id,pev_velocity,Float:{0.0,0.0,0.0})
				set_pev(id,pev_flags,pev(id,pev_flags)|FL_DUCKING)
				g_bHasRecalled[id] = false;
			}
		}
	}
	else
	{
		iLastFrames[id] = 0;
	}
}