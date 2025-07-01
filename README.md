# CS 1.6 Tournament Manager Plugin

A comprehensive tournament management plugin for Counter-Strike 1.6 servers, designed to facilitate organized matches with advanced team selection, player management, and administrative controls.

## Features

### Core Tournament Management
- **Start/End Tournament**: Full tournament lifecycle management
- **Team Selection**: Interactive menus for selecting 5 players per team (CT/T)
- **Player Toggle Selection**: Visual indicators for selected players (✓/[ ])
- **Confirmation System**: Review and confirm selections before starting
- **Admin Access Control**: SteamID-based admin authentication

### Advanced Player Management
- **Player Replacement**: Replace players during team selection
- **Reconnection Handling**: Restore disconnected players to their original teams
- **Spectator Enforcement**: Force non-tournament players to spectator
- **Team Assignment Enforcement**: Prevent unauthorized team changes

### Rules Configuration
- **Disconnect Pause Rule**: Toggle tournament pause on player disconnection
  - **Enabled**: Admin gets replacement menu when player disconnects
  - **Disabled**: Tournament continues with reduced team size

### Real-time Monitoring
- **2-Second Checks**: Comprehensive system monitoring every 2 seconds
- **Team Integrity**: Verify player positions and team assignments
- **Spectator Enforcement**: Ensure non-tournament players stay in spectator
- **Player Count Validation**: Track and validate team sizes

### Menu System
- **Tournament Manager Menu** (`/ts`)
  - Start Tournament
  - End Tournament  
  - Rules Configuration
- **Team Selection Menus**
  - CT Team Selection (5 players)
  - T Team Selection (5 players)
- **Confirmation Menu**
  - Start Tournament
  - Reshow Selected Players
  - Cancel Everything
- **Player Management**
  - View team players
  - Edit/Replace individual players
  - Disconnect handling menus

## Installation

### 1. File Placement
```
cstrike/addons/amxmodx/plugins/
├── tournament_manager.amxx (compiled from tournament_manager.sma)
└── tournament_manager_extended.amxx (compiled from tournament_manager_extended.sma)

cstrike/addons/amxmodx/configs/
└── tournament_admins.cfg
```

### 2. Plugin Compilation
```bash
# Compile the .sma files using AMX Mod X compiler
amxxpc tournament_manager.sma
amxxpc tournament_manager_extended.sma
```

### 3. Plugin Configuration
Add to `plugins.ini`:
```
tournament_manager_extended.amxx
```

### 4. Admin Configuration
Edit `tournament_admins.cfg` and add admin SteamIDs:
```
STEAM_0:1:12345678
STEAM_0:0:87654321
```

## Usage

### Starting a Tournament

1. **Access Tournament Menu**
   ```
   say /ts
   ```

2. **Select Start Tournament**
   - Choose option 1 from the main menu

3. **Select CT Team Players**
   - Choose 5 players from the online player list
   - Players show toggle status: `[✓]` selected, `[ ]` not selected
   - Continue when 5 players are selected

4. **Select T Team Players**
   - Choose 5 players from remaining online players
   - CT players are excluded from T selection
   - Continue when 5 players are selected

5. **Confirm Tournament Start**
   - Review selections
   - Choose "YES - Start Tournament" to begin
   - Or use "Reshow Selected Players" to review/edit teams

### Managing Players During Selection

#### Reviewing Selected Players
1. From confirmation menu, select "Reshow Selected Players"
2. Choose CT Team or T Team to view
3. See detailed player list with slot numbers

#### Replacing Players
1. From team player view, select a player
2. Choose "Replace Player"
3. Select replacement from available players
4. Player is immediately replaced in the team

### Tournament Rules

#### Disconnect Pause Rule
- **Enabled** (default): Tournament pauses when player disconnects
  - Admin receives disconnect notification
  - Menu options: Replace player or continue without replacement
  - If replaced player reconnects, they reclaim their spot
- **Disabled**: Tournament continues with reduced team size

### Administrative Commands

| Command | Description |
|---------|-------------|
| `say /ts` | Open tournament manager menu |
| Menu Option 1 | Start Tournament |
| Menu Option 2 | End Tournament |
| Menu Option 3 | Rules Configuration |

## System Behavior

### Automatic Enforcement
- **Every 2 Seconds**: System checks and enforces all tournament rules
- **New Connections**: Automatically moved to spectator during active tournament
- **Team Changes**: Prevented during tournament for non-tournament players
- **Disconnections**: Handled according to disconnect pause rule setting

### Tournament States
1. **IDLE**: No active tournament
2. **SELECTING_CT**: CT team selection in progress
3. **SELECTING_T**: T team selection in progress
4. **CONFIRMING**: Awaiting tournament start confirmation
5. **ACTIVE**: Tournament is running

### Player Status Tracking
- **Selected Players**: Tracked in team arrays with counts
- **Player Slots**: Each team has 5 numbered slots for players
- **Reconnection Handling**: Original players can reclaim their positions

## Error Handling

### Common Scenarios
- **Insufficient Players**: Menu prevents continuation without 5 players per team
- **Player Disconnection**: Handled according to disconnect pause rule
- **Admin Disconnection**: Tournament continues, but admin controls may be limited
- **Server Restart**: Tournament state is lost (by design for security)

### Security Features
- **Admin Authentication**: Only SteamIDs in config file can access tournament controls
- **Team Enforcement**: Automatic correction of unauthorized team changes
- **Spectator Enforcement**: Non-tournament players forced to spectator

## Troubleshooting

### Plugin Not Loading
- Verify file placement in correct directories
- Check compilation errors in AMX Mod X logs
- Ensure plugin is listed in `plugins.ini`

### Admin Access Denied
- Verify SteamID is correctly added to `tournament_admins.cfg`
- Check SteamID format: `STEAM_0:X:XXXXXXXX`
- Restart server after config changes

### Players Not Moving to Teams
- Check if tournament is in ACTIVE state
- Verify players are properly selected in team arrays
- Review AMX Mod X error logs for CS functions

## Advanced Configuration

### Customization Options
- **TEAM_SIZE**: Change from 5 to different team size (requires recompilation)
- **Check Interval**: Modify from 2 seconds in `check_tournament_status` timer
- **Admin File Path**: Change location of admin configuration file

### Plugin Extensions
The code structure allows for easy extensions:
- Additional rules in the rules menu
- Custom team selection criteria
- Enhanced reconnection logic
- Tournament statistics tracking

## Technical Details

### Dependencies
- AMX Mod X 1.8.0+
- Counter-Strike module
- Fun module
- CSstrike module

### Performance
- Minimal server impact with 2-second check intervals
- Efficient player tracking using arrays
- Menu system optimized for responsiveness

### Compatibility
- Tested with CS 1.6
- Compatible with most CS mods
- Works with other AMX Mod X plugins

## Support

For issues, feature requests, or contributions:
1. Check the troubleshooting section
2. Review AMX Mod X logs for errors
3. Verify configuration files are correct
4. Test with minimal plugin setup

## Version History

### v1.0
- Initial release with full tournament management
- Team selection and player management
- Disconnect handling and reconnection
- Admin authentication system
- Real-time monitoring and enforcement