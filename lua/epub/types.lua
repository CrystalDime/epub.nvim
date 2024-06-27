---@class XMLNode
---@field type string
---@field parent? XMLNode
---@field attributes table<string, string>
---@field children XMLNode[]

---@class XMLTextNode : XMLNode
---@field text string

---@class XMLElement : XMLNode
---@field tag string

---@class XMLParser
---@field parse fun(xml: string): XMLElement
---@field find_by_tag fun(node: XMLNode, tag: string): XMLElement[]
---@field find_by_attribute fun(node: XMLNode, name: string, value: string): XMLElement[]
---@field get_text fun(node: XMLNode): string
---@field get_attributes fun(node: XMLNode): table<string, string>
---@field get_children fun(node: XMLNode): XMLNode[]
---@field print fun(node: XMLNode, indent?: string)

---@alias Path string

---@class UnzipResult
---@field success boolean
---@field message string
---@field output_dir Path
---@field debug_info UnzipDebugInfo

---@class UnzipDebugInfo
---@field command string
---@field output string
---@field exit_code number
