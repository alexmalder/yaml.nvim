local M = {}

local function get_keys(root)
	local keys = {}
	for node, name in root:iter_children() do
		if name == "key" then
			table.insert(keys, node)
		end

		if node:child_count() > 0 then
			for _, child in pairs(get_keys(node)) do
				table.insert(keys, child)
			end
		end
	end
	return keys
end

M.is_value_a_block = function(key)
	for node, name in key:parent():iter_children() do
		if name == "value" then
			if node:type() ~= "block_node" then
				return false
			else
				return node:child():type() ~= "block_scalar"
			end
		end
	end
	return true
end

M.all_keys = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "yaml")
	if not ok or not parser then
		return {}
	end

	local tree = parser:parse()[1]
	local root = tree:root()
	return get_keys(root)
end

M.get_key_relevant_to_cursor = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "yaml")
	if not ok then
		return nil
	end
	parser:parse()
	local node = vim.treesitter.get_node()
	while node ~= nil do
		if node:type() == "block_mapping_pair" then
			return node:field("key")[1]
		end
		node = node:parent()
	end
end

return M
