#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

#define SND_QUACK1 "ambient_mp3/bumper_car_quack1.mp3"
#define SND_QUACK2 "ambient_mp3/bumper_car_quack2.mp3"
#define SND_QUACK3 "ambient_mp3/bumper_car_quack3.mp3"
#define SND_QUACK4 "ambient_mp3/bumper_car_quack4.mp3"
#define SND_QUACK5 "ambient_mp3/bumper_car_quack5.mp3"
#define SND_QUACK6 "ambient_mp3/bumper_car_quack9.mp3"
#define SND_QUACK7 "ambient_mp3/bumper_car_quack11.mp3"

new bool:HasPerk[MAXPLAYERS+1];
new Float:NextQuack[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "RTD2 Duck Walk",
	author = "kking117",
	description = "Adds the negative perk Duck Walk to rtd2."
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
	PrecacheSound(SND_QUACK1, true);
	PrecacheSound(SND_QUACK2, true);
	PrecacheSound(SND_QUACK3, true);
	PrecacheSound(SND_QUACK4, true);
	PrecacheSound(SND_QUACK5, true);
	PrecacheSound(SND_QUACK6, true);
	PrecacheSound(SND_QUACK7, true);
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
    RTD2_ObtainPerk("duckwalk") // create perk using unique token "mytoken"
        .SetName("Duck Walk") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("ambient_mp3/bumper_car_quack11.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, duck, walk, crouch, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		NextQuack[client]=GetGameTime()+GetRandomFloat(0.7, 1.1);
		PrintToChat(client, "Waddle waddle.");
	}
	else
	{
		HasPerk[client]=false;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(HasPerk[client])
	{
		buttons |= IN_DUCK;
		if(NextQuack[client]<=GetGameTime())
		{
			if(buttons & IN_FORWARD)
			{
				RandomDuckNoise(client);
			}
			else if(buttons & IN_BACK)
			{
				RandomDuckNoise(client);
			}
			if(buttons & IN_MOVELEFT)
			{
				RandomDuckNoise(client);
			}
			if(buttons & IN_MOVERIGHT)
			{
				RandomDuckNoise(client);
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

RandomDuckNoise(client)
{
	new pitch = GetRandomInt(89, 153);
	switch(GetRandomInt(0, 6))
	{
		case 0:
		{
			EmitSoundToAll(SND_QUACK1, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 1:
		{
			EmitSoundToAll(SND_QUACK2, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 2:
		{
			EmitSoundToAll(SND_QUACK3, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 3:
		{
			EmitSoundToAll(SND_QUACK4, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 4:
		{
			EmitSoundToAll(SND_QUACK5, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 5:
		{
			EmitSoundToAll(SND_QUACK6, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
		case 6:
		{
			EmitSoundToAll(SND_QUACK7, client, _, SNDLEVEL_SCREAMING, _, _, pitch);
		}
	}
	NextQuack[client]=GetGameTime()+GetRandomFloat(0.7, 1.1);
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