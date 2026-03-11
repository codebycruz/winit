local winit = require("winit")

local eventLoop = winit.EventLoop.new()
local window = winit.Window.fromEventLoop(eventLoop)
window:setTitle("keyboard demo")

local heldKeys = {}

local function updateTitle()
	local keys = {}
	for k in pairs(heldKeys) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local title = #keys > 0 and table.concat(keys, " + ") or "keyboard demo"
	window:setTitle(title)
end

eventLoop:run(function(event, handler)
	if event.name == "windowClose" then
		handler:exit()
	elseif event.name == "focusOut" then
		heldKeys = {}
		updateTitle()
	elseif event.name == "keyPress" then
		heldKeys[event.key] = true
		updateTitle()
	elseif event.name == "keyRelease" then
		heldKeys[event.key] = nil
		updateTitle()
	end
end)
