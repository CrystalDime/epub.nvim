local epub = require("epub.epub")

local function remove_dir(dir)
	-- List all files in the directory
	local files = vim.fn.glob(dir .. "/*", false, true)

	-- Remove each file
	for _, file in ipairs(files) do
		vim.fn.delete(file, "rf")
	end

	-- Remove the directory itself
	vim.fn.delete(dir, "rf")
end

describe("EPUB module", function()
	local test_file = vim.fn.fnamemodify("tests/test.epub", ":p")
	local testing_dir = "temp_test_dir_epub"

	after_each(function()
		if vim.fn.isdirectory(testing_dir) == 1 then
			remove_dir(testing_dir)
		end
	end)

	it("test file exists", function()
		assert.is_true(vim.fn.filereadable(test_file) == 1, "Test file does not exist: " .. test_file)
	end)

	it("can create a new EPUB object", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		assert.not_nil(test_epub)
	end)

	it("loads chapters", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		assert.is_true(#test_epub.chapters > 0)
		assert.equals(2, #test_epub.chapters)
	end)

	it("parses metadata", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		assert.not_equal(test_epub.meta, "")
	end)

	it("parses links", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local link_count = 0

		for _ in pairs(test_epub.links) do
			link_count = link_count + 1
		end
		assert.is_true(link_count > 0)
		assert.is_true(test_epub.links["chapter2.xhtml#ch2-title"] ~= nil)
		assert.is_true(test_epub.links["chapter1.xhtml"] ~= nil)
	end)

	it("handles text formatting", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local chapter2 = test_epub.chapters[2]

		assert.is_true(#chapter2.formatting > 0, "Formatting array is empty")

		-- Check bold formatting
		local bold_format = nil
		for _, format in ipairs(chapter2.formatting) do
			if
				format.attribute == "bold" and chapter2.text:sub(format.start, format.finish):find("This is bold text")
			then
				bold_format = format
				break
			end
		end

		assert.not_nil(bold_format, "Bold formatting for 'This is bold text' not found")

		if bold_format then
			local bold_text_start = chapter2.text:find("This is bold text")
			assert.is_true(bold_text_start ~= nil, "Bold text not found in chapter text")

			assert.equals(bold_text_start, bold_format.start, "Bold formatting start doesn't match text position")
			assert.equals(
				bold_text_start + #"This is bold text" - 1,
				bold_format.finish,
				"Bold formatting finish doesn't match text position"
			)
		end

		-- Check underline formatting
		local underline_format = nil
		for _, format in ipairs(chapter2.formatting) do
			if format.attribute == "underline" then
				underline_format = format
				break
			end
		end

		assert.not_nil(underline_format, "Underline formatting not found")

		if underline_format then
			local underlined_text = chapter2.text:sub(underline_format.start, underline_format.finish)

			assert.is_true(
				underlined_text:find("link back to chapter 1") ~= nil,
				"Underlined text does not contain expected content"
			)

			local expected_start = chapter2.text:find("link back to chapter 1")
			assert.equals(
				expected_start,
				underline_format.start,
				"Underline formatting start doesn't match text position"
			)
			assert.equals(
				expected_start + #"link back to chapter 1" - 1,
				underline_format.finish,
				"Underline formatting finish doesn't match text position"
			)
		end
	end)

	it("handles images", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local chapter1 = test_epub.chapters[1]
		assert.is_true(chapter1.text:find("%[IMG%]") ~= nil)
	end)

	it("handles lists", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local chapter2 = test_epub.chapters[2]
		assert.is_true(chapter2.text:find("- List item 1") ~= nil)
		assert.is_true(chapter2.text:find("- List item 2") ~= nil)
	end)

	it("handles pre and code blocks", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local chapter2 = test_epub.chapters[2]
		assert.is_true(chapter2.text:find("function helloWorld") ~= nil)
	end)

	it("handles CSS classes", function()
		local test_epub = epub.new(test_file, testing_dir, false)

		local css_content = test_epub.css["styles.css"]

		-- Check if the nested CSS table is not empty
		local is_empty = next(css_content) == nil
		assert.is_false(is_empty, "CSS table is empty")

		-- Check if specific classes exist
		assert.is_true(css_content[".note"] ~= nil, ".note class not found")
		assert.is_true(css_content[".highlight"] ~= nil, ".highlight class not found")

		-- Check properties of .note class
		assert.equals("#f0f0f0", css_content[".note"]["background-color"], "background-color mismatch")
		assert.equals("10px", css_content[".note"]["padding"], "padding mismatch")

		-- Check properties of .highlight class
		assert.equals("bold", css_content[".highlight"]["font-weight"], "font-weight mismatch")
		assert.equals("red", css_content[".highlight"]["color"], "color mismatch")
	end)

	it("applies highlight class styling correctly", function()
		local test_epub = epub.new(test_file, testing_dir, false)
		local chapter2 = test_epub.chapters[2]

		local highlight_format = nil
		for _, format in ipairs(chapter2.formatting) do
			if
				format.attribute == "bold" and chapter2.text:sub(format.start, format.finish):find("highlighted text")
			then
				highlight_format = format
				break
			end
		end

		assert.not_nil(highlight_format, "Highlight formatting not found")

		if highlight_format then
			local highlighted_text = chapter2.text:sub(highlight_format.start, highlight_format.finish)
			assert.is_true(highlighted_text:find("highlighted text") ~= nil, "Highlighted text not found")
			assert.equals(
				chapter2.text:find("highlighted text"),
				highlight_format.start,
				"Highlight start doesn't match"
			)
			assert.equals(
				chapter2.text:find("highlighted text") + #"highlighted text" - 1,
				highlight_format.finish,
				"Highlight end doesn't match"
			)
		end
	end)
end)
