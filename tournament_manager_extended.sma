#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN "Tournament Manager Extended"
#define VERSION "1.0"
#define AUTHOR "Tournament System"

#define MAX_PLAYERS 32
#define TEAM_SIZE 5

// Tournament states
enum {
    TOURNAMENT_IDLE,
    TOURNAMENT_SELECTING_CT,
    TOURNAMENT_SELECTING_T,
    TOURNAMENT_CONFIRMING,
    TOURNAMENT_ACTIVE
}

// Global variables
new g_TournamentState = TOURNAMENT_IDLE
new g_SelectedCT[MAX_PLAYERS]
new g_SelectedT[MAX_PLAYERS]
new g_CTCount = 0
new g_TCount = 0
new g_AdminID = 0
new g_RuleDisconnectPause = 1 // 1 = enabled, 0 = disabled
new g_CheckTimer
new g_DisconnectedPlayer = 0
new g_ReplacementContext = 0 // 1 = CT replacement, 2 = T replacement
new g_EditingTeam = 0 // Team currently being edited
new g_EditingPlayerSlot = 0 // Player slot being edited
new g_PlayerSlots_CT[TEAM_SIZE] // Player IDs in CT slots
new g_PlayerSlots_T[TEAM_SIZE]  // Player IDs in T slots

// Admin configuration
new g_AdminFile[64] = "addons/amxmodx/configs/tournament_admins.cfg"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_clcmd("say /ts", "show_tournament_menu")
    register_clcmd("say_team /ts", "show_tournament_menu")
    
    register_menucmd(register_menuid("TournamentMain"), 1023, "handle_main_menu")
    register_menucmd(register_menuid("CTSelection"), 1023, "handle_ct_selection")
    register_menucmd(register_menuid("TSelection"), 1023, "handle_t_selection")
    register_menucmd(register_menuid("ConfirmMenu"), 1023, "handle_confirm_menu")
    register_menucmd(register_menuid("ReshowMenu"), 1023, "handle_reshow_menu")
    register_menucmd(register_menuid("TeamSelectMenu"), 1023, "handle_team_select_menu")
    register_menucmd(register_menuid("PlayerEditMenu"), 1023, "handle_player_edit_menu")
    register_menucmd(register_menuid("RulesMenu"), 1023, "handle_rules_menu")
    register_menucmd(register_menuid("ReplacePlayerMenu"), 1023, "handle_replace_player_menu")
    register_menucmd(register_menuid("DisconnectMenu"), 1023, "handle_disconnect_menu")
    register_menucmd(register_menuid("ReplacementSelectMenu"), 1023, "handle_replacement_select_menu")
    register_menucmd(register_menuid("TeamPlayersMenu"), 1023, "handle_team_players_menu")
    
    register_event("TeamInfo", "on_team_change", "a")
    
    // Initialize player slots
    reset_player_slots()
    
    // Start the check timer (checks every 2 seconds as requested)
    g_CheckTimer = set_task(2.0, "check_tournament_status", 0, "", 0, "b")
    
    // Register client events
    register_logevent("on_round_start", 2, "1=Round_Start")
}

public plugin_end() {
    if(task_exists(g_CheckTimer)) {
        remove_task(g_CheckTimer)
    }
}

public client_connect(id) {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // Force new connections to spectator during tournament
        set_task(1.0, "force_spectator", id)
    }
}

public client_disconnect(id) {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // Check if disconnected player was in tournament
        if(is_player_selected_ct(id) || is_player_selected_t(id)) {
            if(g_RuleDisconnectPause) {
                g_DisconnectedPlayer = id
                handle_player_disconnect(id)
            }
        }
    }
    
    // Remove from selected lists and slots
    remove_from_selected(id)
    remove_from_slots(id)
}

public client_putinserver(id) {
    // Check if this is a reconnecting tournament player
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        check_reconnecting_player(id)
    }
}

