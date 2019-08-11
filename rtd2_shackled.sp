#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

new bool:HasPerk[MAXPLAYERS+1];

new Float:NextPull[MAXPLAYERS+1]; //used to keep track of the next time the player gets 'tugged' by the shackle
new Float:ShackleLife[MAXPLAYERS+1]; //how much stress the shackle can handle before breaking
new ShackleRef[MAXPLAYERS+1]; //used to keep track of tether beams, also to keep track of who is bound
new ShackleTo[MAXPLAYERS+1]; //the client the person is bound to
new Handle:hTrace;

new Handle:PartnerHUD;

new Handle:cvarSDist;
new Float:f_SDist = 300.0;

new Handle:cvarSPower;
new Float:f_SPower = 0.2;

public Plugin myinfo = 
{
	name = "RTD2 Shackled",
	author = "kking117",
	description = "Adds the negative perk Shackled to rtd2."
};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	
	cvarSPower=CreateConVar("rtd_shackled_ratio", "0.2", "The roller to partner pull ratio. 0.2 = the roller has 20% of the pulling power while the partner has 80%.", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarSPower, CvarChange);
	
	cvarSDist=CreateConVar("rtd_shackled_distance", "300.0", "The distance the two shackled players can be from each other before they start to get pulled.", _, true, 0.0, true, 99999.0);
	HookConVarChange(cvarSDist, CvarChange);
	
	PartnerHUD=CreateHudSynchronizer();
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarSPower)
	{
		f_SPower = StringToFloat(newValue);
	}
	else if(convar==cvarSDist)
	{
		f_SDist = StringToFloat(newValue);
	}
}

