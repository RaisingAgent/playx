-- PlayX
-- Copyright (c) 2009, 2010 sk89q <http://www.sk89q.com>
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 2 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- 
-- $Id$

include("shared.lua")

language.Add("gmod_playx", "PlayX Player")
language.Add("Undone_gmod_playx", "Undone PlayX Player")
language.Add("Cleanup_gmod_playx", "PlayX Player")
language.Add("Cleaned_gmod_playx", "Cleaned up the PlayX Player")

ENT.Engine = nil
ENT.EngineError = nil
ENT.Media = nil
ENT.Started = false
ENT.Centered = false

--- Returns true if there is an attached engine.
-- @return Boolean
function ENT:HasEngine()
    return self.Engine ~= nil
end

--- Returns true if there is media.
-- @return Boolean
function ENT:HasMedia()
    return self.Media ~= nil
end

--- Returns true if the current media is resumable. If there is no media, then
-- this function will return false.
-- @return Boolean
function ENT:IsResumable()
    return self.Media ~= nil and self.Media.Resumable
end

--- Returns whether something is playing.
-- @return Boolean
function ENT:IsPlaying()
    return self.Engine ~= nil
end

--- Initializes the entity.
-- @hidden
function ENT:Initialize()
    self.Entity:DrawShadow(false)
    
    -- We do the following so that the screen always appears, even if the
    -- entity itself is not inside the player's view.
    self:SetRenderBoundsWS(Vector(-50000, -50000, -50000),
                           Vector(50000, 50000, 50000))
    
    self.Centered = false
    
    self:CalculateScreenBounds()
end

--- Get the amount of time that the media has elapsed. Note that if the media
-- was not started at the beginning, that difference will be reflected in
-- the output of this function.
-- @return Time in seconds
function ENT:GetElapsedTime()
    if self:HasMedia() then
        return RealTime() - self.Media.StartTime
    end
end

--- Begin a media.
-- @param handler
-- @param arguments
-- @param resumable
-- @param lowFramerate
-- @param startTime
-- @hidden
function ENT:Begin(handler, arguments, resumable, lowFramerate, startTime)
    self:Stop() -- Kill previous engine
    
    self.Media = {
        Handler = handler,
        Arguments = arguments,
        StartTime = startTime,
        Resumable = resumable,
        LowFramerate = lowFramerate,
    }
end

--- Stops media.
-- @hidden
function ENT:End()
    self:Stop()
    
    self.Media = nil
    self.Started = false
end

--- Start playing the media. If there is no media, then nothing will happen.
-- Even if the media is not resumable, calling this function will cause the
-- media to start playing, even if it starts from the beginning. 
function ENT:Start()
    if not self:HasMedia() then
        return
    end
    
    self.Started = true
    
    if self:HasEngine() then
        self.Engine:Destroy()
        self.Engine = nil
    end
    
    self:CalculateScreenBounds()
    self:UpdateFPS()
end

--- Stop playing.
function ENT:Stop()
    self.Started = false
    
    if self:HasEngine() then
        self.Engine:Destroy()
        self.Engine = nil
    end
end

--- Updates the FPS.
-- @hidden
function ENT:UpdateFPS()
    if self:HasEngine() and self:HasMedia() then
        self.Engine:SetFPS(self.Media.LowFramerate and 1 or PlayX.GetPlayerFPS())
    end
end

--- Update the volume.
-- @hidden
function ENT:UpdateVolume()
    if self:HasEngine() then
        self.Engine:SetVolume(PlayX.GetPlayerVolume())
    end
end

