#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike>

#include "globals.sp"

public Plugin myinfo =
{
	name = "weapon_paints",
	author = "DisTraTuL",
	description = "Weapons & Knifes Skins",
	version = "iulie.2018",
	url = "distratul@csgotracker.ro / https://csgotracker.ro"
};

native IsClientVIP(int iId);

enum StatTrakOption:
{
	StatTrakOption_None = 0,

	StatTrakOption_Disabled,
	StatTrakOption_Enabled
};

enum Knife:
{
	Knife_None = -1,
	Knife_Default = 0,

	Knife_Karambit,
	Knife_Butterfly,
	Knife_M9,
	Knife_Bayonet,
	Knife_Tactical,
	Knife_Push,
	Knife_Falchion,
	Knife_Gut,
	Knife_Flip,
	Knife_Bowie
};

enum KnifeSkin:
{
	Knife_Skin_None = -2,
	Knife_Skin_Random = -1,
	Knife_Skin_Default = 0,

	Knife_Skin_Fade = 38,
	Knife_Skin_Webs = 12,
	Knife_Skin_WebsDarker = 232,
	Knife_Skin_Purple = 98,
	Knife_Skin_Oiled = 44,
	Knife_Skin_DDPat = 5,
	Knife_Skin_Night = 40,
	Knife_Skin_MarbleFade = 413,
	Knife_Skin_ForestBoreal = 77,
	Knife_Skin_DopplerPhase1 = 418,
	Knife_Skin_DopplerPhase2 = 419,
	Knife_Skin_DopplerPhase3 = 420,
	Knife_Skin_DopplerPhase4 = 421,
	Knife_Skin_Slaughter = 59,
	Knife_Skin_Blued = 42,
	Knife_Skin_TigerOrange = 409,
	Knife_Skin_Damascus = 410,
	Knife_Skin_DopplerRuby = 415,
	Knife_Skin_DopplerSapphire = 416,
	Knife_Skin_DopplerBlackpearl = 417,
	Knife_Skin_Damascus90 = 411,
	Knife_Skin_Stained = 43,
	Knife_Skin_SafariMesh = 72,
	Knife_Skin_UrbanMasked = 143,
	Knife_Skin_Scorched = 175,
	Knife_Skin_RustCoat = 414,
	Knife_Skin_Bayonet_Lore = 558,
	Knife_Skin_Flip_Lore = 559,
	Knife_Skin_Gut_Lore = 560,
	Knife_Skin_Karambit_Lore = 561,
	Knife_Skin_M9_Bayonet_Lore = 562,
	Knife_Skin_Bayonet_BLaminate = 563,
	Knife_Skin_Flip_BLaminate = 564,
	Knife_Skin_Gut_BLaminate = 565,
	Knife_Skin_Karambit_BLaminate = 566,
	Knife_Skin_M9_Bayonet_BLaminate = 567,
	Knife_Skin_EmeraldMarbleized = 568,
	Knife_Skin_GDoppler_P1 = 569,
	Knife_Skin_GDoppler_P2 = 570,
	Knife_Skin_GDoppler_P3 = 571,
	Knife_Skin_GDoppler_P4 = 572,
	Knife_Skin_Bayonet_Auto = 573,
	Knife_Skin_Flip_Auto = 574,
	Knife_Skin_Gut_Auto = 575,
	Knife_Skin_Karambit_Auto = 576,
	Knife_Skin_M9_Bayonet_Auto = 577,
	Knife_Skin_BrightWater = 578,
	Knife_Skin_BrightWater_M9 = 579,
	Knife_Skin_FreeHand = 580,
	Knife_Skin_FreeHand_M9 = 581,
	Knife_Skin_FreeHand_Karambit = 582
};

Handle g_pDatabase = INVALID_HANDLE;

Handle g_pKnifeCookie = INVALID_HANDLE;
Handle g_pStatTrakOptionCookie = INVALID_HANDLE;
Handle g_pKnifeSkinCookie = INVALID_HANDLE;

int g_Skins[MAXPLAYERS + 1][PLATFORM_MAX_PATH * 3];
int g_ItemDefinitionIndex[MAXPLAYERS + 1] = { 0, ... };
int g_Kills[MAXPLAYERS + 1] = { 0, ... };
int g_SpawnTime[MAXPLAYERS + 1] = { 0, ... };

char g_Steam[MAXPLAYERS + 1][MAX_NAME_LENGTH];

bool g_bIsInGame[MAXPLAYERS + 1] = { false, ... };
bool g_bMessageShown[MAXPLAYERS + 1] = { false, ... };

KnifeSkin g_pKnifeSkin[MAXPLAYERS + 1] = { Knife_Skin_None, ... };
Knife g_pKnife[MAXPLAYERS + 1] = { Knife_None, ... };
StatTrakOption g_pStatTrakOption[MAXPLAYERS + 1] = { StatTrakOption_None, ... };
Handle g_pWear = INVALID_HANDLE;
Handle g_pNTCookies[PLATFORM_MAX_PATH * 3] = { INVALID_HANDLE, ... };

char g_Buffer[PLATFORM_MAX_PATH * 16];

int g_iFakeClient = INVALID_ENT_REFERENCE;

bool g_bIsInRound = false;

float g_fDelay = 0.0;
int g_Offset = 0;

int Find(char[] szProp)
{
	static int iIter = 0, iInfo = 0;

	static char pClasses[][] =
	{
		"Player", "CSPlayer", "CCSPlayer", "GameResource", "GameResources",
		"CGameResource", "CGameResources", "CSGameResource", "CSGameResources",
		"CCSGameResource", "CCSGameResources", "BasePlayer", "CBasePlayer",
		"BaseEntity", "CBaseEntity", "BaseWeapon", "CBaseWeapon", "BaseGrenade",
		"CBaseGrenade", "BaseCombatWeapon", "CBaseCombatWeapon", "WeaponCSBase",
		"CWeaponCSBase", "CSWeaponCSBase", "CCSWeaponCSBase", "PlayerResource",
		"CPlayerResource", "CSPlayerResource", "CCSPlayerResource", "PlayerResources",
		"CPlayerResources", "CSPlayerResources", "CCSPlayerResources", "BaseAnimating",
		"CBaseAnimating", "BaseCombatCharacter", "CBaseCombatCharacter",
		"BaseMultiplayerPlayer", "CBaseMultiplayerPlayer", "BaseFlex", "CBaseFlex"
	};

	for (iIter = 0; iIter < sizeof(pClasses); iIter++)
	{
		if ((iInfo = FindSendPropInfo(pClasses[iIter], szProp)) > 0)
			return iInfo;
	}

	return 0;
}

void xSaveUserNameTagForWeapon(int iUser, int iWeapon, char[] szNameTag)
{
	static char szName[MAX_NAME_LENGTH] = "";
	static char szInfo[PLATFORM_MAX_PATH] = "";

	if (g_pNTCookies[iWeapon] == INVALID_HANDLE)
	{
		FormatEx(szName, sizeof(szName), "m_szCustomName@%04d", iWeapon);
		FormatEx(szInfo, sizeof(szInfo), "Custom Name For Weapon Having m_iItemDefinitionIndex %d", iWeapon);

		g_pNTCookies[iWeapon] = RegClientCookie(szName, szInfo, CookieAccess_Private);
	}

	if (g_pNTCookies[iWeapon] != INVALID_HANDLE)
	{
		SetClientCookie(iUser, g_pNTCookies[iWeapon], szNameTag);
	}
}

void xGetUserNameTagForWeapon(int iUser, int iWeapon, char[] szNameTag)
{
	static char szName[MAX_NAME_LENGTH] = "";
	static char szInfo[PLATFORM_MAX_PATH] = "";

	if (g_pNTCookies[iWeapon] == INVALID_HANDLE)
	{
		FormatEx(szName, sizeof(szName), "m_szCustomName@%04d", iWeapon);
		FormatEx(szInfo, sizeof(szInfo), "Custom Name For Weapon Having m_iItemDefinitionIndex %d", iWeapon);

		g_pNTCookies[iWeapon] = RegClientCookie(szName, szInfo, CookieAccess_Private);
	}

	if (g_pNTCookies[iWeapon] != INVALID_HANDLE)
	{
		GetClientCookie(iUser, g_pNTCookies[iWeapon], szNameTag, MAX_NAME_LENGTH);
	}
}

public void OnMySQLThreadedConnection(Handle pOwner, Handle pChild, const char[] Error, any Data)
{
	if (g_pDatabase == INVALID_HANDLE)
	{
		g_pDatabase = pChild;

		if (strlen(Error) < 1 && g_pDatabase != INVALID_HANDLE)
		{
			SQL_SetCharset(g_pDatabase, "utf8");

			SQL_TQuery(g_pDatabase, QueryHandler_Empty, "CREATE TABLE IF NOT EXISTS nf_players (Steam varchar(128) NOT NULL UNIQUE, Skins varchar(8192), Name varchar(128), lastSeen NUMERIC, Kills NUMERIC);", _, DBPrio_High);
		}
	}

	else if (pChild != INVALID_HANDLE)
	{
		CloseHandle(pChild);
		pChild = INVALID_HANDLE;
	}
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_CreateFakeClient, _, TIMER_FLAG_NO_MAPCHANGE);
	
	g_fDelay = 0.0;
}

public Action Timer_CreateFakeClient(Handle pTimer, any _Data)
{
	if (g_iFakeClient == INVALID_ENT_REFERENCE)
		g_iFakeClient = CreateFakeClient("BOT Hattrick");
}

public void OnMapEnd()
{
	if (g_iFakeClient != INVALID_ENT_REFERENCE)
		g_iFakeClient = INVALID_ENT_REFERENCE;
	
	g_bIsInRound = false;
	g_fDelay = 0.0;
}

