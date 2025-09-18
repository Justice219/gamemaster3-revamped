gm3 = gm3 or {}

local PANEL = {}

function PANEL:Init()
    self:SetSize(lyx.Scale(1280), lyx.Scale(720))
    self:Center()
    self:SetTitle("Gamemaster 3: Revamped")
    self:MakePopup()

    self.startButton = vgui.Create("lyx.TextButton2", self)
    self.startButton:SetSize(lyx.ScaleW(100), lyx.Scale(50))
    self.startButton:SetPos(lyx.ScaleW(self:GetWide() / 2 - 100), lyx.Scale(self:GetTall() / 2 - 25))
    self.startButton:SetText("Start Game")
    self.startButton:SetWide(lyx.Scale(200))
    self.startButton:SetFont("GM3.Components.Player")
    self.startButton.DoClick = function()
        self:StartGame()
        surface.PlaySound("buttons/button9.wav")
    end

    -- self.MessageButton = vgui.Create("lyx.TextButton2", self)
    -- self.MessageButton:SetText("Send Message")
    -- self.MessageButton:SetFont("GM3.Components.Player")
    -- self.MessageButton:Dock(TOP)
    -- self.MessageButton:DockMargin(lyx.ScaleW(15), lyx.Scale(0), lyx.ScaleW(15), lyx.Scale(12))

    self.clickerButton = vgui.Create("lyx.TextButton2", self)
    self.clickerButton:SetSize(lyx.ScaleW(100), lyx.Scale(50))
    self.clickerButton:SetText("Click me!")
    self.clickerButton.DoClick = function()
        self:ButtonClicked()
    end
    self.clickerButton:SetVisible(false)

    self.timerLabel = vgui.Create("DLabel", self)
    self.timerLabel:SetPos(lyx.ScaleW(10), lyx.Scale(10))
    self.timerLabel:SetSize(lyx.ScaleW(100), lyx.Scale(30))
    self.timerLabel:Dock(TOP)
    self.timerLabel:SetText("Time Left: 0:00")

    self.levelLabel = vgui.Create("DLabel", self)
    self.levelLabel:SetPos(lyx.ScaleW(10), lyx.Scale(40))
    self.levelLabel:SetSize(lyx.ScaleW(100), lyx.Scale(30))
    self.levelLabel:Dock(TOP)
    self.levelLabel:SetText("Level: 0")

    self.levelsLabel = vgui.Create("DLabel", self)
    self.levelsLabel:SetPos(lyx.ScaleW(10), lyx.Scale(70))
    self.levelsLabel:SetSize(lyx.ScaleW(100), lyx.Scale(30))
    self.levelsLabel:Dock(TOP)
    self.levelsLabel:SetText("Levels: 0")

    self.failOverlay = vgui.Create("DPanel", self)
    self.failOverlay:SetSize(lyx.ScaleW(self:GetWide()), lyx.Scale(self:GetTall()))
    self.failOverlay.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(255, 0, 0, self.failOverlayAlpha))
    end
    self.failOverlay:SetVisible(false)

    self.fastestTime = nil
    self.startTime = nil
    self.skillCheckActive = false
    self.skillCheckSuccessZone = 0.3 -- 30% of the line
    self.skillCheckMarkerPosition = 0
    self.failOverlayAlpha = 0 
    self.level = 0
    self.maxLevels = 1
    self.callback = nil
    self.hashedEnt = nil
end

function PANEL:Setup(maxLevels, callback, hashedEnt)
    self.maxLevels = tonumber(maxLevels)
    self.callback = callback
    self.hashedEnt = hashedEnt

    self.levelsLabel:SetText("Number of Levels: " .. maxLevels)
end

function PANEL:StartGame()
    self.level = 1
    self.startButton:SetVisible(false)
    self.clickerButton:SetVisible(true)
    self.startTime = SysTime()
    self:NewRound()
end

