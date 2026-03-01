local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm
local utils = require("resurrect.utils")

---@class pane_tree_module
---@field max_nlines integer
local pub = {}
pub.max_nlines = 3500

---@alias Pane any
---@alias PaneInformation {left: integer, top: integer, height: integer, width: integer}
---@alias pane_tree {left: integer, top: integer, height: integer, width: integer, bottom: pane_tree?, right: pane_tree?, text: string, cwd: string, domain?: string, process?: local_process_info?, pane: Pane?, is_active: boolean, is_zoomed: boolean, alt_screen_active: boolean}
---@alias local_process_info {name: string, argv: string[], cwd: string, executable: string}

---Check if a pane is healthy enough to include in serialized state.
---Filters out ghost panes (e.g. SSH tabs stuck in "Connecting...") that have
---no resolved cwd, zero cell dimensions, or non-spawnable domains.
---@param pane_info PaneInformation
---@return boolean healthy
---@return string? reason
local function is_pane_healthy(pane_info)
	local pane = pane_info.pane
	if not pane then
		return false, "nil pane object"
	end

	local cwd = pane:get_current_working_dir()
	if not cwd or not cwd.file_path or cwd.file_path == "" then
		return false, "no resolved cwd (likely stuck in Connecting...)"
	end

	-- Cell dimensions from PaneInformation; zero means never rendered
	if pane_info.width == 0 and pane_info.height == 0 then
		return false, "zero cell dimensions (never rendered)"
	end

	local ok, domain = pcall(function()
		return wezterm.mux.get_domain(pane:get_domain_name())
	end)
	if ok and domain and not domain:is_spawnable() then
		return false, "domain " .. pane:get_domain_name() .. " is not spawnable"
	end

	return true, nil
end

---compare function returns true if a is more left than b
---@param a PaneInformation
---@param b PaneInformation
---@return boolean
local function compare_pane_by_coord(a, b)
	if a.left == b.left then
		return a.top < b.top
	else
		return a.left < b.left
	end
end

---@param root PaneInformation
---@param pane PaneInformation
---@return boolean
local function is_right(root, pane)
	if root.left + root.width < pane.left then
		return true
	end
	return false
end

---@param root PaneInformation
---@param pane PaneInformation
---@return boolean
local function is_bottom(root, pane)
	if root.top + root.height < pane.top then
		return true
	end
	return false
end

---@param root pane_tree
---@param panes PaneInformation
---@return pane_tree | nil
local function pop_connected_bottom(root, panes)
	for i, pane in ipairs(panes) do
		if root.left == pane.left and root.top + root.height + 1 == pane.top then
			table.remove(panes, i)
			return pane
		end
	end
end

---@param root pane_tree
---@param panes PaneInformation
---@return pane_tree | nil
local function pop_connected_right(root, panes)
	for i, pane in ipairs(panes) do
		if root.top == pane.top and root.left + root.width + 1 == pane.left then
			table.remove(panes, i)
			return pane
		end
	end
end

