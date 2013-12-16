class 'Speedometer'

function Speedometer:__init()
    self.enabled = true
    self.center_aligned = false
    self.unit = 1 -- 0: m/s 1: km/h 2: mph
    self.position = LocalPlayer:GetPosition()

    self:CreateSettings()
    self.speed_text_size = TextSize.Gigantic
    self.unit_text_size = TextSize.Huge
    self.zero_health        = Color( 255,  78, 69 ) -- Zero health colour
    self.full_health        = Color( 55,  204, 73 ) -- Full health colour

    Events:Subscribe( "PreTick", self, self.PreTick )
    Events:Subscribe( "Render", self, self.Render )
    Events:Subscribe( "LocalPlayerChat", self, self.LocalPlayerChat )
    Events:Subscribe( "LocalPlayerInput", self, self.LocalPlayerInput )
    Events:Subscribe( "ModulesLoad", self, self.ModulesLoad )
    Events:Subscribe( "ModuleUnload", self, self.ModuleUnload )
end

function Speedometer:CreateSettings()
    self.window_open = false

    self.window = Window.Create()
    self.window:SetSize( Vector2( 300, 100 ) )
    self.window:SetPosition( (Render.Size - self.window:GetSize())/2 )

    self.window:SetTitle( "Speedometer Settings" )
    self.window:SetVisible( self.window_open )
    self.window:Subscribe( "WindowClosed", self, self.WindowClosed )

    self.widgets = {}

    local enabled_checkbox = LabeledCheckBox.Create( self.window )
    enabled_checkbox:SetSize( Vector2( 300, 20 ) )
    enabled_checkbox:SetDock( GwenPosition.Top )
    enabled_checkbox:GetLabel():SetText( "Enabled" )
    enabled_checkbox:GetCheckBox():SetChecked( self.enabled )
    enabled_checkbox:GetCheckBox():Subscribe( "CheckChanged", 
        function() self.enabled = enabled_checkbox:GetCheckBox():GetChecked() end )

    local center_checkbox = LabeledCheckBox.Create( self.window )
    center_checkbox:SetSize( Vector2( 300, 20 ) )
    center_checkbox:SetDock( GwenPosition.Top )
    center_checkbox:GetLabel():SetText( "First-Person Centered" )
    center_checkbox:GetCheckBox():SetChecked( self.center_aligned )
    center_checkbox:GetCheckBox():Subscribe( "CheckChanged", 
        function() self.center_aligned = center_checkbox:GetCheckBox():GetChecked() end )

    local rbc = RadioButtonController.Create( self.window )
    rbc:SetSize( Vector2( 300, 20 ) )
    rbc:SetDock( GwenPosition.Top )

    local units = { "m/s", "km/h", "mph" }
    for i, v in ipairs( units ) do
        local option = rbc:AddOption( v )
        option:SetSize( Vector2( 100, 20 ) )
        option:SetDock( GwenPosition.Left )

        if i-1 == self.unit then
            option:Select()
        end

        option:GetRadioButton():Subscribe( "Checked",
            function()
                self.unit = i-1
            end )
    end
end

function Speedometer:GetWindowOpen()
    return self.window_open
end

function Speedometer:SetWindowOpen( state )
    self.window_open = state
    self.window:SetVisible( self.window_open )
    Mouse:SetVisible( self.window_open )
end

function Speedometer:GetSpeed( vehicle )
    local speed = vehicle:GetLinearVelocity():Length()

    if self.unit == 0 then
        return speed
    elseif self.unit == 1 then
        return speed * 3.6
    elseif self.unit == 2 then
        return speed * 2.237
    end
end

function Speedometer:GetUnitString()
    if self.unit == 0 then
        return "m/s"
    elseif self.unit == 1 then
        return "km/h"
    elseif self.unit == 2 then
        return "mph"
    end
end

