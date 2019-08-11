#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>
#include <tf2attributes>

new Handle:hTrace;

new bool:HasPerk[MAXPLAYERS+1];
new DispRef[MAXPLAYERS+1];
new Float:LastDspLoc[MAXPLAYERS+1][3];
new Float:LastScale[MAXPLAYERS+1];
new TFClassType:OGClass[MAXPLAYERS+1];
new Float:DisguiseReturn[MAXPLAYERS+1];

new Float:PlayerVecMin[3] = {-24.0, -24.0, -24.0};
new Float:PlayerVecMax[3] = {24.0, 24.0, 24.0};

new Handle:cvarDispLevel;
new i_DispLevel = 3;
new Handle:cvarDispHealth;
new Float:f_DispHealth = 1.0;

public Plugin myinfo = 
{
	name = "RTD2 Dispenserized",
	author = "kking117",
	description = "Adds the positive perk Dispenserized to rtd2."
};

public void OnPluginStart()
{
	cvarDispLevel=CreateConVar("rtd_dispensertime_level", "3.0", "The dispenser's level. (1-3 = level 1-3)", _, true, 1.0, true, 3.0);
	HookConVarChange(cvarDispLevel, CvarChange);
	
	cvarDispHealth=CreateConVar("rtd_dispensertime_health", "1.0", "The dispenser's life multiplier (Disposable sentries always have 100 health).", _, true, 0.0, false, 99999.0);
	HookConVarChange(cvarDispHealth, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	HookEvent("object_destroyed", OnBuildDestroy, EventHookMode_Post);
	HookEvent("player_healed", OnPlayerHeal, EventHookMode_Pre);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarDispLevel)
	{
		i_DispLevel = StringToInt(newValue);
	}
	else if(convar==cvarDispHealth)
	{
		f_DispHealth = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	i_DispLevel = GetConVarInt(cvarDispLevel);
	f_DispHealth = GetConVarFloat(cvarDispHealth);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
		DispRef[client]=-1;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamagePost);
	HasPerk[client] = false;
	DispRef[client]=-1;
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
    RTD2_ObtainPerk("dispenserized") // create perk using unique token "mytoken"
        .SetName("Dispenserized") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/engineer_autobuildingdispenser02.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, dispenser, dispensertime, disptime, transform, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		TF2_AddCondition(client, TFCond_PreventDeath);
		if(f_DispHealth!=1.0)
		{
			TF2Attrib_SetByDefIndex(client, 286, view_as<float>(f_DispHealth));
		}
		new Float:location[3];
		new Float:angles[3];
		new Float:velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
		GetClientEyeAngles(client, angles);
		angles[0]=0.0;
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		location[2]+=1.0;
		CreateDispenser(client, location, angles, velocity, i_DispLevel);
		PrintToChat(client, "You are the dispenser!");
	}
	else
	{
		HasPerk[client]=false;
		TF2_RemovePlayerDisguise(client);
		TF2_RemoveCondition(client, TFCond_PreventDeath);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		if(f_DispHealth!=1.0)
		{
			TF2Attrib_RemoveByDefIndex(client, 286);
		}
		SetPlayerAlpha(client, 255);
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", LastScale[client]);
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetClientViewEntity(client, client);
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
		RemoveDispenser(client, false);
	}
}

public Action:OnRoundChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new client=1; client<=MaxClients; client++)
	{
	    if(IsValidClient(client) && HasPerk[client])
		{
			DisguiseReturn[client]=0.0;
		    RTD2_Remove(client, RTDRemove_Custom, "The round has ended");
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerHeal(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "healer"));
	new target=GetClientOfUserId(GetEventInt(event, "patient"));
	new heals=GetEventInt(event, "amount");
	if(HasPerk[target])
	{
		SetEntProp(target, Prop_Send, "m_iHealth", GetClientMaxHealth(target)-(GetClientMaxHealth(target)-2));
		HealSentry(target, heals);
	}
}

