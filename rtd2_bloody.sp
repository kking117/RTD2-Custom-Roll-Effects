#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new bool:HasPerk[MAXPLAYERS+1];

new Handle:cvarBDmgMult;
new Float:f_BDmgMult = 2.0;

public Plugin myinfo = 
{
	name = "RTD2 Bloody",
	author = "kking117",
	description = "Adds the positive perk Bloody to rtd2."
};

public void OnPluginStart()
{
	cvarBDmgMult=CreateConVar("rtd_bloody_dmg_mult", "2.0", "Bloody's damage multiplier.", _, true, 0.0, false, 9999.0);
	HookConVarChange(cvarBDmgMult, CvarChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarBDmgMult)
	{
		f_BDmgMult = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_BDmgMult = GetConVarFloat(cvarBDmgMult);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
	}
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamagePost);
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
    RTD2_ObtainPerk("bloody") // create perk using unique token "mytoken"
        .SetName("Bloody") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/demoman_autodejectedtie04.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, bleed, bleeding, blood, dot, damage, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
	}
	else
	{
		HasPerk[client]=false;
	}
}

public Action:OnTakeDamagePost(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(IsValidClient(attacker))
	{
		if(HasPerk[attacker])
		{
			if(!(damagetype & DMG_SLASH))
			{
				damage*=f_BDmgMult;
				if(damage>8.0)
				{
					
					if((damagetype & DMG_PREVENT_PHYSICS_FORCE) && (damagetype & DMG_BURN))
					{
					}
					else
					{
						TF2_MakeBleed(client, attacker, (damage-5.0)/8.0);
						damage=4.0;
						return Plugin_Changed;
					}
				}
			}
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