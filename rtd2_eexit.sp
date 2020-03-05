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

new Handle:cvarEEForce;
new Float:f_EEForce = 4096.0;

new bool:FloorTouched[MAXPLAYERS+1]=true;
new LastButtons[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "RTD2 Emergency Exit",
	author = "kking117",
	description = "Adds the positive perk Emergency Exit to rtd2."
};

public void OnPluginStart()
{
	cvarEEForce=CreateConVar("rtd_eexit_force", "4096.0", "The force at which the the player is shot up when rolling emergency exit.", _, false, 0.0, false, 1.0);
	HookConVarChange(cvarEEForce, CvarChange);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarEEForce)
	{
		f_EEForce = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_EEForce = GetConVarFloat(cvarEEForce);
	for(new client=1; client<=MaxClients; client++)
	{
		FloorTouched[client] = true;
	}
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
    RTD2_ObtainPerk("emergencyexit") // create perk using unique token "mytoken"
        .SetName("Emergency Exit") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(-1)
        .SetSound("weapons/flare_detonator_launch.wav") // set activation sound
		.SetClasses("0") // make the perk applicable only to everyone
        .SetWeaponClasses("0") // make the perk applicable only to clients holding a shotgun
        .SetTags("launch, notimer, good, exit, emergency, escape, eexit, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		new Float:FPush[3];
		FPush[2] = f_EEForce;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, FPush);
		AttatchParticle(client, "burningplayer_rainbow_flame", 0.5);
		CreateTimer(0.5, Timer_Parachute, GetClientUserId(client));
		FloorTouched[client] = false;
	}
	else
	{
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(!FloorTouched[client])
	{
		if((buttons & IN_JUMP) && (LastButtons[client] & IN_JUMP)==0)
		{
			TF2_RemoveCondition(client, TFCond_Parachute);
		}
		LastButtons[client] = buttons;
		if((GetEntityFlags(client) & FL_ONGROUND))
		{
			FloorTouched[client] = false;
		}
	}
	return Plugin_Continue;
}

public Action:Timer_Parachute(Handle:timer, client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client))
	{
		TF2_AddCondition(client, TFCond_Parachute, TFCondDuration_Infinite, client);
	}
}

stock AttatchParticle(entity, String:particlename[], Float:duration)
{
	new particle = CreateEntityByName("info_particle_system");
    
    new String:tName[128];
    if (IsValidEdict(particle))
    {
        new Float:pos[3] ;
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        pos[2] += 10;
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        
        Format(tName, sizeof(tName), "target%i", entity);
        DispatchKeyValue(entity, "targetname", tName);
       
        DispatchKeyValue(particle, "targetname", "tf2particle");
        DispatchKeyValue(particle, "parentname", tName);
        DispatchKeyValue(particle, "effect_name", particlename);
        DispatchSpawn(particle);
        SetVariantString(tName);
        AcceptEntityInput(particle, "SetParent", particle, particle, 0);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
		if (duration > 0.0)
		{
			CreateTimer(duration, Timer_RemoveParticle, EntIndexToEntRef(particle));
		}
    }
}

public Action:Timer_RemoveParticle(Handle:timer, entity)
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