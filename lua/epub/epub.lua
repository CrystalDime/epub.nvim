local xmlparser = require("epub.xml_parser")
local util = require("epub.utils")

---@class FormattingRange
---@field start number
---@field finish number
---@field attribute string

---@class Chapter
---@field title string
---@field text string
---@field formatting FormattingRange[]
---@field links table<number, {start: number, finish: number, url: string}>
---@field frag table<string, number>

---@class Epub
---@field container UnzipResult
---@field rootdir string
---@field chapters Chapter[]
---@field links table<string, {chapter: number, position: number}>
---@field meta string
---@field css table<string, table>

---@class Epub
local M = {}

---@param path string
---@param output_dir string
---@param meta boolean
---@return Epub|nil
function M.new(path, output_dir, meta)
	local epub = {}
	local unzip_result = util.unzip(path, output_dir)
	if not unzip_result.success then
		print("Unzip failed. Debug info:")
		print("Command:", unzip_result.debug_info.command)
		print("Output:", unzip_result.debug_info.output)
		print("Exit code:", unzip_result.debug_info.exit_code)
		return nil
	end

	epub.container = unzip_result
	epub.rootdir = ""
	epub.chapters = {}
	epub.links = {}
	epub.meta = ""

	local chapters = M.get_spine(epub)
	if not meta then
		M.get_chapters(epub, chapters)
	end

	return epub
end

---@param epub Epub
---@param name string
---@return string
function M.get_text(epub, name)
	local file = io.open(epub.container.output_dir .. "/" .. name, "r")
	if not file then
		return ""
	end
	local content = file:read("*all")
	file:close()
	return content
end

