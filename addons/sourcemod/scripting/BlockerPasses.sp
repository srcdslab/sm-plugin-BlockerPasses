#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

/*
    UseMoreColors: change 0 to 1 to use the morecolors library
    UseAdminMenu: change 1 to 0 to NOT use the admin menu in-game
*/
#define	UseMoreColors	0
#define	UseAdminMenu	1

#if UseMoreColors
	#include <multicolors>
#endif

#if UseAdminMenu
	#include <sdkhooks>
	#include <adminmenu>
	#undef REQUIRE_PLUGIN
	#define ADMIN_LEVEL		ADMFLAG_ROOT
#endif

const  TEAM_ALL = 1;
const  TEAM_ONE = 2;
const  TEAM_TWO = 3;

bool g_bLate;
bool g_bIsLocked;

#include "blockerpasses/stock.sp"
#include "blockerpasses/natives.sp"

#if UseAdminMenu
	TopMenu g_hTopMenu;
	Menu g_hETitleMenu;
	Menu g_hPropsMenu;
	Menu g_hRoteMenu;
	Menu g_hColorMenu;
	Menu g_hQuotaMenu;
#endif

ConVar g_cvEnabled;
ConVar g_cvAnnounce;
ConVar g_cvMinPlayer;
ConVar g_cvDisplayMode;
ConVar g_cvBlockAccountingTeam;
ConVar g_cvAutoSave;

bool g_bEnabled;
bool g_bAnnounce;
bool g_bPrintInChat;
bool g_bAccTeams;
bool g_bAutosave;
int g_biMinPlayers;
char s_sMapName[64];

#if UseAdminMenu
	ConVar g_cvUseAdminMenu;
	bool g_bUseAdminMenu;
	char g_sPropList[64][256];
#endif

KeyValues g_kv;
ArrayList g_aDataProps;

public Plugin myinfo =
{
	name = "Blocker passes",
	author = ">>Satan<<",
	description = "Blocker passes on maps",
	version = "1.3.0",
};

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sError, int Err_max)
{
	Create_Natives();
	g_bLate = bLate;
	return APLRes_Success;
}

