// Tournament Manager Enhanced Functions
// This file contains all the missing logic and enhancements

// ===============================
// MISSING UTILITY FUNCTIONS
// ===============================

public auto_select_ct_players() {
    new players[32], num
    get_players(players, num, "ch")
    
    // Clear current selections
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        g_SelectedCT[i] = 0
    }
    g_CTCount = 0
    
    // Randomly select 5 players
    new selected_count = 0
    new attempts = 0
    
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
    
    // Clear current T selections
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        g_SelectedT[i] = 0
    }
    g_TCount = 0
    
    // Randomly select 5 players (excluding CT players)
    new selected_count = 0
    new attempts = 0
    
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

public find_player_in_tournament(id) {
    // Check CT slots
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) {
            return (i + 1) // Return slot number (1-based)
        }
    }
    
    // Check T slots
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_T[i] == id) {
            return (i + TEAM_SIZE + 1) // Return slot number (6-10 for T team)
        }
    }
    
    return -1 // Not found
}

public find_player_slot_ct(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] == id) {
            return i
        }
    }
    return -1
}

public find_player_slot_t(id) {
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_T[i] == id) {
            return i
        }
    }
    return -1
}

public find_player_in_history(const authid[]) {
    // Check CT history
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(equal(g_PlayerHistory_CT[i], authid)) {
            return i // CT slot
        }
    }
    
    // Check T history
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(equal(g_PlayerHistory_T[i], authid)) {
            return (i + TEAM_SIZE) // T slot (offset by TEAM_SIZE)
        }
    }
    
    return -1
}

public cleanup_player_from_selection(id) {
    // Remove from CT
    if(g_SelectedCT[id]) {
        g_SelectedCT[id] = 0
        g_CTCount--
        
        // Remove from CT slots
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_CT[i] == id) {
                g_PlayerSlots_CT[i] = 0
                break
            }
        }
    }
    
    // Remove from T
    if(g_SelectedT[id]) {
        g_SelectedT[id] = 0
        g_TCount--
        
        // Remove from T slots
        for(new i = 0; i < TEAM_SIZE; i++) {
            if(g_PlayerSlots_T[i] == id) {
                g_PlayerSlots_T[i] = 0
                break
            }
        }
    }
}

