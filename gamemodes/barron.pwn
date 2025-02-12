//
//  RC BARNSTORM - A demonstration vehicle vs vehicle script for SA-MP 0.2
//  -- by kyeman (SA-MP team) 2007
//
//  This script demonstrates the following :-
//  - An automatic vehicle observer mode switchable via a key press.
//  - Text drawing and the use of GTA ~k~ key constants.
//  - Use of RC vehicles
//  - Dynamic creation and destruction of vehicles
//  - The OnPlayerKeyStateChange event/callback and determining
//    if a key has just been pressed.
//  - Bypassing SA-MP's class selection with SetSpawnInfo

// Add this before includes
#define SSCANF_NO_NICE_FEATURES

#include <a_samp>
#include <core>
#include <float>
#include <a_mysql> // Download dulu di github.com/pBlueG/SA-MP-MySQL
#include <YSI_Coding\y_hooks> // Add this include
#include <YSI_Data\y_iterate>
#include <sscanf2>
#include <md5> // Add this for password hashing

// Database defines
// #define PLAYER_DATA "Users/%s.ini"

// MySQL Define
#define MYSQL_HOST      "localhost"
#define MYSQL_USER      "root"
#define MYSQL_PASSWORD  "1234"
#define MYSQL_DATABASE  "dalemondb"

// Dialog defines
#define DIALOG_LOGIN     1
#define DIALOG_REGISTER  2

// Tambahin di bagian atas file, setelah defines
#define MAX_LOGIN_TRIES 3
#define LOGIN_TIMEOUT   30 // dalam detik

// Tambahin di bagian atas setelah defines
#define PLAYER_MARKER_MODE_OFF 0

// TextDraw Defines (update semua)
#define TD_LOGIN_BG       0  // Background hitam transparan
#define TD_LOGIN_BOX      1  // Box putih
#define TD_LOGIN_LOGO     2  // Logo server
#define TD_LOGIN_HEADER   3  // Text "SELAMAT DATANG"
#define TD_LOGIN_CITY     4  // Text "KOTA DALEMON"
#define TD_LOGIN_DESC     5  // Description
#define TD_LOGIN_INPUT    6  // Input box
#define TD_LOGIN_BUTTON   7  // Login button
#define TD_LOGIN_CLOSE    8  // Close button

// Variables
enum pInfo
{
    pID,                    // ID di database
    pName[MAX_PLAYER_NAME], // Nama player
    pPassword[65],          // Password (hashed)
    pSalt[17],             // Salt buat password
    pCash,
    pAdmin,
    pScore,
    Float:pHealth,
    bool:pLogged,
    bool:pSpawned,
    pLoginTries,
    pLoginTimer
}
new PlayerInfo[MAX_PLAYERS][pInfo];

new gPlayerVehicles[MAX_PLAYERS]; // the vehicleid for the active playerid
new gPlayerObserving[MAX_PLAYERS]; // player observing which active player
new Text:txtObsHelper;

// MySQL connection handle
new MySQL:g_SQL;

new Text:LoginTD[9]; // Update jumlah TextDraws

new Float:gSpawnPositions[26][4] = { // positions where players in vehicles spawn
{-205.7703,-119.6655,2.4094,342.0546},
{-202.1386,-54.1213,2.4111,95.6799},
{-197.2334,7.5293,2.4034,16.0852},
{-135.7348,61.7265,2.4112,354.3534},
{-73.7883,73.4238,2.4082,260.5399},
{-6.9850,27.9988,2.4112,201.7691},
{0.6782,-16.0898,2.4076,161.7720},
{-46.3365,-88.3937,2.4092,180.7382},
{-72.4389,-127.2939,2.4107,113.5616},
{-128.1940,-144.1725,2.4094,78.9676},
{-266.0189,-50.6718,2.4125,223.8079},
{-244.2617,-1.0468,2.1038,257.3333},
{-93.3146,-32.4889,2.4085,186.0631},
{-130.7054,-93.4983,2.4124,73.8375},
{-117.4049,4.2989,2.4112,337.1284},
{-26.1622,135.8739,2.4094,248.1580},
{45.5705,86.7586,2.0753,147.3342},
{54.9881,2.2997,1.1132,95.7173},
{-248.9905,-119.3982,2.4083,303.7859},
{-60.1321,55.5239,2.4038,325.2209},
{-60.9184,47.9302,5.7706,342.8299},
{-70.0303,-22.0071,2.4113,165.2789},
{-138.3093,-83.2640,2.4152,4.0455},
{-25.5989,94.6100,2.4041,150.8322},
{-161.0327,-70.5945,2.4042,142.9221},
{-54.8308,-139.6148,2.4119,258.7639}
};

