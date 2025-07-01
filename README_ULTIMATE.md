# Tournament Manager Ultimate v2.0

## Complete CS 1.6 Tournament Management System

This is the ultimate single-file Counter-Strike 1.6 tournament plugin that provides comprehensive tournament management with all advanced features and enhanced capabilities.

## 🚀 Features

### Core Tournament System
- **Complete Menu System**: `/ts` command opens the main tournament management interface
- **Team Selection**: Enhanced 5v5 team selection with auto-selection options
- **Tournament Lifecycle**: Start, manage, pause, and end tournaments
- **SteamID-based Admin Authentication**: Secure admin access control

### Enhanced Team Management
- **Smart Team Selection**: Manual selection with toggle indicators
- **Auto-Selection Options**: Random and skill-based team balancing
- **Team Shuffling**: Random shuffle and skill-based redistribution
- **Player Replacement**: Real-time player substitution system
- **Team Editing**: Individual player management and slot editing

### Advanced Disconnect Handling
- **Configurable Rules**: Pause tournament or continue with reduced teams
- **Reconnection System**: Automatic restoration for returning players
- **Replacement Management**: Find substitutes for disconnected players
- **Timeout System**: Configurable wait times for reconnections

### Comprehensive Monitoring
- **Real-time Validation**: 2-second comprehensive system checks
- **Fast Monitoring**: 1-second critical system validation
- **Team Integrity**: Automatic team assignment enforcement
- **Spectator Control**: Force non-tournament players to spectate

### Professional Tournament Features
- **Tournament Status Dashboard**: Live tournament information
- **Player Statistics**: Performance tracking and statistics
- **History Management**: Tournament and player history tracking
- **Advanced Rules Configuration**: Customizable tournament rules
- **Emergency Controls**: Admin override and emergency functions

## 📋 Requirements

- **AMX Mod X**: Version 1.8.2 or higher
- **Counter-Strike 1.6**: Any version
- **Modules Required**:
  - `amxmodx.amxx`
  - `cstrike.amxx` 
  - `fun.amxx`

## 🔧 Installation

### Step 1: Install the Plugin
1. Copy `tournament_manager_complete_ultimate.sma` to `addons/amxmodx/scripting/`
2. Compile the plugin:
   ```bash
   amxmodx/scripting/amxxpc tournament_manager_complete_ultimate.sma
   ```
3. Copy the compiled `.amxx` file to `addons/amxmodx/plugins/`

### Step 2: Configure Admin Access
1. Copy `tournament_admins.cfg` to `addons/amxmodx/configs/`
2. Edit the file and add your SteamIDs:
   ```
   STEAM_0:0:123456
   STEAM_0:1:987654
   ```

### Step 3: Add to Plugin Configuration
Add this line to `addons/amxmodx/configs/plugins.ini`:
```
tournament_manager_complete_ultimate.amxx
```

### Step 4: Restart Server
Restart your Counter-Strike server or change the map to load the plugin.

## 🎮 Usage

### Basic Commands
- `/ts` - Open tournament management menu (admins only)
- `/ready` - Mark yourself as ready
- `/unready` - Mark yourself as unready  
- `/rejoin` - Rejoin tournament after disconnect

### Admin Console Commands
- `tournament_info` - Display tournament status information
- `tournament_status` - Show complete tournament status
- `tournament_force_end` - Force end current tournament

### Starting a Tournament

1. **Open Menu**: Type `/ts` in chat
2. **Quick Setup**: Use "Advanced Setup" → "Quick Random Teams"
3. **Manual Setup**: 
   - Select "Start Tournament"
   - Choose 5 CT players
   - Choose 5 T players
   - Confirm selection
4. **Start**: Click "YES - START TOURNAMENT"

### Managing Active Tournaments

- **View Status**: Use main menu → "Tournament Status"
- **Pause/Resume**: Access pause controls from status menu
- **Player Management**: Replace disconnected players
- **Emergency End**: Use confirmation menu to end tournament

## ⚙️ Configuration Options

### Tournament Rules
Access via main menu → "Rules Configuration":

- **Disconnect Pause**: Pause tournament when players disconnect
- **Auto Balance**: Automatically balance teams
- **Force Ready**: Require all players to be ready
- **Allow Substitutes**: Enable player substitutions
- **Spectator Talk**: Allow spectators to use voice chat

### Advanced Rules
- **Round Time**: 2 minutes (configurable)
- **Freeze Time**: 6 seconds (configurable)
- **Buy Time**: 15 seconds (configurable)
- **Friendly Fire**: Enabled during tournaments

## 🔍 Monitoring Systems

### Comprehensive Check (Every 2 seconds)
- Team integrity validation
- Player assignment enforcement
- Spectator control
- Tournament rules compliance
- Round progress monitoring
- Statistics updates

### Fast Check (Every 1 second)
- Basic team rules enforcement
- Critical disconnection detection
- Suspicious activity monitoring

## 🚨 Troubleshooting

### Common Issues

**"Access denied" message**
- Ensure your SteamID is in `tournament_admins.cfg`
- Check file permissions and location

**Players not moving to correct teams**
- Wait for automatic enforcement (happens every 2 seconds)
- Use "Force Round Restart" from tournament status menu

**Plugin not loading**
- Verify all required modules are loaded
- Check AMX Mod X logs for compilation errors
- Ensure plugin is listed in `plugins.ini`

### Log Files
Check these logs for detailed information:
- `addons/amxmodx/logs/error_*.log` - Error messages
- `addons/amxmodx/logs/L*.log` - Tournament events

## 📊 Advanced Features

### Skill-Based Team Balancing
The plugin includes intelligent team balancing based on:
- Player ping (connection quality)
- Random skill variance
- Tournament history performance

### Player History Tracking
- Maintains history of all tournament participants
- Tracks player performance and statistics
- Enables reconnection to previous slots

### Menu Navigation System
- Smart menu stack management
- Breadcrumb navigation
- Context-sensitive menus
- Quick access shortcuts

### Emergency Controls
- Force tournament end
- Emergency player replacement
- Admin override functions
- System integrity restoration

## 🏆 Tournament Management Best Practices

1. **Pre-Tournament Setup**
   - Ensure minimum 10 players online
   - Configure rules before starting
   - Test admin access

2. **During Tournament**
   - Monitor disconnect notifications
   - Use replacement system for disconnects
   - Keep spare players as substitutes

3. **Post-Tournament**
   - Review tournament statistics
   - Archive important match data
   - Reset system for next tournament

## 📝 Version History

### v2.0 Ultimate (Latest)
- Complete single-file implementation
- All enhanced features integrated
- Professional tournament management
- Comprehensive monitoring system
- Advanced team balancing
- Complete disconnect handling
- Menu navigation system
- Tournament history tracking

## 🔧 Technical Specifications

- **Lines of Code**: 2000+ lines
- **Menu Systems**: 20+ interactive menus
- **Monitoring Frequency**: 1-2 second intervals
- **Player Capacity**: Up to 32 players
- **Tournament Size**: 5v5 teams
- **Admin Capacity**: Unlimited admins via SteamID

## 📞 Support

For support and updates:
- Check server logs for detailed error information
- Verify configuration files are properly formatted
- Ensure all required modules are loaded
- Test with minimal plugin setup first

## 📄 License

This plugin is provided as-is for Counter-Strike 1.6 tournament management. Use and modify according to your server's needs.

---

**Tournament Manager Ultimate v2.0** - The complete solution for professional CS 1.6 tournament management.