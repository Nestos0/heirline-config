local g_buf_names = {}

local function is_repeated(name)
	if name == "" or name == "[No Name]" then
		return false
	end

	local buf_names = {}
	for path in pairs(g_buf_names) do
		if vim.fs.basename(path) == name then
			table.insert(buf_names, path)
		end
	end

	if #buf_names <= 1 then
		return false
	end

	local displays = {}
	local parents = {}
	for _, p in ipairs(buf_names) do
		displays[p] = name
		parents[p] = p
	end

	local not_repeated = false
	while not not_repeated do
		not_repeated = true
		local counts = {}

		for _, p in ipairs(buf_names) do
			counts[displays[p]] = (counts[displays[p]] or 0) + 1
		end

		for _, p in ipairs(buf_names) do
			if counts[displays[p]] > 1 then
				local next_parent = vim.fs.dirname(parents[p])

				parents[p] = next_parent
				displays[p] = vim.fs.basename(next_parent) .. "/" .. displays[p]
				not_repeated = false
			end
		end
	end

	for p, display in pairs(displays) do
		g_buf_names[p] = display
	end

	return true
end

local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

vim.o.laststatus = 3
vim.o.showtabline = 1

local colors = {
	bg = "#202328",
	fg = "#c0caf5",
	dim = "#5c6370",
	yellow = "#ECBE7B",
	cyan = "#008080",
	darkblue = "#081633",
	green = "#98be65",
	orange = "#FF8800",
	violet = "#a9a1e1",
	magenta = "#c678dd",
	blue = "#51afef",
	red = "#ec5f67",
	tabline_bg = "#16161e",
}

require("heirline").load_colors(colors)

local mode_colors = {
	n = colors.red,
	i = colors.green,
	v = colors.blue,
	["\22"] = colors.blue,
	V = colors.blue,
	c = colors.magenta,
	no = colors.red,
	s = colors.orange,
	S = colors.orange,
	["\19"] = colors.orange,
	ic = colors.yellow,
	R = colors.violet,
	Rv = colors.violet,
	cv = colors.red,
	ce = colors.red,
	r = colors.cyan,
	rm = colors.cyan,
	["r?"] = colors.cyan,
	["!"] = colors.red,
	t = colors.red,
}

local cond = {
	buffer_not_empty = function()
		return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
	end,
	hide_in_width = function()
		return vim.fn.winwidth(0) > 80
	end,
}

local ViModeLeft = { provider = "▊", hl = { fg = "blue" } }

local ViModeIcon = {
	init = function(self)
		self.mode = vim.fn.mode(1)
	end,
	provider = "  ",
	hl = function(self)
		local mode = self.mode:sub(1, 1)
		return { fg = mode_colors[mode] or colors.red, bold = true }
	end,
	update = { "ModeChanged", pattern = "*:*" },
}

local FileSize = {
	condition = cond.buffer_not_empty,
	update = { "BufEnter", "BufWritePost" },
	provider = function()
		local file = vim.fn.expand("%:p")
		if file == "" then
			return ""
		end
		local size = vim.fn.getfsize(file)
		if size <= 0 then
			return ""
		end
		local suffixes = { "B", "KB", "MB", "GB" }
		local i = 1
		while size >= 1024 and i < #suffixes do
			size = size / 1024
			i = i + 1
		end
		return string.format("%.0f%s ", size, suffixes[i])
	end,
	hl = { fg = "#c0caf5" },
}

local FileNameBlock = {
	init = function(self)
		self.filename = vim.api.nvim_buf_get_name(0)
	end,
	update = { "BufEnter", "BufModifiedSet", "DirChanged", "BufWritePost" },
	{
		init = function(self)
			local filename = self.filename or ""
			local extension = vim.fn.fnamemodify(filename, ":e")
			self.icon, self.icon_color =
				require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
		end,
		provider = function(self)
			return self.icon and (" " .. self.icon .. " ")
		end,
		hl = function(self)
			return { fg = self.icon_color }
		end,
	},
	{
		provider = function(self)
			local filename = vim.fn.fnamemodify(self.filename or "[No Name]", ":.")
			if filename == "" then
				return "[No Name]"
			end
			return filename
		end,
		hl = function()
			return { fg = vim.bo.modified and "magenta" or "fg", bold = true }
		end,
	},
	{
		provider = function()
			return vim.bo.modified and " ●  " or "  "
		end,
		hl = { fg = "green", bold = true },
	},
}

