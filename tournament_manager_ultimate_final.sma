// CONTINUATION OF tournament_manager_ultimate.sma
// Add this to the end of the previous file

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

// Add all other missing functions with essential implementations...