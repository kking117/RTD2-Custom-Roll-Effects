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
new Float:CamAngles[MAXPLAYERS+1][3];

public Plugin myinfo = 
{
	name = "RTD2 Unplugged Mouse",
	author = "kking117",
	description = "Adds the negative perk Unplugged Mouse to rtd2."
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
    RTD2_ObtainPerk("unpluggedmouse") // create perk using unique token "mytoken"
        .SetName("Unplugged Mouse") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/scout_invinciblenotready02.mp3") // set activation sound
		.SetClasses("0") // make the perk applicable only to everyone
        .SetWeaponClasses("0") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, mouse, unplugged, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client] = true;
		new Float:eyeangles[3];
		GetClientEyeAngles(client, eyeangles);
		CamAngles[client][0] = eyeangles[0];
		CamAngles[client][1] = eyeangles[1];
		CamAngles[client][2] = eyeangles[2]; //pretty sure this isn't used but eh
		PrintToChat(client, "This looks bad.");
	}
	else
	{
		HasPerk[client] = false;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(HasPerk[client])
	{
		for(new slot = 0; slot < 3; slot++)
		{
			new weapon = GetPlayerWeaponSlot(client, slot);
			if(IsValidEntity(weapon))
			{
				SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", GetGameTime()+0.3);
				SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", GetGameTime()+0.3);
			}
		}
		buttons = buttons & ~IN_ATTACK;
		buttons = buttons & ~IN_ATTACK2;
		buttons = buttons & ~IN_ATTACK3;
		TeleportEntity(client, NULL_VECTOR, CamAngles[client], NULL_VECTOR);
		return Plugin_Changed;
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