function PANEL:NewRound()
    local x = math.random(0, self:GetWide() - self.clickerButton:GetWide())
    local y = math.random(0, self:GetTall() - self.clickerButton:GetTall())
    self.clickerButton:SetPos(x, y)

    self.startTime = SysTime()
    self.skillCheckActive = true
    self.skillCheckMarkerPosition = 0
    self.skillCheckSuccessZone = 5 - (self.level - 1) * 0.05 -- decrease success zone with each level

    self.roundStartTime = SysTime()
    self.roundTimeLimit = self.skillCheckSuccessZone * 10 -- correlate round time limit with skill check success zone
end

function PANEL:ButtonClicked()
    if not self.skillCheckActive then return end
    surface.PlaySound("buttons/button9.wav")

    local success = self.skillCheckMarkerPosition >= (1 - self.skillCheckSuccessZone) and self.skillCheckMarkerPosition <= 1
    if success then
        local reactionTime = SysTime() - self.startTime
        if self.fastestTime == nil or reactionTime < self.fastestTime then
            self.fastestTime = reactionTime
            print("New fastest time: " .. reactionTime)
        end
        self.level = self.level + 1
        if self.level > self.maxLevels then
            print("You win!")
            self:Remove()

            net.Start("gm3:hashing:win")
                net.WriteEntity(self.hashedEnt)
            net.SendToServer()

            chat.AddText(Color(38, 224, 94), "[HASHING] ", Color(255, 255, 255), "You have successfully unlocked the door!")
            return
        end
    else
        print("Skill check failed!")
        self:FailSequence()
        print("You failed at level " .. self.level)
    end

    self.skillCheckActive = false
    self:NewRound()

    self.roundStartTime = SysTime()

    print("Button clicked")
    print("Marker position: " .. self.skillCheckMarkerPosition)
    print("Success zone: " .. self.skillCheckSuccessZone)

    self.levelLabel:SetText("Level: " .. self.level)
end

function PANEL:FailSequence()
    surface.PlaySound("buttons/button10.wav")
    self.failOverlay:SetVisible(true)
    self.failOverlayAlpha = 255
    self.clickerButton:SetVisible(false) -- Hide the clicker button
    self.timerLabel:SetVisible(false) -- Hide the timer label
    surface.PlaySound("buttons/button10.wav") -- play fail sound

    -- Display a "You failed" label
    self.failLabel = vgui.Create("DLabel", self)
    self.failLabel:SetPos(self:GetWide() / 2, self:GetTall() / 2)
    self.failLabel:SetSize(200, 50)
    self.failLabel:SetText("You failed!")

    timer.Create("FailSequence", 0.01, 100, function() -- fade out overlay
        if IsValid(self.failOverlay) then
            self.failOverlayAlpha = self.failOverlayAlpha - 2.55
        else
            timer.Remove("FailSequence")
        end
    end)

    -- After 5 seconds, remove the fail label and bring back the start game screen
    timer.Simple(5, function()
        if IsValid(self.failLabel) then
            self.failLabel:Remove()
        end
        
        // reset the whole game
        if IsValid(self.startButton) then
            self.startButton:SetVisible(true)
        end
        if IsValid(self.timerLabel) then
            self.timerLabel:SetVisible(true)
        end
        if IsValid(self.clickerButton) then
            self.clickerButton:SetVisible(false)
        end
        self.level = 0
        self.roundStartTime = nil
        self.failOverlayAlpha = 0
        self.skillCheckActive = false
        self.skillCheckMarkerPosition = 0
        self.level = 0
        self.failOverlay:SetVisible(false)
    end)
end

function PANEL:Think()
    if self.skillCheckActive then
        self.skillCheckMarkerPosition = self.skillCheckMarkerPosition + FrameTime()
        if self.skillCheckMarkerPosition > 1 then
            self.skillCheckActive = false
            print("Skill check failed!")
            self:FailSequence()
        end
    end

    if self.roundStartTime then
        local timeLeft = math.max(0, self.roundTimeLimit - (SysTime() - self.roundStartTime))
        self.timerLabel:SetText(string.format("Time left: %.2f", timeLeft))
        if timeLeft <= 0 then
            print("Time's up!")
            self:FailSequence()
        end
    end

    if self.failOverlayAlpha <= 0 then
        self.failOverlay:SetVisible(false)
    end
end

vgui.Register("GM3.Hashing", PANEL, "lyx.Frame2")