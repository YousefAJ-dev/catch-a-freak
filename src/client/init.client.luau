--!strict
-- Client entry point: starts every controller.

local DoorController = require(script.DoorController)
local HudController = require(script.HudController)
local FreakRenderer = require(script.FreakRenderer)
local GrabController = require(script.GrabController)
local CarryController = require(script.CarryController)
local NotifyController = require(script.NotifyController)

DoorController.start()
HudController.start()
FreakRenderer.start()
GrabController.start()
CarryController.start()
NotifyController.start()
