local ts_utils = require("nvim-treesitter.ts_utils")
local luasnip = require("luasnip")
local snippet = luasnip.snippet
local text_node = luasnip.text_node
local insert_node = luasnip.insert_node

local M = {}

---@private
---@param node TSNode
---@param bufnr number|nil
---@return string
function M._get_node_text(node, bufnr)
	if not bufnr then
		bufnr = vim.api.nvim_get_current_buf()
	end
	return vim.treesitter.get_node_text(node, bufnr)
end

---@alias TSNodeType "formal_parameters"|"function_declaration"|"identifier"|"rest_pattern"
---
---@param node TSNode
---@param types TSNodeType[]
---@return TSNode[]
local function find_node_children(node, types)
	---@type TSNode[]
	local children = {}
	for child in node:iter_children() do
		for _, type in ipairs(types) do
			if child:type() == type then
				table.insert(children, child)
			end
		end
	end
	return children
end

---@private
---@param node TSNode
---@param type TSNodeType
---@return TSNode|nil
function M._find_node_child(node, type)
	for child in node:iter_children() do
		if child:type() == type then
			return child
		end
	end
	return nil
end

---@private
---@return TSNode|nil
function M._get_function_node()
	local current_node = ts_utils.get_node_at_cursor()
	if current_node == nil then
		vim.notify("No node found", vim.log.levels.INFO)
		return nil
	end

	---@type TSNode|nil
	local function_node = nil
	while current_node ~= nil and current_node.parent do
		if current_node:type() == "function_declaration" then
			function_node = current_node
		end

		---@type TSNode|nil
		current_node = current_node:parent()
		if not current_node then
			break
		end
	end

	return function_node
end

---@private
---@param function_node TSNode
---@return TSNode[]|nil
function M._get_function_parameters(function_node)
	local formal_parameters = M._find_node_child(function_node, "formal_parameters")
	if not formal_parameters then
		vim.notify("No formal parameters found", vim.log.levels.INFO)
		return nil
	end

	---@type TSNode[]
	local identifiers = find_node_children(formal_parameters, { "identifier" })
	local rest_pattern = M._find_node_child(formal_parameters, "rest_pattern")
	if rest_pattern ~= nil then
		local rest_pattern_identifiers = find_node_children(rest_pattern, { "identifier" })
		for _, identifier in ipairs(rest_pattern_identifiers) do
			table.insert(identifiers, identifier)
		end
	end

	return identifiers
end

M.insert_jsdoc = function()
	local function_node = M._get_function_node()
	if not function_node then
		vim.notify("No function node found", vim.log.levels.INFO)
		return nil
	end

	local parameters = M._get_function_parameters(function_node)
	if not parameters then
		vim.notify("No parameters found", vim.log.levels.INFO)
		return nil
	end

	---@type unknown[]
	local nodes = {}
	table.insert(nodes, text_node({ "/**", "" }))
	for i, parameter in ipairs(parameters) do
		local parameter_name = M._get_node_text(parameter)
		table.insert(nodes, text_node(" * @param {"))
		table.insert(nodes, insert_node(i, ""))
		table.insert(nodes, text_node("} "))
		table.insert(nodes, text_node({ parameter_name, "" }))
	end
	table.insert(nodes, text_node({ " */", "" }))

	luasnip.add_snippets("javascript", { snippet("jsdoc", nodes) })

	-- Insert a new line above the function
	local current_window = vim.api.nvim_get_current_win()
	local start_row, _ = function_node:start()
	vim.api.nvim_win_set_cursor(current_window, { start_row + 1, 0 })

	---@type table<string, table<string, string>>
	luasnip.snip_expand(luasnip.get_snippets(vim.bo.ft)[1])
end

M.setup = function() end

return M
