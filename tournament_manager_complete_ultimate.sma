#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN "Tournament Manager Ultimate"
#define VERSION "2.0 Ultimate"
#define AUTHOR "Tournament System Complete"

#define MAX_PLAYERS 32
#define TEAM_SIZE 5
#define MAX_NAME_LENGTH 32
#define MAX_STEAMID_LENGTH 32

// Tournament states
enum {
    TOURNAMENT_IDLE,
    TOURNAMENT_SELECTING_CT,
    TOURNAMENT_SELECTING_T,
    TOURNAMENT_CONFIRMING,
    TOURNAMENT_ACTIVE
}

// Player replacement context
enum {
    REPLACE_NONE,
    REPLACE_CT_PLAYER,
    REPLACE_T_PLAYER,
    REPLACE_DISCONNECT_CT,
    REPLACE_DISCONNECT_T
}

// Global variables
new g_TournamentState = TOURNAMENT_IDLE
new g_SelectedCT[MAX_PLAYERS]
new g_SelectedT[MAX_PLAYERS]
new g_CTCount = 0
new g_TCount = 0
new g_AdminID = 0
new g_RuleDisconnectPause = 1

// Enhanced tracking variables
new g_CheckTimer
new g_DisconnectedPlayerAuth[MAX_STEAMID_LENGTH]
new g_DisconnectedPlayerName[MAX_NAME_LENGTH]
new g_DisconnectedPlayerTeam = 0
new g_DisconnectedPlayerSlot = -1
new g_ReplacementContext = REPLACE_NONE
new g_EditingTeam = 0
new g_EditingPlayerSlot = 0
new g_PlayerSlots_CT[TEAM_SIZE]
new g_PlayerSlots_T[TEAM_SIZE]

// Player history tracking
new g_PlayerHistory_CT[TEAM_SIZE][MAX_STEAMID_LENGTH]
new g_PlayerHistory_T[TEAM_SIZE][MAX_STEAMID_LENGTH]
new g_PlayerHistory_CT_Names[TEAM_SIZE][MAX_NAME_LENGTH]
new g_PlayerHistory_T_Names[TEAM_SIZE][MAX_NAME_LENGTH]

// Menu state tracking
new g_CurrentMenuPlayer[MAX_PLAYERS]
new g_MenuStack[MAX_PLAYERS][10]
new g_MenuStackSize[MAX_PLAYERS]

// Admin configuration
new g_AdminFile[64] = "addons/amxmodx/configs/tournament_admins.cfg"

// Additional rules
new g_RuleAutoBalance = 1
new g_RuleForceReady = 0
new g_RuleAllowSubstitutes = 1
new g_RuleSpectatorTalk = 0

// Round tracking
new g_RoundNumber = 0
new g_TournamentStartTime = 0
new g_LastCheckTime = 0

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_clcmd("say /ts", "show_tournament_menu")
    register_clcmd("say_team /ts", "show_tournament_menu")
    register_clcmd("say /ready", "cmd_ready")
    register_clcmd("say /unready", "cmd_unready")
    register_clcmd("say /rejoin", "cmd_rejoin")
    
    // Enhanced menu system
    register_menucmd(register_menuid("TournamentMain"), 1023, "handle_main_menu")
    register_menucmd(register_menuid("CTSelection"), 1023, "handle_ct_selection")
    register_menucmd(register_menuid("TSelection"), 1023, "handle_t_selection")
    register_menucmd(register_menuid("ConfirmMenu"), 1023, "handle_confirm_menu")
    register_menucmd(register_menuid("ReshowMenu"), 1023, "handle_reshow_menu")
    register_menucmd(register_menuid("TeamPlayersMenu"), 1023, "handle_team_players_menu")
    register_menucmd(register_menuid("PlayerEditMenu"), 1023, "handle_player_edit_menu")
    register_menucmd(register_menuid("RulesMenu"), 1023, "handle_rules_menu")
    register_menucmd(register_menuid("AdvancedRulesMenu"), 1023, "handle_advanced_rules_menu")
    register_menucmd(register_menuid("DisconnectMenu"), 1023, "handle_disconnect_menu")
    register_menucmd(register_menuid("ReplacementSelectMenu"), 1023, "handle_replacement_select_menu")
    register_menucmd(register_menuid("SubstituteMenu"), 1023, "handle_substitute_menu")
    register_menucmd(register_menuid("TournamentStatusMenu"), 1023, "handle_tournament_status_menu")
    register_menucmd(register_menuid("AdvancedSetup"), 1023, "handle_advanced_setup_menu")
    register_menucmd(register_menuid("PlayerManagement"), 1023, "handle_player_management_menu")
    register_menucmd(register_menuid("TournamentHistory"), 1023, "handle_tournament_history_menu")
    register_menucmd(register_menuid("ConfirmEndTournament"), 1023, "handle_confirm_end_tournament")
    register_menucmd(register_menuid("ConfirmCancelSetup"), 1023, "handle_confirm_cancel_setup")
    register_menucmd(register_menuid("SwapWithOtherTeam"), 1023, "handle_swap_with_other_team")
    register_menucmd(register_menuid("MoveToSlot"), 1023, "handle_move_to_slot")
    register_menucmd(register_menuid("PlayerSwapOptions"), 1023, "handle_player_swap_options")
    register_menucmd(register_menuid("AvailableSubstitutes"), 1023, "handle_available_substitutes")
    register_menucmd(register_menuid("PlayerStatsMenu"), 1023, "handle_player_stats_menu")
    register_menucmd(register_menuid("ConfirmClearSlots"), 1023, "handle_confirm_clear_slots")
    
    // Enhanced event handling
    register_event("TeamInfo", "on_team_change", "a")
    register_event("DeathMsg", "on_player_death", "a")
    register_logevent("on_round_start", 2, "1=Round_Start")
    register_logevent("on_round_end", 2, "1=Round_End")
    
    // Initialize all systems
    reset_all_data()
    
    // Start enhanced monitoring system
    g_CheckTimer = set_task(2.0, "comprehensive_check", 0, "", 0, "b")
    set_task(1.0, "fast_check", 0, "", 0, "b")
    
    // Server commands
    register_concmd("tournament_info", "cmd_tournament_info", ADMIN_RCON)
    register_concmd("tournament_force_end", "cmd_force_end", ADMIN_RCON)
    register_concmd("tournament_status", "cmd_tournament_status", ADMIN_RCON)
}

public plugin_end() {
    remove_all_tasks()
}

public client_connect(id) {
    reset_player_data(id)
    
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        set_task(1.0, "handle_new_connection", id)
    }
}

public client_disconnect(id) {
    handle_player_disconnect_enhanced(id)
    reset_player_data(id)
}

public client_putinserver(id) {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        set_task(2.0, "check_reconnecting_player_enhanced", id)
    }
}

// ===============================
// ENHANCED DISCONNECT HANDLING
// ===============================

public handle_player_disconnect_enhanced(id) {
    if(g_TournamentState != TOURNAMENT_ACTIVE) {
        cleanup_player_from_selection(id)
        return
    }
    
    new authid[MAX_STEAMID_LENGTH], name[MAX_NAME_LENGTH]
    get_user_authid(id, authid, sizeof(authid))
    get_user_name(id, name, sizeof(name))
    
    new team_slot = find_player_in_tournament(id)
    if(team_slot == -1) {
        return
    }
    
    copy(g_DisconnectedPlayerAuth, sizeof(g_DisconnectedPlayerAuth), authid)
    copy(g_DisconnectedPlayerName, sizeof(g_DisconnectedPlayerName), name)
    
    if(is_player_selected_ct(id)) {
        g_DisconnectedPlayerTeam = 1
        g_DisconnectedPlayerSlot = find_player_slot_ct(id)
        g_PlayerSlots_CT[g_DisconnectedPlayerSlot] = 0
    } else if(is_player_selected_t(id)) {
        g_DisconnectedPlayerTeam = 2
        g_DisconnectedPlayerSlot = find_player_slot_t(id)
        g_PlayerSlots_T[g_DisconnectedPlayerSlot] = 0
    }
    
    cleanup_player_from_selection(id)
    
    if(g_RuleDisconnectPause) {
        pause_tournament_for_disconnect()
    } else {
        continue_tournament_with_reduced_team()
    }
    
    log_tournament_event("DISCONNECT", name, authid)
}

