#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

//ghost_pumpkin
//ghost_pumpkin_flyingbits

#define DEF_EYES "eyes"
#define DEF_FOOT_L "foot_L"
#define DEF_FOOT_R "foot_R"
#define DEF_HAND_L "effect_hand_L"
#define DEF_HAND_R "effect_hand_R"
#define DEF_BACK_L "back_lower"

#define SCOUT_BACK_U "back_upper"

#define PYRO_EYES "head"
#define PYRO_BACK_U "flag"

#define ENGINEER_EYES "head"

#define MEDIC_BACK_U "flag"

#define SNIPER_BACK_U "flag"


#define SND_SCOUT_FIRE1 "vo/scout_autoonfire01.mp3"
#define SND_SCOUT_FIRE2 "vo/scout_autoonfire02.mp3"

#define SND_SOLDIER_FIRE1 "vo/soldier_autoonfire01.mp3"
#define SND_SOLDIER_FIRE2 "vo/soldier_autoonfire02.mp3"
#define SND_SOLDIER_FIRE3 "vo/soldier_autoonfire03.mp3"

#define SND_ENGINEER_FIRE1 "vo/engineer_autoonfire01.mp3"
#define SND_ENGINEER_FIRE2 "vo/engineer_autoonfire02.mp3"

#define SND_PYRO_FIRE1 "vo/pyro_autoonfire01.mp3"
#define SND_PYRO_FIRE2 "vo/pyro_autoonfire02.mp3"

#define SND_DEMOMAN_FIRE1 "vo/demoman_autoonfire01.mp3"
#define SND_DEMOMAN_FIRE2 "vo/demoman_autoonfire02.mp3"
#define SND_DEMOMAN_FIRE3 "vo/demoman_autoonfire03.mp3"

#define SND_HEAVY_FIRE1 "vo/heavy_autoonfire01.mp3"
#define SND_HEAVY_FIRE2 "vo/heavy_autoonfire02.mp3"
#define SND_HEAVY_FIRE3 "vo/heavy_autoonfire03.mp3"
#define SND_HEAVY_FIRE4 "vo/heavy_autoonfire04.mp3"
#define SND_HEAVY_FIRE5 "vo/heavy_autoonfire05.mp3"

#define SND_ENGINEER_FIRE1 "vo/engineer_autoonfire01.mp3"
#define SND_ENGINEER_FIRE2 "vo/engineer_autoonfire02.mp3"
#define SND_ENGINEER_FIRE3 "vo/engineer_autoonfire03.mp3"

#define SND_MEDIC_FIRE1 "vo/medic_autoonfire01.mp3"
#define SND_MEDIC_FIRE2 "vo/medic_autoonfire02.mp3"
#define SND_MEDIC_FIRE3 "vo/medic_autoonfire03.mp3"
#define SND_MEDIC_FIRE4 "vo/medic_autoonfire04.mp3"
#define SND_MEDIC_FIRE5 "vo/medic_autoonfire05.mp3"

#define SND_SNIPER_FIRE1 "vo/sniper_autoonfire01.mp3"
#define SND_SNIPER_FIRE2 "vo/sniper_autoonfire02.mp3"
#define SND_SNIPER_FIRE3 "vo/sniper_autoonfire03.mp3"

#define SND_SPY_FIRE1 "vo/spy_autoonfire01.mp3"
#define SND_SPY_FIRE2 "vo/spy_autoonfire02.mp3"
#define SND_SPY_FIRE3 "vo/spy_autoonfire03.mp3"


new bool:HasPerk[MAXPLAYERS+1];
new Float:NextBurnReact[MAXPLAYERS+1];
new BurnCount;

new Handle:cvarHFTeam;
new b_HFTeam = false;

new Handle:cvarHFTick;
new Float:f_HFTick = 0.4;

new Handle:cvarHFDmg;
new Float:f_HFDmg = 4.0;


public Plugin myinfo = 
{
	name = "RTD2 Hellfire",
	author = "kking117",
	description = "Adds the negative perk Hellfire to rtd2."
};

