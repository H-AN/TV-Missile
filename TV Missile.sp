#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "[华仔]巡飞弹", 
    author = "华仔 H-AN", 
    description = "华仔 H-AN 巡飞弹", 
    version = "1.0", 
    url = "[华仔]特殊武器,巡飞弹, QQ群107866133, github https://github.com/H-AN"
};

#define MAX_FLAME_WEAPONS 32
char g_TvWeapons[MAX_FLAME_WEAPONS][64];
int g_TvWeaponsCount = 0;

char g_FlySounds[16][PLATFORM_MAX_PATH];
int g_FlySoundsCount = 0;

char g_ExpSounds[16][PLATFORM_MAX_PATH];
int g_ExpSoundsCount = 0;

char g_FireSounds[16][PLATFORM_MAX_PATH];
int g_FireSoundsCount = 0;

char g_OverSounds[16][PLATFORM_MAX_PATH];
int g_OverSoundsCount = 0;

char g_OverlayZoom[PLATFORM_MAX_PATH];
char g_OverOverlay[PLATFORM_MAX_PATH];

enum struct TVMissileConfig
{
    ConVar TVMissileINTERVAL;
    ConVar TVMissileSPEED;
    ConVar TVMissileTURNFACTOR;
    ConVar TVMissileDMG;
    ConVar TVMissileFlySound;
    ConVar TVMissileExplosionSound;
    ConVar TVMissileFlyOVERLAY;
    ConVar TVMissileEndOVERLAY;
}
TVMissileConfig g_TVMissileConfig;

bool Isfreeze;
Handle g_hGuideTimer[MAXPLAYERS+1];
bool g_bGuiding[MAXPLAYERS+1];
int g_iGuideOwner[2048];

float SmokeOrigin[3] = {-30.0,0.0,0.0};
float SmokeAngle[3] = {0.0,-180.0,0.0};

public void OnPluginStart()
{
    HookEvent("player_death", Event_Death);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_freeze_end", RoundFreezeEnd);

    g_TVMissileConfig.TVMissileINTERVAL = CreateConVar("tv_interval", "0.02", "TV弹飞行接受指令更新间隔");
    g_TVMissileConfig.TVMissileSPEED = CreateConVar("tv_speed", "400.0", "TV弹飞行速度");
    g_TVMissileConfig.TVMissileTURNFACTOR = CreateConVar("tv_turnfactor", "0.2", "TV弹转向速度");
    g_TVMissileConfig.TVMissileDMG = CreateConVar("tv_damage", "100.0", "TV弹伤害");
    g_TVMissileConfig.TVMissileFlySound = CreateConVar("tv_flysound", "1", "TV弹飞行是否播放火箭音效");
    g_TVMissileConfig.TVMissileExplosionSound = CreateConVar("tv_expsound", "1", "TV弹是否播放爆炸音效");
    g_TVMissileConfig.TVMissileFlyOVERLAY = CreateConVar("tv_flyoverlay", "1", "是否开启飞弹飞行叠加层");
    g_TVMissileConfig.TVMissileEndOVERLAY = CreateConVar("tv_endoverlay", "1", "是否开启飞弹结束叠加层");
}

public OnMapStart()
{
    LoadTVMissileConfig();
	PrecacheModel("models/Items/ar2_grenade.mdl");
}

void LoadTVMissileConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/TVMissile.cfg");

    if (!FileExists(path))
    {
        WriteDefaultConfig(path);
        PrintToServer("[TV Missile] 配置文件不存在，已生成默认配置！");
    }

    KeyValues kv = new KeyValues("TVMissile");
    if (!FileToKeyValues(kv, path))
    {
        PrintToServer("[TV Missile] 配置读取失败！");
        delete kv;
        return;
    }

    char raw[512];
    KvGetString(kv, "tvweapon", raw, sizeof(raw));
    TrimString(raw);

    PrintToServer("[TV Missile] 原始读取: '%s' 长度 %d", raw, strlen(raw));

    // 分割字符串
    char weapons[32][64];
    int count = ExplodeString(raw, ",", weapons, sizeof(weapons), sizeof(weapons[]));
    g_TvWeaponsCount = 0;

    for (int i = 0; i < count; i++)
    {
        TrimString(weapons[i]);
        if (strlen(weapons[i]) == 0) continue;

        strcopy(g_TvWeapons[g_TvWeaponsCount], sizeof(g_TvWeapons[]), weapons[i]);
        PrintToServer("[TV Missile] 配置文件中TV弹武器[%d]: %s", g_TvWeaponsCount, g_TvWeapons[g_TvWeaponsCount]);
        g_TvWeaponsCount++;
    }

    if (g_TvWeaponsCount == 0)
    {
        PrintToServer("[TV Missile] 警告：没有有效的TV弹武器配置！");
    }

    char rawSounds[512];
    KvGetString(kv, "flysound", rawSounds, sizeof(rawSounds));
    TrimString(rawSounds);

    char sounds[16][PLATFORM_MAX_PATH];
    int soundcount = ExplodeString(rawSounds, ",", sounds, sizeof(sounds), sizeof(sounds[0]));
    g_FlySoundsCount = 0;

    for (int i = 0; i < soundcount && g_FlySoundsCount < 16; i++)
    {
        TrimString(sounds[i]);
        if (strlen(sounds[i]) == 0) continue;

        strcopy(g_FlySounds[g_FlySoundsCount], sizeof(g_FlySounds[]), sounds[i]);

        PrecacheSound(g_FlySounds[g_FlySoundsCount]);
        PrintToServer("[TV Missile] 预缓存导弹飞行音效[%d]: %s", g_FlySoundsCount, g_FlySounds[g_FlySoundsCount]);
        g_FlySoundsCount++;
    }

    char ExpSounds[512];
    KvGetString(kv, "expsound", ExpSounds, sizeof(ExpSounds));
    TrimString(ExpSounds);

    char soundexps[16][PLATFORM_MAX_PATH];
    int expsoundcount = ExplodeString(ExpSounds, ",", soundexps, sizeof(soundexps), sizeof(soundexps[0]));
    g_ExpSoundsCount = 0;

    for (int i = 0; i < expsoundcount && g_ExpSoundsCount < 16; i++)
    {
        TrimString(soundexps[i]);
        if (strlen(soundexps[i]) == 0) continue;

        strcopy(g_ExpSounds[g_ExpSoundsCount], sizeof(g_ExpSounds[]), soundexps[i]);

        PrecacheSound(g_ExpSounds[g_ExpSoundsCount]);
        PrintToServer("[TV Missile] 预缓存导弹爆炸音效[%d]: %s", g_ExpSoundsCount, g_ExpSounds[g_ExpSoundsCount]);
        g_ExpSoundsCount++;
    }

    char FireSounds[512];
    KvGetString(kv, "firesound", FireSounds, sizeof(FireSounds));
    TrimString(FireSounds);

    char soundfires[16][PLATFORM_MAX_PATH];
    int firesoundcount = ExplodeString(FireSounds, ",", soundfires, sizeof(soundfires), sizeof(soundfires[0]));
    g_FireSoundsCount = 0;

    for (int i = 0; i < firesoundcount && g_FireSoundsCount < 16; i++)
    {
        TrimString(soundfires[i]);
        if (strlen(soundfires[i]) == 0) continue;

        strcopy(g_FireSounds[g_FireSoundsCount], sizeof(g_FireSounds[]), soundfires[i]);

        PrecacheSound(g_FireSounds[g_FireSoundsCount]);
        PrintToServer("[TV Missile] 预缓存导弹发射音效[%d]: %s", g_FireSoundsCount, g_FireSounds[g_FireSoundsCount]);
        g_FireSoundsCount++;
    }

    char OverSounds[512];
    KvGetString(kv, "oversound", OverSounds, sizeof(OverSounds));
    TrimString(OverSounds);

    char soundover[16][PLATFORM_MAX_PATH];
    int oversoundcount = ExplodeString(OverSounds, ",", soundover, sizeof(soundover), sizeof(soundover[0]));
    g_OverSoundsCount = 0;

    for (int i = 0; i < oversoundcount && g_OverSoundsCount < 16; i++)
    {
        TrimString(soundover[i]);
        if (strlen(soundover[i]) == 0) continue;

        strcopy(g_OverSounds[g_OverSoundsCount], sizeof(g_OverSounds[]), soundover[i]);

        PrecacheSound(g_OverSounds[g_OverSoundsCount]);
        PrintToServer("[TV Missile] 预缓存花屏音效[%d]: %s", g_OverSoundsCount, g_OverSounds[g_OverSoundsCount]);
        g_OverSoundsCount++;
    }

    KvGetString(kv, "overlayzoom", g_OverlayZoom, sizeof(g_OverlayZoom));
    TrimString(g_OverlayZoom);
    if (strlen(g_OverlayZoom) > 0)
    {
        char path1[PLATFORM_MAX_PATH];
        Format(path1, sizeof(path1), "%s.vmt", g_OverlayZoom);
        PrecacheGeneric(path1, true);

        Format(path1, sizeof(path1), "%s.vtf", g_OverlayZoom);
        PrecacheGeneric(path1, true);

        PrintToServer("[TV Missile] 导弹准星 Overlay: %s", g_OverlayZoom);
    }

    KvGetString(kv, "overoverlay", g_OverOverlay, sizeof(g_OverOverlay));
    TrimString(g_OverOverlay);
    if (strlen(g_OverOverlay) > 0)
    {
        char path2[PLATFORM_MAX_PATH];
        Format(path2, sizeof(path2), "%s.vmt", g_OverOverlay);
        PrecacheGeneric(path2, true);

        Format(path2, sizeof(path2), "%s.vtf", g_OverOverlay);
        PrecacheGeneric(path2, true);

        PrintToServer("[TV Missile] 花屏 Overlay: %s", g_OverOverlay);
    }

    delete kv;
}