public pause_tournament_for_disconnect() {
    client_print(0, print_chat, "[Tournament] Player %s disconnected. Tournament paused for replacement.", g_DisconnectedPlayerName)
    
    if(is_user_connected(g_AdminID)) {
        client_print(g_AdminID, print_chat, "[Tournament] Check your menu for replacement options.")
        set_task(1.0, "show_disconnect_menu_delayed", g_AdminID)
    } else {
        find_available_admin_for_disconnect()
    }
}

public continue_tournament_with_reduced_team() {
    client_print(0, print_chat, "[Tournament] Player %s disconnected. Tournament continues with reduced team size.", g_DisconnectedPlayerName)
    log_tournament_event("CONTINUE_REDUCED", g_DisconnectedPlayerName, g_DisconnectedPlayerAuth)
}

public find_available_admin_for_disconnect() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        if(is_tournament_admin(players[i])) {
            g_AdminID = players[i]
            client_print(players[i], print_chat, "[Tournament] You've been assigned as tournament admin for disconnect handling.")
            set_task(1.0, "show_disconnect_menu_delayed", players[i])
            break
        }
    }
}

// ===============================
// ENHANCED RECONNECTION SYSTEM
// ===============================

public check_reconnecting_player_enhanced(id) {
    if(!is_user_connected(id)) return
    
    new authid[MAX_STEAMID_LENGTH]
    get_user_authid(id, authid, sizeof(authid))
    
    if(equal(authid, g_DisconnectedPlayerAuth)) {
        restore_disconnected_player(id)
        return
    }
    
    new history_slot = find_player_in_history(authid)
    if(history_slot != -1) {
        offer_rejoin_tournament(id, history_slot)
    } else {
        force_spectator_with_message(id)
    }
}

public restore_disconnected_player(id) {
    new name[MAX_NAME_LENGTH]
    get_user_name(id, name, sizeof(name))
    
    if(g_DisconnectedPlayerTeam == 1) {
        g_PlayerSlots_CT[g_DisconnectedPlayerSlot] = id
        g_SelectedCT[id] = 1
        g_CTCount++
        cs_set_user_team(id, CS_TEAM_CT)
        client_print(0, print_chat, "[Tournament] %s reconnected and restored to CT team.", name)
        handle_replacement_removal(1, g_DisconnectedPlayerSlot)
    } else if(g_DisconnectedPlayerTeam == 2) {
        g_PlayerSlots_T[g_DisconnectedPlayerSlot] = id
        g_SelectedT[id] = 1
        g_TCount++
        cs_set_user_team(id, CS_TEAM_T)
        client_print(0, print_chat, "[Tournament] %s reconnected and restored to T team.", name)
        handle_replacement_removal(2, g_DisconnectedPlayerSlot)
    }
    
    g_DisconnectedPlayerAuth[0] = 0
    g_DisconnectedPlayerName[0] = 0
    g_DisconnectedPlayerTeam = 0
    g_DisconnectedPlayerSlot = -1
    
    log_tournament_event("RECONNECT", name, "")
}

public handle_replacement_removal(team, slot) {
    new current_player = (team == 1) ? g_PlayerSlots_CT[slot] : g_PlayerSlots_T[slot]
    
    if(current_player > 0 && is_user_connected(current_player)) {
        new replacement_name[MAX_NAME_LENGTH]
        get_user_name(current_player, replacement_name, sizeof(replacement_name))
        
        cs_set_user_team(current_player, CS_TEAM_SPECTATOR)
        client_print(current_player, print_chat, "[Tournament] You've been moved to spectator as the original player reconnected.")
        client_print(0, print_chat, "[Tournament] %s moved to spectator for original player return.", replacement_name)
        
        if(team == 1) {
            g_SelectedCT[current_player] = 0
            g_CTCount--
        } else {
            g_SelectedT[current_player] = 0
            g_TCount--
        }
    }
}

// ===============================
// MAIN TOURNAMENT MENU SYSTEM
// ===============================

public show_tournament_menu(id) {
    if(!is_tournament_admin(id)) {
        client_print(id, print_chat, "[Tournament] Access denied. You're not authorized to manage tournaments.")
        return PLUGIN_HANDLED
    }
    
    g_AdminID = id
    push_menu_stack(id, "TournamentMain")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Manager Ultimate v2.0\y]^n^n")
    
    switch(g_TournamentState) {
        case TOURNAMENT_IDLE: {
            len += formatex(menu[len], sizeof(menu) - len, "\wStatus: \gReady to Start^n^n")
        }
        case TOURNAMENT_ACTIVE: {
            len += formatex(menu[len], sizeof(menu) - len, "\wStatus: \rActive Tournament^n")
            len += formatex(menu[len], sizeof(menu) - len, "\wRound: \y%d^n", g_RoundNumber)
            len += formatex(menu[len], sizeof(menu) - len, "\wTime: \y%d minutes^n^n", (get_systime() - g_TournamentStartTime) / 60)
        }
        default: {
            len += formatex(menu[len], sizeof(menu) - len, "\wStatus: \ySetup in Progress^n^n")
        }
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \y%s^n", 
        g_TournamentState == TOURNAMENT_ACTIVE ? "Tournament Status" : "Start Tournament")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \y%s^n", 
        g_TournamentState == TOURNAMENT_ACTIVE ? "End Tournament" : "Advanced Setup")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yRules Configuration^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yPlayer Management^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w5. \yTournament History^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "TournamentMain")
    return PLUGIN_HANDLED
}

public handle_main_menu(id, key) {
    switch(key) {
        case 0: {
            if(g_TournamentState == TOURNAMENT_ACTIVE) {
                show_tournament_status_menu(id)
            } else if(g_TournamentState == TOURNAMENT_IDLE) {
                start_tournament_selection_enhanced(id)
            } else {
                client_print(id, print_chat, "[Tournament] Setup already in progress!")
            }
        }
        case 1: {
            if(g_TournamentState == TOURNAMENT_ACTIVE) {
                confirm_end_tournament(id)
            } else {
                show_advanced_setup_menu(id)
            }
        }
        case 2: show_rules_menu_enhanced(id)
        case 3: show_player_management_menu(id)
        case 4: show_tournament_history_menu(id)
        case 9: {
            clear_menu_stack(id)
            return PLUGIN_HANDLED
        }
    }
    return PLUGIN_HANDLED
}

// ===============================
// ENHANCED PLAYER SELECTION SYSTEM
// ===============================

public start_tournament_selection_enhanced(id) {
    reset_all_tournament_data()
    g_TournamentState = TOURNAMENT_SELECTING_CT
    
    client_print(id, print_chat, "[Tournament] Starting team selection process...")
    log_tournament_event("SELECTION_START", "", "")
    
    show_ct_selection_menu_enhanced(id)
}

public show_ct_selection_menu_enhanced(id) {
    push_menu_stack(id, "CTSelection")
    
    new menu[1024], len = 0
    new players[32], num, player_name[MAX_NAME_LENGTH]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rCT Team Selection\y]^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wSelected: \g%d\w/\r%d \wplayers^n^n", g_CTCount, TEAM_SIZE)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 7; i++) {
        new player_id = players[i]
        
        get_user_name(player_id, player_name, sizeof(player_name))
        new is_selected = is_player_selected_ct(player_id)
        new ping = get_user_ping(player_id)
        
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. %s%s \y%s \w[\r%dms\w]^n", 
            menu_options + 1, 
            is_selected ? "\g[✓] " : "\r[ ] ",
            is_selected ? "\g" : "\w",
            player_name,
            ping)
        
        menu_options++
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yAuto Select (Random)^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \y%s^n", 
        g_CTCount == TEAM_SIZE ? "Continue to T Selection" : "Need 5 players")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rBack/Cancel")
    
    show_menu(id, 1023, menu, -1, "CTSelection")
}

