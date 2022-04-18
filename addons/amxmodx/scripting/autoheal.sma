#include <amxmodx>
#include <fakemeta>

// Copyright
#define PLUGIN "HP Autoheal"
#define VERSION "1.4"
#define AUTHOR "AciD"

// Defines
#define TASKID 100

// Cvars
new hp_reg, hp_regtime, hp_showdmg;

// Misc
new plrHeal[33]

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("AcidoX", "Autoheal 1.4", FCVAR_SERVER)
	register_event("Damage", "damage", "b", "2>0")
	
	hp_reg = register_cvar("hp_reg", "60")
	hp_regtime = register_cvar("hp_regtime", "0.5")
	hp_showdmg = register_cvar("hp_showdmg", "1")
}

public damage(id)
{
	new dmg = read_data(2)
	
	if(read_data(4) != 0 || read_data(5) != 0 || read_data(6) != 0) return
	
	if((get_pcvar_num(hp_showdmg) == 1) && dmg < 100) {
	new msg[32]
	formatex(msg, 31, "Damage: %i", dmg)
	set_hudmessage(255, 0, 0, 0.05, 0.9, 0, 2.0, 2.0, 0.2)
	show_hudmessage(id, msg)
	
	}
	plrHeal[id] += dmg
	
	if(!task_exists(TASKID + id))
	{
		set_task(get_pcvar_float(hp_regtime), "tsk_heal", id + TASKID)
	}
}


public tsk_heal(id)
{
	id -= TASKID
	
	if(plrHeal[id] == 0) return
	if(!is_user_alive(id))
	{
		plrHeal[id] = 0
		return
	}
	new hp_reg2 = get_pcvar_num(hp_reg);
	new hp = pev(id, pev_health)
	
	plrHeal[id] > hp_reg2 ? (plrHeal[id] = hp_reg2) : 0
	
	if(hp + plrHeal[id] > 100)
	{
		plrHeal[id] = 0
		return
	}

	set_pev(id, pev_health, float(hp + plrHeal[id]))
	plrHeal[id] = 0
	
	return
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