//------------------------------------------------------------------------------------------------------

main()
{
	print("Running: RC BARNSTORM by kyeman 2007");
}

//------------------------------------------------
// ObserverSwitchToNextVehicle
// Will increment the current observed player
// until it finds a new player with an active vehicle.

ObserverSwitchToNextVehicle(playerid)
{
	new x=0;
	while(x!=MAX_PLAYERS) { // MAX_PLAYERS iterations
	    gPlayerObserving[playerid]++;
	    if(gPlayerObserving[playerid] == MAX_PLAYERS) {
			// we need to cycle back to the start
			gPlayerObserving[playerid] = 0;
		}
		// see if the target player has a vehicle,
		// if so assign this player to observe it
		if(gPlayerVehicles[gPlayerObserving[playerid]] != 0) {
			PlayerSpectateVehicle(playerid,gPlayerVehicles[gPlayerObserving[playerid]]);
			return;
		}
		x++;
	}
	// didn't find any vehicles to observe. we'll have to default to last
	PlayerSpectateVehicle(playerid,gPlayerVehicles[gPlayerObserving[playerid]]);
}

//------------------------------------------------
// IsKeyJustDown. Returns 1 if the key
// has just been pressed, 0 otherwise.

IsKeyJustDown(key, newkeys, oldkeys)
{
	if((newkeys & key) && !(oldkeys & key)) return 1;
	return 0;
}

//------------------------------------------------

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(gPlayerObserving[playerid] >= 0 && IsKeyJustDown(KEY_SPRINT,newkeys,oldkeys)) {
		// They're requesting to spawn, so take them out of observer mode
		// this will cause them to spawn automatically, using the SpawnInfo
		// we previously forced upon them during OnPlayerRequestClass
		TogglePlayerSpectating(playerid,0);
		gPlayerObserving[playerid] = (-1);
		SendClientMessage(playerid,0xFFFFFFFF,"Leaving spectate");
		return;
	}
	
	if(gPlayerObserving[playerid] >= 0 && IsKeyJustDown(KEY_FIRE,newkeys,oldkeys)) {
	   // They're requesting to change observer to another vehicle.
	   ObserverSwitchToNextVehicle(playerid);
	}
}

//------------------------------------------------

public OnPlayerConnect(playerid)
{
	// Reset semua data player
	PlayerInfo[playerid][pCash] = 0;
	PlayerInfo[playerid][pAdmin] = 0;
	PlayerInfo[playerid][pScore] = 0;
	PlayerInfo[playerid][pHealth] = 100.0;
	PlayerInfo[playerid][pLogged] = false;
	PlayerInfo[playerid][pSpawned] = false;
	
	// Reset login variables
	PlayerInfo[playerid][pLoginTries] = 0;
	PlayerInfo[playerid][pLoginTimer] = -1;
	
	// Debug messages
    SendClientMessage(playerid, -1, "DEBUG: OnPlayerConnect called");
	
	// Get player name
	GetPlayerName(playerid, PlayerInfo[playerid][pName], MAX_PLAYER_NAME);
	
	// Check if account exists
	new query[103];
	mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `players` WHERE `username` = '%e' LIMIT 1", PlayerInfo[playerid][pName]);
	
	// Debug query
    printf("DEBUG: Query: %s", query);
	
	mysql_tquery(g_SQL, query, "OnPlayerDataCheck", "d", playerid);
	
	// Add block spectator/spawn before login
    TogglePlayerSpectating(playerid, 1);
    
    // Debug
    SendClientMessage(playerid, -1, "DEBUG: OnPlayerConnect called");
    printf("DEBUG: Player %s connected", PlayerInfo[playerid][pName]);
	
	ShowLoginCard(playerid); // Add this before return 1
	
	return 1;
}

//------------------------------------------------

public OnPlayerDisconnect(playerid, reason)
{
	// Save data player waktu disconnect
	if(PlayerInfo[playerid][pLogged] == true)
	{
		SavePlayerData(playerid);
	}
	
	if(gPlayerVehicles[playerid]) {
	    // Make sure their vehicle is destroyed when they leave.
    	DestroyVehicle(gPlayerVehicles[playerid]);
    	gPlayerVehicles[playerid] = 0;
	}
	return 0;
}