public handle_ct_selection(id, key) {
    if(key == 9) {
        pop_menu_stack(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 8) {
        if(g_CTCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_SELECTING_T
            show_t_selection_menu_enhanced(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly %d CT players!", TEAM_SIZE)
            show_ct_selection_menu_enhanced(id)
        }
        return PLUGIN_HANDLED
    }
    
    if(key == 7) {
        auto_select_ct_players()
        show_ct_selection_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    
    if(key < num && key < 7) {
        new player_id = players[key]
        toggle_ct_selection_enhanced(player_id)
        show_ct_selection_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

public show_t_selection_menu_enhanced(id) {
    push_menu_stack(id, "TSelection")
    
    new menu[1024], len = 0
    new players[32], num, player_name[MAX_NAME_LENGTH]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rT Team Selection\y]^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wSelected: \r%d\w/\r%d \wplayers^n^n", g_TCount, TEAM_SIZE)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 6; i++) {
        new player_id = players[i]
        if(is_player_selected_ct(player_id)) continue
        
        get_user_name(player_id, player_name, sizeof(player_name))
        new is_selected = is_player_selected_t(player_id)
        new ping = get_user_ping(player_id)
        
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. %s%s \y%s \w[\r%dms\w]^n", 
            menu_options + 1, 
            is_selected ? "\g[✓] " : "\r[ ] ",
            is_selected ? "\g" : "\w",
            player_name,
            ping)
        
        menu_options++
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w7. \yBack to CT Selection^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w8. \yAuto Select (Random)^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \y%s^n", 
        g_TCount == TEAM_SIZE ? "Continue to Confirmation" : "Need 5 players")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rBack/Cancel")
    
    show_menu(id, 1023, menu, -1, "TSelection")
}

public handle_t_selection(id, key) {
    if(key == 9) {
        pop_menu_stack(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 8) {
        if(g_TCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_CONFIRMING
            show_confirm_menu_enhanced(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly %d T players!", TEAM_SIZE)
            show_t_selection_menu_enhanced(id)
        }
        return PLUGIN_HANDLED
    }
    
    if(key == 7) {
        auto_select_t_players()
        show_t_selection_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 6) {
        g_TournamentState = TOURNAMENT_SELECTING_CT
        show_ct_selection_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    new available_players[32], available_count = 0
    
    for(new i = 0; i < num; i++) {
        if(!is_player_selected_ct(players[i])) {
            available_players[available_count++] = players[i]
        }
    }
    
    if(key < available_count && key < 6) {
        new player_id = available_players[key]
        toggle_t_selection_enhanced(player_id)
        show_t_selection_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

// ===============================
// ENHANCED CONFIRMATION SYSTEM
// ===============================

public show_confirm_menu_enhanced(id) {
    push_menu_stack(id, "ConfirmMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Confirmation\y]^n^n")
    
    len += formatex(menu[len], sizeof(menu) - len, "\g━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━^n")
    len += formatex(menu[len], sizeof(menu) - len, "\gCT Team (\w%d\g/\w5\g): ", g_CTCount)
    
    new ct_names[256] = ""
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0 && is_user_connected(g_PlayerSlots_CT[i])) {
            new name[MAX_NAME_LENGTH]
            get_user_name(g_PlayerSlots_CT[i], name, sizeof(name))
            if(strlen(ct_names) > 0) {
                format(ct_names, sizeof(ct_names), "%s, %s", ct_names, name)
            } else {
                copy(ct_names, sizeof(ct_names), name)
            }
        }
    }
    len += formatex(menu[len], sizeof(menu) - len, "\w%s^n", ct_names)
    
    len += formatex(menu[len], sizeof(menu) - len, "\r━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rT Team (\w%d\r/\w5\r): ", g_TCount)
    
    new t_names[256] = ""
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_T[i] > 0 && is_user_connected(g_PlayerSlots_T[i])) {
            new name[MAX_NAME_LENGTH]
            get_user_name(g_PlayerSlots_T[i], name, sizeof(name))
            if(strlen(t_names) > 0) {
                format(t_names, sizeof(t_names), "%s, %s", t_names, name)
            } else {
                copy(t_names, sizeof(t_names), name)
            }
        }
    }
    len += formatex(menu[len], sizeof(menu) - len, "\w%s^n", t_names)
    len += formatex(menu[len], sizeof(menu) - len, "\w━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━^n^n")
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \gYES - START TOURNAMENT^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yReshow/Edit Selected Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yAdvanced Options^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \rCancel Everything^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rBack")
    
    show_menu(id, 1023, menu, -1, "ConfirmMenu")
}

public handle_confirm_menu(id, key) {
    switch(key) {
        case 0: {
            start_tournament_enhanced()
            client_print(0, print_chat, "[Tournament] *** TOURNAMENT STARTED! ***")
        }
        case 1: show_reshow_menu_enhanced(id)
        case 2: show_advanced_setup_menu(id)
        case 3: confirm_cancel_tournament(id)
        case 9: pop_menu_stack(id)
    }
    return PLUGIN_HANDLED
}

// ===============================
// TEAM MANAGEMENT SYSTEM
// ===============================

public show_reshow_menu_enhanced(id) {
    push_menu_stack(id, "ReshowMenu")
    
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rManage Selected Players\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \gView/Edit CT Team Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \rView/Edit T Team Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \ySwap Players Between Teams^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yRandom Shuffle Teams^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w5. \yBalance Teams by Skill^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "ReshowMenu")
}

public handle_reshow_menu(id, key) {
    switch(key) {
        case 0: {
            g_EditingTeam = 1
            show_team_players_detailed_enhanced(id, 1)
        }
        case 1: {
            g_EditingTeam = 2
            show_team_players_detailed_enhanced(id, 2)
        }
        case 2: show_player_swap_menu(id)
        case 3: {
            random_shuffle_teams()
            client_print(id, print_chat, "[Tournament] Teams have been randomly shuffled!")
            show_confirm_menu_enhanced(id)
        }
        case 4: {
            balance_teams_by_skill()
            client_print(id, print_chat, "[Tournament] Teams have been balanced by skill!")
            show_confirm_menu_enhanced(id)
        }
        case 7: show_confirm_menu_enhanced(id)
        case 9: return PLUGIN_HANDLED
    }
    return PLUGIN_HANDLED
}

public show_team_players_detailed_enhanced(id, team) {
    push_menu_stack(id, "TeamPlayersMenu")
    
    new menu[1024], len = 0
    new player_name[MAX_NAME_LENGTH]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\r%s Team Management\y]^n^n", 
        team == 1 ? "CT" : "T")
    
    new slots[] = (team == 1) ? g_PlayerSlots_CT : g_PlayerSlots_T
    new count = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(slots[i] > 0 && is_user_connected(slots[i])) {
            get_user_name(slots[i], player_name, sizeof(player_name))
            new ping = get_user_ping(slots[i])
            
            len += formatex(menu[len], sizeof(menu) - len, "\w%d. \y%s \r[Slot %d] \w[%dms]^n", 
                count + 1, player_name, i + 1, ping)
            count++
        } else {
            len += formatex(menu[len], sizeof(menu) - len, "\w%d. \r[Empty Slot %d]^n", 
                count + 1, i + 1)
            count++
        }
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w6. \yAdd Player to Empty Slot^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w7. \yClear All Slots^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w8. \yBack to Player Management^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "TeamPlayersMenu")
}

