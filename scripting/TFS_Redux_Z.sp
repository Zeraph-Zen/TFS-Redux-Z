/*
	Team Fortress Sandbox Redux "Zen" (TFS Redux Z)
	A forked and modified version of bolt's TFS Redux plugin.
	This version was already modified prior to me getting it by Batfoxkid#7401 on Discord, 
	adding buildzones and fixing the plugin as it appeared to be non functional when grabbed from the original github repo. 

	The name change is a result of me wanting to differentiate between this and the original a bit more, but having no creativity in what to name it.


	Below this is the original comment, made by bolt.

	Team Fortress Sandbox Redux (TFS Redux)
	Coded by bolt

	CREDITS:
	- KTM: He coded the original TFS Plugin that was developed for the {SuN} and {SuN} Revived servers.
	- chundo: His 'Help Menu' plugin helped me learn how to use config files to create menus.
	- Xeon: Owner of Neogenesis Network. Although he didn't help me in this project, he's helped me in the past with my development adventures. This guy is awesome.
	- The {SuN} Community and Staff: For being part of the best gaming community I've ever been in. ALL of you are awesome!
*/

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <adminmenu>

#define PLUGIN_VERSION "Zen 0.4"

//Defines for sounds
#define SOUND_SPAWN "buttons/lightswitch2.wav"
#define SOUND_DELETE "physics/plaster/drywall_impact_hard1.wav"
#define SOUND_MANIPSAVE "physics/plaster/ceiling_tile_impact_bullet2.wav"
#define SOUND_MANIPDISCARD "physics/plaster/ceiling_tile_impact_bullet3.wav"
#define SOUND_PAINT "physics/flesh/flesh_squishy_impact_hard2.wav"
#define SOUND_EDIT "items/flashlight1.wav"

enum ChatCommand {
	String:command[32],
	String:description[255]
}

enum PropMenuType {
	PropMenuType_List,
	PropMenuType_Text
}

/*enum struct PropMenu {
	char name[32];
	char title[128];
	PropMenuType type;
	Handle items;
	int itemct
}*/

enum PropMenu {
	String:name[32],
	String:title[128],
	PropMenuType:type,
	Handle:items,
	itemct
}

/* The original plugin info, it felt wrong to delete it despite the dead link so here it is kept as a mere comment
public Plugin:myinfo = 
{
	name = "TFS Redux",
	author = "bolt",
	description = "Rewritten and improved Team Fortress Sandbox",
	version = PLUGIN_VERSION,
	url = "https://bolts.dev/"
}
*/

public Plugin:myinfo = 
{
	name = "TFS Redux",
	author = "Zeraph",
	description = "A modified version of bolt's TFS Redux plugin",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zeraph-Zen/TFS-Redux-Z"
}

/*Exists twice? Keeping as a comment for testing
//Defines for sounds
#define SOUND_SPAWN "buttons/lightswitch2.wav"
*/

// Prop menus
new Handle:g_PropMenus = INVALID_HANDLE;

//prop states
new g_iOwner[4096];
new bool:g_bKillProp[4096];

new g_bInBuildZone[4096];
/*
	g_bInBuildZone appears to be an array with a length of 4096 containing 1s and 0s which is what it uses as a true or false to check if you're in a build area
	But if that's the case, why isn't it using booleans? 
*/
new g_iPropCount[MAXPLAYERS+1];
new g_iLastProp[MAXPLAYERS+1];
new g_iSelectedProp[MAXPLAYERS+1];

//manipulate
new Float:g_vecLockedAng[MAXPLAYERS+1][3];
new Float:g_vecSelectedPropPrevPos[MAXPLAYERS+1][3];
new Float:g_vecSelectedPropPrevAng[MAXPLAYERS+1][3];

// Config parsing
new g_configLevel = -1;

// Textures
new g_iBeamIndex;
new g_BeamSprite;
new g_HaloSprite;

// Cvars
new Handle:prop_limit;

public OnPluginStart() {
	//Creates the commands and sets some settings
	RegConsoleCmd("sm_tfs", Command_TFSMenu, "Open the TFS Menu", FCVAR_PLUGIN);
	RegAdminCmd("sm_tfs_admin", Command_TFSAdmin, ADMFLAG_GENERIC);
	//RegAdminCmd("sm_tfs_clearuser", Command_TFSClear, ADMFLAG_GENERIC);

	prop_limit = CreateConVar("sm_tfs_proplimit", "50", "Prop Limit for each user.", FCVAR_PLUGIN|FCVAR_NOTIFY);

	HookEvent("player_death", OnPlayerSpawn, EventHookMode_Post);

	new String:hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/TFS/proplist.cfg");
	ParseConfigFile(hc);

	AutoExecConfig(false);
}