local Location = { provider = "%l:%c ", hl = { fg = "fg" } }

local Progress = { provider = "%P ", hl = { fg = "fg", bold = true } }

local Diagnostics = {
	condition = conditions.has_diagnostics,
	static = { error_icon = " ", warn_icon = " ", info_icon = " " },
	init = function(self)
		self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
		self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
		self.infos = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
	end,
	update = { "DiagnosticChanged", "BufEnter" },
	{
		provider = function(self)
			return self.errors > 0 and (self.error_icon .. self.errors .. " ")
		end,
		hl = { fg = "red" },
	},
	{
		provider = function(self)
			return self.warnings > 0 and (self.warn_icon .. self.warnings .. " ")
		end,
		hl = { fg = "yellow" },
	},
	{
		provider = function(self)
			return self.infos > 0 and (self.info_icon .. self.infos .. " ")
		end,
		hl = { fg = "cyan" },
	},
}

local LSPActive = {
	update = { "LspAttach", "LspDetach", "BufEnter" },
	init = function(self)
		self.name = "No Active Lsp"
		self.tailwind = false
		local buf_ft = vim.bo.filetype
		local clients = vim.lsp.get_clients({ bufnr = 0 })
		if #clients == 0 then
			return
		end
		for _, client in ipairs(clients) do
			local filetypes = client.config.filetypes or {}
			if vim.tbl_contains(filetypes, buf_ft) then
				if client.name == "tailwindcss" then
					self.name = "󱏿 TW"
					self.tailwind = true
					return
				elseif self.name == "No Active Lsp" then
					self.name = client.name
				end
			end
		end
	end,
	provider = function(self)
		if self.name == "No Active Lsp" then
			return ""
		end
		if self.tailwind then
			return self.name .. " "
		end
		return " LSP: " .. self.name .. " "
	end,
	hl = function(self)
		if self.tailwind then
			return { fg = "#38bdf8", bold = true }
		end
		return { fg = "#ffffff", bold = true }
	end,
}

local FileEncoding = {
	condition = cond.hide_in_width,
	update = { "BufEnter" },
	provider = function()
		return string.upper(vim.bo.fileencoding or vim.o.encoding) .. " "
	end,
	hl = { fg = "green", bold = true },
}

local FileFormat = {
	condition = cond.hide_in_width,
	update = { "BufEnter" },
	provider = function()
		return string.upper(vim.bo.fileformat) .. " "
	end,
	hl = { fg = "green", bold = true },
}

local GitBranch = {
	condition = conditions.is_git_repo,
	init = function(self)
		self.status_dict = vim.b.gitsigns_status_dict
	end,
	update = { "User", pattern = "GitSignsUpdate" },
	provider = function(self)
		return " " .. (self.status_dict.head or "") .. " "
	end,
	hl = { fg = "violet", bold = true },
}

local Diff = {
	condition = function()
		return conditions.is_git_repo() and cond.hide_in_width()
	end,
	init = function(self)
		self.status_dict = vim.b.gitsigns_status_dict
	end,
	update = { "User", pattern = "GitSignsUpdate" },
	{
		provider = function(self)
			local count = self.status_dict.added or 0
			return count > 0 and (" " .. count .. " ") or ""
		end,
		hl = { fg = "green" },
	},
	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("󰝤 " .. count .. " ") or ""
		end,
		hl = { fg = "orange" },
	},
	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and (" " .. count .. " ") or ""
		end,
		hl = { fg = "red" },
	},
}

local ViModeRight = { provider = "▊", hl = { fg = "blue" } }