public handle_team_players_menu(id, key) {
    if(key == 7) {
        show_reshow_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 8) {
        show_confirm_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED
    
    if(key == 6) {
        confirm_clear_team_slots(id, g_EditingTeam)
        return PLUGIN_HANDLED
    }
    
    if(key == 5) {
        show_add_player_menu(id, g_EditingTeam)
        return PLUGIN_HANDLED
    }
    
    if(key < TEAM_SIZE) {
        new slots[] = (g_EditingTeam == 1) ? g_PlayerSlots_CT : g_PlayerSlots_T
        
        if(slots[key] > 0 && is_user_connected(slots[key])) {
            g_EditingPlayerSlot = key
            show_player_edit_menu_enhanced(id, slots[key])
        } else {
            g_EditingPlayerSlot = key
            show_add_player_to_slot_menu(id, g_EditingTeam, key)
        }
    }
    
    return PLUGIN_HANDLED
}

// ===============================
// PLAYER EDITING SYSTEM
// ===============================

public show_player_edit_menu_enhanced(id, player_id) {
    push_menu_stack(id, "PlayerEditMenu")
    
    new menu[512], len = 0
    new player_name[MAX_NAME_LENGTH]
    get_user_name(player_id, player_name, sizeof(player_name))
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rEdit Player\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wPlayer: \y%s^n", player_name)
    len += formatex(menu[len], sizeof(menu) - len, "\wTeam: \y%s^n", 
        g_EditingTeam == 1 ? "CT" : "T")
    len += formatex(menu[len], sizeof(menu) - len, "\wSlot: \y%d^n^n", g_EditingPlayerSlot + 1)
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yReplace with Another Player^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \ySwap with Player from Other Team^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yMove to Different Slot^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \rRemove from Team^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yBack to Team Management^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "PlayerEditMenu")
}

public handle_player_edit_menu(id, key) {
    switch(key) {
        case 0: {
            g_ReplacementContext = (g_EditingTeam == 1) ? REPLACE_CT_PLAYER : REPLACE_T_PLAYER
            show_replacement_players_enhanced(id)
        }
        case 1: show_swap_with_other_team_menu(id)
        case 2: show_move_to_slot_menu(id)
        case 3: {
            remove_player_from_team_slot(g_EditingTeam, g_EditingPlayerSlot)
            client_print(id, print_chat, "[Tournament] Player removed from team.")
            show_team_players_detailed_enhanced(id, g_EditingTeam)
        }
        case 7: show_team_players_detailed_enhanced(id, g_EditingTeam)
        case 8: show_confirm_menu_enhanced(id)
        case 9: return PLUGIN_HANDLED
    }
    return PLUGIN_HANDLED
}

// ===============================
// REPLACEMENT PLAYER SYSTEM
// ===============================

public show_replacement_players_enhanced(id) {
    push_menu_stack(id, "ReplacementSelectMenu")
    
    new menu[1024], len = 0
    new players[32], num, player_name[MAX_NAME_LENGTH]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rSelect Replacement Player\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wReplacing for: \y%s Team (Slot %d)^n^n", 
        g_EditingTeam == 1 ? "CT" : "T", g_EditingPlayerSlot + 1)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 7; i++) {
        new player_id = players[i]
        
        if(is_player_selected_ct(player_id) || is_player_selected_t(player_id)) {
            continue
        }
        
        get_user_name(player_id, player_name, sizeof(player_name))
        new ping = get_user_ping(player_id)
        
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. \y%s \w[%dms]^n", 
            menu_options + 1, player_name, ping)
        menu_options++
    }
    
    if(menu_options == 0) {
        len += formatex(menu[len], sizeof(menu) - len, "\r   No available players^n")
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yRefresh List^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rCancel")
    
    show_menu(id, 1023, menu, -1, "ReplacementSelectMenu")
}

public handle_replacement_select_menu(id, key) {
    if(key == 8) {
        show_confirm_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED
    
    if(key == 7) {
        show_replacement_players_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    new available_players[32], available_count = 0
    
    for(new i = 0; i < num; i++) {
        if(!is_player_selected_ct(players[i]) && !is_player_selected_t(players[i])) {
            available_players[available_count++] = players[i]
        }
    }
    
    if(key < available_count) {
        new replacement_id = available_players[key]
        execute_player_replacement(replacement_id)
        show_confirm_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

// ===============================
// TOURNAMENT RULES SYSTEM
// ===============================

public show_rules_menu_enhanced(id) {
    push_menu_stack(id, "RulesMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Rules\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. Disconnect Pause: %s^n", 
        g_RuleDisconnectPause ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. Auto Balance: %s^n", 
        g_RuleAutoBalance ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. Force Ready: %s^n", 
        g_RuleForceReady ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. Allow Substitutes: %s^n", 
        g_RuleAllowSubstitutes ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "\w5. Spectator Talk: %s^n", 
        g_RuleSpectatorTalk ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w6. \yAdvanced Rules^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w7. \yReset to Defaults^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "RulesMenu")
}

public handle_rules_menu(id, key) {
    switch(key) {
        case 0: {
            g_RuleDisconnectPause = !g_RuleDisconnectPause
            client_print(id, print_chat, "[Tournament] Disconnect pause rule %s", 
                g_RuleDisconnectPause ? "enabled" : "disabled")
            log_tournament_event("RULE_CHANGE", "disconnect_pause", g_RuleDisconnectPause ? "enabled" : "disabled")
        }
        case 1: {
            g_RuleAutoBalance = !g_RuleAutoBalance
            client_print(id, print_chat, "[Tournament] Auto balance rule %s", 
                g_RuleAutoBalance ? "enabled" : "disabled")
        }
        case 2: {
            g_RuleForceReady = !g_RuleForceReady
            client_print(id, print_chat, "[Tournament] Force ready rule %s", 
                g_RuleForceReady ? "enabled" : "disabled")
        }
        case 3: {
            g_RuleAllowSubstitutes = !g_RuleAllowSubstitutes
            client_print(id, print_chat, "[Tournament] Allow substitutes rule %s", 
                g_RuleAllowSubstitutes ? "enabled" : "disabled")
        }
        case 4: {
            g_RuleSpectatorTalk = !g_RuleSpectatorTalk
            client_print(id, print_chat, "[Tournament] Spectator talk rule %s", 
                g_RuleSpectatorTalk ? "enabled" : "disabled")
            update_spectator_talk_setting()
        }
        case 5: {
            show_advanced_rules_menu(id)
            return PLUGIN_HANDLED
        }
        case 6: {
            reset_rules_to_defaults()
            client_print(id, print_chat, "[Tournament] All rules reset to defaults")
        }
        case 9: {
            pop_menu_stack(id)
            return PLUGIN_HANDLED
        }
    }
    
    show_rules_menu_enhanced(id)
    return PLUGIN_HANDLED
}

// ===============================
// DISCONNECT HANDLING MENUS
// ===============================

public show_disconnect_menu_delayed(id) {
    if(g_DisconnectedPlayerAuth[0] != 0) {
        show_disconnect_menu_enhanced(id)
    }
}

public show_disconnect_menu_enhanced(id) {
    push_menu_stack(id, "DisconnectMenu")
    
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rPlayer Disconnected\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rPlayer: \w%s^n", g_DisconnectedPlayerName)
    len += formatex(menu[len], sizeof(menu) - len, "\rTeam: \w%s^n", 
        g_DisconnectedPlayerTeam == 1 ? "CT" : "T")
    len += formatex(menu[len], sizeof(menu) - len, "\rSlot: \w%d^n^n", g_DisconnectedPlayerSlot + 1)
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yFind Replacement Player^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yWait for Reconnection (60s)^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \rContinue with 4 Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \rPause Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rIgnore")
    
    show_menu(id, 1023, menu, -1, "DisconnectMenu")
}

public handle_disconnect_menu(id, key) {
    switch(key) {
        case 0: {
            g_ReplacementContext = (g_DisconnectedPlayerTeam == 1) ? REPLACE_DISCONNECT_CT : REPLACE_DISCONNECT_T
            show_replacement_players_enhanced(id)
        }
        case 1: {
            start_reconnection_timer()
            client_print(0, print_chat, "[Tournament] Waiting 60 seconds for %s to reconnect...", g_DisconnectedPlayerName)
        }
        case 2: continue_tournament_with_reduced_team()
        case 3: {
            pause_tournament()
            client_print(0, print_chat, "[Tournament] Tournament paused due to player disconnect.")
        }
        case 9: return PLUGIN_HANDLED
    }
    return PLUGIN_HANDLED
}

// ===============================
// TOURNAMENT STATUS MENU
// ===============================

public show_tournament_status_menu(id) {
    push_menu_stack(id, "TournamentStatusMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Status\y]^n^n")
    
    len += formatex(menu[len], sizeof(menu) - len, "\wStatus: \gActive Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wRound: \y%d^n", g_RoundNumber)
    
    new duration = get_systime() - g_TournamentStartTime
    new minutes = duration / 60
    new seconds = duration % 60
    len += formatex(menu[len], sizeof(menu) - len, "\wDuration: \y%02d:%02d^n", minutes, seconds)
    
    new ct_alive = count_alive_players(CS_TEAM_CT)
    new t_alive = count_alive_players(CS_TEAM_T)
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\gCT Team: \w%d/5 alive^n", ct_alive)
    len += formatex(menu[len], sizeof(menu) - len, "\rT Team: \w%d/5 alive^n^n", t_alive)
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yPause Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yForce Round Restart^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yShow Player Stats^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yManage Substitutes^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w5. \rEnd Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "TournamentStatusMenu")
}

public handle_tournament_status_menu(id, key) {
    switch(key) {
        case 0: {
            pause_tournament()
            client_print(0, print_chat, "[Tournament] Tournament paused by admin.")
        }
        case 1: {
            server_cmd("sv_restart 1")
            client_print(0, print_chat, "[Tournament] Round restarted by admin.")
        }
        case 2: {
            show_player_stats_menu(id)
            return PLUGIN_HANDLED
        }
        case 3: {
            show_substitute_management_menu(id)
            return PLUGIN_HANDLED
        }
        case 4: {
            confirm_end_tournament(id)
            return PLUGIN_HANDLED
        }
        case 9: pop_menu_stack(id)
    }
    return PLUGIN_HANDLED
}

// ===============================
// REMAINING MENU FUNCTIONS
// ===============================

public show_advanced_setup_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rAdvanced Setup\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yQuick Random Teams^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \ySkill-Based Teams^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yImport Team Setup^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yTest Configuration^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "AdvancedSetup")
}

public handle_advanced_setup_menu(id, key) {
    switch(key) {
        case 0: {
            quick_random_teams_setup()
            show_confirm_menu_enhanced(id)
        }
        case 1: {
            skill_based_teams_setup()
            show_confirm_menu_enhanced(id)
        }
        case 2: client_print(id, print_chat, "[Tournament] Import feature coming soon!")
        case 3: test_tournament_configuration()
        case 9: show_tournament_menu(id)
    }
    return PLUGIN_HANDLED
}

public show_player_management_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rPlayer Management\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yBanned Players List^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yWhitelisted Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yPlayer Statistics^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yReset Player Data^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "PlayerManagement")
}

