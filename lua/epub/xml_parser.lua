---@class XMLParser
local M = {}

-- Helper function to trim whitespace
local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- Helper function to parse attributes
local function parse_attributes(s)
	local attrs = {}
	for name, value in s:gmatch('([%w:%-%_]+)%s*=%s*"([^"]*)"') do
		attrs[name] = value
	end
	return attrs
end

---@param xml string
---@return XMLElement
function M.parse(xml)
	local stack = {}
	local current = { type = "element", tag = "root", attributes = {}, children = {} }
	local i = 1

	while i <= #xml do
		-- Handle comments
		if xml:sub(i, i + 3) == "<!--" then
			local j = xml:find("-->", i + 4, true)
			if j then
				i = j + 3
			end
		-- Handle XML declaration and doctypes
		elseif xml:sub(i, i + 1) == "<?" or xml:sub(i, i + 1) == "<!" then
			local j = xml:find(">", i + 2, true)
			if j then
				i = j + 1
			end
		-- Handle opening tags
		elseif xml:sub(i, i) == "<" and xml:sub(i + 1, i + 1) ~= "/" then
			local j = xml:find(">", i + 1, true)
			if j then
				local tag_content = xml:sub(i + 1, j - 1)
				local tag, attrs = tag_content:match("^(%S+)%s*(.-)$")
				local node = {
					type = "element",
					tag = tag,
					attributes = parse_attributes(attrs),
					children = {},
					parent = current,
				}
				table.insert(current.children, node)
				if not tag_content:match("/$") then
					table.insert(stack, current)
					current = node
				end
				i = j + 1
			else
				i = i + 1
			end
		-- Handle closing tags
		elseif xml:sub(i, i + 1) == "</" then
			local j = xml:find(">", i + 2, true)
			if j then
				local tag = xml:sub(i + 2, j - 1)
				if tag == current.tag and #stack > 0 then
					current = table.remove(stack)
				end
				i = j + 1
			else
				i = i + 1
			end
		-- Handle text content
		else
			local j = xml:find("<", i, true)
			if j then
				local text = xml:sub(i, j - 1)
				local text_node = { type = "text", text = text, parent = current }
				table.insert(current.children, text_node)
				i = j
			else
				local text = xml:sub(i)
				local text_node = { type = "text", text = text, parent = current }
				table.insert(current.children, text_node)
				i = #xml + 1
			end
		end
	end

	-- Find the first non-text node child
	for _, child in ipairs(current.children) do
		if child.type ~= "text" then
			return child
		end
	end

	-- If no non-text child is found, return the root element itself
	return current
end

---@param node XMLNode
---@param tag string
---@return XMLElement[]
function M.find_by_tag(node, tag)
	local results = {}

	if node.type == "element" and node.tag == tag then
		table.insert(results, node)
	end

	if node.type == "element" then
		for _, child in ipairs(node.children) do
			local child_results = M.find_by_tag(child, tag)
			for _, result in ipairs(child_results) do
				table.insert(results, result)
			end
		end
	end

	return results
end

---@param node XMLNode
---@param name string
---@param value string
---@return XMLElement[]
function M.find_by_attribute(node, name, value)
	local results = {}

	if node.type == "element" and node.attributes and node.attributes[name] == value then
		table.insert(results, node)
	end

	if node.type == "element" then
		for _, child in ipairs(node.children) do
			local child_results = M.find_by_attribute(child, name, value)
			for _, result in ipairs(child_results) do
				table.insert(results, result)
			end
		end
	end

	return results
end

---@param node XMLNode
---@return string
function M.get_text(node)
	if node.type == "text" then
		return node.text
	end

	local text = {}
	if node.type == "element" then
		for _, child in ipairs(node.children) do
			table.insert(text, M.get_text(child))
		end
	end
	return trim(table.concat(text, " "))
end

---@param node XMLNode
---@return XMLNode[]
function M.get_children(node)
	if node.type == "element" then
		return node.children
	else
		return {}
	end
end

---@param node XMLNode
---@param indent? string
function M.print(node, indent)
	indent = indent or ""

	if node.type == "element" then
		-- Print the node tag
		io.write(indent .. "Node: " .. (node.tag or "No tag") .. "\n")

		-- Print attributes
		if next(node.attributes) then
			io.write(indent .. "  Attributes:\n")
			for name, value in pairs(node.attributes) do
				io.write(indent .. "    " .. name .. " = " .. value .. "\n")
			end
		else
			io.write(indent .. "  No attributes\n")
		end

		-- Print children
		if #node.children > 0 then
			io.write(indent .. "  Children (" .. #node.children .. "):\n")
			for i, child in ipairs(node.children) do
				io.write(indent .. "    Child " .. i .. ":\n")
				M.print(child, indent .. "      ")
			end
		else
			io.write(indent .. "  No children\n")
		end

		-- Print parent information
		if node.parent then
			io.write(indent .. "  Parent: " .. (node.parent.tag or "No tag") .. "\n")
		else
			io.write(indent .. "  No parent (root node)\n")
		end
	elseif node.type == "text" then
		io.write(indent .. "Text: " .. (node.text or "No text") .. "\n")
	end

	io.write("\n") -- Add a blank line between nodes for better readability
end

return M
