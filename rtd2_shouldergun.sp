#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <rtd2>

#define MDL_GUN "models/buildables/sentry1.mdl"
#define SND_SHOOT "weapons/sentry_shoot_mini.wav"

new Handle:cvarSGFire;
new Float:f_SGFire = 0.16;

new Handle:cvarSGDmg;
new Float:f_SGDmg = 8.0;

new Handle:cvarSGRange;
new Float:f_SGRange = 800.0;

new Handle:cvarSGTurn;
new Float:f_SGTurn = 1.0;

new Handle:cvarSGSpread;
new Float:f_SGSpread = 2.0;

new Handle:cvarSGAimRate;
new Float:f_SGAimRate = 0.2;

new Handle:cvarSGBullets;
new i_SGBullets = 1;

new Handle:cvarSGShotMode;
new i_SGShotMode = 0;

new Handle:cvarSGIdle;
new i_SGIdle = 0;

new Handle:cvarSGAim;
new i_SGAim = 1;

new Handle:cvarSGHealth;
new i_SGHealth = 50;

new Handle:cvarSGAmmo;
new i_SGAmmo = 25;

new Handle:hTrace; //for wall checks

new bool:HasPerk[MAXPLAYERS+1];

//for shoulder gun
new Float:GunNextShot[MAXPLAYERS+1];
new Float:GunAimAngle[MAXPLAYERS+1][3];
new Float:GunNextAim[MAXPLAYERS+1];
new bool:FoundTarget[MAXPLAYERS+1];
new Float:LastSGHit[MAXPLAYERS+1]; //keeps track of the last time the client's shouldergun hit
new LastGunTarget[MAXPLAYERS+1];
new Float:LastGunOffset[MAXPLAYERS+1];
new BulletTraceShooter; //keeps track of the player's gun that shot

//shoulder gun cosmetic
new ShoulderGunRef[MAXPLAYERS+1];

new BulletCycle;

new g_CurButtons[MAXPLAYERS+1]; //records current sets of buttons

public Plugin myinfo = 
{
	name = "RTD2 Shoulder Gun",
	author = "kking117",
	description = "Adds the positive perk Shoulder Gun to rtd2."
};

public void OnPluginStart()
{
	cvarSGFire=CreateConVar("rtd_shoulder_firerate", "0.16", "The cooldown between each shot for the shoulder gun.", _, true, 0.1, false, 1.0);
	HookConVarChange(cvarSGFire, CvarChange);
	
	cvarSGDmg=CreateConVar("rtd_shoulder_dmg", "8.0", "The shoulder gun's bullet damage.", _, true, 1.0, false, 1.0);
	HookConVarChange(cvarSGDmg, CvarChange);
	
	cvarSGRange=CreateConVar("rtd_shoulder_range", "800.0", "The view distance of the shoulder gun. (1100.0 is the same as a normal sentry, 800.0 is roughly minisentry range.)", _, true, 100.0, false, 1.0);
	HookConVarChange(cvarSGRange, CvarChange);
	
	cvarSGTurn=CreateConVar("rtd_shoulder_turnrate", "1.0", "How quickly the shoulder gun turns. (This is 50% faster when tracking a target.)", _, true, 0.01, false, 1.0);
	HookConVarChange(cvarSGTurn, CvarChange);
	
	cvarSGSpread=CreateConVar("rtd_shoulder_spread", "2.0", "The random spread of the bullets in degrees.", _, true, 0.0, true, 90.0);
	HookConVarChange(cvarSGSpread, CvarChange);
	
	cvarSGAimRate=CreateConVar("rtd_shoulder_aimrate", "0.2", "How often the shoulder gun rechecks its targets. (Higher values means less work for the server but results in a loss in accuracy.)(Values lower than 0.05 will update its' aim as soon as possible.)", _, true, 0.0, true, 0.5);
	HookConVarChange(cvarSGAimRate, CvarChange);
	
	cvarSGBullets=CreateConVar("rtd_shoulder_shots", "1.0", "How many bullets to fire per shot. (Limit: 1-9)", _, true, 1.0, true, 9.0);
	HookConVarChange(cvarSGBullets, CvarChange);
	
	cvarSGShotMode=CreateConVar("rtd_shoulder_shoot_mode", "0.0", "Changes when the shoulder gun shoots (Note: It will always auto fire at targets.), 0 = only when it has a target, 1 = always, 2 = while holding down fire.", _, true, 0.0, true, 2.0);
	HookConVarChange(cvarSGShotMode, CvarChange);
	
	cvarSGIdle=CreateConVar("rtd_shoulder_idle_mode", "0.0", "Changes how the shoulder gun aims when there's no target, 0 = follows user's aim, 1 = spins around.", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarSGIdle, CvarChange);
	
	cvarSGAim=CreateConVar("rtd_shoulder_aim_enable", "1.0", "Disables the shoulder gun's auto aim when set to 0.", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarSGAim, CvarChange);
	
	cvarSGHealth=CreateConVar("rtd_shoulder_health", "50.0", "The amount of health the shoulder gun has when it dismounts. (100 is the highest) (Set to 0 to disable dismounting).", _, true, 0.0, true, 100.0);
	HookConVarChange(cvarSGAim, CvarChange);
	
	cvarSGAmmo=CreateConVar("rtd_shoulder_ammo", "25.0", "The amount of ammo the shoulder gun has when it dismounts. (100 is the highest) (Like any disposable sentry it will automatically detonate when out of ammo).", _, true, 0.0, true, 100.0);
	HookConVarChange(cvarSGAmmo, CvarChange);
	
	HookEvent("teamplay_round_start", OnRoundChange);
	HookEvent("teamplay_round_win", OnRoundChange);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
	if(RTD2_IsRegOpen())
	{
		RegisterPerk(); // if module was late-loaded, register our perk
	}
}