public void OnPluginStart()
{
	#if UseAdminMenu
		g_hETitleMenu = new Menu(MenuPropMenuHandler);
		g_hETitleMenu.SetTitle("| English Blocker Passes |");
		g_hETitleMenu.ExitBackButton = true;

		g_hETitleMenu.AddItem("PropsMenu", 	"Props Menu");
		g_hETitleMenu.AddItem("ColorMenu", 	"Colors Menu");
		g_hETitleMenu.AddItem("QuotaMenu", 	"Quota Menu");
		g_hETitleMenu.AddItem("SaveProps", 	"Save Props");
		g_hETitleMenu.AddItem("", 		"", ITEMDRAW_SPACER);
		g_hETitleMenu.AddItem("LockAll", 	"Load | All Props");
		g_hETitleMenu.AddItem("UnLockAll", 	"UnLoad | All Props");

		g_hRoteMenu = new Menu(PropRoteMenuHandle);
		g_hRoteMenu.SetTitle("| Rotate Menu |");
		g_hRoteMenu.ExitBackButton = true;

		g_hRoteMenu.AddItem("RotateX+45", "Rotate +45° on axis X");
		g_hRoteMenu.AddItem("RotateX-45", "Rotate -45° on axis X");
		g_hRoteMenu.AddItem("RotateY+45", "Rotate +45° on axis Y");
		g_hRoteMenu.AddItem("RotateY-45", "Rotate -45° on axis Y");
		g_hRoteMenu.AddItem("RotateZ+45", "Rotate +45° on axis Z");
		g_hRoteMenu.AddItem("RotateZ-45", "Rotate -45° on axis Z");

		g_hColorMenu = new Menu(MenuPropColorHandler);
		g_hColorMenu.SetTitle("| Colors Menu |");
		g_hColorMenu.ExitBackButton = true;

		g_hColorMenu.AddItem("color1", "Red");
		g_hColorMenu.AddItem("color2", "Green");
		g_hColorMenu.AddItem("color3", "Blue");
		g_hColorMenu.AddItem("color4", "Yellow");
		g_hColorMenu.AddItem("color5", "Blue");
		g_hColorMenu.AddItem("color6", "Pink\n ");
		g_hColorMenu.AddItem("color7", "Invisible (25%)");
		g_hColorMenu.AddItem("color8", "Invisible (100%)");

		g_hQuotaMenu = new Menu(MenuPropQuotaHandler);
		g_hQuotaMenu.SetTitle("| Quota Menu |");
		g_hQuotaMenu.ExitBackButton = true;

		g_hQuotaMenu.AddItem("++", "+1");
		g_hQuotaMenu.AddItem("--", "-1");
		g_hQuotaMenu.AddItem("5", "5");
		g_hQuotaMenu.AddItem("8", "8");
		g_hQuotaMenu.AddItem("10", "10");
		g_hQuotaMenu.AddItem("12", "12");
		g_hQuotaMenu.AddItem("14", "14");
		g_hQuotaMenu.AddItem("16", "16");
		g_hQuotaMenu.AddItem("18", "18");
		g_hQuotaMenu.AddItem("20", "20");
		g_hQuotaMenu.AddItem("24", "24");
		g_hQuotaMenu.AddItem("28", "28");
		g_hQuotaMenu.AddItem("32", "32");
		g_hQuotaMenu.AddItem("64", "64");
	#endif

	g_cvEnabled = CreateConVar("sm_bp_enable", 					"1", 	"1|0 Enable / Disable the plugin", _, true, 0.0, true, 1.0);
	g_bEnabled = GetConVarBool(g_cvEnabled);
	g_cvEnabled.AddChangeHook(OnConVarChanged);

	g_cvAnnounce = CreateConVar("sm_bp_anonce", 					"1", 	"1|0 Enable / Disable message about the status of the lock plug", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bAnnounce = GetConVarBool(g_cvAnnounce);
	g_cvAnnounce.AddChangeHook(OnConVarChanged);

	g_cvDisplayMode = CreateConVar("sm_bp_amode", 					"1", 	"Message Display Type (0 - HUD, 1 - Chat)", _, true, 0.0, true, 1.0);
	g_bPrintInChat = GetConVarBool(g_cvDisplayMode);
	g_cvDisplayMode.AddChangeHook(OnConVarChanged);


	g_cvMinPlayer = CreateConVar("sm_bp_minplayer", 			"10", 	"The minimum number of players for the machine. removal of all processes, blocking passage", FCVAR_NOTIFY, true, 0.0, true, 64.0);
	g_biMinPlayers = GetConVarInt(g_cvMinPlayer);
	g_cvMinPlayer.AddChangeHook(OnConVarChanged);

	g_cvBlockAccountingTeam = CreateConVar("sm_bp_onlyct", 		"0", 	"1|0 Enable / Disable counting only the players of the CT team for the decision on blocking", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bAccTeams = GetConVarBool(g_cvBlockAccountingTeam);
	g_cvBlockAccountingTeam.AddChangeHook(OnConVarChanged);

	g_cvAutoSave = CreateConVar("sm_bp_autosave", 			"0", 	"1|0 Enable / Disable automatic saving props at the end of each round,", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bAutosave = GetConVarBool(g_cvAutoSave);
	g_cvAutoSave.AddChangeHook(OnConVarChanged);

	#if UseAdminMenu
		g_cvUseAdminMenu = CreateConVar("sm_bp_enableadmmenu",	"1",	"1|0 Enable / Disable the plugin management menu in the game",  _, true, 0.0, true, 1.0);
		g_bUseAdminMenu = GetConVarBool(g_cvUseAdminMenu);
		g_cvUseAdminMenu.AddChangeHook(OnConVarChanged);
	#endif

	AutoExecConfig(true);
	LoadTranslations("blocker_passes.phrases");

	g_aDataProps = CreateArray();

	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);

	#if UseAdminMenu
		RegAdminCmd("sm_bpmenu", CommandAdminPasses, ADMFLAG_ROOT);
	#endif
	RegAdminCmd("sm_getaimpos", CommandGetPoss, ADMFLAG_ROOT);

	if (g_bLate) {
		PreloadConfigs();
		g_bLate = false;
	}

	#if UseAdminMenu
		TopMenu topmenu;
		if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
			OnAdminMenuReady(topmenu);
		}
	#endif
}

public void OnMapStart()
{
	PreloadConfigs();

	#if UseAdminMenu
		LoadPropsMenu();
	#endif
}

public void OnMapEnd()
{
	delete g_kv;
}

public void OnPostThink(int client)
{
	char buffer[64], sBuffer[128];

	int entity = GetClientAimTarget2(client, false);

	if (entity > MaxClients) {
		GetEntPropString(entity, Prop_Data, "m_iName", buffer, sizeof(buffer));
		if (StrContains(buffer, "BpModelId", true) != -1)
		{
			char outBuffer[2][8];
			ExplodeString(buffer, "_", outBuffer, 2, 16, false);
			Format(sBuffer, sizeof(sBuffer), "The quota for this object: %s", outBuffer[1]);
			PrintHudText(client, sBuffer);
		}
	}
}

void PreloadConfigs()
{
	GetCurrentMap(s_sMapName, sizeof(s_sMapName));

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/blocker_passes/");

	if (!DirExists(path)) {
		CreateDirectory(path, 511);
	}

	g_kv = CreateKeyValues("blocker_passes");
	BuildPath(Path_SM, path, sizeof(path), "data/blocker_passes/%s.txt", s_sMapName);
	FileToKeyValues(g_kv, path);
}

#if UseAdminMenu
	public Action CommandAdminPasses(int client, int args)
	{
		if (g_bUseAdminMenu) {
			DisplayTopMenu(g_hTopMenu, client, TopMenuPosition_LastCategory);
		}

		return Plugin_Handled;
	}
#endif

public Action CommandGetPoss(int client, int args)
{
	float g_fOrigin[3];
	GetClientEyePosition(client, g_fOrigin);

	if (TR_DidHit(INVALID_HANDLE)) {
		TR_GetEndPosition(g_fOrigin, INVALID_HANDLE);
		PrintToChat(client, "\x04[SM]\x04 Position: \x01%-.1f\x04; \x01%-.1f\x04; \x01%-.1f\x04.", g_fOrigin[0], g_fOrigin[1], g_fOrigin[2]);
	}

	return Plugin_Handled;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvEnabled) {
		g_bEnabled = convar.BoolValue;
	} else if (convar == g_cvAnnounce) {
		g_bAnnounce = convar.BoolValue;
	} else if (convar == g_cvDisplayMode) {
		g_bPrintInChat = convar.BoolValue;
	} else if (convar == g_cvMinPlayer) {
		g_biMinPlayers = convar.IntValue;
	} else if (convar == g_cvBlockAccountingTeam) {
		g_bAccTeams = convar.BoolValue;
	} else if (convar == g_cvAutoSave) {
		g_bAutosave = convar.BoolValue;
	}
#if UseAdminMenu
	else if (convar == g_cvUseAdminMenu) {
		g_bUseAdminMenu = convar.BoolValue;
	}
#endif
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) {
		return;
	}

	ClearArray(g_aDataProps);

	int clients = GetRealClientCount(g_bAccTeams ? TEAM_TWO : TEAM_ALL);

	if (clients < g_biMinPlayers) {

		g_bIsLocked = true;
		SpawnBlocks(GetRealClientCount(g_bAccTeams ? TEAM_TWO : TEAM_ALL));

		if (!g_bAnnounce) {
			return;
		}

		if (g_bAccTeams) {
			switch (g_bPrintInChat) {
				case false:{
					PrintCenterTextAll("%t", "Blocked due to lack of CT");
				}
				case true:{
					#if UseMoreColors
						CPrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "Blocked due to lack of CT");
					#else
						PrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "Blocked due to lack of CT");
					#endif
				}
			}
		} else {
			switch (g_bPrintInChat) {
				case false:{
					PrintCenterTextAll("%t", "Blocked due to lack of CT");

				}
				case true:{
					#if UseMoreColors
						CPrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "Block Because of the user");
					#else
						PrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "Block Because of the user");
					#endif
				}
			}
		}
	} else {

		g_bIsLocked = false;

		if (!g_bAnnounce) {
			return;
		}

		switch (g_bPrintInChat) {
			case false:{
				PrintCenterTextAll("%t", "UnBlock B");
			}
			case true:{
				#if UseMoreColors
					CPrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "UnBlock B");
				#else
					PrintToChatAll("\x05[SM Blocker Passes]\x01 %t", "UnBlock B");
				#endif
			}
		}
	}

	return;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bAutosave) {
		SaveAllProps(0);
	}

	return;
}

