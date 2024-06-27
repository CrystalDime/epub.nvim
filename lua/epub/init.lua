-- init.lua

local M = {}

M.setup = function(opts)
	opts = opts or {}
	-- Set default options
	local default_opts = {
		auto_open = false, -- Enable automatic opening of EPUBs
		output_dir = vim.fn.stdpath("cache") .. "/epub_reader", -- Default output directory
		data_dir = vim.fn.stdpath("data") .. "/epub_reader", -- Persistent data directory
	}
	M.options = vim.tbl_deep_extend("force", default_opts, opts)

	-- Create output and data directories if they don't exist
	vim.fn.mkdir(M.options.output_dir, "p")
	vim.fn.mkdir(M.options.data_dir, "p")

	-- Create user command
	vim.api.nvim_create_user_command("EpubOpen", function(args)
		M.open_epub(args.args)
	end, { nargs = 1, complete = "file" })

	-- Set up autocommand for automatic EPUB opening if enabled
	if M.options.auto_open then
		vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
			pattern = "*.epub",
			callback = function(ev)
				M.open_epub(ev.file)
			end,
		})
	end
end

-- Helper function to create a safe, shortened name
local function create_safe_name(path)
	-- Get the directory and filename
	local dir = vim.fn.fnamemodify(path, ":h:t")
	local name = vim.fn.fnamemodify(path, ":t:r")

	-- Combine them, replace non-alphanumeric characters, and truncate
	local combined = dir .. "_" .. name
	local safe = combined:gsub("[^%w%-%_%.%s]", "_")
	return safe:sub(1, 50) -- Limit to 50 characters
end

M.open_epub = function(epub_path)
	-- Normalize the path to handle different representations of the same file
	local normalized_path = vim.fn.fnamemodify(epub_path, ":p")

	-- Generate a unique, consistent subdirectory name based on the EPUB file path
	local subdir = create_safe_name(normalized_path)

	-- Create the full path for the subdirectory
	local extract_dir = vim.fn.fnamemodify(M.options.output_dir .. "/" .. subdir, ":p")

	-- Ensure the subdirectory exists
	vim.fn.mkdir(extract_dir, "p")

	-- Use the extract_dir for unzipping
	local raw_epub = require("epub.epub").new(normalized_path, extract_dir, false)
	local processed_epub = require("epub.bk").create_bk(raw_epub)
	local view_opts = {
		epub_path = normalized_path,
		data_dir = M.options.data_dir,
	}
	require("epub.view").open(processed_epub, view_opts)
end

return M
