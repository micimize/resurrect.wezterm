--- Tests for pane_tree.validate_pane_tree()
local helper = require("test_helper")
local lu = helper.lu
local mp = helper.mock_pane
local wez = helper.mock_wezterm
local pane_tree = require("resurrect.pane_tree")

TestValidatePaneTree = {}

function TestValidatePaneTree:setUp()
	helper.reset()
	wez.mux._domains["local"] = mp.make_domain({ spawnable = true })
end

function TestValidatePaneTree:test_nil_tree_invalid()
	local ok, reason = pane_tree.validate_pane_tree(nil)
	lu.assertFalse(ok)
	lu.assertEquals(reason, "nil pane_tree")
end

function TestValidatePaneTree:test_valid_tree_passes()
	local tree = { cwd = "/home/user", domain = "local" }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

function TestValidatePaneTree:test_empty_cwd_invalid()
	local tree = { cwd = "" }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertFalse(ok)
	lu.assertEquals(reason, "empty cwd")
end

function TestValidatePaneTree:test_nil_cwd_invalid()
	local tree = { cwd = nil }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertFalse(ok)
	lu.assertEquals(reason, "empty cwd")
end

function TestValidatePaneTree:test_missing_domain_invalid()
	-- Domain not registered in mock => get_domain throws
	local tree = { cwd = "/home/user", domain = "gone" }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "does not exist")
end

function TestValidatePaneTree:test_nonspawnable_domain_invalid()
	wez.mux._domains["ssh_dead"] = mp.make_domain({ spawnable = false })
	local tree = { cwd = "/home/user", domain = "ssh_dead" }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "not spawnable")
end

function TestValidatePaneTree:test_no_domain_field_valid()
	-- Local pane has no domain field
	local tree = { cwd = "/home/user" }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

function TestValidatePaneTree:test_prunes_invalid_right_subtree()
	local tree = { cwd = "/ok", right = { cwd = "" } }
	local ok, _ = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNil(tree.right)
	lu.assertNotNil(helper.find_log("warn", "pruning invalid right pane"))
end

function TestValidatePaneTree:test_prunes_invalid_bottom_subtree()
	local tree = { cwd = "/ok", bottom = { cwd = "" } }
	local ok, _ = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNil(tree.bottom)
	lu.assertNotNil(helper.find_log("warn", "pruning invalid bottom pane"))
end

function TestValidatePaneTree:test_keeps_valid_subtrees()
	local tree = {
		cwd = "/ok",
		right = { cwd = "/ok2" },
		bottom = { cwd = "/ok3" },
	}
	local ok, _ = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNotNil(tree.right)
	lu.assertNotNil(tree.bottom)
end

function TestValidatePaneTree:test_deep_pruning()
	local tree = {
		cwd = "/ok",
		right = { cwd = "/ok2", bottom = { cwd = "" } },
	}
	local ok, _ = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNotNil(tree.right)
	lu.assertNil(tree.right.bottom)
end

function TestValidatePaneTree:test_prunes_both_subtrees()
	local tree = { cwd = "/ok", right = { cwd = "" }, bottom = { cwd = "" } }
	local ok, _ = pane_tree.validate_pane_tree(tree)
	lu.assertTrue(ok)
	lu.assertNil(tree.right)
	lu.assertNil(tree.bottom)
end

function TestValidatePaneTree:test_root_invalid_rejects_whole_tree()
	local tree = { cwd = "", right = { cwd = "/ok" } }
	local ok, reason = pane_tree.validate_pane_tree(tree)
	lu.assertFalse(ok)
	lu.assertEquals(reason, "empty cwd")
end