function Speedometer:DrawShadowedText( pos, text, colour, size, scale )
    if scale == nil then scale = 1.0 end
    if size == nil then size = TextSize.Default end

    local shadow_colour = Color( 0, 0, 0, 255 )
    shadow_colour = shadow_colour * 0.4

    Render:DrawText( pos + Vector3( 1, 1, 0 ), text, shadow_colour, size, scale )
    Render:DrawText( pos, text, colour, size, scale )
end

function Speedometer:PreTick()
    self.position = LocalPlayer:GetPosition()
end

function Speedometer:Render()
    if Game:GetState() ~= GUIState.Game or not self.enabled then return end
    if not LocalPlayer:InVehicle() then return end

    local vehicle = LocalPlayer:GetVehicle()

    local speed = self:GetSpeed( vehicle )
    local speed_text = string.format( "%.01f", speed )
    local speed_size = Render:GetTextSize( speed_text, self.speed_text_size )

    local unit_text = self:GetUnitString()
    local unit_size = Render:GetTextSize( unit_text, self.unit_text_size )
    local angle = vehicle:GetAngle() * Angle( math.pi, 0, math.pi )

    local text_size = speed_size + Vector2( unit_size.x + 24, 0 )

    local t = Transform3()

    if self.center_aligned then
        local pos_3d = vehicle:GetPosition()
        pos_3d.y = LocalPlayer:GetBonePosition( "ragdoll_Head" ).y

        local scale = 1
        
        t:Translate( pos_3d )
        t:Scale( 0.0050 * scale )
        t:Rotate( angle )
        t:Translate( Vector3( 0, 0, 2000 ) )
        t:Translate( -Vector3( text_size.x, text_size.y, 0 )/2 )
    else
        local pos_3d = self.position
        angle = angle * Angle( -math.rad(20), 0, 0 )

        local scale = math.clamp( Camera:GetPosition():Distance( pos_3d ), 0, 500 )
        scale = scale / 20
        
        t = Transform3()
        t:Translate( pos_3d )
        t:Scale( 0.0050 * scale )
        t:Rotate( angle )
        t:Translate( Vector3( text_size.x, text_size.y, -250 ) * -1.5 )
    end

    Render:SetTransform( t )

    local factor = math.clamp( vehicle:GetHealth() - 0.4, 0.0, 0.6 ) * 2.5

    local col = math.lerp( self.zero_health, self.full_health, factor )

    self:DrawShadowedText( Vector3( 0, 0, 0 ), speed_text, col, self.speed_text_size )
    self:DrawShadowedText( 
            Vector3( speed_size.x + 24, (speed_size.y - unit_size.y)/2, 0), 
            unit_text, Color( 255, 255, 255, 255 ), self.unit_text_size )

    local bar_pos = Vector3( 0, text_size.y + 4, 0 )

    Render:FillArea( 
        bar_pos, 
        Vector3( text_size.x, 16, 0 ), Color( 0, 0, 0 ) )

    Render:FillArea( 
        bar_pos, 
        Vector3( text_size.x * vehicle:GetHealth(), 16, 0 ), col )
end

function Speedometer:LocalPlayerChat( args )
    local msg = args.text

    if msg == "/speedometer" or msg == "/speedo" then
        self:SetWindowOpen( not self:GetWindowOpen() )
    end
end

function Speedometer:LocalPlayerInput( args )
    if self:GetWindowOpen() and Game:GetState() == GUIState.Game then
        return false
    end
end

function Speedometer:WindowClosed( args )
    self:SetWindowOpen( false )
end

function Speedometer:ModulesLoad()
    Events:FireRegisteredEvent( "HelpAddItem",
        {
            name = "Speedometer",
            text = 
                "The speedometer is a heads-up display that shows you your " ..
                "current speed in m/s, km/h, or mph.\n\n" ..
                "To configure it, type /speedometer or /speedo in chat."
        } )
end

function Speedometer:ModuleUnload()
    Events:FireRegisteredEvent( "HelpRemoveItem",
        {
            name = "Speedometer"
        } )
end

speedometer = Speedometer()