public force_spectator(id) {
    if(is_user_connected(id) && g_TournamentState == TOURNAMENT_ACTIVE) {
        if(!is_player_selected_ct(id) && !is_player_selected_t(id)) {
            cs_set_user_team(id, CS_TEAM_SPECTATOR)
            client_print(id, print_chat, "[Tournament] You've been moved to spectator during active tournament.")
        }
    }
}

public check_tournament_status() {
    if(g_TournamentState != TOURNAMENT_ACTIVE) return
    
    // Comprehensive check of everything every 2 seconds
    check_team_integrity()
    enforce_team_assignments()
    check_spectator_enforcement()
    check_player_counts()
    validate_tournament_state()
}

public check_team_integrity() {
    // Verify CT team integrity
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_CT[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                // Player disconnected, clear slot
                g_PlayerSlots_CT[i] = 0
                g_SelectedCT[player_id] = 0
                g_CTCount--
            } else if(cs_get_user_team(player_id) != CS_TEAM_CT) {
                // Player not in correct team, fix it
                cs_set_user_team(player_id, CS_TEAM_CT)
            }
        }
    }
    
    // Verify T team integrity
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_T[i]
        if(player_id > 0) {
            if(!is_user_connected(player_id)) {
                // Player disconnected, clear slot
                g_PlayerSlots_T[i] = 0
                g_SelectedT[player_id] = 0
                g_TCount--
            } else if(cs_get_user_team(player_id) != CS_TEAM_T) {
                // Player not in correct team, fix it
                cs_set_user_team(player_id, CS_TEAM_T)
            }
        }
    }
}

public check_spectator_enforcement() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        if(!is_player_selected_ct(id) && !is_player_selected_t(id)) {
            if(cs_get_user_team(id) != CS_TEAM_SPECTATOR) {
                cs_set_user_team(id, CS_TEAM_SPECTATOR)
                client_print(id, print_chat, "[Tournament] You must stay in spectator during tournament.")
            }
        }
    }
}

public check_player_counts() {
    // Count actual players in tournament teams
    new ct_count = 0, t_count = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0 && is_user_connected(g_PlayerSlots_CT[i])) {
            ct_count++
        }
        if(g_PlayerSlots_T[i] > 0 && is_user_connected(g_PlayerSlots_T[i])) {
            t_count++
        }
    }
    
    // Update counts
    g_CTCount = ct_count
    g_TCount = t_count
}

public validate_tournament_state() {
    // Check if tournament should continue based on player counts
    if(!g_RuleDisconnectPause) {
        // Tournament continues even with fewer players
        return
    }
    
    // Additional validation logic can be added here
}

public check_reconnecting_player(id) {
    new authid[32]
    get_user_authid(id, authid, sizeof(authid))
    
    // Check if this player was in tournament before disconnecting
    if(g_DisconnectedPlayer > 0 && equal_steamids(g_DisconnectedPlayer, id)) {
        // Player reconnected, restore their position
        restore_player_position(id)
        g_DisconnectedPlayer = 0
    }
}

public restore_player_position(id) {
    // Find the player's original slot and restore them
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == 0 && was_player_in_ct_slot(id, i)) {
            g_PlayerSlots_CT[i] = id
            g_SelectedCT[id] = 1
            g_CTCount++
            cs_set_user_team(id, CS_TEAM_CT)
            client_print(id, print_chat, "[Tournament] Welcome back! You've been restored to CT team.")
            
            // Remove any replacement player
            remove_replacement_from_ct()
            return
        }
        
        if(g_PlayerSlots_T[i] == 0 && was_player_in_t_slot(id, i)) {
            g_PlayerSlots_T[i] = id
            g_SelectedT[id] = 1
            g_TCount++
            cs_set_user_team(id, CS_TEAM_T)
            client_print(id, print_chat, "[Tournament] Welcome back! You've been restored to T team.")
            
            // Remove any replacement player
            remove_replacement_from_t()
            return
        }
    }
}