--- Updates the screen bounds, based on either the screen list or using
-- an algorithm at detecting the screen.
-- @hidden
function ENT:CalculateScreenBounds()
    local model = self.Entity:GetModel()
    local info = PlayXScreens[model:lower()]
    
    -- Is this a pre-defined screen?
    if info then
        if info.IsProjector then
            --self:SetProjectorBounds(info.Right, info.Up, info.Forward)
            self:SetScreenBounds(nil, 1024, 512,
                                 info.Right, info.Up, info.Forward)
        else
            local right = info.RotateAroundRight
            local up = info.RotateAroundUp
            local forward = info.RotateAroundForward
            
            -- For backwards compatibility, adapt to the new rotation system
            if type(right) == 'boolean' then
                right = right and -90 or 0
            end
            if type(up) == 'boolean' then
                up = up and 90 or 0
            end
            if type(forward) == 'boolean' then
                forward = forward and 90 or 0
            end
            
            self:SetScreenBounds(info.Offset, info.Width, info.Height,
                                 right, up, forward)
        end
    -- Or let's do our best attempt at fitting a screen automatically.
    else
        local center = self.Entity:OBBCenter()
        local mins = self.Entity:OBBMins()
        local maxs = self.Entity:OBBMaxs()
        local rightArea = (maxs.z * mins.z) * (maxs.y * mins.y)
        local forwardArea = (maxs.z * mins.z) * (maxs.x * mins.x)
        local topArea = (maxs.y * mins.y) * (maxs.x * mins.x)
        local maxArea = math.max(rightArea, forwardArea, topArea)
        
        if maxArea == rightArea then
	        local width = maxs.y - mins.y
	        local height = maxs.z - mins.z
	        local pos = Vector(center.x + (maxs.x - mins.x) / 2 + 0.5,
	                           center.y - width / 2,
	                           center.z + height / 2)
            self:SetScreenBounds(pos, width, height, -90, 90, 0)
        elseif maxArea == forwardArea then
            local width = maxs.x - mins.x
            local height = maxs.z - mins.z
            local pos = Vector(center.x + width / 2,
                               center.y + (maxs.y - mins.y) / 2 + 0.5,
                               center.z + height / 2)
            self:SetScreenBounds(pos, width, height, 180, 0, -90)
        else
            local width = maxs.y - mins.y
            local height = maxs.x - mins.x
            local pos = Vector(center.x + height / 2,
                               center.y + width / 2,
                               center.z + (maxs.z - mins.z) / 2 + 0.5)
            self:SetScreenBounds(pos, width, height, 0, -90, 0)
        end
    end
end

--- Set the bounds for non-projector screens.
-- @param pos Offset
-- @param width
-- @param height
-- @param right
-- @param up
-- @param forward
-- @hidden
function ENT:SetScreenBounds(pos, width, height, right, up, forward)
    self.IsProjector = pos == nil
    
    self.ScreenOffset = pos
    self.ScreenWidth = width
    self.ScreenHeight = height
    
    if self:HasMedia() then
        self:CreateEngine(width, height)
    end
    
    if self:HasEngine() then
        self.Width, self.Height = self.Engine.Width, self.Engine.Height
    else
        self.Width = 1024
        self.Height = self.IsSquare and 1024 or 512
    end
    
    -- Fit the content to the viewport
    if width / height < self.Width / self.Height then
        self.DrawScale = width / self.Width
        self.DrawWidth = self.Width
        self.DrawHeight = height / self.DrawScale
        self.DrawShiftX = 0
        self.DrawShiftY = (self.DrawHeight - self.Height) / 2
    else
        self.DrawScale = height / self.Height
        self.DrawWidth = width / self.DrawScale
        self.DrawHeight = self.Height
        self.DrawShiftX = (self.DrawWidth - self.Width) / 2
        self.DrawShiftY = 0
    end
    
    self.Right = right
    self.Up = up
    self.Forward = forward
end

--- Set the bounds for projector screens.
-- @param right
-- @param up
-- @param forward
-- @hidden
function ENT:SetProjectorBounds(right, up, forward)
    self.IsProjector = true
    
    self.Forward = forward
    self.Right = right
    self.Up = up
    
    if self:HasMedia() then
        self:CreateEngine(1024, 512)
    end
    
    if self:HasEngine() then    
        self.Width, self.Height = self.Engine.Width, self.Engine.Height
    else
        self.Width = 1024
        self.Height = 512
    end
    
    self.DrawScale = 1 -- Not used
end

--- Returns the position from which the projector is projecting from if it's
-- a projector, otherwise it returns the screen position. 
-- @return Position
-- @return Normal
function ENT:GetSourcePos()
    if self.IsProjector then
        return self.Entity:GetPos() + self.Entity:OBBCenter()
    else
        -- This is not right
        local p = self.ScreenOffset
        return self.Entity:LocalToWorld(p)
    end
end

--- Gets the projector's screen position, or if it's not a projector, a psuedo
-- projection line endpoint.
-- If the entity is not a projector then nil will be returned. 
-- @return Position
-- @return Normal
-- @return Boolean indicating whether a screen is showing
function ENT:GetProjectionPos()
    if self.IsProjector then
	    local excludeEntities = player.GetAll()
	    table.insert(excludeEntities, self.Entity)
	    
	    local dir = self.Entity:GetForward() * self.Forward * 4000 +
	                self.Entity:GetRight() * self.Right * 4000 +
	                self.Entity:GetUp() * self.Up * 4000
	    local tr = util.QuickTrace(self.Entity:LocalToWorld(self.Entity:OBBCenter()),
	                               dir, excludeEntities)
	    
	    if tr.Hit then
	        return tr.HitPos, tr.HitNormal, true
	    else
	        return tr.HitPos, tr.HitNormal, false
	    end
	else
        local ang = self.Entity:GetAngles()
        
        ang:RotateAroundAxis(ang:Right(), self.Right)
        ang:RotateAroundAxis(ang:Up(), self.Up)
        ang:RotateAroundAxis(ang:Forward(), self.Forward)
        
        return self:GetSourcePos() + ang:Up() *
            (10 * (self.DrawWidth * self.DrawHeight * self.DrawScale) ^ 0.3)
	end
