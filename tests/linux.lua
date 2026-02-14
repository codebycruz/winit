if jit.os ~= "Linux" then
	return
end

local ffi = require("ffi")
local x11 = require("x11api")
local winit = require("winit")

local EventLoop = winit.EventLoop
local Window = winit.Window

local passed = 0
local failed = 0

local function check(name, condition, msg)
	if condition then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. name .. (msg and (" - " .. msg) or ""))
	end
end

-- Test 1: Create an event loop and window
local eventLoop = EventLoop.new()
check("EventLoop.new", eventLoop ~= nil)

local window = Window.new(eventLoop, 800, 600)
check("Window.new", window ~= nil)
check("Window.width", window.width == 800, "expected 800, got " .. tostring(window.width))
check("Window.height", window.height == 600, "expected 600, got " .. tostring(window.height))
check("Window.id", window.id ~= nil and window.id ~= 0, "window id should be non-zero")

eventLoop:register(window)

-- Test 2: Query window attributes via X11 API directly
-- Flush and give the window manager time to map the window
x11.flush(eventLoop.display)
os.execute("sleep 0.1")

local attrs = x11.getWindowAttributes(eventLoop.display, window)
check("getWindowAttributes", attrs ~= nil)
if attrs then
	check("attrs.width", attrs.width == 800, "expected 800, got " .. tostring(attrs.width))
	check("attrs.height", attrs.height == 600, "expected 600, got " .. tostring(attrs.height))
end

-- Test 3: Verify window is visible via xwininfo (shell out)

local windowIdHex = string.format("0x%x", tonumber(window.id))

-- Use xwininfo to verify the window exists and has correct geometry
local tmpFile = "/tmp/winit_test_xwininfo_" .. os.time() .. ".txt"
local cmd = "xwininfo -id " .. windowIdHex .. " > " .. tmpFile .. " 2>&1"
local exitOk = os.execute(cmd)
check("xwininfo runs", exitOk == 0 or exitOk == true)

local f = io.open(tmpFile, "r")
if f then
	local output = f:read("*a")
	f:close()
	os.remove(tmpFile)

	check("xwininfo finds window", output:find("Width:") ~= nil, "xwininfo output missing Width")
	local w = output:match("Width:%s*(%d+)")
	local h = output:match("Height:%s*(%d+)")
	if w and h then
		check("xwininfo width", tonumber(w) == 800, "expected 800, got " .. w)
		check("xwininfo height", tonumber(h) == 600, "expected 600, got " .. h)
	end
else
	os.remove(tmpFile)
	check("xwininfo output readable", false, "could not read tmpfile")
end

-- Test 4: Set title and verify via xprop
window:setTitle("winit test window")
x11.flush(eventLoop.display)
os.execute("sleep 0.05")

local tmpFile2 = "/tmp/winit_test_xprop_" .. os.time() .. ".txt"
local cmd2 = "xprop -id " .. windowIdHex .. " _NET_WM_NAME > " .. tmpFile2 .. " 2>&1"
os.execute(cmd2)

local f2 = io.open(tmpFile2, "r")
if f2 then
	local output2 = f2:read("*a")
	f2:close()
	os.remove(tmpFile2)

	check("xprop title", output2:find("winit test window") ~= nil,
		"expected title 'winit test window' in: " .. output2:gsub("\n", " "))
else
	os.remove(tmpFile2)
	check("xprop output readable", false, "could not read tmpfile")
end

-- Test 5: Run event loop briefly and check that we receive expected events
local events = {}
local eventCount = 0

eventLoop:run(function(event, handler)
	handler:setMode("poll")
	eventCount = eventCount + 1
	events[event.name] = true

	-- Let the loop run for a bit to collect events, then exit
	if eventCount > 20 or events["aboutToWait"] then
		handler:exit()
	end
end)

check("received aboutToWait event", events["aboutToWait"] == true)

-- Test 6: Create a second window and verify both work
local eventLoop2 = EventLoop.new()
local win2 = Window.fromEventLoop(eventLoop2)
check("Window.fromEventLoop", win2 ~= nil)
check("fromEventLoop default width", win2.width == 1200, "expected 1200, got " .. tostring(win2.width))
check("fromEventLoop default height", win2.height == 720, "expected 720, got " .. tostring(win2.height))

local attrs2 = x11.getWindowAttributes(eventLoop2.display, win2)
check("second window attributes", attrs2 ~= nil)
if attrs2 then
	check("second window width", attrs2.width == 1200, "expected 1200, got " .. tostring(attrs2.width))
	check("second window height", attrs2.height == 720, "expected 720, got " .. tostring(attrs2.height))
end

win2:destroy()

-- Test 7: Set cursor (should not error)
local cursorOk = pcall(function()
	-- Need a fresh window since we destroyed the event loop's window
	local el = EventLoop.new()
	local w = Window.new(el, 200, 200)
	w:setCursor("pointer")
	w:setCursor("hand2")
	w:resetCursor()
	w:destroy()
end)
check("setCursor/resetCursor", cursorOk)

-- Summary
print(string.format("\nLinux window tests: %d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed")
end