local StatusLine = {
	ViModeLeft,
	ViModeIcon,
	FileSize,
	FileNameBlock,
	Location,
	Progress,
	Diagnostics,
	{ provider = "%=" },
	LSPActive,
	{ provider = "%=" },
	FileEncoding,
	FileFormat,
	GitBranch,
	Diff,
	ViModeRight,
}

local EvilLogo = {
	provider = "  ",
	hl = { fg = "green", bold = true, bg = "bg" },
}

local BufferComponent = {
	init = function(self)
		self.is_active = self.bufnr == vim.api.nvim_get_current_buf()
		local name = vim.api.nvim_buf_get_name(self.bufnr or 0)
		self.buf_name = name
		if self.buf_name == "" then
			self.buf_name = "[No Name]"
		end

		self.is_visible = false
		local current_tab = vim.api.nvim_get_current_tabpage()
		local wins = vim.api.nvim_tabpage_list_wins(current_tab)
		for _, win in ipairs(wins) do
			if vim.api.nvim_win_get_buf(win) == self.bufnr then
				self.is_visible = true
				break
			end
		end
	end,
	hl = function(self)
		if self.is_active then
			-- 当前活跃buffer
			return {
				fg = "fg",
				bg = "bg",
				bold = true,
			}
		elseif self.is_visible then
			-- 在当前tab中可见但非活跃的buffer
			return {
				fg = "dim",
				bg = "tabline_bg",
				bold = false,
			}
		else
			-- 在其他tab中的buffer
			-- return {
			-- 	fg = "dim",
			-- 	bg = "tabline_bg",
			-- 	bold = false,
			-- }
		end
	end,
	{ provider = " " },
	{
		init = function(self)
			local filename = self.buf_name
			local extension = vim.fn.fnamemodify(filename, ":e")
			self.icon, self.icon_color =
				require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
		end,
		provider = function(self)
			return self.icon and (self.icon .. " ")
		end,
		hl = function(self)
			return { fg = self.icon_color }
		end,
	},
	{
		provider = function(self)
			local filename = vim.fs.basename(self.buf_name)
			if filename == "" then
				filename = "[No Name]"
			end

			g_buf_names[self.buf_name] = filename
			is_repeated(filename)

			return g_buf_names[self.buf_name] .. " "
		end,
	},
	{
		provider = function(self)
			return vim.bo[self.bufnr].modified and "●" or " "
		end,
		hl = { fg = "green", bold = true },
	},
	{ provider = " " },
	on_click = {
		callback = function(_, minwid)
			vim.api.nvim_win_set_buf(0, minwid)
		end,
		minwid = function(self)
			return self.bufnr
		end,
		name = "heirline_tabline_buffer_callback",
	},
}

local LeftTrunc = { provider = "< ", hl = { fg = "dim" } }
local RightTrunc = { provider = " >", hl = { fg = "dim" } }

local FileFormatSymbol = {
	provider = function()
		local fmt = vim.bo.fileformat
		if fmt == "unix" then
			return " "
		elseif fmt == "dos" then
			return " "
		elseif fmt == "mac" then
			return " "
		else
			return "? "
		end
	end,
	hl = { fg = "fg", bold = true },
}

local FileEncodingTab = {
	provider = function()
		return (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding):upper() .. " "
	end,
	hl = { fg = "fg" },
}

local TabsIndicator = {
	condition = function()
		return #vim.api.nvim_list_tabpages() > 1
	end,
	provider = function()
		local current = vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage())
		local total = #vim.api.nvim_list_tabpages()
		return string.format(" 󰓩 %d/%d ", current, total)
	end,
	hl = { fg = "green", bold = true, bg = "bg" },
}

local TabLine = {
	EvilLogo,
	TabsIndicator,
	{ provider = "%=" },
	utils.make_buflist(BufferComponent, LeftTrunc, RightTrunc),
	{ provider = "%=" },
	FileFormatSymbol,
	{ provider = " " },
	FileEncodingTab,
}

return {
	statusline = StatusLine,
	tabline = TabLine,
}