// 写入默认配置
void WriteDefaultConfig(const char[] path)
{
    Handle file = OpenFile(path, "w");
    if (file == INVALID_HANDLE) return;

    WriteFileLine(file, "// TV Missile 配置文件");
    WriteFileLine(file, "// tvweapon 支持多个武器用 , 隔开(例如  weapon_scout,weapon_xunfeidan,weapon_m4a1 )");
    WriteFileLine(file, "// flysound 巡飞弹飞行音效 多个声路径用 , 隔开");
    WriteFileLine(file, "// expsound 巡飞弹爆炸音效 多个声路径用 , 隔开");
    WriteFileLine(file, "// firesound 巡飞弹发射音效 多个声路径用 , 隔开");
    WriteFileLine(file, "// oversound 巡飞弹结束花屏音效 多个声路径用 , 隔开");
    WriteFileLine(file, "// overlayzoom 巡飞弹飞行显示的准星叠加层 路径");
    WriteFileLine(file, "// overoverlay 巡飞弹结束花屏叠加层 路径");
    WriteFileLine(file, "\"TVMissile\"");
    WriteFileLine(file, "{");
    WriteFileLine(file, "    \"tvweapon\"    \"weapon_scout,weapon_xunfeidan\"");
    WriteFileLine(file, "    \"flysound\"    \"weapons/rpg/rocket1.wav\"");
    WriteFileLine(file, "    \"expsound\"    \"weapons/huazai/herosvd/explode3.wav,weapons/huazai/herosvd/explode4.wav,weapons/huazai/herosvd/explode5.wav\"");
    WriteFileLine(file, "    \"firesound\"    \"weapons/huazai/herosvd/svdex-launcher.wav\"");
    WriteFileLine(file, "    \"oversound\"    \"xuehua/xuehua.mp3\"");
    WriteFileLine(file, "    \"overlayzoom\"    \"overlays/xunfeidan/xunfei\"");
    WriteFileLine(file, "    \"overoverlay\"    \"overlays/xunfeidan/xuehua1\"");
    WriteFileLine(file, "}");

    CloseHandle(file);
}



public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponSwitch, WeaponHook);
}

public Action:WeaponHook(client, weapon)
{
    if(g_bGuiding[client])
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    Isfreeze = true;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsValidClient(i))
            return Plugin_Continue;

        if (g_hGuideTimer[i] != INVALID_HANDLE)
        {
            KillTimer(g_hGuideTimer[i]);
            g_hGuideTimer[i] = INVALID_HANDLE;
        }
        g_bGuiding[i] = false;
        SetClientViewEntity(i, i);
        SetEntityMoveType(i, MOVETYPE_WALK);
    }

    return Plugin_Continue;
}

public Action RoundFreezeEnd(Handle event, const String:name[], bool dontBroadcast)
{
    Isfreeze = false;

    return Plugin_Continue;
}

public Action Event_Death(Event event, const char[] name, bool dontBroadcast) 
{
		
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_hGuideTimer[client] != INVALID_HANDLE)
    {
        KillTimer(g_hGuideTimer[client]);
        g_hGuideTimer[client] = INVALID_HANDLE;
    }
    g_bGuiding[client] = false;

    return Plugin_Continue;

}

