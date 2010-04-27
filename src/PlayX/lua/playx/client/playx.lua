-- PlayX
-- Copyright (c) 2009 sk89q <http://www.sk89q.com>
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

require("datastream")

CreateClientConVar("playx_enabled", 1, true, false)
CreateClientConVar("playx_fps", 14, true, false)
CreateClientConVar("playx_volume", 80, true, false)
CreateClientConVar("playx_provider", "", false, false)
CreateClientConVar("playx_uri", "", false, false)
CreateClientConVar("playx_start_time", "0:00", false, false)
CreateClientConVar("playx_force_low_framerate", 0, false, false)
CreateClientConVar("playx_use_jw", 1, false, false)
CreateClientConVar("playx_ignore_length", 0, false, false)
CreateClientConVar("playx_use_chrome", 1, true, false)
CreateClientConVar("playx_error_windows", 1, true, false)

------------------------------------------------------------
-- PlayX Client API
------------------------------------------------------------

PlayX = {}

include("playx/functions.lua")
include("playx/client/bookmarks.lua")
include("playx/client/handlers.lua")
include("playx/client/panel.lua")
include("playx/client/ui.lua")
include("playx/client/engines/html.lua")
include("playx/client/engines/gm_chrome.lua")

PlayX.Enabled = true
PlayX.Instances = {}
PlayX.JWPlayerURL = ""
PlayX.HostURL = ""

local spawnWindow = nil
local updateWindow = nil

--- Checks whether there are any players. This doesn't check to see whether
-- there are any PlayX entities, as something can still be playing even
-- if the client is unaware of an entity.
-- @return
function PlayX.PlayerExists()
    return #PlayX.Instances > 0
end

--- Checks whether any media being played can be resumed.
function PlayX.HasResumable()
    for _, v in pairs(PlayX.Instances) do
        if v.Media.Resumable then return true end
    end
    
    return false
end

--- Enables the player.
function PlayX.Enable()
    RunConsoleCommand("playx_enabled", "1")
end

--- Disables the player.
function PlayX.Disable()
    RunConsoleCommand("playx_enabled", "0")
end

--- Gets the player FPS.
-- @return
function PlayX.GetPlayerFPS()
    return math.Clamp(GetConVar("playx_fps"):GetInt(), 1, 30)
end

--- Sets the player FPS
-- @param fps
function PlayX.SetPlayerFPS(fps)
    RunConsoleCommand("playx_fps", fps)
end

--- Gets the player volume.
-- @return
function PlayX.GetPlayerVolume()
    return math.Clamp(GetConVar("playx_volume"):GetInt(), 0, 100)
end

--- Sets the player volume.
-- @return
function PlayX.SetPlayerVolume(vol)
    RunConsoleCommand("playx_volume", vol)
end

--- Resume playing of everything.
function PlayX.ResumePlay()
    if PlayX.PlayerExists() then
        PlayX.ShowError("Nothing is playing.")
    elseif PlayX.Enabled then
        local count = 0
        
        for _, v in pairs(PlayX.Instances) do
            if v.Resumable then
                v:Start()
                count = count + 1
            end
        end
        
        if count == 0 then
            PlayX.ShowError("The media being played cannot be resumed.")
        end
    end
end

--- Stops playing everything.
function PlayX.StopPlay()
    if not PlayX.PlayerExists() then
        PlayX.ShowError("Nothing is playing.\n")
    els
        for _, v in pairs(PlayX.Instances) do
            v:Stop()
        end
    end
end
PlayX.HidePlayer = PlayX.StopPlay -- Legacy

--- Reset the render bounds of the project screen.
function PlayX.ResetRenderBounds()
    if not PlayX.PlayerExists() then
        PlayX.ShowError("Nothing is playing.\n")
    elseif PlayX.Enabled then
        for _, v in pairs(PlayX.Instances) do
            if ValidEntity(v.Entity) then
                v.Entity:ResetRenderBounds()
            end
        end
    end
end

--- Sends a request to the server to play something.
-- @param provider Name of provider, leave blank to auto-detect
-- @param uri URI to play
-- @param start Time to start the video at, in seconds
-- @param forceLowFramerate Force the client side players to play at 1 FPS
-- @param useJW True to allow the use of the JW player, false for otherwise, nil to default true
-- @param ignoreLength True to not check the length of the video (for auto-close)
-- @return The result generated by a provider, or nil and the error message
function PlayX.RequestOpenMedia(provider, uri, start, forceLowFramerate, useJW, ignoreLength)
    if useJW == nil then useJW = true end
    RunConsoleCommand("playx_open", uri, provider, start,
                      forceLowFramerate and 1 or 0, useJW and 1 or 0,
                      ignoreLength and 1 or 0)