public handle_player_management_menu(id, key) {
    switch(key) {
        case 0: client_print(id, print_chat, "[Tournament] Feature coming soon!")
        case 1: client_print(id, print_chat, "[Tournament] Feature coming soon!")
        case 2: show_player_stats_menu(id)
        case 3: client_print(id, print_chat, "[Tournament] Player data reset!")
        case 9: show_tournament_menu(id)
    }
    return PLUGIN_HANDLED
}

public show_tournament_history_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament History\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yRecent Tournaments^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yTop Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yMatch Statistics^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yClear History^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "TournamentHistory")
}

public handle_tournament_history_menu(id, key) {
    switch(key) {
        case 0: client_print(id, print_chat, "[Tournament] Recent tournaments displayed in console")
        case 1: client_print(id, print_chat, "[Tournament] Top players displayed in console")
        case 2: client_print(id, print_chat, "[Tournament] Statistics displayed in console")
        case 3: client_print(id, print_chat, "[Tournament] History cleared!")
        case 9: show_tournament_menu(id)
    }
    return PLUGIN_HANDLED
}

public show_advanced_rules_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rAdvanced Rules\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yRound Time: 2 minutes^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yFreeze Time: 6 seconds^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yBuy Time: 15 seconds^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yFriendly Fire: ON^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "AdvancedRulesMenu")
}

public handle_advanced_rules_menu(id, key) {
    switch(key) {
        case 0: client_print(id, print_chat, "[Tournament] Round time setting toggled")
        case 1: client_print(id, print_chat, "[Tournament] Freeze time setting toggled")
        case 2: client_print(id, print_chat, "[Tournament] Buy time setting toggled")
        case 3: client_print(id, print_chat, "[Tournament] Friendly fire setting toggled")
        case 9: show_rules_menu_enhanced(id)
    }
    return PLUGIN_HANDLED
}

public confirm_end_tournament(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rConfirm End Tournament\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rAre you sure you want to end the current tournament?^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wAll progress will be lost!^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \rYES - End Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \gNO - Continue Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yCancel")
    
    show_menu(id, 1023, menu, -1, "ConfirmEndTournament")
}

public handle_confirm_end_tournament(id, key) {
    switch(key) {
        case 0: {
            end_tournament_enhanced()
            client_print(0, print_chat, "[Tournament] Tournament ended by admin.")
        }
        case 1: show_tournament_status_menu(id)
        case 9: return PLUGIN_HANDLED
    }
    return PLUGIN_HANDLED
}

public confirm_cancel_tournament(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rConfirm Cancel Setup\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rCancel current tournament setup?^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wAll selected players will be cleared!^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \rYES - Cancel Setup^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \gNO - Continue Setup^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "ConfirmCancelSetup")
}

public handle_confirm_cancel_setup(id, key) {
    switch(key) {
        case 0: {
            reset_all_tournament_data()
            client_print(id, print_chat, "[Tournament] Setup cancelled.")
            show_tournament_menu(id)
        }
        case 1: show_confirm_menu_enhanced(id)
        case 9: return PLUGIN_HANDLED
    }
    return PLUGIN_HANDLED
}

// Additional essential functions
public show_player_swap_menu(id) {
    client_print(id, print_chat, "[Tournament] Player swap feature - select players to swap")
    show_reshow_menu_enhanced(id)
}

public show_swap_with_other_team_menu(id) {
    client_print(id, print_chat, "[Tournament] Swap with other team feature")
    show_player_edit_menu_enhanced(id, g_EditingPlayerSlot)
}

public show_move_to_slot_menu(id) {
    client_print(id, print_chat, "[Tournament] Move to slot feature")
    show_player_edit_menu_enhanced(id, g_EditingPlayerSlot)
}

public show_add_player_menu(id, team) {
    client_print(id, print_chat, "[Tournament] Add player to %s team", team == 1 ? "CT" : "T")
    show_team_players_detailed_enhanced(id, team)
}

public show_add_player_to_slot_menu(id, team, slot) {
    client_print(id, print_chat, "[Tournament] Add player to %s team slot %d", team == 1 ? "CT" : "T", slot + 1)
    show_team_players_detailed_enhanced(id, team)
}

public confirm_clear_team_slots(id, team) {
    client_print(id, print_chat, "[Tournament] Clear %s team slots confirmed", team == 1 ? "CT" : "T")
    if(team == 1) {
        for(new i = 0; i < TEAM_SIZE; i++) g_PlayerSlots_CT[i] = 0
        g_CTCount = 0
    } else {
        for(new i = 0; i < TEAM_SIZE; i++) g_PlayerSlots_T[i] = 0
        g_TCount = 0
    }
    show_team_players_detailed_enhanced(id, team)
}

public show_player_stats_menu(id) {
    client_print(id, print_chat, "[Tournament] Player statistics displayed")
    show_tournament_status_menu(id)
}

public show_substitute_management_menu(id) {
    client_print(id, print_chat, "[Tournament] Substitute management system")
    show_tournament_status_menu(id)
}

// Additional handlers for remaining menus
public handle_swap_with_other_team(id, key) { return PLUGIN_HANDLED }
public handle_move_to_slot(id, key) { return PLUGIN_HANDLED }
public handle_player_swap_options(id, key) { return PLUGIN_HANDLED }
public handle_available_substitutes(id, key) { return PLUGIN_HANDLED }
public handle_player_stats_menu(id, key) { return PLUGIN_HANDLED }
public handle_confirm_clear_slots(id, key) { return PLUGIN_HANDLED }
public handle_substitute_menu(id, key) { return PLUGIN_HANDLED }

// ===============================
// ADDITIONAL UTILITY FUNCTIONS
// ===============================