public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel[3], float angles[3], &weapon)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || client <= 0)
        return Plugin_Continue;

    char ClassName[30];
    int WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (WeaponIndex <= 0)
        return Plugin_Continue;

    GetEntityClassname(WeaponIndex, ClassName, sizeof(ClassName));
    
    if (IsTvWeapon(ClassName))
    {
        if(GetEntPropFloat(WeaponIndex, Prop_Data, "m_flNextPrimaryAttack") <= GetGameTime()
                && GetEntPropFloat(client, Prop_Data, "m_flNextAttack") <= GetGameTime()
                && !g_bGuiding[client] && !Isfreeze)
        {
                if (buttons & IN_ATTACK)
                {
                    if(!PlayerInGround(client))
                    {
                        PrintToChat(client, "你必须站在地上才能发射TV弹");
                    }
                    else
                    {
                        makecustumviewpunch(client);
                        CreateTimer(0.0, Missile2, client); 
                    }
                    SetEntPropFloat(WeaponIndex, Prop_Data, "m_flNextPrimaryAttack", FloatAdd(GetGameTime(), 0.8));      
                }
        }
    }
    return Plugin_Continue;
}

bool IsTvWeapon(const char[] weaponClass)
{
    char weapon[64];
    strcopy(weapon, sizeof(weapon), weaponClass); // 拷贝到可写缓冲区
    TrimString(weapon); 

    //PrintToServer("=== 检查武器: '%s' ===", weapon);

    for (int i = 0; i < g_TvWeaponsCount; i++)
    {
        if (StrEqual(weapon, g_TvWeapons[i], false))
        {
            return true;
        }
    }
    return false;
}

public Action Missile2(Handle timer, any client)
{
    float cleyepos[3], cleyeangle[3], Fwd[3];
    GetClientEyePosition(client, cleyepos);
    GetClientEyeAngles(client, cleyeangle);
    
    // 计算发射位置偏移
    GetAngleVectors(cleyeangle, Fwd, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(Fwd, Fwd);
    ScaleVector(Fwd, SquareRoot((16.0 * 16.0)+(16.0 * 16.0)));
    AddVectors(cleyepos, Fwd, cleyepos);
    
    CreateMissile(client, cleyepos, cleyeangle, 2500.0, MissileTouchHook);

    int randomExpIndex = GetRandomInt(0, g_FireSoundsCount-1);
    char soundPath[PLATFORM_MAX_PATH];
    strcopy(soundPath, sizeof(soundPath), g_FireSounds[randomExpIndex]);

    EmitSoundToAll(soundPath, client, SNDCHAN_WEAPON, SNDLEVEL_ROCKET);
    EmitSoundToAll(soundPath, client, SNDCHAN_STATIC, SNDLEVEL_NORMAL);

    return Plugin_Continue;
}

stock CreateMissile(client, float pos[3], float angle[3], float speed, SDKHookCB:callback)
{
    float anglevector[3];
    GetAngleVectors(angle, anglevector, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(anglevector, anglevector);
    ScaleVector(anglevector, speed);
    
    int entity = CreateEntityByName("hegrenade_projectile");
    if(entity == -1) return -1;
    
    DispatchSpawn(entity);
    
    // 设置碰撞体积
    float vecmax[3] = {1.0, 1.0, 1.0};
    float vecmin[3] = {-1.0, -1.0, -1.0};
    SetEntPropVector(entity, Prop_Send, "m_vecMins", vecmin);
    SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vecmax);
    
    // 设置模型和大小
    SetEntityModel(entity, "models/Items/ar2_grenade.mdl");
    SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 2.0); 
    
    TeleportEntity(entity, pos, angle, anglevector);

    int flysound = GetConVarInt(g_TVMissileConfig.TVMissileFlySound);
    if(flysound >= 1)
    {
        int randomIndex = GetRandomInt(0, g_FlySoundsCount-1);
        char soundPath[PLATFORM_MAX_PATH];
        strcopy(soundPath, sizeof(soundPath), g_FlySounds[randomIndex]);
        EmitSoundToAll(soundPath, entity, 1, 90);
    }
    StartGuidedRocket(client, entity);
    SetClientViewEntity(client, entity);

    int SmokeIndex = CreateEntityByName("env_rockettrail");
	if (SmokeIndex != -1)
	{
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_Opacity", 0.5);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_SpawnRate", 100.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_ParticleLifetime", 0.2);
		float SmokeBlue[3] = {1.0, 1.0, 1.0};
		SetEntPropVector(SmokeIndex, Prop_Send, "m_StartColor", SmokeBlue);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_StartSize", 5.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_EndSize", 30.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_SpawnRadius", 0.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_MinSpeed", 0.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_MaxSpeed", 10.0);
		SetEntPropFloat(SmokeIndex, Prop_Send, "m_flFlareScale", 1.0);

		DispatchSpawn(SmokeIndex);
		ActivateEntity(SmokeIndex);
		
		char NadeName[20];
		Format(NadeName, sizeof(NadeName), "Nade_%i", entity);
		DispatchKeyValue(entity, "targetname", NadeName);
		SetVariantString(NadeName);
		AcceptEntityInput(SmokeIndex, "SetParent");
		TeleportEntity(SmokeIndex, SmokeOrigin, SmokeAngle, NULL_VECTOR);
	}

    SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
    SDKHook(entity, SDKHook_StartTouch, callback);
    
    return entity;
}

