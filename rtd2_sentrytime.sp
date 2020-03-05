#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>
#include <tf2attributes>

new Handle:hTrace;

new bool:HasPerk[MAXPLAYERS+1];
new SentryRef[MAXPLAYERS+1];
new Float:LastSentryLoc[MAXPLAYERS+1][3];
new Float:LastScale[MAXPLAYERS+1];
new TFClassType:OGClass[MAXPLAYERS+1];
new Float:DisguiseReturn[MAXPLAYERS+1];

new Float:PlayerVecMin[3] = {-24.0, -24.0, -24.0};
new Float:PlayerVecMax[3] = {24.0, 24.0, 24.0};

new Handle:cvarSentryLevel;
new i_SentryLevel = 3;
new Handle:cvarSentryHealth;
new Float:f_SentryHealth = 1.0;
new Handle:cvarSentryMode;
new i_SentryMode = 1;

public Plugin myinfo = 
{
	name = "RTD2 Sentreized",
	author = "kking117",
	description = "Adds the positive perk Sentreized to rtd2."
};

public void OnPluginStart()
{
	cvarSentryLevel=CreateConVar("rtd_sentrytime_level", "3.0", "The sentry's level. (1-3 = level 1-3, 4-5 = minisentry + disposable)", _, true, 1.0, true, 5.0);
	HookConVarChange(cvarSentryLevel, CvarChange);
	
	cvarSentryHealth=CreateConVar("rtd_sentrytime_health", "1.0", "The sentry's life multiplier (Disposable sentries always have 100 health).", _, true, 0.0, false, 99999.0);
	HookConVarChange(cvarSentryHealth, CvarChange);
	
	cvarSentryMode=CreateConVar("rtd_sentrytime_mode", "1.0", "If set to 1, the player dies if the sentry dies, otherwise it ends the roll early.", _, true, 0.0, false, 1.0);
	HookConVarChange(cvarSentryMode, CvarChange);
	
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
	if(convar==cvarSentryLevel)
	{
		i_SentryLevel = StringToInt(newValue);
	}
	else if(convar==cvarSentryHealth)
	{
		f_SentryHealth = StringToFloat(newValue);
	}
	else if(convar==cvarSentryMode)
	{
		i_SentryMode = StringToInt(newValue);
	}
}

public void OnMapStart()
{
	i_SentryLevel = GetConVarInt(cvarSentryLevel);
	f_SentryHealth = GetConVarFloat(cvarSentryHealth);
	i_SentryMode = GetConVarInt(cvarSentryMode);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
		SentryRef[client]=-1;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamagePost);
	HasPerk[client] = false;
	SentryRef[client]=-1;
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
    RTD2_ObtainPerk("sentreized") // create perk using unique token "mytoken"
        .SetName("Sentreized") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/engineer_autobuildingsentry01.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, sentry, sentrytime, transform, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		TF2_AddCondition(client, TFCond_PreventDeath);
		if(f_SentryHealth!=1.0)
		{
			TF2Attrib_SetByDefIndex(client, 286, view_as<float>(f_SentryHealth));
		}
		new Float:location[3];
		new Float:angles[3];
		new Float:velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
		GetClientEyeAngles(client, angles);
		angles[0]=0.0;
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		location[2]+=1.0;
		CreateSentry(client, location, angles, velocity, i_SentryLevel);
	}
	else
	{
		if(HasPerk[client])
		{
			if(i_SentryMode==1)
			{
				RemoveSentry(client, 2);
			}
			else
			{
				RemoveSentry(client, 4);
			}
		}
		HasPerk[client]=false;
		TF2_RemovePlayerDisguise(client);
		TF2_RemoveCondition(client, TFCond_PreventDeath);
		TF2_RemoveCondition(client, TFCond_StealthedUserBuffFade);
		TF2_RemoveCondition(client, TFCond_OnFire);
		TF2_RemoveCondition(client, TFCond_Bleeding);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		if(f_SentryHealth!=1.0)
		{
			TF2Attrib_RemoveByDefIndex(client, 286);
		}
		SetPlayerAlpha(client, 255);
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", LastScale[client]);
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetClientViewEntity(client, client);
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
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
				TF2_SetPlayerClass(client, OGClass[client], false, false);
				DisguiseReturn[client]=0.0;
			}
		}
	}
    if(HasPerk[client])
	{
		new entity = EntRefToEntIndex(SentryRef[client]);
		if(entity>0 && IsValidEntity(entity))
		{
			new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(IsValidEntity(weapon))
			{
				new String:classname[255];
				GetEntityClassname(weapon, classname, sizeof(classname));
				if(!StrEqual(classname, "tf_weapon_laser_pointer"))
				{
					buttons = buttons & ~IN_ATTACK;
					buttons = buttons & ~IN_ATTACK2;
				}
			}
			else
			{
				buttons = buttons & ~IN_ATTACK;
				buttons = buttons & ~IN_ATTACK2;
			}
			buttons = buttons & ~IN_ATTACK3;
			buttons |= IN_DUCK;
			SetEntProp(client, Prop_Send, "m_iHealth", 2);
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
			LastSentryLoc[client][0] = location[0];
			LastSentryLoc[client][1] = location[1];
			LastSentryLoc[client][2] = location[2];
			location[2]+=GetEntPropFloat(entity, Prop_Send, "m_flModelScale")*90.0;
			TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			if(i_SentryMode==1)
			{
				RemoveSentry(client, 0);
			}
			else
			{
				RemoveSentry(client, 1);
			}
		}
	}
}

