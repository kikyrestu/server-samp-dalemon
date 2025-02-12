#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <streamer>
#include <zcmd>
#include <progress2>

// MySQL Configuration
#define MYSQL_HOST      "localhost"
#define MYSQL_USER      "samp"
#define MYSQL_PASSWORD  "1234"
#define MYSQL_DATABASE  "dalemondb"

// Global Variables
new MySQL:g_SQL;

// Admin Levels
#define PLAYER_LEVEL    0
#define HELPER          1
#define ADMIN           2
#define SR_ADMIN        3
#define HEAD_ADMIN      4
#define MANAGEMENT      5

// Colors
#define COLOR_RED       0xFF0000FF
#define COLOR_GREEN     0x33CC33FF
#define COLOR_YELLOW    0xFFFF00FF
#define COLOR_WHITE     0xFFFFFFFF
#define COLOR_GREY      0xAFAFAFFF

// Dialog IDs
#define DIALOG_LOGIN    1
#define DIALOG_AHELP    2
#define DIALOG_TOGGLEHUD    3

// Player data structure
enum E_PLAYER_DATA
{
    pID,
    pName[MAX_PLAYER_NAME],
    pPassword[65],
    pSalt[17],
    pEmail[32],
    pAdmin,
    pMoney,
    pScore,
    Float:pHealth,
    Float:pArmour,
    Float:pHunger,
    Float:pThirst,
    Float:pStamina,
    PlayerBar:pHealthBar,
    PlayerBar:pHungerBar,
    PlayerBar:pThirstBar,
    PlayerBar:pStaminaBar,
    bool:pLoggedIn,
    bool:pSpawned,
    bool:pIsSprinting
};

new PlayerInfo[MAX_PLAYERS][E_PLAYER_DATA];

// Admin Room Configuration
#define ADMIN_ROOM_X          2229.6216
#define ADMIN_ROOM_Y          -1721.6531
#define ADMIN_ROOM_Z          13.5625
#define ADMIN_ROOM_INT        5       // Ganton Gym Interior
#define ADMIN_ROOM_VW         9999    // Virtual World khusus admin
#define ADMIN_ROOM_ANGLE      180.0

// Admin Room Exit Point (di pojok ruangan)
#define ADMIN_EXIT_X          2287.6216  // Pojok ruangan
#define ADMIN_EXIT_Y          -1721.6531
#define ADMIN_EXIT_Z          13.5625
#define ADMIN_EXIT_ANGLE      90.0

// HUD Configuration
#define MAX_HUNGER          100
#define MAX_THIRST          100
#define HUNGER_RATE         2.0  // Berkurang 2% per 2 jam normal
#define THIRST_RATE         3.0  // Berkurang 3% per 1.5 jam normal
#define SPRINT_HUNGER_MULTI 2.0  // 2x lebih cepat saat sprint
#define SPRINT_THIRST_MULTI 3.0  // 3x lebih cepat saat sprint
#define HUNGER_ANIMATION_THRESHOLD 20.0 // Mulai animasi saat hunger/thirst dibawah 20%
#define MAX_STAMINA         100.0
#define STAMINA_REGEN_RATE 2.0    // Regenerasi stamina per detik saat istirahat
#define STAMINA_DRAIN_RATE 5.0    // Berkurang berapa per detik saat sprint
#define MIN_STAMINA_TO_SPRINT 10.0 // Minimal stamina untuk bisa sprint

main() {
    print("\n----------------------------------");
    print(" Dalemon Roleplay Started\n");
    print("----------------------------------\n");
}

