local M = {}

---@class Bk
---@field quit boolean
---@field chapters table[]
---@field chapter number
---@field line number
---@field mark table<string, {number, number}>
---@field links table<string, {chapter: number, position: number}>
---@field colors table
---@field cols number
---@field rows number
---@field max_width number
---@field view string
---@field cursor number
---@field dir string
---@field meta table<string>

-- Helper function to get terminal size
local function get_terminal_size()
	local width = vim.o.columns
	local height = vim.o.lines - vim.o.cmdheight
	return width, height
end

-- Helper function to wrap text
local function wrap(text, max_cols)
	local lines = {}
	local start = 1
	local end_pos = 1
	local after = 0
	local cols = 0
	local space = false

	local function char_width(c)
		return vim.fn.strdisplaywidth(c)
	end

	for i = 1, #text do
		local char = text:sub(i, i)
		local width = char_width(char)
		cols = cols + width

		if char == "\n" then
			after = 0
			end_pos = i
			space = true
			cols = max_cols + 1
		elseif char == " " then
			after = 0
			end_pos = i
			space = true
		elseif char == "-" or char == "—" then
			if cols <= max_cols then
				after = 0
				end_pos = i + 1
				space = false
			end
		else
			after = after + width
		end

		if cols > max_cols then
			if cols == after then
				after = width
				end_pos = i
				space = false
			end
			table.insert(lines, { start, end_pos - 1 })
			start = end_pos
			if space then
				start = start + 1
			end
			cols = after
		end
	end

	if start <= #text then
		table.insert(lines, { start, #text })
	end

	return lines
end

-- Constructor for Bk
local function new(epub, args)
	local cols, rows = get_terminal_size()
	local width = math.min(cols, args.width)
	local meta = wrap(epub.meta, width)
	local chapters = {}
	for _, chapter in ipairs(epub.chapters) do
		chapter.lines = wrap(chapter.text, width)
		if vim.fn.strwidth(chapter.title) > width then
			chapter.title = vim.fn.strcharpart(chapter.title, 0, width - 1) .. "…"
		end
		table.insert(chapters, chapter)
	end
	local bk = setmetatable({
		quit = false,
		chapters = chapters,
		chapter = 1,
		line = 1,
		mark = {},
		links = epub.links,
		colors = args.colors,
		cols = cols,
		rows = rows,
		max_width = args.width,
		view = args.toc and "toc" or "page",
		cursor = 1,
		dir = "next",
		meta = meta,
	}, { __index = M })
	bk:jump_byte(args.chapter, args.byte)
	bk:set_mark("'")
	return bk
end

function M:jump(chapter, line)
	self:set_mark("'")
	self.chapter = chapter
	self.line = line
end

function M:jump_byte(chapter, byte)
	self.chapter = chapter
	local lines = self.chapters[chapter].lines
	for i, line_range in ipairs(lines) do
		if line_range[1] > byte then
			self.line = math.max(1, i - 1)
			return
		end
	end
	self.line = #lines
end

function M:jump_reset()
	local mark = self.mark["'"]
	if mark then
		self.chapter = mark[1]
		self.line = mark[2]
	end
end

function M:set_mark(char)
	self.mark[char] = { self.chapter, self.line }
end

function M:pad()
	return math.floor((self.cols - self.max_width) / 2)
end

-- Main function to create and initialize Bk
function M.create_bk(epub, args)
	args = args or {}
	args.width = args.width or 140
	args.colors = args.colors or { fg = "White", bg = "Black" }
	args.chapter = args.chapter or 1
	args.byte = args.byte or 1
	args.toc = args.toc or false

	local window_id = vim.api.nvim_get_current_win()
	local window_info = vim.fn.getwininfo(window_id)[1]
	local real_width = window_info.width - window_info.textoff

	-- Use the smaller of real_width or args.width
	args.width = math.min(real_width, args.width)
	return new(epub, args)
end

return M