//------------------------------------------------
//rcbarron = 464

public OnPlayerSpawn(playerid)
{
	// Create their own vehicle and put them in
    gPlayerVehicles[playerid] = CreateVehicle(464,
						gSpawnPositions[playerid][0],
						gSpawnPositions[playerid][1],
						gSpawnPositions[playerid][2],
						gSpawnPositions[playerid][3],
						-1,-1,10);

    PutPlayerInVehicle(playerid,gPlayerVehicles[playerid],0);
    //ForceClassSelection(playerid); // for next time they respawn
    TextDrawHideForPlayer(playerid, txtObsHelper);
    SetPlayerWorldBounds(playerid,200.0,-300.0,200.0,-200.0);
   	return 1;
}

//------------------------------------------------

public OnPlayerDeath(playerid, killerid, reason)
{
	// We need to cleanup their vehicle
	RemovePlayerFromVehicle(gPlayerVehicles[playerid]);
	DestroyVehicle(gPlayerVehicles[playerid]);
	gPlayerVehicles[playerid] = 0;
	
	// Send the death information to all clients
	SendDeathMessage(killerid,playerid,reason);

    // If anyone was observing them, they'll have to switch to the next
    new x=0;
    while(x!=MAX_PLAYERS) {
        if(x != playerid && gPlayerObserving[x] == playerid) {
            ObserverSwitchToNextVehicle(x);
		}
		x++;
	}

 	return 1;
}

//------------------------------------------------

public OnPlayerRequestClass(playerid, classid)
{
    if(!PlayerInfo[playerid][pLogged]) {
        TogglePlayerSpectating(playerid, 1);
        return 0;
    }
    
	// put them straight into observer mode, effectively
	// bypassing class selection.
 	TogglePlayerSpectating(playerid,1);
    ObserverSwitchToNextVehicle(playerid);
    TextDrawShowForPlayer(playerid, txtObsHelper);

    // also force this dud spawn info upon them so that they
    // have spawn information set.
    SetSpawnInfo(playerid,0,0,
			gSpawnPositions[playerid][0],
			gSpawnPositions[playerid][1],
			gSpawnPositions[playerid][2],
			gSpawnPositions[playerid][3],
			-1,-1,-1,-1,-1,-1);
    
	return 0;
}

//------------------------------------------------

public OnGameModeInit()
{
	// MySQL connection
	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE);
	if(g_SQL == MYSQL_INVALID_HANDLE) 
	{
		print("MySQL Connection Failed!");
		SendRconCommand("exit"); // Stop server kalo gagal connect
		return 0;
	}
	print("MySQL Connection Successful!");

	// Create tables kalo belom ada
	mysql_tquery(g_SQL, "CREATE TABLE IF NOT EXISTS `players` (\
		`id` int(11) NOT NULL AUTO_INCREMENT,\
		`username` varchar(24) NOT NULL,\
		`password` varchar(65) NOT NULL,\
		`salt` varchar(17) NOT NULL,\
		`cash` int(11) NOT NULL DEFAULT '0',\
		`admin` int(11) NOT NULL DEFAULT '0',\
		`score` int(11) NOT NULL DEFAULT '0',\
		`health` float NOT NULL DEFAULT '100.0',\
		PRIMARY KEY (`id`),\
		UNIQUE KEY `username` (`username`)\
	)");

	// Server settings
	SetGameModeText("Roleplay v1.0");
	ShowPlayerMarkers(PLAYER_MARKER_MODE_OFF);
	ShowNameTags(1);
	SetNameTagDrawDistance(20.0);
	EnableStuntBonusForAll(0);
	DisableInteriorEnterExits();

	// Add a dud player class
	AddPlayerClass(0,0.0,0.0,4.0,0.0,-1,-1,-1,-1,-1,-1);
	
	// Init our globals
	new x=0;
	while(x!=MAX_PLAYERS) {
	    gPlayerVehicles[x] = 0;
	    gPlayerObserving[x] = (-1);
	    x++;
	}
	
	// Init our observer helper text display
	txtObsHelper = TextDrawCreate(20.0, 400.0,
	"Press ~b~~k~~PED_SPRINT~ ~w~to spawn~n~Press ~b~~k~~PED_FIREWEAPON~ ~w~to switch players");
	TextDrawUseBox(txtObsHelper, 0);
	TextDrawFont(txtObsHelper, 2);
	TextDrawSetShadow(txtObsHelper,0);
    TextDrawSetOutline(txtObsHelper,1);
    TextDrawBackgroundColor(txtObsHelper,0x000000FF);
    TextDrawColor(txtObsHelper,0xFFFFFFFF);
    
	CreateLoginTextDraws(); // Add this line before return 1
	
	return 1;
}

