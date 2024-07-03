local M = {}

local options = {}

---@class ViewOpts
---@field epub_path string
---@field data_dir string

---@type number|nil
local reader_bufnr = nil

---@type Bk|nil
local current_bk = nil

---@type string|nil
local current_epub_path = nil

---@type string|nil
local current_data_file = nil

local function get_epub_data_file(epub_path, data_dir)
	local epub_name = vim.fn.fnamemodify(epub_path, ":t:r")
	return data_dir .. "/" .. epub_name .. ".json"
end

local function save_epub_data(chapter)
	if current_data_file then
		local data = vim.json.encode({ last_chapter = chapter })
		vim.fn.writefile({ data }, current_data_file)
	end
end

local function load_epub_data()
	if current_data_file and vim.fn.filereadable(current_data_file) == 1 then
		local data = vim.fn.readfile(current_data_file)[1]
		return vim.json.decode(data)
	end
	return nil
end

---@param bk Bk
---@param opts ViewOpts
function M.open(bk, opts)
	current_bk = bk
	current_epub_path = opts.epub_path
	current_data_file = get_epub_data_file(opts.epub_path, opts.data_dir)

	if not current_bk then
		return
	end

	local epub_data = load_epub_data()
	if epub_data and epub_data.last_chapter then
		current_bk.chapter = epub_data.last_chapter
	end

	local bufnr = M.create_buffer()
	vim.api.nvim_set_current_buf(bufnr)

	M.display_chapter(current_bk.chapters[current_bk.chapter])
	M.setup_keymaps()
	-- Define highlight groups
	vim.api.nvim_command("highlight EpubBold gui=bold")
	vim.api.nvim_command("highlight EpubItalic gui=italic")
	vim.api.nvim_command("highlight EpubUnderline gui=underline")
	--vim.api.nvim_command("highlight EpubLink guifg=blue gui=underline")
	vim.api.nvim_command("highlight EpubLinkIcon guifg=green")
end

---@return number
function M.create_buffer()
	reader_bufnr = vim.api.nvim_create_buf(false, true)
	return reader_bufnr
end

---@param chapter Chapter
function M.display_chapter(chapter)
	if reader_bufnr == nil then
		return -- error handle this probably
	end
	---@type string[]
	local lines = {}
	---@type number[]
	local line_ends = {}
	local current_pos = 0

	for _, line_range in ipairs(chapter.lines) do
		local line = chapter.text:sub(line_range[1], line_range[2])
		table.insert(lines, line)
		current_pos = current_pos + #line
		table.insert(line_ends, current_pos)
	end

	-- Attempt to set lines and notify if there's an error
	local success, error_msg = pcall(vim.api.nvim_buf_set_lines, reader_bufnr, 0, -1, false, lines)
	if not success then
		return
	end

	-- Store the line_ends in the chapter for later use
	chapter.line_ends = line_ends

	M.apply_formatting(chapter)
	M.setup_links(chapter)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

function M.next_chapter()
	if current_bk and current_bk.chapter < #current_bk.chapters then
		current_bk.chapter = current_bk.chapter + 1
		M.display_chapter(current_bk.chapters[current_bk.chapter])
		save_epub_data(current_bk.chapter)
	end
end

function M.prev_chapter()
	if current_bk and current_bk.chapter > 1 then
		current_bk.chapter = current_bk.chapter - 1
		M.display_chapter(current_bk.chapters[current_bk.chapter])
		save_epub_data(current_bk.chapter)
	end
end

function M.show_toc()
	if not current_bk then
		return
	end

	---@type string[]
	local toc = {}
	for i, chapter in ipairs(current_bk.chapters) do
		table.insert(toc, string.format("%d. %s", i, chapter.title))
	end
	vim.ui.select(toc, { prompt = "Select a chapter:" }, function(choice)
		if choice then
			current_bk.chapter = tonumber(choice:match("^(%d+)"))
			M.display_chapter(current_bk.chapters[current_bk.chapter])
		end
	end)
end

---@param chapter Chapter
function M.apply_formatting(chapter)
	if reader_bufnr == nil or not chapter.formatting then
		return
	end

	local ns_id = vim.api.nvim_create_namespace("epub_formatting")
	local lines = vim.api.nvim_buf_get_lines(reader_bufnr, 0, -1, false)

	-- Create a mapping of absolute positions to buffer lines and columns
	local pos_map = {}
	local current_pos = 0
	for i, line in ipairs(lines) do
		for j = 1, #line do
			current_pos = current_pos + 1
			pos_map[current_pos] = { line = i - 1, col = j - 1 }
		end
		current_pos = current_pos + 1 -- Account for newline
	end

	for _, format in ipairs(chapter.formatting) do
		local start_pos = pos_map[format.start]
		local end_pos = pos_map[format.finish]

		if not start_pos or not end_pos then
			goto continue
		end

		local hl_group = format.attribute == "bold" and "EpubBold"
			or format.attribute == "italic" and "EpubItalic"
			or format.attribute == "underline" and "EpubUnderline"
			or nil

		if hl_group then
			if start_pos.line == end_pos.line then
				vim.api.nvim_buf_add_highlight(
					reader_bufnr,
					ns_id,
					hl_group,
					start_pos.line,
					start_pos.col,
					end_pos.col + 1
				)
			else
				vim.api.nvim_buf_add_highlight(reader_bufnr, ns_id, hl_group, start_pos.line, start_pos.col, -1)
				for line = start_pos.line + 1, end_pos.line - 1 do
					vim.api.nvim_buf_add_highlight(reader_bufnr, ns_id, hl_group, line, 0, -1)
				end
				vim.api.nvim_buf_add_highlight(reader_bufnr, ns_id, hl_group, end_pos.line, 0, end_pos.col + 1)
			end
		end

		::continue::
	end