---@param epub Epub
---@param spine table<number, {title: string, path: string}>
function M.get_chapters(epub, spine)
	for _, chapter in ipairs(spine) do
		local xml = M.get_text(epub, epub.rootdir .. chapter.path)
		local doc = xmlparser.parse(xml)
		local body = xmlparser.find_by_tag(doc, "body")[1]

		local c = {
			title = chapter.title,
			text = "",
			lines = {},
			formatting = {},
			state = {},
			links = {},
			frag = {},
		}

		M.render(epub, body, c)

		if c.text:match("^%s*$") then
			goto continue
		end

		local relative = chapter.path:match("([^/]+)$")
		epub.links[relative] = { #epub.chapters + 1, 0 }

		for id, pos in pairs(c.frag) do
			local url = relative .. "#" .. id
			epub.links[url] = { #epub.chapters + 1, pos }
		end

		for _, link in ipairs(c.links) do
			if link.url:sub(1, 1) == "#" then
				link.url = relative .. link.url
			end
		end

		table.insert(epub.chapters, c)

		::continue::
	end
end

---@param epub Epub
---@return table<number, {title: string, path: string}>
function M.get_spine(epub)
	local container_xml = M.get_text(epub, "META-INF/container.xml")
	local container_doc = xmlparser.parse(container_xml)

	local rootfile = xmlparser.find_by_tag(container_doc, "rootfile")[1]
	local path = rootfile.attributes["full-path"]
	local content_xml = M.get_text(epub, path)
	local content_doc = xmlparser.parse(content_xml)

	epub.rootdir = path:match("(.*/)") or ""
	epub.css = {}

	local manifest = {}
	local nav = {}

	local package = xmlparser.find_by_tag(content_doc, "package")[1]
	local metadata = xmlparser.find_by_tag(package, "metadata")[1]
	local manifest_node = xmlparser.find_by_tag(package, "manifest")[1]
	local spine_node = xmlparser.find_by_tag(package, "spine")[1]

	for _, child in ipairs(xmlparser.get_children(metadata)) do
		local name = child.tag
		local text = xmlparser.get_text(child)
		if text and name ~= "meta" then
			epub.meta = epub.meta .. name .. ": " .. text .. "\n"
		end
	end

	for _, item in ipairs(xmlparser.find_by_tag(manifest_node, "item")) do
		manifest[item.attributes["id"]] = item.attributes["href"]
	end

	for id, href in pairs(manifest) do
		local item = xmlparser.find_by_attribute(manifest_node, "id", id)[1]
		if item and item.attributes["media-type"] == "text/css" then
			local css_content = M.get_text(epub, href)
			epub.css[href] = M.parse_css(css_content)
		end
	end

	local version = package.attributes["version"]
	if version == "3.0" then
		local nav_item = xmlparser.find_by_attribute(manifest_node, "id", "nav")[1]
			or xmlparser.find_by_attribute(manifest_node, "properties", "nav")[1]
		local nav_path = nav_item.attributes["href"]
		local nav_xml = M.get_text(epub, epub.rootdir .. nav_path)
		local nav_doc = xmlparser.parse(nav_xml)
		M.epub3(nav_doc, nav)
	else
		local toc_id = spine_node.attributes["toc"] or "ncx"
		local toc_path = manifest[toc_id]
		local toc_xml = M.get_text(epub, epub.rootdir .. toc_path)
		local toc_doc = xmlparser.parse(toc_xml)
		M.epub2(toc_doc, nav)
	end

	local spine = {}
	for i, itemref in ipairs(xmlparser.find_by_tag(spine_node, "itemref")) do
		local id = itemref.attributes["idref"]
		local path = manifest[id]
		manifest[id] = nil
		local label = nav[path] or tostring(i)
		table.insert(spine, { title = label, path = path })
	end

	return spine
end

---@param doc XMLNode
---@param nav table<string, string>
function M.epub2(doc, nav)
	local navMap = xmlparser.find_by_tag(doc, "navMap")[1]
	for _, navPoint in ipairs(xmlparser.find_by_tag(navMap, "navPoint")) do
		local content = xmlparser.find_by_tag(navPoint, "content")[1]
		local path = content.attributes["src"]:match("^[^#]+")
		local text_node = xmlparser.find_by_tag(navPoint, "text")[1]
		local text = xmlparser.get_text(text_node)
		nav[path] = nav[path] or text
	end
end

---@param doc XMLNode
---@param nav table<string, string>
function M.epub3(doc, nav)
	local nav_node = xmlparser.find_by_tag(doc, "nav")[1]
	local ol = xmlparser.find_by_tag(nav_node, "ol")[1]
	for _, a in ipairs(xmlparser.find_by_tag(ol, "a")) do
		local path = a.attributes["href"]:match("^[^#]+")
		local text = xmlparser.get_text(a)
		nav[path] = text
	end
end

---@param epub Epub
---@param node XMLNode
---@param chapter Chapter
function M.render(epub, node, chapter)
	if node.type == "text" then
		local text = node.text
		if text then
			local start_pos = #chapter.text + 1
			chapter.text = chapter.text .. text
			local end_pos = #chapter.text
		end
		return
	end

	local id = node.attributes["id"]
	if id then
		chapter.frag[id] = #chapter.text + 1
	end

	local class = node.attributes["class"]
	if class then
		local styles = M.get_styles(epub, class)
		if styles["font-weight"] == "bold" then
			M.render_with_attribute(epub, node, chapter, "bold")
			return
		elseif styles["font-style"] == "italic" then
			M.render_with_attribute(epub, node, chapter, "italic")
			return
		end
	end

	local tag = node.tag
	if tag == "br" then
		chapter.text = chapter.text .. "\n"
	elseif tag == "hr" then
		chapter.text = chapter.text .. "\n* * *\n"
	elseif tag == "img" then
		chapter.text = chapter.text .. "\n[IMG]\n"
	elseif tag == "a" then
		local href = node.attributes["href"]
		if href and not href:match("^http") then
			local start = #chapter.text + 1
			M.render_with_attribute(epub, node, chapter, "underline")
			local finish = #chapter.text
			table.insert(chapter.links, { start = start, finish = finish, url = href })
		else
			M.render_children(epub, node, chapter)
		end
	elseif tag == "em" then
		M.render_with_attribute(epub, node, chapter, "italic")
	elseif tag == "strong" then
		M.render_with_attribute(epub, node, chapter, "bold")
	elseif tag:match("^h%d$") then
		chapter.text = chapter.text .. "\n"
		M.render_with_attribute(epub, node, chapter, "bold")
		chapter.text = chapter.text .. "\n"
	elseif tag == "blockquote" or tag == "div" or tag == "p" or tag == "tr" then
		chapter.text = chapter.text .. "\n"
		M.render_children(epub, node, chapter)
		chapter.text = chapter.text .. "\n"
	elseif tag == "li" then
		chapter.text = chapter.text .. "\n- "
		M.render_children(epub, node, chapter)
		chapter.text = chapter.text .. "\n"
	elseif tag == "pre" or tag == "code" then
		chapter.text = chapter.text .. "\n  "
		for _, child in ipairs(xmlparser.get_children(node)) do
			if child.type == "text" and child.text then
				chapter.text = chapter.text .. child.text:gsub("\n", "\n  ")
			else
				M.render(epub, child, chapter)
			end
		end
		chapter.text = chapter.text .. "\n"
	else
		M.render_children(epub, node, chapter)
	end
end

---@param epub Epub
---@param node XMLNode
---@param chapter Chapter
---@param attribute string
function M.render_with_attribute(epub, node, chapter, attribute)
	local start_pos = #chapter.text + 1
	M.render_children(epub, node, chapter)
	local end_pos = #chapter.text
	table.insert(chapter.formatting, { start = start_pos, finish = end_pos, attribute = attribute })
end

---@param epub Epub
---@param node XMLNode
---@param chapter Chapter
function M.render_children(epub, node, chapter)
	for _, child in ipairs(xmlparser.get_children(node)) do
		M.render(epub, child, chapter)
	end
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

---@param css_content string
---@return table
function M.parse_css(css_content)
	local css = {}

	-- Remove comments
	css_content = css_content:gsub("/%*.-%*/", "")

	for selector, rules in css_content:gmatch("([^{}]+)%s*{%s*([^}]+)}") do
		selector = trim(selector)
		css[selector] = {}

		for property, value in rules:gmatch("([^:]+)%s*:%s*([^;]+)%s*;?") do
			property = trim(property)
			css[selector][property] = trim(value)
		end
	end

	return css
end

---@param epub Epub
---@param class string
---@return table
function M.get_styles(epub, class)
	local styles = {}
	for _, css_file in pairs(epub.css) do
		if css_file["." .. class] then
			for property, value in pairs(css_file["." .. class]) do
				styles[property] = value
			end
		end
	end
	return styles
end

return M
