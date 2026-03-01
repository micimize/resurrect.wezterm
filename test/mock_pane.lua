--- Mock pane, PaneInformation, and domain object factories for testing.
local M = {}

--- Create a mock Pane object.
---@param opts table|nil
---@return table pane
function M.make_pane(opts)
	opts = opts or {}
	local pane = {}

	function pane:get_current_working_dir()
		if opts.cwd == nil then return nil end
		return { file_path = opts.cwd }
	end

	function pane:get_domain_name()
		return opts.domain or "local"
	end

	function pane:get_dimensions()
		return {
			scrollback_rows = opts.scrollback_rows or 100,
			pixel_width = opts.pixel_width or 800,
			pixel_height = opts.pixel_height or 600,
		}
	end

	function pane:pane_id()
		return opts.pane_id or 0
	end

	function pane:get_lines_as_escapes(_)
		return opts.text or ""
	end

	function pane:is_alt_screen_active()
		return opts.alt_screen_active or false
	end

	function pane:get_foreground_process_info()
		return opts.process_info or {
			name = "bash",
			argv = { "bash" },
			cwd = opts.cwd or "/tmp",
			executable = "/bin/bash",
		}
	end

	return pane
end

--- Create a PaneInformation table (the struct from tab:panes_with_info()).
---@param opts table|nil
---@return table pane_info
function M.make_pane_info(opts)
	opts = opts or {}
	return {
		pane = opts.pane or M.make_pane(opts),
		left = opts.left or 0,
		top = opts.top or 0,
		width = opts.width or 80,
		height = opts.height or 24,
		is_active = opts.is_active or false,
		is_zoomed = opts.is_zoomed or false,
		pixel_width = opts.pixel_width or 800,
		pixel_height = opts.pixel_height or 600,
	}
end

--- Create a mock domain object.
---@param opts table|nil
---@return table domain
function M.make_domain(opts)
	opts = opts or {}
	local domain = {}
	function domain:is_spawnable()
		if opts.spawnable == nil then return true end
		return opts.spawnable
	end
	return domain
end

return M
