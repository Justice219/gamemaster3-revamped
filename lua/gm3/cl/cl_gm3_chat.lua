gm3 = gm3 or {}
lyx = lyx

--[[
    Client-side GM3 chat command handler
    Displays command output in chat with proper formatting
]]
lyx:NetAdd("gm3:command:run", {
    func = function(len)
        local cmd = net.ReadTable()
        local args = net.ReadTable()
        local ply = net.ReadEntity()

        -- Validate received data
        if not cmd or not IsValid(ply) then
            return
        end
        -- Debug output (commented out for production)
        -- PrintTable(cmd)

        -- Build the message based on command settings
        local messageText = table.concat(args, " ")
        local headerStr = ""
        local playerStr = ""

        -- Ensure colors are valid
        local color1 = cmd.color1 and Color(cmd.color1.r or 255, cmd.color1.g or 255, cmd.color1.b or 255) or Color(0, 255, 213)
        local color2 = cmd.color2 and Color(cmd.color2.r or 255, cmd.color2.g or 255, cmd.color2.b or 255) or Color(255, 255, 255)

        -- Build header if needed
        if cmd.useHeader then
            local commandName = cmd.command or "GM3"
            -- Remove prefix character if present
            if string.sub(commandName, 1, 1) == "!" or string.sub(commandName, 1, 1) == "/" then
                commandName = string.sub(commandName, 2)
            end
            headerStr = string.upper("[" .. commandName .. "] ")
        end

        -- Add player name if needed
        if cmd.showPlayerName then
            playerStr = ply:Nick() .. ": "
        end

        -- Display the message with appropriate formatting
        if cmd.useHeader and cmd.showPlayerName then
            chat.AddText(color1, headerStr .. playerStr, color2, messageText)
        elseif cmd.useHeader and not cmd.showPlayerName then
            chat.AddText(color1, headerStr, color2, messageText)
        elseif not cmd.useHeader and cmd.showPlayerName then
            chat.AddText(color1, playerStr, color2, messageText)
        else
            chat.AddText(color2, messageText)
        end
    end
})
