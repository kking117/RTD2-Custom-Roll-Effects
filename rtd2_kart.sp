#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new bool:HasPerk[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "RTD2 Kartify",
	author = "kking117",
	description = "Adds the positive perk Kartify to rtd2."
};

public void OnPluginStart()
{
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
    RTD2_ObtainPerk("kart") // create perk using unique token "mytoken"
        .SetName("Kartify") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/scout_battlecry03.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("kart, good, fast, speed, fun, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		EnableKart(client);
		PrintToChat(client, "Brum brum.");
	}
	else
	{
		HasPerk[client]=false;
		DisableKart(client);
	}
}

EnableKart(client)
{
	new Float:vAngles[3]; // original
	GetClientEyeAngles(client, vAngles);
	TF2_AddCondition(client, TFCond_HalloweenKart, TFCondDuration_Infinite, client);
	TeleportEntity(client, NULL_VECTOR, vAngles, NULL_VECTOR);
}

DisableKart(client)
{
	TF2_RemoveCondition(client, TFCond_HalloweenKart);
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