public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar==cvarSGFire)
	{
		f_SGFire = StringToFloat(newValue);
	}
	else if(convar==cvarSGDmg)
	{
		f_SGDmg = StringToFloat(newValue);
	}
	else if(convar==cvarSGRange)
	{
		f_SGRange = StringToFloat(newValue);
	}
	else if(convar==cvarSGTurn)
	{
		f_SGTurn = StringToFloat(newValue);
	}
	else if(convar==cvarSGSpread)
	{
		f_SGSpread = StringToFloat(newValue);
	}
	else if(convar==cvarSGAimRate)
	{
		f_SGAimRate = StringToFloat(newValue);
	}
	else if(convar==cvarSGBullets)
	{
		i_SGBullets = StringToInt(newValue);
	}
	else if(convar==cvarSGShotMode)
	{
		i_SGShotMode = StringToInt(newValue);
	}
	else if(convar==cvarSGIdle)
	{
		i_SGIdle = StringToInt(newValue);
	}
	else if(convar==cvarSGAim)
	{
		i_SGAim = StringToInt(newValue);
	}
	else if(convar==cvarSGHealth)
	{
		i_SGHealth = StringToInt(newValue);
	}
	else if(convar==cvarSGAmmo)
	{
		i_SGAmmo = StringToInt(newValue);
	}
}

