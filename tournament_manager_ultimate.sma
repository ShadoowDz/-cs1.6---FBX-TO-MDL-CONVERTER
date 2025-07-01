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