public show_tournament_menu(id) {
    if(!is_tournament_admin(id)) {
        client_print(id, print_chat, "[Tournament] You don't have permission to use tournament manager.")
        return PLUGIN_HANDLED
    }
    
    g_AdminID = id
    
    new menu[512]
    new len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Manager\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yStart Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yEnd Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yRules Configuration^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "TournamentMain")
    return PLUGIN_HANDLED
}

public handle_main_menu(id, key) {
    switch(key) {
        case 0: { // Start Tournament
            if(g_TournamentState == TOURNAMENT_ACTIVE) {
                client_print(id, print_chat, "[Tournament] Tournament is already active!")
                return PLUGIN_HANDLED
            }
            start_tournament_selection(id)
        }
        case 1: { // End Tournament
            if(g_TournamentState != TOURNAMENT_ACTIVE) {
                client_print(id, print_chat, "[Tournament] No active tournament to end!")
                return PLUGIN_HANDLED
            }
            end_tournament()
            client_print(id, print_chat, "[Tournament] Tournament ended!")
        }
        case 2: { // Rules
            show_rules_menu(id)
        }
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

public start_tournament_selection(id) {
    reset_selections()
    reset_player_slots()
    g_TournamentState = TOURNAMENT_SELECTING_CT
    show_ct_selection_menu(id)
}

public show_ct_selection_menu(id) {
    new menu[1024], len = 0
    new players[32], num, player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rCT Team Selection\y] \w(\r%d\w/\r5\w)^n^n", g_CTCount)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 8; i++) {
        new player_id = players[i]
        
        get_user_name(player_id, player_name, sizeof(player_name))
        new is_selected = is_player_selected_ct(player_id)
        
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. %s%s \y%s^n", 
            menu_options + 1, 
            is_selected ? "\g[✓] " : "\r[ ] ",
            is_selected ? "\g" : "\w",
            player_name)
        
        menu_options++
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w9. \y%s^n", 
        g_CTCount == TEAM_SIZE ? "Continue to T Selection" : "Need 5 players")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rCancel")
    
    show_menu(id, 1023, menu, -1, "CTSelection")
}

public handle_ct_selection(id, key) {
    if(key == 9) return PLUGIN_HANDLED // Cancel
    
    if(key == 8) { // Continue
        if(g_CTCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_SELECTING_T
            show_t_selection_menu(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly 5 CT players!")
            show_ct_selection_menu(id)
        }
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    
    if(key < num) {
        new player_id = players[key]
        toggle_ct_selection(player_id)
        show_ct_selection_menu(id)
    }
    
    return PLUGIN_HANDLED
}

public show_t_selection_menu(id) {
    new menu[1024], len = 0
    new players[32], num, player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rT Team Selection\y] \w(\r%d\w/\r5\w)^n^n", g_TCount)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 8; i++) {
        new player_id = players[i]
        if(is_player_selected_ct(player_id)) continue // Skip CT players
        
        get_user_name(player_id, player_name, sizeof(player_name))
        new is_selected = is_player_selected_t(player_id)
        
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. %s%s \y%s^n", 
            menu_options + 1, 
            is_selected ? "\g[✓] " : "\r[ ] ",
            is_selected ? "\g" : "\w",
            player_name)
        
        menu_options++
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yBack to CT Selection^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \y%s^n", 
        g_TCount == TEAM_SIZE ? "Continue to Confirmation" : "Need 5 players")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rCancel")
    
    show_menu(id, 1023, menu, -1, "TSelection")
}