public void OnEntityDestroyed(int entity)
{
	int index = -1;

	if ((index = FindValueInArray(g_aDataProps, entity)) != -1) {
		RemoveFromArray(g_aDataProps, index);
	}
}

#if UseAdminMenu
	public void OnAdminMenuReady(Handle aTopMenu)
	{
		if (!g_bUseAdminMenu)
			return;

		TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

		// Block us from being called twice
		if (topmenu == g_hTopMenu) {
			return;
		}

		// Save the Handle
		g_hTopMenu = topmenu;

		TopMenuObject blocker_passes = g_hTopMenu.FindCategory("blocker_passes");

		if (blocker_passes == INVALID_TOPMENUOBJECT) {
			blocker_passes = AddToTopMenu(g_hTopMenu, "blocker_passes", TopMenuObject_Category, Handle_Category, INVALID_TOPMENUOBJECT, "sm_blocker_passes", ADMIN_LEVEL);
		}

		g_hTopMenu.AddItem("sm_bp_save", blocker_passes_Save, blocker_passes, "sm_bp_save", ADMIN_LEVEL);
		g_hTopMenu.AddItem("sm_bp_props", blocker_passes_Props, blocker_passes, "sm_bp_props", ADMIN_LEVEL);
		g_hTopMenu.AddItem("sm_bp_plsettings", blocker_passes_Settings, blocker_passes, "sm_bp_plsettings", ADMIN_LEVEL);
	}

	public void Handle_Category(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
	{
		switch (action) {
			case TopMenuAction_DisplayTitle:{
				Format(buffer, maxlength, "[EN] Blocker Passes");
			}
			case TopMenuAction_DisplayOption:{
				Format(buffer, maxlength, "[EN] Blocker Passes");
			}
		}
	}

	public void blocker_passes_Settings(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
	{
		switch (action) {
			case TopMenuAction_DisplayOption :{
				Format(buffer, maxlength, "Settings");
			}
			case TopMenuAction_SelectOption :{
				ShowSettingsMenu(param);
			}
		}
	}

	public void blocker_passes_Props(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
	{
		switch (action) {
			case TopMenuAction_DisplayOption :{
				Format(buffer, maxlength, "Main Menu");
			}
			case TopMenuAction_SelectOption :{
				g_hETitleMenu.Display(param, MENU_TIME_FOREVER);
			}
		}
	}

	public void blocker_passes_Save(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
	{
		switch (action) {
			case TopMenuAction_DisplayOption :{
				Format(buffer, maxlength, "Save Props");
			}
			case TopMenuAction_SelectOption :{
				SaveAllProps(param);
			}
		}
	}

	void ShowSettingsMenu(int client)
	{
		char buffer[64];

		Menu menu = new Menu(MenuSettingsHandler);
		menu.SetTitle("Settings");
		menu.ExitBackButton = true;

		Format(buffer, sizeof(buffer), "Plugin Enabled: %s", g_bEnabled ? "ON" : "OFF");
		menu.AddItem("Enable", buffer);

		Format(buffer, sizeof(buffer), "Accounting For All Players: %s", g_bAccTeams ? "OFF" : "ON");
		menu.AddItem("Acc_Team", buffer);

		Format(buffer, sizeof(buffer), "Plugin Announce: %s", g_bAnnounce ? "ON" : "OFF");
		menu.AddItem("Anonce", buffer);

		menu.Display(client, MENU_TIME_FOREVER);
	}

	public int MenuSettingsHandler(Menu menu, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_End:{
				delete menu;
			}
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					if (g_hTopMenu != INVALID_HANDLE)
						DisplayTopMenu(g_hTopMenu, param1, TopMenuPosition_LastCategory);
				}
			}
			case MenuAction_Select :{

				char sType[32];
				menu.GetItem(param2, sType, sizeof(sType));

				if (strcmp(sType, "Enable", false) == 0) {
					g_bEnabled = !g_bEnabled;
				} else if (strcmp(sType, "Acc_Team", false) == 0) {
					g_bAccTeams = !g_bAccTeams;
				} else if (strcmp(sType, "Anonce", false) == 0) {
					g_bAnnounce = !g_bAnnounce;
				}

				ShowSettingsMenu(param1);
			}
		}

		return 0;
	}

	public int MenuPropMenuHandler(Menu menu, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					if (g_hTopMenu != INVALID_HANDLE)
						DisplayTopMenu(g_hTopMenu, param1, TopMenuPosition_LastCategory);
				}
			}
			case MenuAction_Select :{

				char sType[32];
				menu.GetItem(param2, sType, sizeof(sType));

				if (strcmp(sType, "PropsMenu", false) == 0) {
					g_hPropsMenu.Display(param1, MENU_TIME_FOREVER);
				} else if (strcmp(sType, "ColorMenu", false) == 0) {
					g_hColorMenu.Display(param1, MENU_TIME_FOREVER);
				} else if (strcmp(sType, "QuotaMenu", false) == 0) {
					SDKHook(param1, SDKHook_PostThinkPost, OnPostThink);
					g_hQuotaMenu.Display(param1, MENU_TIME_FOREVER);
				} else if (strcmp(sType, "SaveProps", false) == 0) {
					SaveAllProps(param1);
				} else if (strcmp(sType, "LockAll", false) == 0) {
					SpawnBlocks(0);
					g_bIsLocked = true;
					menu.Display(param1, MENU_TIME_FOREVER);
				} else if (strcmp(sType, "UnLockAll", false) == 0) {
					int i, size;

					size = GetArraySize(g_aDataProps);

					while (i < size) {
						DeleteProp(GetArrayCell(g_aDataProps, i));
						i++;
					}
					g_bIsLocked = false;

					menu.Display(param1, MENU_TIME_FOREVER);
				}

			}
		}

		return 0;
	}

	public int PropMenuHandler(Menu menu, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					g_hETitleMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}
			case MenuAction_Select :{

				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				int ent = -1, index = -1, index2 = StringToInt(info);

				float g_fOrigin[3], g_fAngles[3];

				GetClientEyePosition(param1, g_fOrigin);
				GetClientEyeAngles(param1, g_fAngles);
				TR_TraceRayFilter(g_fOrigin, g_fAngles, MASK_SOLID, RayType_Infinite, Trace_FilterPlayers, param1);

				if (TR_DidHit(INVALID_HANDLE)) {

					TR_GetEndPosition(g_fOrigin, INVALID_HANDLE);
					TR_GetPlaneNormal(INVALID_HANDLE, g_fAngles);
					GetVectorAngles(g_fAngles, g_fAngles);
					g_fAngles[0] += 90.0;

					if (!strcmp(info, "rote")) {
						g_hRoteMenu.Display(param1, MENU_TIME_FOREVER);
						return 0;
					} else if (!strcmp(info, "remove")) {
						if ((ent = GetClientAimTarget(param1, false)) > MaxClients) {
							if ((index = FindValueInArray(g_aDataProps, ent)) != -1) {
								RemoveFromArray(g_aDataProps, index);
								DeleteProp(ent);
								PrintHintText(param1, "Prop removed!");
							}
						} else {
							PrintToChat(param1, "\x05[SM Blocker Passes]\x01 Invalid object!");
						}
					} else {
						CreateEntity(g_fOrigin, g_fAngles, g_sPropList[index2], g_biMinPlayers);
						PrintHintText(param1, "Props Successfully Installed!");
					}
					menu.DisplayAt(param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
				}
			}
		}

		return 0;
	}

	public int PropRoteMenuHandle(Menu menu, MenuAction action, int client, int param2)
	{
		switch (action) {
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					g_hPropsMenu.Display(client, MENU_TIME_FOREVER);
				}
			}
			case MenuAction_Select :{

				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				float RotateVec[3];
				int entity = GetClientAimTarget2(client, false);

				if (entity > MaxClients) {

					GetEntPropVector(entity, Prop_Send, "m_angRotation", RotateVec);

					if (strcmp(info, "RotateX+45") == 0) {
						RotateVec[0] = RotateVec[0] + 45.0;
					} else if (strcmp(info, "RotateX-45") == 0) {
						RotateVec[0] = RotateVec[0] - 45.0;
					} else if (strcmp(info, "RotateY+45") == 0) {
						RotateVec[1] = RotateVec[1] + 45.0;
					} else if (strcmp(info, "RotateY-45") == 0) {
						RotateVec[1] = RotateVec[1] - 45.0;
					} else if (strcmp(info, "RotateZ+45") == 0) {
						RotateVec[2] = RotateVec[2] + 45.0;
					} else if (strcmp(info, "RotateZ-45") == 0) {
						RotateVec[2] = RotateVec[2] - 45.0;
					}

					TeleportEntity(entity, NULL_VECTOR, RotateVec, NULL_VECTOR);
				}
				menu.Display(client, MENU_TIME_FOREVER);
			}
		}

		return 0;
	}

	public int MenuPropColorHandler(Menu menu, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					if (g_hTopMenu != INVALID_HANDLE) {
						g_hETitleMenu.Display(param1, MENU_TIME_FOREVER);
					}
				}
			}
			case MenuAction_Select :{

				char sType[10];
				menu.GetItem(param2, sType, sizeof(sType));

				int ent = -1;

				if ((ent = GetClientAimTarget(param1, false)) > MaxClients) {
					if (!strcmp(sType, "color1")) {
						SetEntityRenderColor(ent, 255, 0, 0, 255);
					} else if (!strcmp(sType, "color2")) {
						SetEntityRenderColor(ent, 0, 255, 0, 255);
					} else if (!strcmp(sType, "color3")) {
						SetEntityRenderColor(ent, 0, 0, 255, 255);
					} else if (!strcmp(sType, "color4")) {
						SetEntityRenderColor(ent, 255, 255, 0, 255);
					} else if (!strcmp(sType, "color5")) {
							SetEntityRenderColor(ent, 0, 255, 255, 255);
					} else if (!strcmp(sType, "color6")) {
						SetEntityRenderColor(ent, 255, 0, 255, 255);
					} else if (!strcmp(sType, "color7")) {
						SetEntityRenderColor(ent, 255, 255, 255, 50);
					} else if (!strcmp(sType, "color8")) {
						SetEntityRenderColor(ent, 255, 255, 255, 0);
					}
				}

				menu.DisplayAt(param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
			}
		}

		return 0;
	}

	public int MenuPropQuotaHandler(Menu menu, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Cancel :{
				if (param2 == MenuCancel_ExitBack) {
					SDKUnhook(param1, SDKHook_PostThinkPost, OnPostThink);
					g_hETitleMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}

			case MenuAction_Select :{

				char sType[12];
				menu.GetItem(param2, sType, sizeof(sType));

				int ent = -1, Quota;
				if ((ent = GetClientAimTarget(param1, false)) > MaxClients) {

					char buffer[32];
					GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));

					if (StrContains(buffer, "BpModelId", true) != -1) {
						if (strcmp(sType, "++", false) != 0 && strcmp(sType, "--", false) != 0) {
							Quota = StringToInt(sType);
							Format(buffer, sizeof(buffer), "BpModelId%d_%d", ent, Quota);
							DispatchKeyValue(ent, "targetname", buffer);
						}
						else {

							char outBuffer[2][8];
							ExplodeString(buffer, "_", outBuffer, 2, 16);

							if (strcmp(sType, "++", false) == 0) {
								Quota = StringToInt(outBuffer[1]) + 1;
							}
							else if (strcmp(sType, "--", false) == 0) {
								Quota = StringToInt(outBuffer[1]) - 1;
							}

							Format(buffer, sizeof(buffer), "BpModelId%d_%d", ent, Quota);
							DispatchKeyValue(ent, "targetname", buffer);
						}
					}
				}

				menu.DisplayAt(param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
			}
		}

		return 0;
	}
