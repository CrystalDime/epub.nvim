local plenary = require("plenary")
local xml_parser = require("epub.xml_parser")

describe("xml parser", function()
	it("should parse basic xml", function()
		local test_xml = [[
<root>
    <person id="1" name="john">
        <age>30</age>
        <city>new york</city>
    </person>
    <person id="2" name="jane">
        <age>25</age>
        <city>los angeles</city>
    </person>
</root>
        ]]
		local root = xml_parser.parse(test_xml)

		-- test find_by_tag
		local persons = xml_parser.find_by_tag(root, "person")
		assert.are.equal(2, #persons)

		-- test find_by_attribute
		local john = xml_parser.find_by_attribute(root, "name", "john")
		assert.are.equal(1, #john)
		assert.are.equal("1", john[1].attributes.id)

		-- test get_text
		local ages = xml_parser.find_by_tag(root, "age")
		assert.are.equal("30", xml_parser.get_text(ages[1]):match("^%s*(.-)%s*$"))
		assert.are.equal("25", xml_parser.get_text(ages[2]):match("^%s*(.-)%s*$"))

		-- test get_children (including text nodes)
		local root_children = xml_parser.get_children(root)
		assert.are.equal(5, #root_children)
	end)

	it("should handle xml with declaration", function()
		local test_xml = [[
<?xml version="1.0" encoding="utf-8"?>
<root>
    <element>content</element>
</root>
        ]]
		local root = xml_parser.parse(test_xml)

		assert.are.equal("root", root.tag)
		assert.are.equal(3, #root.children)
		assert.are.equal("element", root.children[2].tag)
		assert.are.equal("content", xml_parser.get_text(root.children[2]):match("^%s*(.-)%s*$"))
	end)

	it("should handle xml with comments throughout the structure", function()
		local test_xml = [[
<?xml version="1.0" encoding="utf-8"?>
<!doctype html public "-//w3c//dtd xhtml 1.0 transitional//en" "http://www.w3.org/tr/xhtml1/dtd/xhtml1-transitional.dtd">
<root>
    <!-- this is a comment -->
    <element1>content1</element1>
    <element2>
        <!-- nested comment -->
        <nested>
            nested content
            <!-- another comment -->
        </nested>
    </element2>
    <!-- comment at the end -->
</root>
    ]]
		local root = xml_parser.parse(test_xml)
		assert.are.equal("root", root.tag)
		assert.are.equal(7, #root.children)

		assert.are.equal("element1", root.children[3].tag)
		assert.are.equal("content1", xml_parser.get_text(root.children[3]):match("^%s*(.-)%s*$"))
		assert.are.equal("element2", root.children[5].tag)
		assert.are.equal(4, #root.children[5].children) -- Changed from 3 to 4
		assert.are.equal("nested", root.children[5].children[3].tag) -- Changed from 2 to 3
		assert.are.equal("nested content", xml_parser.get_text(root.children[5].children[3]):match("^%s*(.-)%s*$"))
		-- ensure comments are not parsed as nodes
		local comments = xml_parser.find_by_tag(root, "!--")
		assert.are.equal(0, #comments)
	end)

	it("should parse complex html-like xml with nested elements and various classes", function()
		local test_xml = [[
<body class="calibre">
    <p class="sp" id="ch1"> </p>
    <p class="ct"><a href="part0024.html#c_ch1" class="calibre2"><span class="ct-cn" id="4oiq4-2c29a077dda942b280918b0a86e88a42">1</span> optimal stopping</a></p>
    <p class="cst1"><a href="part0024.html#c_ch1" class="calibre2"><span class="epub-i">when to stop looking</span></a></p>
    <p class="epf"><span class="epub-i">though all christians start a wedding invitation by solemnly declaring their marriage is due to special divine arrangement, i, as a philosopher, would like to talk in greater detail about this … </span></p>
    <p class="epc"><span class="epub-sc">—johannes kepler</span></p>
    <p class="epf"><span class="epub-i">if you prefer mr. martin to every other person; if you think him the most agreeable man you have ever been in company with, why should you hesitate?</span></p>
    <p class="epc"><span class="epub-sc">—jane austen, </span><span class="epub-sc-i">emma</span></p>
    <p class="tni">it's such a common phenomenon that college guidance counselors even have a slang term for it: the 'turkey drop.' high-school sweethearts come home for thanksgiving of their freshman year of college and, four days later, return to campus single.</p>
    <p class="tx">an angst-ridden brian went to his own college guidance counselor his freshman year. his high-school girlfriend had gone to a different college several states away, and they struggled with the distance. they also struggled with a stranger and more philosophical question: how good a relationship did they have? they had no real benchmark of other relationships by which to judge it. brian's counselor recognized theirs as a classic freshman-year dilemma, and was surprisingly nonchalant in her advice: "gather data."</p>
</body>
        ]]
		local root = xml_parser.parse(test_xml)

		-- test overall structure
		assert.are.equal("body", root.tag)
		assert.are.equal("calibre", root.attributes.class)
		assert.are.equal(19, #root.children)

		-- test nested elements
		local ct_p = xml_parser.find_by_attribute(root, "class", "ct")[1]
		assert.are.equal(1, #ct_p.children)
		assert.are.equal("a", ct_p.children[1].tag)
		assert.are.equal("span", ct_p.children[1].children[1].tag)
		assert.are.equal("1", xml_parser.get_text(ct_p.children[1].children[1]):match("^%s*(.-)%s*$"))
		assert.are.equal("optimal stopping", xml_parser.get_text(ct_p.children[1].children[2]):match("^%s*(.-)%s*$"))

		-- test element with multiple classes
		local epc_p = xml_parser.find_by_attribute(root, "class", "epc")[2]
		assert.are.equal(2, #epc_p.children)
		assert.are.equal("epub-sc", epc_p.children[1].attributes.class)
		assert.are.equal("epub-sc-i", epc_p.children[2].attributes.class)

		-- test text content
		local tni_p = xml_parser.find_by_attribute(root, "class", "tni")[1]
		assert.are.equal(
			"it's such a common phenomenon that college guidance counselors even have a slang term for it: the 'turkey drop.' high-school sweethearts come home for thanksgiving of their freshman year of college and, four days later, return to campus single.",
			xml_parser.get_text(tni_p):match("^%s*(.-)%s*$")
		)

		-- test attributes with special characters
		local span_with_complex_id =
			xml_parser.find_by_attribute(root, "id", "4oiq4-2c29a077dda942b280918b0a86e88a42")[1]
		assert.are.equal("span", span_with_complex_id.tag)
		assert.are.equal("ct-cn", span_with_complex_id.attributes.class)
	end)

	it("should handle deeply nested elements with mixed content", function()
		local test_xml = [[
<root>
    <div>
        <p>paragraph 1 with <b>bold</b> text.</p>
        <p>paragraph 2 with <i>italic</i> and <u>underlined</u> text.</p>
        <section>
            <header>section header</header>
            <p>section paragraph with <a href="#">a link</a>.</p>
            <footer>section footer</footer>
        </section>
    </div>
</root>
    ]]
		local root = xml_parser.parse(test_xml)

		-- test overall structure
		assert.are.equal("root", root.tag)
		assert.are.equal(3, #root.children)
		assert.are.equal("div", root.children[2].tag)

		-- test nested structure
		local div = root.children[2]
		assert.are.equal(7, #div.children)
		assert.are.equal("p", div.children[2].tag)
		assert.are.equal(3, #div.children[2].children)
		assert.are.equal("paragraph 1 with ", xml_parser.get_text(div.children[2].children[1]))
		assert.are.equal("b", div.children[2].children[2].tag)
		assert.are.equal("bold", xml_parser.get_text(div.children[2].children[2]))
		assert.are.equal(" text.", xml_parser.get_text(div.children[2].children[3]))
		assert.are.equal("p", div.children[4].tag)
		assert.are.equal(5, #div.children[4].children)
		assert.are.equal("paragraph 2 with ", xml_parser.get_text(div.children[4].children[1]))
		assert.are.equal("i", div.children[4].children[2].tag)
		assert.are.equal("italic", xml_parser.get_text(div.children[4].children[2]))
		assert.are.equal(" and ", xml_parser.get_text(div.children[4].children[3]))
		assert.are.equal("u", div.children[4].children[4].tag)
		assert.are.equal("underlined", xml_parser.get_text(div.children[4].children[4]))
		assert.are.equal(" text.", xml_parser.get_text(div.children[4].children[5]))

		-- test deeply nested structure
		local section = div.children[6]
		assert.are.equal("section", section.tag)
		assert.are.equal(7, #section.children)
		assert.are.equal("header", section.children[2].tag)
		assert.are.equal("section header", xml_parser.get_text(section.children[2]))
		assert.are.equal("p", section.children[4].tag)
		assert.are.equal(3, #section.children[4].children)
		assert.are.equal("section paragraph with ", xml_parser.get_text(section.children[4].children[1]))
		assert.are.equal("a", section.children[4].children[2].tag)
		assert.are.equal("a link", xml_parser.get_text(section.children[4].children[2]))
		assert.are.equal(".", xml_parser.get_text(section.children[4].children[3]))
		assert.are.equal("footer", section.children[6].tag)
		assert.are.equal("section footer", xml_parser.get_text(section.children[6]))
	end)
end)