public void OnPluginStart()
{
	cvarHFTeam=CreateConVar("rtd_hellfire_team", "0.0", "When set to one it swaps the flame team colour. (0 = Green for Red and Purple for Blu)", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarHFTeam, CvarChange);
	
	cvarHFDmg=CreateConVar("rtd_hellfire_dmg", "4.0", "How much damage the hellfire does per interval. (TF2 Afterburn is 4.0 by default)", _, true, 1.0, false, 9999.0);
	HookConVarChange(cvarHFDmg, CvarChange);
	
	cvarHFTick=CreateConVar("rtd_hellfire_rate", "0.51", "How long an interval is for hellfire. (TF2 Afterburn is 0.51)", _, true, 0.1, false, 9999.0);
	HookConVarChange(cvarHFTick, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarHFTeam)
	{
		b_HFTeam = StringToInt(newValue);
	}
	else if(convar==cvarHFDmg)
	{
		f_HFDmg = StringToFloat(newValue);
	}
	else if(convar==cvarHFTick)
	{
		f_HFTick = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	b_HFTeam = GetConVarInt(cvarHFTeam);
	f_HFDmg = GetConVarFloat(cvarHFDmg);
	f_HFTick = GetConVarFloat(cvarHFTick);
	PrecacheSound("vo/halloween_merasmus/sf12_staff_magic05.mp3", true);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
	}
	BurnCount = 0;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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
    RTD2_ObtainPerk("hellfire") // create perk using unique token "mytoken"
        .SetName("Hellfire") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/halloween_merasmus/sf12_staff_magic05.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, hell, fire, cursedflames, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		BurnCount+=1;
		TF2_AddCondition(client, TFCond_OnFire, 0.5);
		NextBurnReact[client]=GetGameTime()+GetRandomFloat(3.0, 6.0);
		CreateTimer(0.1, Timer_ReapplyParticle, GetClientUserId(client));
		CreateTimer(f_HFTick, Timer_ApplyBurnDmg, GetClientUserId(client));
	}
	else
	{
		BurnCount-=1;
		HasPerk[client]=false;
	}
}

public Action:Timer_ReapplyParticle(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	//2056
	if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			if(GetClientTeam(client)==3)
			{
				if(b_HFTeam)
				{
					AttatchParticleBurn(client, "halloween_burningplayer_flyingbits");
				}
				else
				{
					AttatchParticleBurn(client, "ghost_pumpkin_flyingbits");
				}
			}
			else
			{
				if(b_HFTeam)
				{
					AttatchParticleBurn(client, "ghost_pumpkin_flyingbits");
				}
				else
				{
					AttatchParticleBurn(client, "halloween_burningplayer_flyingbits");
				}
			}
			CreateTimer(1.0, Timer_ReapplyParticle, GetClientUserId(client));
		}
	}
}

public Action:Timer_ApplyBurnDmg(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			DamageEntity(client, client, f_HFDmg, 2056);
			if(NextBurnReact[client]<=GetGameTime())
			{
				FireReact(client);
				NextBurnReact[client]=GetGameTime()+GetRandomFloat(3.0, 6.0);
			}
			CreateTimer(f_HFTick, Timer_ApplyBurnDmg, GetClientUserId(client));
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

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(BurnCount>0)
	{
		//plugin has a stroke and somehow identifies damage from damageentity as -1
		if(attacker<0)
		{
			attacker = 0;
		}
		if(inflictor<0)
		{
			inflictor = 0;
		}
	}
	if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			if((damagetype & DMG_PREVENT_PHYSICS_FORCE) && (damagetype & DMG_BURN))
			{
				if(TF2_IsPlayerInCondition(client, TFCond_OnFire))
				{
					TF2_RemoveCondition(client, TFCond_OnFire);
					damage = 0.0;
					return Plugin_Changed;
				}
			}
			else
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_OnFire))
				{
					//added so weapons like the flare gun recognise the player as being on fire
					//as you'd imagine this would be earape if you got hit repeatedly
					TF2_AddCondition(client, TFCond_OnFire, 0.1, client);
				}
			}
		}
	}
	return Plugin_Continue;
}