#endif

void SpawnBlocks(const int clients)
{
	float pos[3], ang[3];
	char buffer[16], Models[256], s_text[256];
	int entity, UnLockNum, color[4];

	if (g_kv.GotoFirstSubKey()) {
		do{
			g_kv.GetVector("Position", pos);
			g_kv.GetVector("Angles", ang);
			g_kv.GetString("Model", Models, sizeof(Models));
			g_kv.GetString("Text", s_text, sizeof(s_text));
			g_kv.GetString("Colors", buffer, sizeof(buffer));

			UnLockNum = g_kv.GetNum("UnLockNum", g_biMinPlayers);

			StringToColor(buffer, color);

			if (UnLockNum > clients) {
				if (strlen(s_text) > 2) {
					ReplaceString(s_text, sizeof(s_text), "{default}", "\x01", false);
					ReplaceString(s_text, sizeof(s_text), "{teamcolor}", "\x02", false);
					ReplaceString(s_text, sizeof(s_text), "{lightgreen}", "\x03", false);
					ReplaceString(s_text, sizeof(s_text), "{green}", "\x04", false);
					ReplaceString(s_text, sizeof(s_text), "{darkgreen}", "\x05", false);

					#if UseMoreColors
						CPrintToChatAll(s_text);
					#else
						PrintToChatAll(s_text);
					#endif
				}

				if ((entity = CreateEntity(pos, ang, Models, UnLockNum)) != -1) {
					SetEntityColor(entity, color);
				}
			}
		} while (KvGotoNextKey(g_kv));
	}

	g_kv.Rewind();
}

