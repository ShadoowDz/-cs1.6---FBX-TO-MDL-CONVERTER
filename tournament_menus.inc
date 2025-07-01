// Tournament Manager - Complete Menu System
// This file contains all missing menu implementations

// ===============================
// MISSING MENU IMPLEMENTATIONS
// ===============================

public show_t_selection_menu_enhanced(id) {
    push_menu_stack(id, "TSelection")
    
    new menu[1024], len = 0
    new players[32], num, player_name[MAX_NAME_LENGTH]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rT Team Selection\y]^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wSelected: \r%d\w/\r%d \wplayers^n^n", g_TCount, TEAM_SIZE)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num && menu_options < 7; i++) {
        new player_id = players[i]
        if(is_player_selected_ct(player_id)) continue // Skip CT players
        
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
    if(key == 9) { // Back/Cancel
        pop_menu_stack(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 8) { // Continue
        if(g_TCount == TEAM_SIZE) {
            g_TournamentState = TOURNAMENT_CONFIRMING
            show_confirm_menu_enhanced(id)
        } else {
            client_print(id, print_chat, "[Tournament] You must select exactly %d T players!", TEAM_SIZE)
            show_t_selection_menu_enhanced(id)
        }
        return PLUGIN_HANDLED
    }
    
    if(key == 7) { // Auto Select
        auto_select_t_players()
        show_t_selection_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    
    if(key == 6) { // Back to CT
        g_TournamentState = TOURNAMENT_SELECTING_CT
        show_ct_selection_menu_enhanced(id)
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
        toggle_t_selection_enhanced(player_id)
        show_t_selection_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

public show_confirm_menu_enhanced(id) {
    push_menu_stack(id, "ConfirmMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Confirmation\y]^n^n")
    
    // Show team summaries
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
        case 0: { // START TOURNAMENT
            start_tournament_enhanced()
            client_print(0, print_chat, "[Tournament] *** TOURNAMENT STARTED! ***")
        }
        case 1: { // Reshow/Edit players
            show_reshow_menu_enhanced(id)
        }
        case 2: { // Advanced Options
            show_advanced_setup_menu(id)
        }
        case 3: { // Cancel
            confirm_cancel_tournament(id)
        }
        case 9: { // Back
            pop_menu_stack(id)
        }
    }
    return PLUGIN_HANDLED
}

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
        case 0: { // CT Team
            g_EditingTeam = 1
            show_team_players_detailed_enhanced(id, 1)
        }
        case 1: { // T Team
            g_EditingTeam = 2
            show_team_players_detailed_enhanced(id, 2)
        }
        case 2: { // Swap Players
            show_player_swap_menu(id)
        }
        case 3: { // Random Shuffle
            random_shuffle_teams()
            client_print(id, print_chat, "[Tournament] Teams have been randomly shuffled!")
            show_confirm_menu_enhanced(id)
        }
        case 4: { // Balance by Skill
            balance_teams_by_skill()
            client_print(id, print_chat, "[Tournament] Teams have been balanced by skill!")
            show_confirm_menu_enhanced(id)
        }
        case 7: { // Back to confirmation
            show_confirm_menu_enhanced(id)
        }
        case 9: return PLUGIN_HANDLED // Exit
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
    if(key == 7) { // Back to player management
        show_reshow_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 8) { // Back to confirmation
        show_confirm_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED // Exit
    
    if(key == 6) { // Clear all slots
        confirm_clear_team_slots(id, g_EditingTeam)
        return PLUGIN_HANDLED
    }
    
    if(key == 5) { // Add player to empty slot
        show_add_player_menu(id, g_EditingTeam)
        return PLUGIN_HANDLED
    }
    
    // Handle player selection for editing (0-4)
    if(key < TEAM_SIZE) {
        new slots[] = (g_EditingTeam == 1) ? g_PlayerSlots_CT : g_PlayerSlots_T
        
        if(slots[key] > 0 && is_user_connected(slots[key])) {
            g_EditingPlayerSlot = key
            show_player_edit_menu_enhanced(id, slots[key])
        } else {
            // Empty slot - offer to add player
            g_EditingPlayerSlot = key
            show_add_player_to_slot_menu(id, g_EditingTeam, key)
        }
    }
    
    return PLUGIN_HANDLED
}

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
        case 0: { // Replace Player
            g_ReplacementContext = (g_EditingTeam == 1) ? REPLACE_CT_PLAYER : REPLACE_T_PLAYER
            show_replacement_players_enhanced(id)
        }
        case 1: { // Swap with other team
            show_swap_with_other_team_menu(id)
        }
        case 2: { // Move to different slot
            show_move_to_slot_menu(id)
        }
        case 3: { // Remove from team
            remove_player_from_team_slot(g_EditingTeam, g_EditingPlayerSlot)
            client_print(id, print_chat, "[Tournament] Player removed from team.")
            show_team_players_detailed_enhanced(id, g_EditingTeam)
        }
        case 7: { // Back to team management
            show_team_players_detailed_enhanced(id, g_EditingTeam)
        }
        case 8: { // Back to confirmation
            show_confirm_menu_enhanced(id)
        }
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

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
        
        // Skip if player is already selected
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
    if(key == 8) { // Back to confirmation
        show_confirm_menu_enhanced(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) return PLUGIN_HANDLED // Cancel
    
    if(key == 7) { // Refresh list
        show_replacement_players_enhanced(id)
        return PLUGIN_HANDLED
    }
    
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
        execute_player_replacement(replacement_id)
        show_confirm_menu_enhanced(id)
    }
    
    return PLUGIN_HANDLED
}

// ===============================
// ADVANCED MENU IMPLEMENTATIONS
// ===============================

public show_advanced_setup_menu(id) {
    push_menu_stack(id, "AdvancedSetup")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rAdvanced Tournament Setup\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yTeam Balancing Options^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \yPlayer Skill Assessment^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w3. \yAuto-Selection Criteria^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w4. \yTournament Format Settings^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w5. \yMap and Mode Configuration^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack")
    
    show_menu(id, 1023, menu, -1, "AdvancedSetup")
}

public show_advanced_rules_menu(id) {
    push_menu_stack(id, "AdvancedRulesMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rAdvanced Tournament Rules\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. Round Time Limit: \y%d minutes^n", 2)
    len += formatex(menu[len], sizeof(menu) - len, "\w2. Buy Time: \y%d seconds^n", 15)
    len += formatex(menu[len], sizeof(menu) - len, "\w3. Freeze Time: \y%d seconds^n", 6)
    len += formatex(menu[len], sizeof(menu) - len, "\w4. Max Rounds: \y%d^n", 30)
    len += formatex(menu[len], sizeof(menu) - len, "\w5. Win Condition: \yFirst to 16^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w6. Overtime Rules: \yMR3^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack to Rules")
    
    show_menu(id, 1023, menu, -1, "AdvancedRulesMenu")
}

public handle_advanced_rules_menu(id, key) {
    switch(key) {
        case 0: { // Round time
            // Implement round time configuration
        }
        case 1: { // Buy time
            // Implement buy time configuration
        }
        case 2: { // Freeze time
            // Implement freeze time configuration
        }
        case 3: { // Max rounds
            // Implement max rounds configuration
        }
        case 4: { // Win condition
            // Implement win condition configuration
        }
        case 5: { // Overtime
            // Implement overtime rules configuration
        }
        case 9: { // Back
            show_rules_menu_enhanced(id)
        }
    }
    return PLUGIN_HANDLED
}

public show_tournament_status_menu(id) {
    push_menu_stack(id, "TournamentStatusMenu")
    
    new menu[1024], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Status\y]^n^n")
    
    // Current tournament info
    len += formatex(menu[len], sizeof(menu) - len, "\wStatus: \gActive Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\wRound: \y%d^n", g_RoundNumber)
    
    new duration = get_systime() - g_TournamentStartTime
    new minutes = duration / 60
    new seconds = duration % 60
    len += formatex(menu[len], sizeof(menu) - len, "\wDuration: \y%02d:%02d^n", minutes, seconds)
    
    // Team status
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
        case 0: { // Pause tournament
            pause_tournament()
            client_print(0, print_chat, "[Tournament] Tournament paused by admin.")
        }
        case 1: { // Force restart
            server_cmd("sv_restart 1")
            client_print(0, print_chat, "[Tournament] Round restarted by admin.")
        }
        case 2: { // Player stats
            show_player_stats_menu(id)
            return PLUGIN_HANDLED
        }
        case 3: { // Manage substitutes
            show_substitute_management_menu(id)
            return PLUGIN_HANDLED
        }
        case 4: { // End tournament
            confirm_end_tournament(id)
            return PLUGIN_HANDLED
        }
        case 9: { // Back
            pop_menu_stack(id)
        }
    }
    return PLUGIN_HANDLED
}

