--- Tests for pane_tree module: is_pane_healthy, create_pane_tree, geometry.
local helper = require("test_helper")
local lu = helper.lu
local mp = helper.mock_pane
local wez = helper.mock_wezterm
local pane_tree = require("resurrect.pane_tree")

---------------------------------------------------------------------------
-- is_pane_healthy
---------------------------------------------------------------------------
TestIsPaneHealthy = {}

function TestIsPaneHealthy:setUp()
	helper.reset()
	-- Register a default "local" domain that is spawnable
	wez.mux._domains["local"] = mp.make_domain({ spawnable = true })
end

function TestIsPaneHealthy:test_healthy_pane_passes()
	local pi = mp.make_pane_info({ cwd = "/home/user", domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

function TestIsPaneHealthy:test_nil_pane_object_fails()
	local pi = { pane = nil, left = 0, top = 0, width = 80, height = 24 }
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "nil pane object")
end

function TestIsPaneHealthy:test_nil_cwd_fails()
	local pi = mp.make_pane_info({ cwd = nil, domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "no resolved cwd")
end

function TestIsPaneHealthy:test_empty_cwd_file_path_fails()
	local pi = mp.make_pane_info({ cwd = "", domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "no resolved cwd")
end

function TestIsPaneHealthy:test_nil_cwd_file_path_fails()
	-- Pane whose get_current_working_dir returns {file_path = nil}
	local pane = mp.make_pane({ cwd = "/tmp", domain = "local" })
	-- Override to return table with nil file_path
	function pane:get_current_working_dir() return { file_path = nil } end
	local pi = mp.make_pane_info({ pane = pane, domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "no resolved cwd")
end

function TestIsPaneHealthy:test_zero_dimensions_fails()
	local pi = mp.make_pane_info({ cwd = "/home/user", width = 0, height = 0, domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "zero cell dimensions")
end

function TestIsPaneHealthy:test_zero_width_nonzero_height_passes()
	-- Only fails when BOTH are zero
	local pi = mp.make_pane_info({ cwd = "/home/user", width = 0, height = 24, domain = "local" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

function TestIsPaneHealthy:test_nonspawnable_domain_fails()
	wez.mux._domains["ssh_dead"] = mp.make_domain({ spawnable = false })
	local pi = mp.make_pane_info({ cwd = "/home/user", domain = "ssh_dead" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertFalse(ok)
	lu.assertStrContains(reason, "not spawnable")
end

function TestIsPaneHealthy:test_missing_domain_passes()
	-- Domain lookup failure is not fatal when pane has a cwd
	-- (pcall catches the error from get_domain)
	local pi = mp.make_pane_info({ cwd = "/home/user", domain = "nonexistent" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

function TestIsPaneHealthy:test_spawnable_domain_passes()
	wez.mux._domains["ssh_good"] = mp.make_domain({ spawnable = true })
	local pi = mp.make_pane_info({ cwd = "/home/user", domain = "ssh_good" })
	local ok, reason = pane_tree._is_pane_healthy(pi)
	lu.assertTrue(ok)
	lu.assertNil(reason)
end

---------------------------------------------------------------------------
-- create_pane_tree filtering
---------------------------------------------------------------------------
TestCreatePaneTree = {}

function TestCreatePaneTree:setUp()
	helper.reset()
	wez.mux._domains["local"] = mp.make_domain({ spawnable = true })
end

function TestCreatePaneTree:test_all_healthy_panes_builds_tree()
	-- Three panes in a row: left, center, right
	local panes = {
		mp.make_pane_info({ cwd = "/a", left = 0, top = 0, width = 26, height = 24, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/b", left = 27, top = 0, width = 26, height = 24, pane_id = 2, domain = "local" }),
		mp.make_pane_info({ cwd = "/c", left = 54, top = 0, width = 26, height = 24, pane_id = 3, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	-- Root should be leftmost (left=0)
	lu.assertEquals(tree.cwd, "/a")
end

function TestCreatePaneTree:test_ghost_pane_filtered_out()
	local panes = {
		mp.make_pane_info({ cwd = "/home/user", left = 0, top = 0, width = 80, height = 24, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = nil, left = 81, top = 0, width = 80, height = 24, pane_id = 2, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/home/user")
	-- Ghost pane should have been logged
	lu.assertNotNil(helper.find_log("warn", "skipping unhealthy pane"))
end

function TestCreatePaneTree:test_all_unhealthy_returns_nil()
	local panes = {
		mp.make_pane_info({ cwd = nil, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = nil, pane_id = 2, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNil(tree)
end

function TestCreatePaneTree:test_single_healthy_pane()
	local panes = {
		mp.make_pane_info({ cwd = "/home/user", pane_id = 1, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/home/user")
	lu.assertNil(tree.right)
	lu.assertNil(tree.bottom)
end

function TestCreatePaneTree:test_empty_panes_list()
	local tree = pane_tree.create_pane_tree({})
	lu.assertNil(tree)
end

function TestCreatePaneTree:test_spatial_sorting_preserved()
	-- Pass panes in wrong order; root should still be top-left
	local panes = {
		mp.make_pane_info({ cwd = "/c", left = 54, top = 0, width = 26, height = 24, pane_id = 3, domain = "local" }),
		mp.make_pane_info({ cwd = "/a", left = 0, top = 0, width = 26, height = 24, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/b", left = 27, top = 0, width = 26, height = 24, pane_id = 2, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/a")
end

---------------------------------------------------------------------------
-- Geometry (indirect via create_pane_tree)
---------------------------------------------------------------------------
TestGeometry = {}

function TestGeometry:setUp()
	helper.reset()
	wez.mux._domains["local"] = mp.make_domain({ spawnable = true })
end

function TestGeometry:test_two_panes_horizontal_split()
	local panes = {
		mp.make_pane_info({ cwd = "/left", left = 0, top = 0, width = 40, height = 24, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/right", left = 41, top = 0, width = 39, height = 24, pane_id = 2, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/left")
	lu.assertNotNil(tree.right)
	lu.assertEquals(tree.right.cwd, "/right")
	lu.assertNil(tree.bottom)
end

function TestGeometry:test_two_panes_vertical_split()
	local panes = {
		mp.make_pane_info({ cwd = "/top", left = 0, top = 0, width = 80, height = 11, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/bottom", left = 0, top = 12, width = 80, height = 11, pane_id = 2, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/top")
	lu.assertNotNil(tree.bottom)
	lu.assertEquals(tree.bottom.cwd, "/bottom")
	lu.assertNil(tree.right)
end

function TestGeometry:test_three_panes_l_shape()
	-- TL=(0,0,40,11) BL=(0,12,40,11) R=(41,0,39,24)
	local panes = {
		mp.make_pane_info({ cwd = "/tl", left = 0, top = 0, width = 40, height = 11, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/bl", left = 0, top = 12, width = 40, height = 11, pane_id = 2, domain = "local" }),
		mp.make_pane_info({ cwd = "/r", left = 41, top = 0, width = 39, height = 24, pane_id = 3, domain = "local" }),
	}
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/tl")
	lu.assertNotNil(tree.right)
	lu.assertEquals(tree.right.cwd, "/r")
	lu.assertNotNil(tree.bottom)
	lu.assertEquals(tree.bottom.cwd, "/bl")
end

---------------------------------------------------------------------------
-- Geometry helper direct tests
---------------------------------------------------------------------------
TestGeometryHelpers = {}

function TestGeometryHelpers:test_compare_pane_by_coord_left_priority()
	local a = { left = 0, top = 5 }
	local b = { left = 10, top = 0 }
	lu.assertTrue(pane_tree._compare_pane_by_coord(a, b))
	lu.assertFalse(pane_tree._compare_pane_by_coord(b, a))
end

function TestGeometryHelpers:test_compare_pane_by_coord_top_tiebreak()
	local a = { left = 0, top = 0 }
	local b = { left = 0, top = 10 }
	lu.assertTrue(pane_tree._compare_pane_by_coord(a, b))
	lu.assertFalse(pane_tree._compare_pane_by_coord(b, a))
end

function TestGeometryHelpers:test_is_right()
	local root = { left = 0, width = 40 }
	local right = { left = 41 }
	local not_right = { left = 20 }
	lu.assertTrue(pane_tree._is_right(root, right))
	lu.assertFalse(pane_tree._is_right(root, not_right))
end

function TestGeometryHelpers:test_is_bottom()
	local root = { top = 0, height = 11 }
	local bottom = { top = 12 }
	local not_bottom = { top = 5 }
	lu.assertTrue(pane_tree._is_bottom(root, bottom))
	lu.assertFalse(pane_tree._is_bottom(root, not_bottom))
end

---------------------------------------------------------------------------
-- PR #127: nil pane guard in insert_panes
---------------------------------------------------------------------------
TestPR127NilGuard = {}

function TestPR127NilGuard:setUp()
	helper.reset()
	wez.mux._domains["local"] = mp.make_domain({ spawnable = true })
end

function TestPR127NilGuard:test_create_pane_tree_does_not_crash_with_overlapping_geometry()
	-- A 2x2 symmetric grid where panes can appear in both right and bottom lists.
	-- The nil pane guard prevents a crash when insert_panes encounters a pane
	-- that was already consumed by the other branch.
	local panes = {
		mp.make_pane_info({ cwd = "/tl", left = 0, top = 0, width = 39, height = 11, pane_id = 1, domain = "local" }),
		mp.make_pane_info({ cwd = "/tr", left = 40, top = 0, width = 39, height = 11, pane_id = 2, domain = "local" }),
		mp.make_pane_info({ cwd = "/bl", left = 0, top = 12, width = 39, height = 11, pane_id = 3, domain = "local" }),
		mp.make_pane_info({ cwd = "/br", left = 40, top = 12, width = 39, height = 11, pane_id = 4, domain = "local" }),
	}
	-- Should not crash
	local tree = pane_tree.create_pane_tree(panes)
	lu.assertNotNil(tree)
	lu.assertEquals(tree.cwd, "/tl")
end