//------------------------------------------------

public OnGameModeExit()
{
	DestroyLoginTextDraws();
	mysql_close(g_SQL);
	return 1;
}

//------------------------------------------------

public OnPlayerUpdate(playerid)
{
	/*
	new Keys,ud,lr;
	
	if(GetPlayerState(playerid) == PLAYER_STATE_SPECTATING) {
	    GetPlayerKeys(playerid,Keys,ud,lr);
	    if(ud > 0) {
	        SendClientMessage(playerid, 0xFFFFFFFF, "DOWN");
		}
		else if(ud < 0) {
		    SendClientMessage(playerid, 0xFFFFFFFF, "UP");
		}
		
		if(lr > 0) {
	        SendClientMessage(playerid, 0xFFFFFFFF, "RIGHT");
		}
		else if(lr < 0) {
		    SendClientMessage(playerid, 0xFFFFFFFF, "LEFT");
		}
	}*/
	
	return 1;
}

//------------------------------------------------

// Helper function buat ambil nama player (anti-hack)

// Remove GetPlayerNameEx function since it's not used

//------------------------------------------------

forward OnPlayerDataCheck(playerid);
public OnPlayerDataCheck(playerid)
{
	if(cache_num_rows() > 0)
	{
		// Akun ada - ambil data
		cache_get_value_name_int(0, "id", PlayerInfo[playerid][pID]);
		cache_get_value_name(0, "password", PlayerInfo[playerid][pPassword], 65);
		cache_get_value_name(0, "salt", PlayerInfo[playerid][pSalt], 17);
		
		// Show login dialog dengan design baru
		new string[512];
		format(string, sizeof(string), "\
{FFFFFF}Selamat Datang di {FF0000}Kota Dalemon\n\
\n\
{FFFFFF}Halo, {FF0000}%s{FFFFFF}!\n\
Kami senang melihat Anda kembali ke kota kami.\n\
\n\
{FF0000}» {FFFFFF}Server Info:\n\
• Website: dalemon-rp.com\n\
• Discord: discord.gg/dalemon\n\
• Instagram: @dalemon.rp\n\
\n\
Silahkan masukkan password Anda untuk melanjutkan:\n", 
PlayerInfo[playerid][pName]);
		
		ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, 
			"{FF0000}DALEMON {FFFFFF}ROLEPLAY", 
			string, 
			"Masuk", "Keluar"
		);
	}
	else
	{
		// Akun ga ada - show register dialog
		new string[128];
		format(string, sizeof(string), "Selamat datang %s\nSilahkan daftar dengan password:", PlayerInfo[playerid][pName]);
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", string, "Register", "Keluar");
	}
	return 1;
}

SavePlayerData(playerid)
{
    if(PlayerInfo[playerid][pLogged] == false) return 0;
    
    new query[512];
    mysql_format(g_SQL, query, sizeof(query), 
        "UPDATE `players` SET `cash`=%d,`admin`=%d,`score`=%d,`health`=%f WHERE `id`=%d",
        PlayerInfo[playerid][pCash],
        PlayerInfo[playerid][pAdmin],
        PlayerInfo[playerid][pScore],
        PlayerInfo[playerid][pHealth],
        PlayerInfo[playerid][pID]
    );
    mysql_tquery(g_SQL, query);
    return 1;
}

