gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings for scene director (server -> client only)
    lyx:NetAdd("gm3:tools:scenedirector:start")
    lyx:NetAdd("gm3:tools:scenedirector:camera")
    lyx:NetAdd("gm3:tools:scenedirector:subtitle")
    lyx:NetAdd("gm3:tools:scenedirector:end")
    lyx:NetAdd("gm3:tools:scenedirector:effect")

    gm3 = gm3
    lyx = lyx

    -- Table to track active scenes
    gm3.activeScenes = gm3.activeScenes or {}
    gm3.sceneParticipants = gm3.sceneParticipants or {}

    local tool = GM3Module.new(
        "Scene Director",
        "Create cinematic sequences with camera control, subtitles, effects and more for narrative events",
        "GM3 Assistant",
        {
            ["Scene Mode"] = {
                type = "string",
                def = "cinematic" -- Options: cinematic, cutscene, dialogue, action
            },
            ["Target Players"] = {
                type = "string",
                def = "all" -- all, specific player steamid, or team name
            },
            ["Camera Mode"] = {
                type = "string",
                def = "fixed" -- Options: fixed, follow, orbit, free
            },
            ["Camera Target"] = {
                type = "string",
                def = "self" -- Player steamid or entity class
            },
            ["Camera Distance"] = {
                type = "number",
                def = 150 -- Distance from target
            },
            ["Camera Angle"] = {
                type = "string",
                def = "front" -- front, back, left, right, top, custom
            },
            ["Subtitle Text"] = {
                type = "string",
                def = "" -- Text to display
            },
            ["Subtitle Speaker"] = {
                type = "string",
                def = "" -- Who is speaking (shows above subtitle)
            },
            ["Subtitle Duration"] = {
                type = "number",
                def = 5 -- How long to show subtitle
            },
            ["Scene Effect"] = {
                type = "string",
                def = "none" -- none, fade_in, fade_out, letterbox, blur, slowmo, blackwhite
            },
            ["Effect Intensity"] = {
                type = "number",
                def = 1 -- 0.1 to 2
            },
            ["Freeze Players"] = {
                type = "boolean",
                def = true -- Freeze players during scene
            },
            ["Hide HUD"] = {
                type = "boolean",
                def = true -- Hide HUD elements during scene
            },
            ["Scene Duration"] = {
                type = "number",
                def = 10 -- Total scene duration in seconds, 0 = manual end
            },
            ["End Scene"] = {
                type = "boolean",
                def = false -- Set to true to end active scene
            }
        },
        function(ply, args)
            -- End scene if requested
            if args["End Scene"] then
                -- End all active scenes for the target players
                local targets = {}
                if args["Target Players"] == "all" then
                    targets = player.GetAll()
                else
                    local targetPlayer = gm3:GetPlayerBySteamID(args["Target Players"])
                    if IsValid(targetPlayer) then
                        targets = {targetPlayer}
                    end
                end

                for _, target in ipairs(targets) do
                    if gm3.sceneParticipants[target] then
                        -- Send end scene message
                        lyx:NetSend("gm3:tools:scenedirector:end", {}, target)

                        -- Unfreeze if frozen
                        if gm3.sceneParticipants[target].frozen then
                            target:Freeze(false)
                        end

                        gm3.sceneParticipants[target] = nil
                    end
                end

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(100,255,100),
                    ["header"] = "Scene Director",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Scene ended for selected players.",
                    ["ply"] = ply
                })
                return
            end

            -- Get target players
            local targets = {}
            if args["Target Players"] == "all" then
                targets = player.GetAll()
            elseif string.StartWith(args["Target Players"], "team:") then
                local teamName = string.sub(args["Target Players"], 6)
                for _, p in ipairs(player.GetAll()) do
                    if team.GetName(p:Team()) == teamName then
                        table.insert(targets, p)
                    end
                end
            else
                local targetPlayer = gm3:GetPlayerBySteamID(args["Target Players"])
                if IsValid(targetPlayer) then
                    targets = {targetPlayer}
                else
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Scene Director",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Target player not found! Use 'all' or valid SteamID.",
                        ["ply"] = ply
                    })
                    return
                end
            end

            -- Start scene for each target
            for _, target in ipairs(targets) do
                -- Track participant
                gm3.sceneParticipants[target] = {
                    frozen = args["Freeze Players"],
                    startTime = CurTime(),
                    duration = args["Scene Duration"]
                }

                -- Freeze player if requested
                if args["Freeze Players"] then
                    target:Freeze(true)
                end

                -- Send scene start data
                lyx:NetSend("gm3:tools:scenedirector:start", {
                    mode = args["Scene Mode"],
                    hideHUD = args["Hide HUD"]
                }, target)

                -- Set up camera if not "none"
                if args["Camera Mode"] ~= "none" then
                    local cameraTarget = nil
                    if args["Camera Target"] == "self" then
                        cameraTarget = target
                    else
                        cameraTarget = gm3:GetPlayerBySteamID(args["Camera Target"])
                    end

                    lyx:NetSend("gm3:tools:scenedirector:camera", {
                        mode = args["Camera Mode"],
                        target = cameraTarget,
                        distance = args["Camera Distance"],
                        angle = args["Camera Angle"]
                    }, target)
                end

                -- Send subtitle if provided
                if args["Subtitle Text"] and args["Subtitle Text"] ~= "" then
                    timer.Simple(0.5, function()
                        if IsValid(target) then
                            lyx:NetSend("gm3:tools:scenedirector:subtitle", {
                                text = args["Subtitle Text"],
                                speaker = args["Subtitle Speaker"],
                                duration = args["Subtitle Duration"]
                            }, target)
                        end
                    end)
                end

                -- Apply scene effect
                if args["Scene Effect"] ~= "none" then
                    lyx:NetSend("gm3:tools:scenedirector:effect", {
                        effect = args["Scene Effect"],
                        intensity = args["Effect Intensity"]
                    }, target)
                end

                -- Auto-end scene after duration
                if args["Scene Duration"] > 0 then
                    timer.Simple(args["Scene Duration"], function()
                        if IsValid(target) and gm3.sceneParticipants[target] then
                            lyx:NetSend("gm3:tools:scenedirector:end", {}, target)

                            if gm3.sceneParticipants[target].frozen then
                                target:Freeze(false)
                            end

                            gm3.sceneParticipants[target] = nil
                        end
                    end)
                end
            end

            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(100,255,100),
                ["header"] = "Scene Director",
                ["color2"] = Color(255,255,255),
                ["text"] = "Scene started for " .. #targets .. " player(s)!",
                ["ply"] = ply
            })
        end,
        "Roleplay"
    )

    gm3:addTool(tool)