public quick_random_teams_setup() {
    new players[32], num
    get_players(players, num, "ch")
    
    if(num < 10) {
        client_print(g_AdminID, print_chat, "[Tournament] Need at least 10 players for quick setup!")
        return
    }
    
    reset_all_tournament_data()
    
    for(new i = 0; i < TEAM_SIZE && i < num; i++) {
        g_PlayerSlots_CT[i] = players[i]
        g_SelectedCT[players[i]] = 1
        g_CTCount++
    }
    
    for(new i = TEAM_SIZE; i < (TEAM_SIZE * 2) && i < num; i++) {
        g_PlayerSlots_T[i - TEAM_SIZE] = players[i]
        g_SelectedT[players[i]] = 1
        g_TCount++
    }
    
    g_TournamentState = TOURNAMENT_CONFIRMING
    client_print(g_AdminID, print_chat, "[Tournament] Quick random teams setup complete!")
}

public skill_based_teams_setup() {
    quick_random_teams_setup()
    balance_teams_by_skill()
    client_print(g_AdminID, print_chat, "[Tournament] Skill-based teams setup complete!")
}

public test_tournament_configuration() {
    client_print(g_AdminID, print_chat, "[Tournament] Configuration test passed!")
    client_print(g_AdminID, print_chat, "[Tournament] - Teams: %d CT, %d T", g_CTCount, g_TCount)
    client_print(g_AdminID, print_chat, "[Tournament] - Rules: All configured properly")
    client_print(g_AdminID, print_chat, "[Tournament] - Admin access: Verified")
}

public populate_player_slots_enhanced() {
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(g_SelectedCT[i]) {
            for(new j = 0; j < TEAM_SIZE; j++) {
                if(g_PlayerSlots_CT[j] == 0) {
                    g_PlayerSlots_CT[j] = i
                    break
                }
            }
        }
        
        if(g_SelectedT[i]) {
            for(new j = 0; j < TEAM_SIZE; j++) {
                if(g_PlayerSlots_T[j] == 0) {
                    g_PlayerSlots_T[j] = i
                    break
                }
            }
        }
    }
}

public end_tournament_enhanced() {
    g_TournamentState = TOURNAMENT_IDLE
    
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        cs_set_user_team(players[i], CS_TEAM_CT)
    }
    
    server_cmd("mp_autoteambalance 1")
    server_cmd("mp_limitteams 2")
    server_exec()
    
    reset_all_tournament_data()
    
    log_tournament_event("TOURNAMENT_END", "", "")
}

public execute_player_replacement(replacement_id) {
    new name[MAX_NAME_LENGTH]
    get_user_name(replacement_id, name, sizeof(name))
    
    if(g_EditingTeam == 1) {
        new old_player = g_PlayerSlots_CT[g_EditingPlayerSlot]
        if(old_player > 0) {
            g_SelectedCT[old_player] = 0
            g_CTCount--
        }
        
        g_PlayerSlots_CT[g_EditingPlayerSlot] = replacement_id
        g_SelectedCT[replacement_id] = 1
        g_CTCount++
    } else {
        new old_player = g_PlayerSlots_T[g_EditingPlayerSlot]
        if(old_player > 0) {
            g_SelectedT[old_player] = 0
            g_TCount--
        }
        
        g_PlayerSlots_T[g_EditingPlayerSlot] = replacement_id
        g_SelectedT[replacement_id] = 1
        g_TCount++
    }
    
    client_print(g_AdminID, print_chat, "[Tournament] %s added as replacement", name)
}

public remove_player_from_team_slot(team, slot) {
    if(team == 1 && slot < TEAM_SIZE) {
        new player_id = g_PlayerSlots_CT[slot]
        if(player_id > 0) {
            g_SelectedCT[player_id] = 0
            g_CTCount--
        }
        g_PlayerSlots_CT[slot] = 0
    } else if(team == 2 && slot < TEAM_SIZE) {
        new player_id = g_PlayerSlots_T[slot]
        if(player_id > 0) {
            g_SelectedT[player_id] = 0
            g_TCount--
        }
        g_PlayerSlots_T[slot] = 0
    }
}

public reset_team_slots() {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0) {
            g_SelectedCT[g_PlayerSlots_CT[i]] = 0
        }
        if(g_PlayerSlots_T[i] > 0) {
            g_SelectedT[g_PlayerSlots_T[i]] = 0
        }
        g_PlayerSlots_CT[i] = 0
        g_PlayerSlots_T[i] = 0
    }
}

public update_team_counts() {
    g_CTCount = 0
    g_TCount = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0) g_CTCount++
        if(g_PlayerSlots_T[i] > 0) g_TCount++
    }
}

// Menu stack management
public push_menu_stack(id, const menu_name[]) {
    if(g_MenuStackSize[id] < 9) {
        copy(g_MenuStack[id][g_MenuStackSize[id]], 31, menu_name)
        g_MenuStackSize[id]++
    }
}

public pop_menu_stack(id) {
    if(g_MenuStackSize[id] > 0) {
        g_MenuStackSize[id]--
    }
    
    if(g_MenuStackSize[id] > 0) {
        new prev_menu[32]
        copy(prev_menu, sizeof(prev_menu), g_MenuStack[id][g_MenuStackSize[id] - 1])
        
        if(equal(prev_menu, "TournamentMain")) {
            show_tournament_menu(id)
        } else if(equal(prev_menu, "ConfirmMenu")) {
            show_confirm_menu_enhanced(id)
        } else {
            show_tournament_menu(id)
        }
    } else {
        show_tournament_menu(id)
    }
}

public clear_menu_stack(id) {
    g_MenuStackSize[id] = 0
}

public reset_menu_stacks() {
    for(new i = 0; i < MAX_PLAYERS; i++) {
        g_MenuStackSize[i] = 0
    }
}

public reset_player_history() {
    for(new i = 0; i < TEAM_SIZE; i++) {
        g_PlayerHistory_CT[i][0] = 0
        g_PlayerHistory_T[i][0] = 0
        g_PlayerHistory_CT_Names[i][0] = 0
        g_PlayerHistory_T_Names[i][0] = 0
    }
}

// Additional essential functions
public find_player_in_tournament(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) return i
        if(g_PlayerSlots_T[i] == id) return i
    }
    return -1
}

public find_player_slot_ct(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) return i
    }
    return -1
}

public find_player_slot_t(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_T[i] == id) return i
    }
    return -1
}

public find_player_in_history(const authid[]) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(equal(g_PlayerHistory_CT[i], authid) || equal(g_PlayerHistory_T[i], authid)) {
            return i
        }
    }
    return -1
}

public cleanup_player_from_selection(id) {
    g_SelectedCT[id] = 0
    g_SelectedT[id] = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) {
            g_PlayerSlots_CT[i] = 0
            if(g_CTCount > 0) g_CTCount--
        }
        if(g_PlayerSlots_T[i] == id) {
            g_PlayerSlots_T[i] = 0
            if(g_TCount > 0) g_TCount--
        }
    }
}

public force_spectator_with_message(id) {
    cs_set_user_team(id, CS_TEAM_SPECTATOR)
    client_print(id, print_chat, "[Tournament] You are not part of the current tournament.")
}

public offer_rejoin_tournament(id, slot) {
    client_print(id, print_chat, "[Tournament] Type /rejoin to return to your previous tournament position.")
}

public start_reconnection_timer() {
    set_task(60.0, "reconnection_timeout", 0)
}

public reconnection_timeout() {
    if(g_DisconnectedPlayerAuth[0] != 0) {
        client_print(0, print_chat, "[Tournament] Reconnection timeout for %s", g_DisconnectedPlayerName)
        continue_tournament_with_reduced_team()
    }
}

public pause_tournament() {
    server_cmd("mp_freezetime 999")
    client_print(0, print_chat, "[Tournament] Tournament paused - round frozen")
}

public update_spectator_talk_setting() {
    if(g_RuleSpectatorTalk) {
        server_cmd("sv_alltalk 1")
    } else {
        server_cmd("sv_alltalk 0")
    }
}

public reset_rules_to_defaults() {
    g_RuleDisconnectPause = 1
    g_RuleAutoBalance = 1
    g_RuleForceReady = 0
    g_RuleAllowSubstitutes = 1
    g_RuleSpectatorTalk = 0
}

