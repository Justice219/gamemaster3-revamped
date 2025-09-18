gm3 = gm3
lyx = lyx

--[[
--! Internal GM3 Chat Handler
--! Handles custom chat commands for roleplay (ooc, comms, etc.)
--! The !gm3 menu command uses LYX, custom commands use PlayerSay hook
--]]

-- Register network strings immediately
if SERVER then
    util.AddNetworkString("gm3:menu:open")
    util.AddNetworkString("gm3:command:run")
end

do
    --+ GM3 menu command using lyx with proper timing
    timer.Simple(0.5, function()
        lyx:ChatAddCommand("gm3", {
            prefix = "!",
            func = function(ply, args)
                if not gm3:SecurityCheck(ply) then
                    ply:ChatPrint("You don't have permission to access GM3.")
                    return
                end

                net.Start("gm3:menu:open")
                net.Send(ply)

                gm3.Logger:Log("Player " .. ply:Nick() .. " opened GM3 menu")
            end,
            description = "Open the Gamemaster 3 admin menu",
            usage = "!gm3"
        })
        gm3.Logger:Log("Registered !gm3 command with LYX")
    end)
end

do
    -- GM3 Custom Command System for roleplay commands (ooc, comms, etc.)

    function gm3:CommandExists(cmd, ply)
        if not cmd then return end
        return gm3.commands[cmd] ~= nil
    end

    function gm3:CommandCreate(tbl, ply)
        if not tbl.command then return end

        if gm3:CommandExists(tbl.command) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255,255,255),
                ["text"] = "Command " .. tbl.command .. " already exists!",
                ["ply"] = ply
            })
            return
        end

        gm3.commands[tbl.command] = tbl

        lyx:MessagePlayer({
            ["type"] = "header",
            ["color1"] = Color(0,255,213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255,255,255),
            ["text"] = "Command " .. tbl.command .. " has been created!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    function gm3:CommandRemove(cmd, ply)
        if not cmd then return end

        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255,255,255),
                ["text"] = "Command " .. cmd .. " does not exist!",
                ["ply"] = ply
            })
            return
        end

        gm3.commands[cmd] = nil
        lyx:MessagePlayer({
            ["type"] = "header",
            ["color1"] = Color(0,255,213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255,255,255),
            ["text"] = "Command " .. cmd .. " has been removed!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    function gm3:CommandAddRank(cmd, rank, ply)
        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255,255,255),
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
            ["color1"] = Color(0,255,213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255,255,255),
            ["text"] = rank .. " has been added to " .. cmd .. "!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    function gm3:CommandRemoveRank(cmd, rank, ply)
        if not gm3:CommandExists(cmd) then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255,255,255),
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
            ["color1"] = Color(0,255,213),
            ["header"] = "Gamemaster 3",
            ["color2"] = Color(255,255,255),
            ["text"] = rank .. " has been removed from " .. cmd .. "!",
            ["ply"] = ply
        })
        lyx:JSONSave("gm3_commands.txt", gm3.commands)
    end

    -- PlayerSay hook for GM3 custom roleplay commands (ooc, comms, etc.)
    hook.Add("PlayerSay", "gm3:command:call", function(ply, text)
        local args = string.Explode(" ", text)
        local cmd = args[1]

        if not gm3:CommandExists(cmd) then return end

        -- Check if player has permission to use this command
        if gm3.commands[cmd].ranks and not gm3.commands[cmd].ranks[ply:GetUserGroup()] then
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(0,255,213),
                ["header"] = "Gamemaster 3",
                ["color2"] = Color(255,255,255),
                ["text"] = "You do not have permission to use this command!",
                ["ply"] = ply
            })
            return ""
        end

        -- Remove command from args
        table.remove(args, 1)

        -- Broadcast the command to all clients for display
        net.Start("gm3:command:run")
            net.WriteTable(gm3.commands[cmd])
            net.WriteTable(args)
            net.WriteEntity(ply)
        net.Broadcast()

        return "" -- Suppress original message
    end)

    -- Load saved commands on server start
    timer.Simple(1, function()
        local commands = lyx:JSONLoad("gm3_commands.txt")
        if commands then
            gm3.commands = commands
            gm3.Logger:Log("Loading GM3 custom commands...")
            for k, v in pairs(gm3.commands) do
                gm3.Logger:Log("Loaded Command: " .. k)
            end
        else
            gm3.Logger:Log("No custom commands found")
        end
    end)
end