public handle_t_selection(id, key) {
    if(key == 9) return PLUGIN_HANDLED // Cancel
    
    if(key == 8) { // Continue
        if(g_TCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_CONFIRMING
            show_confirm_menu(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly 5 T players!")
            show_t_selection_menu(id)
        }
        return PLUGIN_HANDLED
    }
    
    if(key == 7) { // Back to CT
        g_TournamentState = TOURNAMENT_SELECTING_CT
        show_ct_selection_menu(id)
        return PLUGIN_HANDLED
    }
    
    new players[32], num
    get_players(players, num, "ch")
    new available_players[32], available_count = 0
    
    // Build list of available players (not in CT)
    for(new i = 0; i < num; i++) {
        if(!is_player_selected_ct(players[i])) {
            available_players[available_count++] = players[i]
        }
    }
    
    if(key < available_count) {
        new player_id = available_players[key]
        toggle_t_selection(player_id)
        show_t_selection_menu(id)
    }
    
    return PLUGIN_HANDLED
}

public show_confirm_menu(id) {
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Confirmation\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\gCT Team: \w%d players selected^n", g_CTCount)
    len += formatex(menu[len], sizeof(menu) - len, "\rT Team: \w%d players selected^n^n", g_TCount)
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \gYES - Start Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yReshow Selected Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \rCancel Everything^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "ConfirmMenu")
}

public handle_confirm_menu(id, key) {
    switch(key) {
        case 0: { // Start Tournament
            start_tournament()
            client_print(0, print_chat, "[Tournament] Tournament started! Selected players moved to teams.")
        }
        case 1: { // Reshow players
            show_reshow_menu(id)
        }
        case 2: { // Cancel
            reset_selections()
            reset_player_slots()
            client_print(id, print_chat, "[Tournament] Tournament setup cancelled.")
        }
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

public show_reshow_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rReshow Selected Players\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \gCT Team Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \rT Team Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w3. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "ReshowMenu")
}

public handle_reshow_menu(id, key) {
    switch(key) {
        case 0: { // CT Team
            g_EditingTeam = 1
            show_team_players_detailed(id, 1)
        }
        case 1: { // T Team
            g_EditingTeam = 2
            show_team_players_detailed(id, 2)
        }
        case 2: show_confirm_menu(id) // Back to confirmation
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

public show_team_players_detailed(id, team) {
    new menu[1024], len = 0
    new player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\r%s Team Players\y]^n^n", 
        team == 1 ? "CT" : "T")
    
    new slots[] = (team == 1) ? g_PlayerSlots_CT : g_PlayerSlots_T
    new count = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(slots[i] > 0 && is_user_connected(slots[i])) {
            get_user_name(slots[i], player_name, sizeof(player_name))
            len += formatex(menu[len], sizeof(menu) - len, "\w%d. \y%s \r(Slot %d)^n", 
                count + 1, player_name, i + 1)
            count++
        }
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yBack to Reshow Menu^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "TeamPlayersMenu")
}