---@param root pane_tree | nil
---@param panes PaneInformation[]
---@return pane_tree | nil
local function insert_panes(root, panes)
	if root == nil then
		return nil
	end

	-- Guard against nil pane (can happen in symmetric layouts where a pane
	-- appears in both right and bottom lists; PR #127)
	if root.pane == nil then
		return root
	end

	local domain = root.pane:get_domain_name()
	if not wezterm.mux.get_domain(domain):is_spawnable() then
		wezterm.log_warn("Domain " .. domain .. " is not spawnable")
		wezterm.emit("resurrect.error", "Domain " .. domain .. " is not spawnable")
	else
		root.domain = domain

		if not root.pane:get_current_working_dir() then
			root.cwd = ""
		else
			root.cwd = root.pane:get_current_working_dir().file_path
			if utils.is_windows then
				root.cwd = root.cwd:gsub("^/([a-zA-Z]):", "%1:")
			end
		end

		if domain == "local" then
			-- pane:inject_output() is unavailable for non-local domains,
			-- only saving local scrollback because it would slow down the process
			-- See: https://github.com/MLFlexer/resurrect.wezterm/issues/41
			root.alt_screen_active = root.pane:is_alt_screen_active()
			if root.alt_screen_active then
				local process_info = root.pane:get_foreground_process_info()
				process_info.children = nil
				process_info.pid = nil
				process_info.ppid = nil
				root.process = process_info
			else
				local nlines = root.pane:get_dimensions().scrollback_rows
				if nlines > pub.max_nlines then
					nlines = pub.max_nlines
				end
				root.text = root.pane:get_lines_as_escapes(nlines)
			end
		end
	end

	root.pane = nil

	if #panes == 0 then
		return root
	end

	local right, bottom = {}, {}
	for _, pane in ipairs(panes) do
		if is_right(root, pane) then
			table.insert(right, pane)
		end
		if is_bottom(root, pane) then
			table.insert(bottom, pane)
		end
	end

	if #right > 0 then
		local right_child = pop_connected_right(root, right)
		root.right = insert_panes(right_child, right)
	end

	if #bottom > 0 then
		local bottom_child = pop_connected_bottom(root, bottom)
		root.bottom = insert_panes(bottom_child, bottom)
	end

	return root
end

---Create a pane tree from a list of PaneInformation.
---Filters out unhealthy panes (ghost tabs, stuck SSH connections) before
---building the spatial tree. Note: for multi-pane layouts, filtering before
---tree construction can break spatial adjacency calculations. This is
---acceptable because ghost panes are almost always single-pane tabs.
---@param panes PaneInformation
---@return pane_tree | nil
function pub.create_pane_tree(panes)
	local healthy_panes = {}
	for _, pane_info in ipairs(panes) do
		local healthy, reason = is_pane_healthy(pane_info)
		if healthy then
			table.insert(healthy_panes, pane_info)
		else
			local pane_id = pane_info.pane and pane_info.pane:pane_id() or "nil"
			wezterm.log_warn("resurrect: skipping unhealthy pane " .. tostring(pane_id) .. ": " .. (reason or "unknown"))
		end
	end

	if #healthy_panes == 0 then
		return nil
	end

	table.sort(healthy_panes, compare_pane_by_coord)
	local root = table.remove(healthy_panes, 1)
	return insert_panes(root, healthy_panes)
end

---maps over the pane tree
---@param pane_tree pane_tree
---@param f fun(pane_tree: pane_tree): pane_tree
---@return nil
function pub.map(pane_tree, f)
	if pane_tree == nil then
		return nil
	end

	pane_tree = f(pane_tree)
	if pane_tree.right then
		pub.map(pane_tree.right, f)
	end
	if pane_tree.bottom then
		pub.map(pane_tree.bottom, f)
	end

	return pane_tree
end

function pub.fold(pane_tree, acc, f)
	if pane_tree == nil then
		return acc
	end

	acc = f(acc, pane_tree)
	if pane_tree.right then
		acc = pub.fold(pane_tree.right, acc, f)
	end
	if pane_tree.bottom then
		acc = pub.fold(pane_tree.bottom, acc, f)
	end

	return acc
end

---Validate a deserialized pane_tree before attempting to restore it.
---Prunes invalid subtrees in place rather than rejecting the whole tree.
---@param pane_tree pane_tree
---@return boolean valid
---@return string? reason
function pub.validate_pane_tree(pane_tree)
	if pane_tree == nil then
		return false, "nil pane_tree"
	end

	if not pane_tree.cwd or pane_tree.cwd == "" then
		return false, "empty cwd"
	end

	if pane_tree.domain then
		local ok, domain = pcall(function()
			return wezterm.mux.get_domain(pane_tree.domain)
		end)
		if not ok or not domain then
			return false, "domain '" .. tostring(pane_tree.domain) .. "' does not exist"
		end
		if not domain:is_spawnable() then
			return false, "domain '" .. pane_tree.domain .. "' is not spawnable"
		end
	end

	-- Prune invalid subtrees rather than rejecting the whole tree
	if pane_tree.right then
		local valid, reason = pub.validate_pane_tree(pane_tree.right)
		if not valid then
			wezterm.log_warn("resurrect: pruning invalid right pane: " .. (reason or "unknown"))
			pane_tree.right = nil
		end
	end

	if pane_tree.bottom then
		local valid, reason = pub.validate_pane_tree(pane_tree.bottom)
		if not valid then
			wezterm.log_warn("resurrect: pruning invalid bottom pane: " .. (reason or "unknown"))
			pane_tree.bottom = nil
		end
	end

	return true, nil
end

return pub
