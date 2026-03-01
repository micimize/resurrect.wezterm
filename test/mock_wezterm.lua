--- Mock wezterm module for unit testing.
--- Injected via package.preload before any plugin code loads.
local dkjson = require("dkjson")

local mock = {}

-- Logging (captured for assertions)
mock._log = {}
function mock.log_warn(msg) table.insert(mock._log, { level = "warn", msg = msg }) end
function mock.log_error(msg) table.insert(mock._log, { level = "error", msg = msg }) end
function mock.log_info(msg) table.insert(mock._log, { level = "info", msg = msg }) end

-- Events (captured for assertions)
mock._events = {}
function mock.emit(event, ...)
	table.insert(mock._events, { event = event, args = { ... } })
end

-- JSON (real encode/decode via dkjson)
function mock.json_encode(val) return dkjson.encode(val) end
function mock.json_parse(str) return dkjson.decode(str) end

-- Mux (configurable per-test)
mock.mux = {}
mock.mux._domains = {}

function mock.mux.get_domain(name)
	local d = mock.mux._domains[name]
	if not d then
		error("domain '" .. tostring(name) .. "' not found")
	end
	return d
end

-- action stubs (used by tab_state, window_state save actions)
mock.action = setmetatable({}, {
	__index = function(_, k)
		return function(...) return { action = k, args = { ... } } end
	end,
})
function mock.action_callback(fn) return { action_callback = fn } end

-- shell_join_args stub
function mock.shell_join_args(argv)
	if not argv then return "" end
	local parts = {}
	for _, a in ipairs(argv) do
		table.insert(parts, tostring(a))
	end
	return table.concat(parts, " ")
end

-- Platform detection (default to Linux)
mock.target_triple = "x86_64-unknown-linux-gnu"

-- Nerdfonts stub
mock.nerdfonts = setmetatable({}, {
	__index = function(_, k) return "<" .. k .. ">" end,
})

-- gui stub
mock.gui = {}
function mock.gui.gui_windows() return {} end

-- time stub
mock.time = {}
function mock.time.call_after(_, _) end

-- Reset function for test isolation
function mock._reset()
	mock._log = {}
	mock._events = {}
	mock.mux._domains = {}
end

return mock
