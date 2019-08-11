#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new Handle:SwitchHUD;

new TransHp[MAXPLAYERS+1];
new TransHpMax[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "RTD2 Switcheroo",
	author = "kking117",
	description = "Adds the positive perk Switcheroo to rtd2."
};

public void OnPluginStart()
{
	SwitchHUD=CreateHudSynchronizer();
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public void OnMapStart()
{
	PrecacheSound("vo/halloween_merasmus/sf12_found05.mp3", true);
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
    RTD2_ObtainPerk("switcheroo") // create perk using unique token "mytoken"
        .SetName("Switcheroo") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(-1)
        .SetSound("vo/halloween_merasmus/sf12_found05.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, swap, switch, teleport, notimer") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		TF2_RemoveCondition(client, TFCond_Slowed);
		TF2_RemoveCondition(client, TFCond_Taunting);
		new target = GetRandomClient(client, GetClientTeam(client));
		if(IsValidClient(target))
		{
			TF2_RemoveCondition(target, TFCond_Slowed);
			TF2_RemoveCondition(target, TFCond_Taunting);
			new Float:clientloc[3];
			new Float:clientvel[3];
			new Float:clientang[3];
			new Float:targetloc[3];
			new Float:targetvel[3];
			new Float:targetang[3];
			new TFClassType:clientcla = TF2_GetPlayerClass(client);
			new TFClassType:targetcla = TF2_GetPlayerClass(target);
			new clienthp = GetEntProp(client, Prop_Send, "m_iHealth");
			new targethp = GetEntProp(target, Prop_Send, "m_iHealth");
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", clientloc);
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientvel);
			GetEntPropVector(client, Prop_Data, "m_angRotation", clientang);
			GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetloc);
			GetEntPropVector(target, Prop_Data, "m_vecVelocity", targetvel);
			GetEntPropVector(target, Prop_Data, "m_angRotation", targetang);
			TeleportEntity(client, targetloc, targetvel, targetang);
			TeleportEntity(target, clientloc, clientvel, clientang);
			DestroyBuildings(client);
			TF2_SetPlayerClass(client, targetcla);
			TF2_RegeneratePlayer(client);
			DestroyBuildings(target);
			TF2_SetPlayerClass(target, clientcla);
			TF2_RegeneratePlayer(target);
			TF2_AddCondition(client, TFCond_TeleportedGlow, 2.5, client);
			TF2_AddCondition(target, TFCond_TeleportedGlow, 2.5, target);
			SetEntProp(client, Prop_Send, "m_iHealth", targethp);
			SetEntProp(target, Prop_Send, "m_iHealth", clienthp);
			new String:username[60];
			GetClientName(target, username, sizeof(username));
			SetHudTextParams(-1.0, 0.43, 4.0, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
			ShowSyncHudText(client, SwitchHUD, "Swapped places with %s!", username);
			PrintToChat(client, "You've swapped places and class with %s.", username);
			GetClientName(client, username, sizeof(username));
			SetHudTextParams(-1.0, 0.43, 4.0, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
			ShowSyncHudText(target, SwitchHUD, "Swapped places with %s!", username);
			EmitSoundToAll("vo/halloween_merasmus/sf12_found05.mp3", target);
		}
		else
		{
			new randarray[8];
			new arrayloop = 0;
			for(new class=1; arrayloop<=7; class++)
			{
				if(TFClassType:class != TF2_GetPlayerClass(client))
				{
					randarray[arrayloop] = class;
					arrayloop+=1;
				}
			}
			TransHp[client] = GetEntProp(client, Prop_Send, "m_iHealth");
			TransHpMax[client] = GetClientMaxHealth(client);
			TF2_SetPlayerClass(client, TFClassType:randarray[GetRandomInt(0, 7)]);
			TF2_RegeneratePlayer(client);
			PrintToChat(client, "You've swapped classes.");
			CreateTimer(0.12, Timer_UpdateHealth, GetClientUserId(client));
		}
	}
	else
	{
	}
}

public Action:Timer_UpdateHealth(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		new newmaxhp = GetClientMaxHealth(client);
		new Float:newhealth = ((newmaxhp*1.0)/(TransHpMax[client]*1.0));
		SetEntProp(client, Prop_Send, "m_iHealth", RoundToNearest(TransHp[client]*newhealth));
	}
}

GetRandomClient(client, team)
{
	new clients[32];
	new count=-1;
	for(new i = 0; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(IsPlayerAlive(i) && i!=client)
			{
				if(team>1)
				{
					if(GetClientTeam(i)==team)
					{
						count+=1;
						clients[count]=i;
						
					}
				}
				else
				{
					count+=1;
					clients[count]=i;
				}
			}
		}
	}
	if(count>-1)
	{
		return clients[GetRandomInt(0, count)];
	}
	else
	{
		return -1;
	}
}

DestroyBuildings(client)
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
			{
				AcceptEntityInput(ent, "kill");
			}
		}
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
			{
				AcceptEntityInput(ent, "kill");
			}
		}
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
			{
				AcceptEntityInput(ent, "kill");
			}
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