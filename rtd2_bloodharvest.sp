#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

#define IN_ATTACK		(1 << 0)
#define IN_JUMP			(1 << 1)
#define IN_DUCK			(1 << 2)
#define IN_FORWARD		(1 << 3)
#define IN_BACK			(1 << 4)
#define IN_USE			(1 << 5)
#define IN_CANCEL		(1 << 6)
#define IN_LEFT			(1 << 7)
#define IN_RIGHT		(1 << 8)
#define IN_MOVELEFT		(1 << 9)
#define IN_MOVERIGHT		(1 << 10)
#define IN_ATTACK2		(1 << 11)
#define IN_RUN			(1 << 12)
#define IN_RELOAD		(1 << 13)
#define IN_ALT1			(1 << 14)
#define IN_ALT2			(1 << 15)
#define IN_SCORE		(1 << 16)   	/**< Used by client.dll for when scoreboard is held down */
#define IN_SPEED		(1 << 17)	/**< Player is holding the speed key */
#define IN_WALK			(1 << 18)	/**< Player holding walk key */
#define IN_ZOOM			(1 << 19)	/**< Zoom key for HUD zoom */
#define IN_WEAPON1		(1 << 20)	/**< weapon defines these bits */
#define IN_WEAPON2		(1 << 21)	/**< weapon defines these bits */
#define IN_BULLRUSH		(1 << 22)
#define IN_GRENADE1		(1 << 23)	/**< grenade 1 */
#define IN_GRENADE2		(1 << 24)	/**< grenade 2 */
#define IN_ATTACK3		(1 << 25)
#define MAX_BUTTONS 26

new bool:HasPerk[MAXPLAYERS+1];

new g_LastButtons[MAXPLAYERS+1]; //records previous sets of buttons
new LastDamageBits[MAXPLAYERS+1]; //records dmg bits from last hit
new MediGunID[MAXPLAYERS+1]; //keeps track of the type of medigun used
new Float:MediDrainNo[MAXPLAYERS+1]; //keeps track of an uber%
new bool:MediDrain[MAXPLAYERS+1]; //to inform that the uber is draining

new Handle:hTrace;

new Handle:cvarLSMult;
new Float:f_LSMult = 1.0;

new Handle:cvarQFdmg;
new Float:f_QFdmg = 3.36;

new Handle:cvarKKdmg;
new Float:f_KKdmg = 2.4;

new Handle:cvarVACdmg;
new Float:f_VACdmg = 2.4;

new Handle:cvarMGdmg;
new Float:f_MGdmg = 2.4;

new Handle:cvarQFUberLSMult;
new Float:f_QFUberLSMult = 1.0;

new Handle:cvarQFUberdmgMult;
new Float:f_QFUberdmgMult = 3.0;

new Handle:cvarKKUberLSMult;
new Float:f_KKUberLSMult = 0.25;

new Handle:cvarKKUberdmgMult;
new Float:f_KKUberdmgMult = 4.0;

new Handle:cvarVACUberLSMult;
new Float:f_VACUberLSMult = 1.75;

new Handle:cvarVACUberdmgMult;
new Float:f_VACUberdmgMult = 1.75;

new Handle:cvarMGUberLSMult;
new Float:f_MGUberLSMult = 1.0;

new Handle:cvarMGUberdmgMult;
new Float:f_MGUberdmgMult = 2.0;



public Plugin myinfo = 
{
	name = "RTD2 Bloody Harvest",
	author = "kking117",
	description = "Adds the positive perk Bloody Harvest to rtd2."
};

