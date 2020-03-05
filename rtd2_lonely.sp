#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new bool:HasPerk[MAXPLAYERS+1];

new Handle:cvarDRMult;
new Float:f_DRMult = 1.5;

new Handle:cvarBaseDmg;
new Float:f_BaseDmg = 4.0;

new Handle:cvarFFMult;
new Float:f_FFMult = 0.5;

new Handle:cvarRangeDist;
new Float:f_RangeDist = 300.0;

new BeamTrail; //ring stuff
new Handle:hTrace; //for wall checks
new clienthitno[MAXPLAYERS+1][MAXPLAYERS+1]; //used to keep track of how often the player has been hurt

public Plugin myinfo = 
{
	name = "RTD2 Lonely",
	author = "kking117",
	description = "Adds the negative perk Lonely to rtd2."
};

public void OnPluginStart()
{
	cvarDRMult=CreateConVar("rtd_lonely_dmg_rate_mult", "1.5", "Multiplier for lonely's stack damage.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarDRMult, CvarChange);
	
	cvarBaseDmg=CreateConVar("rtd_lonely_dmg_base", "4.0", "Base damage for lonely's damage.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarBaseDmg, CvarChange);
	
	cvarFFMult=CreateConVar("rtd_lonely_ff_mult", "0.5", "Lonely's damage multiplier vs team members.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarFFMult, CvarChange);
	
	cvarRangeDist=CreateConVar("rtd_lonely_dist", "300.0", "Lonely's range of influence.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarRangeDist, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}


public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarDRMult)
	{
		f_DRMult = StringToFloat(newValue);
	}
	else if(convar==cvarBaseDmg)
	{
		f_BaseDmg = StringToFloat(newValue);
	}
	else if(convar==cvarFFMult)
	{
		f_FFMult = StringToFloat(newValue);
	}
	else if(convar==cvarRangeDist)
	{
		f_RangeDist = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_DRMult = GetConVarFloat(cvarDRMult);
	f_BaseDmg = GetConVarFloat(cvarBaseDmg);
	f_FFMult = GetConVarFloat(cvarFFMult);
	f_RangeDist = GetConVarFloat(cvarRangeDist);
	BeamTrail = PrecacheModel("sprites/laser.vmt", true);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		ResetHitNo(client);
		HasPerk[client] = false;
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
    RTD2_ObtainPerk("lonely") // create perk using unique token "mytoken"
        .SetName("Lonely") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/announcer_dec_missionbegins10s01.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, lonely, friendlyfire, aoe, damage, speed, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public Action:OnRoundChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new client=1; client<=MaxClients; client++)
	{
	    if(IsValidClient(client) && HasPerk[client])
		{
		    RTD2_Remove(client, RTDRemove_Custom, "The round has ended");
		}
	}
	return Plugin_Continue;
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		ResetHitNo(client);
		CreateTimer(0.5, Timer_AOE, GetClientUserId(client));
	}
	else
	{
		HasPerk[client]=false;
	}
}

public Action:Timer_AOE(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && HasPerk[client])
	{
		if(GetClientTeam(client) >= 2)
		{
			new Float:clientPosition[3];
			new Float:targetPosition[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", clientPosition);
			if(!IsCloaked(client))
			{
				if (GetDisguiseTeam(client) == GetClientTeam(client) || GetDisguiseTeam(client) == 0)
				{
					new colour[4];
					if(GetClientTeam(client)==2)
					{
						colour[0] = 255;
						colour[1] = 45;
						colour[2] = 45;
						colour[3] = 255;
					}
					else
					{
						colour[0] = 45;
						colour[1] = 45;
						colour[2] = 255;
						colour[3] = 255;
					}
					clientPosition[2]+=25.0;
					EmitRing(clientPosition,  colour, f_RangeDist*1.25);
					clientPosition[2]+=45.0; //this is unoptimized, fight me
				}
				else
				{
					clientPosition[2]+=70.0; //this is unoptimized, fight me
				}
			}
			clientPosition[2]+=GetEntPropFloat(client, Prop_Send, "m_flModelScale")*40.0;
			for(new target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && IsPlayerAlive(target) && target != client)
				{
					GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetPosition);
					targetPosition[2]+=GetEntPropFloat(target, Prop_Send, "m_flModelScale")*40.0;
					if(GetVectorDistance(clientPosition, targetPosition)<=f_RangeDist && InClearView(clientPosition, targetPosition, target))
					{
						if (GetClientTeam(client)==GetClientTeam(target))
						{
							DamageEntity(target, target, (f_BaseDmg+(clienthitno[client][target]*f_DRMult)*f_FFMult), DMG_SLASH);
							TF2_AddCondition(target, TFCond_SpeedBuffAlly, 1.5, client);
						}
						else
						{
							DamageEntity(target, client, f_BaseDmg+(clienthitno[client][target]*f_DRMult), DMG_SLASH);
							TF2_AddCondition(target, TFCond_SpeedBuffAlly, 1.5, client);
						}
						clienthitno[client][target] += 1;
					}
					else
					{
						if (clienthitno[client][target] > 0)
						{
							clienthitno[client][target] -= 2;
							if (clienthitno[client][target] < 0)
							{
								clienthitno[client][target] = 0;
							}
						}
					}
				}
				else if(IsValidClient(target) && !IsPlayerAlive(target))
				{
					clienthitno[client][target] = 0;
				}
			}
			CreateTimer(0.5, Timer_AOE, GetClientUserId(client));
		}
		else
		{
			RTD2_Remove(client, RTDRemove_Custom, "No longer on a playable team");
		}
	}
}