public OnMapStart() {
	//Repeated from above? Uncertain if it's needed, due to a lack of knowledge in this language
	//Keeping untouched for now
	new String:hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/TFS/proplist.cfg");
	ParseConfigFile(hc);

	g_BeamSprite = PrecacheModel("materials/sprites/halo01.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	g_iBeamIndex = PrecacheModel("materials/sprites/purplelaser1.vmt");

	//Self explanitory, adds the sounds defined earlier to the cache
	PrecacheSound(SOUND_SPAWN);
	PrecacheSound(SOUND_DELETE);
	PrecacheSound(SOUND_MANIPSAVE);
	PrecacheSound(SOUND_MANIPDISCARD);
	PrecacheSound(SOUND_PAINT);
	PrecacheSound(SOUND_EDIT);
	
	int entity = -1;
	while((entity=FindEntityByClassname(entity, "func_flagdetectionzone")) != -1) //Yeah, I genuinely don't know what this is, all I know is that this is a confusing language
	{
		SDKHook(entity, SDKHook_StartTouch, OnBuildZoneEnter);
		SDKHook(entity, SDKHook_Touch, OnBuildZoneTouch);
		SDKHook(entity, SDKHook_EndTouch, OnBuildZoneExit);
	}
}

public void OnPlayerSpawn(Event event, const char[] naame, bool dontBroadcast)
{
	g_bInBuildZone[GetClientOfUserId(event.GetInt("userid"))] = 0;
}

public void OnEntityCreated(int entity, const char[] classname) {
	g_bInBuildZone[entity] = 0;

	if(StrEqual(classname, "func_flagdetectionzone")) { //This is what decides that any func_flagdetectionzone triggers are to be the "build areas" of the map
		SDKHook(entity, SDKHook_StartTouch, OnBuildZoneEnter); //Hooks the entities
		SDKHook(entity, SDKHook_Touch, OnBuildZoneTouch);
		SDKHook(entity, SDKHook_EndTouch, OnBuildZoneExit);
	}
}

public void OnBuildZoneEnter(int entity, int client) {
	if(client > 0 && client < sizeof(g_bInBuildZone)) {
		g_bInBuildZone[client]++;
	}
}

public void OnBuildZoneTouch(int entity, int client) {
	if(client > 0 && client < sizeof(g_bInBuildZone) && !g_bInBuildZone[client]) {
		g_bInBuildZone[client] = 1;
	}
}

public void OnBuildZoneExit(int entity, int client) {
	if(client > 0 && client < sizeof(g_bInBuildZone)) {
		if(--g_bInBuildZone[client] < 0) {
			g_bInBuildZone[client] = 0;
		}
	}
}

public void OnPluginEnd() {
	for(new i=1; i<sizeof(g_iOwner); i++) {
		if(g_iOwner[i]) {
			DeleteProp(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bInBuildZone[client] = 0;
	/* Uncertain if props get deleted on client disconnect, so I'll leave this commented out for now
	for(new i=1; i<sizeof(g_iOwner); i++) {
		if(g_iOwner[i] == client) {
			DeleteProp(i);
		}
	}
	if(IsValidEntity(client)) {
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
	}*/
}

bool:ParseConfigFile(const String:file[]) {
	if (g_PropMenus != INVALID_HANDLE) {
		ClearArray(g_PropMenus);
		CloseHandle(g_PropMenus);
		g_PropMenus = INVALID_HANDLE;
	}

	new Handle:parser = SMC_CreateParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(parser, Config_End);

	new line = 0;
	new col = 0;
	new String:error[128];
	new SMCError:result = SMC_ParseFile(parser, file, line, col);
	CloseHandle(parser);

	if (result != SMCError_Okay) {
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}

	return (result == SMCError_Okay);
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) {
	g_configLevel++;
	if (g_configLevel == 1) {
	new hmenu[PropMenu];
	strcopy(hmenu[name], sizeof(hmenu[name]), section);
	hmenu[items] = CreateDataPack();
	hmenu[itemct] = 0;
	if (g_PropMenus == INVALID_HANDLE) {
		g_PropMenus = CreateArray(sizeof(hmenu));
	}
	PushArrayArray(g_PropMenus, hmenu[0]);
	}
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) {
	new msize = GetArraySize(g_PropMenus);
	new hmenu[PropMenu];
	GetArrayArray(g_PropMenus, msize-1, hmenu[0]);
	switch (g_configLevel) {
		case 1: {
			if(strcmp(key, "title", false) == 0)
				strcopy(hmenu[title], sizeof(hmenu[title]), value);
			if(strcmp(key, "type", false) == 0) {
				if(strcmp(value, "text", false) == 0)
					hmenu[type] = PropMenuType_Text;
				else
					hmenu[type] = PropMenuType_List;
			}
		}
		case 2: {
			WritePackString(hmenu[items], key);
			WritePackString(hmenu[items], value);
			hmenu[itemct]++;
		}
	}
	SetArrayArray(g_PropMenus, msize-1, hmenu[0]);
	return SMCParse_Continue;
}
public SMCResult:Config_EndSection(Handle:parser) {
	g_configLevel--;
	if (g_configLevel == 1) {
		new hmenu[PropMenu];
		new msize = GetArraySize(g_PropMenus);
		GetArrayArray(g_PropMenus, msize-1, hmenu[0]);
		ResetPack(hmenu[items]);
	}
	return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) {
	if (failed) {
		SetFailState("Plugin configuration error");
	}
}

public Action:Command_TFSMenu(client, args) {
	TFS_ShowMainMenu(client); {
		return Plugin_Handled;
	}
}

TFS_ShowMainMenu(client)
{	//Items are added to the list, ordered as function to which the identifying string is passed, a string identifying the item lastly followed by the actual text shown in menu
	new Handle:menu = CreateMenu(TFS_MainMenuHandler);
	SetMenuExitBackButton(menu, false);
	SetMenuTitle(menu, "TFS Redux Zen V0.4\n"); //Sets the title of the menu to the current version of the plugin, strangely not using the variable defined early on so it'll probably be changed to do that later
	AddMenuItem(menu, "props", "Prop Spawner");
	AddMenuItem(menu, "manip", "Manipulate Menu");
	AddMenuItem(menu, "edit", "Edit Menu");
	AddMenuItem(menu, "whoowns", "Check Prop Ownership");
	AddMenuItem(menu, "delete", "Delete Prop");
	AddMenuItem(menu, "clearall", "Clear All Props");
	if (CheckCommandAccess(client, "sm_tfs_admin", ADMFLAG_GENERIC)) //Checks if you have admin permissions, if so it adds a button for the admin menu
	{
		AddMenuItem(menu, "admin", "Admin Menu");
	}
	DisplayMenu(menu, client, 30);
}

public TFS_MainMenuHandler(Handle:menu, MenuAction:action, client, param2) { 
//"client" used to be "param1", replacing it has aided greatly in readability.
//param2 is an integer used in other functions to determine a "position" value, but a position of what exactly?.
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	} 
	else if (action == MenuAction_Select) 
	{
		new String:item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		if (StrEqual(item, "props"))
		{
			TFS_ShowPropMenu(client);
		}
		else if (StrEqual(item, "manip"))
		{
			TFS_ManipMenu(client);
		}
		else if (StrEqual(item, "edit"))
		{
			ShowMenu_Edit(client);
		}
		else if (StrEqual(item, "whoowns"))
		{
			WhoOwns(client);
		}
		else if (StrEqual(item, "delete"))
		{
			DeleteAimProp(client);
		}
		else if (StrEqual(item, "clearall"))
		{
			ShowMenu_Clear(client);
		}
		else if (StrEqual(item, "admin"))
		{
			TFS_ShowAdminMenu(client);
		}
	}
}

TFS_ShowPropMenu(client) {
	new Handle:menu = CreateMenu(TFS_PropMenuHandler);
	SetMenuTitle(menu, "TFS Redux Zen - Prop Spawn Menu (Your Count: %i)", g_iPropCount[client]);
	new msize = GetArraySize(g_PropMenus);
	new hmenu[PropMenu];
	new String:menuid[10];
	for (new i = 0; i < msize; ++i) {
		Format(menuid, sizeof(menuid), "PropMenu_%d", i);
		GetArrayArray(g_PropMenus, i, hmenu[0]);
		AddMenuItem(menu, menuid, hmenu[name]);
	}
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 30);
}

public TFS_PropMenuHandler(Handle:menu, MenuAction:action, client, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu); }
	else if(action == MenuAction_Cancel) {
		TFS_ShowMainMenu(client); }
	else if (action == MenuAction_Select) {
		new String:buf[64];
		new msize = GetArraySize(g_PropMenus);
		// Menu from config file
		if (param2 <= msize) {
			new hmenu[PropMenu];
			GetArrayArray(g_PropMenus, param2, hmenu[0]);
			new String:mtitle[512];
			Format(mtitle, sizeof(mtitle), "%s\n ", hmenu[title]);
			if (hmenu[type] == PropMenuType_Text) {
				new Handle:cpanel = CreatePanel();
				SetPanelTitle(cpanel, mtitle);
				new String:text[128];
				new String:junk[128];
				for (new i = 0; i < hmenu[itemct]; ++i) {
					ReadPackString(hmenu[items], junk, sizeof(junk));
					ReadPackString(hmenu[items], text, sizeof(text));
					DrawPanelText(cpanel, text);
				}
				for (new j = 0; j < 7; ++j)
				DrawPanelItem(cpanel, " ", ITEMDRAW_NOTEXT);
				DrawPanelText(cpanel, " ");
				DrawPanelItem(cpanel, "Back", ITEMDRAW_CONTROL);
				DrawPanelItem(cpanel, " ", ITEMDRAW_NOTEXT);
				DrawPanelText(cpanel, " ");
				DrawPanelItem(cpanel, "Exit", ITEMDRAW_CONTROL);
				ResetPack(hmenu[items]);
				SendPanelToClient(cpanel, client, TFS_MenuHandler, 30);
				CloseHandle(cpanel);
			} else {
				new Handle:cmenu = CreateMenu(TFS_CustomMenuHandler);
				SetMenuExitBackButton(cmenu, true);
				SetMenuTitle(cmenu, mtitle);
				new String:cmd[128];
				new String:desc[128];
				for (new i = 0; i < hmenu[itemct]; ++i) {
					ReadPackString(hmenu[items], cmd, sizeof(cmd));
					ReadPackString(hmenu[items], desc, sizeof(desc));
					new drawstyle = ITEMDRAW_DEFAULT;
					if (strlen(cmd) == 0)
						drawstyle = ITEMDRAW_DISABLED;
					AddMenuItem(cmenu, cmd, desc, drawstyle);
				}
				ResetPack(hmenu[items]);
				DisplayMenu(cmenu, client, 30);
			}
		}
	}
}


