pcall(include, "autorun/translation.lua") local L = translation and translation.L or function(s) return s end

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

PlayX._BookmarksPanelList = nil

local hasLoaded = false

--- Draw the settings panel.
local function SettingsPanel(panel)
    panel:ClearControls()
--    panel:AddHeader()

    panel:AddControl("CheckBox", {
        Label = L"Enabled",
        Command = "playx_enabled",
    })

    if PlayX.CrashDetected then
		local msg = panel:AddControl("Label", {Text = L("PlayX has detected a crash in a previous session. Is it safe to " ..
			"re-enable PlayX? For most people, crashes " ..
			"with the new versions of Gmod and PlayX are very rare, but a handful " ..
			"of people crash every time something is played. Try enabling " ..
			"PlayX a few times to determine whether you fall into this group.")})
		msg:SetWrap(true)
        msg:SetColor(Color(255, 255, 255, 255))
        msg:SetTextColor(Color(255, 255, 255, 255))
		msg:SetTextInset(8,0)
		msg:SetContentAlignment(7)
		msg:SetAutoStretchVertical( true )
        msg.Paint = function(self)
            draw.RoundedBox(6, 0, 0, self:GetWide(), self:GetTall(), Color(255, 0, 0, 100))
        end
    end

    if not PlayX.Enabled then return end

    panel:AddControl("CheckBox", {
        Label = L"Show errors in message boxes",
        Command = "playx_error_windows",
    }):SetTooltip("Uncheck to use hints instead")

    panel:AddControl("Slider", {
        Label = L"Volume:",
        Command = "playx_volume",
        Type = "Float",
        Min = "1",
        Max = "100",
    }):SetTooltip(L"May have no effect, depending on what's playing.")

    local numHasMedia, numResumable, numPlaying = PlayX.GetCounts()

    if numHasMedia > 0 then
        if numResumable > 0 then
            local button = panel:AddControl("Button", {
                Label = L"Hide Player",
                Command = "playx_hide",
            })

            if numPlaying == 0 then
                button:SetDisabled(true)
            end

            if numPlaying > 0 then
                panel:AddControl("Button", {
                    Label = L"Re-initialize Player",
                    Command = "playx_resume",
                })
            else
                panel:AddControl("Button", {
                    Label = L"Resume Play",
                    Command = "playx_resume",
                })
            end

            panel:AddControl("Label", {
                Text = L"The current media supports resuming."
            })
        else
            if numPlaying > 0 then
                panel:AddControl("Button", {
                    Label = L"Stop Play",
                    Command = "playx_hide",
                }):SetTooltip("This is a temporary disable.")

                panel:AddControl("Button", {
                    Label = L"Re-initialize Player",
                    Command = "playx_resume",
                }):SetDisabled(true)
            else
                panel:AddControl("Button", {
                    Label = L"Stop Play",
                    Command = "playx_hide",
                }):SetDisabled(true)

                panel:AddControl("Button", {
                    Label = L"Resume Play",
                    Command = "playx_resume",
                }):SetDisabled(true)
            end

            panel:AddControl("Label", {
                Text = L"The current media cannot be resumed once stopped."
            })
        end
    end
end

--- Draw the control panel.
local function ControlPanel(panel)
    panel:ClearControls()
--    panel:AddHeader()

    local options = {
        ["Auto-detect"] = {["playx_provider"] = ""}
    }

    for id, name in pairs(PlayX.Providers) do
        options[name] = {["playx_provider"] = id}
    end

    local label = panel:AddControl("Label", {Text = "Provider:"})

    panel:AddControl("ListBox", {
        Label = L"Provider:",
        Options = options,
    })

    local textbox = panel:AddControl("TextBox", {
        Label = L"URI:",
        Command = "playx_uri",
        WaitForEnter = false,
    })
    textbox:SetTooltip("Example: http://www.youtube.com/watch?v=NWdTcxv4V-g")

    panel:AddControl("TextBox", {
        Label = L"Start At:",
        Command = "playx_start_time",
        WaitForEnter = false,
    })

    if PlayX.JWPlayerURL then
        panel:AddControl("CheckBox", {
            Label = L"Use an improved player when applicable",
            Command = "playx_use_jw",
        })
    end

    panel:AddControl("CheckBox", {
        Label = L"Force low frame rate",
        Command = "playx_force_low_framerate",
    }):SetTooltip("Use this for music-only videos")

    panel:AddControl("Button", {
        Label = L"Open Media",
        Command = "playx_gui_open",
    })

    local button = panel:AddControl("Button", {
        Label = L"Close Media",
        Command = "playx_gui_close",
    })

    panel:AddControl("Button", {
        Label = L"Add as Bookmark",
        Command = "playx_gui_bookmark",
    })

    local numHasMedia, numResumable, numPlaying = PlayX.GetCounts()

    if not numHasMedia then
        button:SetDisabled(true)
    end

    local button = panel:AddControl("Button", {
        Label = L"Check for Updates",
        Command = "playx_update_window",
    })