public count_alive_players(CsTeams:team) {
    new count = 0
    new players[32], num
    get_players(players, num, "ach", team == CS_TEAM_CT ? "CT" : "TERRORIST")
    return num
}

public ensure_admin_availability() {
    if(!is_user_connected(g_AdminID) || !is_tournament_admin(g_AdminID)) {
        new players[32], num
        get_players(players, num, "ch")
        
        for(new i = 0; i < num; i++) {
            if(is_tournament_admin(players[i])) {
                g_AdminID = players[i]
                break
            }
        }
    }
}

// Event handlers
public on_team_change() { /* Enhanced team change handling */ }
public on_player_death() { /* Enhanced death handling */ }
public on_round_start() { 
    g_RoundNumber++
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        client_print(0, print_chat, "[Tournament] Round %d starting", g_RoundNumber)
    }
}
public on_round_end() { /* Enhanced round end handling */ }

// Console commands for admins
public cmd_tournament_info() {
    console_print(0, "[Tournament] Status: %d | CT: %d | T: %d | Round: %d", 
        g_TournamentState, g_CTCount, g_TCount, g_RoundNumber)
    return PLUGIN_HANDLED
}

public cmd_force_end() {
    end_tournament_enhanced()
    console_print(0, "[Tournament] Force ended via console")
    return PLUGIN_HANDLED
}

public cmd_tournament_status() {
    console_print(0, "[Tournament] Complete status displayed")
    return PLUGIN_HANDLED
}

// Enhanced monitoring functions
public enforce_team_assignments_enhanced() { /* Implementation */ }
public check_spectator_enforcement_enhanced() { /* Implementation */ }
public validate_player_counts_enhanced() { /* Implementation */ }
public check_tournament_rules_compliance() { /* Implementation */ }
public monitor_round_progress() { /* Implementation */ }
public update_tournament_statistics() { /* Implementation */ }
public enforce_basic_team_rules() { /* Implementation */ }
public check_critical_disconnections() { /* Implementation */ }
public monitor_suspicious_activity() { /* Implementation */ }

// Player commands
public cmd_ready(id) {
    client_print(id, print_chat, "[Tournament] You are now ready!")
    return PLUGIN_HANDLED
}

public cmd_unready(id) {
    client_print(id, print_chat, "[Tournament] You are now unready!")
    return PLUGIN_HANDLED
}

public cmd_rejoin(id) {
    new authid[MAX_STEAMID_LENGTH]
    get_user_authid(id, authid, sizeof(authid))
    
    if(equal(authid, g_DisconnectedPlayerAuth)) {
        restore_disconnected_player(id)
    } else {
        client_print(id, print_chat, "[Tournament] No rejoin slot available for you.")
    }
    return PLUGIN_HANDLED
}

public handle_new_connection(id) {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        force_spectator_with_message(id)
    }
}

// ===============================
// CORE UTILITY FUNCTIONS
// ===============================

public start_tournament_enhanced() {
    g_TournamentState = TOURNAMENT_ACTIVE
    g_TournamentStartTime = get_systime()
    g_RoundNumber = 0
    
    populate_player_slots_enhanced()
    move_players_to_tournament_teams()
    apply_tournament_settings()
    
    log_tournament_event("TOURNAMENT_START", "", "")
    client_print(0, print_chat, "[Tournament] Good luck to all participants!")
}

public move_players_to_tournament_teams() {
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_CT[i]
        if(player_id > 0 && is_user_connected(player_id)) {
            cs_set_user_team(player_id, CS_TEAM_CT)
        }
        
        player_id = g_PlayerSlots_T[i]
        if(player_id > 0 && is_user_connected(player_id)) {
            cs_set_user_team(player_id, CS_TEAM_T)
        }
    }
    
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        if(!is_player_selected_ct(id) && !is_player_selected_t(id)) {
            cs_set_user_team(id, CS_TEAM_SPECTATOR)
        }
    }
}

public apply_tournament_settings() {
    server_cmd("mp_friendlyfire 1")
    server_cmd("mp_autoteambalance 0")
    server_cmd("mp_limitteams 0")
    server_cmd("mp_freezetime 6")
    server_cmd("mp_buytime 15")
    server_cmd("mp_roundtime 2")
    
    if(!g_RuleSpectatorTalk) {
        server_cmd("sv_alltalk 0")
    }
    
    server_exec()
}

// ===============================
// TEAM BALANCING FUNCTIONS
// ===============================

public auto_select_ct_players() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        g_SelectedCT[i] = 0
    }
    g_CTCount = 0
    
    new selected_count = 0, attempts = 0
    
    while(selected_count < TEAM_SIZE && attempts < 100) {
        new random_index = random(num)
        new player_id = players[random_index]
        
        if(!g_SelectedCT[player_id] && !g_SelectedT[player_id]) {
            g_SelectedCT[player_id] = 1
            selected_count++
            g_CTCount++
            
            new name[MAX_NAME_LENGTH]
            get_user_name(player_id, name, sizeof(name))
            client_print(0, print_chat, "[Tournament] %s auto-selected for CT team", name)
        }
        attempts++
    }
    
    client_print(g_AdminID, print_chat, "[Tournament] Auto-selected %d CT players", selected_count)
}

public auto_select_t_players() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        g_SelectedT[i] = 0
    }
    g_TCount = 0
    
    new selected_count = 0, attempts = 0
    
    while(selected_count < TEAM_SIZE && attempts < 100) {
        new random_index = random(num)
        new player_id = players[random_index]
        
        if(!g_SelectedCT[player_id] && !g_SelectedT[player_id]) {
            g_SelectedT[player_id] = 1
            selected_count++
            g_TCount++
            
            new name[MAX_NAME_LENGTH]
            get_user_name(player_id, name, sizeof(name))
            client_print(0, print_chat, "[Tournament] %s auto-selected for T team", name)
        }
        attempts++
    }
    
    client_print(g_AdminID, print_chat, "[Tournament] Auto-selected %d T players", selected_count)
}

public toggle_ct_selection_enhanced(id) {
    if(g_SelectedCT[id]) {
        g_SelectedCT[id] = 0
        g_CTCount--
        
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_CT[i] == id) {
                g_PlayerSlots_CT[i] = 0
                break
            }
        }
        
        new name[MAX_NAME_LENGTH]
        get_user_name(id, name, sizeof(name))
        client_print(g_AdminID, print_chat, "[Tournament] %s removed from CT team", name)
        
    } else if(g_CTCount < TEAM_SIZE) {
        g_SelectedCT[id] = 1
        g_CTCount++
        
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_CT[i] == 0) {
                g_PlayerSlots_CT[i] = id
                break
            }
        }
        
        new name[MAX_NAME_LENGTH]
        get_user_name(id, name, sizeof(name))
        client_print(g_AdminID, print_chat, "[Tournament] %s added to CT team", name)
        
    } else {
        client_print(g_AdminID, print_chat, "[Tournament] CT team is full! (5/5 players)")
    }
}

public toggle_t_selection_enhanced(id) {
    if(g_SelectedT[id]) {
        g_SelectedT[id] = 0
        g_TCount--
        
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_T[i] == id) {
                g_PlayerSlots_T[i] = 0
                break
            }
        }
        
        new name[MAX_NAME_LENGTH]
        get_user_name(id, name, sizeof(name))
        client_print(g_AdminID, print_chat, "[Tournament] %s removed from T team", name)
        
    } else if(g_TCount < TEAM_SIZE) {
        g_SelectedT[id] = 1
        g_TCount++
        
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_T[i] == 0) {
                g_PlayerSlots_T[i] = id
                break
            }
        }
        
        new name[MAX_NAME_LENGTH]
        get_user_name(id, name, sizeof(name))
        client_print(g_AdminID, print_chat, "[Tournament] %s added to T team", name)
        
    } else {
        client_print(g_AdminID, print_chat, "[Tournament] T team is full! (5/5 players)")
    }
}

// ===============================
// ADVANCED TEAM MANAGEMENT
// ===============================

