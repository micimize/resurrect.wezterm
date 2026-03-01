--- Test helper: sets up package.path and injects mock wezterm module.
--- Must be required before any plugin modules.

-- Set testing flag BEFORE any plugin requires
_RESURRECT_TESTING = true

-- Determine repo root from this file's location
local script_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local repo_root = script_dir:match("(.*/)[^/]+/") or "./"

-- Set up package.path to find plugin modules and test modules
package.path = repo_root .. "plugin/?.lua;"
	.. repo_root .. "plugin/?/init.lua;"
	.. repo_root .. "test/?.lua;"
	.. package.path

-- Inject mock wezterm module before any plugin code loads
local mock_wezterm = require("mock_wezterm")
package.preload["wezterm"] = function()
	return mock_wezterm
end

-- Stub dev.wezterm so init.lua doesn't crash if transitively required
package.preload["dev.wezterm"] = function()
	return { setup = function() return repo_root .. "plugin" end }
end

-- Load test utilities
local lu = require("luaunit")
local mock_pane = require("mock_pane")

local M = {}
M.lu = lu
M.mock_wezterm = mock_wezterm
M.mock_pane = mock_pane
M.repo_root = repo_root

--- Reset all mock state between tests
function M.reset()
	mock_wezterm._reset()
end

--- Helper to count log messages at a given level
function M.count_logs(level)
	local count = 0
	for _, entry in ipairs(mock_wezterm._log) do
		if entry.level == level then
			count = count + 1
		end
	end
	return count
end

--- Helper to find a log message containing a substring
function M.find_log(level, substring)
	for _, entry in ipairs(mock_wezterm._log) do
		if entry.level == level and entry.msg:find(substring, 1, true) then
			return entry
		end
	end
	return nil
end

--- Create a temp file path for test isolation
local test_counter = 0
function M.tmp_path(suffix)
	test_counter = test_counter + 1
	return "/tmp/resurrect_test_" .. os.time() .. "_" .. test_counter .. (suffix or "")
end

--- Write a string to a file (for test setup)
function M.write_file(path, content)
	local f = io.open(path, "w")
	if not f then error("Could not open " .. path .. " for writing") end
	f:write(content)
	f:close()
end

--- Read a file to string (for test assertions)
function M.read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local content = f:read("*a")
	f:close()
	return content
end

--- Remove a file (test cleanup)
function M.remove_file(path)
	os.remove(path)
end

return M