end

--- Creates the engine for drawing.
-- @hidden
function ENT:CreateEngine(screenWidth, screenHeight)
    local engine, engineError = 
        PlayX.ResolveHandler(self.Media.Handler, self.Media.Arguments,
                             screenWidth, screenHeight,
                             self:GetElapsedTime(),
                             PlayX.GetPlayerVolume())
    
    self.Engine = engine
    self.EngineError = engineError
    self.Centered = self.Engine and self.Engine.Centered or false
end

--- Resets the render bounds.
function ENT:ResetRenderBounds()
    self:SetRenderBoundsWS(Vector(-100, -100, -100), Vector(100, 100, 100))
    self:SetRenderBoundsWS(Vector(-50000, -50000, -50000), Vector(50000, 50000, 50000))
end

--- Draw function.
-- @hidden
function ENT:Draw()
    self.Entity:DrawModel()
    
    if self.DrawScale then
        render.SuppressEngineLighting(true)
        if self.Engine and self.Engine.PrePaint then
            self.Engine:PrePaint()
        end
        
        -- Projector rendering
        if self.IsProjector then
            local excludeEntities = player.GetAll()
            table.insert(excludeEntities, self.Entity)
            
            local dir = self.Entity:GetForward() * self.Forward * 4000 +
                        self.Entity:GetRight() * self.Right * 4000 +
                        self.Entity:GetUp() * self.Up * 4000
            local tr = util.QuickTrace(self.Entity:LocalToWorld(self.Entity:OBBCenter()),
                                       dir, excludeEntities)
            
            if tr.Hit then
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Forward(), 90) 
                ang:RotateAroundAxis(ang:Right(), -90)
                
                local width = tr.HitPos:Distance(self.Entity:LocalToWorld(self.Entity:OBBCenter())) * 0.001
                local height = width / 2
                local pos = tr.HitPos - ang:Right() * height * self.Height / 2
                            - ang:Forward() * width * self.Width / 2
                            + ang:Up() * 2
                
                cam.Start3D2D(pos, ang, width)
                if self.Engine then
                    self.Engine:Paint()
                else
                    surface.SetDrawColor(0, 0, 0, 255)
                    surface.DrawRect(0, 0, 1024, 512)
                    
                    if not PlayX.Enabled then
                        draw.SimpleText("Re-enable the player in the tool menu -> Options",
                                        "HUDNumber",
                                        1024 / 2, 512 / 2, Color(255, 255, 255, 255),
                                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
                cam.End3D2D()
            end
        else
            local shiftMultiplier = 1
            if not self.Centered then
                shiftMultiplier = 2
            end
            
            local p = self.ScreenOffset - 
                Vector(0, self.DrawShiftX * self.DrawScale,
                       self.DrawShiftY * shiftMultiplier * self.DrawScale)
            local pos = self.Entity:LocalToWorld(p)
            local ang = self.Entity:GetAngles()
            
            ang:RotateAroundAxis(ang:Right(), self.Right)
            ang:RotateAroundAxis(ang:Up(), self.Up)
            ang:RotateAroundAxis(ang:Forward(), self.Forward)
            
            cam.Start3D2D(pos, ang, self.DrawScale)
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(-self.DrawShiftX, -self.DrawShiftY * shiftMultiplier, self.DrawWidth, self.DrawHeight)
            if self.Engine then
                self.Engine:Paint()
            else
                if not PlayX.Enabled then
                    draw.SimpleText("Re-enable the player in the tool menu -> Options",
                                    "HUDNumber",
                                    self.DrawWidth / 2 - self.DrawShiftX,
                                    self.DrawHeight / 2 - self.DrawShiftY * shiftMultiplier,
                                    Color(255, 255, 255, 255),
                                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            cam.End3D2D()
        end

        if self.Engine and self.Engine.PostPaint then
            self.Engine:PostPaint()
        end
        render.SuppressEngineLighting(false)
    end
end

--- On remove function.
-- @hidden
function ENT:OnRemove()
    if self:HasEngine() then
        local ent = self
        local engine = self.Engine
	    
	    -- Give Gmod 200ms to really delete the entity
	    timer.Simple(0.2, function()
	        if not ValidEntity(ent) then -- Entity is really gone
		        engine:Destroy()
		        engine = nil
	        elseif ValidEntity(ent) then -- Gmod lied
	            ent:ResetRenderBounds()
	        end
	   end)
    end
end