--!strict
-- Client entry point: starts every controller.

local DoorController = require(script.DoorController)
local HudController = require(script.HudController)

DoorController.start()
HudController.start()
