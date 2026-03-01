--- Tests for state_manager.load_state() backup fallback.
local helper = require("test_helper")
local lu = helper.lu
local wez = helper.mock_wezterm
local file_io = require("resurrect.file_io")
local state_manager = require("resurrect.state_manager")

TestLoadState = {}

function TestLoadState:setUp()
	helper.reset()
	-- Use a temp directory for state storage
	self.dir = "/tmp/resurrect_test_state_" .. os.time() .. "_" .. math.random(10000)
	os.execute('mkdir -p "' .. self.dir .. '/tab"')
	state_manager.save_state_dir = self.dir .. "/"
end

function TestLoadState:tearDown()
	os.execute('rm -rf "' .. self.dir .. '"')
end

function TestLoadState:test_load_state_primary_valid()
	-- Write valid state
	local state = { title = "test-tab", pane_tree = { cwd = "/home" } }
	helper.write_file(self.dir .. "/tab/test-tab.json", wez.json_encode(state))

	local result = state_manager.load_state("test-tab", "tab")
	lu.assertNotNil(result)
	lu.assertEquals(result.title, "test-tab")
end

function TestLoadState:test_load_state_primary_missing_backup_valid()
	-- No primary, but valid backup
	local state = { title = "from-backup", pane_tree = { cwd = "/home" } }
	helper.write_file(self.dir .. "/tab/test-tab.json.bak", wez.json_encode(state))

	local result = state_manager.load_state("test-tab", "tab")
	lu.assertNotNil(result)
	lu.assertEquals(result.title, "from-backup")
	-- Should have logged a warning about trying backup
	lu.assertNotNil(helper.find_log("warn", "trying backup"))
end

function TestLoadState:test_load_state_both_missing()
	-- Neither primary nor backup exists
	local result = state_manager.load_state("nonexistent", "tab")
	lu.assertNotNil(result)
	-- Should return empty table
	lu.assertEquals(next(result), nil)
end

function TestLoadState:test_load_state_primary_corrupt_backup_valid()
	-- Corrupt primary
	helper.write_file(self.dir .. "/tab/test-tab.json", "{{{corrupt")
	-- Valid backup
	local state = { title = "from-backup", pane_tree = { cwd = "/home" } }
	helper.write_file(self.dir .. "/tab/test-tab.json.bak", wez.json_encode(state))

	local result = state_manager.load_state("test-tab", "tab")
	lu.assertNotNil(result)
	lu.assertEquals(result.title, "from-backup")
end