public Action:OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	if(HasPerk[client])
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client)-(GetClientMaxHealth(client)-2));
		TF2_AddCondition(client, TFCond_PreventDeath);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsPlayerAlive(client))
	{
		if(DisguiseReturn[client]!=0.0)
		{
			if(DisguiseReturn[client]<=GetGameTime())
			{
				TF2_SetPlayerClass(client, OGClass[client]);
				DisguiseReturn[client]=0.0;
			}
		}
	}
    if(HasPerk[client])
	{
		new entity = EntRefToEntIndex(DispRef[client]);
		if(entity>0 && IsValidEntity(entity))
		{
			buttons = buttons & ~IN_ATTACK;
			buttons = buttons & ~IN_ATTACK2;
			buttons = buttons & ~IN_ATTACK3;
			buttons |= IN_DUCK;
			SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client)-(GetClientMaxHealth(client)-2));
			new Float:location[3];
			new Float:velocity[3];
			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", location);
			GetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);
			new Float:nextloc[3];
			nextloc[0]=location[0]+(velocity[0]*0.05);
			nextloc[1]=location[1]+(velocity[1]*0.05);
			nextloc[2]=location[2]+(velocity[2]*0.05);
			if(TraceHullCollidePlayerDef(location, nextloc, entity)) //, 1.0))
			{
				velocity[0]=0.0;
				velocity[1]=0.0;
				//velocity[2]=0.0;
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, velocity);
			}
			LastDspLoc[client][0] = location[0];
			LastDspLoc[client][1] = location[1];
			LastDspLoc[client][2] = location[2];
			location[2]+=GetEntPropFloat(entity, Prop_Send, "m_flModelScale")*90.0;
			TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			RTD2_Remove(client, RTDRemove_Custom, "Dispenser was deleted");
		}
	}
}

public Action:OnTakeDamagePost(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			new entity = EntRefToEntIndex(DispRef[client]);
			if(entity>0 && IsValidEntity(entity))
			{
				//pass afterburn and bleed to the sentry
				if((damagetype & DMG_PREVENT_PHYSICS_FORCE) && (damagetype & DMG_BURN))
				{
					if(client==attacker)
					{
						DamageEntity(entity, 0, damage, damagetype);
					}
					else
					{
						DamageEntity(entity, attacker, damage, damagetype);
					}
				}
				else if(damagetype & DMG_SLASH)
				{
					if(client==attacker)
					{
						DamageEntity(entity, 0, damage, damagetype);
					}
					else
					{
						DamageEntity(entity, attacker, damage, damagetype);
					}
				}
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnBuildDestroy(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new entity=GetEventInt(event, "index");
	if(IsValidClient(client))
	{
		if(EntRefToEntIndex(DispRef[client])==entity)
		{
			RemoveDispenser(client, true);
		}
	}
}

HealSentry(client, amount)
{
	new entity = EntRefToEntIndex(DispRef[client]);
	if(entity>0 && IsValidEntity(entity))
	{
		SetVariantInt(amount);
		AcceptEntityInput(entity, "AddHealth");
	}
}

RemoveDispenser(client, bool:SlayPlayer)
{
	new entity = EntRefToEntIndex(DispRef[client]);
	if(entity>0 && IsValidEntity(entity))
	{
		new Float:location[3];
		new Float:angles[3];
		new Float:velocity[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", location);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", angles); 
		GetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);
		location[2]+=1.0;
		TeleportEntity(client, location, angles, velocity);
		DispRef[client]=-1;
		if(SlayPlayer)
		{
			FakeClientCommand(client, "explode");
		}
		else
		{
			new disphealth = GetEntProp(entity, Prop_Send, "m_iHealth");
			if(disphealth>GetClientMaxHealth(client))
			{
				SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client));
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_iHealth", disphealth);
			}
		}
		AcceptEntityInput(entity, "kill");
	}
	else
	{
		LastDspLoc[client][2]+=1.0;
		TeleportEntity(client, LastDspLoc[client], NULL_VECTOR, NULL_VECTOR);
	}
}

