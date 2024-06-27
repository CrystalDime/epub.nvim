local M = {}

---Unzip a file to a specified output directory
---@param epub_path string The path to the EPUB file
---@param output_dir string The directory to extract the EPUB contents to
---@return UnzipResult
M.unzip = function(epub_path, output_dir)
	-- Ensure the output directory exists
	vim.fn.mkdir(output_dir, "p")
	-- Construct the unzip command
	local cmd =
		string.format("unzip -o '%s' -d '%s' 2>&1", vim.fn.shellescape(epub_path), vim.fn.shellescape(output_dir))

	-- Execute the unzip command
	local output = vim.fn.system(cmd)
	local success = vim.v.shell_error == 0

	-- Prepare the result
	local result = {
		success = success,
		message = success and "EPUB successfully extracted" or "Failed to extract EPUB",
		output_dir = output_dir,
		debug_info = {
			command = cmd,
			output = output,
			exit_code = vim.v.shell_error,
		},
	}

	return result
end

-- Convert a character position to line and column numbers
---Convert a character position to line and column numbers
---@param lines table<number, number> A table where each key is a line number and the value is the ending position of that line
---@param pos number The character position to convert
---@return number | nil line The line number
---@return number | nil col The column number
M.get_line_col = function(lines, pos)
	if type(line_ends) ~= "table" then
		vim.notify("Error: 'line_ends' is not a table", vim.log.levels.ERROR)
		return nil, nil
	end
	if type(pos) ~= "number" then
		vim.notify("Error: 'pos' is not a number", vim.log.levels.ERROR)
		return nil, nil
	end

	local prev_end = 0
	for line_num, line_end in ipairs(line_ends) do
		if type(line_end) ~= "number" then
			vim.notify("Error: line end position is not a number", vim.log.levels.ERROR)
			return nil, nil
		end
		if pos <= line_end then
			local col = pos - prev_end
			return line_num, col
		end
		prev_end = line_end
	end

	vim.notify("Warning: Position " .. pos .. " is out of range", vim.log.levels.WARN)
	return nil, nil -- Position is out of range
end

M.copy_table = function(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

return M
