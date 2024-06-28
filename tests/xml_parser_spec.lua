local plenary = require("plenary")
local xml_parser = require("epub.xml_parser")

describe("XML Parser", function()
	it("should parse basic XML", function()
		local test_xml = [[
<root>
    <person id="1" name="John">
        <age>30</age>
        <city>New York</city>
    </person>
    <person id="2" name="Jane">
        <age>25</age>
        <city>Los Angeles</city>
    </person>
</root>
        ]]
		local root = xml_parser.parse(test_xml)

		-- Test find_by_tag
		local persons = xml_parser.find_by_tag(root, "person")
		assert.are.equal(2, #persons)

		-- Test find_by_attribute
		local john = xml_parser.find_by_attribute(root, "name", "John")
		assert.are.equal(1, #john)
		assert.are.equal("1", john[1].attributes.id)

		-- Test get_text
		local ages = xml_parser.find_by_tag(root, "age")
		assert.are.equal("30", xml_parser.get_text(ages[1]))
		assert.are.equal("25", xml_parser.get_text(ages[2]))

		-- Test get_children
		local root_children = xml_parser.get_children(root)
		assert.are.equal(2, #root_children)
	end)

	it("should parse attributes with hyphens", function()
		local test_xml = [[
<root>
    <element full-path="/path/to/file" another-attr="value">
        Content
    </element>
</root>
        ]]
		local root = xml_parser.parse(test_xml)
		local element = xml_parser.find_by_tag(root, "element")[1]
		assert.are.equal("/path/to/file", element.attributes["full-path"])
		assert.are.equal("value", element.attributes["another-attr"])
	end)

	it("should handle XML with declaration", function()
		local test_xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<root>
    <element>Content</element>
</root>
        ]]
		local root = xml_parser.parse(test_xml)

		assert.are.equal("root", root.tag)
		assert.are.equal(1, #root.children)
		assert.are.equal("element", root.children[1].tag)
		assert.are.equal("Content", xml_parser.get_text(root.children[1]))
	end)

	it("should parse attributes with hyphens and colons", function()
		local test_xml = [[
<root>
    <element full-path="/path/to/file" dc:title="Some Title" some_attr="value">
        Content
    </element>
</root>
        ]]
		local root = xml_parser.parse(test_xml)
		local element = xml_parser.find_by_tag(root, "element")[1]
		assert.are.equal("/path/to/file", element.attributes["full-path"])
		assert.are.equal("Some Title", element.attributes["dc:title"])
		assert.are.equal("value", element.attributes["some_attr"])
	end)

	it("should parse tags with colons", function()
		local test_xml = [[
<root>
    <ns:tag>Content</ns:tag>
    <another:tag attr="value" />
</root>
        ]]
		local root = xml_parser.parse(test_xml)
		local ns_tag = xml_parser.find_by_tag(root, "ns:tag")[1]
		local another_tag = xml_parser.find_by_tag(root, "another:tag")[1]
		assert.are.equal("ns:tag", ns_tag.tag)
		assert.are.equal("Content", xml_parser.get_text(ns_tag))
		assert.are.equal("another:tag", another_tag.tag)
		assert.are.equal("value", another_tag.attributes.attr)
	end)

	it("should handle XML with comments throughout the structure", function()
		local test_xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<root>
    <!-- This is a comment -->
    <element1>Content1</element1>
    <element2>
        <!-- Nested comment -->
        <nested>
            Nested content
            <!-- Another comment -->
        </nested>
    </element2>
    <!-- Comment at the end -->
</root>
        ]]
		local root = xml_parser.parse(test_xml)
		assert.are.equal("root", root.tag)
		assert.are.equal(2, #root.children)
		assert.are.equal("element1", root.children[1].tag)
		assert.are.equal("Content1", xml_parser.get_text(root.children[1]))
		assert.are.equal("element2", root.children[2].tag)
		assert.are.equal(1, #root.children[2].children)
		assert.are.equal("nested", root.children[2].children[1].tag)
		assert.are.equal("Nested content", xml_parser.get_text(root.children[2].children[1]):match("^%s*(.-)%s*$"))
		-- Ensure comments are not parsed as nodes
		local comments = xml_parser.find_by_tag(root, "!--")
		assert.are.equal(0, #comments)
	end)

	it("should parse complex HTML-like XML with nested elements and various classes", function()
		local test_xml = [[
<body class="calibre">
    <p class="sp" id="ch1"> </p>
    <p class="ct"><a href="part0024.html#c_ch1" class="calibre2"><span class="ct-cn" id="4OIQ4-2c29a077dda942b280918b0a86e88a42">1</span> Optimal Stopping</a></p>
    <p class="cst1"><a href="part0024.html#c_ch1" class="calibre2"><span class="epub-i">When to Stop Looking</span></a></p>
    <p class="epf"><span class="epub-i">Though all Christians start a wedding invitation by solemnly declaring their marriage is due to special Divine arrangement, I, as a philosopher, would like to talk in greater detail about this … </span></p>
    <p class="epc"><span class="epub-sc">—JOHANNES KEPLER</span></p>
    <p class="epf"><span class="epub-i">If you prefer Mr. Martin to every other person; if you think him the most agreeable man you have ever been in company with, why should you hesitate?</span></p>
    <p class="epc"><span class="epub-sc">—JANE AUSTEN, </span><span class="epub-sc-i">EMMA</span></p>
    <p class="tni">It's such a common phenomenon that college guidance counselors even have a slang term for it: the 'turkey drop.' High-school sweethearts come home for Thanksgiving of their freshman year of college and, four days later, return to campus single.</p>
    <p class="tx">An angst-ridden Brian went to his own college guidance counselor his freshman year. His high-school girlfriend had gone to a different college several states away, and they struggled with the distance. They also struggled with a stranger and more philosophical question: how good a relationship did they have? They had no real benchmark of other relationships by which to judge it. Brian's counselor recognized theirs as a classic freshman-year dilemma, and was surprisingly nonchalant in her advice: "Gather data."</p>
</body>
        ]]
		local root = xml_parser.parse(test_xml)

		-- Test overall structure
		assert.are.equal("body", root.tag)
		assert.are.equal("calibre", root.attributes.class)
		assert.are.equal(9, #root.children)

		-- Test nested elements
		local ct_p = xml_parser.find_by_attribute(root, "class", "ct")[1]
		assert.are.equal(1, #ct_p.children)
		assert.are.equal("a", ct_p.children[1].tag)
		assert.are.equal("span", ct_p.children[1].children[1].tag)
		assert.are.equal("1", xml_parser.get_text(ct_p.children[1].children[1]))
		assert.are.equal(" Optimal Stopping", xml_parser.get_text(ct_p.children[1].children[2]))

		-- Test element with multiple classes
		local epc_p = xml_parser.find_by_attribute(root, "class", "epc")[2]
		assert.are.equal(2, #epc_p.children)
		assert.are.equal("epub-sc", epc_p.children[1].attributes.class)
		assert.are.equal("epub-sc-i", epc_p.children[2].attributes.class)

		-- Test text content
		local tni_p = xml_parser.find_by_attribute(root, "class", "tni")[1]
		assert.are.equal(
			"It's such a common phenomenon that college guidance counselors even have a slang term for it: the 'turkey drop.' High-school sweethearts come home for Thanksgiving of their freshman year of college and, four days later, return to campus single.",
			xml_parser.get_text(tni_p)
		)

		-- Test attributes with special characters
		local span_with_complex_id =
			xml_parser.find_by_attribute(root, "id", "4OIQ4-2c29a077dda942b280918b0a86e88a42")[1]
		assert.are.equal("span", span_with_complex_id.tag)
		assert.are.equal("ct-cn", span_with_complex_id.attributes.class)
	end)

	it("should handle deeply nested elements with mixed content", function()
		local test_xml = [[
<root>
    <div>
        <p>Paragraph 1 with <b>bold</b> text.</p>
        <p>Paragraph 2 with <i>italic</i> and <u>underlined</u> text.</p>
        <section>
            <header>Section Header</header>
            <p>Section paragraph with <a href="#">a link</a>.</p>
            <footer>Section Footer</footer>
        </section>
    </div>
</root>
        ]]
		local root = xml_parser.parse(test_xml)

		-- Test overall structure
		assert.are.equal("root", root.tag)
		assert.are.equal(1, #root.children)
		assert.are.equal("div", root.children[1].tag)

		-- Test nested structure
		local div = root.children[1]
		assert.are.equal(3, #div.children)
		assert.are.equal("p", div.children[1].tag)
		assert.are.equal(3, #div.children[1].children)
		assert.are.equal("Paragraph 1 with ", xml_parser.get_text(div.children[1].children[1]))
		assert.are.equal("b", div.children[1].children[2].tag)
		assert.are.equal("bold", xml_parser.get_text(div.children[1].children[2]))
		assert.are.equal(" text.", xml_parser.get_text(div.children[1].children[3]))
		assert.are.equal("p", div.children[2].tag)
		assert.are.equal(5, #div.children[2].children)
		assert.are.equal("Paragraph 2 with ", xml_parser.get_text(div.children[2].children[1]))
		assert.are.equal("i", div.children[2].children[2].tag)
		assert.are.equal("italic", xml_parser.get_text(div.children[2].children[2]))
		assert.are.equal(" and ", xml_parser.get_text(div.children[2].children[3]))
		assert.are.equal("u", div.children[2].children[4].tag)
		assert.are.equal("underlined", xml_parser.get_text(div.children[2].children[4]))
		assert.are.equal(" text.", xml_parser.get_text(div.children[2].children[5]))

		-- Test deeply nested structure
		local section = div.children[3]
		assert.are.equal("section", section.tag)
		assert.are.equal(3, #section.children)
		assert.are.equal("header", section.children[1].tag)
		assert.are.equal("Section Header", xml_parser.get_text(section.children[1]))
		assert.are.equal("p", section.children[2].tag)
		assert.are.equal(3, #section.children[2].children)
		assert.are.equal("Section paragraph with ", xml_parser.get_text(section.children[2].children[1]))
		assert.are.equal("a", section.children[2].children[2].tag)
		assert.are.equal("a link", xml_parser.get_text(section.children[2].children[2]))
		assert.are.equal(".", xml_parser.get_text(section.children[2].children[3]))
		assert.are.equal("footer", section.children[3].tag)
		assert.are.equal("Section Footer", xml_parser.get_text(section.children[3]))
	end)
end)
