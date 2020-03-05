#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

#define SND_ENGI_ROLL "vo/engineer_no03.mp3"
#define SND_SPY_BACK "vo/spy_tietaunt01.mp3"

new bool:HasPerk[MAXPLAYERS+1];
new TFClassType:OGClass[MAXPLAYERS+1]; //the clients original class before transforming
new TFClassType:NewClass[MAXPLAYERS+1]; //the clients new class

new TransHp[MAXPLAYERS+1];
new TransHpMax[MAXPLAYERS+1];

new Handle:cvarSCBuild;
new i_SCBuild = 4;

public Plugin myinfo = 
{
	name = "RTD2 Swapped Class",
	author = "kking117",
	description = "Adds the positive perk Swapped Class to rtd2."
};

public void OnPluginStart()
{
	cvarSCBuild=CreateConVar("rtd_swapped_build", "4", "Destroy these buildings when switching back from Engineer. (Add the numbers together for the desired effect(s)) (1 = sentryguns, 2 = dispensers, 4 = teleporters)", _, true, 0.0, true, 7.0);
	HookConVarChange(cvarSCBuild, CvarChange);
	
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarSCBuild)
	{
		i_SCBuild = StringToInt(newValue);
	}
}

public void OnMapStart()
{
	i_SCBuild = GetConVarInt(cvarSCBuild);
	PrecacheSound(SND_ENGI_ROLL, true);
	PrecacheSound(SND_SPY_BACK, true);
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
    RTD2_ObtainPerk("swapclass") // create perk using unique token "mytoken"
        .SetName("Swapped Class") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("player/spy_disguise.wav") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, swap, class, swapped, switched") // set perk's search tags
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
		TF2_RemoveCondition(client, TFCond_Slowed);
		TF2_RemoveCondition(client, TFCond_Taunting);
		TF2_AddCondition(client, TFCond_TeleportedGlow, 2.0, client);
		OGClass[client] = TF2_GetPlayerClass(client);
		new randarray[8];
		new arrayloop = 0;
		for(new class=1; arrayloop<=7; class++)
		{
			if(TFClassType:class != OGClass[client])
			{
				randarray[arrayloop] = class;
				arrayloop+=1;
			}
		}
		NewClass[client] = TFClassType:randarray[GetRandomInt(0, 7)];
		TransHp[client] = GetEntProp(client, Prop_Send, "m_iHealth");
		TransHpMax[client] = GetClientMaxHealth(client);
		TF2_SetPlayerClass(client, NewClass[client], false, false);
		TF2_RegeneratePlayer(client);
		CreateTimer(0.5, Timer_ResponseTrans, GetClientUserId(client));
		CreateTimer(0.12, Timer_UpdateHealth, GetClientUserId(client));
		DestroyBuildings(client, false);
	}
	else
	{
		HasPerk[client]=false;
		if(IsPlayerAlive(client))
		{
			TF2_AddCondition(client, TFCond_TeleportedGlow, 2.0, client);
			if(TF2_GetPlayerClass(client)==TFClass_Engineer)
			{
				DestroyBuildings(client, true);
			}
			else
			{
				DestroyBuildings(client, false);
			}
			TF2_RemoveCondition(client, TFCond_Slowed);
			TF2_RemoveCondition(client, TFCond_Taunting);
			TransHp[client] = GetEntProp(client, Prop_Send, "m_iHealth");
			TransHpMax[client] = GetClientMaxHealth(client);
			TF2_SetPlayerClass(client, OGClass[client], false, false);
			TF2_RegeneratePlayer(client);
			CreateTimer(0.12, Timer_UpdateHealth, GetClientUserId(client));
			CreateTimer(0.5, Timer_ResponseBack, GetClientUserId(client));
			
		}
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

public Action:Timer_ResponseBack(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		VoiceLine(client, OGClass[client], false);
	}
}

public Action:Timer_ResponseTrans(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		VoiceLine(client, NewClass[client], true);
	}
}

VoiceLine(client, TFClassType:class, bool:Rolled)
{
	switch(class)
	{
		case TFClass_Scout:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/scout_sf13_magic_reac03.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/scout_mvm_resurrect07.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Soldier:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/soldier_negativevocalization04.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/soldier_mvm_resurrect03.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Pyro:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/pyro_negativevocalization01.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/pyro_laughevil02.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_DemoMan:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/demoman_jeers06.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/demoman_gibberish12.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Heavy:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/heavy_jeers03.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/heavy_mvm_resurrect04.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Engineer:
		{
			if(Rolled)
			{
				EmitSoundToAll(SND_ENGI_ROLL, client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/engineer_battlecry07.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Medic:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/medic_negativevocalization04.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/medic_item_secop_idle02.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Sniper:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/sniper_negativevocalization07.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll("vo/sniper_negativevocalization02.mp3", client, SNDCHAN_VOICE);
			}
		}
		case TFClass_Spy:
		{
			if(Rolled)
			{
				EmitSoundToAll("vo/spy_negativevocalization04.mp3", client, SNDCHAN_VOICE);
			}
			else
			{
				EmitSoundToAll(SND_SPY_BACK, client, SNDCHAN_VOICE);
			}
		}
	}
}

stock GetClientMaxHealth(client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

DestroyBuildings(client, flags)
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(flags && (i_SCBuild & 1))
			{
				AcceptEntityInput(ent, "kill");
			}
			else
			{
				if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
				{
					AcceptEntityInput(ent, "kill");
				}
			}
		}
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(flags && (i_SCBuild & 2))
			{
				AcceptEntityInput(ent, "kill");
			}
			else
			{
				if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
				{
					AcceptEntityInput(ent, "kill");
				}
			}
		}
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
	{
		if(GetEntPropEnt(ent, Prop_Send, "m_hBuilder") == client)
		{
			if(flags && (i_SCBuild & 4))
			{
				AcceptEntityInput(ent, "kill");
			}
			else
			{
				if(GetEntProp(ent, Prop_Send, "m_bPlacing"))
				{
					AcceptEntityInput(ent, "kill");
				}
			}
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