public toggle_ct_selection_enhanced(id) {
    if(g_SelectedCT[id]) {
        // Deselect
        g_SelectedCT[id] = 0
        g_CTCount--
        
        // Remove from slot
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
        // Select
        g_SelectedCT[id] = 1
        g_CTCount++
        
        // Add to first available slot
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
        // Deselect
        g_SelectedT[id] = 0
        g_TCount--
        
        // Remove from slot
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
        // Select
        g_SelectedT[id] = 1
        g_TCount++
        
        // Add to first available slot
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
// MENU NAVIGATION SYSTEM
// ===============================

public push_menu_stack(id, const menu_name[]) {
    if(g_MenuStackSize[id] < 10) {
        copy(g_MenuStack[id][g_MenuStackSize[id]], 31, menu_name)
        g_MenuStackSize[id]++
    }
}

public pop_menu_stack(id) {
    if(g_MenuStackSize[id] > 0) {
        g_MenuStackSize[id]--
        
        if(g_MenuStackSize[id] > 0) {
            // Go back to previous menu
            new previous_menu[32]
            copy(previous_menu, sizeof(previous_menu), g_MenuStack[id][g_MenuStackSize[id] - 1])
            
            if(equal(previous_menu, "TournamentMain")) {
                show_tournament_menu(id)
            } else if(equal(previous_menu, "RulesMenu")) {
                show_rules_menu_enhanced(id)
            } else if(equal(previous_menu, "CTSelection")) {
                show_ct_selection_menu_enhanced(id)
            } else if(equal(previous_menu, "TSelection")) {
                show_t_selection_menu_enhanced(id)
            }
            // Add more menu navigation as needed
        } else {
            // Return to main menu
            show_tournament_menu(id)
        }
    }
}

public clear_menu_stack(id) {
    g_MenuStackSize[id] = 0
}

public reset_menu_stacks() {
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        clear_menu_stack(i)
    }
}

// ===============================
// PLAYER HISTORY SYSTEM
// ===============================

public save_player_to_history(id, team, slot) {
    new authid[MAX_STEAMID_LENGTH], name[MAX_NAME_LENGTH]
    get_user_authid(id, authid, sizeof(authid))
    get_user_name(id, name, sizeof(name))
    
    if(team == 1) { // CT
        copy(g_PlayerHistory_CT[slot], sizeof(g_PlayerHistory_CT[]), authid)
        copy(g_PlayerHistory_CT_Names[slot], sizeof(g_PlayerHistory_CT_Names[]), name)
    } else if(team == 2) { // T
        copy(g_PlayerHistory_T[slot], sizeof(g_PlayerHistory_T[]), authid)
        copy(g_PlayerHistory_T_Names[slot], sizeof(g_PlayerHistory_T_Names[]), name)
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

public populate_player_slots_enhanced() {
    new ct_slot = 0, t_slot = 0
    
    // Populate CT slots and save to history
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(is_player_selected_ct(i) && ct_slot < TEAM_SIZE) {
            g_PlayerSlots_CT[ct_slot] = i
            save_player_to_history(i, 1, ct_slot)
            ct_slot++
        }
    }
    
    // Populate T slots and save to history
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(is_player_selected_t(i) && t_slot < TEAM_SIZE) {
            g_PlayerSlots_T[t_slot] = i
            save_player_to_history(i, 2, t_slot)
            t_slot++
        }
    }
}

// ===============================
// ENHANCED MONITORING FUNCTIONS
// ===============================

public handle_slot_disconnect(team, slot, player_id) {
    new name[MAX_NAME_LENGTH], authid[MAX_STEAMID_LENGTH]
    get_user_name(player_id, name, sizeof(name))
    get_user_authid(player_id, authid, sizeof(authid))
    
    if(team == 1) { // CT
        g_PlayerSlots_CT[slot] = 0
        g_CTCount--
    } else { // T
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

public check_player_behavior(id) {
    // Check for suspicious behavior
    new current_team = cs_get_user_team(id)
    
    // Verify player is not trying to exploit
    if(current_team == CS_TEAM_SPECTATOR) {
        // Tournament player shouldn't be in spectator unless disconnecting
        if(is_player_selected_ct(id)) {
            cs_set_user_team(id, CS_TEAM_CT)
        } else if(is_player_selected_t(id)) {
            cs_set_user_team(id, CS_TEAM_T)
        }
    }
}

public enforce_basic_team_rules() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        
        if(is_player_selected_ct(id)) {
            if(cs_get_user_team(id) != CS_TEAM_CT) {
                cs_set_user_team(id, CS_TEAM_CT)
            }
        } else if(is_player_selected_t(id)) {
            if(cs_get_user_team(id) != CS_TEAM_T) {
                cs_set_user_team(id, CS_TEAM_T)
            }
        } else {
            if(cs_get_user_team(id) != CS_TEAM_SPECTATOR) {
                cs_set_user_team(id, CS_TEAM_SPECTATOR)
            }
        }
    }
}

public check_critical_disconnections() {
    // Fast check for critical disconnections
    for(new i = 0; i < TEAM_SIZE; i++) {
        if(g_PlayerSlots_CT[i] > 0 && !is_user_connected(g_PlayerSlots_CT[i])) {
            handle_slot_disconnect(1, i, g_PlayerSlots_CT[i])
        }
        if(g_PlayerSlots_T[i] > 0 && !is_user_connected(g_PlayerSlots_T[i])) {
            handle_slot_disconnect(2, i, g_PlayerSlots_T[i])
        }
    }
}

public monitor_suspicious_activity() {
    // Monitor for suspicious activities during tournament
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        
        // Check for rapid team switching attempts
        // Check for unusual ping spikes
        // Check for potential cheating indicators
        
        new ping = get_user_ping(id)
        if(ping > 500 && (is_player_selected_ct(id) || is_player_selected_t(id))) {
            new name[MAX_NAME_LENGTH]
            get_user_name(id, name, sizeof(name))
            
            if(is_user_connected(g_AdminID)) {
                client_print(g_AdminID, print_chat, "[Tournament] WARNING: %s has high ping (%dms)", name, ping)
            }
        }
    }
}