public void OnPluginStart()
{
	cvarLSMult=CreateConVar("rtd_bloodharvest_life_mult", "1.0", "Life steal multiplier of the damage dealt.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarLSMult, CvarChange);
	
	cvarQFdmg=CreateConVar("rtd_bloodharvest_qf_dmg", "3.36", "Damage the Quick-Fix inflicts to enemies per tick.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarQFdmg, CvarChange);
	
	cvarQFUberdmgMult=CreateConVar("rtd_bloodharvest_qf_uberdmg_mult", "3.0", "Damage multiplier while ubering with the Quick-Fix.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarQFUberdmgMult, CvarChange);
	
	cvarQFUberLSMult=CreateConVar("rtd_bloodharvest_qf_uberlife_mult", "1.0", "Life steal multiplier while ubering with the Quick-Fix. (overrides rtd_bloodharvest_life_mult)", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarQFUberLSMult, CvarChange);
	
	cvarKKdmg=CreateConVar("rtd_bloodharvest_kk_dmg", "2.4", "Damage the Kritzkrieg inflicts to enemies per tick.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarKKdmg, CvarChange);
	
	cvarKKUberdmgMult=CreateConVar("rtd_bloodharvest_kk_uberdmg_mult", "4.0", "Damage multiplier while ubering with the Kritzkrieg.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarKKUberdmgMult, CvarChange);
	
	cvarKKUberLSMult=CreateConVar("rtd_bloodharvest_kk_uberlife_mult", "0.25", "Life steal multiplier while ubering with the Kritzkrieg. (overrides rtd_bloodharvest_life_mult)", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarKKUberLSMult, CvarChange);
	
	cvarVACdmg=CreateConVar("rtd_bloodharvest_vac_dmg", "2.4", "Damage the Vaccinator inflicts to enemies per tick.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarVACdmg, CvarChange);
	
	cvarVACUberdmgMult=CreateConVar("rtd_bloodharvest_vac_uberdmg_mult", "1.75", "Damage multiplier while ubering with the Vaccinator.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarVACUberdmgMult, CvarChange);
	
	cvarVACUberLSMult=CreateConVar("rtd_bloodharvest_vac_uberlife_mult", "1.75", "Life steal multiplier while ubering with the Vaccinator. (overrides rtd_bloodharvest_life_mult)", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarVACUberLSMult, CvarChange);
	
	cvarMGdmg=CreateConVar("rtd_bloodharvest_mg_dmg", "2.4", "Damage the Stock Medi Gun inflicts to enemies per tick.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarMGdmg, CvarChange);
	
	cvarMGUberdmgMult=CreateConVar("rtd_bloodharvest_vac_uberdmg_mult", "1.0", "Damage multiplier while ubering with the Vaccinator.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarMGUberdmgMult, CvarChange);
	
	cvarMGUberLSMult=CreateConVar("rtd_bloodharvest_vac_uberlife_mult", "2.0", "Life steal multiplier while ubering with the Vaccinator. (overrides rtd_bloodharvest_life_mult)", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarMGUberLSMult, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarLSMult)
	{
		f_LSMult = StringToFloat(newValue);
	}
	else if(convar==cvarQFdmg)
	{
		f_QFdmg = StringToFloat(newValue);
	}
	else if(convar==cvarQFUberdmgMult)
	{
		f_QFUberdmgMult = StringToFloat(newValue);
	}
	else if(convar==cvarQFUberLSMult)
	{
		f_QFUberLSMult = StringToFloat(newValue);
	}
	else if(convar==cvarKKdmg)
	{
		f_KKdmg = StringToFloat(newValue);
	}
	else if(convar==cvarKKUberdmgMult)
	{
		f_KKUberdmgMult = StringToFloat(newValue);
	}
	else if(convar==cvarKKUberLSMult)
	{
		f_KKUberLSMult = StringToFloat(newValue);
	}
	else if(convar==cvarVACdmg)
	{
		f_VACdmg = StringToFloat(newValue);
	}
	else if(convar==cvarVACUberdmgMult)
	{
		f_VACUberdmgMult = StringToFloat(newValue);
	}
	else if(convar==cvarVACUberLSMult)
	{
		f_VACUberLSMult = StringToFloat(newValue);
	}
	else if(convar==cvarMGdmg)
	{
		f_MGdmg = StringToFloat(newValue);
	}
	else if(convar==cvarMGUberdmgMult)
	{
		f_MGUberdmgMult = StringToFloat(newValue);
	}
	else if(convar==cvarMGUberLSMult)
	{
		f_MGUberLSMult = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_LSMult = GetConVarFloat(cvarLSMult);
	f_QFdmg = GetConVarFloat(cvarQFdmg);
	f_QFUberdmgMult = GetConVarFloat(cvarQFUberdmgMult);
	f_QFUberLSMult = GetConVarFloat(cvarQFUberLSMult);
	f_KKdmg = GetConVarFloat(cvarKKdmg);
	f_KKUberdmgMult = GetConVarFloat(cvarKKUberdmgMult);
	f_KKUberLSMult = GetConVarFloat(cvarKKUberLSMult);
	f_VACdmg = GetConVarFloat(cvarVACdmg);
	f_VACUberdmgMult = GetConVarFloat(cvarVACUberdmgMult);
	f_VACUberLSMult = GetConVarFloat(cvarVACUberLSMult);
	f_MGdmg = GetConVarFloat(cvarMGdmg);
	f_MGUberdmgMult = GetConVarFloat(cvarMGUberdmgMult);
	f_MGUberLSMult = GetConVarFloat(cvarMGUberLSMult);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
		MediDrain[client] = false;
		MediDrainNo[client] = 0.0;
	}
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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
    RTD2_ObtainPerk("bloodyharvest") // create perk using unique token "mytoken"
        .SetName("Bloody Harvest") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/medic_specialcompleted12.mp3") // set activation sound
		.SetClasses("7") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("medigun") // make the perk applicable only to clients holding a medigun
        .SetTags("good, medigun, damage, lifesteal, healing, bloody, blood, harvest, medic, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		new weapon = GetPlayerWeaponSlot(client, 1);
		ForceWeaponSlot(client, 1);
		if(HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
		{
			MediGunID[client] = GetWeaponIndex(weapon);
		}
		else
		{
			MediGunID[client] = 29; //sanity stuff
		}
		CreateTimer(0.1, Timer_HealChecker, GetClientUserId(client));
		PrintToChat(client, "Locked to your medigun, but you can target enemies to siphon their life!");
	}
	else
	{
		HasPerk[client]=false;
		MediDrain[client] = false;
		MediDrainNo[client] = 0.0;
		new patient = GetHealingTarget(client);
		if(IsValidClient(patient) && GetClientTeam(client) != GetClientTeam(patient))
		{
			if(GetDisguiseTeam(patient) == 0 || GetDisguiseTeam(patient) != GetClientTeam(client))
			{
				SetHealingTarget(client, -1);
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

public Action:Timer_HealChecker(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && HasPerk[client])
	{
		MediDrain[client] = UberDraining(client);
		new weapon = GetPlayerWeaponSlot(client, 1);
		new ActiveWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(IsValidEntity(ActiveWep) && IsValidEntity(weapon))
		{
			if(weapon==ActiveWep)
			{
				new patient = GetHealingTarget(client);
				if(IsValidClient(patient) && GetClientTeam(patient) != GetClientTeam(client))
				{
					MedigunLifeSteal(client, patient);
				}
				if(g_LastButtons[client] & IN_ATTACK)
				{
					new target = -1;
					target = GetClosestTarget(client, 550.0, true, true, 35.0, 0);
					if(IsValidClient(target))
					{
						SetHealingTarget(client, target);
					}
				}
			}
		}
		else
		{
			SetHealingTarget(client, -1);
		}
		CreateTimer(0.1, Timer_HealChecker, GetClientUserId(client));
	}
}

public Action:Hook_WeaponCanSwitchTo(client, weapon) 
{ 
    if(HasPerk[client])
	{
		if(weapon!=GetPlayerWeaponSlot(client, 1))
		{
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
    if(IsValidClient(client))
	{
	    if(IsValidClient(attacker) && HasPerk[attacker])
		{
		    LastDamageBits[client] = damagetype;
		}
	}
    return Plugin_Continue;
}

public Action:OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage=GetEventInt(event, "damageamount");
	if(HasPerk[attacker])
	{
	    if(LastDamageBits[client] & DMG_SLASH) //bleeding damage/vampire medi gun dmg
		{
			if(MediDrain[client])
			{
				if(MediGunID[client] == 35) //kritzkrieg
				{
					SetEntityHealth(attacker, RoundToNearest(damage*f_KKUberLSMult)+GetClientHealth(attacker));
				}
				else if(MediGunID[client] == 411) //nesquik
				{
					SetEntityHealth(attacker, RoundToNearest(damage*f_QFUberLSMult)+GetClientHealth(attacker));
				}
				else if(MediGunID[client] == 998) //vaccinator
				{
					SetEntityHealth(attacker, RoundToNearest(damage*f_VACUberLSMult)+GetClientHealth(attacker));
				}
				else //other/medigun
				{
					SetEntityHealth(attacker, RoundToNearest(damage*f_MGUberLSMult)+GetClientHealth(attacker));
				}
			}
			else
			{
				SetEntityHealth(attacker, RoundToNearest(damage*f_LSMult)+GetClientHealth(attacker));
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(IsValidClient(client))
	{
		g_LastButtons[client]=buttons;
	}
	return Plugin_Changed;
}

stock bool:UberDraining(client)
{
	if(IsValidClient(client))
	{
		new medigun=GetPlayerWeaponSlot(client, 1);
		if(IsValidEntity(medigun))
		{
			decl String:classname[64];
			GetEntityClassname(medigun, classname, sizeof(classname));
			if(!strcmp(classname, "tf_weapon_medigun", false))
			{
				new Float:charge = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
				if (MediDrainNo[client] > charge)
				{
					MediDrainNo[client] = charge;
					return true;
				}
				MediDrainNo[client] = charge;
			}
		}
	}
	return false;
}

ForceWeaponSlot(client, slot)
{
	new weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}

SetHealingTarget(client, target)
{
    new medigun=GetPlayerWeaponSlot(client, 1);
	if(IsValidEntity(medigun))
	{
		decl String:classname[64];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if(!strcmp(classname, "tf_weapon_medigun", false))
		{
			if(target==-1)
			{
				SetEntProp(medigun, Prop_Send, "m_bHealing", 0);
				SetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget", -1);
			}
			else
			{
				SetEntProp(medigun, Prop_Send, "m_bHealing", 1);
				SetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget", target);
			}
		}
	}
}

stock GetHealingTarget(client)
{
	new medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(IsValidEntity(medigun))
	{
		decl String:classname[64];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if(!strcmp(classname, "tf_weapon_medigun", false))
		{
			if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
			{
				return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
			}
		}
	}
	return -1;
}

MedigunLifeSteal(client, patient)
{
	if(IsValidClient(patient))
	{
		if(MediDrain[client])
		{
			if (MediGunID[client] == 35) //kritzkrieg
			{
				DamageEntity(patient, client, f_KKdmg*f_KKUberdmgMult, DMG_SLASH);
			}
			else if (MediGunID[client] == 411) //quikfix
			{
				DamageEntity(patient, client, f_QFdmg*f_QFUberdmgMult, DMG_SLASH);
			}
			else if (MediGunID[client] == 998) //vaccinator
			{
				DamageEntity(patient, client, f_VACdmg*f_VACUberdmgMult, DMG_SLASH);
			}
			else //considered stock medi gun for fail safes
			{
				DamageEntity(patient, client, f_MGdmg*f_MGUberdmgMult, DMG_SLASH);
			}
		}
		else
		{
			if (MediGunID[client] == 35) //kritzkrieg
			{
				DamageEntity(patient, client, f_KKdmg, DMG_SLASH);
			}
			else if (MediGunID[client] == 411) //quikfix
			{
				DamageEntity(patient, client, f_QFdmg, DMG_SLASH);
			}
			else if (MediGunID[client] == 998) //vaccinator
			{
				DamageEntity(patient, client, f_VACdmg, DMG_SLASH);
			}
			else //considered stock medi gun for fail safes
			{
				DamageEntity(patient, client, f_MGdmg, DMG_SLASH);
			}
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
			DispatchKeyValue(client,"targetname","targetsname_bloodyharvest");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_bloodyharvest");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			DispatchKeyValue(pointHurt,"classname","");
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

stock GetClosestTarget(client, Float:Distance, bool:InView, bool:InSight, Float:SightCone, ClearViewType)
{
    new Float:clientPosition[3];
	new Float:targetPosition[3];
	new Float:angles[3];
	GetClientEyeAngles(client, angles);
	new starget = -1;
	new Float:targetdist = Distance;
	GetClientEyePosition(client, clientPosition);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target) && IsPlayerAlive(target) && client!=target)
		{
		    GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			targetPosition[2]+=GetEntityHeight(target, 0.3);
		    if(GetVectorDistance(clientPosition, targetPosition)<targetdist)
			{
				if(!IsCloaked(target))
				{
					if(InView && InClearView(clientPosition, targetPosition, client, ClearViewType))
					{
						if(InSight && IsTargetInSightCone(client, target, angles, SightCone, Distance, true))
						{
							starget=target;
							targetdist = GetVectorDistance(clientPosition, targetPosition);
						}
						else if(!InSight)
						{
						    starget=target;
							targetdist = GetVectorDistance(clientPosition, targetPosition);
						}
					}
					else if(InSight && IsTargetInSightCone(client, target, angles, SightCone, Distance, true))
					{
						if(!InView)
						{
							starget=target;
							targetdist = GetVectorDistance(clientPosition, targetPosition);
						}
					}
					else if(!InView && !InSight)
					{
						starget=target;
						targetdist = GetVectorDistance(clientPosition, targetPosition);
					}
				}
			}
		}
	}
	return starget;
}

//Not my code, I have no idea where I found this but I know it was from a post on alliedmodders.net
stock bool:IsTargetInSightCone(client, target, Float:viewangle[3], Float:angle, Float:distance, bool:heightcheck)
{
	if(angle > 360.0 || angle < 0.0)
	{
		ThrowError("Angle Max : 360 & Min : 0. %d isn't proper angle.", angle);
	}
	new Float:clientpos[3], Float:targetpos[3], Float:targetvector[3], Float:resultangle, Float:resultdistance;

	GetAngleVectors(viewangle, viewangle, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(viewangle, viewangle);
	
	GetClientAbsOrigin(client, clientpos);
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", clientpos);
	GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetpos);

	if(heightcheck && distance > 0)
	{
		resultdistance = GetVectorDistance(clientpos, targetpos);
	}
	MakeVectorFromPoints(clientpos, targetpos, targetvector);
	NormalizeVector(targetvector, targetvector);
	
	resultangle = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, viewangle)));
	
	if(resultangle <= angle/2)	
	{
		if(distance > 0)
		{
			if(!heightcheck)
			{
				resultdistance = GetVectorDistance(clientpos, targetpos);
			}
			if(distance >= resultdistance)
			{
				return true;
			}
			else
			{
				return false;
			}
		}
		else
		{
			return true;
		}
	}
	else
	{
		return false;
	}
}

stock bool:InClearView(Float:pos2[3], Float:pos[3], entity, type)
{
    switch(type)
	{
	    case 0:
		{
		    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilterHoming, entity);
		}
		case 1:
		{
		    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilter_NoNPCPLAYERPROJ, entity);
		}
	}
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace)) //if there's an obstruction
		{
		    CloseHandle(hTrace);
		    return false;
		}
		else //if there isn't a wall between them
		{
			CloseHandle(hTrace);
			return true;
		}
	}
	return false;
}

stock bool:TraceFilterHoming(entity, contentsMask, any:ent)
{
	if(entity == ent || IsValidClient(entity))
	{
		return false;
	}
	return true;
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
		GetEntityClassname(entity, ClassName, sizeof(ClassName)); //we really don't care about projectiles
		if(!StrContains(ClassName, "tf_projectile", false))
		{
		    return false;
		}
		else if(!StrContains(ClassName, "obj_", false)) //buildings and sapper attatchments
		{
		    return false;
		}
	}
	return true;
}

stock bool:IsCloaked(client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) //if a spy is cloaked
	{
		return true;
	}
	else if(TF2_IsPlayerInCondition(client, TFCond_Stealthed)) //player is using the cloak spell
	{
		return true;
	}
	else if(TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade)) //player is using the cloak spell
	{
		return true;
	}
	else
	{
	    return false;
	}
}

stock Float:GetEntityHeight(entity, Float:mult)
{
    if(IsValidEntity(entity))
	{
		if(HasEntProp(entity, Prop_Send, "m_vecMaxs"))
		{
		    new Float:height[3];
			GetEntPropVector(entity, Prop_Send, "m_vecMaxs", height);
			return height[2]*mult;
		}
	}
	return 0.0;
}

stock GetWeaponIndex(entity)
{
	if(IsValidEntity(entity) && !IsValidClient(entity))
	{
	    new index = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		return index;
	}
	return -1;
}

stock GetDisguiseTeam(client)
{
    if(IsValidClient(client))
	{
	    if(TF2_IsPlayerInCondition(client, TFCond_Disguised)) //actually has the disguise condition
	    {
		    return GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
	    }
	}
	return 0;
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