public Action MissileTouchHook(entity, other)
{
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if(client == -1) return Plugin_Continue;
    
    float entityposition[3];    
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityposition);
    
    float dmg = g_TVMissileConfig.TVMissileDMG.FloatValue;
    int GrenadeDamage = RoundToZero(dmg);

    makeExplosion(client, entity, entityposition, "巡飞弹", GrenadeDamage, 250, 0.0);

    int expsound = GetConVarInt(g_TVMissileConfig.TVMissileExplosionSound);
    if(expsound >= 1)
    {
        int randomExpIndex = GetRandomInt(0, g_ExpSoundsCount-1);
        char expsoundPath[PLATFORM_MAX_PATH];
        strcopy(expsoundPath, sizeof(expsoundPath), g_ExpSounds[randomExpIndex]);

        EmitSoundToAll(expsoundPath, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, entityposition);
    }

    SetClientViewEntity(client, client);
    g_bGuiding[client] = false;
    if (g_hGuideTimer[client] != INVALID_HANDLE)
    {
        KillTimer(g_hGuideTimer[client]);
        g_hGuideTimer[client] = INVALID_HANDLE;
    }

    int flysound = GetConVarInt(g_TVMissileConfig.TVMissileFlySound);
    if(flysound >= 1)
    {
        int randomIndex = GetRandomInt(0, g_FlySoundsCount-1);
        char soundPath[PLATFORM_MAX_PATH];
        strcopy(soundPath, sizeof(soundPath), g_FlySounds[randomIndex]);
        StopSound(entity, 1, soundPath);
    }
    
    int endoverlay = GetConVarInt(g_TVMissileConfig.TVMissileEndOVERLAY);
    if(endoverlay >= 1)
    {
        int randomOverIndex = GetRandomInt(0, g_OverSoundsCount-1);
        char soundOverPath[PLATFORM_MAX_PATH];
        strcopy(soundOverPath, sizeof(soundOverPath), g_OverSounds[randomOverIndex]);
        EmitSoundToClient(client, soundOverPath);
        ShowOverlay(client, g_OverOverlay, 0.2);
    }
    AcceptEntityInput(entity, "Kill");

    SetEntityMoveType(client, MOVETYPE_WALK);

    return Plugin_Continue;

}

stock makeExplosion(attacker = 0, inflictor = -1, const Float:attackposition[3], const String:weaponname[] = "", magnitude = 0, radiusoverride = 0, float damageforce = 0.0, flags = 0)
{
	int explosion = CreateEntityByName("env_explosion");
	if(explosion != -1)
	{
    
		DispatchKeyValueVector(explosion, "Origin", attackposition);
		char intbuffer[64];
		IntToString(magnitude, intbuffer, 64);
		DispatchKeyValue(explosion,"iMagnitude", intbuffer);
		if(radiusoverride > 0)
		{
			IntToString(radiusoverride, intbuffer, 64);
			DispatchKeyValue(explosion,"iRadiusOverride", intbuffer);
		}
		if(damageforce > 0.0)
		{
			DispatchKeyValueFloat(explosion,"DamageForce", damageforce);
		}
		if(flags != 0)
		{
			IntToString(flags, intbuffer, 64);
			DispatchKeyValue(explosion,"spawnflags", intbuffer);
		}

		if(!StrEqual(weaponname, "", false))
		{
			DispatchKeyValue(explosion,"classname", weaponname);
			if(inflictor != -1)
			{
				DispatchKeyValue(inflictor,"classname", weaponname);
			}
		}
		DispatchSpawn(explosion);
		if(attacker != -1)
		{
			SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", attacker);
		}
		if(inflictor != -1)
		{
			SetEntPropEnt(explosion, Prop_Data, "m_hInflictor", inflictor);
		}
		AcceptEntityInput(explosion, "Explode");
		if(~flags & 0x00000002)
		{
			AcceptEntityInput(explosion, "Kill");
		}
		return explosion;
	}
	else
	{
		return -1;
	}
}