public OnGameModeInit()
{
    print("Gamemode started!");
    SetGameModeText("Dalemon Roleplay");
    
    // Connect to MySQL
    printf("[DEBUG] Connecting to MySQL... Host: %s, User: %s, DB: %s", MYSQL_HOST, MYSQL_USER, MYSQL_DATABASE);
    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE);
    if(mysql_errno() != 0)
    {
        printf("[ERROR] Could not connect to MySQL database! Error code: %d", mysql_errno());
        SendRconCommand("exit");
        return 1;
    }
    print("Successfully connected to MySQL database!");
    
    // Create admin room exit pickup (only visible in VW 9999)
    CreatePickup(1318, 1, ADMIN_EXIT_X, ADMIN_EXIT_Y, ADMIN_EXIT_Z, ADMIN_ROOM_VW);
    Create3DTextLabel("Keluar dari Admin Room\n{FFFFFF}/exitadmin", 0xFF0000FF, ADMIN_EXIT_X, ADMIN_EXIT_Y, ADMIN_EXIT_Z, 15.0, ADMIN_ROOM_VW);
    
    // Create tables if not exists
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS players (\
        id INT(11) NOT NULL AUTO_INCREMENT,\
        username VARCHAR(24) NOT NULL,\
        password VARCHAR(65) NOT NULL,\
        admin_level INT(11) DEFAULT 0,\
        register_date DATETIME DEFAULT CURRENT_TIMESTAMP,\
        last_login DATETIME DEFAULT CURRENT_TIMESTAMP,\
        PRIMARY KEY (id),\
        UNIQUE KEY username (username)\
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
    
    AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
    
    // Timer untuk update stats (setiap 5 detik)
    SetTimer("UpdatePlayerStatus", 5000, true);
    return 1;
}

public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    // Reset player data
    ResetPlayerData(playerid);
    
    // Get player name
    GetPlayerName(playerid, PlayerInfo[playerid][pName], MAX_PLAYER_NAME);
    
    // Show login dialog
    ShowLoginDialog(playerid);
    
    // Create progress bars with icons
    PlayerInfo[playerid][pHealthBar] = CreatePlayerProgressBar(playerid, 548.0, 385.0, 89.0, 8.0, 0xFF0000FF, 100.0, BAR_DIRECTION_RIGHT);
    PlayerInfo[playerid][pHungerBar] = CreatePlayerProgressBar(playerid, 548.0, 400.0, 89.0, 8.0, 0xFFFF00FF, 100.0, BAR_DIRECTION_RIGHT);
    PlayerInfo[playerid][pThirstBar] = CreatePlayerProgressBar(playerid, 548.0, 415.0, 89.0, 8.0, 0x0000FFFF, 100.0, BAR_DIRECTION_RIGHT);
    PlayerInfo[playerid][pStaminaBar] = CreatePlayerProgressBar(playerid, 548.0, 430.0, 89.0, 8.0, 0x00FF00FF, 100.0, BAR_DIRECTION_RIGHT);
    
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    // Destroy progress bars
    DestroyPlayerProgressBar(playerid, PlayerInfo[playerid][pHealthBar]);
    DestroyPlayerProgressBar(playerid, PlayerInfo[playerid][pHungerBar]);
    DestroyPlayerProgressBar(playerid, PlayerInfo[playerid][pThirstBar]);
    DestroyPlayerProgressBar(playerid, PlayerInfo[playerid][pStaminaBar]);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(PlayerInfo[playerid][pLoggedIn])
    {
        // Reset player stats on spawn
        PlayerInfo[playerid][pHunger] = 100.0;
        PlayerInfo[playerid][pThirst] = 100.0;
        PlayerInfo[playerid][pStamina] = 100.0;
        SetPlayerHealth(playerid, 100.0);
        
        // Show progress bars
        ShowPlayerProgressBar(playerid, PlayerInfo[playerid][pHealthBar]);
        ShowPlayerProgressBar(playerid, PlayerInfo[playerid][pHungerBar]);
        ShowPlayerProgressBar(playerid, PlayerInfo[playerid][pThirstBar]);
        ShowPlayerProgressBar(playerid, PlayerInfo[playerid][pStaminaBar]);
        
        // Set initial values
        PlayerInfo[playerid][pSpawned] = true;
        PlayerInfo[playerid][pIsSprinting] = false;
        
        // Set spawn position
        if(PlayerInfo[playerid][pAdmin] >= ADMIN) // Semua admin level 2+ spawn di adminroom
        {
            // Admin & Developer spawn in admin room
            SetPlayerPos(playerid, ADMIN_ROOM_X, ADMIN_ROOM_Y, ADMIN_ROOM_Z);
            SetPlayerFacingAngle(playerid, ADMIN_ROOM_ANGLE);
            SetPlayerInterior(playerid, ADMIN_ROOM_INT);
            SetPlayerVirtualWorld(playerid, ADMIN_ROOM_VW);
            SendClientMessage(playerid, COLOR_GREEN, "* Anda spawn di ruang admin khusus.");
        }
        else
        {
            // Regular player spawn
            SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
            SetPlayerFacingAngle(playerid, 269.1425);
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
        }
        
        SetCameraBehindPlayer(playerid);
    }
    return 1;
}

