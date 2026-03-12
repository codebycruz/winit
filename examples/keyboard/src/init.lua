local winit = require("winit")

local eventLoop = winit.EventLoop.new()
local window = winit.Window.fromEventLoop(eventLoop)

local heldKeys = {}
local grabMode = "none" ---@type winit.CursorGrab

local function updateTitle()
	local keys = {}
	for k in pairs(heldKeys) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local keysStr = #keys > 0 and table.concat(keys, " + ") or "none"
	window:setTitle("keys: " .. keysStr .. "  |  grab: " .. grabMode .. "  (C=contain  L=locked  N=none)")
end

updateTitle()

local function setGrab(mode)
	grabMode = mode
	window:setCursorGrab(mode)
	updateTitle()
end

eventLoop:run(function(event, handler)
	if event.name == "windowClose" then
		handler:exit()
	elseif event.name == "focusOut" then
		heldKeys = {}
		updateTitle()
	elseif event.name == "keyPress" then
		local key = event.key
		if key == "c" then
			setGrab(grabMode == "contain" and "none" or "contain")
		elseif key == "l" then
			setGrab(grabMode == "locked" and "none" or "locked")
		elseif key == "n" or key == "escape" then
			setGrab("none")
		else
			heldKeys[key] = true
			updateTitle()
		end
	elseif event.name == "keyRelease" then
		heldKeys[event.key] = nil
		updateTitle()
	end
end)
