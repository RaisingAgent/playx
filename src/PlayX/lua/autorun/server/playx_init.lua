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

AddCSLuaFile("autorun/client/playx_init.lua")
AddCSLuaFile("playx/functions.lua")
AddCSLuaFile("playx/client/playx.lua")
AddCSLuaFile("playx/client/providers.lua")
AddCSLuaFile("playx/client/panel.lua")
AddCSLuaFile("playx/client/ui.lua")
AddCSLuaFile("playx/client/engines/html.lua")
AddCSLuaFile("playx/client/engines/gm_chrome.lua")

include("playx/playx.lua")