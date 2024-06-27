local M = {}

function M.parse(css_text)
	local styles = {}
	for selector, body in css_text:gmatch("([%w%.#]+)%s*{([^}]*)}") do
		local attributes = {}
		for property, value in body:gmatch("(%w+)%s*:%s*([^;]+);") do
			attributes[property] = value:lower()
		end
		styles[selector] = attributes
	end
	return styles
end

return M
