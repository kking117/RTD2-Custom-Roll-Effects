#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>


new bool:HasPerk[MAXPLAYERS+1];
new Float:NextPush[MAXPLAYERS+1];
new Float:WindyForce[MAXPLAYERS+1][3];

new Handle:cvarWMinForce;
new Float:f_WMinForce = 50.0;
new Handle:cvarWMaxForce;
new Float:f_WMaxForce = 250.0;

new Handle:cvarWScoutMult;
new Float:f_WScoutMult = 1.25;
new Handle:cvarWSoldierMult;
new Float:f_WSoldierMult = 0.8;
new Handle:cvarWPyroMult;
new Float:f_WPyroMult = 1.1;
new Handle:cvarWDemoMult;
new Float:f_WDemoMult = 0.9;
new Handle:cvarWHeavyMult;
new Float:f_WHeavyMult = 0.7;
new Handle:cvarWEngineerMult;
new Float:f_WEngineerMult = 1.0;
new Handle:cvarWMedicMult;
new Float:f_WMedicMult = 1.0;
new Handle:cvarWSniperMult;
new Float:f_WSniperMult = 1.0;
new Handle:cvarWSpyMult;
new Float:f_WSpyMult = 1.1;


public Plugin myinfo = 
{
	name = "RTD2 Windy",
	author = "kking117",
	description = "Adds the negative perk Windy to rtd2."
};

