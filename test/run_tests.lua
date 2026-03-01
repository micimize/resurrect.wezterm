#!/usr/bin/env lua5.4
--- Test runner: loads all test_*.lua files and runs them via LuaUnit.
--- NOTE: WezTerm uses Lua 5.4 (via mlua), not LuaJIT. Use lua5.4 to run tests.

-- Bootstrap test infrastructure
require("test_helper")

-- Load test modules (each registers test classes as globals)
require("test_pane_tree")
require("test_validate")
require("test_file_io")
require("test_state_manager")

-- Run all tests
local lu = require("luaunit")
os.exit(lu.LuaUnit.run())
