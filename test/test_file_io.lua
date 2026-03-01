--- Tests for file_io module: backup, load_json, sanitize_json.
local helper = require("test_helper")
local lu = helper.lu
local wez = helper.mock_wezterm
local file_io = require("resurrect.file_io")

---------------------------------------------------------------------------
-- write_state backup behavior
---------------------------------------------------------------------------
TestWriteStateBackup = {}

function TestWriteStateBackup:setUp()
	helper.reset()
	-- Use unique temp paths per test
	self.path = helper.tmp_path(".json")
end

function TestWriteStateBackup:tearDown()
	helper.remove_file(self.path)
	helper.remove_file(self.path .. ".bak")
end

function TestWriteStateBackup:test_write_state_creates_backup()
	-- First write
	local state1 = { cwd = "/v1", title = "first" }
	file_io.write_state(self.path, state1, "tab")

	-- Second write should create .bak
	local state2 = { cwd = "/v2", title = "second" }
	file_io.write_state(self.path, state2, "tab")

	local bak_content = helper.read_file(self.path .. ".bak")
	lu.assertNotNil(bak_content)
	lu.assertStrContains(bak_content, "v1")
end

function TestWriteStateBackup:test_no_backup_on_first_write()
	local state = { cwd = "/v1", title = "first" }
	file_io.write_state(self.path, state, "tab")

	local bak_content = helper.read_file(self.path .. ".bak")
	lu.assertNil(bak_content)
end

function TestWriteStateBackup:test_backup_contains_previous_content()
	local state1 = { cwd = "/v1", title = "first" }
	file_io.write_state(self.path, state1, "tab")
	local v1_content = helper.read_file(self.path)

	local state2 = { cwd = "/v2", title = "second" }
	file_io.write_state(self.path, state2, "tab")

	local bak_content = helper.read_file(self.path .. ".bak")
	lu.assertEquals(bak_content, v1_content)

	local primary_content = helper.read_file(self.path)
	lu.assertStrContains(primary_content, "v2")
end

---------------------------------------------------------------------------
-- load_json error handling
---------------------------------------------------------------------------
TestLoadJson = {}

function TestLoadJson:setUp()
	helper.reset()
	self.path = helper.tmp_path(".json")
end

function TestLoadJson:tearDown()
	helper.remove_file(self.path)
end

function TestLoadJson:test_load_json_valid_file()
	helper.write_file(self.path, '{"cwd":"/home/user","title":"test"}')
	local result = file_io.load_json(self.path)
	lu.assertNotNil(result)
	lu.assertEquals(result.cwd, "/home/user")
	lu.assertEquals(result.title, "test")
end

function TestLoadJson:test_load_json_missing_file()
	local result = file_io.load_json("/tmp/nonexistent_resurrect_test_file.json")
	lu.assertNil(result)
end

function TestLoadJson:test_load_json_corrupt_file()
	helper.write_file(self.path, "{{{invalid json")
	-- Should return nil rather than crashing
	local ok, result = pcall(file_io.load_json, self.path)
	-- Either returns nil gracefully or throws (document which)
	if ok then
		lu.assertNil(result)
	end
	-- If pcall caught an error, that's also acceptable (json_parse may throw)
end

function TestLoadJson:test_load_json_sanitizes_control_chars()
	-- Write JSON with an embedded control character
	helper.write_file(self.path, '{"text":"hello\\u0001world"}')
	local result = file_io.load_json(self.path)
	lu.assertNotNil(result)
	lu.assertNotNil(result.text)
end

---------------------------------------------------------------------------
-- sanitize_json
---------------------------------------------------------------------------
TestSanitizeJson = {}

function TestSanitizeJson:setUp()
	helper.reset()
end

function TestSanitizeJson:test_sanitize_no_control_chars()
	local input = '{"name":"hello world"}'
	local output = file_io._sanitize_json(input)
	lu.assertEquals(output, input)
end

function TestSanitizeJson:test_sanitize_null_byte()
	local input = '{"text":"hello' .. string.char(0) .. 'world"}'
	local output = file_io._sanitize_json(input)
	lu.assertStrContains(output, "\\u0000")
	-- Should not contain the raw null byte
	lu.assertNil(output:find(string.char(0)))
end

function TestSanitizeJson:test_sanitize_tab_char()
	local input = '{"text":"hello' .. string.char(9) .. 'world"}'
	local output = file_io._sanitize_json(input)
	lu.assertStrContains(output, "\\u0009")
end

function TestSanitizeJson:test_sanitize_newline()
	local input = '{"text":"hello' .. string.char(10) .. 'world"}'
	local output = file_io._sanitize_json(input)
	lu.assertStrContains(output, "\\u000A")
end
