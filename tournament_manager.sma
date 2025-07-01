#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN "Tournament Manager"
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
    
    register_event("TeamInfo", "on_team_change", "a")
    
    // Start the check timer
    g_CheckTimer = set_task(2.0, "check_tournament_status", 0, "", 0, "b")
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
                handle_player_disconnect(id)
            }
        }
    }
    
    // Remove from selected lists
    remove_from_selected(id)
}

public force_spectator(id) {
    if(is_user_connected(id) && g_TournamentState == TOURNAMENT_ACTIVE) {
        cs_set_user_team(id, CS_TEAM_SPECTATOR)
        client_print(id, print_chat, "[Tournament] You've been moved to spectator during active tournament.")
    }
}

public check_tournament_status() {
    if(g_TournamentState != TOURNAMENT_ACTIVE) return
    
    // Check team counts and enforce spectator for non-selected players
    new players[32], num
    get_players(players, num, "ch") // connected and not HLTV
    
    for(new i = 0; i < num; i++) {
        new id = players[i]
        new team = cs_get_user_team(id)
        
        if(!is_player_selected_ct(id) && !is_player_selected_t(id)) {
            if(team != CS_TEAM_SPECTATOR) {
                cs_set_user_team(id, CS_TEAM_SPECTATOR)
                client_print(id, print_chat, "[Tournament] You must stay in spectator during tournament.")
            }
        }
    }
    
    // Check if selected players are in correct teams
    enforce_team_assignments()
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
    g_TournamentState = TOURNAMENT_SELECTING_CT
    show_ct_selection_menu(id)
}

public show_ct_selection_menu(id) {
    new menu[1024], len = 0
    new players[32], num, player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rCT Team Selection\y] \w(\r%d\w/\r5\w)^n^n", g_CTCount)
    
    get_players(players, num, "ch")
    new menu_options = 0
    
    for(new i = 0; i < num; i++) {
        new player_id = players[i]
        if(menu_options >= 8) break // Menu limit
        
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
    
    for(new i = 0; i < num; i++) {
        new player_id = players[i]
        if(menu_options >= 8) break
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
        case 0: show_team_players(id, 1) // CT
        case 1: show_team_players(id, 2) // T
        case 2: show_confirm_menu(id) // Back to confirmation
        case 9: return PLUGIN_HANDLED // Exit
    }
    return PLUGIN_HANDLED
}

public show_team_players(id, team) {
    new menu[1024], len = 0
    new player_name[32]
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\r%s Team Players\y]^n^n", 
        team == 1 ? "CT" : "T")
    
    new count = 0
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        new is_selected = (team == 1) ? is_player_selected_ct(i) : is_player_selected_t(i)
        if(is_selected && is_user_connected(i)) {
            get_user_name(i, player_name, sizeof(player_name))
            len += formatex(menu[len], sizeof(menu) - len, "\w%d. \y%s^n", count + 1, player_name)
            count++
        }
    }
    
    len += formatex(menu[len], sizeof(menu) - len, "^n\w9. \yBack to Reshow Menu^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w0. \rBack to Confirmation")
    
    show_menu(id, 1023, menu, -1, "TeamSelectMenu")
}

public handle_team_select_menu(id, key) {
    if(key == 8) { // Back to reshow
        show_reshow_menu(id)
        return PLUGIN_HANDLED
    }
    if(key == 9) { // Back to confirmation
        show_confirm_menu(id)
        return PLUGIN_HANDLED
    }
    
    // Handle player selection for editing
    // Implementation would continue here for player editing
    
    return PLUGIN_HANDLED
}

public show_rules_menu(id) {
    new menu[512], len = 0
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rTournament Rules\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w1. Disconnect Pause: %s^n", 
        g_RuleDisconnectPause ? "\gEnabled" : "\rDisabled")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \yBack to Main Menu")
    
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
    
    new admin_name[32], disconnected_name[32]
    get_user_name(g_AdminID, admin_name, sizeof(admin_name))
    get_user_name(disconnected_id, disconnected_name, sizeof(disconnected_name))
    
    client_print(g_AdminID, print_chat, "[Tournament] Player %s disconnected. Check your menu for replacement options.", disconnected_name)
    show_disconnect_menu(g_AdminID, disconnected_id)
}

public show_disconnect_menu(id, disconnected_id) {
    new menu[512], len = 0
    new player_name[32]
    get_user_name(disconnected_id, player_name, sizeof(player_name))
    
    len += formatex(menu[len], sizeof(menu) - len, "\y[\rPlayer Disconnected\y]^n^n")
    len += formatex(menu[len], sizeof(menu) - len, "\rPlayer: \w%s^n^n", player_name)
    len += formatex(menu[len], sizeof(menu) - len, "\w1. \yReplace Player^n")
    len += formatex(menu[len], sizeof(menu) - len, "\w2. \rContinue Without Replacement^n")
    len += formatex(menu[len], sizeof(menu) - len, "^n\w0. \rIgnore")
    
    show_menu(id, 1023, menu, -1, "DisconnectMenu")
}

public handle_disconnect_menu(id, key) {
    switch(key) {
        case 0: { // Replace player
            // Show available players for replacement
            show_replacement_players(id)
        }
        case 1: { // Continue without replacement
            client_print(0, print_chat, "[Tournament] Continuing tournament with reduced team size.")
        }
        case 9: return PLUGIN_HANDLED // Ignore
    }
    return PLUGIN_HANDLED
}

public show_replacement_players(id) {
    // Implementation for showing available replacement players
    // This would show all online players not currently selected
}

public handle_replace_player_menu(id, key) {
    // Implementation for handling player replacement
    return PLUGIN_HANDLED
}

// Utility functions
public start_tournament() {
    g_TournamentState = TOURNAMENT_ACTIVE
    
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
}

public end_tournament() {
    g_TournamentState = TOURNAMENT_IDLE
    reset_selections()
    
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

public enforce_team_assignments() {
    for(new i = 1; i <= MAX_PLAYERS; i++) {
        if(!is_user_connected(i)) continue
        
        new current_team = cs_get_user_team(i)
        
        if(is_player_selected_ct(i) && current_team != CS_TEAM_CT) {
            cs_set_user_team(i, CS_TEAM_CT)
        } else if(is_player_selected_t(i) && current_team != CS_TEAM_T) {
            cs_set_user_team(i, CS_TEAM_T)
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
        // Prevent team changes during tournament unless authorized
        set_task(0.1, "check_team_change", id)
    }
}