public handle_team_players_menu(id, key) {
    if(key == 7) { // Back to reshow
        show_reshow_menu(id)
        return PLUGIN_HANDLED
    }
    if(key == 8) { // Back to confirmation
        show_confirm_menu(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED // Exit
    
    // Handle player selection for editing
    new slots[] = (g_EditingTeam == 1) ? g_PlayerSlots_CT : g_PlayerSlots_T
    new current_slot = 0
    
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(slots[i] > 0 && is_user_connected(slots[i])) {
            if(current_slot == key) {
                g_EditingPlayerSlot = i
                show_player_edit_menu(id, slots[i])
                return PLUGIN_HANDLED
            }
            current_slot++
        }
    }
    
    return PLUGIN_HANDLED
}

public show_player_edit_menu(id, player_id) {
    new menu[512], len = 0
    new player_name[32]
    get_user_name(player_id, player_name, sizeof(player_name))
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rEdit Player\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wPlayer: \y%s^n", player_name)
    len += formatex(menu[len], sizeof(menu) - len, "\wTeam: \y%s^n^n", 
        g_EditingTeam == 1 ? "CT" : "T")
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yReplace Player^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w8. \yBack to Team Players^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rExit")
    
    show_menu(id, 1023, menu, -1, "PlayerEditMenu")
}

public handle_player_edit_menu(id, key) {
    switch(key) {
        case 0: { // Replace Player
            g_ReplacementContext = g_EditingTeam
            show_replacement_players(id)
        }
        case 7: { // Back to team players
            show_team_players_detailed(id, g_EditingTeam)
        }
        case 8: { // Back to confirmation
            show_confirm_menu(id)
        }
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

public show_replacement_players(id) {
    new menu[1024], len = 0
    new players[32], num, player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rSelect Replacement\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wReplacing for: \y%s Team^n^n", 
        g_ReplacementContext == 1 ? "CT" : "T")
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 8; i++) {
        new player_id = players[i]
        
        // Skip if player is already selected
        if(is_player_selected_ct(player_id) || is_player_selected_t(player_id)) {
            continue
        }
        
        get_user_name(player_id, player_name, sizeof(player_name))
        len += formatex(menu[len], sizeof(menu) - len, "\w%d. \y%s^n", 
            menu_options + 1, player_name)
        menu_options++
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w9. \yBack to Confirmation^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rCancel")
    
    show_menu(id, 1023, menu, -1, "ReplacementSelectMenu")
}

public handle_replacement_select_menu(id, key) {
    if(key == 8) { // Back to confirmation
        show_confirm_menu(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED // Cancel
    
    new players[32], num
    get_players(players, num, "ch")
    new available_players[32], available_count = 0
    
    // Build list of available players
    for(new i = 0; i < num; i++) {
        if(!is_player_selected_ct(players[i]) && !is_player_selected_t(players[i])) {
            available_players[available_count++] = players[i]
        }
    }
    
    if(key < available_count) {
        new replacement_id = available_players[key]
        replace_player_in_slot(replacement_id)
        show_confirm_menu(id)
    }
    
    return PLUGIN_HANDLED
}

public replace_player_in_slot(replacement_id) {
    if(g_ReplacementContext == 1) { // CT replacement
        new old_player = g_PlayerSlots_CT[g_EditingPlayerSlot]
        
        // Remove old player
        if(old_player > 0) {
            g_SelectedCT[old_player] = 0
            if(is_user_connected(old_player)) {
                cs_set_user_team(old_player, CS_TEAM_SPECTATOR)
            }
        }
        
        // Add new player
        g_PlayerSlots_CT[g_EditingPlayerSlot] = replacement_id
        g_SelectedCT[replacement_id] = 1
        
    } else if(g_ReplacementContext == 2) { // T replacement
        new old_player = g_PlayerSlots_T[g_EditingPlayerSlot]
        
        // Remove old player
        if(old_player > 0) {
            g_SelectedT[old_player] = 0
            if(is_user_connected(old_player)) {
                cs_set_user_team(old_player, CS_TEAM_SPECTATOR)
            }
        }
        
        // Add new player
        g_PlayerSlots_T[g_EditingPlayerSlot] = replacement_id
        g_SelectedT[replacement_id] = 1
    }
    
    new player_name[32], old_name[32]
    get_user_name(replacement_id, player_name, sizeof(player_name))
    
    client_print(g_AdminID, print_chat, "[Tournament] Player replaced with %s", player_name)
}

public show_rules_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Rules\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. Disconnect Pause: %s^n", 
        g_RuleDisconnectPause ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "^n\rDisconnect Pause:^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wWhen enabled, tournament pauses^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wfor player replacement when^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wsomeone disconnects.^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \yBack to Main Menu")
    
    show_menu(id, 1023, menu, -1, "RulesMenu")
}

public handle_rules_menu(id, key) {
    switch(key) {
        case 0: { // Toggle disconnect pause
            g_RuleDisconnectPause = !g_RuleDisconnectPause
            client_print(id, print_chat, "[Tournament] Disconnect pause rule %s", 
                g_RuleDisconnectPause ? "enabled" : "disabled")
            show_rules_menu(id)
        }
        case 9: show_tournament_menu(id) // Back to main
    }
    return PLUGIN_HANDLED
}

public handle_player_disconnect(disconnected_id) {
    if(!g_RuleDisconnectPause) return
    
    new disconnected_name[32]
    get_user_name(disconnected_id, disconnected_name, sizeof(disconnected_name))
    
    client_print(g_AdminID, print_chat, "[Tournament] Player %s disconnected. Check your menu for replacement options.", disconnected_name)
    
    // Determine which team the player was on
    if(is_player_selected_ct(disconnected_id)) {
        g_ReplacementContext = 1
        g_EditingTeam = 1
        // Find the slot
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_CT[i] == disconnected_id) {
                g_EditingPlayerSlot = i
                break
            }
        }
    } else if(is_player_selected_t(disconnected_id)) {
        g_ReplacementContext = 2
        g_EditingTeam = 2
        // Find the slot
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_T[i] == disconnected_id) {
                g_EditingPlayerSlot = i
                break
            }
        }
    }
    
    show_disconnect_menu(g_AdminID, disconnected_id)
}