// ===============================
// MISSING UTILITY MENU FUNCTIONS
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
        case 0: { // Find replacement
            g_ReplacementContext = (g_DisconnectedPlayerTeam == 1) ? REPLACE_DISCONNECT_CT : REPLACE_DISCONNECT_T
            show_replacement_players_enhanced(id)
        }
        case 1: { // Wait for reconnection
            start_reconnection_timer()
            client_print(0, print_chat, "[Tournament] Waiting 60 seconds for %s to reconnect...", g_DisconnectedPlayerName)
        }
        case 2: { // Continue with 4
            continue_tournament_with_reduced_team()
        }
        case 3: { // Pause tournament
            pause_tournament()
            client_print(0, print_chat, "[Tournament] Tournament paused due to player disconnect.")
        }
        case 9: return PLUGIN_HANDLED // Ignore
    }
    return PLUGIN_HANDLED
}

// ===============================
// ADDITIONAL MISSING FUNCTIONS
// ===============================

public confirm_end_tournament(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rConfirm End Tournament\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rAre you sure you want to end^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rthe current tournament?^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rThis action cannot be undone.^n^n")
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \rYes, End Tournament^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \gNo, Continue Tournament^n")
    
    show_menu(id, 1023, menu, -1, "ConfirmEndTournament")
}