public TFS_MenuHandler(Handle:menu, MenuAction:action, client, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (menu == INVALID_HANDLE && action == MenuAction_Select && param2 == 8) {
		TFS_ShowPropMenu(client);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			TFS_ShowPropMenu(client);
		}
	}
}

public TFS_CustomMenuHandler(Handle:menu, MenuAction:action, client, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (action == MenuAction_Select) {
		new String:itemval[512];
		GetMenuItem(menu, param2, itemval, sizeof(itemval));
		if (strlen(itemval) > 0)
		{
			if(!g_bInBuildZone[client])
			{
				PrintToChat(client, "You can't build here! Move into a building area!");
				TFS_ShowPropMenu(client);
				return;
			}
			new prop_limit_ = GetConVarInt(prop_limit);
			if((g_iPropCount[client] >= prop_limit_))
			{
				PrintToChat(client, "You can't spawn any more props. Delete some to spawn more!");
				TFS_ShowMainMenu(client);
				return;
			}
			if(g_bIsClientSpec(client) == 1)
			{
				PrintToChat(client, "You cannot build in Spectator! Please join either RED or BLU!");
				TFS_ShowMainMenu(client);
				return;
			}
//			PrintToChatAll(itemval)
			decl ent;
			new Float:AbsAngles[3], Float:ClientOrigin[3], Float:Origin[3], Float:pos[3], Float:beampos[3], Float:PropOrigin[3], Float:EyeAngles[3];
						
			GetClientAbsOrigin(client, ClientOrigin);
			GetClientEyeAngles(client, EyeAngles);
			GetClientAbsAngles(client, AbsAngles);
				
			GetCollisionPoint(client, pos);
			
			/*if(!CanPropBeHere(pos))
			{
				PrintToChat(client, "You can't build here! Move into a building area!");
				TFS_ShowMainMenu(client);
				return;
			}*/
				
			PropOrigin[0] = pos[0];
			PropOrigin[1] = pos[1];
			PropOrigin[2] = (pos[2] + 0);
				
			beampos[0] = pos[0];
			beampos[1] = pos[1];
			beampos[2] = (PropOrigin[2] + 10);
				
			//Spawn ent:
			ent = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(ent, "model", itemval);
			DispatchKeyValue(ent, "solid","6");
			DispatchSpawn(ent);
			SetEntityRenderMode(ent, RENDER_TRANSALPHA);
			ActivateEntity(ent);
			TeleportEntity(ent, PropOrigin, AbsAngles, NULL_VECTOR);
			
			g_iOwner[ent] = client;
			g_iPropCount[client]++;
			g_iLastProp[client] = ent;
			
			RequestFrame(CheckEntity1, ent);
				
			//Send BeamRingPoint:
			GetEntPropVector(ent, Prop_Data, "m_vecOrigin", Origin);
			TE_SetupBeamRingPoint(PropOrigin, 10.0, 150.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, {236, 150, 55, 200}, 20, 0);
			TE_SendToAll();
			EmitSoundToClient(client, SOUND_SPAWN, _, _, _, _, _, 50);

			//anti-stuck protection
			for (new i=1; i <= MaxClients; i++)
				if (IsClientInGame(i) && IsPlayerAlive(i))
					if (IsStuckInEnt(i, ent))
					{
						PrintToChat(client, "\x01You cannot build on \x04Players!");
						DeleteProp(ent);
						break;
					}
			TFS_ShowPropMenu(client);
		}
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			TFS_ShowPropMenu(client);
		}
	}
}