public show_disconnect_menu(id, disconnected_id) {
    new menu[512], len = 0
    new player_name[32]
    get_user_name(disconnected_id, player_name, sizeof(player_name))
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rPlayer Disconnected\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rPlayer: \w%s^n", player_name)
    len += formatex(menu[len], sizeof(menu) - len, "\rTeam: \w%s^n^n", 
        g_ReplacementContext == 1 ? "CT" : "T")
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yReplace Player^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \rContinue Without Replacement^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rIgnore")
    
    show_menu(id, 1023, menu, -1, "DisconnectMenu")
}

public handle_disconnect_menu(id, key) {
    switch(key) {
        case 0: { // Replace player
            show_replacement_players(id)
        }
        case 1: { // Continue without replacement
            client_print(0, print_chat, "[Tournament] Continuing tournament with reduced team size.")
            
            // Clear the disconnected player's slot
            if(g_ReplacementContext == 1) {
                g_PlayerSlots_CT[g_EditingPlayerSlot] = 0
                g_SelectedCT[g_DisconnectedPlayer] = 0
                g_CTCount--
            } else if(g_ReplacementContext == 2) {
                g_PlayerSlots_T[g_EditingPlayerSlot] = 0
                g_SelectedT[g_DisconnectedPlayer] = 0
                g_TCount--
            }
        }
        case 9: return PLUGIN_HANDLED // Ignore
    }
    return PLUGIN_HANDLED
}

// Utility functions
public start_tournament() {
    g_TournamentState = TOURNAMENT_ACTIVE
    
    // Populate player slots
    populate_player_slots()
    
    // Move selected players to their teams
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(is_user_connected(i)) {
            if(is_player_selected_ct(i)) {
                cs_set_user_team(i, CS_TEAM_CT)
            } else if(is_player_selected_t(i)) {
                cs_set_user_team(i, CS_TEAM_T)
            } else {
                cs_set_user_team(i, CS_TEAM_SPECTATOR)
            }
        }
    }
    
    client_print(0, print_chat, "[Tournament] All non-tournament players have been moved to spectator.")
}

public end_tournament() {
    g_TournamentState = TOURNAMENT_IDLE
    reset_selections()
    reset_player_slots()
    
    // Allow all players to join teams freely
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        client_print(id, print_chat, "[Tournament] Tournament ended. You can now join teams freely.")
    }
}

public reset_selections() {
    for(new i = 0; i < MAX_PLAYERS; i++) {
        g_SelectedCT[i] = 0
        g_SelectedT[i] = 0
    }
    g_CTCount = 0
    g_TCount = 0
}

public reset_player_slots() {
    for(new i = 0; i < TEAM_SIZE; i++) {
        g_PlayerSlots_CT[i] = 0
        g_PlayerSlots_T[i] = 0
    }
}

public populate_player_slots() {
    new ct_slot = 0, t_slot = 0
    
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(is_player_selected_ct(i) && ct_slot < TEAM_SIZE) {
            g_PlayerSlots_CT[ct_slot++] = i
        }
        if(is_player_selected_t(i) && t_slot < TEAM_SIZE) {
            g_PlayerSlots_T[t_slot++] = i
        }
    }
}

