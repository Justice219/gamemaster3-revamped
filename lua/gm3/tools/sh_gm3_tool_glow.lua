gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Glow",
        "Makes a player glow. LEave color blank to use random color. NAME OR STEAMID", 
        "Justice#4956",
        {
            ["Name/SteamID"] = {
                type = "string",
                def = "Garry"
            },
            ["Duration"] = {
                type = "number",
                def = 5
            },
            ["Color"] = {
                type = "string",
                def = "255,255,255"
            },
        },
        function(ply, args)
            local target = nil 
            for k,v in pairs(player.GetAll()) do
                if v:Nick() == args["Name/SteamID"] or v:SteamID() == args["Name/SteamID"] then
                    target = v
                end
            end
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Shrink",["color2"] = Color(255,255,255),["text"] = "Player not found!",
                    ["ply"] = ply
                })
                return
            end

            // check if color is blank
            local color = args["Color"]
            if color == "" then
                color = Color(math.random(0,255),math.random(0,255),math.random(0,255))
            else
                local tbl = string.Explode(",", color)
                color = Color(tonumber(tbl[1]),tonumber(tbl[2]),tonumber(tbl[3]))
            end

            // set player glow
            target:SetColor(color)
            target:SetMaterial("models/effects/vol_light001")

            // remove glow after duration
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SetColor(Color(255,255,255))
                    target:SetMaterial("")
                end
            end)
        end,
        "Visual" -- Category for tools affecting player vision/display
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end