//------------------------------------------------

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_LOGIN:
        {
            if(!response) return Kick(playerid);
            
            new query[256];
            mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `players` WHERE `username` = '%e' LIMIT 1", PlayerInfo[playerid][pName]);
            mysql_tquery(g_SQL, query, "OnPlayerLogin", "is", playerid, inputtext);
        }
        case DIALOG_REGISTER:
        {
            if(!response) return Kick(playerid);
            if(strlen(inputtext) < 6) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", "Password minimal 6 karakter!\nSilahkan masukkan password:", "Register", "Keluar");
            
            // Generate salt
            new salt[17];
            for(new i = 0; i < 16; i++) salt[i] = random(94) + 33;
            salt[16] = 0;
            format(PlayerInfo[playerid][pSalt], 17, "%s", salt);
            
            // Hash password using our new Hash function
            new hashed_pass[65];
            format(hashed_pass, sizeof(hashed_pass), "%s", Hash(inputtext, salt));
            
            // Save to database
            new query[512];
            mysql_format(g_SQL, query, sizeof(query), "INSERT INTO `players` (`username`, `password`, `salt`) VALUES ('%e', '%e', '%e')", 
                PlayerInfo[playerid][pName], hashed_pass, salt);
            mysql_tquery(g_SQL, query, "OnPlayerRegister", "i", playerid);
        }
    }
    return 1;
}

//------------------------------------------------

forward OnPlayerLogin(playerid, const password[]);
public OnPlayerLogin(playerid, const password[])
{
    if(cache_num_rows() > 0)
    {
        new db_password[65], db_salt[17];
        cache_get_value_name(0, "password", db_password, sizeof(db_password));
        cache_get_value_name(0, "salt", db_salt, sizeof(db_salt));
        
        new hashed_pass[65];
        format(hashed_pass, sizeof(hashed_pass), "%s", Hash(password, db_salt));
        
        if(strcmp(hashed_pass, db_password) == 0)
        {
            ShowLoadingTextDraw(playerid); // Tambahin loading text
            
            // Password bener - Load data player
            cache_get_value_name_int(0, "id", PlayerInfo[playerid][pID]);
            cache_get_value_name_int(0, "cash", PlayerInfo[playerid][pCash]);
            cache_get_value_name_int(0, "admin", PlayerInfo[playerid][pAdmin]);
            cache_get_value_name_int(0, "score", PlayerInfo[playerid][pScore]);
            cache_get_value_name_float(0, "health", PlayerInfo[playerid][pHealth]);
            
            PlayerInfo[playerid][pLogged] = true;
            SendClientMessage(playerid, -1, "Login berhasil!");
            
            TogglePlayerSpectating(playerid, 0); // Allow spawn after login
            SpawnPlayer(playerid);
        }
        else
        {
            // Password salah - tambah counter
            PlayerInfo[playerid][pLoginTries]++;
            
            if(PlayerInfo[playerid][pLoginTries] >= MAX_LOGIN_TRIES)
            {
                // Kalo udah 3x salah, timeout
                new string[128];
                format(string, sizeof(string), "\
{FFFFFF}Selamat Datang di {FF0000}Kota Dalemon\n\
\n\
{FFFFFF}Halo, {FF0000}%s{FFFFFF}!\n\
\n\
{FF0000}[!] {FFFFFF}Password yang Anda masukkan salah! (%d/%d)\n\
Silahkan coba lagi dengan password yang benar.\n\
\n\
{FF0000}» {FFFFFF}Server Info:\n\
• Website: dalemon-rp.com\n\
• Discord: discord.gg/dalemon\n\
• Instagram: @dalemon.rp\n\
\n\
Masukkan password Anda:\n",
PlayerInfo[playerid][pName], PlayerInfo[playerid][pLoginTries], MAX_LOGIN_TRIES);
                
                ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, 
                    "{FF0000}DALEMON {FFFFFF}ROLEPLAY", 
                    string, 
                    "Masuk", "Keluar"
                );
            }
        }
    }
    return 1;
}

//------------------------------------------------

// Tambahin timer buat unlock login
forward UnlockLogin(playerid);
public UnlockLogin(playerid)
{
    PlayerInfo[playerid][pLoginTries] = 0;
    KillTimer(PlayerInfo[playerid][pLoginTimer]);
    return 1;
}

//------------------------------------------------

// Tambahin function buat loading text
// Tambah variable global untuk TextDraw
new Text:gLoadingTD;

ShowLoadingTextDraw(playerid)
{
    // Bikin TextDraw nya
    gLoadingTD = TextDrawCreate(320.0, 200.0, "Loading...");
    TextDrawShowForPlayer(playerid, gLoadingTD);
    // Set timer buat ilangin
    SetTimer("HideLoadingTextDraw", 2000, false);
    return 1;
}

forward HideLoadingTextDraw();
public HideLoadingTextDraw()
{
    TextDrawDestroy(gLoadingTD);
    return 1;
}

//------------------------------------------------