// Timer untuk update status player
forward UpdatePlayerStatus(playerid);
public UpdatePlayerStatus(playerid)
{
    if(!IsPlayerConnected(playerid) || !PlayerInfo[playerid][pSpawned])
        return 0;
        
    // Update health bar
    new Float:health;
    GetPlayerHealth(playerid, health);
    SetPlayerProgressBarValue(playerid, PlayerInfo[playerid][pHealthBar], health);
    
    // Update hunger
    if(PlayerInfo[playerid][pIsSprinting])
        PlayerInfo[playerid][pHunger] -= 0.3; // Berkurang lebih cepat saat sprint
    else
        PlayerInfo[playerid][pHunger] -= 0.2; // Normal
        
    if(PlayerInfo[playerid][pHunger] < 0.0) PlayerInfo[playerid][pHunger] = 0.0;
    SetPlayerProgressBarValue(playerid, PlayerInfo[playerid][pHungerBar], PlayerInfo[playerid][pHunger]);
    
    // Update thirst
    if(PlayerInfo[playerid][pIsSprinting])
        PlayerInfo[playerid][pThirst] -= 0.4; // Berkurang lebih cepat saat sprint
    else
        PlayerInfo[playerid][pThirst] -= 0.3; // Normal
        
    if(PlayerInfo[playerid][pThirst] < 0.0) PlayerInfo[playerid][pThirst] = 0.0;
    SetPlayerProgressBarValue(playerid, PlayerInfo[playerid][pThirstBar], PlayerInfo[playerid][pThirst]);
    
    // Update stamina
    if(PlayerInfo[playerid][pIsSprinting])
    {
        PlayerInfo[playerid][pStamina] -= 1.0;
        if(PlayerInfo[playerid][pStamina] < 0.0)
        {
            PlayerInfo[playerid][pStamina] = 0.0;
            PlayerInfo[playerid][pIsSprinting] = false; // Stop sprint if stamina empty
        }
    }
    else if(PlayerInfo[playerid][pStamina] < 100.0)
    {
        PlayerInfo[playerid][pStamina] += 0.5;
        if(PlayerInfo[playerid][pStamina] > 100.0) PlayerInfo[playerid][pStamina] = 100.0;
    }
    SetPlayerProgressBarValue(playerid, PlayerInfo[playerid][pStaminaBar], PlayerInfo[playerid][pStamina]);
    
    // Reduce health if hunger/thirst too low
    if(PlayerInfo[playerid][pHunger] < 20.0 || PlayerInfo[playerid][pThirst] < 20.0)
    {
        new Float:damage = 3.0;
        SetPlayerHealth(playerid, health - damage);
    }
    
    return 1;
}

ShowLoginDialog(playerid)
{
    new string[128];
    format(string, sizeof(string), "Selamat datang di Dalemon Roleplay!\n\nSilakan masukkan password untuk akun {FF0000}%s", PlayerInfo[playerid][pName]);
    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Keluar");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_LOGIN:
        {
            if(!response) return Kick(playerid);
            
            // TODO: Add password check here
            PlayerInfo[playerid][pLoggedIn] = true;
            SpawnPlayer(playerid);
            SendClientMessage(playerid, -1, "Anda berhasil login!");
            return 1;
        }
    }
    return 0;
}

ResetPlayerData(playerid)
{
    PlayerInfo[playerid][pID] = 0;
    PlayerInfo[playerid][pAdmin] = 0;
    PlayerInfo[playerid][pMoney] = 0;
    PlayerInfo[playerid][pScore] = 0;
    PlayerInfo[playerid][pHealth] = 100.0;
    PlayerInfo[playerid][pArmour] = 0.0;
    PlayerInfo[playerid][pHunger] = 100.0;
    PlayerInfo[playerid][pThirst] = 100.0;
    PlayerInfo[playerid][pStamina] = 100.0;
    PlayerInfo[playerid][pLoggedIn] = false;
    PlayerInfo[playerid][pSpawned] = false;
    PlayerInfo[playerid][pIsSprinting] = false;
    return 1;
}
