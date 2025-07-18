local M = {}

---Unzip a file to a specified output directory
---@param epub_path string The path to the EPUB file
---@param output_dir string The directory to extract the EPUB contents to
---@return UnzipResult
M.unzip = function(epub_path, output_dir)
	-- Ensure the output directory exists
	vim.fn.mkdir(output_dir, "p")

	-- Normalize Windows paths: replace backslashes with slashes and remove trailing slash
	if jit and jit.os == "Windows" then
		epub_path = epub_path:gsub("\\", "/")
		output_dir = output_dir:gsub("\\", "/"):gsub("/$", "") -- remove trailing slash
	end

	-- Construct the unzip command
	local cmd = string.format("unzip -o %s -d %s 2>&1", vim.fn.shellescape(epub_path), vim.fn.shellescape(output_dir))

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

M.copy_table = function(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

return M