public Action:OnTakeDamagePost(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			new entity = EntRefToEntIndex(SentryRef[client]);
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
		if(EntRefToEntIndex(SentryRef[client])==entity)
		{
			if(i_SentryMode==1)
			{
				RemoveSentry(client, 0);
			}
			else
			{
				RemoveSentry(client, 1);
			}
		}
	}
}

HealSentry(client, amount)
{
	new entity = EntRefToEntIndex(SentryRef[client]);
	if(entity>0 && IsValidEntity(entity))
	{
		SetVariantInt(amount);
		AcceptEntityInput(entity, "AddHealth");
	}
}

RemoveSentry(client, reason)
{
	HasPerk[client]=false;
	if(reason == 0)
	{
		FakeClientCommand(client, "explode");
	}
	else if(reason == 1)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client));
		RTD2_Remove(client, RTDRemove_Custom, "Sentry was destroyed");
	}
	else if(reason == 3)
	{
		RTD2_Remove(client, RTDRemove_Custom, "Sentry was deleted");
	}
	else if(reason == 4)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client));
	}
	new entity = EntRefToEntIndex(SentryRef[client]);
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
		SentryRef[client]=-1;
		if(reason == 2)
		{
			new senthealth = GetEntProp(entity, Prop_Send, "m_iHealth");
			if(senthealth>GetClientMaxHealth(client))
			{
				SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client));
			}
			else if(senthealth>0)
			{
				SetEntProp(client, Prop_Send, "m_iHealth", senthealth);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_iHealth", 1);
			}
		}
		AcceptEntityInput(entity, "kill");
	}
	else
	{
		LastSentryLoc[client][2]+=1.0;
		TeleportEntity(client, LastSentryLoc[client], NULL_VECTOR, NULL_VECTOR);
	}
}

CreateSentry(client, Float:location[3], Float:angles[3], Float:velocity[3], level)
{
	new entity = CreateEntityByName("obj_sentrygun");
	if(IsValidEntity(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
		SetVariantInt(GetClientTeam(client));
		AcceptEntityInput(entity, "SetTeam");
		
		TeleportEntity(entity, location, angles, velocity);
		AcceptEntityInput(entity, "SetBuilder", client);
		//SetEntProp(entity, Prop_Data, "m_nDefaultUpgradeLevel", 0);
		switch(level)
		{
			case 1, 2, 3:
			{
				SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
				SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
				SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client)-2);
			}
			case 4:
			{
				SetEntProp(entity, Prop_Send, "m_bMiniBuilding", 1);
				SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", 1);
				SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", 1);
				SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
				SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.75);
			}
			case 5:
			{
				SetEntProp(entity, Prop_Send, "m_bDisposableBuilding", 1);
				SetEntProp(entity, Prop_Send, "m_bMiniBuilding", 1);
				SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", 1);
				SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", 1);
				SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
				SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.6);
			}
		}
		SetEntProp(entity, Prop_Data, "m_spawnflags", 8);
		//2 : Invulnerable
		//4 : Upgradable
		//8 : Infinite Ammo
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);		//This is crucial
		DispatchSpawn(entity);
		
		OGClass[client]=TF2_GetPlayerClass(client);
		if(OGClass[client]!=TFClass_Spy)
		{
			TF2_SetPlayerClass(client, TFClass_Spy, false, false);
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
		
		SentryRef[client] = EntIndexToEntRef(entity);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetClientViewEntity(client, entity);
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		TF2_AddCondition(client, TFCond_StealthedUserBuffFade);
		
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