public void OnPluginStart()
{
	cvarWMinForce=CreateConVar("rtd_windy_minforce", "50.0", "The minimum push force windy can appply.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWMinForce, CvarChange);
	
	cvarWMaxForce=CreateConVar("rtd_windy_maxforce", "275.0", "The maximum push force windy can appply.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWMaxForce, CvarChange);
	
	cvarWScoutMult=CreateConVar("rtd_windy_scout_mult", "1.25", "Windy force multiplier for Scouts.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWScoutMult, CvarChange);
	
	cvarWSoldierMult=CreateConVar("rtd_windy_soldier_mult", "0.8", "Windy force multiplier for Soldiers.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWSoldierMult, CvarChange);
	
	cvarWPyroMult=CreateConVar("rtd_windy_pyro_mult", "1.1", "Windy force multiplier for Pyros.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWPyroMult, CvarChange);
	
	cvarWDemoMult=CreateConVar("rtd_windy_demo_mult", "0.9", "Windy force multiplier for Demomen.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWDemoMult, CvarChange);
	
	cvarWHeavyMult=CreateConVar("rtd_windy_heavy_mult", "0.7", "Windy force multiplier for Heavy.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWHeavyMult, CvarChange);
	
	cvarWEngineerMult=CreateConVar("rtd_windy_engineer_mult", "1.0", "Windy force multiplier for Engineer.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWEngineerMult, CvarChange);
	
	cvarWMedicMult=CreateConVar("rtd_windy_medic_mult", "1.0", "Windy force multiplier for Medic.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWMedicMult, CvarChange);
	
	cvarWSniperMult=CreateConVar("rtd_windy_sniper_mult", "1.0", "Windy force multiplier for Sniper.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWSniperMult, CvarChange);
	
	cvarWSpyMult=CreateConVar("rtd_windy_spy_mult", "1.1", "Windy force multiplier for Spy.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarWSpyMult, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarWMinForce)
	{
		f_WMinForce = StringToFloat(newValue);
	}
	else if(convar==cvarWMaxForce)
	{
		f_WMaxForce = StringToFloat(newValue);
	}
	else if(convar==cvarWScoutMult)
	{
		f_WScoutMult = StringToFloat(newValue);
	}
	else if(convar==cvarWSoldierMult)
	{
		f_WSoldierMult = StringToFloat(newValue);
	}
	else if(convar==cvarWPyroMult)
	{
		f_WPyroMult = StringToFloat(newValue);
	}
	else if(convar==cvarWDemoMult)
	{
		f_WDemoMult = StringToFloat(newValue);
	}
	else if(convar==cvarWHeavyMult)
	{
		f_WHeavyMult = StringToFloat(newValue);
	}
	else if(convar==cvarWEngineerMult)
	{
		f_WEngineerMult = StringToFloat(newValue);
	}
	else if(convar==cvarWMedicMult)
	{
		f_WMedicMult = StringToFloat(newValue);
	}
	else if(convar==cvarWSniperMult)
	{
		f_WSniperMult = StringToFloat(newValue);
	}
	else if(convar==cvarWSpyMult)
	{
		f_WSpyMult = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_WMaxForce = GetConVarFloat(cvarWMaxForce);
	f_WMinForce = GetConVarFloat(cvarWMinForce);
	f_WScoutMult = GetConVarFloat(cvarWScoutMult);
	f_WSoldierMult = GetConVarFloat(cvarWSoldierMult);
	f_WPyroMult = GetConVarFloat(cvarWPyroMult);
	f_WDemoMult = GetConVarFloat(cvarWDemoMult);
	f_WHeavyMult = GetConVarFloat(cvarWHeavyMult);
	f_WEngineerMult = GetConVarFloat(cvarWEngineerMult);
	f_WMedicMult = GetConVarFloat(cvarWMedicMult);
	f_WSniperMult = GetConVarFloat(cvarWSniperMult);
	f_WSpyMult = GetConVarFloat(cvarWSpyMult);
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
    RTD2_ObtainPerk("windy") // create perk using unique token "mytoken"
        .SetName("Windy") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("ambient_mp3/hallow02.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, windy, wind, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		NextPush[client]=GetGameTime()+0.1;
		if(GetRandomInt(0, 1)==0)
		{
			WindyForce[client][0]=GetRandomFloat(f_WMinForce, f_WMaxForce);
		}
		else
		{
			WindyForce[client][0]=GetRandomFloat(f_WMinForce, f_WMaxForce)*-1.0;
		}
		if(GetRandomInt(0, 1)==0)
		{
			WindyForce[client][1]=GetRandomFloat(f_WMinForce, f_WMaxForce);
		}
		else
		{
			WindyForce[client][1]=GetRandomFloat(f_WMinForce, f_WMaxForce)*-1.0;
		}
		if(GetRandomInt(0, 1)==0)
		{
			WindyForce[client][2]=GetRandomFloat(f_WMinForce, f_WMaxForce);
		}
		else
		{
			WindyForce[client][2]=GetRandomFloat(f_WMinForce, f_WMaxForce)*-1.0;
		}
		PrintToChat(client, "Watch your step!");
	}
	else
	{
		HasPerk[client]=false;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.5);
			if(NextPush[client]<=GetGameTime())
			{
				new Float:velocity[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity); //velocity
				new Float:multforce=1.0;
				switch(TF2_GetPlayerClass(client))
				{
					case TFClass_Scout:
					{
						multforce=f_WScoutMult;
					}
					case TFClass_Soldier:
					{
						multforce=f_WSoldierMult;
					}
					case TFClass_Pyro:
					{
						multforce=f_WPyroMult;
					}
					case TFClass_DemoMan:
					{
						multforce=f_WDemoMult;
					}
					case TFClass_Heavy:
					{
						multforce=f_WHeavyMult;
					}
					case TFClass_Engineer:
					{
						multforce=f_WEngineerMult;
					}
					case TFClass_Medic:
					{
						multforce=f_WMedicMult;
					}
					case TFClass_Sniper:
					{
						multforce=f_WSniperMult;
					}
					case TFClass_Spy:
					{
						multforce=f_WSpyMult;
					}
				}
				if(GetEntityFlags(client) & FL_ONGROUND)
				{
					velocity[0]+=WindyForce[client][0]*multforce;
					velocity[1]+=WindyForce[client][1]*multforce;
					velocity[2]+=WindyForce[client][2]*multforce;
				}
				else
				{
					velocity[0]+=(WindyForce[client][0]*0.35)*multforce;
					velocity[1]+=(WindyForce[client][0]*0.35)*multforce;
					velocity[2]+=(WindyForce[client][0]*0.35)*multforce;
				}
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
				NextPush[client]=GetGameTime()+0.1;
			}
		}
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