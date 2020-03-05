#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>
#include <tf2attributes>


new bool:HasPerk[MAXPLAYERS+1];

#define	MAX_EDICT_BITS	11
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

//timer to prevent picking up money
new Float:DoshSafeTime[MAX_EDICTS];
new Float:LastDeath; //tracks the time since someone died into an explosion of money
//this is to reduce the amount of money that spawns on death to avoid spam/lag

public Plugin myinfo = 
{
	name = "RTD2 Hedgehog Mode",
	author = "kking117",
	description = "Adds the positive perk Hedgehog Mode to rtd2."
};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public void OnMapStart()
{
	LastDeath=0.0;
	PrecacheSound("mvm/mvm_money_pickup.wav", true);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo); 
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
    RTD2_ObtainPerk("hedgehog") // create perk using unique token "mytoken"
        .SetName("Hedgehog Mode") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/scout_invinciblechgunderfire02.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, fast, hedgehog, blue, money, dosh, dollarydoos, melee, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		TF2Attrib_SetByName(client, "damage force increase hidden", 1.4);
		TF2Attrib_SetByName(client, "increased jump height from weapon", 1.3);
		TF2Attrib_SetByName(client, "SET BONUS: move speed set bonus", 1.4);
		SetEntityRenderColor(client, 128, 255, 192, 255);
		ForceWeaponSlot(client, 2);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
	}
	else
	{
		HasPerk[client]=false;
		SetEntityRenderColor(client, 255, 255, 255, 255);
		TF2Attrib_RemoveByName(client, "SET BONUS: move speed set bonus");
		TF2Attrib_RemoveByName(client, "increased jump height from weapon");
		TF2Attrib_RemoveByName(client, "damage force increase hidden");
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		CreateTimer(0.05, Timer_DoshDeath, GetClientUserId(client));
	}
}

public Action:Timer_DoshDeath(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && GetClientTeam(client)>1 && !IsPlayerAlive(client))
	{
		if(LastDeath<=GetGameTime())
		{
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
			CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		}
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		CreateTimer(GetRandomFloat(0.05, 0.5), Timer_DoshDeathSpawn, GetClientUserId(client));
		LastDeath=GetGameTime()+15.5;
	}
}

public Action:Timer_DoshDeathSpawn(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && !IsPlayerAlive(client))
	{
		DropCash(client, GetRandomInt(0, 2), true);
	}
}

public Action:Event_MoneyTouch(entity, toucher)
{
	if(IsValidEntity(entity))
	{
	    if(IsValidClient(toucher) && DoshSafeTime[entity]>GetGameTime())
		{
			SDKHook(entity, SDKHook_Touch, OnTouch_Money);
		    return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:OnTouch_Money(entity, toucher)
{
	if(IsValidEntity(entity))
	{
	    if(IsValidClient(toucher) && DoshSafeTime[entity]>GetGameTime())
		{
		    return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:Hook_WeaponCanSwitchTo(client, weapon) 
{ 
    if(HasPerk[client])
	{
		if(weapon!=GetPlayerWeaponSlot(client, 2))
		{
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
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

public Action:OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new damage=GetEventInt(event, "damageamount");
	if(HasPerk[client])
	{
		if(damage>90)
		{
			DropCash(client, 2, true);
		}
		else if(damage>45)
		{
			DropCash(client, 1, true);
		}
		else
		{
			DropCash(client, 0, true);
		}
	}
}

public Action:Timer_KillMoney(Handle:timer, entity)
{
	entity = EntRefToEntIndex(entity);
	if(IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
		DoshSafeTime[entity]=0.0; //clean up so shit doesn't get werid
	}
}

DropCash(client, size, bool:usesound)
{
	if(IsValidClient(client))
	{
		new Float:clientloc[3];
		new Float:velocity[3];
		GetClientEyePosition(client, clientloc);
		new Money;
		switch(size)
		{
			case 0:
			{
				Money = CreateEntityByName("item_currencypack_small");
			}
			case 1:
			{
				Money = CreateEntityByName("item_currencypack_medium");
			}
			case 2:
			{
				Money = CreateEntityByName("item_currencypack_large");
			}
		}
		velocity[0] = GetRandomFloat(-300.0, 300.0);
		velocity[1] = GetRandomFloat(-300.0, 300.0);
		velocity[2] = GetRandomFloat(500.0, 700.0);
		DoshSafeTime[Money] = GetGameTime()+3.0;
		CreateTimer(15.0, Timer_KillMoney, EntIndexToEntRef(Money));
		DispatchSpawn(Money);
		SDKHook(Money, SDKHook_StartTouch, Event_MoneyTouch);
		SetEntityMoveType(Money, MOVETYPE_STEP);
		TeleportEntity(Money, clientloc, NULL_VECTOR, velocity);
		if(usesound)
		{
			EmitSoundToAll("mvm/mvm_money_pickup.wav", client, _, _, _, _, _);
		}
	}
}

ForceWeaponSlot(client, slot)
{
	new weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
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