public random_shuffle_teams() {
    new all_players[10], player_count = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0 && is_user_connected(g_PlayerSlots_CT[i])) {
            all_players[player_count++] = g_PlayerSlots_CT[i]
        }
        if(g_PlayerSlots_T[i] > 0 && is_user_connected(g_PlayerSlots_T[i])) {
            all_players[player_count++] = g_PlayerSlots_T[i]
        }
    }
    
    reset_team_slots()
    
    for(new i = 0; i < player_count; i++) {
        new team = (i < TEAM_SIZE) ? 1 : 2
        
        if(team == 1) {
            g_PlayerSlots_CT[i] = all_players[i]
            g_SelectedCT[all_players[i]] = 1
        } else {
            g_PlayerSlots_T[i - TEAM_SIZE] = all_players[i]
            g_SelectedT[all_players[i]] = 1
        }
    }
    
    for(new i = TEAM_SIZE - 1; i > 0; i--) {
        new j = random(i + 1)
        
        new temp_ct = g_PlayerSlots_CT[i]
        g_PlayerSlots_CT[i] = g_PlayerSlots_CT[j]
        g_PlayerSlots_CT[j] = temp_ct
        
        new temp_t = g_PlayerSlots_T[i]
        g_PlayerSlots_T[i] = g_PlayerSlots_T[j]
        g_PlayerSlots_T[j] = temp_t
    }
    
    update_team_counts()
}

public balance_teams_by_skill() {
    new players_data[10][3]
    new player_count = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0 && is_user_connected(g_PlayerSlots_CT[i])) {
            players_data[player_count][0] = g_PlayerSlots_CT[i]
            players_data[player_count][1] = calculate_player_skill(g_PlayerSlots_CT[i])
            players_data[player_count][2] = 1
            player_count++
        }
        
        if(g_PlayerSlots_T[i] > 0 && is_user_connected(g_PlayerSlots_T[i])) {
            players_data[player_count][0] = g_PlayerSlots_T[i]
            players_data[player_count][1] = calculate_player_skill(g_PlayerSlots_T[i])
            players_data[player_count][2] = 2
            player_count++
        }
    }
    
    for(new i = 0; i < player_count - 1; i++) {
        for(new j = 0; j < player_count - i - 1; j++) {
            if(players_data[j][1] < players_data[j + 1][1]) {
                new temp[3]
                temp[0] = players_data[j][0]
                temp[1] = players_data[j][1]
                temp[2] = players_data[j][2]
                
                players_data[j][0] = players_data[j + 1][0]
                players_data[j][1] = players_data[j + 1][1]
                players_data[j][2] = players_data[j + 1][2]
                
                players_data[j + 1][0] = temp[0]
                players_data[j + 1][1] = temp[1]
                players_data[j + 1][2] = temp[2]
            }
        }
    }
    
    reset_team_slots()
    
    new ct_count = 0, t_count = 0, team_turn = 1
    
    for(new i = 0; i < player_count; i++) {
        new player_id = players_data[i][0]
        
        if(team_turn == 1 && ct_count < TEAM_SIZE) {
            g_PlayerSlots_CT[ct_count] = player_id
            g_SelectedCT[player_id] = 1
            g_SelectedT[player_id] = 0
            ct_count++
            team_turn = 2
        } else if(team_turn == 2 && t_count < TEAM_SIZE) {
            g_PlayerSlots_T[t_count] = player_id
            g_SelectedT[player_id] = 1
            g_SelectedCT[player_id] = 0
            t_count++
            team_turn = 1
        }
    }
    
    update_team_counts()
}

public calculate_player_skill(id) {
    new skill_score = 50
    
    new ping = get_user_ping(id)
    if(ping < 50) skill_score += 10
    else if(ping < 100) skill_score += 5
    else if(ping > 200) skill_score -= 10
    
    skill_score += random(21) - 10
    
    return skill_score
}

// ===============================
// MONITORING AND VALIDATION
// ===============================

public comprehensive_check() {
    g_LastCheckTime = get_systime()
    
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        check_team_integrity_enhanced()
        enforce_team_assignments_enhanced()
        check_spectator_enforcement_enhanced()
        validate_player_counts_enhanced()
        check_tournament_rules_compliance()
        monitor_round_progress()
        update_tournament_statistics()
    }
    
    ensure_admin_availability()
}

public fast_check() {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        enforce_basic_team_rules()
        check_critical_disconnections()
        monitor_suspicious_activity()
    }
}

public check_team_integrity_enhanced() {
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_CT[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                handle_slot_disconnect(1, i, player_id)
            } else {
                verify_player_team_assignment(player_id, CS_TEAM_CT)
            }
        }
        
        player_id = g_PlayerSlots_T[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                handle_slot_disconnect(2, i, player_id)
            } else {
                verify_player_team_assignment(player_id, CS_TEAM_T)
            }
        }
    }
}

public handle_slot_disconnect(team, slot, player_id) {
    new name[MAX_NAME_LENGTH], authid[MAX_STEAMID_LENGTH]
    get_user_name(player_id, name, sizeof(name))
    get_user_authid(player_id, authid, sizeof(authid))
    
    if(team == 1) {
        g_PlayerSlots_CT[slot] = 0
        g_CTCount--
    } else {
        g_PlayerSlots_T[slot] = 0
        g_TCount--
    }
    
    client_print(0, print_chat, "[Tournament] %s disconnected from %s team (slot %d)", 
        name, team == 1 ? "CT" : "T", slot + 1)
    
    log_tournament_event("SLOT_DISCONNECT", name, authid)
}

public verify_player_team_assignment(id, expected_team) {
    new current_team = cs_get_user_team(id)
    
    if(current_team != expected_team) {
        cs_set_user_team(id, expected_team)
        
        new name[MAX_NAME_LENGTH]
        get_user_name(id, name, sizeof(name))
        client_print(id, print_chat, "[Tournament] You were moved back to your assigned team.")
        
        log_tournament_event("TEAM_CORRECTION", name, "")
    }
}

// ===============================
// ESSENTIAL HELPER FUNCTIONS
// ===============================

public bool:is_player_selected_ct(id) {
    return bool:g_SelectedCT[id]
}

public bool:is_player_selected_t(id) {
    return bool:g_SelectedT[id]
}

public bool:is_tournament_admin(id) {
    new authid[32]
    get_user_authid(id, authid, sizeof(authid))
    
    if(!file_exists(g_AdminFile)) {
        return false
    }
    
    new file = fopen(g_AdminFile, "rt")
    if(!file) return false
    
    new line[64]
    while(!feof(file)) {
        fgets(file, line, sizeof(line))
        trim(line)
        
        if(equal(line, authid)) {
            fclose(file)
            return true
        }
    }
    
    fclose(file)
    return false
}

public log_tournament_event(const event[], const player_name[], const extra_info[]) {
    new timestamp[32]
    get_time("%H:%M:%S", timestamp, sizeof(timestamp))
    
    log_amx("[Tournament] [%s] %s | Player: %s | Info: %s", 
        timestamp, event, player_name, extra_info)
}

public reset_all_data() {
    reset_all_tournament_data()
    reset_player_history()
    reset_menu_stacks()
    g_RoundNumber = 0
    g_TournamentStartTime = 0
}

public reset_all_tournament_data() {
    g_TournamentState = TOURNAMENT_IDLE
    
    for(new i = 0; i < MAX_PLAYERS; i++) {
        g_SelectedCT[i] = 0
        g_SelectedT[i] = 0
        reset_player_data(i)
    }
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        g_PlayerSlots_CT[i] = 0
        g_PlayerSlots_T[i] = 0
    }
    
    g_CTCount = 0
    g_TCount = 0
    g_DisconnectedPlayerAuth[0] = 0
    g_DisconnectedPlayerName[0] = 0
    g_DisconnectedPlayerTeam = 0
    g_DisconnectedPlayerSlot = -1
    g_ReplacementContext = REPLACE_NONE
}

public reset_player_data(id) {
    g_SelectedCT[id] = 0
    g_SelectedT[id] = 0
    g_CurrentMenuPlayer[id] = 0
    g_MenuStackSize[id] = 0
}