end

if CLIENT then
    local activeScene = {}
    local letterboxSize = 0
    local targetLetterbox = 0
    local cameraData = {}
    local subtitleData = {}
    local effectData = {}

    -- Handle scene start
    lyx.NetReceive("gm3:tools:scenedirector:start", function(ply, tbl)
        activeScene = {
            mode = tbl.mode,
            hideHUD = tbl.hideHUD,
            startTime = CurTime()
        }
        targetLetterbox = tbl.mode == "cinematic" and 100 or 0
    end)

    -- Handle camera setup
    lyx.NetReceive("gm3:tools:scenedirector:camera", function(ply, tbl)
        cameraData = {
            mode = tbl.mode,
            target = tbl.target,
            distance = tbl.distance,
            angle = tbl.angle,
            startTime = CurTime()
        }
    end)

    -- Handle subtitles
    lyx.NetReceive("gm3:tools:scenedirector:subtitle", function(ply, tbl)
        subtitleData = {
            text = tbl.text,
            speaker = tbl.speaker,
            duration = tbl.duration,
            startTime = CurTime()
        }
    end)

    -- Handle effects
    lyx.NetReceive("gm3:tools:scenedirector:effect", function(ply, tbl)
        effectData = {
            effect = tbl.effect,
            intensity = tbl.intensity,
            startTime = CurTime()
        }

        -- Handle immediate effects
        if tbl.effect == "slowmo" then
            game.SetTimeScale(0.5 * (2 - tbl.intensity))
        end
    end)

    -- Handle scene end
    lyx.NetReceive("gm3:tools:scenedirector:end", function(ply, tbl)
        activeScene = {}
        cameraData = {}
        subtitleData = {}
        effectData = {}
        targetLetterbox = 0
        game.SetTimeScale(1)
    end)

    -- Calculate camera view
    hook.Add("CalcView", "GM3_SceneDirector", function(ply, pos, angles, fov)
        if not cameraData.mode then return end

        local view = {}
        local target = cameraData.target

        if not IsValid(target) then
            target = ply
        end

        local targetPos = target:GetPos() + Vector(0, 0, 50)

        if cameraData.mode == "fixed" then
            -- Fixed camera position
            local angleOffsets = {
                front = Angle(0, 0, 0),
                back = Angle(0, 180, 0),
                left = Angle(0, 90, 0),
                right = Angle(0, -90, 0),
                top = Angle(-89, 0, 0),
                custom = angles
            }

            local selectedAngle = angleOffsets[cameraData.angle] or Angle(0, 0, 0)
            local forward = selectedAngle:Forward()

            view.origin = targetPos - forward * cameraData.distance
            view.angles = (targetPos - view.origin):Angle()

        elseif cameraData.mode == "follow" then
            -- Follow camera (smooth follow)
            local offset = angles:Forward() * -cameraData.distance
            view.origin = targetPos + offset
            view.angles = (targetPos - view.origin):Angle()

        elseif cameraData.mode == "orbit" then
            -- Orbiting camera
            local time = CurTime() - cameraData.startTime
            local angle = time * 30 -- 30 degrees per second

            view.origin = targetPos + Vector(
                math.cos(math.rad(angle)) * cameraData.distance,
                math.sin(math.rad(angle)) * cameraData.distance,
                30
            )
            view.angles = (targetPos - view.origin):Angle()

        elseif cameraData.mode == "free" then
            -- Free camera (player controlled but from different position)
            return
        end

        view.fov = fov
        view.drawviewer = true

        return view
    end)

    -- Render effects and UI
    hook.Add("HUDPaint", "GM3_SceneDirector", function()
        local w, h = ScrW(), ScrH()

        -- Letterbox effect
        if targetLetterbox > 0 or letterboxSize > 0 then
            letterboxSize = Lerp(FrameTime() * 3, letterboxSize, targetLetterbox)

            if letterboxSize > 1 then
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(0, 0, w, letterboxSize * lyx.Scale())
                surface.DrawRect(0, h - letterboxSize * lyx.Scale(), w, letterboxSize * lyx.Scale())
            end
        end

        -- Subtitles
        if subtitleData.text and CurTime() - subtitleData.startTime < subtitleData.duration then
            local alpha = 255
            local timeLeft = subtitleData.duration - (CurTime() - subtitleData.startTime)

            -- Fade in/out
            if timeLeft < 0.5 then
                alpha = timeLeft * 510
            elseif CurTime() - subtitleData.startTime < 0.5 then
                alpha = (CurTime() - subtitleData.startTime) * 510
            end

            -- Draw speaker name if provided
            if subtitleData.speaker and subtitleData.speaker ~= "" then
                draw.SimpleText(
                    subtitleData.speaker,
                    "DermaDefault",
                    w / 2,
                    h - 140 * lyx.Scale(),
                    Color(200, 200, 200, alpha),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end

            -- Draw subtitle text with word wrap
            local lines = string.Explode("\n", subtitleData.text)
            for i, line in ipairs(lines) do
                draw.SimpleText(
                    line,
                    "DermaLarge",
                    w / 2,
                    h - 100 * lyx.Scale() + (i - 1) * 25 * lyx.Scale(),
                    Color(255, 255, 255, alpha),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end

        -- Scene effects
        if effectData.effect then
            local timeSince = CurTime() - effectData.startTime

            if effectData.effect == "fade_in" then
                local alpha = math.max(0, 255 - timeSince * 255 / effectData.intensity)
                surface.SetDrawColor(0, 0, 0, alpha)
                surface.DrawRect(0, 0, w, h)

            elseif effectData.effect == "fade_out" then
                local alpha = math.min(255, timeSince * 255 / effectData.intensity)
                surface.SetDrawColor(0, 0, 0, alpha)
                surface.DrawRect(0, 0, w, h)

            elseif effectData.effect == "blur" then
                -- Blur is handled by overriding HUDShouldDraw

            elseif effectData.effect == "blackwhite" then
                -- Black and white filter
                local tab = {
                    ["$pp_colour_addr"] = 0,
                    ["$pp_colour_addg"] = 0,
                    ["$pp_colour_addb"] = 0,
                    ["$pp_colour_brightness"] = 0,
                    ["$pp_colour_contrast"] = 1,
                    ["$pp_colour_colour"] = 0,
                    ["$pp_colour_mulr"] = 0,
                    ["$pp_colour_mulg"] = 0,
                    ["$pp_colour_mulb"] = 0
                }
                DrawColorModify(tab)
            end
        end
    end)

    -- Hide HUD elements during scene
    hook.Add("HUDShouldDraw", "GM3_SceneDirector", function(name)
        if activeScene.hideHUD and name ~= "CHudGMod" then
            return false
        end
    end)
end