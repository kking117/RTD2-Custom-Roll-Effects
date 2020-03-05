#pragma semicolon 1

#include <rtd2>
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>


new bool:HasPerk[MAXPLAYERS+1];
new Float:DiminishRate[MAXPLAYERS+1];

new Handle:cvarSR_Shotgun_Force;
new Float:f_SR_Shotgun_Force = -500.0;

new Handle:cvarSR_Pistol_Force;
new Float:f_SR_Pistol_Force = -175.0;

new Handle:cvarSR_Syringe_Force;
new Float:f_SR_Syringe_Force = -125.0;

new Handle:cvarSR_SMG_Force;
new Float:f_SR_SMG_Force = -140.0;

new Handle:cvarSR_RL_Force;
new Float:f_SR_RL_Force = -600.0;

new Handle:cvarSR_GL_Force;
new Float:f_SR_GL_Force = -600.0;

new Handle:cvarSR_SL_Force;
new Float:f_SR_SL_Force = -600.0;

new Handle:cvarSR_MG_Force;
new Float:f_SR_MG_Force = -30.0;

new Handle:cvarSR_FT_Force;
new Float:f_SR_FT_Force = -25.0;

new Handle:cvarSR_SR_Force;
new Float:f_SR_SR_Force = -600.0;

new Handle:cvarSR_Laser_Force;
new Float:f_SR_Laser_Force = -500.0;

new Handle:cvarSR_FG_Force;
new Float:f_SR_FG_Force = -300.0;

new Handle:cvarSR_Revolver_Force;
new Float:f_SR_Revolver_Force = -250.0;

new Handle:cvarSR_Bow_Force;
new Float:f_SR_Bow_Force = -600.0;

new Handle:cvarSR_Cleaver_Force;
new Float:f_SR_Cleaver_Force = -600.0;

new Handle:cvarSR_Jar_Force;
new Float:f_SR_Jar_Force = -1200.0;

new Handle:cvarSR_Diminish;
new Float:f_SR_Diminish = 0.01;

new Handle:cvarSR_Diminish_Scale;
new Float:f_SR_Diminish_Scale = 0.25;

public Plugin myinfo = 
{
	name = "RTD2 Stronger Recoil",
	author = "kking117",
	description = "Adds the negative perk Stronger Recoil to rtd2."
};