int CreateEntity(const float pos[3], const float ang[3], const char[] g_szModel, const int iMinPlayer)
{
	int entity = CreateEntityByName("prop_dynamic_override");

	if (entity == -1) {
		return -1;
	}

	if (!IsModelPrecached(g_szModel)) {
		PrecacheModel(g_szModel);
	}

	char buffer[32];
	Format(buffer, sizeof(buffer), "BpModelId%d_%d", entity, iMinPlayer);

	SetEntityModel(entity, g_szModel);
	DispatchKeyValue(entity, "targetname", buffer);
	DispatchKeyValue(entity, "Solid", "6");
	DispatchSpawn(entity);

	TeleportEntity(entity, pos, ang, NULL_VECTOR);

	PushArrayCell(g_aDataProps, entity);

	return entity;
}

public bool Trace_FilterPlayers(int entity, int contentsMask, any data)
{
	if (entity != data && entity > MaxClients) {
		return true;
	}
	return false;
}

public bool TRFilter_AimTarget(int entity, int mask, int client)
{
    return (entity != client);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, int client)
{
	return ((entity > MaxClients) || !entity);
}

int GetRealClientCount(const int team)
{
	int clients = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			if (team > TEAM_ALL) {
				if (GetClientTeam(i) == team) {
					clients++;
				} else {
					continue;
				}
			} else {
				clients++;
			}
		}
	}

	return clients;
}