public void CheckEntity1(int entity)
{
	RequestFrame(CheckEntity2, entity);
}

public void CheckEntity2(int entity)
{
	//if(IsValidEntity(entity) && !g_bInBuildZone[entity])
	//	DeleteProp(entity);
}

stock GetCollisionPoint(client, Float:pos[3])
{
	decl Float:vOrigin[3], Float:vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	if (entity <= MaxClients) {
		return false;
	}
	if (contentsMask & MASK_SOLID) {
		return true;
	}
	
	static char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname))) {

		PrintToConsoleAll(classname);
		if(StrEqual(classname, "func_nobuild")) {
			return true;
		}
	}
	
	return false;
}

///////////////////
/*Manipulate Menu*/
///////////////////

//Manipulate Menu
TFS_ManipMenu(client)
{
	new target = GetClientAimTarget(client, false);
	if(!g_bInBuildZone[client]) {
		PrintToChat(client, "You are outside of a building area, so may not manipulate this prop!");
		TFS_ShowMainMenu(client);
		return;
	} else {
		if(CanModifyProp(client, target)) {
			//menu chunk
			g_iSelectedProp[client] = target;
			GetEntPropVector(g_iSelectedProp[client], Prop_Data, "m_angRotation", g_vecSelectedPropPrevAng[client]);
			GetEntPropVector(g_iSelectedProp[client], Prop_Data, "m_vecOrigin", g_vecSelectedPropPrevPos[client]);
			GetClientEyeAngles(client, g_vecLockedAng[client]);
			SDKHook(client, SDKHook_PreThink, PropManip);
			SetEntityMoveType(client, MOVETYPE_NONE);

			//prevents unable to re-grab prop after grab. 
			SetEntProp(target, Prop_Send, "m_nSolidType", 6);

			//draw menu
			new Handle:menu = CreateMenu(Menu_Manip);
			SetMenuTitle(menu, "WASD Moves The Prop | Jump or Duck moves Up or Down | Alt-Fire Rotates");

			AddMenuItem(menu, "1", "Save Your Changes");
			AddMenuItem(menu, "2", "Discard Your Changes");

			SetMenuExitButton(menu, false);
			DisplayMenu(menu, client, 720);
		}
	}
}

//Manipulate Menu options
public Menu_Manip(Handle:menu, MenuAction:action, client, option) {
	if(action == MenuAction_Select) {//This is the user selection, not entirely sure how it works but hey
		for (new i=1; i <= MaxClients; i++) { //For loop that increments the value of i
			if (IsClientInGame(i) && IsPlayerAlive(i)) { //If the client with a value of i is fully connected and alive
				if (IsStuckInEnt(i, g_iSelectedProp[client])) { //Check if client i is stuck in the selected prop of the current client (That's you!)
					PrintToChat(client, "\x01You cannot move props onto \x04Players!");
					TeleportEntity(g_iSelectedProp[client], g_vecSelectedPropPrevPos[client], g_vecSelectedPropPrevAng[client], NULL_VECTOR);
					break;
				}
			}/* Attempt to stop the prop being placed outside of build zones, but this method deoesn't work
			if (!g_bInBuildZone[g_iSelectedProp[client]]) { //I believe this only checks if users are in build areas
				PrintToChat(client, "The prop cannot be moved outside of build areas!");
				TeleportEntity(g_iSelectedProp[client], g_vecSelectedPropPrevPos[client], g_vecSelectedPropPrevAng[client], NULL_VECTOR);
				break;
			}*/
		}
		SDKUnhook(client, SDKHook_PreThink, PropManip); //Returns controls to the players after manipulating a prop
		SetEntityMoveType(client, MOVETYPE_WALK);
		EmitSoundToClient(client, SOUND_MANIPSAVE, _, _, _, _, _, 50);
		TFS_ShowMainMenu(client);

		if(option == 1) {//Discard changes
			TeleportEntity(g_iSelectedProp[client], g_vecSelectedPropPrevPos[client], g_vecSelectedPropPrevAng[client], NULL_VECTOR);
			EmitSoundToClient(client, SOUND_MANIPDISCARD, _, _, _, _, _, 50);
		}
	}
	else if(action == MenuAction_Cancel) {
		TFS_ShowMainMenu(client);} 
	else if(action == MenuAction_End) {
		CloseHandle(menu);
	}
}