public void OnPluginStart()
{
	cvarSR_Shotgun_Force=CreateConVar("rtd_strongerrecoil_force_shotgun", "-500.0", "The pushback force of scatterguns, shotguns and the rescue ranger, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Shotgun_Force, CvarChange);
	
	cvarSR_Pistol_Force=CreateConVar("rtd_strongerrecoil_force_pistol", "-175.0", "The pushback force of pistols, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Pistol_Force, CvarChange);
	
	cvarSR_Syringe_Force=CreateConVar("rtd_strongerrecoil_force_syringegun", "-125.0", "The pushback force of syringe guns, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Syringe_Force, CvarChange);
	
	cvarSR_SMG_Force=CreateConVar("rtd_strongerrecoil_force_smg", "-140.0", "The pushback force of smgs, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_SMG_Force, CvarChange);
	
	cvarSR_RL_Force=CreateConVar("rtd_strongerrecoil_force_rocketlauncher", "-600.0", "The pushback force of rocket launchers, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_RL_Force, CvarChange);
	
	cvarSR_GL_Force=CreateConVar("rtd_strongerrecoil_force_grenadelauncher", "-600.0", "The pushback force of grenade launchers, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_GL_Force, CvarChange);
	
	cvarSR_SL_Force=CreateConVar("rtd_strongerrecoil_force_stickylauncher", "-600.0", "The pushback force of stickybomb launchers, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_SL_Force, CvarChange);
	
	cvarSR_MG_Force=CreateConVar("rtd_strongerrecoil_force_minigun", "-30.0", "The pushback force of miniguns, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_MG_Force, CvarChange);
	
	cvarSR_FT_Force=CreateConVar("rtd_strongerrecoil_force_flamethrower", "-25.0", "The pushback force of flamethrowers, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_FT_Force, CvarChange);
	
	cvarSR_SR_Force=CreateConVar("rtd_strongerrecoil_force_sniperrifle", "-600.0", "The pushback force of sniper rifles, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_SR_Force, CvarChange);
	
	cvarSR_Laser_Force=CreateConVar("rtd_strongerrecoil_force_laser", "-500.0", "The pushback force of the righteous bison and pomson 6000, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Laser_Force, CvarChange);
	
	cvarSR_FG_Force=CreateConVar("rtd_strongerrecoil_force_flaregun", "-300.0", "The pushback force of flareguns and the man melter, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_FG_Force, CvarChange);
	
	cvarSR_Revolver_Force=CreateConVar("rtd_strongerrecoil_force_revolver", "-250.0", "The pushback force of revolvers, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Revolver_Force, CvarChange);
	
	cvarSR_Bow_Force=CreateConVar("rtd_strongerrecoil_force_bow", "-600.0", "The pushback force of the huntsman and crusader's crossbow, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Bow_Force, CvarChange);
	
	cvarSR_Cleaver_Force=CreateConVar("rtd_strongerrecoil_force_cleaver", "-600.0", "The pushback force of the flying guillotine, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Cleaver_Force, CvarChange);
	
	cvarSR_Jar_Force=CreateConVar("rtd_strongerrecoil_force_jar", "-1200.0", "The pushback force of jar weapons, 0 = has no effect.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Jar_Force, CvarChange);
	
	cvarSR_Diminish=CreateConVar("rtd_strongerrecoil_diminish_rate", "0.01", "Reduces the knockback force of the recoil by this much in percentage each time it's activated without touching the ground, less than 0.0 = disabled.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Diminish, CvarChange);
	
	cvarSR_Diminish_Scale=CreateConVar("rtd_strongerrecoil_diminish_ratescale", "0.25", "Scales the diminish rate based on the weapons knockback lower numbers means the knockback amount has less influence, 0.0 = disabled.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarSR_Diminish_Scale, CvarChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarSR_Shotgun_Force)
	{
		f_SR_Shotgun_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Pistol_Force)
	{
		f_SR_Pistol_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Syringe_Force)
	{
		f_SR_Syringe_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_SMG_Force)
	{
		f_SR_SMG_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_RL_Force)
	{
		f_SR_RL_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_GL_Force)
	{
		f_SR_GL_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_SL_Force)
	{
		f_SR_SL_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_MG_Force)
	{
		f_SR_MG_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_FT_Force)
	{
		f_SR_FT_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_SR_Force)
	{
		f_SR_SR_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Laser_Force)
	{
		f_SR_Laser_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_FG_Force)
	{
		f_SR_FG_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Revolver_Force)
	{
		f_SR_Revolver_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Bow_Force)
	{
		f_SR_Bow_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Jar_Force)
	{
		f_SR_Jar_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Cleaver_Force)
	{
		f_SR_Cleaver_Force = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Diminish)
	{
		f_SR_Diminish = StringToFloat(newValue);
	}
	else if(convar==cvarSR_Diminish_Scale)
	{
		f_SR_Diminish_Scale = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_SR_RL_Force = GetConVarFloat(cvarSR_RL_Force);
	f_SR_SL_Force = GetConVarFloat(cvarSR_SL_Force);
	f_SR_GL_Force = GetConVarFloat(cvarSR_GL_Force);
	f_SR_MG_Force = GetConVarFloat(cvarSR_MG_Force);
	f_SR_SR_Force = GetConVarFloat(cvarSR_SR_Force);
	f_SR_FT_Force = GetConVarFloat(cvarSR_FT_Force);
	f_SR_FG_Force = GetConVarFloat(cvarSR_FG_Force);
	f_SR_Shotgun_Force = GetConVarFloat(cvarSR_Shotgun_Force);
	f_SR_Jar_Force = GetConVarFloat(cvarSR_Jar_Force);
	f_SR_SMG_Force = GetConVarFloat(cvarSR_SMG_Force);
	f_SR_Revolver_Force = GetConVarFloat(cvarSR_Revolver_Force);
	f_SR_Laser_Force = GetConVarFloat(cvarSR_Laser_Force);
	f_SR_Pistol_Force = GetConVarFloat(cvarSR_Pistol_Force);
	f_SR_Bow_Force = GetConVarFloat(cvarSR_Bow_Force);
	f_SR_Syringe_Force = GetConVarFloat(cvarSR_Syringe_Force);
	f_SR_Diminish = GetConVarFloat(cvarSR_Diminish);
	f_SR_Diminish_Scale = GetConVarFloat(cvarSR_Diminish_Scale);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
		DiminishRate[client]=1.0;
	}
}

public OnClientPutInServer(client)
{
	HasPerk[client] = false;
}

public void RTD2_OnRegOpen()
{
    RegisterPerk(); // Core plugin fully initialized or perks were refetched, register our perk
}

public void OnPluginEnd()
{
    RTD2_DisableModulePerks(); // ensures custom perks will be called for deactivation, in case this module unloads
}

void RegisterPerk()
{
    RTD2_ObtainPerk("strongerrecoil") // create perk using unique token "mytoken"
        .SetName("Stronger Recoil") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/taunts/sniper_taunts45.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, strong, recoil, weapon, shooting, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		DiminishRate[client]=1.0;
	}
	else
	{
		HasPerk[client]=false;
		DiminishRate[client]=1.0;
	}
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
    if(HasPerk[client] && GetPlayerWeaponSlot(client, 2) != weapon)
	{
		new Float:eyeangles[3];
		new Float:clientvelocity[3];
		new Float:ScreenShake[3];
		new Float:vbuffer[3];
		ScreenShake[0] = GetRandomFloat(-20.0, -80.0);
		ScreenShake[1] = GetRandomFloat(-25.0, 25.0);
		ScreenShake[2] = GetRandomFloat(-25.0, 25.0);
		GetClientEyeAngles(client, eyeangles);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientvelocity);
		GetAngleVectors(eyeangles, vbuffer, NULL_VECTOR, NULL_VECTOR);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", ScreenShake);
		if(StrContains(weaponname, "tf_weapon_scattergun")>=0 || StrContains(weaponname, "tf_weapon_shotgun")>=0 || StrContains(weaponname, "tf_weapon_soda")>=0 || StrContains(weaponname, "tf_weapon_pep_brawler")>=0 || StrContains(weaponname, "tf_weapon_handgun_scout")>=0 || StrContains(weaponname, "tf_weapon_sentry_revenge")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Shotgun_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Shotgun_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Shotgun_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Shotgun_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Shotgun_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Shotgun_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Shotgun_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_minigun")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				//generally miniguns are super fast
				//so we'll reduce their diminish rates internally
				//so I don't have to do as much work
				//and you can actually use the damn thing to fly for more than half a second
				DiminishRate[client]-=f_SR_Diminish*0.25;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=((f_SR_MG_Force*-0.001)*f_SR_Diminish_Scale)*0.25;
				}
			}
			if(f_SR_MG_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_MG_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_MG_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_MG_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_MG_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_MG_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_flamethrower")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				//generally flamethrowers shoot alot
				//so we'll reduce their diminish rates internally
				//so I don't have to do as much work
				//and you can actually use the damn thing to fly for more than half a second
				DiminishRate[client]-=f_SR_Diminish*0.25;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=((f_SR_FT_Force*-0.001)*f_SR_Diminish_Scale)*0.5;
				}
			}
			if(f_SR_FT_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_FT_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_FT_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_FT_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_FT_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_FT_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_rocketlauncher")>=0 || StrContains(weaponname, "tf_weapon_particle_cannon")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_RL_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_RL_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_RL_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_RL_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_RL_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_RL_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < 0.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_RL_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_grenadelauncher")>=0 || StrContains(weaponname, "tf_weapon_cannon")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_GL_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_GL_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_GL_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_GL_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_GL_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_GL_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_GL_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_pipebomblauncher")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_SL_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_SL_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_SL_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_SL_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_SL_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_SL_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_SL_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_flaregun")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_FG_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_FG_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_FG_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_FG_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_FG_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_FG_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_FG_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_sniperrifle")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_SR_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_SR_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_SR_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_SR_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_SR_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_SR_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_SR_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_smg")>=0 || StrContains(weaponname, "tf_weapon_charged_smg")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_SMG_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_SMG_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_SMG_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_SMG_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_SMG_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_SMG_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_SMG_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_raygun")>=0 || StrContains(weaponname, "tf_weapon_drg_pomson")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Laser_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Laser_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Laser_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Laser_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Laser_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Laser_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Laser_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_pistol")>=0 || StrContains(weaponname, "tf_weapon_handgun_scout_secondary")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Pistol_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Pistol_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Pistol_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Pistol_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Pistol_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Pistol_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Pistol_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_syringegun_medic")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Syringe_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Syringe_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Syringe_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Syringe_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Syringe_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Syringe_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Syringe_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_crossbow")>=0 || StrContains(weaponname, "tf_weapon_compound_bow")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Bow_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Bow_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Bow_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Bow_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Bow_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Bow_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Bow_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_revolver")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Revolver_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Revolver_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Revolver_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Revolver_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Revolver_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Revolver_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Revolver_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_cleaver")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Cleaver_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Cleaver_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Cleaver_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Cleaver_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Cleaver_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Cleaver_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Cleaver_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
		else if(StrContains(weaponname, "tf_weapon_jar")>=0)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				DiminishRate[client]-=f_SR_Diminish;
				if (f_SR_Diminish_Scale != 0.0)
				{
					DiminishRate[client]-=(f_SR_Jar_Force*-0.001)*f_SR_Diminish_Scale;
				}
			}
			if(f_SR_Jar_Force != 0.0 && DiminishRate[client] > 0.05)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					vbuffer[0]=(vbuffer[0]*((f_SR_Jar_Force*0.5)*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*((f_SR_Jar_Force*0.5)*DiminishRate[client]))+clientvelocity[1];
				}
				else
				{
					vbuffer[0]=(vbuffer[0]*(f_SR_Jar_Force*DiminishRate[client]))+clientvelocity[0];
					vbuffer[1]=(vbuffer[1]*(f_SR_Jar_Force*DiminishRate[client]))+clientvelocity[1];
				}
				if (clientvelocity[2] < -10.0)
				{
					clientvelocity[2] *=0.5;
				}
				vbuffer[2]=(vbuffer[2]*(f_SR_Jar_Force*DiminishRate[client]))+clientvelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vbuffer);
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(HasPerk[client])
	{
		if((GetEntityFlags(client) & FL_ONGROUND))
		{
			DiminishRate[client]=1.0;
		}
	}
	return Plugin_Continue;
}

stock bool:IsValidClient(client, bool:replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}