void Kv_Clear(KeyValues kvhandle)
{
	kvhandle.Rewind();

	if (kvhandle.GotoFirstSubKey()) {
		do{
			kvhandle.DeleteThis();
			kvhandle.Rewind();
		}
		while (kvhandle.GotoFirstSubKey());
	}
	kvhandle.Rewind();
}

void SaveAllProps(int client)
{
	Kv_Clear(g_kv);

	int ent;
	int color[4];
	int index = 1;
	float pos[3], ang[3];
	char buffer_modelsname[PLATFORM_MAX_PATH], buffer_2[64], colors[16];

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/blocker_passes/%s.txt", s_sMapName);

	for (int i = 0; i < g_aDataProps.Length; i++) {

		// ent = GetArrayCell(g_aDataProps, i);
		ent = g_aDataProps.Get(i);

		if (ent > MaxClients && IsValidEdict(ent)) {

			GetEntPropString(ent, Prop_Data, "m_ModelName", buffer_modelsname, sizeof(buffer_modelsname));
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
			GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
			MyGetEntityRenderColor(ent, color);
			ColorToString(color, colors, sizeof(colors));

			IntToString(index, buffer_2, sizeof(buffer_2));
			g_kv.JumpToKey(buffer_2, true);

			g_kv.SetVector("Position", pos);
			g_kv.SetVector("Angles", ang);
			g_kv.SetString("Model", buffer_modelsname);
			g_kv.SetString("colors", colors);
			g_kv.SetString("Text", "");

			#if UseAdminMenu
				char buffer[32], outBuffer[2][8];
				GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
				ExplodeString(buffer, "_", outBuffer, 2, 16, false);
				g_kv.SetNum("UnLockNum", StringToInt(outBuffer[1]));
			#else
				g_kv.SetNum("UnLockNum", g_biMinPlayers);
			#endif

			g_kv.Rewind();

			index++;
		}
	}

	KeyValuesToFile(g_kv, path);

	if (client == 0) {
		return;
	}
	PrintHintText(client, "Positions\nSuccessfully saved.\nTotal %d Props!", index - 1);

	#if UseAdminMenu
		DisplayTopMenu(g_hTopMenu, client, TopMenuPosition_LastCategory);
	#endif
}
#if UseAdminMenu
	void DeleteProp(int entity)
	{
		int diss = CreateEntityByName("env_entity_dissolver");
		if (diss == -1) {
			return;
		}

		char dname[16];
		Format(dname, sizeof(dname), "dis_%d", entity);
		DispatchKeyValue(entity, "targetname", dname);
		DispatchKeyValue(diss, "dissolvetype", "3");
		DispatchKeyValue(diss, "target", dname);
		AcceptEntityInput(diss, "Dissolve");
		AcceptEntityInput(diss, "kill");
	}

	void LoadPropsMenu()
	{
		g_hPropsMenu = new Menu(PropMenuHandler);
		g_hPropsMenu.SetTitle("| Props Menu |");
		g_hPropsMenu.ExitButton = true;
		g_hPropsMenu.ExitBackButton = true;

		char file[255];
		KeyValues kv = CreateKeyValues("Props");
		BuildPath(Path_SM, file, sizeof(file), "data/blocker_passes/props_menu.txt");
		FileToKeyValues(kv, file);
		int menu_items = 0;
		int reqmenuitems = 4;

		if (kv.GotoFirstSubKey()) {
			int index = 0;
			char buffer[255];
			char bufferindex[5];
			do{
				kv.GetString("model", g_sPropList[index], sizeof(g_sPropList[]));

				PrecacheModel(g_sPropList[index]);

				kv.GetSectionName(buffer, sizeof(buffer));
				IntToString(index, bufferindex, sizeof(bufferindex));
				g_hPropsMenu.AddItem(bufferindex, buffer);
				index++;
				menu_items++;
				if (menu_items == reqmenuitems)
				{
					menu_items = 0;
					g_hPropsMenu.AddItem("", 	"", ITEMDRAW_SPACER);
					g_hPropsMenu.AddItem("rote", 	"[Rotate Prop]");
					g_hPropsMenu.AddItem("remove", 	"[Remove Prop]");
				}
			}
			while (kv.GotoNextKey());
		}
		delete kv;
	}
#endif