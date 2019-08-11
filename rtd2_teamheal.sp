#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new bool:HasPerk[MAXPLAYERS+1];
new LastHP[MAXPLAYERS+1]; //to keep track of last amount of hp (for getting the crusader's crossbow to play nice)

public Plugin myinfo = 
{
	name = "RTD2 Team Healing",
	author = "kking117",
	description = "Adds the positive perk Team Healing to rtd2."
};

public void OnPluginStart()
{
	HookEvent("player_healed", OnPlayerHeal, EventHookMode_Pre);
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public void OnMapStart()
{
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
    RTD2_ObtainPerk("teamheal") // create perk using unique token "mytoken"
        .SetName("Team Healing") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/medic_cheers06.mp3") // set activation sound
		.SetClasses("7") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, medic, medigun, healing, heal, teamhealing, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		PrintToChat(client, "Healing you deal is evenly distrubted to the entire team.");
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
    if(IsPlayerAlive(client))
	{
		LastHP[client] = GetEntProp(client, Prop_Send, "m_iHealth");
	}
	return Plugin_Continue;
}

public Action:OnPlayerHeal(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "healer"));
	new target=GetClientOfUserId(GetEventInt(event, "patient"));
	new heals=GetEventInt(event, "amount");
	if(HasPerk[client])
	{
		new teamno = 0;
		new i;
		new bool:medigunheal = false;
		new activewep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new String:weaponname[256];
		if(IsValidEntity(activewep))
		{
			GetEntityClassname(activewep, weaponname, sizeof(weaponname));
			if(StrEqual(weaponname, "tf_weapon_medigun", false))
			{
				if(GetEntPropEnt(activewep, Prop_Send, "m_hHealingTarget")==target)
				{
					medigunheal = true;
				}
			}
		}
		
		if(IsValidClient(target) && medigunheal)
		{
			HealClient(target, RoundToNearest(heals*-1.0), true);
		}
		
		for(i=0; i < MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(GetClientTeam(i)==GetClientTeam(client))
				{
					teamno+=1;
				}
			}
		}
		if(heals>teamno)
		{
			heals = RoundToNearest((heals*1.0)/(teamno*1.0));
			for(i=0; i < MaxClients; i++)
			{
				if(IsValidClient(i))
				{
					if(!medigunheal && i==target)
					{
						HealClient(target, (LastHP[i]-GetEntProp(i, Prop_Send, "m_iHealth"))+heals, true);
					}
					else if(GetClientTeam(i)==GetClientTeam(client))
					{
						HealClient(i, heals, true);
					}
				}
			}
		}
		else
		{
			for(i=0; i < MaxClients; i++)
			{
				if(IsValidClient(i))
				{
					if(!medigunheal && i==target)
					{
						HealClient(target, (LastHP[i]-GetEntProp(i, Prop_Send, "m_iHealth"))+1, true);
					}
					else if(GetClientTeam(i)==GetClientTeam(client))
					{
						HealClient(i, 1, true);
					}
				}
			}
		}
	}
}

stock HealClient(client, health, bool:OverHeal)
{
    if(!OverHeal && GetClientHealth(client)+health>GetClientMaxHealth(client))
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetClientMaxHealth(client));
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth")+health);
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