//Manipulate prop controls
public PropManip(client)
{
	decl Float:pos[3], Float:ang[3], Float:pAng[3], Float:pPos[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	//g_iSelectedProp[client] = target;
	GetEntPropVector(g_iSelectedProp[client], Prop_Data, "m_angRotation", pAng);
	GetEntPropVector(g_iSelectedProp[client], Prop_Data, "m_vecOrigin", pPos);
	new btns = GetClientButtons(client);
	
	pos[2] -= 32.0;
	
	//Beam for manipulation
	TE_SetupBeamPoints(pos, pPos, g_iBeamIndex, 0, 0, 0, 0.1, 4.0, 8.0, 0, 0.0, {236, 150, 55, 200}, 0);
	TE_SendToAll(0.0);

	//up + down
	if(btns & IN_JUMP)
	{
		pPos[2] += 1.0;
	}
	else if(btns & IN_DUCK)
	{
		pPos[2] -= 1.0;
	}	
	// left + right
	if(btns & IN_MOVELEFT)
	{
		pPos[0] -= 1.0;
	}
	else if(btns & IN_MOVERIGHT)
	{
		pPos[0] += 1.0;
	}
	
	// forward + backward
	if(btns & IN_FORWARD)
	{
		pPos[1] += 1.0;
	}
	else if(btns & IN_BACK)
	{
		pPos[1] -= 1.0;
	}
	
	//Rotation
	if(btns & IN_ATTACK2)
	{
		for(new i=0; i<=2; i++)
		{
			new change = RoundToNearest(g_vecLockedAng[client][i] - ang[i]);
			pAng[i] += float(change);
		}
		TeleportEntity(client, NULL_VECTOR, g_vecLockedAng[client], NULL_VECTOR);
	}
	else
	{
		GetClientEyeAngles(client, g_vecLockedAng[client]);
	}
	
	//apply modifications
	//if(CanPropBeHere(pPos))
	TeleportEntity(g_iSelectedProp[client], pPos, pAng, NULL_VECTOR);
}

//Looks like earlier attempts at specifying buildzones by Batfoxkid, I'll keep em around for now

/*stock bool CanPropBeHere(const float pos[3])
{
        static const float maxs[3] = { 50.0, 50.0, 50.0 };
        static const float mins[3] = { -50.0, -50.0, 0.0 };
	TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_ALL, CanThisPropBeHere);
	if(TR_DidHit())
		return true;
	
	return false;
}

public bool CanThisPropBeHere(int entity, int contentsMask)
{
	static char classname[32];
	if(GetEntityClassname(entity, classname, sizeof(classname)))
	{
		PrintToConsoleAll(classname);
		if(StrEqual(classname, "func_flagdetectionzone"))
			return true;
	}
	
	return false;
}*/

/////////////
/*Edit Menu*/
/////////////

ShowMenu_Edit(client)
{
	new Handle:menu = CreateMenu(Menu_Edit);
	SetMenuTitle(menu, "TFS Redux - Edit Menu");

	AddMenuItem(menu, "1", "Open Adv. Rotation Menu");
	AddMenuItem(menu, "2", "Color/Paint");
	AddMenuItem(menu, "3", "Straighten");
	AddMenuItem(menu, "4", "Toggle collision");
	AddMenuItem(menu, "5", "Set See Through");
	AddMenuItem(menu, "6", "Desaturate");
	AddMenuItem(menu, "7", "Undo Last Prop");
	AddMenuItem(menu, "8", "Set Size Normal");
	AddMenuItem(menu, "9", "Set Size Small");
	AddMenuItem(menu, "10", "Set Size Large");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_Edit(Handle:menu, MenuAction:action, client, option)
{	
	if(action == MenuAction_Select)
	{
		switch(option)
		{
			//Open Advanced Rotation Menu
			case 0: 
			{
				ShowMenu_AdvRotate(client);
				return;
			}
			case 1:
			{
				ShowMenu_Color(client);
				return;
			}
		}
		
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//straighten
				case 2:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//toggle collision
				case 3:
				{
					new col = GetEntProp(target, Prop_Send, "m_nSolidType");
					if(col != 0)
					{
						SetEntProp(target, Prop_Send, "m_nSolidType", 0);
						PrintToChat(client, "Collision disabled.");
						EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
					}
					else
					{
						SetEntProp(target, Prop_Send, "m_nSolidType", 6);
						PrintToChat(client, "Collision enabled.");
						EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
					}
				}
				//see through
				case 4:
				{
					new offset = GetEntSendPropOffs(target, "m_clrRender");
					SetEntData(target, offset + 3, 128, 1, true);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//Desaturate
				case 5:
				{
					new offset = GetEntSendPropOffs(target, "m_clrRender");
					for(new i=0; i<=2; i++)
					{
						if(GetEntData(target, offset + i, 1) == 0)
							SetEntData(target, offset + i, 128, 1, true);
					}
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//undo last prop
				case 6:DeleteLastProp(client);
				//resize normal
				case 7:
				{
					SetEntPropFloat(target, Prop_Send, "m_flModelScale", 1.0);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//resize small
				case 8:
				{
					SetEntPropFloat(target, Prop_Send, "m_flModelScale", 0.5);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//resize big
				case 9:
				{
					SetEntPropFloat(target, Prop_Send, "m_flModelScale", 1.2);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
			}
		}
		if(option > 0)
			ShowMenu_Edit(client);
		EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		TFS_ShowMainMenu(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

///////////////////////////
/*advanced rotation menu */
///////////////////////////

ShowMenu_AdvRotate(client)
{
	new Handle:menu = CreateMenu(Menu_AdvRotate);
	SetMenuTitle(menu, "TFS Redux - Adv. Rotation Menu");
	
	AddMenuItem(menu, "1", "X-Rotation Menu");
	AddMenuItem(menu, "2", "Y-Rotation Menu");
	AddMenuItem(menu, "3", "Z-Rotation Menu");
	AddMenuItem(menu, "4", "Rotate Upwards");
	AddMenuItem(menu, "5", "Rotate Sideways");
	AddMenuItem(menu, "6", "Straighten");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_AdvRotate(Handle:menu, MenuAction:action, client, option)
{	
	if(action == MenuAction_Select)
	{
		switch(option)
		{
			//X menu
			case 0: ShowMenu_XRotate(client);
			//Y menu
			case 1: ShowMenu_YRotate(client);
			//Z menu
			case 2: ShowMenu_ZRotate(client);
		}
		
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//upwards
				case 3:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 90.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//sideways
				case 4:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 90.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
				//straighten
				case 5:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
			}
		}
		if(option > 2)
			ShowMenu_AdvRotate(client);
		EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		ShowMenu_Edit(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

// X rotation Menu
ShowMenu_XRotate(client)
{
	new Handle:menu = CreateMenu(Menu_xRotate);
	SetMenuTitle(menu, "TFS Redux - Adv. X Rotation Menu");
	
	AddMenuItem(menu, "1", "X Rotation +1");
	AddMenuItem(menu, "2", "X rotation +5");
	AddMenuItem(menu, "3", "X rotation +10");
	AddMenuItem(menu, "4", "X Rotation +15");
	AddMenuItem(menu, "5", "X Rotation +30");
	AddMenuItem(menu, "6", "X Rotation +90");
	AddMenuItem(menu, "7", "Straighten");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_xRotate(Handle:menu, MenuAction:action, client, option)
{	
	if(action == MenuAction_Select)
	{
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//y +1
				case 0:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 1.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +5
				case 1:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 5.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +10
				case 2:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 10.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +15
				case 3:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 15.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +30
				case 4:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 30.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +90
				case 5:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[0] += 90.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//straighten
				case 6:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
			}
		}
		ShowMenu_XRotate(client);
		EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		ShowMenu_AdvRotate(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

// Y rotation Menu
ShowMenu_YRotate(client)
{
	new Handle:menu = CreateMenu(Menu_yRotate);
	SetMenuTitle(menu, "TFS Redux - Adv. Y Rotation Menu");
	
	AddMenuItem(menu, "1", "Y Rotation +1");
	AddMenuItem(menu, "2", "Y rotation +5");
	AddMenuItem(menu, "3", "Y rotation +10");
	AddMenuItem(menu, "4", "Y Rotation +15");
	AddMenuItem(menu, "5", "Y Rotation +30");
	AddMenuItem(menu, "6", "Y Rotation +90");
	AddMenuItem(menu, "7", "Straighten");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_yRotate(Handle:menu, MenuAction:action, client, option)
{	
	if(action == MenuAction_Select)
	{
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//y +1
				case 0:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 1.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +5
				case 1:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 5.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +10
				case 2:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 10.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +15
				case 3:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 15.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +30
				case 4:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 30.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//y +90
				case 5:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[1] += 90.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//straighten
				case 6:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
			}
		}
		ShowMenu_YRotate(client);
		EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		ShowMenu_AdvRotate(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

// z rotation Menu
ShowMenu_ZRotate(client)
{
	new Handle:menu = CreateMenu(Menu_zRotate);
	SetMenuTitle(menu, "TFS Redux - Adv. Z Rotation Menu");
	
	AddMenuItem(menu, "1", "Z Rotation +1");
	AddMenuItem(menu, "2", "Z rotation +5");
	AddMenuItem(menu, "3", "Z rotation +10");
	AddMenuItem(menu, "4", "Z Rotation +15");
	AddMenuItem(menu, "5", "Z Rotation +30");
	AddMenuItem(menu, "6", "Z Rotation +90");
	AddMenuItem(menu, "7", "Straighten");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_zRotate(Handle:menu, MenuAction:action, client, option)
{	
	if(action == MenuAction_Select)
	{
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//z +1
				case 0:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 1.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//z +5
				case 1:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 5.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//Z +10
				case 2:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 10.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//Z +15
				case 3:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 15.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//Z +30
				case 4:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 30.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//Z +90
				case 5:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					new Float:ang[3];
					Entity_GetAbsAngles(target, ang);
					ang[2] += 90.0;
					TeleportEntity(target, NULL_VECTOR, ang, NULL_VECTOR);
				}
				//straighten
				case 6:
				{
					//Resolidates prop to prevent unselectable prop glitch.
					SetEntProp(target, Prop_Send, "m_nSolidType", 6);
					decl Float:f_angles[3];
					f_angles[0] = 0.0, f_angles[1] = 0.0, f_angles[2] = 0.0;
					TeleportEntity(target, NULL_VECTOR, f_angles, NULL_VECTOR);
					EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
				}
			}
		}
		ShowMenu_ZRotate(client);
		EmitSoundToClient(client, SOUND_EDIT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		ShowMenu_AdvRotate(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

//////////////////
/*Who Owns This?*/
//////////////////

public WhoOwns(client) {
	new prop = GetClientAimTarget(client, false); //Prop variable is set to the client
	if (!(prop <= 0)) {
		new owner = g_iOwner[prop];
		PrintToChat(client, "Prop is owned by: %N", owner);
		TFS_ShowMainMenu(client);
	} else {
		PrintToChat(client, "Invalid target!");
		TFS_ShowMainMenu(client);
	}
}

///////////////////
/*Gameplay Basics*/
///////////////////

//checks if in spec
stock bool:g_bIsClientSpec(client)
{
	return GetClientTeam(client)<2;
}

//ownership checker
bool:CanModifyProp(client, prop)
{
	if(prop <= GetMaxClients())
	{
		PrintToChat(client, "Not a valid prop!");
		return false;
	}
	if(g_iOwner[prop] != client)
	{
		PrintToChat(client, "You don't own this prop!");
		return false;
	}
	return true;
}

bool:ValidProp(client, prop)
{
	if(prop <= GetMaxClients())
	{
		PrintToChat(client, "Not a valid prop!");
		return false;
	}
	return true;
}

/////////////////////
/*Dissolve Function*/
/////////////////////

//Dissolve function
DeleteProp(prop)
{
	g_iPropCount[g_iOwner[prop]]--;
	Effect_DissolveEntity(prop, DISSOLVE_CORE);
	g_iOwner[prop] = 0;
	g_bKillProp[prop] = false;
}

//////////////////
/*Undo Last Prop*/
//////////////////

//Undoes last prop using dissolve function
DeleteLastProp(client)
{
	if(CanModifyProp(client, g_iLastProp[client]))
	{
		DeleteProp(g_iLastProp[client]);
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
		g_iLastProp[client] = 0;
	}
	TFS_ShowMainMenu(client);
}

//Undo Command version (doesn't kick back to main menu)
DeleteLastPropCmd(client)
{
	if(CanModifyProp(client, g_iLastProp[client]))
	{
		DeleteProp(g_iLastProp[client]);
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
		g_iLastProp[client] = 0;
	}
}

///////////////
/*Delete Prop*/
///////////////

//Deletes prop using dissolve function
DeleteAimProp(client)
{
	new target = GetClientAimTarget(client, false);
	if(CanModifyProp(client, target))
	{
		DeleteProp(target);
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
	}
	TFS_ShowMainMenu(client);
}

//Delete command version (doesn't kick back to main menu)
DeleteAimPropCmd(client)
{
	new target = GetClientAimTarget(client, false);
	if(CanModifyProp(client, target))
	{
		DeleteProp(target);
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
	}
}

////////////////////////
/*Clear All Props Menu*/
////////////////////////

ShowMenu_Clear(client)
{
	new Handle:menu = CreateMenu(Menu_Clear);
	SetMenuTitle(menu, "Are you sure you want to clear all your props?");
	
	AddMenuItem(menu, "1", "Yes");
	AddMenuItem(menu, "2", "No");
	
	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 720);

}

public Menu_Clear(Handle:menu, MenuAction:action, client, option)
{
	if(action == MenuAction_Select)
	{
		if(option == 0)
		{
			ClearAllProps(client);
		}
		TFS_ShowMainMenu(client);
	}
	else if(action == MenuAction_Cancel)
		TFS_ShowMainMenu(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

//prop clearer
ClearAllProps(client)
{
	for(new i=1; i<sizeof(g_iOwner); i++) {
		if(g_iOwner[i] == client)
		DeleteProp(i);
	}
	if(IsValidEntity(client)) {
		EmitSoundToClient(client, SOUND_DELETE, _, _, _, _, _, 50);
	}
}

//////////////
/*Paint Menu*/
//////////////

ShowMenu_Color(client) {

	new Handle:menu = CreateMenu(Menu_Color);
	SetMenuTitle(menu, "TFS Redux - Paint Menu");
	
	AddMenuItem(menu, "1", "Normal");
	AddMenuItem(menu, "2", "Red");
	AddMenuItem(menu, "3", "Green");
	AddMenuItem(menu, "4", "Blue");
	AddMenuItem(menu, "5", "Yellow");
	AddMenuItem(menu, "6", "Pale Blue");
	AddMenuItem(menu, "7", "Light Green");
	AddMenuItem(menu, "8", "Orange");
	AddMenuItem(menu, "9", "Cyan");
	AddMenuItem(menu, "10", "Brown");
	AddMenuItem(menu, "11", "Lavender");
	AddMenuItem(menu, "12", "Pink");
	AddMenuItem(menu, "13", "Purple");
	AddMenuItem(menu, "14", "Gray");		
	AddMenuItem(menu, "15", "Black");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 720);
}
public Menu_Color(Handle:menu, MenuAction:action, client, option) {

	if(action == MenuAction_Select)
	{
		new target = GetClientAimTarget(client, false);
		if(CanModifyProp(client, target))
		{
			switch(option)
			{
				//normal
				case 0: SetEntityRenderColor(target, 255, 255, 255, 255);
				//red
				case 1: SetEntityRenderColor(target, 255, 0, 0, 255);
				//Green
				case 2: SetEntityRenderColor(target, 102, 255, 102, 255);
				//blue
				case 3: SetEntityRenderColor(target, 0, 0, 255, 255);
				//yellow
				case 4: SetEntityRenderColor(target, 255, 255, 0, 255);
				//Pale Blue
				case 5: SetEntityRenderColor(target, 0, 128, 255, 255);
				//Light Green
				case 6: SetEntityRenderColor(target, 153, 204, 204, 255);
				//orange
				case 7: SetEntityRenderColor(target, 255, 97, 3, 255);
				//cyan
				case 8: SetEntityRenderColor(target, 0, 255, 255, 255);
				//brown
				case 9: SetEntityRenderColor(target, 139, 69, 19, 255);	
				//Lavender
				case 10: SetEntityRenderColor(target, 230, 230, 250, 255);
				//pink
				case 11: SetEntityRenderColor(target, 255, 0, 255, 255);
				//purple
				case 12: SetEntityRenderColor(target, 125, 38, 205, 255);
				//gray
				case 13: SetEntityRenderColor(target, 110, 123, 139, 255);
				//black
				case 14: SetEntityRenderColor(target, 0, 0, 0, 255);
			}
		}
		ShowMenu_Color(client);
		/*if(option > 7)
			ClientCommand(client, "slot9");*/
		EmitSoundToClient(client, SOUND_PAINT, _, _, _, _, _, 120);
	}
	else if(action == MenuAction_Cancel)
		TFS_ShowMainMenu(client);
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

///////////////
/*Admin Menus*/
///////////////

public Action:Command_TFSAdmin(client, args) {
	TFS_ShowAdminMenu(client);
	return Plugin_Handled;
}

TFS_ShowAdminMenu(client)
{
	new Handle:menu = CreateMenu(AdminMenu);
	SetMenuTitle(menu, "TFS Redux - Admin Menu");

	AddMenuItem(menu, "to", "Take Ownership of Prop");
	AddMenuItem(menu, "fcp", "Force-Clear a Player's Props")
	AddMenuItem(menu, "reset", "Reset a Player's Prop Count")
	AddMenuItem(menu, "max", "Set a Player's Prop Count to Max")
	AddMenuItem(menu, "rld", "Reload proplist.cfg")


	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 720);
}

public int AdminMenu(Menu menu, MenuAction action, int client, int option)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			TFS_ShowMainMenu(client);
		}
		case MenuAction_Select:
		{

			new String:item[64];
			GetMenuItem(menu, option, item, sizeof(item));
			
			if (StrEqual(item, "to"))
			{
                TakeOwnership(client);
			}
			else if (StrEqual(item, "fcp"))
			{
				ShowMenu_AdminFCP(client);
			}
			else if (StrEqual(item, "reset"))
			{
				ShowMenu_AdminResetPC(client);
			}
			else if (StrEqual(item, "max"))
			{
				ShowMenu_AdminMax(client);
			}
			else if (StrEqual(item, "rld"))
			{
				new String:hc[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, hc, sizeof(hc), "configs/TFS/proplist.cfg");
				ParseConfigFile(hc);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}

	}
	return 0;
}

ShowMenu_AdminFCP(client)
{
	new Handle:menu = CreateMenu(AdminFCP);
	SetMenuTitle(menu, "TFS Redux - Select a player to clear their props!");
	
/*	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;

		decl String:sID[8], String:sName[32];

		GetClientName(i, sName, sizeof(sName));
		Format(sID, sizeof(sID), "%d", i);

		AddMenuItem(menu, sID, sName);
	} */

	AddTargetsToMenu(menu, client, true, false);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 720);
}

public int AdminFCP(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			TFS_ShowAdminMenu(client);
		}
		case MenuAction_Select:
        {    
			new String:sInfo[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
			new target = GetClientOfUserId(StringToInt(sInfo));
			ClearAllProps(target);
			PrintToChat(client, "Removed props of %N", target);
//			ForceClearProps(client, sInfo);
//			PrintToChat(client, "test1 %s", sInfo);
//			PrintToChat(client, "test2 %N", param2);
//			for (int i = 1; i <= MaxClients; i++)
//			{
//				if (!IsClientInGame(i) && (StringToInt(sInfo) != i)) continue;
//
//				PrintToChat(client, "That player's name is: %N", i);
//				ForceClearProps(client, i)
//				return;
//			}  
        }

		case MenuAction_End:
		{
			CloseHandle(menu);
		}

	}
	return 0;
}

ShowMenu_AdminResetPC(client) //Y'know, reading the function name at first gave me a different impression
{
	new Handle:menu = CreateMenu(AdminResetPC);
	SetMenuTitle(menu, "TFS Redux - Select a player to reset their propcount!");

	AddTargetsToMenu(menu, client, true, false);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 720);
}

public int AdminResetPC(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			TFS_ShowAdminMenu(client);
		}
		case MenuAction_Select:
        {    
			new String:sInfo[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
			new target = GetClientOfUserId(StringToInt(sInfo));
			g_iPropCount[target] = 0;

			ReplyToCommand(client, "You reset %N's propcount!", target);
        }

		case MenuAction_End:
		{
			CloseHandle(menu);
		}

	}
	return 0;
}

ShowMenu_AdminMax(client)
{
	new Handle:menu = CreateMenu(AdminMax);
	SetMenuTitle(menu, "TFS Redux - Set a player's propcount to max");

	AddTargetsToMenu(menu, client, true, false);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 720);
}

public int AdminMax(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			TFS_ShowAdminMenu(client);
		}
		case MenuAction_Select:
        {    
			new String:sInfo[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
			new target = GetClientOfUserId(StringToInt(sInfo));
			new prop_limit_ = GetConVarInt(prop_limit);
			g_iPropCount[target] = prop_limit_;

			ReplyToCommand(client, "You set %N's propcount to %i!", target, prop_limit_);
        }

		case MenuAction_End:
		{
			CloseHandle(menu);
		}

	}
	return 0;
}

/////////////////
/*Admin Actions*/
/////////////////

TakeOwnership(client)
{
	new target = GetClientAimTarget(client, false);
	if (client != g_iOwner[target] && g_iOwner[target])
	{
		g_iOwner[target] = client;
		PrintToChat(client, "Took Ownership of this Prop!")
	}
}


/*
public Action:Command_TFSClear(user, targetUser) { //Doesn't work, clears *all* props rather than just a users props. Commenting out.
	
	if (targetUser == 0) {
		if (user != 0) {
			PrintToChat(user, "Invalid Target!");
		} else {
			PrintToConsole(user, "Invalid Target!");
		}
		return Plugin_Stop;
	}

	new x = 0;
	for(new i=1; i<sizeof(g_iOwner); i++) {
		if(g_iOwner[i] == targetUser) {
		DeleteProp(i);
		x++;
		}
	}

	if (user != 0) {
		PrintToChat(user, "Cleared %i props from target.", x);
	} else {
		PrintToConsole(user, "Cleared %i props from target.", x);
	}
	return Plugin_Handled;
}
*/

/*
ForceClearProps(client, args)
{
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	// Try and find a matching player
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		PrintToChatAll("%s", target_list[i]);
		ClearAllProps(target_list[i]);
	}
	
	ReplyToCommand(client, "Player props cleared");
	return Plugin_Handled;
}
*/

//////////////////////////
/*Stuck Player Preventer*/
//////////////////////////

stock bool:IsStuckInEnt(client, ent)
{
    decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
    
    GetClientMins(client, vecMin);
    GetClientMaxs(client, vecMax);
    
    GetClientAbsOrigin(client, vecOrigin);
    
    TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
    return TR_DidHit();
}


public bool:TraceRayHitOnlyEnt(entityhit, mask, any:data)
{
    return entityhit==data;
}