end
PANEL = {}
vgui.Register( "dlistview", PANEL ,"DListView") -- Hacky Fix
--- Draw the control panel.
local function BookmarksPanel(panel)
    panel:ClearControls()
    --panel:AddHeader()

    panel:SizeToContents(true)

    local bookmarks = panel:AddControl("DListView", {})
    PlayX._BookmarksPanelList = bookmarks
    bookmarks:SetMultiSelect(false)
    bookmarks:AddColumn(L"Title")
    bookmarks:AddColumn(L"URI")
    bookmarks:SetTall(ScrH() * 7.5/10)

    for k, bookmark in pairs(PlayX.Bookmarks) do
        local line = bookmarks:AddLine(bookmark.Title, bookmark.URI)
        if bookmark.Keyword ~= "" then
            line:SetTooltip(L"Keyword: " .. bookmark.Keyword)
        end
    end

    bookmarks.OnRowRightClick = function(lst, index, line)
        local menu = DermaMenu()
        menu:AddOption(L"Open", function()
            PlayX.GetBookmark(line:GetValue(1):Trim()):Play()
        end)
        menu:AddOption(L"Edit...", function()
            PlayX.OpenBookmarksWindow(line:GetValue(1))
        end)
        menu:AddOption(L"Copy URI", function()
            SetClipboardText(line:GetValue(2))
        end)
        menu:AddOption(L"Copy to 'Administrate'", function()
            PlayX.GetBookmark(line:GetValue(1):Trim()):CopyToPanel()
        end)
        menu:Open()
    end

    bookmarks.DoDoubleClick = function(lst, index, line)
        if not line then return end
        PlayX.GetBookmark(line:GetValue(1):Trim()):Play()
    end

    --local button = panel:AddControl("DButton", {})
	local button = panel:Button("Open Selected")
    button:SetText(L"Open Selected")
    button.DoClick = function()
        if bookmarks:GetSelectedLine() then
            local line = bookmarks:GetLine(bookmarks:GetSelectedLine())
            PlayX.GetBookmark(line:GetValue(1):Trim()):Play()
	    else
            Derma_Message(L"You didn't select an entry.", L"Error", L"OK")
	    end
    end

    local button = panel:Button("Manage Bookmarks")
    button:SetText(L"Manage Bookmarks...")
    button.DoClick = function()
        PlayX.OpenBookmarksWindow()
    end
end

--- PopulateToolMenu hook.
local function PopulateToolMenu()
    hasLoaded = true
    spawnmenu.AddToolMenuOption("Utilities", "PlayX", "PlayXSettings", "Settings", "", "", SettingsPanel)
    spawnmenu.AddToolMenuOption("Utilities", "PlayX", "PlayXControl", "Administrate", "", "", ControlPanel)
    spawnmenu.AddToolMenuOption("Utilities", "PlayX", "PlayXBookmarks", "Bookmarks (Local)", "", "", BookmarksPanel)
end

hook.Add("PopulateToolMenu", "PlayXPopulateToolMenu", PopulateToolMenu)

--- Updates the tool panels. This calls the PlayXUpdateUI hook with no
-- arguments and with no regards to the returned value.
function PlayX.UpdatePanels()
    hook.Call("PlayXUpdateUI", GAMEMODE)

    if not hasLoaded then return end

    SettingsPanel(controlpanel.Get("PlayXSettings"))
    ControlPanel(controlpanel.Get("PlayXControl"))
end
