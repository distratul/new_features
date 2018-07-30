#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

public Plugin myinfo =
{
	name = "Bot_give_knife",
	author = "DisTraTuL",
	description = "weapon_skins plugin",
	version = "1.0",
	url = "https://csgotracker.ro"
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

Handle g_Knife = INVALID_HANDLE;
bool g_InRound = false;

public void OnPluginStart()
{
	HookEventEx("round_start", OnRoundStart);

	CreateTimer(1.0, Timer_CheckKnives, _, TIMER_REPEAT);

	g_Knife = FindClientCookie("KnifeType");
}

public void OnMapStart()
{
	g_InRound = false;
}

public void OnMapEnd()
{
	g_InRound = false;
}

public Action Timer_CheckKnives(Handle Timer, any Data)
{
	static int Id = INVALID_ENT_REFERENCE;
	static int Knife = INVALID_ENT_REFERENCE;

	static char Class[PLATFORM_MAX_PATH] = "";

	if (g_InRound)
	{
		for (Id = 1; Id <= MaxClients; Id++)
		{
			if (IsClientInGame(Id) && IsPlayerAlive(Id))
			{
				Knife = GetPlayerWeaponSlot(Id, CS_SLOT_KNIFE);

				if (Knife == INVALID_ENT_REFERENCE)
				{
					if (g_Knife == INVALID_HANDLE)
					{
						Knife = GivePlayerItem(Id, GetClientTeam(Id) == CS_TEAM_T ? "weapon_knife_t" : "weapon_knife");

						if (Knife != INVALID_ENT_REFERENCE)
						{
							EquipPlayerWeapon(Id, Knife);
						}
					}

					else
					{
						F_KnifeClassByOption(Id, Class, sizeof(Class));

						Knife = GivePlayerItem(Id, Class);

						if (Knife != INVALID_ENT_REFERENCE)
						{
							EquipPlayerWeapon(Id, Knife);
						}
					}
				}
			}
		}
	}
}

public Action CS_OnTerminateRound(float& Delay, CSRoundEndReason& Reason)
{
	g_InRound = false;
}

public void OnRoundStart(Handle Data, const char[] Name, bool NoBroadcast)
{
	g_InRound = true;
}

void F_KnifeClassByOption(int Id, char[] Class, int Size)
{
	static char Value[PLATFORM_MAX_PATH] = "";

	GetClientCookie(Id, g_Knife, Value, sizeof(Value));

	switch (view_as<Knife>(StringToInt(Value)))
	{
		case Knife_None, Knife_Default:
		{
			switch (GetClientTeam(Id))
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