end

--- Sends a request to the server to stop playing.
function PlayX.RequestCloseMedia()
    RunConsoleCommand("playx_close")
end

--- Builds an instance.
-- @param handler
-- @param arguments
function PlayX.ResolveHandler(handler, arguments)
    local handlers = list.Get("PlayXHandlers")
    
    if handlers[handler] then
        return handlers[handler].Build(arguments)
    else
        Error("Unknown handler: " .. handler)
    end
end

--- Registers an instance
-- @param instance
function PlayX.Register(instance)
    local entIndex = instance.EntityIndex
    
    if PlayX.Instances[entIndex] then
        -- Do a destruct that tries to retain references
        PlayX.Instances[entIndex]:Destruct(true)
    end
    
    PlayX.Instances[entIndex] = instance
end

--- Un-registers an instance
-- @param entIndex Entity index or instance
function PlayX.Unregister(entIndex)
    if type(entIndex) == 'table' then
        entIndex = instance.EntityIndex
    end
    
    if PlayX.Instances[entIndex] then
        PlayX.Instances[entIndex]:Destruct(false)
        PlayX.Instances[entIndex] = nil
    end
end

------------------------------------------------------------
-- PlayerInstance
------------------------------------------------------------

PlayerInstance = {}
mkclass(PlayerInstance)

--- Constructs a PlayerInstance.
function PlayerInstance:Construct(entIndex, handler, arguments, startTime)
    self.Handler = handler
    self.Arguments = arguments
    self.StartTime = startTime
    self.ResumeSupported = arguments.ResumeSupported
    self.LowFramerate = arguments.LowFramerate
    self.EntityIndex = entIndex
    self.Engine = nil
    
    if PlayX.Enabled then
        self.Engine:Start()
    end
    
    self.SetFPS = self.Engine.SetFPS
    self.SetVolume = self.Engine.SetVolume
    self.Destruct = self.Engine.Destruct
end

--- Used to get the associated entity. May return NULL entity, but it will
-- never return a non gmod_playx entity.
function PlayerInstance:GetEntity()
    local ent = ents.GetByIndex(self.EntityIndex)
    
    if ValidEntity(ent) and ent:GetClass() ~= "gmod_playx" then
        Error(string.format("Ent index %d is not a gmod_playx entity", entIndex))
    end
    
    return ent
end

--- Starts playing.
function PlayerInstance:Start()
    if self.Engine then
        self.Engine:Destruct(true) -- Kill old engine
    end
    
    self.Engine = PlayX.ResolveHandler(handler, arguments)
    
    -- Attach the engine
    if ValidEntity(self:GetEntity()) then
        self:GetEntity():AttachEngine(self.Engine)
    end
end

--- Stops playing.
function PlayerInstance:Stop()
    if self.Engine then
        self.Engine:Destruct()
    end
    
    -- Detach the engine
    if ValidEntity(self:GetEntity()) then
        self:GetEntity():AttachEngine(nil)
    end
end

--- Set the FPS.
-- @param fps
function PlayerInstance:SetFPS(fps)
    if self.Engine then
        self.Engine:SetFPS(fps)
    end
end

--- Set the volume.
-- @param volume
function PlayerInstance:SetVolume(volume)
    if self.Engine then
        self.Engine:SetVolume(volume)
    end
end

--- Destruct.
function PlayerInstance:Destruct()
    if self.Engine then
        self.Engine:Destruct()
    end
end

------------------------------------------------------------
-- PlayX Server->Client Messages
------------------------------------------------------------

--- Called on PlayXRegister user message.
local function DSRegister(_, id, encoded, decoded)
    local entIndex = decoded.EntityIndex
    local handler = decoded.Handler
    local arguments = decoded.Arguments
    local playAge = decoded.PlayAge
    local startTime = CurTime() - playAge
    
    local instance = PlayerInstance(entIndex, handler, arguments, startTime)
    PlayX.Register(instance)
end

--- Called on PlayXUnregister user message.
local function UMsgUnregister(um)
    local entIndex = um:ReadLong()
    
    PlayX.Deregister(entIndex)
