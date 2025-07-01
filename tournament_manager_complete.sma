#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN "Tournament Manager Complete"
#define VERSION "2.0"
#define AUTHOR "Tournament System Enhanced"

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
new g_MenuStack[MAX_PLAYERS][10] // Menu navigation stack
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
    
    // Enhanced event handling
    register_event("TeamInfo", "on_team_change", "a")
    register_event("DeathMsg", "on_player_death", "a")
    register_logevent("on_round_start", 2, "1=Round_Start")
    register_logevent("on_round_end", 2, "1=Round_End")
    
    // Initialize all systems
    reset_all_data()
    
    // Start enhanced monitoring system
    g_CheckTimer = set_task(2.0, "comprehensive_check", 0, "", 0, "b")
    set_task(1.0, "fast_check", 0, "", 0, "b") // Fast checks every second
    
    // Server commands
    register_concmd("tournament_info", "cmd_tournament_info", ADMIN_RCON)
    register_concmd("tournament_force_end", "cmd_force_end", ADMIN_RCON)
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
        return // Player not in tournament
    }
    
    // Store disconnect information
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
    
    // Handle based on disconnect rule
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
    
    // Check if this is the disconnected player
    if(equal(authid, g_DisconnectedPlayerAuth)) {
        restore_disconnected_player(id)
        return
    }
    
    // Check if player was in tournament history
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
    
    if(g_DisconnectedPlayerTeam == 1) { // CT
        g_PlayerSlots_CT[g_DisconnectedPlayerSlot] = id
        g_SelectedCT[id] = 1
        g_CTCount++
        cs_set_user_team(id, CS_TEAM_CT)
        client_print(0, print_chat, "[Tournament] %s reconnected and restored to CT team.", name)
        
        // Remove any replacement player
        handle_replacement_removal(1, g_DisconnectedPlayerSlot)
        
    } else if(g_DisconnectedPlayerTeam == 2) { // T
        g_PlayerSlots_T[g_DisconnectedPlayerSlot] = id
        g_SelectedT[id] = 1
        g_TCount++
        cs_set_user_team(id, CS_TEAM_T)
        client_print(0, print_chat, "[Tournament] %s reconnected and restored to T team.", name)
        
        // Remove any replacement player
        handle_replacement_removal(2, g_DisconnectedPlayerSlot)
    }
    
    // Clear disconnect data
    g_DisconnectedPlayerAuth[0] = 0
    g_DisconnectedPlayerName[0] = 0
    g_DisconnectedPlayerTeam = 0
    g_DisconnectedPlayerSlot = -1
    
    log_tournament_event("RECONNECT", name, "")
}

public handle_replacement_removal(team, slot) {
    // Find and remove any replacement player in the slot
    new current_player = (team == 1) ? g_PlayerSlots_CT[slot] : g_PlayerSlots_T[slot]
    
    if(current_player > 0 && is_user_connected(current_player)) {
        new replacement_name[MAX_NAME_LENGTH]
        get_user_name(current_player, replacement_name, sizeof(replacement_name))
        
        cs_set_user_team(current_player, CS_TEAM_SPECTATOR)
        client_print(current_player, print_chat, "[Tournament] You've been moved to spectator as the original player reconnected.")
        client_print(0, print_chat, "[Tournament] %s moved to spectator for original player return.", replacement_name)
        
        // Clear from selection
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
// ENHANCED MENU SYSTEM
// ===============================

public show_tournament_menu(id) {
    if(!is_tournament_admin(id)) {
        client_print(id, print_chat, "[Tournament] Access denied. You're not authorized to manage tournaments.")
        return PLUGIN_HANDLED
    }
    
    g_AdminID = id
    push_menu_stack(id, "TournamentMain")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Manager v2.0\y]^n^n")
    
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
        case 0: { // Start Tournament / Tournament Status
            if(g_TournamentState == TOURNAMENT_ACTIVE) {
                show_tournament_status_menu(id)
            } else if(g_TournamentState == TOURNAMENT_IDLE) {
                start_tournament_selection_enhanced(id)
            } else {
                client_print(id, print_chat, "[Tournament] Setup already in progress!")
            }
        }
        case 1: { // End Tournament / Advanced Setup
            if(g_TournamentState == TOURNAMENT_ACTIVE) {
                confirm_end_tournament(id)
            } else {
                show_advanced_setup_menu(id)
            }
        }
        case 2: { // Rules
            show_rules_menu_enhanced(id)
        }
        case 3: { // Player Management
            show_player_management_menu(id)
        }
        case 4: { // Tournament History
            show_tournament_history_menu(id)
        }
        case 9: { // Exit
            clear_menu_stack(id)
            return PLUGIN_HANDLED
        }
    }
    return PLUGIN_HANDLED
}