// ===============================
// TOURNAMENT STATISTICS
// ===============================

public update_tournament_statistics() {
    // Update various tournament statistics
    // This could include round counts, player performance, etc.
    
    // Example: Track round progression
    if(g_RoundNumber > 0) {
        // Calculate tournament duration
        new duration = get_systime() - g_TournamentStartTime
        
        // Log statistical information periodically
        if(duration % 300 == 0) { // Every 5 minutes
            log_tournament_event("STATS_UPDATE", "", "")
        }
    }
}

public monitor_round_progress() {
    // Monitor round progression and handle special cases
    static last_round = 0
    
    if(g_RoundNumber != last_round) {
        last_round = g_RoundNumber
        
        // Round changed, perform round-specific checks
        check_round_integrity()
        update_round_statistics()
    }
}

public check_round_integrity() {
    // Verify tournament integrity at round start
    validate_player_counts_enhanced()
    ensure_proper_team_distribution()
}

public update_round_statistics() {
    // Update round-specific statistics
    new ct_alive = count_alive_players(CS_TEAM_CT)
    new t_alive = count_alive_players(CS_TEAM_T)
    
    // Log round statistics
    log_tournament_event("ROUND_STATS", "", "")
}

public count_alive_players(team) {
    new count = 0
    new players[32], num
    get_players(players, num, "ach")
    
    for(new i = 0; i < num; i++) {
        if(cs_get_user_team(players[i]) == team) {
            count++
        }
    }
    
    return count
}

// ===============================
// ADMIN MANAGEMENT
// ===============================

public ensure_admin_availability() {
    // Ensure there's always an admin available during tournament
    if(g_TournamentState == TOURNAMENT_ACTIVE && !is_user_connected(g_AdminID)) {
        find_replacement_admin()
    }
}

public find_replacement_admin() {
    new players[32], num
    get_players(players, num, "ch")
    
    for(new i = 0; i < num; i++) {
        if(is_tournament_admin(players[i])) {
            g_AdminID = players[i]
            
            new name[MAX_NAME_LENGTH]
            get_user_name(players[i], name, sizeof(name))
            client_print(0, print_chat, "[Tournament] %s is now the tournament admin.", name)
            
            return
        }
    }
    
    // No admin found - tournament might need to be paused
    client_print(0, print_chat, "[Tournament] WARNING: No tournament admin available!")
}

// ===============================
// LOGGING SYSTEM
// ===============================

public log_tournament_event(const event[], const player_name[], const extra_info[]) {
    new timestamp[32]
    get_time("%H:%M:%S", timestamp, sizeof(timestamp))
    
    log_amx("[Tournament] [%s] %s | Player: %s | Info: %s", 
        timestamp, event, player_name, extra_info)
}

// ===============================
// TASK MANAGEMENT
// ===============================

public remove_all_tasks() {
    if(task_exists(g_CheckTimer)) {
        remove_task(g_CheckTimer)
    }
    
    // Remove any other tasks that might be running
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(task_exists(i + 1000)) { // Player-specific tasks
            remove_task(i + 1000)
        }
    }
}

// ===============================
// RULE MANAGEMENT
// ===============================

public reset_rules_to_defaults() {
    g_RuleDisconnectPause = 1
    g_RuleAutoBalance = 1
    g_RuleForceReady = 0
    g_RuleAllowSubstitutes = 1
    g_RuleSpectatorTalk = 0
    
    log_tournament_event("RULES_RESET", "", "defaults")
}

public update_spectator_talk_setting() {
    // Update server cvar for spectator talk
    if(g_RuleSpectatorTalk) {
        server_cmd("sv_alltalk 1")
    } else {
        server_cmd("sv_alltalk 0")
    }
    server_exec()
}