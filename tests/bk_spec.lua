local plenary = require("plenary")
local bk_module = require("epub.bk")
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

describe("Bk module", function()
	local test_file = vim.fn.fnamemodify("tests/test.epub", ":p")
	local test_epub, bk
	local testing_dir = "temp_test_dir_bk"

	before_each(function()
		test_epub = epub.new(test_file, testing_dir, false)
		bk = bk_module.create_bk(test_epub)
	end)

	after_each(function()
		if vim.fn.isdirectory(testing_dir) == 1 then
			remove_dir(testing_dir)
		end
	end)

	it("can create a new Bk object", function()
		assert.not_nil(bk)
	end)

	it("initializes chapters", function()
		assert.is_true(#bk.chapters > 0)
		assert.equals(#test_epub.chapters, #bk.chapters)
	end)

	it("initializes metadata", function()
		assert.not_equal(#bk.meta, 0)
	end)

	it("initializes links", function()
		local link_count = 0
		for _ in pairs(bk.links) do
			link_count = link_count + 1
		end
		assert.is_true(link_count > 0)
	end)

	it("can jump to a specific chapter and line", function()
		bk:jump(2, 3)
		assert.equals(2, bk.chapter)
		assert.equals(3, bk.line)
	end)

	it("can jump to a specific byte", function()
		local target_chapter = 2
		local target_byte = 100
		bk:jump_byte(target_chapter, target_byte)
		assert.equals(target_chapter, bk.chapter)
		assert.is_true(bk.line > 0)
	end)

	it("can set and jump to marks", function()
		bk:jump(2, 3)
		bk:set_mark("a")
		bk:jump(3, 4)
		assert.equals(3, bk.chapter)
		assert.equals(4, bk.line)
		bk:jump_reset()
		assert.equals(2, bk.chapter)
		assert.equals(3, bk.line)
	end)

	it("calculates padding correctly", function()
		local pad = bk:pad()
		assert.is_true(pad >= 0)
		assert.equals(math.floor((bk.cols - bk.max_width) / 2), pad)
	end)

	it("wraps text correctly", function()
		local max_width = bk.max_width

		-- Assuming the first chapter has some content
		local first_chapter = bk.chapters[1]
		assert.is_not_nil(first_chapter, "First chapter should exist")

		assert.is_true(#first_chapter.lines > 0, "Chapter should have wrapped lines")

		for _, line_range in ipairs(first_chapter.lines) do
			local line_text = first_chapter.text:sub(line_range[1], line_range[2])
			local line_width = vim.fn.strdisplaywidth(line_text)
			assert.is_true(
				line_width <= max_width,
				string.format("Line '%s' width (%d) exceeds max width (%d)", line_text, line_width, max_width)
			)
		end
	end)

	it("truncates long chapter titles", function()
		for _, chapter in ipairs(bk.chapters) do
			assert.is_true(vim.fn.strdisplaywidth(chapter.title) <= bk.max_width)
		end
	end)

	-- Add more tests as needed...
end)