// ===============================
// ENHANCED PLAYER SELECTION
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
    
    for(new i = 0; i < num && menu_options < 8; i++) {
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
    if(key == 9) { // Back/Cancel
        pop_menu_stack(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 8) { // Continue
        if(g_CTCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_SELECTING_T
            show_t_selection_menu_enhanced(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly %d CT players!", TEAM_SIZE)
            show_ct_selection_menu_enhanced(id)
        }
        return PLUGIN_HANDLED
    }
    
    if(key == 7) { // Auto Select
        auto_select_ct_players()
        show_ct_selection_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    
    if(key < num) {
        new player_id = players[key]
        toggle_ct_selection_enhanced(player_id)
        show_ct_selection_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

// ===============================
// ENHANCED RULES SYSTEM
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
        case 0: { // Disconnect Pause
            g_RuleDisconnectPause = !g_RuleDisconnectPause
            client_print(id, print_chat, "[Tournament] Disconnect pause rule %s", 
                g_RuleDisconnectPause ? "enabled" : "disabled")
            log_tournament_event("RULE_CHANGE", "disconnect_pause", g_RuleDisconnectPause ? "enabled" : "disabled")
        }
        case 1: { // Auto Balance
            g_RuleAutoBalance = !g_RuleAutoBalance
            client_print(id, print_chat, "[Tournament] Auto balance rule %s", 
                g_RuleAutoBalance ? "enabled" : "disabled")
        }
        case 2: { // Force Ready
            g_RuleForceReady = !g_RuleForceReady
            client_print(id, print_chat, "[Tournament] Force ready rule %s", 
                g_RuleForceReady ? "enabled" : "disabled")
        }
        case 3: { // Allow Substitutes
            g_RuleAllowSubstitutes = !g_RuleAllowSubstitutes
            client_print(id, print_chat, "[Tournament] Allow substitutes rule %s", 
                g_RuleAllowSubstitutes ? "enabled" : "disabled")
        }
        case 4: { // Spectator Talk
            g_RuleSpectatorTalk = !g_RuleSpectatorTalk
            client_print(id, print_chat, "[Tournament] Spectator talk rule %s", 
                g_RuleSpectatorTalk ? "enabled" : "disabled")
            update_spectator_talk_setting()
        }
        case 5: { // Advanced Rules
            show_advanced_rules_menu(id)
            return PLUGIN_HANDLED
        }
        case 6: { // Reset to Defaults
            reset_rules_to_defaults()
            client_print(id, print_chat, "[Tournament] All rules reset to defaults")
        }
        case 9: { // Back
            pop_menu_stack(id)
            return PLUGIN_HANDLED
        }
    }
    
    show_rules_menu_enhanced(id)
    return PLUGIN_HANDLED
}

// ===============================
// COMPREHENSIVE MONITORING
// ===============================

public comprehensive_check() {
    g_LastCheckTime = get_systime()
    
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // All comprehensive checks
        check_team_integrity_enhanced()
        enforce_team_assignments_enhanced()
        check_spectator_enforcement_enhanced()
        validate_player_counts_enhanced()
        check_tournament_rules_compliance()
        monitor_round_progress()
        update_tournament_statistics()
    }
    
    // Always check for admin availability
    ensure_admin_availability()
}

public fast_check() {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // Quick essential checks every second
        enforce_basic_team_rules()
        check_critical_disconnections()
        monitor_suspicious_activity()
    }
}

public check_team_integrity_enhanced() {
    // Enhanced CT team integrity
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_CT[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                handle_slot_disconnect(1, i, player_id)
            } else {
                verify_player_team_assignment(player_id, CS_TEAM_CT)
                check_player_behavior(player_id)
            }
        }
    }
    
    // Enhanced T team integrity
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_T[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                handle_slot_disconnect(2, i, player_id)
            } else {
                verify_player_team_assignment(player_id, CS_TEAM_T)
                check_player_behavior(player_id)
            }
        }
    }
}

// ===============================
// UTILITY FUNCTIONS
// ===============================

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

// Continue with more enhanced functions...
// [Note: This is getting quite long, so I'll create additional files for specific enhancements]