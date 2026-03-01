local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm
local window_state_mod = require("resurrect.window_state")

local pub = {}

---restore workspace state
---@param workspace_state workspace_state
---@param opts? restore_opts
function pub.restore_workspace(workspace_state, opts)
	if workspace_state == nil then
		return
	end

	wezterm.emit("resurrect.workspace_state.restore_workspace.start")
	if opts == nil then
		opts = {}
	end

	for i, window_state in ipairs(workspace_state.window_states) do
		-- Skip windows with no valid tabs
		if not window_state.tabs or #window_state.tabs == 0 then
			wezterm.log_warn("resurrect: skipping window with no valid tabs during restore")
			goto continue
		end

		local ok, err = pcall(function()
			if i == 1 and opts.window then
				-- inner size is in pixels
				if window_state.size and (opts.resize_window == true or opts.resize_window == nil) then
					opts.window:gui_window():set_inner_size(window_state.size.pixel_width, window_state.size.pixel_height)
				end
				if not opts.close_open_tabs then
					opts.tab = opts.window:active_tab()
					if not opts.close_open_panes then
						opts.pane = opts.window:active_pane()
					end
				end
			else
				local first_cwd = window_state.tabs[1] and window_state.tabs[1].pane_tree
					and window_state.tabs[1].pane_tree.cwd or nil
				local spawn_window_args = {
					width = window_state.size and window_state.size.cols or nil,
					height = window_state.size and window_state.size.rows or nil,
					cwd = first_cwd,
				}
				if opts.spawn_in_workspace then
					spawn_window_args.workspace = workspace_state.workspace
				end
				opts.tab, opts.pane, opts.window = wezterm.mux.spawn_window(spawn_window_args)
			end

			window_state_mod.restore_window(opts.window, window_state, opts)
		end)
		if not ok then
			wezterm.log_error("resurrect: failed to restore window " .. i .. ": " .. tostring(err))
			-- Reset opts to prevent stale state from affecting subsequent windows
			opts.tab = nil
			opts.pane = nil
		end

		::continue::
	end

	-- Set active workspace (PR #118 fix)
	if opts.spawn_in_workspace and workspace_state.workspace then
		wezterm.mux.set_active_workspace(workspace_state.workspace)
	end

	wezterm.emit("resurrect.workspace_state.restore_workspace.finished")
end

---Returns the state of the current workspace
---@return workspace_state
function pub.get_workspace_state()
	local workspace_state = {
		workspace = wezterm.mux.get_active_workspace(),
		window_states = {},
	}
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		if mux_win:get_workspace() == workspace_state.workspace then
			local win_state = window_state_mod.get_window_state(mux_win)
			if #win_state.tabs > 0 then
				table.insert(workspace_state.window_states, win_state)
			else
				wezterm.log_warn("resurrect: skipping window with no healthy tabs during save")
			end
		end
	end
	return workspace_state
end

return pub