end

--- Called on PlayXProvidersList user message.
local function DSProvidersList(_, id, encoded, decoded)
    local list = decoded.List
    
    PlayX.Providers = {}
    
    for k, v in pairs(list) do
        PlayX.Providers[k] = v[1]
    end
    
    PlayX.UpdatePanels()
end

--- Called on PlayXSpawnDialog user message.
local function UMsgSpawnDialog(um)
    PlayX.OpenSpawnDialog()
end

--- Called on PlayXJWURL user message.
local function UMsgJWURL(um)
    PlayX.JWPlayerURL = um:ReadString()
    
    PlayX.UpdatePanels()
end

--- Called on PlayXHostURL user message.
local function UMsgHostURL(um)
    PlayX.HostURL = um:ReadString()
    
    PlayX.UpdatePanels()
end

--- Called on PlayXUpdateInfo user message.
local function UMsgUpdateInfo(um)
    local ver = um:ReadString()
    
    PlayX.OpenUpdateWindow(ver)
end

--- Called on PlayXError user message.
local function UMsgError(um)
    local err = um:ReadString()
    
    PlayX.ShowError(err)
end

datastream.Hook("PlayXRegister", DSRegister)
usermessage.Hook("PlayXUnregister", UMsgUnregister)
datastream.Hook("PlayXProvidersList", DSProvidersList)
usermessage.Hook("PlayXSpawnDialog", UMsgSpawnDialog)
usermessage.Hook("PlayXJWURL", UMsgJWURL)
usermessage.Hook("PlayXHostURL", UMsgHostURL)
usermessage.Hook("PlayXUpdateInfo", UMsgUpdateInfo)
usermessage.Hook("PlayXError", UMsgError)

------------------------------------------------------------
-- Cvar Change Callbacks
------------------------------------------------------------

--- Called on playx_enabled change.
local function EnabledCallback(cvar, old, new)
    for _, instance in pairs(PlayX.Instances) do
        if PlayX.Enabled then
            instance:Start()
        else
            instance:Stop()
        end
    end
    
    PlayX.UpdatePanels()
end

--- Called on playx_fps change.
local function FPSChangeCallback(cvar, old, new)
    for _, instance in pairs(PlayX.Instances) do
        instance:SetFPS(PlayX.GetPlayerFPS())
    end
end

--- Called on playx_volume change.
local function VolumeChangeCallback(cvar, old, new)
    hook.Call("PlayXVolumeChanged", nil, {PlayX.GetPlayerVolume()})
    
    for _, instance in pairs(PlayX.Instances) do
        instance:SetVolume(PlayX.GetPlayerVolume())
    end
end

cvars.AddChangeCallback("playx_enabled", EnabledCallback)
cvars.AddChangeCallback("playx_fps", FPSChangeCallback)
cvars.AddChangeCallback("playx_volume", VolumeChangeCallback)

------------------------------------------------------------
-- Console Commands
------------------------------------------------------------

--- Called for concmd playx_gui_open.
local function ConCmdGUIOpen()
    -- Let's handle bookmark keywords
    if GetConVar("playx_provider"):GetString() == "" then
        local bookmark = PlayX.GetBookmarkByKeyword(GetConVar("playx_uri"):GetString())
        if bookmark then
            bookmark:Play()
            return
        end
    end
    
    PlayX.RequestOpenMedia(GetConVar("playx_provider"):GetString(),
                           GetConVar("playx_uri"):GetString(),
                           GetConVar("playx_start_time"):GetString(),
                           GetConVar("playx_force_low_framerate"):GetBool(),
                           GetConVar("playx_use_jw"):GetBool(),
                           GetConVar("playx_ignore_length"):GetBool())
end

concommand.Add("playx_resume", function() PlayX.ResumePlay() end)
concommand.Add("playx_hide", function() PlayX.HidePlayer() end)
concommand.Add("playx_reset_render_bounds", function() PlayX.ResetRenderBounds() end)
concommand.Add("playx_gui_open", ConCmdGUIOpen)
concommand.Add("playx_gui_close", function() PlayX.RequestCloseMedia() end)
concommand.Add("playx_dump_html", function() PlayX.GetHTML() end)
concommand.Add("playx_update_window", function() PlayX.OpenUpdateWindow() end)

------------------------------------------------------------

PlayX.Enabled = GetConVar("playx_enabled"):GetBool()