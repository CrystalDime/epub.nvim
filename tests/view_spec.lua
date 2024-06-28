local plenary = require("plenary")
local epub = require("epub.epub")
local bk_module = require("epub.bk")
local viewer = require("epub.view")

describe("EPUB View", function()
	local test_file = vim.fn.fnamemodify("tests/test.epub", ":p")
	local test_epub, bk
	local testing_dir = "temp_test_dir_view"
	local data_dir_test = testing_dir .. "/view_data"

	before_each(function()
		vim.fn.mkdir(testing_dir, "p")
		vim.fn.mkdir(data_dir_test, "p")
		test_epub = epub.new(test_file, testing_dir, false)
		bk = bk_module.create_bk(test_epub)
	end)

	after_each(function()
		vim.fn.delete(testing_dir, "rf")
	end)

	describe("open", function()
		it("should create a new buffer and display the first chapter", function()
			viewer.open(bk, { epub_path = test_file, data_dir = data_dir_test })

			local bufnr = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

			assert.truthy(#lines > 0)
		end)
	end)

	describe("navigation", function()
		it("should move to the next and previous chapters", function()
			viewer.open(bk, { epub_path = test_file, data_dir = data_dir_test })
			local initial_chapter = bk.chapter

			viewer.next_chapter()
			assert.equals(initial_chapter + 1, bk.chapter)

			viewer.prev_chapter()
			assert.equals(initial_chapter, bk.chapter)
		end)
	end)

	describe("show_toc", function()
		it("should display the table of contents", function()
			viewer.open(bk, { epub_path = test_file, data_dir = data_dir_test })

			local selected_chapter
			vim.ui.select = function(items, opts, on_choice)
				assert.truthy(#items > 0)
				assert.equals("Select a chapter:", opts.prompt)
				selected_chapter = items[2] -- Select the second chapter
				on_choice(selected_chapter)
			end

			viewer.show_toc()

			assert.equals(2, bk.chapter)
		end)
	end)

	describe("save and load progress", function()
		it("should save and load the last read chapter", function()
			viewer.open(bk, { epub_path = test_file, data_dir = data_dir_test })
			viewer.next_chapter()
			local last_chapter = bk.chapter

			-- Close and reopen the book
			bk = nil
			collectgarbage()
			test_epub = epub.new(test_file, testing_dir, false)
			bk = bk_module.create_bk(test_epub)
			viewer.open(bk, { epub_path = test_file, data_dir = data_dir_test })

			assert.equals(last_chapter, bk.chapter)
		end)
	end)
end)
