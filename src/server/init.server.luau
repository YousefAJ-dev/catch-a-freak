--!strict
-- Server entry point: starts every service in dependency order.

local DataService = require(script.DataService)
local ZoneService = require(script.ZoneService)
local RadiationService = require(script.RadiationService)
local CarryService = require(script.CarryService)
local FreakService = require(script.FreakService)
local FarmService = require(script.FarmService)
local ShopService = require(script.ShopService)
local DebugService = require(script.DebugService)

DataService.start()
ZoneService.start()
RadiationService.start()
CarryService.start()
FreakService.start()
FarmService.start()
ShopService.start()
DebugService.start()
