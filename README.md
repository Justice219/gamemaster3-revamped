# GameMaster 3 - Advanced Gamemaster Tools for Garry's Mod

A comprehensive suite of creative tools designed specifically for gamemasters running events in SWRP, MRP, and DarkRP servers. GM3 provides powerful, non-generic tools that go beyond standard admin functionality to enhance roleplay and event management.

## 🎮 Overview

GameMaster 3 (GM3) is built on the Lyx framework and provides gamemasters with creative control over their events through an intuitive interface and powerful tool system. Unlike generic admin tools, GM3 focuses on narrative control, cinematic experiences, and strategic gameplay elements.

## ✨ Key Features

### Advanced UI System
- **Color Selector Component** - Visual color picker with RGB sliders, hex input, and 18 preset colors
- **Player Selector** - Intuitive player selection with search, team indicators, and visual preview
- **Modular Tool System** - Dynamic parameter types including strings, numbers, booleans, players, and colors
- **Category Organization** - Tools grouped by function (Visual, Roleplay, Utility, etc.)

### Creative Tools

#### 🎬 **Scene Director**
Create cinematic sequences for narrative events:
- Multiple camera modes (fixed, follow, orbit, free)
- Dynamic subtitle system with speaker identification
- Visual effects (fade in/out, letterbox, blur, slow-motion, black & white)
- Player freezing and HUD control during scenes
- Perfect for briefings, cutscenes, and dramatic moments

#### 🗺️ **Territory Control**
Manage faction-based strategic gameplay:
- Visual 3D zone boundaries with real-time updates
- Multiple capture modes (contested, majority, exclusive)
- Faction point system for holding territories
- HUD integration with capture progress
- Spawn protection and vehicle inclusion options
- Ideal for planetary control and faction warfare

#### 🎭 **Puppet Master**
Control player movements and actions:
- Force players to perform specific actions
- Control movement, jumping, and interactions
- Create synchronized performances
- Perfect for scripted events and demonstrations

#### 🌀 **Reality Glitch**
Create surreal and disorienting effects:
- Visual distortions and glitches
- Time manipulation effects
- Reality-bending experiences
- Ideal for horror events or anomaly scenarios

## 📦 Complete Tool List

### Visual Effects
- **Blind** - Apply colored blindness effects with color selector
- **Glow** - Make players glow with custom or random colors
- **Black Screen** - Fade to black for dramatic transitions
- **Screen Message** - Display custom messages on screen
- **Screen Timer** - Show countdown timers for events
- **Player ESP** - Toggle ESP visibility for tactical overview
- **Drunk** - Apply disorientation effects

### Player Control
- **Freeze** - Freeze players with multiple modes and ice effects
- **Invisible** - Toggle player visibility with various modes
- **God Mode** - Grant temporary or permanent invincibility
- **Teleport** - Advanced teleportation with multiple destination options
- **Clone** - Create player clones that mimic movements
- **Levitate** - Launch players into the air
- **Speed** - Modify player movement speed
- **Model Size** - Scale player models
- **Jetpack** - Grant temporary jetpack abilities

### Utility
- **Kill Player/Entities** - Selective removal tools
- **Clear Lag** - Performance optimization
- **Lock Doors** - Control map access
- **Toggle Flashlights** - Server-wide flashlight control
- **Disable Chat** - Manage chat commands
- **Disable Lights** - Control map lighting
- **Low Gravity** - Modify server physics

### Event Tools
- **Lives System** - Set respawn limits for events
- **Cutscene** - Play YouTube videos as cutscenes (Chromium required)
- **Confetti Pop** - Celebration effects
- **Screen Shake** - Environmental effects
- **Molest** - Apply random chaotic effects

## 🚀 Installation

1. Ensure you have the Lyx framework installed
2. Place the `gamemaster3-revamped` folder in your `garrysmod/addons/` directory
3. The addon will automatically load with Lyx

## 📋 Requirements

- Garry's Mod Server
- Lyx Framework (required dependency)
- Chromium x64 branch (for video cutscenes)

## 🎯 Usage

### For Gamemasters
1. Open the GM3 menu (default bind configured in Lyx)
2. Navigate to the Modules tab
3. Select a tool from the categorized list
4. Configure parameters using the intuitive UI
5. Click "Run" to execute the tool

### For Developers
Tools follow the GM3Module structure:
```lua
local tool = GM3Module.new(
    "Tool Name",
    "Description",
    "Author",
    {
        ["Parameter Name"] = {
            type = "string|number|boolean|player|color",
            def = defaultValue
        }
    },
    function(ply, args)
        -- Tool logic here
    end,
    "Category"
)
gm3:addTool(tool)
```

## 🔧 Configuration

Tools can be customized by editing files in `lua/gm3/tools/`. Each tool is self-contained and follows a consistent structure for easy modification.

## 🌐 Network Communication

GM3 uses Lyx's optimized networking system with registered network strings for each tool. This ensures minimal bandwidth usage and maximum performance during events.

## 🎨 Customization

### Adding New Tools
1. Create a new file in `lua/gm3/tools/` following the naming convention `sh_gm3_tool_[name].lua`
2. Use the GM3Module structure
3. Register network strings as needed
4. The tool will automatically appear in the menu

### Custom Categories
Tools can be assigned to custom categories by specifying the category parameter in `GM3Module.new()`

## 📊 Performance

- Efficient timer-based systems with automatic cleanup
- Optimized network messages
- Minimal server impact
- Smart resource management

## 🤝 Contributing

Contributions are welcome! When adding new tools:
1. Follow the existing code structure
2. Include proper comments and documentation
3. Test thoroughly in different scenarios
4. Ensure compatibility with common gamemodes

## 📝 License

This addon is provided as-is for use on Garry's Mod servers running the Lyx framework.

## 🆘 Support

For issues, feature requests, or questions:
- Check the GM3_CLAUDE_DOCUMENTATION.md for detailed technical information
- Review existing tools for implementation examples
- Ensure Lyx framework is properly installed and configured

## 🎖️ Credits

- **GM3 Core System** - Original framework and module system
- **Tool Authors** - Individual credits preserved in each tool file
- **Lyx Framework** - Underlying infrastructure
- **Community** - Feedback and testing

---

*GameMaster 3 - Empowering gamemasters with creative control*