public void OnMapStart()
{
	PrecacheModel(MDL_GUN, true);
	PrecacheSound(SND_SHOOT, true);
	
	f_SGFire = GetConVarFloat(cvarSGFire);
	f_SGDmg = GetConVarFloat(cvarSGDmg);
	f_SGRange = GetConVarFloat(cvarSGRange);
	f_SGTurn = GetConVarFloat(cvarSGTurn);
	f_SGSpread = GetConVarFloat(cvarSGSpread);
	f_SGAimRate = GetConVarFloat(cvarSGAimRate);
	i_SGBullets = GetConVarInt(cvarSGBullets);
	i_SGShotMode = GetConVarInt(cvarSGShotMode);
	i_SGIdle = GetConVarInt(cvarSGIdle);
	i_SGAim = GetConVarInt(cvarSGAim);
	i_SGHealth = GetConVarInt(cvarSGHealth);
	i_SGAmmo = GetConVarInt(cvarSGAmmo);
	//sanity stuff
	for(new client=1; client<=MaxClients; client++)
	{
		HasPerk[client] = false;
		LastSGHit[client] = 0.0;
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
    RTD2_ObtainPerk("shouldergun") // create perk using unique token "mytoken"
        .SetName("Shoulder Gun") // set perk's name
        .SetGood(true) // make the perk good
		.SetTime(0)
        .SetSound("vo/engineer_littlesentry03.mp3") // set activation sound
		.SetClasses("") // make the perk applicable only to Soldier, Pyro and Heavy
        .SetWeaponClasses("") // make the perk applicable only to clients holding a shotgun
        .SetTags("good, gun, sentry, sentrygun, shoulder, mvm_bot") // set perk's search tags
        .SetCall(MyPerk_Call); // set which function should be called for activation/deactivation
}

public void MyPerk_Call(int client, RTDPerk perk, bool bEnable)
{
    if(bEnable)
	{
		HasPerk[client]=true;
		GunNextShot[client]=GetGameTime()+f_SGFire;
		if(i_SGAim && f_SGAimRate>=0.05)
		{
			GunNextAim[client]=GetGameTime()+f_SGAimRate;
		}
		CreateShoulderGun(client);
		if(i_SGAim)
		{
			PrintToChat(client, "You have a shoulder mounted sentry that aims and fires independently.");
		}
		else
		{
			if(i_SGShotMode==1)
			{
				PrintToChat(client, "You have a shoulder mounted sentry that tracks your aim and fires constantly.");
			}
			else if(i_SGShotMode==2)
			{
				PrintToChat(client, "You have a shoulder mounted sentry that tracks your aim and fires when attacking.");
			}
			else
			{
				PrintToChat(client, "You have a shoulder mounted sentry that does... nothing, what?");
			}
		}
	}
	else
	{
		HasPerk[client]=false;
		RemoveShoulderGun(client);
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

public Action:OnPlayerDeath(Handle:event, const String:eventName[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(client))
	{
		if(IsValidClient(attacker))
		{
			if(HasPerk[attacker])
			{
				if(LastSGHit[attacker]>=GetGameTime())
				{
					SetEventString(event, "weapon_logclassname", "rtd_shouldergun");
					SetEventString(event, "weapon", "obj_minisentry");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(IsValidClient(client))
	{
		if(HasPerk[client])
		{
			g_CurButtons[client]=buttons;
			new guntarget = GetClientOfUserId(LastGunTarget[client]);
			if(IsValidClient(guntarget) && !IsPlayerAlive(guntarget))
			{
				LastGunTarget[client]=-1;
				guntarget = -1;
			}
			else if(!IsValidClient(guntarget))
			{
				guntarget = EntRefToEntIndex(LastGunTarget[client]);
				if(guntarget<1 || !IsValidEntity(guntarget))
				{
					LastGunTarget[client]=-1;
					guntarget = -1;
				}
			}		
			new Float:clientPosition[3];
			new Float:targetPosition[3];
			GetClientEyePosition(client, clientPosition);
			if(i_SGAim)
			{
				if(f_SGAimRate<0.05 || GunNextAim[client]<=GetGameTime())
				{
					//2. we get the closest enemy AND we check if something is already in view to shoot
					guntarget = -1;
					FoundTarget[client]=false;
					new Float:shotdistance = f_SGRange;
					new Float:viewdistance = f_SGRange;
					new Float:dist = 0.0;
					new Float:ViewRange = 40.0;
					LastGunOffset[client] = 40.0;
					for(new target=1; target<=MaxClients; target++)
					{
						if(IsValidClient(target) && IsPlayerAlive(target) && GetDisguiseTeam(target)!=GetClientTeam(client) && !IsCloaked(target))
						{
							GetClientEyePosition(target, targetPosition);
							dist = GetVectorDistance(clientPosition, targetPosition);
							if(dist<=f_SGRange)
							{
								if(InClearView(clientPosition, targetPosition, client))
								{
									new Float:DaAngle[3];
									DaAngle[0] = GunAimAngle[client][0];
									DaAngle[1] = GunAimAngle[client][1];
									if(!FoundTarget[client] && dist<=viewdistance)
									{
										//we increase the field of vision if enemies are very close so the sentry can see them
										if(dist<=400.0)
										{
											ViewRange = 40.0+((400.0-dist)*0.15);
										}
										else
										{
											ViewRange = 40.0;
										}
										if(IsTargetInSightCone(client, target, DaAngle, ViewRange, f_SGRange, true))
										{
											viewdistance = dist;
											FoundTarget[client]=true;
										}
									}
									if(dist<=shotdistance)
									{
										shotdistance = dist;
										LastGunTarget[client] = GetClientUserId(target);
										guntarget = target;
									}
								}
							}
						}
					}
					//if we didn't find a human target we'll find buildings instead
					if(guntarget==-1)
					{
						new ent = -1;
						while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
						{
							if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetClientTeam(client))
							{
								GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", targetPosition);
								dist = GetVectorDistance(clientPosition, targetPosition);
								if(dist<=viewdistance)
								{
									if(InClearView(clientPosition, targetPosition, client))
									{
										new Float:DaAngle[3];
										DaAngle[0] = GunAimAngle[client][0];
										DaAngle[1] = GunAimAngle[client][1];
										if(!FoundTarget[client] && IsTargetInSightCone(client, ent, DaAngle, 60.0, f_SGRange, true))
										{
											viewdistance = dist;
											FoundTarget[client]=true;
										}
										if(dist<=shotdistance)
										{
											shotdistance = dist;
											guntarget = ent;
											LastGunTarget[client] = EntIndexToEntRef(guntarget);
											LastGunOffset[client] = 30.0;
										}
									}
								}
							}
						}
						while((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
						{
							if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetClientTeam(client))
							{
								GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", targetPosition);
								dist = GetVectorDistance(clientPosition, targetPosition);
								if(dist<=viewdistance)
								{
									if(InClearView(clientPosition, targetPosition, client))
									{
										new Float:DaAngle[3];
										DaAngle[0] = GunAimAngle[client][0];
										DaAngle[1] = GunAimAngle[client][1];
										if(!FoundTarget[client] && IsTargetInSightCone(client, ent, DaAngle, 60.0, f_SGRange, true))
										{
											viewdistance = dist;
											FoundTarget[client]=true;
										}
										if(dist<=shotdistance)
										{
											shotdistance = dist;
											guntarget = ent;
											LastGunTarget[client] = EntIndexToEntRef(guntarget);
											LastGunOffset[client] = 25.0;
										}
									}
								}
							}
						}
						while((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
						{
							if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetClientTeam(client))
							{
								GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", targetPosition);
								dist = GetVectorDistance(clientPosition, targetPosition);
								if(dist<=viewdistance)
								{
									if(!FoundTarget[client] && InClearView(clientPosition, targetPosition, client))
									{
										new Float:DaAngle[3];
										DaAngle[0] = GunAimAngle[client][0];
										DaAngle[1] = GunAimAngle[client][1];
										if(IsTargetInSightCone(client, ent, DaAngle, 60.0, f_SGRange, true))
										{
											viewdistance = dist;
											FoundTarget[client]=true;
										}
										if(dist<=shotdistance)
										{
											shotdistance = dist;
											guntarget = ent;
											LastGunTarget[client] = EntIndexToEntRef(guntarget);
											LastGunOffset[client] = 10.0;
										}
									}
								}
							}
						}
					}
					if(f_SGAimRate>=0.05)
					{
						GunNextAim[client]=GetGameTime()+f_SGAimRate;
					}
				}
			}
			//3. we rotate the sentry to our target
			if(guntarget>0 && IsValidEntity(guntarget))
			{
				new Float:vBuffer[3], Float:DesiredAngle[3];
				GetEntPropVector(guntarget, Prop_Data, "m_vecAbsOrigin", targetPosition);
				targetPosition[2]+=GetEntPropFloat(guntarget, Prop_Send, "m_flModelScale")*LastGunOffset[client];
				SubtractVectors(targetPosition, clientPosition, vBuffer); 
				NormalizeVector(vBuffer, vBuffer); 
				GetVectorAngles(vBuffer, DesiredAngle); 
				//Y = left to right?
				//X = up and down?
				new Float:VXAngle = GunAimAngle[client][0];
				new Float:VYAngle = GunAimAngle[client][1];
				new Float:DXAngle = DesiredAngle[0];
				new Float:DYAngle = DesiredAngle[1];
				
				if(DXAngle>180.0)
				{
					DXAngle-=360.0;
				}
				else if(DYAngle<-180.0)
				{
					DXAngle+=360.0;
				}
				
				if(DXAngle>60.0)
				{
					DXAngle=60.0;
				}
				else if(DXAngle<-60.0)
				{
					DXAngle=-60.0;
				}
				
				if(DYAngle>180.0)
				{
					DYAngle-=360.0;
				}
				else if(DYAngle<-180.0)
				{
					DYAngle+=360.0;
				}
				
				if(VXAngle-DXAngle<=0.0)
				{
					VXAngle+=f_SGTurn*1.5;
				}
				else
				{
					VXAngle-=f_SGTurn*1.5;
				}
				if(RotateWhichDirection(VYAngle, DYAngle)==1)
				{
					//we start rotating downwards
					VYAngle+=f_SGTurn*1.5;
					if(RotateWhichDirection(VYAngle, DYAngle)==2)
					{
						VYAngle = DYAngle;
					}
				}
				else if(RotateWhichDirection(VYAngle, DYAngle)==2)
				{
					//we start rotating upwards
					VYAngle-=f_SGTurn*1.5;
					if(RotateWhichDirection(VYAngle, DYAngle)==1)
					{
						VYAngle = DYAngle;
					}
				}
				GunAimAngle[client][0] = VXAngle;
				GunAimAngle[client][1] = VYAngle;
			}
			else
			{
				if(i_SGIdle==1)
				{
					//SPEEEEEEEN TO WEEEEN
					if(GunAimAngle[client][0]>60.0)
					{
						GunAimAngle[client][0]=60.0;
					}
					else if(GunAimAngle[client][0]<-60.0)
					{
						GunAimAngle[client][0]=-60.0;
					}
					if(GunAimAngle[client][0]<=0.0)
					{
						GunAimAngle[client][0]+=f_SGTurn;
						if(GunAimAngle[client][0]>0.0)
						{
							GunAimAngle[client][0]=0.0;
						}
					}
					else
					{
						GunAimAngle[client][0]-=f_SGTurn;
						if(GunAimAngle[client][0]<0.0)
						{
							GunAimAngle[client][0]=0.0;
						}
					}
					GunAimAngle[client][1]+=f_SGTurn;
				}
				else
				{
					//no target was found, rotate to player's view
					new Float:DesiredAngle[3];
					GetClientEyeAngles(client, DesiredAngle);
					//Y = left to right?
					//X = up and down?
					new Float:VXAngle = GunAimAngle[client][0];
					new Float:VYAngle = GunAimAngle[client][1];
					new Float:DXAngle = DesiredAngle[0];
					new Float:DYAngle = DesiredAngle[1];
					if(DXAngle>60.0)
					{
						DXAngle=60.0;
					}
					else if(DXAngle<-60.0)
					{
						DXAngle=-60.0;
					}
					if(VXAngle-DXAngle<=0.0)
					{
						VXAngle+=f_SGTurn;
						if(VXAngle>DXAngle)
						{
							VXAngle=DXAngle;
						}
					}
					else
					{
						VXAngle-=f_SGTurn;
						if(VXAngle<DXAngle)
						{
							VXAngle=DXAngle;
						}
					}
					if(RotateWhichDirection(VYAngle, DYAngle)==1)
					{
						//we start rotating downwards
						VYAngle+=f_SGTurn;
						if(RotateWhichDirection(VYAngle, DYAngle)==2)
						{
							VYAngle = DYAngle;
						}
					}
					else if(RotateWhichDirection(VYAngle, DYAngle)==2)
					{
						//we start rotating upwards
						VYAngle-=f_SGTurn;
						if(RotateWhichDirection(VYAngle, DYAngle)==1)
						{
							VYAngle = DYAngle;
						}
					}
					GunAimAngle[client][0] = VXAngle;
					GunAimAngle[client][1] = VYAngle;
				}
			}
			///4. We manually correct the aim angles so the sentry doesn't look in awkward directions
			if(GunAimAngle[client][0]<-60.0)
			{
				GunAimAngle[client][0]=-60.0;
			}
			else if(GunAimAngle[client][0]>60.0)
			{
				GunAimAngle[client][0]=60.0;
			}
			if(GunAimAngle[client][1]>180.0)
			{
				GunAimAngle[client][1]-=360.0;
			}
			else if(GunAimAngle[client][1]<-180.0)
			{
				GunAimAngle[client][1]+=360.0;
			}
			if(GunNextShot[client]<=GetGameTime())
			{
				if(FoundTarget[client])
				{
					FireShoulderGun(client);
					GunNextShot[client]=GetGameTime()+f_SGFire;
				}
				else if(i_SGShotMode==1)
				{
					FireShoulderGun(client);
					GunNextShot[client]=GetGameTime()+f_SGFire;
				}
				else if(i_SGShotMode==2)
				{
					if(buttons & IN_ATTACK)
					{
						FireShoulderGun(client);
						GunNextShot[client]=GetGameTime()+f_SGFire;
					}
				}
			}
			SetShoulderGunPos(client);
		}
	}
}

SetShoulderGunPos(client)
{
    if(IsValidClient(client))
	{
	    if(ShoulderGunRef[client]!=0)
		{
		    new entity = EntRefToEntIndex(ShoulderGunRef[client]);
			if(HasEntProp(entity, Prop_Data, "m_iName"))
			{
			    new String:classname[255];
		        GetEntityClassname(entity, classname, sizeof(classname));
			    if(StrEqual(classname, "prop_dynamic"))
				{
				    new Float:position[3], Float:DesiredAngle[3], Float:vBuffer[3];
					new Float:footpos[3];
					new Float:PlayerScale = GetEntPropFloat(client, Prop_Send, "m_flModelScale"); //scale
					GetEntPropVector(client, Prop_Send, "m_vecOrigin", footpos);
					GetClientEyePosition(client, position);
					GetClientEyeAngles(client, DesiredAngle);
					DesiredAngle[0] = 0.0;
					DesiredAngle[1] +=110.0;
					GetAngleVectors(DesiredAngle, vBuffer, NULL_VECTOR, NULL_VECTOR);
					
					
					//player size is 83.0 by default
					//63.0 when ducking
					new Float:sizeoffset[4];
					switch(TF2_GetPlayerClass(client))
					{
						case TFClass_Scout:
						{
							sizeoffset[0]=7.5;
							sizeoffset[1]=7.5;
							sizeoffset[2]=50.0;
							sizeoffset[3]=16.0;
						}
						case TFClass_Soldier:
						{
							sizeoffset[0]=8.5;
							sizeoffset[1]=8.5;
							sizeoffset[2]=55.5;
							sizeoffset[3]=12.5;
						}
						case TFClass_Pyro:
						{
							sizeoffset[0]=6.5;
							sizeoffset[1]=6.5;
							sizeoffset[2]=52.5;
							sizeoffset[3]=14.0;
						}
						case TFClass_DemoMan:
						{
							sizeoffset[0]=8.5;
							sizeoffset[1]=8.5;
							sizeoffset[2]=59.5;
							sizeoffset[3]=8.5;
						}
						case TFClass_Heavy:
						{
							sizeoffset[0]=15.5;
							sizeoffset[1]=15.5;
							sizeoffset[2]=61.5;
							sizeoffset[3]=13.0;
						}
						case TFClass_Engineer:
						{
							sizeoffset[0]=8.5;
							sizeoffset[1]=8.5;
							sizeoffset[2]=51.5;
							sizeoffset[3]=14.0;
						}
						case TFClass_Medic:
						{
							sizeoffset[0]=8.5;
							sizeoffset[1]=8.5;
							sizeoffset[2]=58.5;
							sizeoffset[3]=20.0;
						}
						case TFClass_Sniper:
						{
							sizeoffset[0]=7.5;
							sizeoffset[1]=8.5;
							sizeoffset[2]=61.5;
							sizeoffset[3]=16.5;
						}
						case TFClass_Spy:
						{
							sizeoffset[0]=7.5;
							sizeoffset[1]=7.5;
							sizeoffset[2]=58.5;
							sizeoffset[3]=20.0;
						}
					}
					
				    position[0]+=vBuffer[0]*sizeoffset[0];
				    position[1]+=vBuffer[1]*sizeoffset[1];
					position[2]=footpos[2]+(PlayerScale*sizeoffset[2]);
					
					if(g_CurButtons[client] & IN_DUCK)
					{
						if(GetEntityFlags(client) & FL_ONGROUND)
						{
							position[2]-=PlayerScale*sizeoffset[3];
						}
					}
					
					//just a bit of prediciton for velocity
					new Float:vVel[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel); //velocity
					position[0]+=vVel[0]*0.03;
				    position[1]+=vVel[1]*0.03;
				    position[2]+=vVel[2]*0.02;
					
					DesiredAngle[0] = GunAimAngle[client][0];
					DesiredAngle[1] = GunAimAngle[client][1];
					DesiredAngle[2] = GunAimAngle[client][2];
					TeleportEntity(entity, position, DesiredAngle, NULL_VECTOR);
				}
			}
		}
	}
}

FireShoulderGun(client)
{
	if(IsValidClient(client))
	{
		new Float:FirePos[3], Float:position[3], Float:shotangle[3];
		GetClientEyePosition(client, position);
		
		BulletTraceShooter=client;
		EmitSoundToAll(SND_SHOOT, client, _, SNDLEVEL_SCREAMING);
		
		for(new i = 0; i < i_SGBullets; i++)
		{
			if(f_SGSpread==0.0)
			{
				GetAngleVectors(GunAimAngle[client], FirePos, NULL_VECTOR, NULL_VECTOR);
			}
			else
			{
				shotangle[0] = GunAimAngle[client][0]+GetRandomFloat(f_SGSpread*-1.0, f_SGSpread);
				shotangle[1] = GunAimAngle[client][1]+GetRandomFloat(f_SGSpread*-1.0, f_SGSpread);
				GetAngleVectors(shotangle, FirePos, NULL_VECTOR, NULL_VECTOR);
			}
			ScaleVector(FirePos, 56754.0);
			AddVectors(position, FirePos, FirePos);
			
			FireBulletTracer(position, FirePos, client);
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
			DispatchKeyValue(client,"targetname","targetsname_shouldergun");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_shouldergun");
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
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

CreateShoulderGun(client)
{
    if(IsValidClient(client))
	{
	    ShoulderGunRef[client]=0;
		new entity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(entity, "model", MDL_GUN); 
		DispatchSpawn(entity);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
		SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
		ShoulderGunRef[client] = EntIndexToEntRef(entity);
		GetClientEyeAngles(client, GunAimAngle[client]);
		SetShoulderGunPos(client);
	}
}

RemoveShoulderGun(client)
{
    if(IsValidClient(client))
	{
	    if(ShoulderGunRef[client]!=0)
		{
		    new entity = EntRefToEntIndex(ShoulderGunRef[client]);
			if(IsValidEntity(entity))
			{
			    if(HasEntProp(entity, Prop_Data, "m_iName"))
			    {
			        new String:classname[255];
		            GetEntityClassname(entity, classname, sizeof(classname));
			        if(StrEqual(classname, "prop_dynamic"))
				    {
						//before deleting the model we spawn a minisentry to dismount from their shoulder
						if(i_SGHealth>0)
						{
							new Float:loc[3];
							new Float:foot[3];
							new Float:vel[3];
							GunAimAngle[client][0] = 0.0;
							GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", loc);
							GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", foot);
							GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel); //velocity
							loc[2]=foot[2]+GetEntPropFloat(client, Prop_Send, "m_flModelScale")*84.0;
							vel[2]+=100.0;
							DismountSentrty(client, loc, GunAimAngle[client], vel);
						}
						//now we delete
				        AcceptEntityInput(entity, "Kill");
					    ShoulderGunRef[client]=0;
				    }
			    }
			}
		}
	}
}

DismountSentrty(client, Float:location[3], Float:angles[3], Float:velocity[3])
{
    new entity = CreateEntityByName("obj_sentrygun"); // Sentry
	if(IsValidEntity(entity) && IsValidClient(client))
	{
		SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
		SetVariantInt(GetClientTeam(client));
		AcceptEntityInput(entity, "SetTeam");
		
		TeleportEntity(entity, location, angles, velocity);
		AcceptEntityInput(entity, "SetBuilder", client);
		
		SetEntProp(entity, Prop_Send, "m_bDisposableBuilding", 1);
		SetEntProp(entity, Prop_Send, "m_bMiniBuilding", 1);
		SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", 1);
		SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", 1);
		SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
		
		//SetEntProp(entity, Prop_Data, "m_spawnflags", 8);
		//2 : Invulnerable
		//4 : Upgradable
		//8 : Infinite Ammo
		SetEntProp(entity, Prop_Send, "m_bBuilding", 1);		//This is crucial
		DispatchSpawn(entity);
		
		CreateTimer(0.3, Timer_SetSentryStat, EntIndexToEntRef(entity));
	}
}

public Action:Timer_SetSentryStat(Handle:timer, entity)
{
	entity = EntRefToEntIndex(entity);
    if(IsValidEntity(entity))
	{
		SetEntProp(entity, Prop_Send, "m_iAmmoShells", i_SGAmmo);
		SetEntProp(entity, Prop_Send, "m_iMaxHealth", i_SGHealth);
		SetEntProp(entity, Prop_Send, "m_iHealth", i_SGHealth);
	}
}

stock GetDisguiseTeam(client)
{
    if(IsValidClient(client))
	{
	    if(TF2_IsPlayerInCondition(client, TFCond_Disguised)) //actually has the disguise condition
	    {
		    return GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
	    }
		else
		{
			return GetClientTeam(client);
		}
	}
	return -1;
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

//used to figure out the shortest route to turn the sentry's left & right to get the desired target
stock RotateWhichDirection(Float:Angle, Float:DesiredAngle)
{
    Angle+=180.0;
	DesiredAngle+=180.0;
	//PrintToChatAll("%.0f", Angle);
	new Float:Diff = Angle-DesiredAngle;
	if(Diff<0.0)
	{
	    Diff*=-1.0;
	}
	if(Angle < DesiredAngle)
	{
	    if(Diff<180.0)
		{
		    return 1; //+
		}
		else
		{
		    return 2; //-
		}
	}
	else
	{
	    if(Diff<180.0)
		{
		    return 2; //-
		}
		else
		{
		    return 1; //+
		}
	}
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

FireBulletTracer(Float:pos2[3], Float:pos[3], entity)
{
    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilter_Bullet, entity);
	if(hTrace != INVALID_HANDLE)
	{
		new Float:loc[3];
		new Float:locsent[3];
		TR_GetEndPosition(loc, hTrace);
		if(ShoulderGunRef[entity]!=0)
		{
			new entity1 = EntRefToEntIndex(ShoulderGunRef[entity]);
			if(IsValidEntity(entity1))
			{
				if(HasEntProp(entity1, Prop_Data, "m_iName"))
				{
					new String:classname[255];
					GetEntityClassname(entity1, classname, sizeof(classname));
					if(StrEqual(classname, "prop_dynamic"))
					{
						GetEntPropVector(entity1, Prop_Data, "m_vecAbsOrigin", locsent);
						locsent[2]+=GetEntPropFloat(entity1, Prop_Send, "m_flModelScale")*37.0;
					}
				}
			}
		}
		FireTracerEffect(locsent, loc);
        CloseHandle(hTrace);
	}
}

stock bool:TraceFilter_Bullet(entity, contentsMask, any:ent)
{
	if(IsValidClient(entity))
	{
	    if(IsPlayerAlive(entity) && GetClientTeam(entity)!=GetClientTeam(BulletTraceShooter))
		{
			LastSGHit[BulletTraceShooter]=GetGameTime();
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
		    return true;
		}
		else
		{
		    return false;
		}
	}
	else if(IsValidEntity(entity))
	{
		new String:ClassName[255];
		GetEntityClassname(entity, ClassName, sizeof(ClassName));
		if(StrContains(ClassName, "obj_", false)!=-1) //buildings and sapper attatchments
		{
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
		    return true;
		}
		else if(StrContains(ClassName, "_boss", false)!=-1) //mvm tank and eyeball boss
		{
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
		    return true;
		}
		else if(StrEqual(ClassName, "merasmus", false)) //merasmus
		{
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
		    return true;
		}
		else if(StrEqual(ClassName, "headless_hatman", false)) //headless_hatman
		{
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
		    return true;
		}
		else if(StrEqual(ClassName, "tf_zombie", false)) //skelemen
		{
			DamageEntity(entity, BulletTraceShooter, f_SGDmg, 2232322);
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


//Not my code either, however it was changed to not parent the particle system for the purpose of bullet tracers
FireTracerEffect(Float:loc1[3], Float:loc2[3])
{
	new particle  = CreateEntityByName("info_particle_system");
	new particle2 = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new String:cpName[128];
		Format(cpName, sizeof(cpName), "target%i", BulletCycle);
		DispatchKeyValue(particle, "targetname", cpName);
		BulletCycle+=1;

		//--------------------------------------
		new String:cp2Name[128];
		Format(cp2Name, sizeof(cp2Name), "tf2particle%i", BulletCycle);
		BulletCycle+=1;

		DispatchKeyValue(particle2, "targetname", cp2Name);
		DispatchKeyValue(particle2, "parentname", cpName);
		//-----------------------------------------------


		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", "bullet_tracer01");
		DispatchKeyValue(particle, "cpoint1", cp2Name);

		DispatchSpawn(particle);
		TeleportEntity(particle, loc1, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(particle2, loc2, NULL_VECTOR, NULL_VECTOR);

		//The particle is finally ready
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		
		if(BulletCycle>99)
		{
			BulletCycle=0;
		}
		CreateTimer(1.0, Timer_KillEntity, EntIndexToEntRef(particle));
		CreateTimer(1.0, Timer_KillEntity, EntIndexToEntRef(particle2));
	}
}

public Action:Timer_KillEntity(Handle:timer, entity)
{
	entity = EntRefToEntIndex(entity);
    if(IsValidEntity(entity))
	{
	    AcceptEntityInput(entity, "kill");
	}
}