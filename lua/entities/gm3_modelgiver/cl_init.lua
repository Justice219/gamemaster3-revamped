-- Incoludes
include("shared.lua")
local imgui = include("lyx_core/thirdparty/cl_lyx_imgui.lua")

function ENT:Draw()
    self:DrawModel()
    
    if imgui.Entity3D2D(self, Vector(-5,21.5,20), Angle(0,180,90), 0.1) then

        -- UI n shit
        surface.SetDrawColor(78,77,77)
        surface.DrawRect(-350,0, 600,200)

        draw.SimpleText("Republic Model Crate", imgui.xFont("!Roboto@30"), -330,5, Color(224,137,96), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Model Path - " .. self:GetModelP(), imgui.xFont("!Roboto@20"), -330,35)
        draw.SimpleText("Model Name - " .. self:GetCrateName(), imgui.xFont("!Roboto@20"), -330,55)

        -- Main UI
        if imgui.xTextButton("Equip Model", "!Roboto@24", -350, 240, 600, 60, 1, Color(255,255,255), Color(224,137,96), Color(253,239,239)) then
                
        end

        imgui.End3D2D()
    end
    -- Admin Draw. Needs to be seperate because of imgui restrictions
    if imgui.Entity3D2D(self, Vector(50,25,30), Angle(0,90,90), 0.1) then

        if imgui.xTextButton("Admin Config", "!Roboto@24", -350, 240, 200, 60, 1, Color(255,255,255), Color(224,137,96), Color(253,239,239)) then
            net.Start("GM2:Entities:ModelGiver:Verify")
            net.WriteEntity(self)
            net.SendToServer()
        end

        imgui.End3D2D()
    end
end

local function configMenu(ent)
    local tabs = {}
    local data = {}
    local funcs = {}

    local function ScaleW(size)
        return ScrW() * size/1920
    end
    local function ScaleH(size)
        return ScrH() * size/1080        
    end

    surface.CreateFont("menu_title", {
        font = "Roboto",
        size = 20,
        weight = 500,
        antialias = true,
        shadow = false
    })
    surface.CreateFont("menu_button", {
        font = "Roboto",
        size = 22.5,
        weight = 500,
        antialias = true,
        shadow = false
    })

    local panel = vgui.Create("DFrame")
    panel:TDLib()
    panel:SetTitle("GM2 by Justice#4956")
    panel:ShowCloseButton(false)
    panel:SetSize(ScaleW(960), ScaleH(540))
    panel:Center()
    panel:MakePopup()
    panel:ClearPaint()
        :Background(Color(40, 41, 40), 6)
        :Text("Model Crate Config", "DermaLarge", Color(255, 255, 255), TEXT_ALIGN_LEFT, ScaleW(390), ScaleH(-240))
        :Text("v1.0", "DermaLarge", Color(255, 255, 255), TEXT_ALIGN_LEFT, ScaleW(5),ScaleH(250))
        :CircleHover(Color(59, 59, 59), 5, 20)

    local panel2 = panel:Add("DPanel")
    panel2:TDLib()
    panel2:SetPos(ScaleW(0), ScaleH(60))
    panel2:SetSize(ScaleW(1920), ScaleH(5))
    panel2:ClearPaint()
        :Background(Color(255, 255, 255), 0)

    local panel3 = panel:Add("DPanel")
    panel3:TDLib()
    panel3:SetPos(ScaleW(275), ScaleH(60))
    panel3:SetSize(ScaleW(5), ScaleH(1000))
    panel3:ClearPaint()
        :Background(Color(255, 255, 255), 0)


    local close = panel:Add("DImageButton")
    close:SetPos(ScaleW(925),ScaleH(10))
    close:SetSize(ScaleW(20),ScaleH(20))
    close:SetImage("icon16/cross.png")
    close.DoClick = function()
        panel:Remove()
    end

    local scroll = panel:Add("DScrollPanel")
    scroll:SetPos(ScaleW(17.5), ScaleH(75))
    scroll:SetSize(ScaleW(240), ScaleW(425))
    scroll:TDLib()
    scroll:ClearPaint()
        --:Background(Color(0, 26, 255), 6)
        :CircleHover(Color(59, 59, 59), 5, 20)

    local function ChangeTab(name)
        print("Changing Tab")
        for k,v in pairs(data) do
            table.RemoveByValue(data, v)
            v:Remove()
            print("Removed")
        end

        local tbl = tabs[name]
        tbl.change()

    end
    
    local function CreateTab(name, tbl)
        local scroll = scroll:Add( "DButton" )
        scroll:SetText( name)
        scroll:Dock( TOP )
        scroll:SetTall( 50 )
        scroll:DockMargin( 0, 5, 0, 5 )
        scroll:SetTextColor(Color(255,255,255))
        scroll:TDLib()
        scroll:SetFont("menu_button")
        scroll:SetIcon(tbl.icon)
        scroll:ClearPaint()
            :Background(Color(59, 59, 59), 5)
            :BarHover(Color(255, 255, 255), 3)
            :CircleClick()
        scroll.DoClick = function()
            ChangeTab(name)
        end

        if tabs[name] then return end
        tabs[name] = tbl
    end
    CreateTab("Statistics", {
        icon = "icon16/chart_bar.png",
        change = function()
            local d = {}
            local p = nil

            main = panel:Add("DPanel")
            main:SetPos(ScaleW(290), ScaleH(75))
            main:SetSize(ScaleW(660), ScaleH(455))
            main:TDLib()
            main:ClearPaint()
                :Background(Color(59, 59, 59), 6)
                :Text("Crate Statistics", "DermaLarge", Color(255, 255, 255), TEXT_ALIGN_LEFT, ScaleW(210),ScaleH(-202.5))
            table.insert(d, #d, main)

            dinfo = panel:Add("DPanel")
            dinfo:SetPos(ScaleW(300), ScaleH(125))
            dinfo:SetSize(ScaleW(640), ScaleH(395))
            dinfo:TDLib()
            dinfo:ClearPaint()
                :Background(Color(40,41,40), 6)

            weapon = dinfo:Add("DLabel")
            weapon:SetPos(ScaleW(10), ScaleH(10))
            weapon:SetSize(ScaleW(600), ScaleH(50))
            weapon:SetFont("menu_title")
            weapon:SetText("Model: " .. ent:GetModelP())

            quantity = dinfo:Add("DLabel")
            quantity:SetPos(ScaleW(10), ScaleH(40))
            quantity:SetSize(ScaleW(600), ScaleH(50))
            quantity:SetFont("menu_title")
            quantity:SetText("Model Name: " .. ent:GetCrateName())


            for k,v in pairs(d) do
                table.insert(data, #data, v)
            end
        end
    })
    CreateTab("Config", {
        icon = "icon16/wrench.png",
        change = function()
            local d = {}
            local p = nil

            main = panel:Add("DPanel")
            main:SetPos(ScaleW(290), ScaleH(75))
            main:SetSize(ScaleW(660), ScaleH(455))
            main:TDLib()
            main:ClearPaint()
                :Background(Color(59, 59, 59), 6)
                :Text("Model Configuration", "DermaLarge", Color(255, 255, 255), TEXT_ALIGN_LEFT, ScaleW(210),ScaleH(-202.5))
            table.insert(d, #d, main)

            dinfo = panel:Add("DPanel")
            dinfo:SetPos(ScaleW(300), ScaleH(125))
            dinfo:SetSize(ScaleW(640), ScaleH(395))
            dinfo:TDLib()
            dinfo:ClearPaint()
                :Background(Color(40,41,40), 6)

            quantityLabel = dinfo:Add("DLabel")
            quantityLabel:SetPos(ScaleW(10), ScaleH(10))
            quantityLabel:SetSize(ScaleW(600), ScaleH(50))
            quantityLabel:SetFont("menu_title")
            quantityLabel:SetText("Model String")

            quantity = dinfo:Add("DTextEntry")
            quantity:SetPos(ScaleW(10), ScaleH(50))
            quantity:SetSize(ScaleW(620), ScaleH(50))
            quantity:SetText(ent:GetModelP())
            quantity:SetFont("menu_title")
            quantity.Paint = function(self, w, h)
                draw.RoundedBox( 6, 0, 0, w, h, Color(59, 59, 59))
                self:DrawTextEntryText(Color(255, 255, 255), Color(255, 0, 0), Color(255, 255, 255))
            end

            weaponLabel = dinfo:Add("DLabel")
            weaponLabel:SetPos(ScaleW(10), ScaleH(100))
            weaponLabel:SetSize(ScaleW(600), ScaleH(50))
            weaponLabel:SetFont("menu_title")
            weaponLabel:SetText("Model Name")

            weapon = dinfo:Add("DTextEntry")
            weapon:SetPos(ScaleW(10), ScaleH(150))
            weapon:SetSize(ScaleW(620), ScaleH(50))
            weapon:SetText(ent:GetCrateName())
            weapon:SetFont("menu_title")
            weapon.Paint = function(self, w, h)
                draw.RoundedBox( 6, 0, 0, w, h, Color(59, 59, 59))
                self:DrawTextEntryText(Color(255, 255, 255), Color(255, 0, 0), Color(255, 255, 255))
            end

            update = dinfo:Add("DButton")
            update:SetPos(ScaleW(10), ScaleH(330))
            update:SetSize(ScaleW(620), ScaleH(50))
            update:SetText("Update")
            update:SetFont("menu_button")
            update:SetTextColor(Color(255,255,255))
            update:TDLib()
            update:ClearPaint()
                :Background(Color(59, 59, 59), 5)
                :BarHover(Color(255, 255, 255), 3)
                :CircleClick()
            update.DoClick = function()
                net.Start("GM2:Entities:ModelGiver:Set")
                net.WriteEntity(ent)
                net.WriteString(quantity:GetValue())
                net.WriteString(weapon:GetValue())
                net.SendToServer()
            end


            for k,v in pairs(d) do
                table.insert(data, #data, v)
            end
        end
    })
    ChangeTab("Statistics")
end


net.Receive("GM3:Entities:ModelGiver:Open", function(len, ply)
    local ent = net.ReadEntity()
    chat.AddText("You have been verified!")
    configMenu(ent)
end)