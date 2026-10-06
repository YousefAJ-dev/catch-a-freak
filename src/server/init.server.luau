--!strict
-- Server entry point: starts every service in dependency order.

local DataService = require(script.DataService)
local ZoneService = require(script.ZoneService)
local RadiationService = require(script.RadiationService)
local DebugService = require(script.DebugService)

DataService.start()
ZoneService.start()
RadiationService.start()
DebugService.start()
