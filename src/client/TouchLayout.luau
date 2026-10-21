--!strict
-- Touch controls layout: on phones and tablets the action buttons gather on
-- the right around a bigger jump button, so one thumb reaches them all.
--
--   column B   column A
--               [Freakpedia]
--   [Dash]
--   [Gold]      [Grab]
--   [Trap]
--   [Net]       [Jump]
--
-- Slots are measured in screen pixels from the bottom-right corner, in the
-- same frame as Roblox's TouchGui, so they line up with the jump button. Guis
-- using them call TouchLayout.adopt, which also opts them out of
-- UiScaleController's shrinking (these sizes are already chosen per screen).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TouchLayout = {}

local changedEvent = Instance.new("BindableEvent")
-- Fires when touch mode turns on or off or the screen size changes.
TouchLayout.changed = changedEvent.Event

-- Touch controls; in Studio, /touchmode on forces them for testing.
function TouchLayout.enabled(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
		or (RunService:IsStudio() and player:GetAttribute("DebugTouchMode") == true)
end

type Metrics = { margin: number, gap: number, jump: number, button: number }

local function metrics(): Metrics
	local view = workspace.CurrentCamera.ViewportSize
	if math.min(view.X, view.Y) <= 500 then -- phone
		return { margin = 14, gap = 8, jump = 92, button = 62 }
	end
	return { margin = 24, gap = 12, jump = 140, button = 92 } -- tablet
end

-- Position and size for a slot, for a GuiObject with AnchorPoint (1, 1).
-- Slots: "jump", "grab", "freakpedia", "item1".."item3", "dash".
function TouchLayout.slot(name: string): (UDim2, UDim2)
	local m = metrics()
	local right, bottom, size
	local columnB = m.margin + m.jump + m.gap
	if name == "jump" then
		right, bottom, size = m.margin, m.margin, m.jump
	elseif name == "grab" then
		right, bottom, size = m.margin, m.margin + m.jump + m.gap, m.jump
	elseif name == "freakpedia" then
		right, bottom, size = m.margin + (m.jump - m.button) / 2, m.margin + 2 * (m.jump + m.gap), m.button
	else
		local row = if name == "dash" then 4 else tonumber(name:match("^item(%d)$"))
		assert(row, "unknown touch slot " .. name)
		right, bottom, size = columnB, m.margin + (row - 1) * (m.button + m.gap), m.button
	end
	return UDim2.new(1, -right, 1, -bottom), UDim2.fromOffset(size, size)
end

local function touchGui(): ScreenGui?
	return player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("TouchGui") :: ScreenGui?
end

-- In touch mode, puts `gui` in the TouchGui's frame and opts it out of UI
-- scaling; otherwise returns it to normal.
function TouchLayout.adopt(gui: ScreenGui)
	local touch = TouchLayout.enabled()
	gui:SetAttribute("NoAutoScale", touch or nil)
	local reference = touchGui()
	if touch and reference then
		gui.ScreenInsets = reference.ScreenInsets
		gui.IgnoreGuiInset = reference.IgnoreGuiInset
	else
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.IgnoreGuiInset = false
	end
end

-- Roblox's PlayerModule builds the jump button (and rebuilds it when the
-- screen changes size); each new one is resized into the "jump" slot.
local function fitJump(button: Instance)
	if button.Name ~= "JumpButton" or not button:IsA("GuiObject") then
		return
	end
	task.defer(function()
		local position, size = TouchLayout.slot("jump")
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = position
		button.Size = size
	end)
end

local function watchTouchGui(gui: Instance)
	if gui.Name ~= "TouchGui" then
		return
	end
	local frame = gui:WaitForChild("TouchControlFrame", 10)
	if not frame then
		return
	end
	frame.ChildAdded:Connect(fitJump)
	local jump = frame:FindFirstChild("JumpButton")
	if jump then
		fitJump(jump)
	end
	changedEvent:Fire() -- guis can now match the TouchGui's insets
end

function TouchLayout.start()
	local function fire()
		local gui = touchGui()
		local jump = gui and gui:FindFirstChild("JumpButton", true)
		if jump then
			fitJump(jump)
		end
		changedEvent:Fire()
	end
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(fire)
	player:GetAttributeChangedSignal("DebugTouchMode"):Connect(fire)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fire)

	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child)
		task.spawn(watchTouchGui, child)
	end)
	local existing = playerGui:FindFirstChild("TouchGui")
	if existing then
		task.spawn(watchTouchGui, existing)
	end
end

return TouchLayout