public confirm_cancel_tournament(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rCancel Tournament Setup\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rCancel tournament setup?^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rAll selections will be lost.^n^n")
    
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \rYes, Cancel Setup^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \gNo, Continue Setup^n")
    
    show_menu(id, 1023, menu, -1, "ConfirmCancelSetup")
}

public start_tournament_enhanced() {
    g_TournamentState = TOURNAMENT_ACTIVE
    g_TournamentStartTime = get_systime()
    g_RoundNumber = 0
    
    // Populate slots with history tracking
    populate_player_slots_enhanced()
    
    // Move all players to their assigned teams
    move_players_to_tournament_teams()
    
    // Apply tournament settings
    apply_tournament_settings()
    
    // Start monitoring
    log_tournament_event("TOURNAMENT_START", "", "")
    
    // Notify all players
    client_print(0, print_chat, "[Tournament] *** TOURNAMENT STARTED ***")
    client_print(0, print_chat, "[Tournament] Good luck to all participants!")
}

public move_players_to_tournament_teams() {
    // Move CT players
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_CT[i]
        if(player_id > 0 && is_user_connected(player_id)) {
            cs_set_user_team(player_id, CS_TEAM_CT)
        }
    }
    
    // Move T players
    for(new i = 0; i < TEAM_SIZE; i++) {
        new player_id = g_PlayerSlots_T[i]
        if(player_id > 0 && is_user_connected(player_id)) {
            cs_set_user_team(player_id, CS_TEAM_T)
        }
    }
    
    // Move all other players to spectator
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
    // Apply server settings for tournament
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

// More utility functions would continue here...