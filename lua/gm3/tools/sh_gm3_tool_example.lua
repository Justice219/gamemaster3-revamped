--[[
!   ________    _____  ________     _____             .___    .__          
+  /  _____/   /     \ \_____  \   /     \   ____   __| _/_ __|  |   ____  
? /   \  ___  /  \ /  \  _(__  <  /  \ /  \ /  _ \ / __ |  |  \  | _/ __ \ 
! \    \_\  \/    Y    \/       \/    Y    (  <_> ) /_/ |  |  /  |_\  ___/ 
+ \______  /\____|__  /______  /\____|__  /\____/\____ |____/|____/\___  >
?        \/         \/       \/         \/            \/               \/  

+ GM3 is a system for Garry's Mod that allows you to create your gamemaster tools
+ The GM3Module class is used to create modular tools for the GM3 System

? GM3Module.new(name, description, author, args, func)
+ name: The name of the tool
+ description: The description of the tool
+ author: The author of the tool
+ args: The arguments of the tool
+ func: The function of the tool

! This file contains an example tool for GM3
? You can use this as a template for your own tools
--]]
gm3 = gm3

if SERVER then
    --! IT IS VERY IMPORTANT YOU INCLUDE BOTH OF THESE REFERENCES !-
    --+ THEY ALLOW YOU TO USE GM3 AND MY LYX LIBRARY
    gm3 = gm3
    lyx = lyx

    --+ CREATE A NEW GM3MODULE
    local tool = GM3Module.new(
        "Example", --? name
        "This is an example tool demonstrating all argument types", --? description
        "GM3", --? author
        { --? arguments
            ["Target Player"] = {
                type = "player",
                def = "" -- Default empty, or could be a specific SteamID
            },
            ["Message"] = {
                type = "string",
                def = "Hello World!"
            },
            ["Duration"] = {
                type = "number",
                def = 10
            },
            ["Enabled"] = {
                type = "boolean",
                def = true
            }
        },
        function(ply, args) --? func
            -- Find the target player by SteamID
            local targetPlayer = nil
            if args["Target Player"] and args["Target Player"] ~= "" then
                for _, p in ipairs(player.GetAll()) do
                    if p:SteamID() == args["Target Player"] then
                        targetPlayer = p
                        break
                    end
                end
            end

            local targetName = targetPlayer and targetPlayer:Nick() or "No player selected"

            lyx:MessageServer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "GM3 Example",
                ["color2"] = Color(255,255,255),
                ["text"] = string.format("Target: %s | Message: %s | Duration: %d | Enabled: %s",
                    targetName, args["Message"], args["Duration"], tostring(args["Enabled"]))
            })

            -- If a player is selected and enabled, do something with them
            if targetPlayer and args["Enabled"] then
                -- Example: Send them a notification
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "GM3",
                    ["color2"] = Color(255,255,255),
                    ["text"] = args["Message"],
                    ["ply"] = targetPlayer
                })
            end
        end,
        "Utility" --? category - Options: Visual, Control, Communication, Environment, Utility
    )

    --+ Add the tool to the GM3 tool list
    --! THIS IS VERY IMPORTANT !--
    gm3:addTool(tool)
end

if CLIENT then
    // if your tool has any client side code, put it here
    // an example would be a menu or drawing, yada yada

    gm3.Logger:Log("Example tool loaded!")

end