//Not mine (obviously), pretty sure it's from war3source
//Why don't I just use sdktools' takedamage? Well because that means other plugins can't use sdkhooks to modify the damage this plugin inflicts (this is just more plugin friendly)
DamageEntity(client, attacker = 0, Float:dmg, dmg_type = DMG_GENERIC)
{
	if(IsValidClient(client) || IsValidEntity(client))
	{
		new damage = RoundToNearest(dmg);
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(client,"targetname","targetsname_lonely");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_lonely");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			DispatchKeyValue(pointHurt,"classname", "");
			DispatchSpawn(pointHurt);
			if(IsValidEntity(attacker))
			{
			    new Float:AttackLocation[3];
		        GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", AttackLocation);
				TeleportEntity(pointHurt, AttackLocation, NULL_VECTOR, NULL_VECTOR);
			}
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

EmitRing(Float:positionvec[3], colour[4], Float:distance)
{
	TE_SetupBeamRingPoint(positionvec, 10.0, distance, BeamTrail, BeamTrail, 0, 10, 0.5, 12.0, 0.0, colour, 0, FBEAM_FADEOUT);
	TE_SendToAll();
}

ResetHitNo(client)
{
	for(new target=1; target<=MaxClients; target++)
	{
		clienthitno[client][target] = 0;
	}
}

stock bool:InClearView(Float:pos2[3], Float:pos[3], entity)
{
    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilterThroughNpc, entity);
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace))//if there's an obstruction
		{
		    CloseHandle(hTrace);
		    return false;
		}
		else//if there isn't a wall between them
		{
			CloseHandle(hTrace);
			return true;
		}
	}
	return false;
}

stock bool:TraceFilterThroughNpc(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidClient(entity))
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:entname[256];
		GetEntityClassname(entity, entname, sizeof(entname));
		if(StrEqual(entname, "tank_boss", false) || StrEqual(entname, "tf_zombie", false) || StrEqual(entname, "tf_robot_destruction_robot", false) || StrEqual(entname, "merasmus", false) || StrEqual(entname, "headless_hatman", false) || StrEqual(entname, "eyeball_boss", false))
		{
			return false;
		}
		else if(StrEqual(entname, "obj_sentrygun", false) || StrEqual(entname, "obj_dispenser", false) || StrEqual(entname, "obj_teleporter", false))
		{
			return false;
		}
		else if(StrContains(entname, "tf_projectile")>=0)
		{
			return false;
		}
	}
	return true;
}

stock GetDisguiseTeam(client)
{
    if(IsValidClient(client))
	{
	    if(TF2_IsPlayerInCondition(client, TFCond_Disguised)) //actually has the disguise condition
	    {
		    return GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
	    }
	}
	return 0;
}

stock bool:IsCloaked(client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) //if a spy is cloaked
	{
		return true;
	}
	else if(TF2_IsPlayerInCondition(client, TFCond_Stealthed)) //player is using the cloak spell
	{
		return true;
	}
	else if(TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade)) //player is using the cloak spell
	{
		return true;
	}
	else
	{
	    return false;
	}
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