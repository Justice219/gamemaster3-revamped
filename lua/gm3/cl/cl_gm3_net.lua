gm3 = gm3
gm3.ranks = gm3.ranks or {}
gm3.tools = gm3.tools or {}
gm3.commands = gm3.commands or {}
gm3.settings = gm3.settings or {}
lyx = lyx

--[[
    GM3 Client-side Network Handler
    Handles all client-side network messages for GM3
]]

do
    --[[
        Receive sync data from server
        Updates local GM3 data with server state
    ]]
    lyx:NetAdd("gm3:sync:request", {
        func = function(len)
            -- Read and validate sync data
            local tools = net.ReadTable()
            local ranks = net.ReadTable()
            local commands = net.ReadTable()
            local settings = net.ReadTable()

            -- Update local data only if valid
            if tools then gm3.tools = tools end
            if ranks then gm3.ranks = ranks end
            if commands then gm3.commands = commands end
            if settings then gm3.settings = settings end

            gm3.Logger:Log("Server sync complete - Tools: " .. table.Count(gm3.tools) ..
                          ", Ranks: " .. table.Count(gm3.ranks) ..
                          ", Commands: " .. table.Count(gm3.commands))

            hook.Run("GM3.DataSynced", gm3.tools, gm3.ranks, gm3.commands, gm3.settings)
        end
    })
    
    --[[
        Handle client ConVar updates from server
        Creates or updates client-side console variables
    ]]
    lyx:NetAdd("gm3:net:clientConvar", {
        func = function(len)
            local bool = net.ReadBool()
            local name = net.ReadString()

            -- Validate convar name
            if not name or #name > 64 or #name < 1 then
                gm3.Logger:Log("Invalid convar name received", 2)
                return
            end

            -- Sanitize convar name (alphanumeric and underscores only)
            if not string.match(name, "^[%w_]+$") then
                gm3.Logger:Log("Invalid convar name format: " .. name, 2)
                return
            end

            -- Get or create the convar
            local convar = GetConVar(name)
            if convar then
                convar:SetBool(bool)
            else
                -- Create new client convar with safe defaults
                CreateClientConVar(name, bool and 1 or 0, true, false)
            end

            gm3.Logger:Log("ConVar updated: " .. name .. " = " .. tostring(bool))
        end
    })
    
    --[[
        Execute console commands from server
        SECURITY: This should be heavily restricted
    ]]
    lyx:NetAdd("gm3:net:stringConCommand", {
        func = function(len)
            local cmd = net.ReadString()

            -- Validate command
            if not cmd or #cmd > 128 or #cmd < 1 then
                gm3.Logger:Log("Invalid console command received", 2)
                return
            end

            -- Whitelist of allowed commands (for security)
            local allowedCommands = {
                ["disconnect"] = true,
                ["retry"] = true,
                ["kill"] = true,
                ["status"] = true,
            }

            -- Extract base command
            local baseCmd = string.Explode(" ", cmd)[1]

            -- Check if command is allowed
            if not allowedCommands[baseCmd] then
                gm3.Logger:Log("Blocked unsafe console command: " .. baseCmd, 2)
                return
            end

            -- Execute the command
            RunConsoleCommand(baseCmd)
            gm3.Logger:Log("Executed console command: " .. baseCmd)
        end
    })
    
    --[[
        Re-download lightmaps for lighting tools
    ]]
    lyx:NetAdd("gm3:tools:enableLights", {
        func = function(len)
            -- Re-download all lightmaps to fix lighting
            render.RedownloadAllLightmaps(true, true)
            gm3.Logger:Log("Lightmaps refreshed")
        end
    })
    
    --[[
        Request sync and reopen menu at specific tab
        @param tab string - Tab to select after reopening
    ]]
    function gm3:SyncReopenMenu(tab)
        -- Request fresh data from server
        net.Start("gm3:sync:request")
        net.SendToServer()

        -- Wait for sync to complete, then reopen menu
        timer.Simple(0.5, function()
            -- Close existing menu if open
            if IsValid(gm3.Menu) then
                gm3.Menu:Remove()
            end

            -- Create new menu
            gm3.Menu = vgui.Create("GM3.Frame")

            -- Select the specified tab after menu loads
            if tab and IsValid(gm3.Menu) then
                timer.Simple(0.1, function()
                    if IsValid(gm3.Menu) and IsValid(gm3.Menu.SideBar) then
                        gm3.Menu.SideBar:SelectItem(tab)
                    end
                end)
            end
        end)
    end
end

gm3.Logger:Log("GM3 client-side network messages initialized")

concommand.Add("gm3_print_tools", function()
    local tools = gm3 and gm3.tools or {}
    local count = table.Count(tools)
    print("[GM3] Client tool count: " .. count)
    if count == 0 then
        print("[GM3] No tools loaded on client.")
        return
    end

    PrintTable(tools)
end)
