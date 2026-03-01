#!/usr/bin/env lua5.4
--- Test runner: loads all test_*.lua files and runs them via LuaUnit.
--- NOTE: WezTerm uses Lua 5.4 (via mlua), not LuaJIT. Use lua5.4 to run tests.

-- Bootstrap package.path so we can find test modules
local script_path = arg[0]:match("(.*/)") or "./"
local repo_root = script_path:match("(.*/)[^/]+/") or "./"

package.path = script_path .. "?.lua;"
	.. repo_root .. "plugin/?.lua;"
	.. repo_root .. "plugin/?/init.lua;"
	.. package.path

-- Load test infrastructure (sets _RESURRECT_TESTING, injects mocks)
require("test_helper")

-- Load test modules (each registers test classes as globals)
require("test_pane_tree")
require("test_validate")
require("test_file_io")
require("test_state_manager")

-- Run all tests
local lu = require("luaunit")
os.exit(lu.LuaUnit.run())