bool IsValidClient(int client)
{
    return (client >= 1 && client <= MaxClients && IsClientInGame(client) && !IsClientSourceTV(client));
}


void makecustumviewpunch(client){
	
	float angle[3] = {0.0, 0.0, 0.0};
		angle[0] = -15.0;
		angle[1] = GetRandomFloat(-4.0, 4.0);

	makeviewpunch(client, angle);
	
}

void makeviewpunch(client, float angle[3]){
	
	float oldangle[3];
	GetEntPropVector(client, Prop_Send, "m_vecPunchAngle", oldangle);
	oldangle[0] = oldangle[0] + angle[0];
	oldangle[1] = oldangle[1] + angle[1];
	oldangle[2] = oldangle[2] + angle[2];
	SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", oldangle);
	SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", angle);
	
}

public void StartGuidedRocket(int client, int entity)
{
    if (entity == -1 || !IsValidEntity(entity)) return;
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) return;

    g_bGuiding[client] = true;
    g_iGuideOwner[entity] = client;

    float interval = g_TVMissileConfig.TVMissileINTERVAL.FloatValue;
    g_hGuideTimer[client] = CreateTimer(interval, RocketGuidanceTimer, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action RocketGuidanceTimer(Handle timer, any ref)
{
    int entity = EntRefToEntIndex(ref);

    if (!IsValidEntity(entity)) return Plugin_Stop;

    int client = g_iGuideOwner[entity];
    if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    float ang[3];
    GetClientEyeAngles(client, ang);
    float fwd[3];
    GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);
    float curVel[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", curVel);
    NormalizeVector(curVel, curVel);
    float newDir[3], turnfactor;
    turnfactor = g_TVMissileConfig.TVMissileTURNFACTOR.FloatValue;
    newDir[0] = curVel[0] * (1.0 - turnfactor) + fwd[0] * turnfactor;
    newDir[1] = curVel[1] * (1.0 - turnfactor) + fwd[1] * turnfactor;
    newDir[2] = curVel[2] * (1.0 - turnfactor) + fwd[2] * turnfactor;
    NormalizeVector(newDir, newDir);
    float speed = g_TVMissileConfig.TVMissileSPEED.FloatValue;
    float anglevector[3];
    GetAngleVectors(ang, anglevector, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(anglevector, anglevector);
    ScaleVector(anglevector, speed);
    TeleportEntity(entity, NULL_VECTOR, ang, anglevector);

    int flyoverlay = GetConVarInt(g_TVMissileConfig.TVMissileFlyOVERLAY);
    if(flyoverlay >= 1)
    {
        ShowOverlay(client, g_OverlayZoom, 0.1);
    }
    if(g_bGuiding[client])
    {
        SetEntityMoveType(client, MOVETYPE_NONE);
    }

    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    g_bGuiding[client] = false;
}

stock void ShowOverlay(int client, char[] path, float lifetime) 
{
	if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
		return;

	int iFlag = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlag);
	ClientCommand(client, "r_screenoverlay \"%s.vtf\"", path);

	if (lifetime != 0.0)
		CreateTimer(lifetime, DeleteOverlay, GetClientUserId(client));
}

stock Action DeleteOverlay(Handle timer, any userid) 
{
	int client = GetClientOfUserId(userid);
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
	return Plugin_Handled;

	int iFlag = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlag);
	ClientCommand(client, "r_screenoverlay \"\"");

	return Plugin_Handled;
}

public bool PlayerInGround(int client)
{
    float fOrigin[3], fGround[3];
	GetClientAbsOrigin(client,fOrigin);
	TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client);  
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(fGround,INVALID_HANDLE);
		float distance = GetVectorDistance(fOrigin, fGround, false);
		if(distance < 10.0)
		{
            return true;
		}
	}
    return false;
}

public bool TraceRayNoPlayers(entity, mask, any data)
{
    if(entity == data || (entity >= 1 && entity <= MaxClients))
    {
        return false;
    }
    return true;
}