// Add this function before OnDialogResponse
stock Hash(const password[], const salt[])
{
    new tmp[128], hash[65];
    format(tmp, sizeof(tmp), "%s%s", password, salt);
    MD5_Generate(hash, tmp, sizeof(hash)); // Ganti MD5_Hash jadi MD5_Generate
    return hash;
}

// Tambah fungsi untuk create login TextDraws sebelum OnGameModeInit
CreateLoginTextDraws()
{
    // Background hitam transparan full screen
    LoginTD[TD_LOGIN_BG] = TextDrawCreate(0.0, 0.0, "_");
    TextDrawLetterSize(LoginTD[TD_LOGIN_BG], 0.0, 50.0);
    TextDrawTextSize(LoginTD[TD_LOGIN_BG], 640.0, 480.0); // Update size
    TextDrawAlignment(LoginTD[TD_LOGIN_BG], 1);
    TextDrawColor(LoginTD[TD_LOGIN_BG], 0);
    TextDrawUseBox(LoginTD[TD_LOGIN_BG], 1);
    TextDrawBoxColor(LoginTD[TD_LOGIN_BG], 0x000000AA);
    TextDrawSetShadow(LoginTD[TD_LOGIN_BG], 0);
    TextDrawSetOutline(LoginTD[TD_LOGIN_BG], 0);
    TextDrawFont(LoginTD[TD_LOGIN_BG], 1);
    TextDrawShowForAll(LoginTD[TD_LOGIN_BG]); // Show untuk semua

    // Box putih tengah
    LoginTD[TD_LOGIN_BOX] = TextDrawCreate(170.0, 130.0, "_");
    TextDrawLetterSize(LoginTD[TD_LOGIN_BOX], 0.0, 22.0);
    TextDrawTextSize(LoginTD[TD_LOGIN_BOX], 470.0, 280.0); // Update size
    TextDrawAlignment(LoginTD[TD_LOGIN_BOX], 1);
    TextDrawColor(LoginTD[TD_LOGIN_BOX], -1);
    TextDrawUseBox(LoginTD[TD_LOGIN_BOX], 1);
    TextDrawBoxColor(LoginTD[TD_LOGIN_BOX], 0xFFFFFFEE);
    TextDrawSetShadow(LoginTD[TD_LOGIN_BOX], 0);
    TextDrawSetOutline(LoginTD[TD_LOGIN_BOX], 0);
    TextDrawFont(LoginTD[TD_LOGIN_BOX], 1);

    // Logo server (make bigger)
    LoginTD[TD_LOGIN_LOGO] = TextDrawCreate(320.0, 140.0, "DALEMON");
    TextDrawAlignment(LoginTD[TD_LOGIN_LOGO], 2);
    TextDrawBackgroundColor(LoginTD[TD_LOGIN_LOGO], 0x00000000);
    TextDrawFont(LoginTD[TD_LOGIN_LOGO], 2);
    TextDrawLetterSize(LoginTD[TD_LOGIN_LOGO], 0.8, 3.0); // Make bigger
    TextDrawColor(LoginTD[TD_LOGIN_LOGO], 0xFF0000FF);
    TextDrawSetProportional(LoginTD[TD_LOGIN_LOGO], 1);
    TextDrawSetOutline(LoginTD[TD_LOGIN_LOGO], 1);

    // Header "SELAMAT DATANG" (adjust position)
    LoginTD[TD_LOGIN_HEADER] = TextDrawCreate(320.0, 190.0, "SELAMAT DATANG");
    TextDrawAlignment(LoginTD[TD_LOGIN_HEADER], 2);
    TextDrawBackgroundColor(LoginTD[TD_LOGIN_HEADER], 0x00000000);
    TextDrawFont(LoginTD[TD_LOGIN_HEADER], 1);
    TextDrawLetterSize(LoginTD[TD_LOGIN_HEADER], 0.5, 2.0);
    TextDrawColor(LoginTD[TD_LOGIN_HEADER], 0x000000FF);
    TextDrawSetProportional(LoginTD[TD_LOGIN_HEADER], 1);

    // Text "KOTA DALEMON" (adjust position)
    LoginTD[TD_LOGIN_CITY] = TextDrawCreate(320.0, 220.0, "KOTA DALEMON");
    TextDrawAlignment(LoginTD[TD_LOGIN_CITY], 2);
    TextDrawBackgroundColor(LoginTD[TD_LOGIN_CITY], 0x00000000);
    TextDrawFont(LoginTD[TD_LOGIN_CITY], 3);
    TextDrawLetterSize(LoginTD[TD_LOGIN_CITY], 0.6, 2.5);
    TextDrawColor(LoginTD[TD_LOGIN_CITY], 0xFF0000FF);
    TextDrawSetProportional(LoginTD[TD_LOGIN_CITY], 1);
    TextDrawSetOutline(LoginTD[TD_LOGIN_CITY], 1);

    // Description (adjust position)
    LoginTD[TD_LOGIN_DESC] = TextDrawCreate(320.0, 260.0, "Silahkan masukkan password untuk melanjutkan");
    TextDrawAlignment(LoginTD[TD_LOGIN_DESC], 2);
    TextDrawBackgroundColor(LoginTD[TD_LOGIN_DESC], 0x00000000);
    TextDrawFont(LoginTD[TD_LOGIN_DESC], 1);
    TextDrawLetterSize(LoginTD[TD_LOGIN_DESC], 0.3, 1.5);
    TextDrawColor(LoginTD[TD_LOGIN_DESC], 0x666666FF);
    TextDrawSetProportional(LoginTD[TD_LOGIN_DESC], 1);

    // Input box (adjust position and size)
    LoginTD[TD_LOGIN_INPUT] = TextDrawCreate(220.0, 290.0, "_");
    TextDrawLetterSize(LoginTD[TD_LOGIN_INPUT], 0.0, 3.0);
    TextDrawTextSize(LoginTD[TD_LOGIN_INPUT], 420.0, 20.0);
    TextDrawAlignment(LoginTD[TD_LOGIN_INPUT], 1);
    TextDrawColor(LoginTD[TD_LOGIN_INPUT], -1);
    TextDrawUseBox(LoginTD[TD_LOGIN_INPUT], 1);
    TextDrawBoxColor(LoginTD[TD_LOGIN_INPUT], 0xEEEEEEFF);
    TextDrawSetShadow(LoginTD[TD_LOGIN_INPUT], 0);
    TextDrawSetOutline(LoginTD[TD_LOGIN_INPUT], 0);
    TextDrawFont(LoginTD[TD_LOGIN_INPUT], 1);
    TextDrawSetSelectable(LoginTD[TD_LOGIN_INPUT], true);

    // Login button (adjust position and size)
    LoginTD[TD_LOGIN_BUTTON] = TextDrawCreate(320.0, 340.0, "MASUK");
    TextDrawAlignment(LoginTD[TD_LOGIN_BUTTON], 2);
    TextDrawBackgroundColor(LoginTD[TD_LOGIN_BUTTON], 0xFF0000FF);
    TextDrawFont(LoginTD[TD_LOGIN_BUTTON], 2);
    TextDrawLetterSize(LoginTD[TD_LOGIN_BUTTON], 0.4, 2.0);
    TextDrawColor(LoginTD[TD_LOGIN_BUTTON], -1);
    TextDrawSetProportional(LoginTD[TD_LOGIN_BUTTON], 1);
    TextDrawUseBox(LoginTD[TD_LOGIN_BUTTON], 1);
    TextDrawBoxColor(LoginTD[TD_LOGIN_BUTTON], 0xFF0000FF);
    TextDrawTextSize(LoginTD[TD_LOGIN_BUTTON], 40.0, 100.0); // Make wider
    TextDrawSetSelectable(LoginTD[TD_LOGIN_BUTTON], true);
}

// Update fungsi ShowLoginCard
ShowLoginCard(playerid)
{
    TogglePlayerSpectating(playerid, 1); // Force spectating mode
    for(new i = 0; i < sizeof(LoginTD); i++) {
        TextDrawShowForPlayer(playerid, LoginTD[i]);
    }
    SelectTextDraw(playerid, 0xFF0000FF);
    return 1;
}

// Tambah OnPlayerClickTextDraw untuk handle clicks
public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    if(clickedid == LoginTD[TD_LOGIN_BUTTON]) {
        // Show password dialog when button clicked
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, 
            "{FF0000}LOGIN", 
            "Masukkan password:", 
            "Masuk", "Keluar"
        );
        return 1;
    }
    return 0;
}

// Add handler to destroy TextDraws
DestroyLoginTextDraws()
{
    for(new i = 0; i < sizeof(LoginTD); i++) {
        TextDrawDestroy(LoginTD[i]);
    }
}
