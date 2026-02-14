if jit.os ~= "Windows" then
	return
end

local ffi = require("ffi")
local winit = require("winit")

local EventLoop = winit.EventLoop
local Window = winit.Window

-- Extra Win32 API calls for verification (not in the winapi module)
ffi.cdef([[
	typedef void* HWND;
	typedef long LONG;
	typedef int BOOL;
	typedef struct { LONG left; LONG top; LONG right; LONG bottom; } TESTRECT;
	BOOL IsWindow(HWND hWnd);
	BOOL GetClientRect(HWND hWnd, TESTRECT* lpRect);
	int GetWindowTextA(HWND hWnd, char* lpString, int nMaxCount);
	BOOL IsWindowVisible(HWND hWnd);
]])
local user32 = ffi.load("user32")

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
check("Window.hwnd", window.hwnd ~= nil, "window hwnd should not be nil")

eventLoop:register(window)

-- Test 2: Verify window handle is valid via Win32 API
check("IsWindow", user32.IsWindow(window.hwnd) ~= 0, "IsWindow returned false")
check("IsWindowVisible", user32.IsWindowVisible(window.hwnd) ~= 0, "window should be visible")

-- Test 3: Verify client area dimensions
local rect = ffi.new("TESTRECT")
local gotRect = user32.GetClientRect(window.hwnd, rect)
check("GetClientRect", gotRect ~= 0, "GetClientRect failed")
if gotRect ~= 0 then
	local clientW = rect.right - rect.left
	local clientH = rect.bottom - rect.top
	check("client width", clientW == 800, "expected 800, got " .. tostring(clientW))
	check("client height", clientH == 600, "expected 600, got " .. tostring(clientH))
end

-- Test 4: Set title and verify via Win32 API
window:setTitle("winit test window")
local buf = ffi.new("char[256]")
local len = user32.GetWindowTextA(window.hwnd, buf, 256)
check("GetWindowText length", len > 0, "GetWindowTextA returned 0")
if len > 0 then
	local title = ffi.string(buf, len)
	check("window title", title == "winit test window",
		"expected 'winit test window', got '" .. title .. "'")
end

-- Test 5: Run event loop briefly and check expected events
local events = {}
local eventCount = 0

eventLoop:run(function(event, handler)
	handler:setMode("poll")
	eventCount = eventCount + 1
	events[event.name] = true

	if eventCount > 20 or events["aboutToWait"] then
		handler:exit()
	end
end)

check("received aboutToWait event", events["aboutToWait"] == true)

-- Test 6: Create a second window via fromEventLoop
local eventLoop2 = EventLoop.new()
local win2 = Window.fromEventLoop(eventLoop2)
check("Window.fromEventLoop", win2 ~= nil)
check("fromEventLoop default width", win2.width == 1200, "expected 1200, got " .. tostring(win2.width))
check("fromEventLoop default height", win2.height == 720, "expected 720, got " .. tostring(win2.height))

check("second window IsWindow", user32.IsWindow(win2.hwnd) ~= 0)

local rect2 = ffi.new("TESTRECT")
local gotRect2 = user32.GetClientRect(win2.hwnd, rect2)
check("second GetClientRect", gotRect2 ~= 0)
if gotRect2 ~= 0 then
	local clientW2 = rect2.right - rect2.left
	local clientH2 = rect2.bottom - rect2.top
	check("second client width", clientW2 == 1200, "expected 1200, got " .. tostring(clientW2))
	check("second client height", clientH2 == 720, "expected 720, got " .. tostring(clientH2))
end

win2:destroy()
check("destroyed window invalid", user32.IsWindow(win2.hwnd) == 0, "window should be invalid after destroy")

-- Test 7: Set cursor (should not error)
local cursorOk = pcall(function()
	local el = EventLoop.new()
	local w = Window.new(el, 200, 200)
	el:register(w)
	w:setCursor("pointer")
	w:setCursor("hand2")
	w:resetCursor()
	w:destroy()
end)
check("setCursor/resetCursor", cursorOk)

-- Summary
print(string.format("\nWindows window tests: %d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed")
end
