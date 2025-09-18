gm3 = gm3
lyx = lyx

--[[
--! Internal GM3 Chat Handler
--! Updated to use proper LYX chat command system with enhanced security
--]]

-- Register the network string immediately to ensure it's available
if SERVER then
    util.AddNetworkString("gm3:menu:open")
end

do
    --[[
        Register the main GM3 menu command using LYX's secure command system
        Includes permission checking and proper error handling
        Delayed to ensure GM3 systems AND network strings are initialized
    ]]
    timer.Simple(0.5, function()  -- Small delay to ensure GM3 systems are initialized
        gm3.Logger:Log("Attempting to register !gm3 command...")

        local success, err = pcall(function()
            return lyx:ChatAddCommand("gm3", {
                prefix = "!",
                func = function(ply, args)
                    gm3.Logger:Log("!gm3 command invoked by: " .. (IsValid(ply) and ply:Nick() or "invalid player"))

                    -- Validate player
                    if not IsValid(ply) then
                        gm3.Logger:Log("ERROR: Invalid player in !gm3 command", 3)
                        return
                    end

                    gm3.Logger:Log("Player usergroup: " .. ply:GetUserGroup())
                    gm3.Logger:Log("Checking security for player: " .. ply:Nick())

                    -- Security check to ensure player has permission
                    local secSuccess, secErr = pcall(function()
                        return gm3:SecurityCheck(ply)
                    end)

                    if not secSuccess then
                        gm3.Logger:Log("ERROR in SecurityCheck: " .. tostring(secErr), 3)
                        ply:ChatPrint("Error checking permissions. Please contact an administrator.")
                        return
                    end

                    local hasAccess = secErr -- secErr contains the return value when pcall succeeds
                    gm3.Logger:Log("Security check result: " .. tostring(hasAccess))

                    if not hasAccess then
                        ply:ChatPrint("You don't have permission to access GM3.")
                        gm3.Logger:Log("Player " .. ply:Nick() .. " denied GM3 access - no permission")
                        return
                    end

                    gm3.Logger:Log("Opening GM3 menu for " .. ply:Nick())

                    -- Open the GM3 menu for the player with error handling
                    local netSuccess, netErr = pcall(function()
                        net.Start("gm3:menu:open")
                        net.Send(ply)
                    end)

                    if not netSuccess then
                        gm3.Logger:Log("ERROR sending menu open net message: " .. tostring(netErr), 3)
                        ply:ChatPrint("Failed to open GM3 menu. Please try again.")
                        return
                    end

                    gm3.Logger:Log("Successfully sent menu open message to " .. ply:Nick())
                end,
                description = "Open the Gamemaster 3 admin menu",
                usage = "!gm3",
                -- Remove the permission function that might be causing issues
                -- Let the internal security check handle it
                cooldown = 1
            })
        end)

        if success then
            gm3.Logger:Log("GM3 command registered successfully: " .. tostring(err))
        else
            gm3.Logger:Log("Failed to register GM3 command: " .. tostring(err), 3)
        end
    end)
end

