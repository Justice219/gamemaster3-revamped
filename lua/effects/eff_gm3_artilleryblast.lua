AddCSLuaFile()

local smokeSprites = {
    "particle/smokesprites_0001",
    "particle/smokesprites_0002",
    "particle/smokesprites_0003",
    "particle/smokesprites_0004",
    "particle/smokesprites_0005",
    "particle/smokesprites_0006",
    "particle/smokesprites_0007",
    "particle/smokesprites_0008",
    "particle/smokesprites_0009"
}

local flareSprites = {
    "effects/yellowflare",
    "sprites/orangeflare1",
    "sprites/light_glow02_add"
}

local emberSprites = {
    "particles/flamelet1",
    "particles/flamelet2",
    "particles/flamelet3"
}

local function RandomColorTint(base)
    return Color(
        math.Clamp((base.r or 255) + math.random(-20, 20), 0, 255),
        math.Clamp((base.g or 180) + math.random(-20, 20), 0, 255),
        math.Clamp((base.b or 120) + math.random(-20, 20), 0, 255)
    )
end

local EFFECT = {}

function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local scale = math.Clamp(data:GetScale() or 1, 0.4, 5)
    local ang = data:GetAngles() or Angle(255, 200, 120)
    local tint = Color(math.Clamp(ang.p or 255, 0, 255), math.Clamp(ang.y or 200, 0, 255), math.Clamp(ang.r or 120, 0, 255))

    local emitter = ParticleEmitter(pos)
    if not emitter then return end

    -- core flash
    local flash = emitter:Add(flareSprites[math.random(#flareSprites)], pos)
    if flash then
        flash:SetVelocity(Vector(0, 0, 0))
        flash:SetDieTime(0.18)
        flash:SetStartAlpha(255)
        flash:SetEndAlpha(0)
        flash:SetStartSize(120 * scale)
        flash:SetEndSize(480 * scale)
        flash:SetColor(tint.r, tint.g, tint.b)
        flash:SetRoll(math.Rand(0, 360))
    end

    -- shockwave ring
    local ring = emitter:Add("effects/select_ring", pos + Vector(0, 0, 2))
    if ring then
        ring:SetVelocity(Vector(0, 0, 0))
        ring:SetDieTime(0.6)
        ring:SetStartAlpha(200)
        ring:SetEndAlpha(0)
        ring:SetStartSize(90 * scale)
        ring:SetEndSize(520 * scale)
        ring:SetColor(tint.r, tint.g, tint.b)
    end

    -- heavy smoke column
    local smokeCount = math.floor(70 * scale)
    for _ = 1, smokeCount do
        local particle = emitter:Add(smokeSprites[math.random(#smokeSprites)], pos)
        if particle then
            particle:SetVelocity(VectorRand():GetNormalized() * math.Rand(200, 800) * scale + Vector(0, 0, math.Rand(120, 260) * scale))
            particle:SetDieTime(math.Rand(2.2, 4.5) * scale)
            particle:SetStartAlpha(230)
            particle:SetEndAlpha(0)
            particle:SetStartSize(math.Rand(120, 200) * scale)
            particle:SetEndSize(math.Rand(320, 420) * scale)
            particle:SetRoll(math.Rand(0, 360))
            local smokeColor = RandomColorTint(Color(120, 110, 100))
            particle:SetColor(smokeColor.r, smokeColor.g, smokeColor.b)
            particle:SetAirResistance(80)
            particle:SetGravity(Vector(0, 0, math.Rand(100, 200)))
        end
    end

    -- fiery embers
    local emberCount = math.floor(40 * scale)
    for _ = 1, emberCount do
        local particle = emitter:Add(emberSprites[math.random(#emberSprites)], pos)
        if particle then
            particle:SetVelocity(VectorRand():GetNormalized() * math.Rand(300, 900) * scale)
            particle:SetDieTime(math.Rand(0.4, 0.9))
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(math.Rand(40, 80) * scale)
            particle:SetEndSize(0)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetColor(tint.r, tint.g, tint.b)
            particle:SetGravity(Vector(0, 0, math.Rand(80, 120) * -1))
        end
    end

    -- debris chunks
    local chunkCount = math.floor(60 * scale)
    for _ = 1, chunkCount do
        local particle = emitter:Add("effects/fleck_cement" .. math.random(1, 2), pos)
        if particle then
            particle:SetVelocity(VectorRand():GetNormalized() * math.Rand(250, 900) * scale + Vector(0, 0, math.Rand(150, 400)))
            particle:SetDieTime(math.Rand(0.6, 1.6))
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(math.Rand(8, 14) * scale)
            particle:SetEndSize(0)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetColor(80, 70, 60)
            particle:SetGravity(Vector(0, 0, -800))
        end
    end

    emitter:Finish()

    local dlight = DynamicLight(0)
    if dlight then
        dlight.pos = pos + Vector(0, 0, 64)
        dlight.r = tint.r
        dlight.g = tint.g
        dlight.b = tint.b
        dlight.brightness = 6 * scale
        dlight.Decay = 2000
        dlight.Size = 600 * scale
        dlight.DieTime = CurTime() + 0.6
    end

    util.ScreenShake(pos, 6 * scale, 5, 1, 800 * scale)
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

effects.Register(EFFECT, "gm3_artilleryblast")