FireReact(client)
{
	if(IsValidClient(client))
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
			{
				switch(GetRandomInt(1,2))
				{
					case 1:
					{
						EmitSoundToAll(SND_SCOUT_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_SCOUT_FIRE2, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Soldier:
			{
				switch(GetRandomInt(1,3))
				{
					case 1:
					{
						EmitSoundToAll(SND_SOLDIER_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_SOLDIER_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_SOLDIER_FIRE3, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Pyro:
			{
				switch(GetRandomInt(1,2))
				{
					case 1:
					{
						EmitSoundToAll(SND_PYRO_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_PYRO_FIRE2, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_DemoMan:
			{
				switch(GetRandomInt(1,3))
				{
					case 1:
					{
						EmitSoundToAll(SND_DEMOMAN_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_DEMOMAN_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_DEMOMAN_FIRE2, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Heavy:
			{
				switch(GetRandomInt(1,5))
				{
					case 1:
					{
						EmitSoundToAll(SND_HEAVY_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_HEAVY_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_HEAVY_FIRE3, client, SNDCHAN_VOICE);
					}
					case 4:
					{
						EmitSoundToAll(SND_HEAVY_FIRE4, client, SNDCHAN_VOICE);
					}
					case 5:
					{
						EmitSoundToAll(SND_HEAVY_FIRE5, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Engineer:
			{
				switch(GetRandomInt(1,3))
				{
					case 1:
					{
						EmitSoundToAll(SND_ENGINEER_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_ENGINEER_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_ENGINEER_FIRE3, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Medic:
			{
				switch(GetRandomInt(1,5))
				{
					case 1:
					{
						EmitSoundToAll(SND_MEDIC_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_MEDIC_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_MEDIC_FIRE3, client, SNDCHAN_VOICE);
					}
					case 4:
					{
						EmitSoundToAll(SND_MEDIC_FIRE4, client, SNDCHAN_VOICE);
					}
					case 5:
					{
						EmitSoundToAll(SND_MEDIC_FIRE5, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Sniper:
			{
				switch(GetRandomInt(1,3))
				{
					case 1:
					{
						EmitSoundToAll(SND_SNIPER_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_SNIPER_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_SNIPER_FIRE3, client, SNDCHAN_VOICE);
					}
				}
			}
			case TFClass_Spy:
			{
				switch(GetRandomInt(1,3))
				{
					case 1:
					{
						EmitSoundToAll(SND_SPY_FIRE1, client, SNDCHAN_VOICE);
					}
					case 2:
					{
						EmitSoundToAll(SND_SPY_FIRE2, client, SNDCHAN_VOICE);
					}
					case 3:
					{
						EmitSoundToAll(SND_SPY_FIRE3, client, SNDCHAN_VOICE);
					}
				}
			}
		}
	}
}

stock AttatchParticleBurn(client, String:particlename[])
{
	new Float:pos[3];
	new tfclass = TF2_GetPlayerClass(client);
	new particle = CreateEntityByName("info_particle_system");
    if(IsValidEdict(particle))
    {
        SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
		DispatchKeyValue(particle, "effect_name", particlename);
		SetVariantString("!activator");
		DispatchSpawn(particle);
		AcceptEntityInput(particle, "SetParent", client, particle, 0);
		switch(tfclass)
		{
			case TFClass_Pyro:
			{
				SetVariantString(PYRO_EYES);
			}
			case TFClass_Engineer:
			{
				SetVariantString(ENGINEER_EYES);
			}
			case TFClass_Scout, TFClass_Soldier, TFClass_DemoMan, TFClass_Heavy, TFClass_Medic, TFClass_Sniper, TFClass_Spy:
			{
				SetVariantString(DEF_EYES);
			}
		}
		AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
		AcceptEntityInput(particle, "start");
		ActivateEntity(particle);
		CreateTimer(0.95, Timer_KillEnt, EntIndexToEntRef(particle));
    }
	//create less burn particles if many players have the perk
	//the back particles are usually hidden inside the player unless moving so removing these makes sense
	//for the math this script makes 7 particle entities every second(then deletes them a second later)
	//if 32 players have this that means it would produces 224 entities per second (which is deleted a second later and remade)
	//with this in place it becomes 5 particles per second (160 with 32 players) which puts much less stress and helps avoid hitting the entity limit
	if(BurnCount<9)
	{
		particle = CreateEntityByName("info_particle_system");
		if(IsValidEdict(particle))
		{
			SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
			DispatchKeyValue(particle, "effect_name", particlename);
			SetVariantString("!activator");
			DispatchSpawn(particle);
			AcceptEntityInput(particle, "SetParent", client, particle, 0);
			switch(tfclass)
			{
				case TFClass_Scout:
				{
					SetVariantString(SCOUT_BACK_U);
				}
				case TFClass_Pyro:
				{
					SetVariantString(PYRO_BACK_U);
				}
				case TFClass_Medic:
				{
					SetVariantString(MEDIC_BACK_U);
				}
				case TFClass_Sniper:
				{
					SetVariantString(SNIPER_BACK_U);
				}
				case TFClass_Soldier, TFClass_DemoMan, TFClass_Heavy, TFClass_Engineer, TFClass_Spy:
				{
					SetVariantString(DEF_BACK_L);
				}
			}
			AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		
			AcceptEntityInput(particle, "start");
			ActivateEntity(particle);
			CreateTimer(0.95, Timer_KillEnt, EntIndexToEntRef(particle));
		}
		particle = CreateEntityByName("info_particle_system");
		if(IsValidEdict(particle))
		{
			SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
			DispatchKeyValue(particle, "effect_name", particlename);
			SetVariantString("!activator");
			DispatchSpawn(particle);
			AcceptEntityInput(particle, "SetParent", client, particle, 0);
			SetVariantString(DEF_BACK_L);
			AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		
			AcceptEntityInput(particle, "start");
			ActivateEntity(particle);
			CreateTimer(0.95, Timer_KillEnt, EntIndexToEntRef(particle));
		}
	}
	particle = CreateEntityByName("info_particle_system");
    if(IsValidEdict(particle))
    {
		SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
		DispatchKeyValue(particle, "effect_name", particlename);
		SetVariantString("!activator");
		DispatchSpawn(particle);
		AcceptEntityInput(particle, "SetParent", client, particle, 0);
		SetVariantString(DEF_HAND_L);
		AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
		AcceptEntityInput(particle, "start");
		ActivateEntity(particle);
		CreateTimer(1.0, Timer_KillEnt, EntIndexToEntRef(particle));
    }
	particle = CreateEntityByName("info_particle_system");
    if(IsValidEdict(particle))
    {
		SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
		DispatchKeyValue(particle, "effect_name", particlename);
		SetVariantString("!activator");
		DispatchSpawn(particle);
		AcceptEntityInput(particle, "SetParent", client, particle, 0);
		SetVariantString(DEF_HAND_R);
		AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
		AcceptEntityInput(particle, "start");
		ActivateEntity(particle);
		CreateTimer(1.0, Timer_KillEnt, EntIndexToEntRef(particle));
    }
	particle = CreateEntityByName("info_particle_system");
    if(IsValidEdict(particle))
    {
		SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
		DispatchKeyValue(particle, "effect_name", particlename);
		SetVariantString("!activator");
		DispatchSpawn(particle);
		AcceptEntityInput(particle, "SetParent", client, particle, 0);
		SetVariantString(DEF_FOOT_L);
		AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
		AcceptEntityInput(particle, "start");
		ActivateEntity(particle);
		CreateTimer(1.0, Timer_KillEnt, EntIndexToEntRef(particle));
    }
	particle = CreateEntityByName("info_particle_system");
    if(IsValidEdict(particle))
    {
		SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
		DispatchKeyValue(particle, "effect_name", particlename);
		SetVariantString("!activator");
		DispatchSpawn(particle);
		AcceptEntityInput(particle, "SetParent", client, particle, 0);
		SetVariantString(DEF_FOOT_R);
		AcceptEntityInput(particle, "SetParentAttachment", particle , particle, 0);
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
		AcceptEntityInput(particle, "start");
		ActivateEntity(particle);
		CreateTimer(1.0, Timer_KillEnt, EntIndexToEntRef(particle));
    }
}

public Action:Timer_KillEnt(Handle:timer, entity)
{
	entity = EntRefToEntIndex(entity);
	if(IsValidEntity(entity))
	{
		RemoveEdict(entity);
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
			DispatchKeyValue(client,"targetname","targetsname_hellfire");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_hellfire");
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
			AcceptEntityInput(pointHurt,"Hurt", attacker);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}