do
    --[[
        GM3 Custom Command Management System
        Allows dynamic creation and management of chat commands
        All commands are properly registered with LYX's chat system
    ]]

    --[[
        Check if a GM3 command exists
        @param cmd string - Command name to check
        @param ply Player - Player requesting the check (optional)
        @return boolean - True if command exists
    ]]
    function gm3:CommandExists(cmd, ply)
        if not cmd or type(cmd) ~= "string" then return false end
        return gm3.commands[cmd] ~= nil
    end

    --[[
        Create a new GM3 command and register it with LYX
        @param tbl table - Command configuration table
        @param ply Player - Player creating the command
    ]]
    function gm3:CommandCreate(tbl, ply)
        -- Validate command configuration
        if not tbl or not tbl.command or type(tbl.command) ~= "string" then
            if IsValid(ply) then
                ply:ChatPrint("Invalid command configuration")
            end
            return
        end

        -- Check if command already exists
        if gm3:CommandExists(tbl.command) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0, 255, 213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Command " .. tbl.command .. " already exists!",
                ["ply"] = ply
            })
            return
        end

        -- Store the GM3 command configuration
        gm3.commands[tbl.command] = tbl

        -- Register the command with LYX's chat system
        local success = lyx:ChatAddCommand(tbl.command, {
            prefix = tbl.prefix or "!",
            func = function(cmdPly, args)
                -- Check if player has permission through GM3 ranks
                if not gm3.commands[tbl.command].ranks[cmdPly:GetUserGroup()] then
                    cmdPly:ChatPrint("You don't have permission to use this command!")
                    return
                end

                -- Execute the command through GM3's system
                net.Start("gm3:command:run")
                    net.WriteTable(gm3.commands[tbl.command])
                    net.WriteTable(args)
                    net.WriteEntity(cmdPly)
                net.Broadcast()
            end,
            description = tbl.description or "GM3 Custom Command",
            usage = (tbl.prefix or "!") .. tbl.command,
            permission = function(cmdPly)
                -- Use GM3's rank system for permissions
                return gm3.commands[tbl.command] and
                       gm3.commands[tbl.command].ranks and
                       gm3.commands[tbl.command].ranks[cmdPly:GetUserGroup()]
            end,
            cooldown = tbl.cooldown or 2
        })

        if success then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0, 255, 213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Command " .. tbl.command .. " has been created!",
                ["ply"] = ply
            })
            lyx:JSONSave("gm3_commands.txt", gm3.commands)
        else
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(255, 0, 0),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Failed to create command " .. tbl.command,
                ["ply"] = ply
            })
        end
    end

    --[[
        Remove a GM3 command and unregister it from LYX
        @param cmd string - Command name to remove
        @param ply Player - Player removing the command
    ]]
    function gm3:CommandRemove(cmd, ply)
        if not cmd or type(cmd) ~= "string" then return end

        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0, 255, 213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Command " .. cmd .. " does not exist!",
                ["ply"] = ply
            })
            return
        end

        -- Remove from GM3 commands
        gm3.commands[cmd] = nil

        -- Remove from LYX chat system
        lyx:ChatRemoveCommand(cmd)

        lyx:MessagePlayer({
            ["type"] = "header",
            ["color1"] = Color(0, 255, 213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255, 255, 255),
            ["text"] = "Command " .. cmd .. " has been removed!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    --[[
        Add a rank permission to a GM3 command
        @param cmd string - Command name
        @param rank string - Rank to add
        @param ply Player - Player making the change
    ]]
    function gm3:CommandAddRank(cmd, rank, ply)
        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0, 255, 213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Command " .. cmd .. " does not exist!",
                ["ply"] = ply
            })
            return
        end

        -- Initialize ranks table if it doesn't exist
        gm3.commands[cmd].ranks = gm3.commands[cmd].ranks or {}
        gm3.commands[cmd].ranks[rank] = true

        lyx:MessagePlayer({
            ["type"] = "header",
            ["color1"] = Color(0, 255, 213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255, 255, 255),
            ["text"] = rank .. " has been added to " .. cmd .. "!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    --[[
        Remove a rank permission from a GM3 command
        @param cmd string - Command name
        @param rank string - Rank to remove
        @param ply Player - Player making the change
    ]]
    function gm3:CommandRemoveRank(cmd, rank, ply)
        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0, 255, 213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255, 255, 255),
                ["text"] = "Command " .. cmd .. " does not exist!",
                ["ply"] = ply
            })
            return
        end

        if gm3.commands[cmd].ranks then
            gm3.commands[cmd].ranks[rank] = nil
        end

        lyx:MessagePlayer({
            ["type"] = "header",
            ["color1"] = Color(0, 255, 213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255, 255, 255),
            ["text"] = rank .. " has been removed from " .. cmd .. "!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    -- REMOVED: Old PlayerSay hook - Commands are now handled by LYX chat system
    -- All GM3 commands are registered with lyx:ChatAddCommand for proper integration
    --[[
        Load saved GM3 commands and register them with LYX
        This runs after a short delay to ensure all systems are initialized
    ]]
    timer.Simple(1, function()
        local commands = lyx:JSONLoad("gm3_commands.txt")
        if commands then
            gm3.commands = commands
            gm3.Logger:Log("Loading GM3 commands...")

            -- Register each saved command with LYX's chat system
            for cmdName, cmdData in pairs(gm3.commands) do
                local success = lyx:ChatAddCommand(cmdName, {
                    prefix = cmdData.prefix or "!",
                    func = function(cmdPly, args)
                        -- Check GM3 rank permissions
                        if not cmdData.ranks or not cmdData.ranks[cmdPly:GetUserGroup()] then
                            cmdPly:ChatPrint("You don't have permission to use this command!")
                            return
                        end

                        -- Execute the command
                        net.Start("gm3:command:run")
                            net.WriteTable(cmdData)
                            net.WriteTable(args)
                            net.WriteEntity(cmdPly)
                        net.Broadcast()
                    end,
                    description = cmdData.description or "GM3 Custom Command",
                    usage = (cmdData.prefix or "!") .. cmdName,
                    permission = function(cmdPly)
                        return cmdData.ranks and cmdData.ranks[cmdPly:GetUserGroup()]
                    end,
                    cooldown = cmdData.cooldown or 2
                })

                if success then
                    gm3.Logger:Log("Registered command: " .. cmdName)
                else
                    gm3.Logger:Log("Failed to register command: " .. cmdName, 2)
                end
            end
        else
            gm3.Logger:Log("No saved GM3 commands found")
        end
    end)
end