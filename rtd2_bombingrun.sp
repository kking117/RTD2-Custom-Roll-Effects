#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

#define SND_SHOOT			"weapons/grenade_launcher_shoot.wav"
#define SND_BLAST1		"weapons/pipe_bomb1.wav"
#define MDL_BOMB1		"models/weapons/w_models/w_stickybomb.mdl"

new bool:HasPerk[MAXPLAYERS+1];
new Float:NextGrenade[MAXPLAYERS+1];

new Handle:cvarBRCritRate;
new Float:f_BRCritRate = 10.0;
new Handle:cvarBRDmg;
new Float:f_BRDmg = 100.0;
new Handle:cvarBRRate;
new Float:f_BRRate = 0.1;
new Handle:cvarBRRadius;
new Float:f_BRRadius = 148.0;
new Handle:cvarBRMinForce;
new Float:f_BRMinForce = 300.0;
new Handle:cvarBRMaxForce;
new Float:f_BRMaxForce = 750.0;

new Handle:hTrace;

public Plugin myinfo = 
{
	name = "RTD2 Bombing Run",
	author = "kking117",
	description = "Adds the negative perk Bombing Run to RTD2."
};

public void OnPluginStart()
{
	cvarBRRadius=CreateConVar("rtd_bombing_radius", "148.0", "The blast radius that the bombs have.", _, true, 1.0, false, 1000.0);
	HookConVarChange(cvarBRRadius, CvarChange);
	
	cvarBRDmg=CreateConVar("rtd_bombing_dmg", "100.0", "The base damage the of the bombs.", _, true, 1.0, false, 1000.0);
	HookConVarChange(cvarBRDmg, CvarChange);
	
	cvarBRRate=CreateConVar("rtd_bombing_rate", "0.1", "The rate of which bombing run spawns bombs. (Please be sensible.)", _, true, 0.05, false, 1000.0);
	HookConVarChange(cvarBRRate, CvarChange);
	
	cvarBRCritRate=CreateConVar("rtd_bombing_crit", "10.0", "The chance that a bomb will spawn as a crit.", _, true, 0.0, true, 100.0);
	HookConVarChange(cvarBRCritRate, CvarChange);
	
	cvarBRMinForce=CreateConVar("rtd_bombing_minforce", "300.0", "The minimum velocity bombs will be launched from the player.", _, true, 0.0, false, 100.0);
	HookConVarChange(cvarBRMinForce, CvarChange);
	
	cvarBRMaxForce=CreateConVar("rtd_bombing_maxforce", "750.0", "The maximum velocity bombs will be launched from the player.", _, true, 0.0, false, 100.0);
	HookConVarChange(cvarBRMaxForce, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarBRRadius)
	{
	    f_BRRadius=StringToFloat(newValue);
	}
	else if(convar==cvarBRMinForce)
	{
	    f_BRMinForce=StringToFloat(newValue);
	}
	else if(convar==cvarBRMaxForce)
	{
	    f_BRMaxForce=StringToFloat(newValue);
	}
	else if(convar==cvarBRDmg)
	{
	    f_BRDmg=StringToFloat(newValue);
	}
	else if(convar==cvarBRRate)
	{
	    f_BRRate=StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_BRMinForce = GetConVarFloat(cvarBRMinForce);
	f_BRMaxForce = GetConVarFloat(cvarBRMaxForce);
	f_BRDmg = GetConVarFloat(cvarBRDmg);
	f_BRRate = GetConVarFloat(cvarBRRate);
	f_BRRadius = GetConVarFloat(cvarBRRadius);
	PrecacheSound(SND_SHOOT);
	PrecacheSound(SND_BLAST1);
	//PrecacheSound("vo/taunts/demoman_taunts11.mp3");
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
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
    RTD2_ObtainPerk("bombingrun") // create perk using unique token "mytoken"
        .SetName("Bombing Run") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/taunts/demoman_taunts11.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, bomb, bombing, run, grenade, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		NextGrenade[client]=GetGameTime()+f_BRRate;
		PrintToChat(client, "Your body is dripping grenades don't stay still for too long.");
	}
	else
	{
		HasPerk[client]=false;
	}
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

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			if(NextGrenade[client]<=GetGameTime())
			{
				new Float:location[3];
				new Float:velocity[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
				location[2]+=GetEntPropFloat(client, Prop_Send, "m_flModelScale")*35.0;
				new bool:crits = false;
				if(GetRandomInt(0, 1)==0)
				{
					velocity[0]=GetRandomFloat(f_BRMinForce, f_BRMaxForce);
				}
				else
				{
					velocity[0]=GetRandomFloat(f_BRMinForce, f_BRMaxForce)*-1.0;
				}
				if(GetRandomInt(0, 1)==0)
				{
					velocity[1]=GetRandomFloat(f_BRMinForce, f_BRMaxForce);
				}
				else
				{
					velocity[1]=GetRandomFloat(f_BRMinForce, f_BRMaxForce)*-1.0;
				}
				if(GetRandomInt(0, 1)==0)
				{
					velocity[2]=GetRandomFloat(f_BRMinForce, f_BRMaxForce);
				}
				else
				{
					velocity[2]=GetRandomFloat(f_BRMinForce, f_BRMaxForce)*-1.0;
				}
				if(f_BRCritRate>=GetRandomFloat(0.0, 100.0))
				{
					crits = true;
				}
				ShootGrenade(client, location, velocity, f_BRDmg, crits, MDL_BOMB1);
				EmitSoundToAll(SND_SHOOT, client);
				NextGrenade[client]=GetGameTime()+f_BRRate;
			}
		}
	}
}