public toggle_ct_selection(id) {
    if(g_SelectedCT[id]) {
        g_SelectedCT[id] = 0
        g_CTCount--
    } else if(g_CTCount < TEAM_SIZE) {
        g_SelectedCT[id] = 1
        g_CTCount++
    }
}

public toggle_t_selection(id) {
    if(g_SelectedT[id]) {
        g_SelectedT[id] = 0
        g_TCount--
    } else if(g_TCount < TEAM_SIZE) {
        g_SelectedT[id] = 1
        g_TCount++
    }
}

public bool:is_player_selected_ct(id) {
    return bool:g_SelectedCT[id]
}

public bool:is_player_selected_t(id) {
    return bool:g_SelectedT[id]
}

public remove_from_selected(id) {
    if(g_SelectedCT[id]) {
        g_SelectedCT[id] = 0
        g_CTCount--
    }
    if(g_SelectedT[id]) {
        g_SelectedT[id] = 0
        g_TCount--
    }
}

public remove_from_slots(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) {
            g_PlayerSlots_CT[i] = 0
        }
        if(g_PlayerSlots_T[i] == id) {
            g_PlayerSlots_T[i] = 0
        }
    }
}

public enforce_team_assignments() {
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(!is_user_connected(i)) continue
        
        new current_team = cs_get_user_team(i)
        
        if(is_player_selected_ct(i) && current_team != CS_TEAM_CT) {
            cs_set_user_team(i, CS_TEAM_CT)
        } else if(is_player_selected_t(i) && current_team != CS_TEAM_T) {
            cs_set_user_team(i, CS_TEAM_T)
        } else if(!is_player_selected_ct(i) && !is_player_selected_t(i) && current_team != CS_TEAM_SPECTATOR) {
            cs_set_user_team(i, CS_TEAM_SPECTATOR)
        }
    }
}

public bool:is_tournament_admin(id) {
    new authid[32]
    get_user_authid(id, authid, sizeof(authid))
    
    // Check if file exists and contains the user's SteamID
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

public on_team_change(id) {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // Prevent unauthorized team changes during tournament
        set_task(0.1, "check_team_change", id)
    }
}

public check_team_change(id) {
    if(!is_user_connected(id)) return
    
    new current_team = cs_get_user_team(id)
    new should_be_team = CS_TEAM_SPECTATOR
    
    if(is_player_selected_ct(id)) {
        should_be_team = CS_TEAM_CT
    } else if(is_player_selected_t(id)) {
        should_be_team = CS_TEAM_T
    }
    
    if(current_team != should_be_team) {
        cs_set_user_team(id, should_be_team)
        client_print(id, print_chat, "[Tournament] You cannot change teams during tournament.")
    }
}

public bool:equal_steamids(id1, id2) {
    new authid1[32], authid2[32]
    get_user_authid(id1, authid1, sizeof(authid1))
    get_user_authid(id2, authid2, sizeof(authid2))
    return equal(authid1, authid2)
}

public bool:was_player_in_ct_slot(id, slot) {
    // This would require storing historical data
    // For now, return false - can be enhanced
    return false
}

public bool:was_player_in_t_slot(id, slot) {
    // This would require storing historical data
    // For now, return false - can be enhanced
    return false
}

public remove_replacement_from_ct() {
    // Logic to remove replacement player from CT team
    // when original player reconnects
}

public remove_replacement_from_t() {
    // Logic to remove replacement player from T team  
    // when original player reconnects
}

public on_round_start() {
    if(g_TournamentState == TOURNAMENT_ACTIVE) {
        // Additional round start checks during tournament
        set_task(1.0, "post_round_start_check")
    }
}

public post_round_start_check() {
    // Ensure all tournament rules are enforced at round start
    check_tournament_status()
}