public Action CS_OnTerminateRound(float& Delay, CSRoundEndReason& Reason)
{
	static int Owner;

	g_bIsInRound = false;

	for (Owner = 1; Owner <= MaxClients; Owner++)
	{
		if (g_bIsInGame[Owner] && IsPlayerAlive(Owner))
			CreateTimer(Delay - GetRandomFloat(0.2975, 0.3995), stripKnifeQuietly, Owner, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action stripKnifeQuietly(Handle pTimer, any Owner)
{
	static char Class[MAX_NAME_LENGTH];
	static int Entity, Tries;

	if (g_bIsInGame[Owner] && IsPlayerAlive(Owner))
	{
		Entity = INVALID_ENT_REFERENCE;

		Tries = 0;

		while ((Entity = GetPlayerWeaponSlot(Owner, CS_SLOT_KNIFE)) != INVALID_ENT_REFERENCE)
		{
			if (GetEdictClassname(Entity, Class, sizeof(Class)) && \
					(StrContains(Class, "Knife", false) != -1 || \
						StrContains(Class, "Bayonet", false) != -1))
			{
				if (RemovePlayerItem(Owner, Entity))
				{
					my_Remove(Entity);
				}

				break;
			}

			if (++Tries >= 4)
				break;
		}
	}
}

float FClamp(float fVal, float fMin, float fMax)
{
	if (fVal < fMin)
		return fMin;

	else if (fVal > fMax)
		return fMax;

	return fVal;
}

float GetWear(int iId)
{
	static char szValue[MAX_NAME_LENGTH / 4] = "";
	GetClientCookie(iId, g_pWear, szValue, sizeof(szValue));

	return FClamp(StringToFloat(szValue), 0.00005, 8192.0);
}

public Action OnWear(int iClient, int iArgs)
{
	if (iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return Plugin_Stop;

	float fOldWear = GetWear(iClient);
	
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "Current\x04 Wear\x0B %f", fOldWear);
		ReplyToCommand(iClient, "Command Usage (Example)\x04 SM_Wear\x0B %f", GetRandomFloat(0.0, 1.0));
		
		return Plugin_Stop;
	}
	
	char szArg[MAX_NAME_LENGTH];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	float fWear = FClamp(StringToFloat(szArg), 0.00005, 8192.0);
	
	FloatToString(fWear, szArg, sizeof(szArg));
	SetClientCookie(iClient, g_pWear, szArg);
	
	ReplyToCommand(iClient, "Old\x04 Wear\x0B %f\x01    New\x04 Wear\x0B %f", fOldWear, StringToFloat(szArg));
	
	if (IsPlayerAlive(iClient))
		CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Stop;
}

public Action Timer_Ad(Handle pTimer, any _Data)
{
	PrintToChatAll("\x01 NEW COMMAND\x04  !WEAR\x05  %f\x01  (EXAMPLE)", GetRandomFloat(0.0, 1.0));
}

public void OnPluginStart()
{
	CreateTimer(60.0 * 10.0, Timer_Ad, _, TIMER_REPEAT);

	SQL_TConnect(OnMySQLThreadedConnection, "new_features");

	HookEventEx("round_start", OnRoundStart);

	HookEventEx("player_spawn", OnPlayerSpawn);
	HookEventEx("player_death", OnPlayerDeath);

	RegAdminCmd("sm_wear", OnWear, 0, "Sets Wear Value (Float) On Item");

	RegConsoleCmd("buyammo", CommandBuyAmmo);

	RegConsoleCmd("buyammo1", CommandBuyAmmo);
	RegConsoleCmd("buyammo2", CommandBuyAmmo);

	RegConsoleCmd("say", CommandSay);
	RegConsoleCmd("say_team", CommandSay);
	
	g_Offset = Find("m_szCustomName");

	g_pKnifeCookie = RegClientCookie("KnifeType", "Stores the knifecc type.", CookieAccess_Private);
	g_pStatTrakOptionCookie = RegClientCookie("StatTrakTechOpt", "Stores the StatTrak(tm) technology option.", CookieAccess_Private);
	g_pKnifeSkinCookie = RegClientCookie("KnifeSkin", "Stores the knife skin.", CookieAccess_Private);
	g_pWear = RegClientCookie("Wear", "Stores The Wear Value", CookieAccess_Private);
}

public void OnRoundStart(Handle pEvent, const char[] eventName, bool bNoBroadcast)
{
	g_bIsInRound = true;
}

public void OnClientAuthorized(int Client, const char[] Auth)
{
	if (!IsFakeClient(Client) && !IsClientSourceTV(Client))
		FormatEx(g_Steam[Client], sizeof(g_Steam[]), Auth);

	else
	{
		FormatEx(g_Steam[Client], sizeof(g_Steam[]), "BOT@%N", Client);

		g_pStatTrakOption[Client] = StatTrakOption_Disabled;
		g_bMessageShown[Client] = true;
		g_pKnife[Client] = Knife_None;
		g_pKnifeSkin[Client] = Knife_Skin_Default;
	}
}

public void OnClientPutInServer(int Client)
{
	static int Iterator;
	
	g_bIsInGame[Client] = true;
	g_Kills[Client] = 0;

	for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
		g_Skins[Client][Iterator] = 0;

	if (IsFakeClient(Client) || IsClientSourceTV(Client) || \
			StrContains("GOTV BOT HLTV SOURCETV SRCTV", g_Steam[Client], false) != -1)
	{
		FormatEx(g_Steam[Client], sizeof(g_Steam[]), "BOT@%N", Client);

		g_pStatTrakOption[Client] = StatTrakOption_Disabled;
		g_bMessageShown[Client] = true;
		g_pKnife[Client] = Knife_None;
		g_pKnifeSkin[Client] = Knife_Skin_Default;
	}

	else
	{
		SDKHookEx(Client, SDKHook_WeaponEquipPost, OnWeaponEquip);

		if (g_pDatabase != INVALID_HANDLE)
		{
			FormatEx(g_Buffer, sizeof(g_Buffer), "SELECT Skins, Kills FROM nf_players WHERE Steam = '%s';", g_Steam[Client]);
			SQL_TQuery(g_pDatabase, QueryHandler_SkinsReceived, g_Buffer, Client, DBPrio_High);
		}

		else
			CreateTimer(0.1, loadSkins_Delayed, Client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action CommandBuyAmmo(int Client, int Args)
{
	static int lastTime[MAXPLAYERS + 1], theTime;

	if (Client > 0 && g_bIsInGame[Client])
	{
		theTime = GetTime();

		if (lastTime[Client] < theTime && IsPlayerAlive(Client))
		{
			CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, Client, TIMER_FLAG_NO_MAPCHANGE);

			lastTime[Client] = theTime + 1;
		}
	}
}

public Action OnWeaponEquip(int iClient, int iEntity)
{
	static int iPrevOwner = INVALID_ENT_REFERENCE;

	if ((iPrevOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hPrevOwner")) == INVALID_ENT_REFERENCE || \
			(iPrevOwner == g_iFakeClient && g_iFakeClient != INVALID_ENT_REFERENCE))
	{
		applyWeaponData(iClient, iEntity, GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex"), true);
	}

	return Plugin_Continue;
}

void SaveMe(int Client)
{
	static int Iterator, iStamp[MAXPLAYERS + 1] = { 0, ... }, Time;
	static char Item[PLATFORM_MAX_PATH / 8];
	static bool bShouldSave = false;
	
	Time = GetTime();
	
	if (Time - iStamp[Client] < 3 || Time - g_SpawnTime[Client] < 1)
		return;
	
	iStamp[Client] = Time;
	
	g_Buffer[0] = EOS;
	bShouldSave = false;
	
	for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
	{
		if (!bShouldSave && g_Skins[Client][Iterator] != 0)
			bShouldSave = true;
		
		IntToString(g_Skins[Client][Iterator], Item, sizeof(Item));
		StrCat(g_Buffer, sizeof(g_Buffer), Item);

		if (Iterator != sizeof(g_Skins[]) - 1)
			StrCat(g_Buffer, sizeof(g_Buffer), ",");
	}

	if (bShouldSave && g_pDatabase != INVALID_HANDLE)
	{
		Format(g_Buffer, sizeof(g_Buffer), \
					"UPDATE nf_players SET Skins = '%s', lastSeen = %d WHERE Steam = '%s';", \
						g_Buffer, GetTime(), g_Steam[Client]);

		SQL_TQuery(g_pDatabase, QueryHandler_Empty, g_Buffer, _, DBPrio_Low);
	}
}

public void OnClientDisconnect(int Client)
{
	SDKUnhook(Client, SDKHook_WeaponEquipPost, OnWeaponEquip);

	g_bIsInGame[Client] = false;
}

public Action loadSkins_Delayed(Handle pTimer, any Client)
{
	if (g_bIsInGame[Client] || \
			IsClientInGame(Client) || \
				IsClientConnected(Client))
	{
		if (g_pDatabase != INVALID_HANDLE)
		{
			FormatEx(g_Buffer, sizeof(g_Buffer), "SELECT Skins, Kills FROM nf_players WHERE Steam = '%s';", g_Steam[Client]);
			SQL_TQuery(g_pDatabase, QueryHandler_SkinsReceived, g_Buffer, Client, DBPrio_High);
		}

		else
			CreateTimer(0.1, loadSkins_Delayed, Client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientCookiesCached(int Client)
{
	static char Value[MAX_NAME_LENGTH / 4];

	if (!IsFakeClient(Client) && \
			!IsClientSourceTV(Client) && \
				StrContains("GOTV BOT HLTV SOURCETV SRCTV", g_Steam[Client], false) == -1)
	{
		GetClientCookie(Client, g_pKnifeCookie, Value, sizeof(Value));

		if (strlen(Value) == 0)
			g_pKnife[Client] = Knife_None;

		else
			g_pKnife[Client] = view_as<Knife>(StringToInt(Value));

		GetClientCookie(Client, g_pKnifeSkinCookie, Value, sizeof(Value));

		if (strlen(Value) == 0)
			g_pKnifeSkin[Client] = Knife_Skin_None;

		else
			g_pKnifeSkin[Client] = view_as<KnifeSkin>(StringToInt(Value));

		GetClientCookie(Client, g_pStatTrakOptionCookie, Value, sizeof(Value));

		if (strlen(Value) == 0)
		{
			g_pStatTrakOption[Client] = StatTrakOption_None;
			g_bMessageShown[Client] = false;
		}

		else
		{
			g_pStatTrakOption[Client] = StringToInt(Value) > 0 ? view_as<StatTrakOption>(StringToInt(Value)) : StatTrakOption_None;
			g_bMessageShown[Client] = GetRandomInt(0, 2) == 0 ? false : true;
		}
	}

	else
	{
		g_pStatTrakOption[Client] = StatTrakOption_Disabled;
		g_bMessageShown[Client] = true;
		g_pKnife[Client] = Knife_None;
		g_pKnifeSkin[Client] = Knife_Skin_Default;
	}
}

int GetRandomKnifeSkin()
{
	static KnifeSkin knifeIds[] =
	{
		Knife_Skin_Default,
		Knife_Skin_Fade,
		Knife_Skin_Webs,
		Knife_Skin_WebsDarker,
		Knife_Skin_Purple,
		Knife_Skin_Oiled,
		Knife_Skin_DDPat,
		Knife_Skin_Night,
		Knife_Skin_MarbleFade,
		Knife_Skin_ForestBoreal,
		Knife_Skin_DopplerPhase1,
		Knife_Skin_DopplerPhase2,
		Knife_Skin_DopplerPhase3,
		Knife_Skin_DopplerPhase4,
		Knife_Skin_Slaughter,
		Knife_Skin_Blued,
		Knife_Skin_TigerOrange,
		Knife_Skin_DopplerRuby,
		Knife_Skin_DopplerSapphire,
		Knife_Skin_DopplerBlackpearl,
		Knife_Skin_GDoppler_P1,
		Knife_Skin_GDoppler_P2,
		Knife_Skin_GDoppler_P3,
		Knife_Skin_GDoppler_P4,
		Knife_Skin_EmeraldMarbleized,
		Knife_Skin_Stained,
		Knife_Skin_SafariMesh,
		Knife_Skin_UrbanMasked,
		Knife_Skin_Scorched,
		Knife_Skin_RustCoat
	};

	return view_as<int>(knifeIds[GetRandomInt(0, sizeof(knifeIds) - 1)]);
}

void KnifeClassByOption(int Owner, char[] Class, int Size)
{
	switch (g_pKnife[Owner])
	{
		case Knife_None, Knife_Default:
		{
			switch (GetClientTeam(Owner))
			{
				case CS_TEAM_CT:	FormatEx(Class, Size, "weapon_knife");
				case CS_TEAM_T:		FormatEx(Class, Size, "weapon_knife_t");
			}
		}

		case Knife_Gut:			FormatEx(Class, Size, "weapon_knife_gut");
		case Knife_Flip:		FormatEx(Class, Size, "weapon_knife_flip");
		case Knife_Falchion:	FormatEx(Class, Size, "weapon_knife_falchion");
		case Knife_Bayonet:		FormatEx(Class, Size, "weapon_bayonet");
		case Knife_M9:			FormatEx(Class, Size, "weapon_knife_m9_bayonet");
		case Knife_Push:		FormatEx(Class, Size, "weapon_knife_push");
		case Knife_Karambit:	FormatEx(Class, Size, "weapon_knife_karambit");
		case Knife_Butterfly:	FormatEx(Class, Size, "weapon_knife_butterfly");
		case Knife_Tactical:	FormatEx(Class, Size, "weapon_knife_tactical");
		case Knife_Bowie:		FormatEx(Class, Size, "weapon_knife_survival_bowie");
	}
}

void applyKnifeData(int Owner, int Entity, int Id)
{
	if (Id >= 128 && g_pKnife[Owner] != Knife_Default && g_pKnife[Owner] != Knife_None)
	{
		SetEntProp(Entity, Prop_Send, "m_iItemIDLow", -1);

		if (g_pKnifeSkin[Owner] == Knife_Skin_Default || g_pKnifeSkin[Owner] == Knife_Skin_None)
			SetEntProp(Entity, Prop_Send, "m_nFallbackPaintKit", 1);

		else
			SetEntProp(Entity, Prop_Send, "m_nFallbackPaintKit", g_pKnifeSkin[Owner] == Knife_Skin_Random ? \
				GetRandomKnifeSkin() : view_as<int>(g_pKnifeSkin[Owner]));

		if (g_pKnifeSkin[Owner] != Knife_Skin_Default && g_pKnifeSkin[Owner] != Knife_Skin_None)
		{
			SetEntPropFloat(Entity, Prop_Send, "m_flFallbackWear", GetWear(Owner));
			SetEntProp(Entity, Prop_Send, "m_nFallbackSeed", GetRandomInt(0, 8192));
		}

		if (g_pStatTrakOption[Owner] == StatTrakOption_Enabled)
			SetEntProp(Entity, Prop_Send, "m_nFallbackStatTrak", g_Kills[Owner]);

		else
			SetEntProp(Entity, Prop_Send, "m_nFallbackStatTrak", -1);

		SetEntProp(Entity, Prop_Send, "m_iEntityQuality", 3);

		if (!xVIPAvail() || (xVIPAvail() && xIsVIP(Owner)))
		{
			xGetUserNameTagForWeapon(Owner, Id, g_Buffer);

			if (strlen(g_Buffer) > 0)
				SetEntDataString(Entity, g_Offset, g_Buffer, PLATFORM_MAX_PATH);
		}

		SetEntProp(Entity, Prop_Send, "m_iAccountID", GetEntProp(Entity, Prop_Send, "m_OriginalOwnerXuidLow"));
	}
}

public APLRes AskPluginLoad2(Handle pSelf, bool bLate, char[] szError, int iMaxErrSize)
{
	MarkNativeAsOptional("IsClientVIP");
	
	CreateNative("EquipKnife", __EquipKnife);
	
	RegPluginLibrary("new_features");

	return APLRes_Success;
}

bool xVIPAvail()
{
	return CanTestFeatures() && \
				GetFeatureStatus(FeatureType_Native, "IsClientVIP") == FeatureStatus_Available ? true : false;
}

bool xIsVIP(int iId)
{
	return CanTestFeatures() && \
				GetFeatureStatus(FeatureType_Native, "IsClientVIP") == FeatureStatus_Available && \
					IsClientVIP(iId) ? true : false;
}

void applyWeaponData(int Owner, int Entity, int Id, bool bByForward = false)
{
	static char Class[MAX_NAME_LENGTH] = "";

	if (GetEdictClassname(Entity, Class, sizeof(Class)) && g_Skins[Owner][Id] > 1 && \
			StrContains(Class, "Bayonet", false) == -1 && StrContains(Class, "Knife", false) == -1)
	{
		if (bByForward)
		{
			if (RemovePlayerItem(Owner, Entity))
			{
				my_Remove(Entity);

				switch (Id)
				{
					case 63: Class = "weapon_cz75a";
					case 64: Class = "weapon_revolver";
					case 61: Class = "weapon_usp_silencer";
					case 60: Class = "weapon_m4a1_silencer";
				}
				
				SDKUnhook(Owner, SDKHook_WeaponEquipPost, OnWeaponEquip);
				
				Entity = GivePlayerItem(Owner, Class);
				
				SDKHookEx(Owner, SDKHook_WeaponEquipPost, OnWeaponEquip);
			}
		}
		
		if (Entity != INVALID_ENT_REFERENCE)
		{
			SetEntProp(Entity, Prop_Send, "m_iItemIDLow", -1);

			SetEntProp(Entity, Prop_Send, "m_nFallbackPaintKit", g_Skins[Owner][Id]);
			SetEntPropFloat(Entity, Prop_Send, "m_flFallbackWear", GetWear(Owner));
			SetEntProp(Entity, Prop_Send, "m_nFallbackSeed", GetRandomInt(0, 8192));

			if (g_pStatTrakOption[Owner] == StatTrakOption_Enabled)
				SetEntProp(Entity, Prop_Send, "m_nFallbackStatTrak", g_Kills[Owner]);

			else
				SetEntProp(Entity, Prop_Send, "m_nFallbackStatTrak", -1);

			if (g_pStatTrakOption[Owner] == StatTrakOption_Enabled)
				SetEntProp(Entity, Prop_Send, "m_iEntityQuality", 9);

			else if (GetEntProp(Entity, Prop_Send, "m_iEntityQuality") == 12)
			{
			
			}

			else
			{
				SetEntProp(Entity, Prop_Send, "m_iEntityQuality", 0);
			}

			if (!xVIPAvail() || (xVIPAvail() && xIsVIP(Owner)))
			{
				xGetUserNameTagForWeapon(Owner, Id, g_Buffer);

				if (strlen(g_Buffer) > 0)
					SetEntDataString(Entity, g_Offset, g_Buffer, PLATFORM_MAX_PATH);
			}

			SetEntProp(Entity, Prop_Send, "m_iAccountID", GetEntProp(Entity, Prop_Send, "m_OriginalOwnerXuidLow"));

			if (!bByForward)
				SaveMe(Owner);
		}
	}
}

public void QueryHandler_Empty(Handle pDb, Handle pQuery, char[] Error, any Data)
{

}

public Action Timer_RetrieveKills(Handle pTimer, any _Data)
{
	if (IsClientInGame(_Data) && g_pDatabase != INVALID_HANDLE)
	{
		FormatEx(g_Buffer, sizeof(g_Buffer), "SELECT kills FROM ss_players WHERE steam = '%s';", g_Steam[_Data]);
		SQL_TQuery(g_pDatabase, QueryHandler_KillsReceived, g_Buffer, _Data, DBPrio_High);
	}
}

public void QueryHandler_KillsReceived(Handle pOwner, Handle pQuery, const char[] Error, any Client)
{
	if (pQuery != INVALID_HANDLE && strlen(Error) < 1 && SQL_GetRowCount(pQuery) > 0)
	{
		SQL_FetchRow(pQuery);
		g_Kills[Client] = SQL_FetchInt(pQuery, 0);
		FormatEx(g_Buffer, sizeof(g_Buffer), "UPDATE nf_players SET Kills = %d WHERE Steam = '%s';", g_Kills[Client], g_Steam[Client]);
		SQL_TQuery(g_pDatabase, QueryHandler_Empty, g_Buffer, Client, DBPrio_Low);
	}
}

public void QueryHandler_SkinsReceived(Handle pOwner, Handle pQuery, const char[] Error, any Client)
{
	static int Iterator;
	static char Buffers[sizeof(g_Skins[])][PLATFORM_MAX_PATH / 8];

	if (pQuery != INVALID_HANDLE && strlen(Error) < 1)
	{
		if (SQL_GetRowCount(pQuery) > 0)
		{
			SQL_FetchRow(pQuery);
			SQL_FetchString(pQuery, 0, g_Buffer, sizeof(g_Buffer));
			g_Kills[Client] = SQL_FetchInt(pQuery, 1);
			
			CreateTimer(0.1, Timer_RetrieveKills, Client, TIMER_FLAG_NO_MAPCHANGE);

			if (strlen(g_Buffer) == 0)
			{
				for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
					g_Skins[Client][Iterator] = 0;
			}

			else
			{
				for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
					Buffers[Iterator][0] = EOS;

				ExplodeString(g_Buffer, ",", Buffers, sizeof(Buffers), sizeof(Buffers[]));

				for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
				{
					if (strlen(Buffers[Iterator]) > 0)
						g_Skins[Client][Iterator] = StringToInt(Buffers[Iterator]);

					else
						g_Skins[Client][Iterator] = 0;
				}
			}
		}

		else
		{
			g_Kills[Client] = 0;

			FormatEx(g_Buffer, sizeof(g_Buffer), "INSERT INTO nf_players VALUES ('%s', '', '', %d, 0);", \
						g_Steam[Client], GetTime());

			if (g_pDatabase != INVALID_HANDLE)
				SQL_TQuery(g_pDatabase, QueryHandler_Empty, g_Buffer, _, DBPrio_Low);

			for (Iterator = 0; Iterator < sizeof(g_Skins[]); Iterator++)
				g_Skins[Client][Iterator] = 0;
		}
	}
}

public void OnPlayerDeath(Handle pEvent, const char[] eventName, bool bNoBroadcast)
{
	static int Client, Attacker, Wpn;

	Client = GetClientOfUserId(GetEventInt(pEvent, "userid"));

	if (Client > 0)
	{
		if (GetRandomInt(1, 10) == 1 && (!xVIPAvail() || (xVIPAvail() && xIsVIP(Client))))
			PrintToChat(Client, " \x05NEW\x09  VIP★\x05  COMMAND\x0B  !NameTag");
		
		Attacker = GetClientOfUserId(GetEventInt(pEvent, "attacker"));

		if (Attacker >= 1 && Attacker <= MaxClients && Attacker != Client && g_bIsInGame[Attacker] && \
				StrContains("GOTV HLTV BOT SOURCETV SRCTV", g_Steam[Attacker], false) == -1)
		{
			g_Kills[Attacker]++;

			if (g_pDatabase != INVALID_HANDLE)
			{
				FormatEx(g_Buffer, sizeof(g_Buffer), "UPDATE nf_players SET Kills = Kills + 1 WHERE Steam = '%s';", g_Steam[Attacker]);
				SQL_TQuery(g_pDatabase, QueryHandler_Empty, g_Buffer);
			}

			if (IsPlayerAlive(Attacker) && g_pStatTrakOption[Attacker] == StatTrakOption_Enabled)
			{
				if ((Wpn = GetPlayerWeaponSlot(Attacker, CS_SLOT_PRIMARY)) != INVALID_ENT_REFERENCE && \
								GetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak") != -1)
				{
					SetEntProp(Wpn, Prop_Send, "m_iItemIDLow", -1);
					SetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak", g_Kills[Attacker]);
					SetEntProp(Wpn, Prop_Send, "m_iAccountID", GetEntProp(Wpn, Prop_Send, "m_OriginalOwnerXuidLow"));
				}

				if ((Wpn = GetPlayerWeaponSlot(Attacker, CS_SLOT_SECONDARY)) != INVALID_ENT_REFERENCE && \
								GetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak") != -1)
				{
					SetEntProp(Wpn, Prop_Send, "m_iItemIDLow", -1);
					SetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak", g_Kills[Attacker]);
					SetEntProp(Wpn, Prop_Send, "m_iAccountID", GetEntProp(Wpn, Prop_Send, "m_OriginalOwnerXuidLow"));
				}

				if ((Wpn = GetPlayerWeaponSlot(Attacker, CS_SLOT_KNIFE)) != INVALID_ENT_REFERENCE && \
								GetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak") != -1)
				{
					SetEntProp(Wpn, Prop_Send, "m_iItemIDLow", -1);
					SetEntProp(Wpn, Prop_Send, "m_nFallbackStatTrak", g_Kills[Attacker]);
					SetEntProp(Wpn, Prop_Send, "m_iAccountID", GetEntProp(Wpn, Prop_Send, "m_OriginalOwnerXuidLow"));
				}
			}
		}

		if (!g_bMessageShown[Client] && GetRandomInt(0, 2) == 0 && g_bIsInGame[Client])
			CreateTimer(GetRandomFloat(2.75, 4.25), TimerHandler_DisplayStatTrakDetails, Client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnPlayerSpawn(Handle pEvent, const char[] eventName, bool bNoBroadcast)
{
	static int Client, iTeam;

	Client = GetClientOfUserId(GetEventInt(pEvent, "userid"));

	if (Client > 0)
	{
		if (g_bIsInGame[Client] && \
				IsPlayerAlive(Client) && \
					GetEntProp(Client, Prop_Send, "m_iHealth") > 0 && \
						((iTeam = GetClientTeam(Client)) == CS_TEAM_T || iTeam == CS_TEAM_CT) && \
							strncmp(g_Steam[Client], "BOT", 3, false))
		{
			g_SpawnTime[Client] = GetTime();
			
			if (g_pStatTrakOption[Client] == StatTrakOption_None)
				CreateTimer(GetRandomFloat(2.0, 5.0), TimerHandler_DisplayStatTrakPanel, Client, TIMER_FLAG_NO_MAPCHANGE);

			if (g_pKnife[Client] != Knife_None && g_pKnife[Client] != Knife_Default)
				CreateTimer(GetRandomFloat(0.1, 0.2), Timer_Replace, Client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_Replace(Handle pTimer, any _Data)
{
	if (g_pKnife[_Data] != Knife_None && g_pKnife[_Data] != Knife_Default)
		replaceKnifeIfPossible(_Data, true);
}

#if !defined _hattrick_csgo_included
	int hCSGO_ClearLine(char[] Line, int Times = 4)
	{
		static int m_Iterator, m_Length;

		m_Iterator = 0;
		m_Length = strlen(Line);

		for (; m_Iterator < Times; m_Iterator++)
		{
			StripQuotes(Line);
			m_Length = TrimString(Line);
		}

		return m_Length;
	}
#endif

public Action CommandSay(int Client, int Args)
{
	static int iIter = 0, iWeaponID = 0, iSize = 0, iWeapon = INVALID_ENT_REFERENCE;
	static char Raw[PLATFORM_MAX_PATH / 2], Command[PLATFORM_MAX_PATH / 2], szClass[PLATFORM_MAX_PATH / 2];

	if (Client > 0 && g_bIsInGame[Client])
	{
		GetCmdArgString(Raw, sizeof(Raw));

		if (hCSGO_PureChatCommand(Raw, Command, sizeof(Command)) >= 2)
		{
			if (strcmp(Command, "Skin", false) == 0 || strcmp(Command[1], "Skin", false) == 0 || \
					strcmp(Command, "Skins", false) == 0 || strcmp(Command[1], "Skins", false) == 0 || \
						strcmp(Command, "Ws", false) == 0 || strcmp(Command[1], "Ws", false) == 0 || \
							strcmp(Command, "Paints", false) == 0 || strcmp(Command[1], "Paints", false) == 0 || \
								strcmp(Command, "Paint", false) == 0 || strcmp(Command[1], "Paint", false) == 0)
			{
				if (!IsPlayerAlive(Client))
					PrintToChat(Client, "* You must be\x04 Alive");

				else
					CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, Client, TIMER_FLAG_NO_MAPCHANGE);
			}
			
			else if (strncmp(Command, "NameTag", 7, false) == 0 || strncmp(Command[1], "NameTag", 7, false) == 0)
			{
				iWeapon = INVALID_ENT_REFERENCE;

				if (xVIPAvail() && !xIsVIP(Client))
				{
					PrintToChat(Client, " \x02YOU MUST BE\x09  VIP★");
				}
				
				else if (!IsPlayerAlive(Client))
				{
					PrintToChat(Client, " \x02YOU ARE DEAD");
				}
				
				else if ((iWeapon = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon")) == INVALID_ENT_REFERENCE)
				{
					PrintToChat(Client, " \x02YOU HAVE NO\x0B  ACTIVE\x02  WEAPON");
				}
				
				else
				{
					iWeaponID = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
					
					hCSGO_ClearLine(Raw);
					ReplaceString(Raw, sizeof(Raw), "%", "％");
					
					for (iIter = 0; iIter < MAX_NAME_LENGTH; iIter++)
						ReplaceString(Raw, sizeof(Raw), "  ", " ");
					
					char pTokens[MAX_NAME_LENGTH / 4][MAX_NAME_LENGTH];
					iSize = ExplodeString(Raw, " ", pTokens, sizeof(pTokens), MAX_NAME_LENGTH);
					
					ClassById(iWeaponID, szClass, sizeof(szClass));
					
					if (strlen(szClass) < 1)
					{
						PrintToChat(Client, " \x02YOU HAVE NO\x04  VALID\x02  WEAPON");
						
						return Plugin_Continue;
					}

					ReplaceString(szClass, sizeof(szClass), "_", " ");
					ReplaceString(szClass, sizeof(szClass), "Weapon ", "", false);

					for (iIter = 0; iIter < strlen(szClass); iIter++)
						szClass[iIter] = CharToUpper(szClass[iIter]);
					
					Format(szClass, sizeof(szClass), "`%s'", szClass);
					
					if (StrContains(szClass, "Knife ", false) != -1 && \
							StrContains(szClass, "Knife T", false) == -1)
					{
						ReplaceString(szClass, sizeof(szClass), "Knife ", "", false);
					}

					if (iSize <= 1)
					{
						xSaveUserNameTagForWeapon(Client, iWeaponID, "");
						
						PrintToChat(Client, " \x04NAME TAG FOR\x0B  %s\x07  REMOVED\x02  (NULL)", szClass);
						
						CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, Client, TIMER_FLAG_NO_MAPCHANGE);
					}
					
					else
					{
						g_Buffer = "";
						
						for (iIter = 0; iIter < iSize; iIter++)
						{
							if (iIter == 0)
								continue;
							
							hCSGO_ClearLine(pTokens[iIter]);
							
							if (strlen(pTokens[iIter]) < 1)
								continue;
							
							StrCat(g_Buffer, MAX_NAME_LENGTH, pTokens[iIter]);
							
							if (iIter != iSize - 1)
								StrCat(g_Buffer, MAX_NAME_LENGTH, " ");
						}
						
						hCSGO_ClearLine(g_Buffer);
						
						if (strlen(g_Buffer) < 1)
						{
							xSaveUserNameTagForWeapon(Client, iWeaponID, "");
							
							PrintToChat(Client, " \x04NAME TAG FOR\x0B  %s\x07  REMOVED\x02  (NULL)", szClass);
							
							CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, Client, TIMER_FLAG_NO_MAPCHANGE);
						}
						
						else
						{
							xSaveUserNameTagForWeapon(Client, iWeaponID, g_Buffer);
							
							PrintToChat(Client, " \x04NAME TAG FOR\x0B  %s\x09  %s", szClass, g_Buffer);
							PrintToChat(Client, " \x05SAY\x07  !NameTag\x05  TO REMOVE\x02  (NULL)");
							
							CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplaySkinsMenu, Client, TIMER_FLAG_NO_MAPCHANGE);
						}
					}
				}
			}

			else if (strncmp(Command, "Knife", 5, false) == 0 || strncmp(Command[1], "Knife", 5, false) == 0 || \
						strncmp(Command, "Knive", 5, false) == 0 || strncmp(Command[1], "Knive", 5, false) == 0 || \
							strncmp(Command, "Cutit", 5, false) == 0 || strncmp(Command[1], "Cutit", 5, false) == 0)
			{
				if (!IsPlayerAlive(Client))
					PrintToChat(Client, "* You must be\x04 Alive");

				else
					CreateTimer(GetRandomFloat(0.025, 0.1575), TimerHandler_DisplayKnivesMenu, Client, TIMER_FLAG_NO_MAPCHANGE);
			}

			else if (strcmp(Command, "ST", false) == 0 || strcmp(Command[1], "ST", false) == 0)
			{
				g_bMessageShown[Client] = true;
				g_pStatTrakOption[Client] = StatTrakOption_None;

				CreateTimer(GetRandomFloat(0.025, 0.1575), \
								TimerHandler_DisplayStatTrakPanel, \
									Client, \
										TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}

	return Plugin_Continue;
}

public int MenuHandler_Skins(Handle pMenu, MenuAction pAction, int Client, int Selection)
{
	static int Weapon, iInfo, Id;
	static char Info[MAX_NAME_LENGTH];
	static bool bDefault;

	if (pAction == MenuAction_Select && \
			g_bIsInGame[Client] && \
				IsPlayerAlive(Client))
	{
		Weapon = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");

		if (Weapon != INVALID_ENT_REFERENCE)
		{
			Id = GetEntProp(Weapon, Prop_Send, "m_iItemDefinitionIndex");

			if (Id != g_ItemDefinitionIndex[Client])
				PrintToChat(Client, "* Have you\x07 switched\x01 the\x09 weapon\x01 yet?");

			else
			{
				bDefault = false;

				GetMenuItem(pMenu, Selection, Info, sizeof(Info));

				iInfo = StringToInt(Info);

				switch (Id)
				{
					case 4:
					{
						if (iInfo >= sizeof(g_Glock18SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Glock18SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Glock18Skins[iInfo]);
						}
					}
					case 2:
					{
						if (iInfo >= sizeof(g_DualBerettasSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_DualBerettasSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_DualBerettasSkins[iInfo]);
						}
					}
					case 36:
					{
						if (iInfo >= sizeof(g_P250SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_P250SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_P250Skins[iInfo]);
						}
					}
					case 30:
					{
						if (iInfo >= sizeof(g_Tec9SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Tec9SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Tec9Skins[iInfo]);
						}
					}
					case 1:
					{
						if (iInfo >= sizeof(g_DEagleSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_DEagleSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_DEagleSkins[iInfo]);
						}
					}
					case 35:
					{
						if (iInfo >= sizeof(g_NovaSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_NovaSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_NovaSkins[iInfo]);
						}
					}
					case 25:
					{
						if (iInfo >= sizeof(g_XM1014SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_XM1014SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_XM1014Skins[iInfo]);
						}
					}
					case 29:
					{
						if (iInfo >= sizeof(g_SawedOffSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_SawedOffSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_SawedOffSkins[iInfo]);
						}
					}
					case 14:
					{
						if (iInfo >= sizeof(g_M249SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_M249SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_M249Skins[iInfo]);
						}
					}
					case 28:
					{
						if (iInfo >= sizeof(g_NegevSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_NegevSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_NegevSkins[iInfo]);
						}
					}
					case 17:
					{
						if (iInfo >= sizeof(g_Mac10SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Mac10SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Mac10Skins[iInfo]);
						}
					}
					case 33:
					{
						if (iInfo >= sizeof(g_Mp7SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Mp7SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Mp7Skins[iInfo]);
						}
					}
					case 24:
					{
						if (iInfo >= sizeof(g_Ump45SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Ump45SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Ump45Skins[iInfo]);
						}
					}
					case 19:
					{
						if (iInfo >= sizeof(g_P90SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_P90SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_P90Skins[iInfo]);
						}
					}
					case 26:
					{
						if (iInfo >= sizeof(g_PPBizonSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_PPBizonSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_PPBizonSkins[iInfo]);
						}
					}
					case 13:
					{
						if (iInfo >= sizeof(g_GalilARSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_GalilARSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_GalilARSkins[iInfo]);
						}
					}
					case 7:
					{
						if (iInfo >= sizeof(g_Ak47SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Ak47SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Ak47Skins[iInfo]);
						}
					}
					case 40:
					{
						if (iInfo >= sizeof(g_SSG08SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_SSG08SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_SSG08Skins[iInfo]);
						}
					}
					case 39:
					{
						if (iInfo >= sizeof(g_SG553SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_SG553SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_SG553Skins[iInfo]);
						}
					}
					case 9:
					{
						if (iInfo >= sizeof(g_AwpSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_AwpSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_AwpSkins[iInfo]);
						}
					}
					case 11:
					{
						if (iInfo >= sizeof(g_G3SG1SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_G3SG1SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_G3SG1Skins[iInfo]);
						}
					}
					case 61:
					{
						if (iInfo >= sizeof(g_UspSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_UspSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_UspSkins[iInfo]);
						}
					}
					case 3:
					{
						if (iInfo >= sizeof(g_FiveSeveNSKinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_FiveSeveNSKinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_FiveSeveNSKins[iInfo]);
						}
					}
					case 27:
					{
						if (iInfo >= sizeof(g_Mag7SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Mag7SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Mag7Skins[iInfo]);
						}
					}
					case 34:
					{
						if (iInfo >= sizeof(g_Mp9SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Mp9SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Mp9Skins[iInfo]);
						}
					}
					case 10:
					{
						if (iInfo >= sizeof(g_FamasSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_FamasSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_FamasSkins[iInfo]);
						}
					}
					case 60:
					{
						if (iInfo >= sizeof(g_M4A1SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_M4A1SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_M4A1Skins[iInfo]);
						}
					}
					case 8:
					{
						if (iInfo >= sizeof(g_AugSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_AugSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_AugSkins[iInfo]);
						}
					}
					case 38:
					{
						if (iInfo >= sizeof(g_Scar20SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_Scar20SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_Scar20Skins[iInfo]);
						}
					}
					case 32:
					{
						if (iInfo >= sizeof(g_P2000SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_P2000SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_P2000Skins[iInfo]);
						}
					}
					case 16:
					{
						if (iInfo >= sizeof(g_M4A4SkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_M4A4SkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_M4A4Skins[iInfo]);
						}
					}
					case 63:
					{
						if (iInfo >= sizeof(g_CZ75AutoSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_CZ75AutoSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_CZ75AutoSkins[iInfo]);
						}
					}
					case 64:
					{
						if (iInfo >= sizeof(g_RevolverSkinIds))
							bDefault = true,
							PrintToChat(Client, "*\x07 Invalid\x01 selection!");

						else
						{
							g_Skins[Client][Id] = g_RevolverSkinIds[iInfo];
							PrintToChat(Client, "* You selected\x05 %s", g_RevolverSkins[iInfo]);
						}
					}

					default:
					{
						PrintToChat(Client, "* You selected\x09 Default");

						bDefault = true;
					}
				}

				if (!bDefault && g_bIsInRound)
				{
					switch (Id)
					{
						case 4:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_glock")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 2:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_elite")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 36:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_p250")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 30:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_tec9")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 1:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_deagle")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 35:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_nova")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 25:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_xm1014")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 29:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_sawedoff")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 14:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_m249")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 28:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_negev")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 17:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_mac10")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 33:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_mp7")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 24:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_ump45")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 19:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_p90")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 26:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_bizon")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 13:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_galilar")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 7:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_ak47")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 40:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_ssg08")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 39:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_sg556")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 9:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_awp")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 11:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_g3sg1")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 61:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_usp_silencer")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 3:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_fiveseven")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 27:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_mag7")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 34:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_mp9")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 10:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_famas")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 60:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_m4a1_silencer")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 8:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_aug")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 38:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_scar20")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 32:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_hkp2000")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 16:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_m4a1")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 63:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_cz75a")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
						case 64:
						{
							if (RemovePlayerItem(Client, Weapon))
							{
								my_Remove(Weapon);

								if ((Weapon = GivePlayerItem(Client, "weapon_revolver")) != INVALID_ENT_REFERENCE)
									applyWeaponData(Client, Weapon, Id);
							}
						}
					}
				}
			}
		}

		else
			PrintToChat(Client, "* You must have an\x05 Active\x09 Weapon");
	}

	else if (pAction == MenuAction_End && \
				pMenu != INVALID_HANDLE)
	{
		CloseHandle(pMenu);
		pMenu = INVALID_HANDLE;
	}
}

public int PanelHandler_StatTrakTech(Handle pPanel, MenuAction pAction, int Client, int Selection)
{
	if (pAction == MenuAction_Select && \
			g_bIsInGame[Client])
	{
		switch (Selection)
		{
			case 1:
			{
				g_bMessageShown[Client] = true;
				g_pStatTrakOption[Client] = StatTrakOption_Enabled;

				SetClientCookie(Client, g_pStatTrakOptionCookie, "2");

				PrintToChat(Client, ">>\x04 StatTrak™\x01 Technology\x05 ENABLED");
			}

			case 2:
			{
				g_bMessageShown[Client] = true;
				g_pStatTrakOption[Client] = StatTrakOption_Disabled;

				SetClientCookie(Client, g_pStatTrakOptionCookie, "1");

				PrintToChat(Client, ">>\x04 StatTrak™\x01 Technology\x07 DISABLED");
			}
		}
	}

	else if (pAction == MenuAction_End && \
				pPanel != INVALID_HANDLE)
	{
		CloseHandle(pPanel);
		pPanel = INVALID_HANDLE;
	}
}

public Action TimerHandler_DisplayStatTrakPanel(Handle pTimer, any Client)
{
	static Handle pPanel;

	if (g_bIsInGame[Client] && \
			g_pStatTrakOption[Client] == StatTrakOption_None)
	{
		pPanel = CreatePanel();

		if (pPanel != INVALID_HANDLE)
		{
			SetPanelTitle(pPanel, "Use StatTrak™ Technology?");

			SetPanelKeys(pPanel, 1 << 0 | 1 << 1);
			DrawPanelText(pPanel, "");

			DrawPanelText(pPanel, "1. Yes");
			DrawPanelText(pPanel, "2. No");

			if (!IsFakeClient(Client) && !IsClientSourceTV(Client))
				SendPanelToClient(pPanel, Client, PanelHandler_StatTrakTech, MENU_TIME_FOREVER);

			CloseHandle(pPanel);
			pPanel = INVALID_HANDLE;
		}
	}
}

public Action TimerHandler_DisplayKnivesMenu(Handle pTimer, any Client)
{
	static Handle pMenu;

	if (g_bIsInGame[Client] && !IsFakeClient(Client) && !IsClientSourceTV(Client))
	{
		pMenu = CreateMenu(MenuHandler_Knives);

		if (pMenu != INVALID_HANDLE)
		{
			SetMenuTitle(pMenu, "★ KNIVES MENU ★");

			AddMenuItem(pMenu, "1", "Default (NO CHANGE)");
			AddMenuItem(pMenu, "2", "★ Bowie (SURViVAL)");
			AddMenuItem(pMenu, "3", "★ Shadow Daggers (PUSH)");
			AddMenuItem(pMenu, "4", "★ M9 Bayonet");
			AddMenuItem(pMenu, "5", "★ Karambit");
			AddMenuItem(pMenu, "6", "★ Bayonet");
			AddMenuItem(pMenu, "7", "★ Huntsman (TACTiCAL)");
			AddMenuItem(pMenu, "8", "★ Butterfly");
			AddMenuItem(pMenu, "9", "★ Gut");
			AddMenuItem(pMenu, "10", "★ Flip");
			AddMenuItem(pMenu, "11", "★ Falchion");

			DisplayMenu(pMenu, Client, MENU_TIME_FOREVER);
		}
	}
}

public int MenuHandler_KnifeSkins(Handle pMenu, MenuAction pAction, int Client, int Skin)
{
	static char Option[MAX_NAME_LENGTH / 8], Info[MAX_NAME_LENGTH / 8];

	if (pAction == MenuAction_Select && \
			g_bIsInGame[Client])
	{
		GetMenuItem(pMenu, Skin, Info, sizeof(Info));

		switch (StringToInt(Info))
		{
			case -1:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Random;

				IntToString(view_as<int>(Knife_Skin_Random), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x05 » RANDOM «");
				replaceKnifeIfPossible(Client);
			}

			case 0:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Default;

				IntToString(view_as<int>(Knife_Skin_Default), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x09 » DEFAULT «");
				replaceKnifeIfPossible(Client);
			}

			case 38:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Fade;

				IntToString(view_as<int>(Knife_Skin_Fade), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Fade");
				replaceKnifeIfPossible(Client);
			}

			case 12:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Webs;

				IntToString(view_as<int>(Knife_Skin_Webs), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Crimson Web");
				replaceKnifeIfPossible(Client);
			}

			case 232:
			{
				g_pKnifeSkin[Client] = Knife_Skin_WebsDarker;

				IntToString(view_as<int>(Knife_Skin_WebsDarker), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Crimson Web (Darker)");
				replaceKnifeIfPossible(Client);
			}

			case 98:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Purple;

				IntToString(view_as<int>(Knife_Skin_Purple), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Ultraviolet");
				replaceKnifeIfPossible(Client);
			}

			case 44:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Oiled;

				IntToString(view_as<int>(Knife_Skin_Oiled), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Case Hardened");
				replaceKnifeIfPossible(Client);
			}

			case 5:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DDPat;

				IntToString(view_as<int>(Knife_Skin_DDPat), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Forest DDPAT");
				replaceKnifeIfPossible(Client);
			}

			case 40:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Night;

				IntToString(view_as<int>(Knife_Skin_Night), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Night");
				replaceKnifeIfPossible(Client);
			}

			case 413:
			{
				g_pKnifeSkin[Client] = Knife_Skin_MarbleFade;

				IntToString(view_as<int>(Knife_Skin_MarbleFade), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Marble Fade");
				replaceKnifeIfPossible(Client);
			}

			case 77:
			{
				g_pKnifeSkin[Client] = Knife_Skin_ForestBoreal;

				IntToString(view_as<int>(Knife_Skin_ForestBoreal), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Boreal Forest");
				replaceKnifeIfPossible(Client);
			}

			case 418:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerPhase1;

				IntToString(view_as<int>(Knife_Skin_DopplerPhase1), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Dopple Phase #1");
				replaceKnifeIfPossible(Client);
			}

			case 419:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerPhase2;

				IntToString(view_as<int>(Knife_Skin_DopplerPhase2), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Dopple Phase #2");
				replaceKnifeIfPossible(Client);
			}

			case 420:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerPhase3;

				IntToString(view_as<int>(Knife_Skin_DopplerPhase3), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Dopple Phase #3");
				replaceKnifeIfPossible(Client);
			}

			case 421:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerPhase4;

				IntToString(view_as<int>(Knife_Skin_DopplerPhase4), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Dopple Phase #4");
				replaceKnifeIfPossible(Client);
			}

			case 59:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Slaughter;

				IntToString(view_as<int>(Knife_Skin_Slaughter), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Slaughter");
				replaceKnifeIfPossible(Client);
			}

			case 42:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Blued;

				IntToString(view_as<int>(Knife_Skin_Blued), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Blue Steel");
				replaceKnifeIfPossible(Client);
			}

			case 409:
			{
				g_pKnifeSkin[Client] = Knife_Skin_TigerOrange;

				IntToString(view_as<int>(Knife_Skin_TigerOrange), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Tiger Tooth");
				replaceKnifeIfPossible(Client);
			}

			case 410:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Damascus;

				IntToString(view_as<int>(Knife_Skin_Damascus), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				if (g_pKnife[Client] == Knife_M9)
				{
					g_pKnifeSkin[Client] = Knife_Skin_Damascus90;

					IntToString(view_as<int>(Knife_Skin_Damascus90), Option, sizeof(Option));
					SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				}

				PrintToChat(Client, "* You selected\x07 Damascus Steel");
				replaceKnifeIfPossible(Client);
			}

			case 415:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerRuby;

				IntToString(view_as<int>(Knife_Skin_DopplerRuby), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Doppler (Ruby)");
				replaceKnifeIfPossible(Client);
			}

			case 416:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerSapphire;

				IntToString(view_as<int>(Knife_Skin_DopplerSapphire), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Doppler (Sapphire)");
				replaceKnifeIfPossible(Client);
			}

			case 417:
			{
				g_pKnifeSkin[Client] = Knife_Skin_DopplerBlackpearl;

				IntToString(view_as<int>(Knife_Skin_DopplerBlackpearl), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Doppler (Blackpearl)");
				replaceKnifeIfPossible(Client);
			}

			case 411:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Damascus90;

				IntToString(view_as<int>(Knife_Skin_Damascus90), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Damascus Steel");
				replaceKnifeIfPossible(Client);
			}

			case 43:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Stained;

				IntToString(view_as<int>(Knife_Skin_Stained), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Stained");
				replaceKnifeIfPossible(Client);
			}

			case 72:
			{
				g_pKnifeSkin[Client] = Knife_Skin_SafariMesh;

				IntToString(view_as<int>(Knife_Skin_SafariMesh), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Safari Mesh");
				replaceKnifeIfPossible(Client);
			}

			case 143:
			{
				g_pKnifeSkin[Client] = Knife_Skin_UrbanMasked;

				IntToString(view_as<int>(Knife_Skin_UrbanMasked), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Urban Masked");
				replaceKnifeIfPossible(Client);
			}

			case 175:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Scorched;

				IntToString(view_as<int>(Knife_Skin_Scorched), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Scorched");
				replaceKnifeIfPossible(Client);
			}

			case 414:
			{
				g_pKnifeSkin[Client] = Knife_Skin_RustCoat;

				IntToString(view_as<int>(Knife_Skin_RustCoat), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 Rust Coat");
				replaceKnifeIfPossible(Client);
			}

			case 558:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Bayonet_Lore;

				IntToString(view_as<int>(Knife_Skin_Bayonet_Lore), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Bayonet;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Bayonet* Lore");
				replaceKnifeIfPossible(Client);
			}

			case 559:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Flip_Lore;

				IntToString(view_as<int>(Knife_Skin_Flip_Lore), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Flip;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Flip* Lore");
				replaceKnifeIfPossible(Client);
			}

			case 560:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Gut_Lore;

				IntToString(view_as<int>(Knife_Skin_Gut_Lore), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Gut;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Gut* Lore");
				replaceKnifeIfPossible(Client);
			}

			case 561:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Karambit_Lore;

				IntToString(view_as<int>(Knife_Skin_Karambit_Lore), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Karambit;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Karambit* Lore");
				replaceKnifeIfPossible(Client);
			}

			case 562:
			{
				g_pKnifeSkin[Client] = Knife_Skin_M9_Bayonet_Lore;

				IntToString(view_as<int>(Knife_Skin_M9_Bayonet_Lore), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Lore");
				replaceKnifeIfPossible(Client);
			}

			case 563:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Bayonet_BLaminate;

				IntToString(view_as<int>(Knife_Skin_Bayonet_BLaminate), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Bayonet;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Bayonet* Black Laminate");
				replaceKnifeIfPossible(Client);
			}

			case 564:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Flip_BLaminate;

				IntToString(view_as<int>(Knife_Skin_Flip_BLaminate), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Flip;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Flip* Black Laminate");
				replaceKnifeIfPossible(Client);
			}

			case 565:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Gut_BLaminate;

				IntToString(view_as<int>(Knife_Skin_Gut_BLaminate), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Gut;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Gut* Black Laminate");
				replaceKnifeIfPossible(Client);
			}

			case 566:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Karambit_BLaminate;

				IntToString(view_as<int>(Knife_Skin_Karambit_BLaminate), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Karambit;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Karambit* Black Laminate");
				replaceKnifeIfPossible(Client);
			}

			case 567:
			{
				g_pKnifeSkin[Client] = Knife_Skin_M9_Bayonet_BLaminate;

				IntToString(view_as<int>(Knife_Skin_M9_Bayonet_BLaminate), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Black Laminate");
				replaceKnifeIfPossible(Client);
			}

			case 568:
			{
				g_pKnifeSkin[Client] = Knife_Skin_EmeraldMarbleized;

				IntToString(view_as<int>(Knife_Skin_EmeraldMarbleized), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 G. Doppler (Emerald)");
				replaceKnifeIfPossible(Client);
			}

			case 569:
			{
				g_pKnifeSkin[Client] = Knife_Skin_GDoppler_P1;

				IntToString(view_as<int>(Knife_Skin_GDoppler_P1), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 G. Doppler Phase #1");
				replaceKnifeIfPossible(Client);
			}

			case 570:
			{
				g_pKnifeSkin[Client] = Knife_Skin_GDoppler_P2;

				IntToString(view_as<int>(Knife_Skin_GDoppler_P2), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 G. Doppler Phase #2");
				replaceKnifeIfPossible(Client);
			}

			case 571:
			{
				g_pKnifeSkin[Client] = Knife_Skin_GDoppler_P3;

				IntToString(view_as<int>(Knife_Skin_GDoppler_P3), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 G. Doppler Phase #3");
				replaceKnifeIfPossible(Client);
			}

			case 572:
			{
				g_pKnifeSkin[Client] = Knife_Skin_GDoppler_P4;

				IntToString(view_as<int>(Knife_Skin_GDoppler_P4), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				PrintToChat(Client, "* You selected\x07 G. Doppler Phase #4");
				replaceKnifeIfPossible(Client);
			}

			case 573:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Bayonet_Auto;

				IntToString(view_as<int>(Knife_Skin_Bayonet_Auto), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Bayonet;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Bayonet* Autotronic");
				replaceKnifeIfPossible(Client);
			}

			case 574:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Flip_Auto;

				IntToString(view_as<int>(Knife_Skin_Flip_Auto), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Flip;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Flip* Autotronic");
				replaceKnifeIfPossible(Client);
			}

			case 575:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Gut_Auto;

				IntToString(view_as<int>(Knife_Skin_Gut_Auto), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Gut;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Gut* Autotronic");
				replaceKnifeIfPossible(Client);
			}

			case 576:
			{
				g_pKnifeSkin[Client] = Knife_Skin_Karambit_Auto;

				IntToString(view_as<int>(Knife_Skin_Karambit_Auto), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Karambit;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Karambit* Autotronic");
				replaceKnifeIfPossible(Client);
			}

			case 577:
			{
				g_pKnifeSkin[Client] = Knife_Skin_M9_Bayonet_Auto;

				IntToString(view_as<int>(Knife_Skin_M9_Bayonet_Auto), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Autotronic");
				replaceKnifeIfPossible(Client);
			}

			case 578:
			{
				g_pKnifeSkin[Client] = Knife_Skin_BrightWater;

				IntToString(view_as<int>(Knife_Skin_BrightWater), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				if (g_pKnife[Client] == Knife_M9)
				{
					g_pKnifeSkin[Client] = Knife_Skin_BrightWater_M9;

					IntToString(view_as<int>(Knife_Skin_BrightWater_M9), Option, sizeof(Option));
					SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				}

				PrintToChat(Client, "* You selected\x07 Bright Water");
				replaceKnifeIfPossible(Client);
			}

			case 579:
			{
				g_pKnifeSkin[Client] = Knife_Skin_BrightWater_M9;

				IntToString(view_as<int>(Knife_Skin_BrightWater_M9), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Bright Water");
				replaceKnifeIfPossible(Client);
			}

			case 580:
			{
				g_pKnifeSkin[Client] = Knife_Skin_FreeHand;

				IntToString(view_as<int>(Knife_Skin_FreeHand), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);

				if (g_pKnife[Client] == Knife_M9)
				{
					g_pKnifeSkin[Client] = Knife_Skin_FreeHand_M9;

					IntToString(view_as<int>(Knife_Skin_FreeHand_M9), Option, sizeof(Option));
					SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				}

				if (g_pKnife[Client] == Knife_Karambit)
				{
					g_pKnifeSkin[Client] = Knife_Skin_FreeHand_Karambit;

					IntToString(view_as<int>(Knife_Skin_FreeHand_Karambit), Option, sizeof(Option));
					SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				}

				PrintToChat(Client, "* You selected\x07 Freehand");
				replaceKnifeIfPossible(Client);
			}

			case 581:
			{
				g_pKnifeSkin[Client] = Knife_Skin_FreeHand_M9;

				IntToString(view_as<int>(Knife_Skin_FreeHand_M9), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_M9;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 M9 Bayonet* Freehand");
				replaceKnifeIfPossible(Client);
			}

			case 582:
			{
				g_pKnifeSkin[Client] = Knife_Skin_FreeHand_Karambit;

				IntToString(view_as<int>(Knife_Skin_FreeHand_Karambit), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeSkinCookie, Option);
				
				g_pKnife[Client] = Knife_Karambit;
				IntToString(view_as<int>(g_pKnife[Client]), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);
				
				PrintToChat(Client, "* You selected\x07 Karambit* Freehand");
				replaceKnifeIfPossible(Client);
			}
		}
	}

	else if (pAction == MenuAction_End && \
				pMenu != INVALID_HANDLE)
	{
		CloseHandle(pMenu);
		pMenu = INVALID_HANDLE;
	}
}

public int MenuHandler_Knives(Handle pMenu, MenuAction pAction, int Client, int Knife)
{
	static char Option[MAX_NAME_LENGTH / 8], Info[MAX_NAME_LENGTH / 8];

	if (pAction == MenuAction_Select && \
			g_bIsInGame[Client])
	{
		GetMenuItem(pMenu, Knife, Info, sizeof(Info));

		switch (StringToInt(Info))
		{
			case 1:
			{
				g_pKnife[Client] = Knife_Default;

				IntToString(view_as<int>(Knife_Default), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x09 Default\x05 (NO CHANGE)");
				replaceKnifeIfPossible(Client);
			}
			
			case 2:
			{
				g_pKnife[Client] = Knife_Bowie;

				IntToString(view_as<int>(Knife_Bowie), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Bowie (SURViVAL)\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}
			
			case 3:
			{
				g_pKnife[Client] = Knife_Push;

				IntToString(view_as<int>(Knife_Push), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Shadow Daggers\x05 (PUSH)\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 4:
			{
				g_pKnife[Client] = Knife_M9;

				IntToString(view_as<int>(Knife_M9), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ M9 Bayonet\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 5:
			{
				g_pKnife[Client] = Knife_Karambit;

				IntToString(view_as<int>(Knife_Karambit), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Karambit\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 6:
			{
				g_pKnife[Client] = Knife_Bayonet;

				IntToString(view_as<int>(Knife_Bayonet), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Bayonet\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 7:
			{
				g_pKnife[Client] = Knife_Tactical;

				IntToString(view_as<int>(Knife_Tactical), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Huntsman\x05 (TACTiCAL)\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 8:
			{
				g_pKnife[Client] = Knife_Butterfly;

				IntToString(view_as<int>(Knife_Butterfly), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Butterfly\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 9:
			{
				g_pKnife[Client] = Knife_Gut;

				IntToString(view_as<int>(Knife_Gut), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Gut\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 10:
			{
				g_pKnife[Client] = Knife_Flip;

				IntToString(view_as<int>(Knife_Flip), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Flip\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}

			case 11:
			{
				g_pKnife[Client] = Knife_Falchion;

				IntToString(view_as<int>(Knife_Falchion), Option, sizeof(Option));
				SetClientCookie(Client, g_pKnifeCookie, Option);

				PrintToChat(Client, "* You selected\x07 ★ Falchion\x01. You can also type\x04 WS\x01 now.");
				replaceKnifeIfPossible(Client);
			}
		}
	}

	else if (pAction == MenuAction_End && \
				pMenu != INVALID_HANDLE)
	{
		CloseHandle(pMenu);
		pMenu = INVALID_HANDLE;
	}
}

public int __EquipKnife(Handle pPlugin, int iParams)
{
	static int iId = INVALID_ENT_REFERENCE, Entity, Id;
	static char Class[MAX_NAME_LENGTH] = "";
	
	iId = GetNativeCell(1);
	
	if (IsClientInGame(iId) && IsPlayerAlive(iId))
	{
		if (g_iFakeClient != INVALID_ENT_REFERENCE)
		{
			KnifeClassByOption(iId, Class, sizeof(Class));
			Entity = GivePlayerItem(g_pKnife[iId] == Knife_None || g_pKnife[iId] == Knife_Default ? \
														iId : g_iFakeClient, Class);

			if (Entity != INVALID_ENT_REFERENCE)
			{
				Id = IDIByClass(Class);

				if (g_pKnife[iId] != Knife_None && g_pKnife[iId] != Knife_Default)
					SetEntProp(Entity, Prop_Send, "m_iItemDefinitionIndex", Id);

				applyKnifeData(iId, Entity, Id);
				EquipPlayerWeapon(iId, Entity);
			}
		}
	}
}

public Action Timer_ReplaceKnife(Handle pTimer, any _Data)
{
	static int iId = INVALID_ENT_REFERENCE;
	static bool bSkipInRound = false;
	
	ResetPack(_Data);
	
	iId = ReadPackCell(_Data);
	bSkipInRound = ReadPackCell(_Data) ? true : false;
	
	CloseHandle(_Data);
	_Data = INVALID_HANDLE;
	
	replaceKnifeIfPossible(iId, bSkipInRound);
}

void replaceKnifeIfPossible(int Client, bool bSkipInRound = false)
{
	static char Class[MAX_NAME_LENGTH];
	static int Entity, Tries, Id;
	static float fGameTime = 0.0;
	static Handle pData = INVALID_HANDLE;

	if ((bSkipInRound == false || g_bIsInRound) && Client >= 1 && Client <= MaxClients && IsClientInGame(Client) && IsPlayerAlive(Client))
	{
		fGameTime = GetEngineTime();
		
		if (fGameTime - g_fDelay < 0.075)
		{
			pData = CreateDataPack();
			
			if (pData != INVALID_HANDLE)
			{
				WritePackCell(pData, Client);
				WritePackCell(pData, bSkipInRound ? 1 : 0);
				
				CreateTimer(GetRandomFloat(0.05, 0.075), Timer_ReplaceKnife, pData);
			}
		}
		
		else
		{
			Entity = INVALID_ENT_REFERENCE;
			Tries = 0;

			while ((Entity = GetPlayerWeaponSlot(Client, CS_SLOT_KNIFE)) != INVALID_ENT_REFERENCE)
			{
				if (GetEdictClassname(Entity, Class, sizeof(Class)) && \
						(StrContains(Class, "Knife", false) != -1 || \
							StrContains(Class, "Bayonet", false) != -1))
				{
					if (RemovePlayerItem(Client, Entity))
					{
						my_Remove(Entity);

						if (g_iFakeClient != INVALID_ENT_REFERENCE)
						{
							KnifeClassByOption(Client, Class, sizeof(Class));
							Entity = GivePlayerItem(g_pKnife[Client] == Knife_None || g_pKnife[Client] == Knife_Default ? \
															Client : g_iFakeClient, Class);

							if (Entity != INVALID_ENT_REFERENCE)
							{
								Id = IDIByClass(Class);
								
								if (g_pKnife[Client] != Knife_None && g_pKnife[Client] != Knife_Default)
									SetEntProp(Entity, Prop_Send, "m_iItemDefinitionIndex", Id);
								
								applyKnifeData(Client, Entity, Id);
								EquipPlayerWeapon(Client, Entity);
							}
						}
					}

					break;
				}

				if (++Tries >= 4)
					break;
			}
			
			SaveMe(Client);
			
			g_fDelay = fGameTime;
		}
	}
}

public Action TimerHandler_DisplaySkinsMenu(Handle pTimer, any Client)
{
	static Handle pMenu;
	static int WeaponId, Id, Iter;
	static char Buffer[PLATFORM_MAX_PATH], Info[MAX_NAME_LENGTH / 4], \
					Class[MAX_NAME_LENGTH];

	if (g_bIsInGame[Client] && !IsFakeClient(Client) && !IsClientSourceTV(Client))
	{
		if (IsPlayerAlive(Client))
			WeaponId = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");

		else
			WeaponId = INVALID_ENT_REFERENCE;

		if (g_pKnifeSkin[Client] == Knife_Skin_None)
		{
			PrintToChat(Client, "* FiRST, PiCK UP A\x07 KNiFE\x05 PAiNT KiT\x09 OPTiON");

			pMenu = CreateMenu(MenuHandler_KnifeSkins);

			if (pMenu != INVALID_HANDLE)
			{
				SetMenuTitle(pMenu, "★ SELECT KNiFE SKiN ★");

				AddMenuItem(pMenu, "-1", "» RANDOM «");
				AddMenuItem(pMenu, "0", "» DEFAULT «");

				AddMenuItem(pMenu, "411", "M9 Bayonet* Damascus Steel");
				AddMenuItem(pMenu, "562", "M9 Bayonet* Lore");
				AddMenuItem(pMenu, "567", "M9 Bayonet* Black Laminate");
				AddMenuItem(pMenu, "577", "M9 Bayonet* Autotronic");
				AddMenuItem(pMenu, "579", "M9 Bayonet* Bright Water");
				AddMenuItem(pMenu, "581", "M9 Bayonet* Freehand");

				AddMenuItem(pMenu, "558", "Bayonet* Lore");
				AddMenuItem(pMenu, "563", "Bayonet* Black Laminate");
				AddMenuItem(pMenu, "573", "Bayonet* Autotronic");

				AddMenuItem(pMenu, "559", "Flip* Lore");
				AddMenuItem(pMenu, "564", "Flip* Black Laminate");
				AddMenuItem(pMenu, "574", "Flip* Autotronic");

				AddMenuItem(pMenu, "560", "Gut* Lore");
				AddMenuItem(pMenu, "565", "Gut* Black Laminate");
				AddMenuItem(pMenu, "575", "Gut* Autotronic");

				AddMenuItem(pMenu, "561", "Karambit* Lore");
				AddMenuItem(pMenu, "566", "Karambit* Black Laminate");
				AddMenuItem(pMenu, "576", "Karambit* Autotronic");
				AddMenuItem(pMenu, "582", "Karambit* Freehand");

				AddMenuItem(pMenu, "580", "Any* Freehand");
				AddMenuItem(pMenu, "578", "Any* Bright Water");

				AddMenuItem(pMenu, "569", "Any* G. Doppler Phase #1");
				AddMenuItem(pMenu, "570", "Any* G. Doppler Phase #2");
				AddMenuItem(pMenu, "571", "Any* G. Doppler Phase #3");
				AddMenuItem(pMenu, "572", "Any* G. Doppler Phase #4");
				AddMenuItem(pMenu, "568", "Any* G. Doppler (Emerald)");

				AddMenuItem(pMenu, "418", "Any* Doppler Phase #1");
				AddMenuItem(pMenu, "419", "Any* Doppler Phase #2");
				AddMenuItem(pMenu, "420", "Any* Doppler Phase #3");
				AddMenuItem(pMenu, "421", "Any* Doppler Phase #4");
				AddMenuItem(pMenu, "415", "Any* Doppler (Ruby)");
				AddMenuItem(pMenu, "416", "Any* Doppler (Sapphire)");
				AddMenuItem(pMenu, "417", "Any* Doppler (Blackpearl)");
				
				AddMenuItem(pMenu, "38", "Any* Fade");
				AddMenuItem(pMenu, "413", "Any* Marble Fade");
				AddMenuItem(pMenu, "44", "Any* Case Hardened");
				AddMenuItem(pMenu, "59", "Any* Slaughter");
				AddMenuItem(pMenu, "12", "Any* Crimson Web");
				AddMenuItem(pMenu, "232", "Any* Crimson Web (Darker)");
				AddMenuItem(pMenu, "98", "Any* Ultraviolet");
				AddMenuItem(pMenu, "40", "Any* Night");
				AddMenuItem(pMenu, "5", "Any* Forest DDPAT");
				AddMenuItem(pMenu, "77", "Any* Boreal Forest");
				AddMenuItem(pMenu, "42", "Any* Blue Steel");
				AddMenuItem(pMenu, "410", "Any* Damascus Steel");
				AddMenuItem(pMenu, "43", "Any* Stained");
				AddMenuItem(pMenu, "72", "Any* Safari Mesh");
				AddMenuItem(pMenu, "143", "Any* Urban Masked");
				AddMenuItem(pMenu, "175", "Any* Scorched");
				AddMenuItem(pMenu, "414", "Any* Rust Coat");
				AddMenuItem(pMenu, "409", "Any* Tiger Tooth");

				DisplayMenu(pMenu, Client, MENU_TIME_FOREVER);
			}
		}

		else if (WeaponId != INVALID_ENT_REFERENCE && \
					GetEdictClassname(WeaponId, Class, sizeof(Class)) && \
						(StrContains(Class, "Knife", false) != -1 || StrContains(Class, "Bayonet", false) != -1))
		{
			pMenu = CreateMenu(MenuHandler_KnifeSkins);

			if (g_pKnife[Client] == Knife_None)
			{
				if (pMenu != INVALID_HANDLE)
				{
					SetMenuTitle(pMenu, "★ SELECT KNiFE SKiN ★");

					AddMenuItem(pMenu, "-1", "» RANDOM «");
					AddMenuItem(pMenu, "0", "» DEFAULT «");

					AddMenuItem(pMenu, "411", "M9 Bayonet* Damascus Steel");
					AddMenuItem(pMenu, "562", "M9 Bayonet* Lore");
					AddMenuItem(pMenu, "567", "M9 Bayonet* Black Laminate");
					AddMenuItem(pMenu, "577", "M9 Bayonet* Autotronic");
					AddMenuItem(pMenu, "579", "M9 Bayonet* Bright Water");
					AddMenuItem(pMenu, "581", "M9 Bayonet* Freehand");

					AddMenuItem(pMenu, "558", "Bayonet* Lore");
					AddMenuItem(pMenu, "563", "Bayonet* Black Laminate");
					AddMenuItem(pMenu, "573", "Bayonet* Autotronic");

					AddMenuItem(pMenu, "559", "Flip* Lore");
					AddMenuItem(pMenu, "564", "Flip* Black Laminate");
					AddMenuItem(pMenu, "574", "Flip* Autotronic");

					AddMenuItem(pMenu, "560", "Gut* Lore");
					AddMenuItem(pMenu, "565", "Gut* Black Laminate");
					AddMenuItem(pMenu, "575", "Gut* Autotronic");

					AddMenuItem(pMenu, "561", "Karambit* Lore");
					AddMenuItem(pMenu, "566", "Karambit* Black Laminate");
					AddMenuItem(pMenu, "576", "Karambit* Autotronic");
					AddMenuItem(pMenu, "582", "Karambit* Freehand");

					AddMenuItem(pMenu, "580", "Any* Freehand");
					AddMenuItem(pMenu, "578", "Any* Bright Water");

					AddMenuItem(pMenu, "569", "Any* G. Doppler Phase #1");
					AddMenuItem(pMenu, "570", "Any* G. Doppler Phase #2");
					AddMenuItem(pMenu, "571", "Any* G. Doppler Phase #3");
					AddMenuItem(pMenu, "572", "Any* G. Doppler Phase #4");
					AddMenuItem(pMenu, "568", "Any* G. Doppler (Emerald)");

					AddMenuItem(pMenu, "418", "Any* Doppler Phase #1");
					AddMenuItem(pMenu, "419", "Any* Doppler Phase #2");
					AddMenuItem(pMenu, "420", "Any* Doppler Phase #3");
					AddMenuItem(pMenu, "421", "Any* Doppler Phase #4");
					AddMenuItem(pMenu, "415", "Any* Doppler (Ruby)");
					AddMenuItem(pMenu, "416", "Any* Doppler (Sapphire)");
					AddMenuItem(pMenu, "417", "Any* Doppler (Blackpearl)");

					AddMenuItem(pMenu, "38", "Any* Fade");
					AddMenuItem(pMenu, "413", "Any* Marble Fade");
					AddMenuItem(pMenu, "44", "Any* Case Hardened");
					AddMenuItem(pMenu, "59", "Any* Slaughter");
					AddMenuItem(pMenu, "12", "Any* Crimson Web");
					AddMenuItem(pMenu, "232", "Any* Crimson Web (Darker)");
					AddMenuItem(pMenu, "98", "Any* Ultraviolet");
					AddMenuItem(pMenu, "40", "Any* Night");
					AddMenuItem(pMenu, "5", "Any* Forest DDPAT");
					AddMenuItem(pMenu, "77", "Any* Boreal Forest");
					AddMenuItem(pMenu, "42", "Any* Blue Steel");
					AddMenuItem(pMenu, "410", "Any* Damascus Steel");
					AddMenuItem(pMenu, "43", "Any* Stained");
					AddMenuItem(pMenu, "72", "Any* Safari Mesh");
					AddMenuItem(pMenu, "143", "Any* Urban Masked");
					AddMenuItem(pMenu, "175", "Any* Scorched");
					AddMenuItem(pMenu, "414", "Any* Rust Coat");
					AddMenuItem(pMenu, "409", "Any* Tiger Tooth");

					DisplayMenu(pMenu, Client, MENU_TIME_FOREVER);
				}
			}

			else
			{
				if (pMenu != INVALID_HANDLE)
				{
					SetMenuTitle(pMenu, "★ SELECT KNiFE SKiN ★");

					AddMenuItem(pMenu, "-1", "» RANDOM «");
					AddMenuItem(pMenu, "0", "» DEFAULT «");

					if (g_pKnife[Client] == Knife_M9)
					{
						AddMenuItem(pMenu, "411", "M9 Bayonet* Damascus Steel");
						AddMenuItem(pMenu, "562", "M9 Bayonet* Lore");
						AddMenuItem(pMenu, "567", "M9 Bayonet* Black Laminate");
						AddMenuItem(pMenu, "577", "M9 Bayonet* Autotronic");
						AddMenuItem(pMenu, "579", "M9 Bayonet* Bright Water");
						AddMenuItem(pMenu, "581", "M9 Bayonet* Freehand");
					}

					if (g_pKnife[Client] == Knife_Bayonet)
					{
						AddMenuItem(pMenu, "558", "Bayonet* Lore");
						AddMenuItem(pMenu, "563", "Bayonet* Black Laminate");
						AddMenuItem(pMenu, "573", "Bayonet* Autotronic");
					}

					if (g_pKnife[Client] == Knife_Flip)
					{
						AddMenuItem(pMenu, "559", "Flip* Lore");
						AddMenuItem(pMenu, "564", "Flip* Black Laminate");
						AddMenuItem(pMenu, "574", "Flip* Autotronic");
					}

					if (g_pKnife[Client] == Knife_Gut)
					{
						AddMenuItem(pMenu, "560", "Gut* Lore");
						AddMenuItem(pMenu, "565", "Gut* Black Laminate");
						AddMenuItem(pMenu, "575", "Gut* Autotronic");
					}

					if (g_pKnife[Client] == Knife_Karambit)
					{
						AddMenuItem(pMenu, "561", "Karambit* Lore");
						AddMenuItem(pMenu, "566", "Karambit* Black Laminate");
						AddMenuItem(pMenu, "576", "Karambit* Autotronic");
						AddMenuItem(pMenu, "582", "Karambit* Freehand");
					}

					AddMenuItem(pMenu, "580", "Any* Freehand");
					AddMenuItem(pMenu, "578", "Any* Bright Water");
					
					AddMenuItem(pMenu, "569", "Any* G. Doppler Phase #1");
					AddMenuItem(pMenu, "570", "Any* G. Doppler Phase #2");
					AddMenuItem(pMenu, "571", "Any* G. Doppler Phase #3");
					AddMenuItem(pMenu, "572", "Any* G. Doppler Phase #4");
					AddMenuItem(pMenu, "568", "Any* G. Doppler (Emerald)");

					AddMenuItem(pMenu, "418", "Any* Doppler Phase #1");
					AddMenuItem(pMenu, "419", "Any* Doppler Phase #2");
					AddMenuItem(pMenu, "420", "Any* Doppler Phase #3");
					AddMenuItem(pMenu, "421", "Any* Doppler Phase #4");
					AddMenuItem(pMenu, "415", "Any* Doppler (Ruby)");
					AddMenuItem(pMenu, "416", "Any* Doppler (Sapphire)");
					AddMenuItem(pMenu, "417", "Any* Doppler (Blackpearl)");

					AddMenuItem(pMenu, "38", "Any* Fade");
					AddMenuItem(pMenu, "413", "Any* Marble Fade");
					AddMenuItem(pMenu, "44", "Any* Case Hardened");
					AddMenuItem(pMenu, "59", "Any* Slaughter");
					AddMenuItem(pMenu, "12", "Any* Crimson Web");
					AddMenuItem(pMenu, "232", "Any* Crimson Web (Darker)");
					AddMenuItem(pMenu, "98", "Any* Ultraviolet");
					AddMenuItem(pMenu, "40", "Any* Night");
					AddMenuItem(pMenu, "5", "Any* Forest DDPAT");
					AddMenuItem(pMenu, "77", "Any* Boreal Forest");
					AddMenuItem(pMenu, "42", "Any* Blue Steel");
					AddMenuItem(pMenu, "410", "Any* Damascus Steel");
					AddMenuItem(pMenu, "43", "Any* Stained");
					AddMenuItem(pMenu, "72", "Any* Safari Mesh");
					AddMenuItem(pMenu, "143", "Any* Urban Masked");
					AddMenuItem(pMenu, "175", "Any* Scorched");
					AddMenuItem(pMenu, "414", "Any* Rust Coat");
					AddMenuItem(pMenu, "409", "Any* Tiger Tooth");

					DisplayMenu(pMenu, Client, MENU_TIME_FOREVER);
				}
			}
		}

		else if (!IsPlayerAlive(Client))
			PrintToChat(Client, "* You must be\x05 Alive");

		else
		{
			if (WeaponId == INVALID_ENT_REFERENCE)
				PrintToChat(Client, "* You must have an\x05 Active\x09 Weapon");

			else
			{
				Id = GetEntProp(WeaponId, Prop_Send, "m_iItemDefinitionIndex");

				pMenu = CreateMenu(MenuHandler_Skins);

				if (pMenu != INVALID_HANDLE)
				{
					switch (Id)
					{
						case 4:
						{
							SetMenuTitle(pMenu, "Select Glock-18 Skin");

							for (Iter = 0; Iter < sizeof(g_Glock18Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Glock18Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 2:
						{
							SetMenuTitle(pMenu, "Select Dual Berettas Skin");

							for (Iter = 0; Iter < sizeof(g_DualBerettasSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_DualBerettasSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 36:
						{
							SetMenuTitle(pMenu, "Select P250 Skin");

							for (Iter = 0; Iter < sizeof(g_P250Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_P250Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 30:
						{
							SetMenuTitle(pMenu, "Select Tec-9 Skin");

							for (Iter = 0; Iter < sizeof(g_Tec9Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Tec9Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 1:
						{
							SetMenuTitle(pMenu, "Select Desert Eagle Skin");

							for (Iter = 0; Iter < sizeof(g_DEagleSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_DEagleSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 35:
						{
							SetMenuTitle(pMenu, "Select Nova Skin");

							for (Iter = 0; Iter < sizeof(g_NovaSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_NovaSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 25:
						{
							SetMenuTitle(pMenu, "Select XM1014 Skin");

							for (Iter = 0; Iter < sizeof(g_XM1014Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_XM1014Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 29:
						{
							SetMenuTitle(pMenu, "Select Sawed-Off Skin");

							for (Iter = 0; Iter < sizeof(g_SawedOffSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_SawedOffSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 14:
						{
							SetMenuTitle(pMenu, "Select M249 Skin");

							for (Iter = 0; Iter < sizeof(g_M249Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_M249Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 28:
						{
							SetMenuTitle(pMenu, "Select Negev Skin");

							for (Iter = 0; Iter < sizeof(g_NegevSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_NegevSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 17:
						{
							SetMenuTitle(pMenu, "Select MAC-10 Skin");

							for (Iter = 0; Iter < sizeof(g_Mac10Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Mac10Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 33:
						{
							SetMenuTitle(pMenu, "Select MP7 Skin");

							for (Iter = 0; Iter < sizeof(g_Mp7Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Mp7Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 24:
						{
							SetMenuTitle(pMenu, "Select UMP-45 Skin");

							for (Iter = 0; Iter < sizeof(g_Ump45Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Ump45Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 19:
						{
							SetMenuTitle(pMenu, "Select P90 Skin");

							for (Iter = 0; Iter < sizeof(g_P90Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_P90Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 26:
						{
							SetMenuTitle(pMenu, "Select PP-Bizon Skin");

							for (Iter = 0; Iter < sizeof(g_PPBizonSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_PPBizonSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 13:
						{
							SetMenuTitle(pMenu, "Select Galil AR Skin");

							for (Iter = 0; Iter < sizeof(g_GalilARSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_GalilARSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 7:
						{
							SetMenuTitle(pMenu, "Select AK-47 Skin");

							for (Iter = 0; Iter < sizeof(g_Ak47Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Ak47Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 40:
						{
							SetMenuTitle(pMenu, "Select SSG 08 Skin");

							for (Iter = 0; Iter < sizeof(g_SSG08Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_SSG08Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 39:
						{
							SetMenuTitle(pMenu, "Select SG 553 Skin");

							for (Iter = 0; Iter < sizeof(g_SG553Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_SG553Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 9:
						{
							SetMenuTitle(pMenu, "Select AWP Skin");

							for (Iter = 0; Iter < sizeof(g_AwpSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_AwpSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 11:
						{
							SetMenuTitle(pMenu, "Select G3SG1 Skin");

							for (Iter = 0; Iter < sizeof(g_G3SG1Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_G3SG1Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 61:
						{
							SetMenuTitle(pMenu, "Select USP-S Skin");

							for (Iter = 0; Iter < sizeof(g_UspSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_UspSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 3:
						{
							SetMenuTitle(pMenu, "Select Five-SeveN Skin");

							for (Iter = 0; Iter < sizeof(g_FiveSeveNSKins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_FiveSeveNSKins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 27:
						{
							SetMenuTitle(pMenu, "Select MAG-7 Skin");

							for (Iter = 0; Iter < sizeof(g_Mag7Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Mag7Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 34:
						{
							SetMenuTitle(pMenu, "Select MP9 Skin");

							for (Iter = 0; Iter < sizeof(g_Mp9Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Mp9Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 10:
						{
							SetMenuTitle(pMenu, "Select FAMAS Skin");

							for (Iter = 0; Iter < sizeof(g_FamasSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_FamasSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 60:
						{
							SetMenuTitle(pMenu, "Select M4A1-S Skin");

							for (Iter = 0; Iter < sizeof(g_M4A1Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_M4A1Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 8:
						{
							SetMenuTitle(pMenu, "Select AUG Skin");

							for (Iter = 0; Iter < sizeof(g_AugSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_AugSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 38:
						{
							SetMenuTitle(pMenu, "Select SCAR-20 Skin");

							for (Iter = 0; Iter < sizeof(g_Scar20Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_Scar20Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 32:
						{
							SetMenuTitle(pMenu, "Select P2000 Skin");

							for (Iter = 0; Iter < sizeof(g_P2000Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_P2000Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 16:
						{
							SetMenuTitle(pMenu, "Select M4A4 Skin");

							for (Iter = 0; Iter < sizeof(g_M4A4Skins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_M4A4Skins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 63:
						{
							SetMenuTitle(pMenu, "Select CZ75-Auto Skin");

							for (Iter = 0; Iter < sizeof(g_CZ75AutoSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_CZ75AutoSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}
						case 64:
						{
							SetMenuTitle(pMenu, "Select R8 Revolver Skin");

							for (Iter = 0; Iter < sizeof(g_RevolverSkins); Iter++)
								FormatEx(Buffer, sizeof(Buffer), g_RevolverSkins[Iter]),
								IntToString(Iter, Info, sizeof(Info)),
								AddMenuItem(pMenu, Info, Buffer);
						}

						default:
						{
							SetMenuTitle(pMenu, "Select <???> Skin");
							AddMenuItem(pMenu, "0", "Default");
						}
					}

					g_ItemDefinitionIndex[Client] = Id;

					DisplayMenu(pMenu, Client, MENU_TIME_FOREVER);
				}
			}
		}
	}
}

public Action TimerHandler_DisplayStatTrakDetails(Handle pTimer, any Client)
{
	if (g_bIsInGame[Client] && !g_bMessageShown[Client])
	{
		PrintHintText(Client, "Type <font color='#00FF00'>!ST</font> for <font color='#FF0000'>StatTrak™</font> weapons.");
		PrintToChat(Client, ">> Type\x07 !ST\x01 for\x09 StatTrak™\x01 weapons.");

		g_bMessageShown[Client] = true;
	}
}

void my_Remove(int Data)
{
	AcceptEntityInput(Data, "KillHierarchy");
}

bool ClassById(int Id, char[] Class, int Size)
{
	switch (Id)
	{
		case 4: FormatEx(Class, Size, "weapon_glock");
		case 2: FormatEx(Class, Size, "weapon_elite");
		case 36: FormatEx(Class, Size, "weapon_p250");
		case 30: FormatEx(Class, Size, "weapon_tec9");
		case 1: FormatEx(Class, Size, "weapon_deagle");
		case 35: FormatEx(Class, Size, "weapon_nova");
		case 25: FormatEx(Class, Size, "weapon_xm1014");
		case 29: FormatEx(Class, Size, "weapon_sawedoff");
		case 14: FormatEx(Class, Size, "weapon_m249");
		case 28: FormatEx(Class, Size, "weapon_negev");
		case 17: FormatEx(Class, Size, "weapon_mac10");
		case 33: FormatEx(Class, Size, "weapon_mp7");
		case 24: FormatEx(Class, Size, "weapon_ump45");
		case 19: FormatEx(Class, Size, "weapon_p90");
		case 26: FormatEx(Class, Size, "weapon_bizon");
		case 13: FormatEx(Class, Size, "weapon_galilar");
		case 7: FormatEx(Class, Size, "weapon_ak47");
		case 40: FormatEx(Class, Size, "weapon_ssg08");
		case 39: FormatEx(Class, Size, "weapon_sg556");
		case 9: FormatEx(Class, Size, "weapon_awp");
		case 11: FormatEx(Class, Size, "weapon_g3sg1");
		case 61: FormatEx(Class, Size, "weapon_usp_silencer");
		case 3: FormatEx(Class, Size, "weapon_fiveseven");
		case 27: FormatEx(Class, Size, "weapon_mag7");
		case 34: FormatEx(Class, Size, "weapon_mp9");
		case 10: FormatEx(Class, Size, "weapon_famas");
		case 60: FormatEx(Class, Size, "weapon_m4a1_silencer");
		case 8: FormatEx(Class, Size, "weapon_aug");
		case 38: FormatEx(Class, Size, "weapon_scar20");
		case 32: FormatEx(Class, Size, "weapon_hkp2000");
		case 16: FormatEx(Class, Size, "weapon_m4a1");
		case 63: FormatEx(Class, Size, "weapon_cz75a");
		case 64: FormatEx(Class, Size, "weapon_revolver");
		case 500: FormatEx(Class, Size, "weapon_bayonet");
		case 505: FormatEx(Class, Size, "weapon_knife_flip");
		case 506: FormatEx(Class, Size, "weapon_knife_gut");
		case 507: FormatEx(Class, Size, "weapon_knife_karambit");
		case 508: FormatEx(Class, Size, "weapon_knife_m9_bayonet");
		case 509: FormatEx(Class, Size, "weapon_knife_tactical");
		case 512: FormatEx(Class, Size, "weapon_knife_falchion");
		case 514: FormatEx(Class, Size, "weapon_knife_survival_bowie");
		case 515: FormatEx(Class, Size, "weapon_knife_butterfly");
		case 516: FormatEx(Class, Size, "weapon_knife_push");
		case 42: FormatEx(Class, Size, "weapon_knife");
		case 59: FormatEx(Class, Size, "weapon_knife_t");

		default: Class[0] = EOS;
	}

	return Class[0] != EOS ? true : false;
}

int IDIByClass(char[] szClass)
{
	if (!strcmp(szClass, "weapon_bayonet")) return 500;

	else if (!strcmp(szClass, "weapon_knife_flip")) return 505;
	else if (!strcmp(szClass, "weapon_knife_gut")) return 506;
	else if (!strcmp(szClass, "weapon_knife_karambit")) return 507;
	else if (!strcmp(szClass, "weapon_knife_m9_bayonet")) return 508;
	else if (!strcmp(szClass, "weapon_knife_tactical")) return 509;
	else if (!strcmp(szClass, "weapon_knife_falchion")) return 512;
	else if (!strcmp(szClass, "weapon_knife_survival_bowie")) return 514;
	else if (!strcmp(szClass, "weapon_knife_butterfly")) return 515;
	else if (!strcmp(szClass, "weapon_knife_push")) return 516;
	else if (!strcmp(szClass, "weapon_knife")) return 42;
	else if (!strcmp(szClass, "weapon_knife_t")) return 59;

	return 0;
}

#if !defined _hattrick_csgo_included
	int hCSGO_PureChatCommand(char[] Input, char[] Output, int Size)
	{
		static int m_Iterator, m_Length;

		m_Iterator = 0;
		m_Length = 0;

		Output[0] = EOS;

		for (; m_Iterator < strlen(Input); m_Iterator++)
		{
			if (Input[m_Iterator] == '!' || Input[m_Iterator] == '/' || \
				IsCharAlpha(Input[m_Iterator]) || IsCharNumeric(Input[m_Iterator]))
			{
				m_Length = Format(Output, Size, "%s%c", Output, Input[m_Iterator]);
			}
		}

		return m_Length;
	}
#endif