ShootGrenade(owner, Float:location[3], Float:velocity[3], Float:damage, bool:Crit, String:modelname[])
{
	new proj = CreateEntityByName("tf_projectile_pipe");
	if(IsValidEntity(proj))
	{
		new iTeam = 0;
		if(IsValidClient(owner))
		{
			iTeam = GetClientTeam(owner);
		}
	    SetEntPropEnt(proj, Prop_Send, "m_hOwnerEntity", owner);
		SetEntPropFloat(proj, Prop_Send, "m_flDamage", damage); 
		if(Crit==true)
		{
		    SetEntProp(proj, Prop_Send, "m_bCritical", 1);
		}
	    SetEntProp(proj,    Prop_Send, "m_iTeamNum",     iTeam, 1);
	    SetEntProp(proj,    Prop_Send, "m_nSkin", (iTeam-2));
	
	    SetVariantInt(iTeam);
	    AcceptEntityInput(proj, "TeamNum", -1, -1, 0);
	    SetVariantInt(iTeam);
	    AcceptEntityInput(proj, "SetTeam", -1, -1, 0); 
		DispatchSpawn(proj);
		SDKHook(proj, SDKHook_StartTouch, OnGrenadeTouch);
		SetEntityModel(proj, modelname);
		
	    TeleportEntity(proj, location, NULL_VECTOR, velocity);
		CreateTimer(2.0, Timer_DetonateGrenade, EntIndexToEntRef(proj));
	}
}