CreateDispenser(client, Float:location[3], Float:angles[3], Float:velocity[3], level)
{
	new entity = CreateEntityByName("obj_dispenser");
	if(IsValidEntity(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
		SetVariantInt(GetClientTeam(client));
		AcceptEntityInput(entity, "SetTeam");
		
		TeleportEntity(entity, location, angles, velocity);
		AcceptEntityInput(entity, "SetBuilder", client);
		//SetEntProp(entity, Prop_Data, "m_nDefaultUpgradeLevel", 0);
		
		SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
		SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
		SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client)-2);
		
		SetEntProp(entity, Prop_Data, "m_spawnflags", 8);
		//2 : Invulnerable
		//4 : Upgradable
		//8 : Infinite Ammo
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);		//This is crucial
		DispatchSpawn(entity);
		
		
		DispRef[client] = EntIndexToEntRef(entity);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetClientViewEntity(client, entity);
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		
		OGClass[client]=TF2_GetPlayerClass(client);
		if(OGClass[client]!=TFClass_Spy)
		{
			TF2_SetPlayerClass(client, TFClass_Spy);
			DisguiseReturn[client]=GetGameTime()+1.75;
		}
		if(GetClientTeam(client)==3)
		{
			TF2_DisguisePlayer(client, 2, TFClass_Scout, client);
		}
		else
		{
			TF2_DisguisePlayer(client, 3, TFClass_Scout, client);
		}
		
		//TeleportEntity(entity, location, angles, velocity);
		location[2]+=GetEntPropFloat(entity, Prop_Send, "m_flModelScale")*90.0;
		LastScale[client] = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", 0.1);
		SetPlayerAlpha(client, 0);
		TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
	}
}

SetPlayerAlpha(client, amount)
{
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntData(client, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
	new weapon = 0;
	new i = 0;
	for(i = 0; i < 6; i++)
	{
		weapon = GetPlayerWeaponSlot(client, i);
		if(!IsValidClient(weapon) && IsValidEntity(weapon))
		{
			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntData(weapon, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
		}
	}
	i = 0;
	while ((i = FindEntityByClassname(i, "tf_wearabl*")) != -1)
	{ 
		if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
		{
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntData(i, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
		}
	}
	while ((i = FindEntityByClassname(i, "tf_powerup_bottle")) != -1)
	{ 
		if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
		{
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntData(i, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
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
			DispatchKeyValue(client,"targetname","targetsname_sentrytime");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_sentrytime");
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

stock GetClientMaxHealth(client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
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

stock bool:TraceHullCollidePlayerDef(Float:pos2[3], Float:pos[3], entity)
{
    //hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilter_NoNPCPLAYERPROJ, entity);
	//new Float:vecmaxs[3];
	//new Float:vecmins[3];
	//GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vecmaxs);
	//GetEntPropVector(entity, Prop_Send, "m_vecMins", vecmins);
	hTrace = TR_TraceHullFilterEx(pos2, pos, PlayerVecMin, PlayerVecMax, MASK_PLAYERSOLID, TraceFilter_NoNPCPLAYERPROJ, entity);
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace))//we hit something
		{
		    CloseHandle(hTrace);
		    return true;
		}
		else//we hit nothing man
		{
			CloseHandle(hTrace);
			return false;
		}
	}
	return false;
}

stock bool:TraceFilter_NoNPCPLAYERPROJ(entity, contentsMask, any:ent)
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
	    new String:ClassName[255];
		GetEntityClassname(entity, ClassName, sizeof(ClassName));
		if(!StrContains(ClassName, "obj_", false)) //buildings and sapper attatchments
		{
		    return false;
		}
		else if(!StrContains(ClassName, "_boss", false)) //monoculous and tank_boss
		{
		    return false;
		}
		else if(!StrContains(ClassName, "mera", false)) //MERASMUS
		{
		    return false;
		}
		else if(!StrContains(ClassName, "tf_zomb", false)) //tf2 skeletons
		{
		    return false;
		}
		else if(!StrContains(ClassName, "headless_hat", false)) //pumpkin boy
		{
		    return false;
		}
	}
	return true;
}