end

---@param chapter Chapter
function M.setup_links(chapter)
	if reader_bufnr == nil then
		vim.notify("Reader buffer is nil", vim.log.levels.ERROR)
		return
	end

	if not chapter.links then
		vim.notify("Chapter links are nil", vim.log.levels.DEBUG)
		return
	end

	if #chapter.links == 0 then
		vim.notify("Chapter links array is empty", vim.log.levels.DEBUG)
		return
	end

	local ns_id = vim.api.nvim_create_namespace("epub_links")
	local lines = vim.api.nvim_buf_get_lines(reader_bufnr, 0, -1, false)

	-- Create a mapping of absolute positions to buffer lines and columns
	local pos_map = {}
	local current_pos = 0
	for i, line in ipairs(lines) do
		for j = 1, #line do
			current_pos = current_pos + 1
			pos_map[current_pos] = { line = i - 1, col = j - 1 }
		end
		current_pos = current_pos + 1 -- Account for newline
	end

	for i, link in ipairs(chapter.links) do
		local start_pos = pos_map[link.start]
		local end_pos = pos_map[link.finish]

		if not start_pos or not end_pos then
			goto continue
		end

		vim.api.nvim_buf_set_extmark(reader_bufnr, ns_id, start_pos.line, start_pos.col, {
			end_line = end_pos.line,
			end_col = end_pos.col + 1,
			hl_group = "EpubLink",
			virt_text = { { " 🔗", "EpubLinkIcon" } },
			virt_text_pos = "eol",
		})

		::continue::
	end
end

-- function M.follow_link()
-- 	if not current_bk or not current_bk.chapters[current_bk.chapter] then
-- 		vim.notify("No current book or chapter", vim.log.levels.ERROR)
-- 		return
-- 	end
--
-- 	local cursor = vim.api.nvim_win_get_cursor(0)
-- 	local current_line = cursor[1] - 1 -- Convert to 0-based index
-- 	local current_col = cursor[2]
--
-- 	local chapter = current_bk.chapters[current_bk.chapter]
-- 	local current_pos = chapter.line_ends[current_line]
-- 		- (chapter.line_ends[current_line] - (current_line > 1 and chapter.line_ends[current_line - 1] or 0))
-- 		+ current_col
-- 		+ 1
--
-- 	for _, link in ipairs(chapter.links) do
-- 		if current_pos >= link.start and current_pos <= link.finish then
-- 			-- Found a link at the cursor position
-- 			if link.url:match("^#") then
-- 				-- Internal link
-- 				local target_id = link.url:sub(2)
-- 				for i, chap in ipairs(current_bk.chapters) do
-- 					if chap.id == target_id then
-- 						current_bk.chapter = i
-- 						M.display_chapter(chap)
-- 						return
-- 					end
-- 				end
-- 				vim.notify("Target chapter not found: " .. target_id, vim.log.levels.WARN)
-- 			else
-- 				-- External link
-- 				-- You can implement external link handling here, e.g., opening in a browser
-- 				vim.notify("External link: " .. link.url, vim.log.levels.INFO)
-- 				-- Uncomment the following line to open the link in the default browser (requires 'xdg-open' on Linux)
-- 				-- vim.fn.system({"xdg-open", link.url})
-- 			end
-- 			return
-- 		end
-- 	end

-- 	vim.notify("No link found at the cursor position", vim.log.levels.INFO)
-- end
---@param line_ends number[]
---@param pos number
---@return number line
---@return number col
function M.get_line_col(line_ends, pos)
	for i, end_pos in ipairs(line_ends) do
		if pos <= end_pos then
			local prev_end = i > 1 and line_ends[i - 1] or 0
			local line = i
			local col = pos - prev_end - 1
			if i > 1 then
				col = col - 1 -- Subtract 1 more to account for the newline
			end

			return line, math.max(0, col) -- Ensure column is never negative
		end
	end
	return #line_ends, pos - line_ends[#line_ends] - 1
end

function M.setup_keymaps()
	if reader_bufnr == nil then
		return
	end

	vim.api.nvim_buf_set_keymap(
		reader_bufnr,
		"n",
		"]c",
		"",
		{ callback = M.next_chapter, noremap = true, silent = true, desc = "Next chapter" }
	)
	vim.api.nvim_buf_set_keymap(
		reader_bufnr,
		"n",
		"[c",
		"",
		{ callback = M.prev_chapter, noremap = true, silent = true, desc = "Previous chapter" }
	)
	vim.api.nvim_buf_set_keymap(
		reader_bufnr,
		"n",
		"gt",
		"",
		{ callback = M.show_toc, noremap = true, silent = true, desc = "Show table of contents" }
	)
	-- vim.api.nvim_buf_set_keymap(
	-- 	reader_bufnr,
	-- 	"n",
	-- 	"gf",
	-- 	"",
	-- 	{ callback = M.follow_link, noremap = true, silent = true, desc = "Follow link" }
	-- )
end

return M