public Action:OnGrenadeTouch(entity, toucher)
{
	if(IsValidClient(toucher))
	{
		if(!GetEntProp(entity, Prop_Send, "m_bTouched"))
		{
			new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if(IsValidClient(owner))
			{
				if(GetClientTeam(toucher)!=GetClientTeam(owner))
				{
					if(GetEntProp(entity, Prop_Send, "m_bCritical", 1))
					{
						ExplodeGrenade(owner, entity, toucher, 1310784, false, "ExplosionCore_MidAir");
					}
					else
					{
						ExplodeGrenade(owner, entity, toucher, 262208, false, "ExplosionCore_MidAir");
					}
				}
			}
			else
			{
				new String:entname[256];
				GetEntityClassname(toucher, entname, sizeof(entname));
				if(StrEqual(entname, "tank_boss", false) || StrEqual(entname, "tf_zombie", false) || StrEqual(entname, "tf_robot_destruction_robot", false) || StrEqual(entname, "merasmus", false) || StrEqual(entname, "headless_hatman", false) || StrEqual(entname, "eyeball_boss", false))
				{
					if(GetEntProp(entity, Prop_Send, "m_bCritical", 1))
					{
						ExplodeGrenade(owner, entity, toucher, 1310784, false, "ExplosionCore_MidAir");
					}
					else
					{
						ExplodeGrenade(owner, entity, toucher, 262208, false, "ExplosionCore_MidAir");
					}
				}
				else if(StrEqual(entname, "obj_sentrygun", false) || StrEqual(entname, "obj_dispenser", false) || StrEqual(entname, "obj_teleporter", false))
				{
					if(GetEntProp(entity, Prop_Send, "m_bCritical", 1))
					{
						ExplodeGrenade(owner, entity, toucher, 1310784, false, "ExplosionCore_MidAir");
					}
					else
					{
						ExplodeGrenade(owner, entity, toucher, 262208, false, "ExplosionCore_MidAir");
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

//crit
//1310784
//normie
//262208

public Action:Timer_DetonateGrenade(Handle:timer, any:entity1)
{
    new entity = EntRefToEntIndex(entity1);
	if(entity>0 && IsValidEntity(entity))
	{
		new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(GetEntProp(entity, Prop_Send, "m_bCritical", 1))
		{
			ExplodeGrenade(owner, entity, -1, 1310784, true, "ExplosionCore_MidAir");
		}
		else
		{
			ExplodeGrenade(owner, entity, -1, 262208, true, "ExplosionCore_MidAir");
		}
	}
}

public Action:ExplodeGrenade(owner, grenade, toucher, dmgbits, bool:effect, String:effectname[255])
{
    new team = 0;
	if(IsValidClient(owner))
	{
	    team = GetClientTeam(owner);
	}
	//get a few variables that we'll be using
	new Float:blastloc[3];
	new Float:basedmg = GetEntPropFloat(grenade, Prop_Send, "m_flDamage");
	GetEntPropVector(grenade, Prop_Data, "m_vecAbsOrigin", blastloc);
	//generate explosion effect
	if(effect)
	{
		new particle = CreateEntityByName("info_particle_system");
		if (IsValidEntity(particle))
		{
			TeleportEntity(particle, blastloc, NULL_VECTOR, NULL_VECTOR);
			DispatchKeyValue(particle, "effect_name", effectname);
			DispatchSpawn(particle);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			SetVariantString("OnUser1 !self:Kill::8:-1");
			AcceptEntityInput(particle, "AddOutput");
			AcceptEntityInput(particle, "FireUser1");
		}
	}
	EmitAmbientSound(SND_BLAST1, blastloc); //, _, SNDLEVEL_SCREAMING);
	///damages players
	new Float:iloc[3];
	new Float:curdmg = basedmg;
	for (new i = 1; i < MaxClients; i++)
    {
        if(IsValidClient(i))
        {
			if(IsPlayerAlive(i))
			{
				curdmg=basedmg;
				if(i==owner || GetClientTeam(i)!=team)
				{
					if(i==owner)
					{
						curdmg*0.75;
					}
					if(i==toucher)
					{
						DamageEntity(i, owner, curdmg, dmgbits);
					}
					else
					{
						GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", iloc);
						iloc[2]+=GetEntPropFloat(i, Prop_Send, "m_flModelScale")*35.0;
						if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
						{
							if(InClearView(blastloc, iloc, i))
							{
								BlastDmgEntity(owner, i, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
							}
						}
					}
				}
			}
		}
	}
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
	{
		if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*30.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
	}
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
	{
		if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*25.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
	}
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
	{
		if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*10.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
	}
	while ((ent = FindEntityByClassname(ent, "tf_zombie")) != -1)
    {
        if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*30.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
    }
	while ((ent = FindEntityByClassname(ent, "tank_boss")) != -1)
    {
        if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*80.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
    }
	while ((ent = FindEntityByClassname(ent, "headless_hatman")) != -1)
    {
		if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*60.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
    }
	while ((ent = FindEntityByClassname(ent, "monoculus")) != -1)
    {
        if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*60.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
    }
	while ((ent = FindEntityByClassname(ent, "merasmus")) != -1)
    {
        if(GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
		{
			if(ent==toucher)
			{
				DamageEntity(ent, owner, curdmg, dmgbits);
			}
			else
			{
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", iloc);
				iloc[2]+=GetEntPropFloat(ent, Prop_Send, "m_flModelScale")*60.0;
				if(GetVectorDistance(blastloc, iloc)<=f_BRRadius)
				{
					if(InClearView(blastloc, iloc, ent))
					{
						BlastDmgEntity(owner, ent, f_BRRadius, GetVectorDistance(blastloc, iloc), curdmg, dmgbits);
					}
				}
			}
		}
    }
	AcceptEntityInput(grenade, "kill");
}

BlastDmgEntity(owner, target, Float:radius, Float:dist, Float:dmg, dmgbits)
{
	dmg*=0.5+((dist/radius)*0.5);
	DamageEntity(target, owner, dmg, dmgbits);
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
			DispatchKeyValue(client,"targetname","targetsname_bombingrun");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_bombingrun");
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