public void OnMapStart()
{
	f_SPower = GetConVarFloat(cvarSPower);
	f_SDist = GetConVarFloat(cvarSDist);
	CreateTimer(0.5, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
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
    RTD2_ObtainPerk("shackled") // create perk using unique token "mytoken"
        .SetName("Shackled") // set perk's name
        .SetGood(false) // make the perk good
		.SetTime(0)
        .SetSound("vo/scout_jeers10.mp3") // set activation sound
		.SetClasses("0") // make the perk applicable only to everyone
        .SetWeaponClasses("0") // make the perk applicable only to clients holding a shotgun
        .SetTags("bad, shackle, bound, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client] = true;
		ShackleTo[client]=-1;
		NextPull[client]=GetGameTime();
		FindNewPartner(client);
		PrintToChat(client, "Co-op mode activated.");
	}
	else
	{
		HasPerk[client] = false;
		new buddy = GetClientOfUserId(ShackleTo[client]);
		if(IsValidClient(buddy))
		{
			RemoveShackle(buddy);
		}
		RemoveShackle(client);
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

public Action:ClientTimer(Handle:timer)
{
	for(new client=1; client<MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			if(GetClientTeam(client)>1 && IsPlayerAlive(client))
			{
				if(HasShackle(client))
				{
					new buddy = GetClientOfUserId(ShackleTo[client]);
					if(IsValidClient(buddy))
					{
						new String:username[60];
						GetClientName(buddy, username, sizeof(username));
						switch(GetClientTeam(buddy))
						{
							case 0, 1:
							{
								SetHudTextParams(-1.0, 0.37, 0.55, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, PartnerHUD, "Partner(%.0f%%) - %s", ShackleLife[client], username);
							}
							case 2:
							{
								SetHudTextParams(-1.0, 0.37, 0.55, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, PartnerHUD, "Partner(%.0f%%) - %s", ShackleLife[client], username);
							}
							case 3:
							{
								SetHudTextParams(-1.0, 0.37, 0.55, 64, 64, 255, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, PartnerHUD, "Partner(%.0f%%) - %s", ShackleLife[client], username);
							}
						}
					}
				}
			}
			else
			{
				if(HasShackle(client))
				{
					RemoveShackle(client);
				}
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(HasPerk[client])
	{
		if(ShackleTo[client]!=-1)
		{
			new buddy = GetClientOfUserId(ShackleTo[client]);
			if(IsValidClient(buddy) && IsPlayerAlive(buddy))
			{
				if(NextPull[client]<GetGameTime())
				{
					new Float:clientpos[3];
					new Float:buddypos[3];
					new Float:dist;
					GetClientEyePosition(client, clientpos);
					GetClientEyePosition(buddy, buddypos);
					dist = GetVectorDistance(clientpos, buddypos);
					if(dist>f_SDist)
					{
						new Float:PullPower = f_SPower;
						if(PullPower!=0.0 || PullPower!=1.0)
						{
							switch(TF2_GetPlayerClass(client))
							{
								case TFClass_Scout, TFClass_Spy:
								{
									PullPower -= 0.05;
								}
								//case TFClass_Engineer, TFClass_Pyro, TFClass_Medic, TFClass_Sniper:
								//{
								//	PullPower += 0.0;
								//}
								case TFClass_DemoMan, TFClass_Soldier:
								{
									PullPower += 0.05;
								}
								case TFClass_Heavy:
								{
									PullPower += 0.1;
								}
							}
							switch(TF2_GetPlayerClass(buddy))
							{
								case TFClass_Scout, TFClass_Spy:
								{
									PullPower += 0.05;
								}
								//case TFClass_Engineer, TFClass_Pyro, TFClass_Medic, TFClass_Sniper:
								//{
								//	PullPower = 0.0;
								//}
								case TFClass_DemoMan, TFClass_Soldier:
								{
									PullPower -= 0.05;
								}
								case TFClass_Heavy:
								{
									PullPower -= 0.1;
								}
							}
						}
						if(PullPower<0.0)
						{
							PullPower=0.0;
						}
						else if(PullPower>1.0)
						{
							PullPower=1.0;
						}
						new Float:vbuffer[3];
						new Float:slowdown = 0.0;
						dist = (dist-f_SDist)+100.0;
						if(dist>800.0)
						{
							dist = 800.0;
						}
						if(InClearView(clientpos, buddypos, client))
						{
							ShackleLife[client]-=RoundToNearest(dist*0.01);
							ShackleLife[buddy]-=RoundToNearest(dist*0.01);
						}
						else
						{
							//the shackle will disconnect more easily if eye contact is broken
							ShackleLife[client]-=RoundToNearest(dist*0.02);
							ShackleLife[buddy]-=RoundToNearest(dist*0.02);
						}
						dist*=0.005;
						slowdown = dist/800.0;
						//////////////////////
						//PULLING THE ROLLER//
						//////////////////////
						new Float:clientvel[3];
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientvel);
						MakeVectorFromPoints(clientpos, buddypos, vbuffer);
						vbuffer[0]*=dist*(1.0-PullPower);
						vbuffer[1]*=dist*(1.0-PullPower);
						vbuffer[2]*=dist*(1.0-PullPower);
						if(GetEntityFlags(client) & FL_ONGROUND)
						{
							vbuffer[2]*=0.5;
							TF2_AddCondition(client, TFCond_LostFooting, 0.3);
							TF2_StunPlayer(client, 0.3, slowdown*(1.0-PullPower), TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT);
						}
						else
						{
							vbuffer[0]*=0.35;
							vbuffer[1]*=0.35;
						}
						clientvel[0]+=vbuffer[0];
						clientvel[1]+=vbuffer[1];
						clientvel[2]+=vbuffer[2];
						//PrintToServer("Hori: %.1f, Vert: %.1f", (vbuffer[0]+vbuffer[1])*0.5, vbuffer[2]);
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientvel);
						///////////////////////
						//PULLING THE PARTNER//
						///////////////////////
						new Float:buddyvel[3];
						GetEntPropVector(buddy, Prop_Data, "m_vecVelocity", buddyvel);
						MakeVectorFromPoints(buddypos, clientpos, vbuffer);
						vbuffer[0]*=dist*PullPower;
						vbuffer[1]*=dist*PullPower;
						vbuffer[2]*=dist*PullPower;
						if(GetEntityFlags(buddy) & FL_ONGROUND)
						{
							vbuffer[2]*=0.5;
							TF2_AddCondition(buddy, TFCond_LostFooting, 0.3);
							TF2_StunPlayer(buddy, 0.3, slowdown*PullPower, TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT);
						}
						else
						{
							vbuffer[0]*=0.35;
							vbuffer[1]*=0.35;
						}
						buddyvel[0]+=vbuffer[0];
						buddyvel[1]+=vbuffer[1];
						buddyvel[2]+=vbuffer[2];
						TeleportEntity(buddy, NULL_VECTOR, NULL_VECTOR, buddyvel);
					}
					NextPull[client]=GetGameTime()+0.2;
				}
				else
				{
					if(ShackleLife[client]<100.0)
					{
						ShackleLife[client]+=0.1;
					}
					if(ShackleLife[buddy]<100.0)
					{
						ShackleLife[buddy]+=0.1;
					}
				}
				if(ShackleLife[client]<0.0)
				{
					RemoveShackle(client);
					RemoveShackle(buddy);
				}
			}
			else
			{
				RemoveShackle(client);
				NextPull[client]=GetGameTime()+0.5;
			}
		}
		else
		{
			if(NextPull[client]<GetGameTime())
			{
				NextPull[client]=GetGameTime()+0.5;
				FindNewPartner(client);
			}
		}
	}
	return Plugin_Continue;
}

FindNewPartner(client)
{
	new validplayer[32];
	new loop=0;
	new Float:clientpos[3];
	new Float:targetpos[3];
	new Float:closestDist=99999.0;
	new closestid=-1;
	GetClientEyePosition(client, clientpos);
	for(new i=0; i < MaxClients; i++)
	{
		if(IsValidClient(i) && i!=client)
		{
			if(IsPlayerAlive(i))
			{
				//we don't want multiple players bound to a single person
				if(!HasPerk[i] && !HasShackle(i))
				{
					GetClientEyePosition(i, targetpos);
					if(InClearView(clientpos, targetpos, client))
					{
						validplayer[loop]=i;
						loop+=1;
					}
				}
			}
		}
	}
	if(loop>0)
	{
		for(new i=0; i < loop; i++)
		{
			GetClientEyePosition(validplayer[i], targetpos);
			if(GetVectorDistance(clientpos, targetpos)<closestDist)
			{
				closestDist=GetVectorDistance(clientpos, targetpos);
				closestid = validplayer[i];
			}
		}
		if(IsValidClient(closestid))
		{
			ShackleTo[client]=GetClientUserId(closestid);
			ShackleTo[closestid]=GetClientUserId(client);
			ShackleLife[client]=100.0;
			ShackleLife[closestid]=100.0;
			SetupShackle(client, closestid, "medicgun_beam_machinery_stage3");
		}
	}
}

RemoveShackle(client)
{
	//PrintToServer("BREAK");
	new entity = EntRefToEntIndex(ShackleRef[client]);
	if(IsValidEntity(entity))
	{
		new String:ClassName[255];
		GetEntityClassname(entity, ClassName, sizeof(ClassName));
		if(!StrContains(ClassName, "info_particle_system", false))
		{
		    AcceptEntityInput(entity, "Kill");
		}
	}
	ShackleRef[client]=0;
	ShackleTo[client]=-1;
}

SetupShackle(ent1, ent2, String:ParticleName[])
{
	new particle  = CreateEntityByName("info_particle_system");
	new particle2 = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new String:tName[128];
		Format(tName, sizeof(tName), "target%i", ent1);
		DispatchKeyValue(ent1, "targetname", tName);

		new String:cpName[128];
		Format(cpName, sizeof(cpName), "target%i", ent2);
		DispatchKeyValue(ent2, "targetname", cpName);

		//--------------------------------------
		new String:cp2Name[128];
		Format(cp2Name, sizeof(cp2Name), "tf2particle%i", ent2);

		DispatchKeyValue(particle2, "targetname", cp2Name);
		DispatchKeyValue(particle2, "parentname", cpName);

		SetVariantString(cpName);
		AcceptEntityInput(particle2, "SetParent");

		SetVariantString("flag");
		AcceptEntityInput(particle2, "SetParentAttachment");
		//-----------------------------------------------


		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", ParticleName);
		DispatchKeyValue(particle, "cpoint1", cp2Name);

		DispatchSpawn(particle);

		SetVariantString(tName);
		AcceptEntityInput(particle, "SetParent");

		SetVariantString("flag");
		AcceptEntityInput(particle, "SetParentAttachment");

		//The particle is finally ready
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		
		ShackleRef[ent1] = EntIndexToEntRef(particle);
		ShackleRef[ent2] = EntIndexToEntRef(particle2);
	}
}

stock bool:HasShackle(client)
{
	if(IsValidClient(client))
	{
		new entity = EntRefToEntIndex(ShackleRef[client]);
		if(IsValidEntity(entity))
		{
			new String:ClassName[255];
			GetEntityClassname(entity, ClassName, sizeof(ClassName));
			if(!StrContains(ClassName, "info_particle_system", false))
			{
				return true;
			}
		}
	}
	return false;
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

stock bool:InClearView(Float:pos2[3], Float:pos[3], entity)
{
    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilterThroughNpc, entity);
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace))//if there's an obstruction
		{
		    CloseHandle(hTrace);
		    return false;
		}
		else//if there isn't a wall between them
		{
			CloseHandle(hTrace);
			return true;
		}
	}
	return false;
}

stock bool:TraceFilterThroughNpc(entity, contentsMask, any:ent)
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
		new String:entname[256];
		GetEntityClassname(entity, entname, sizeof(entname));
		if(StrEqual(entname, "tank_boss", false) || StrEqual(entname, "tf_zombie", false) || StrEqual(entname, "tf_robot_destruction_robot", false) || StrEqual(entname, "merasmus", false) || StrEqual(entname, "headless_hatman", false) || StrEqual(entname, "eyeball_boss", false))
		{
			return false;
		}
		else if(StrEqual(entname, "obj_sentrygun", false) || StrEqual(entname, "obj_dispenser", false) || StrEqual(entname, "obj_teleporter", false))
		{
			return false;
		}
		else if(StrContains(entname, "tf_projectile")>=0)
		{
			return false;
		}
	}
	return true;
}