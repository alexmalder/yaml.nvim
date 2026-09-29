local M = {}

local function node_end_row(node)
	local _, _, end_row, end_col = node:range()
	if end_col == 0 then
		return end_row - 1
	end
	return end_row
end

local function find_nested_mappings(node, found)
	for child, _ in node:iter_children() do
		if child:type() == "block_mapping" then
			table.insert(found, child)
		else
			find_nested_mappings(child, found)
		end
	end
end

local sort_mapping

local function apply_nested(node, bufnr, span_start, lines)
	local nested = {}
	find_nested_mappings(node, nested)
	for _, mapping in ipairs(nested) do
		local start_row, _, sorted = sort_mapping(mapping, bufnr)
		if sorted ~= nil then
			for i, line in ipairs(sorted) do
				lines[start_row - span_start + i] = line
			end
		end
	end
	return #nested > 0
end

sort_mapping = function(mapping, bufnr)
	local chunks = {}
	local pending = nil
	local prev_end = nil

	for child, _ in mapping:iter_children() do
		local kind = child:type()
		if kind == "block_mapping_pair" then
			local key_node = child:field("key")[1]
			local key = ""
			if key_node ~= nil then
				key = vim.treesitter.get_node_text(key_node, bufnr)
			end

			local start_row = child:start()
			if pending ~= nil and pending < start_row then
				start_row = pending
			end
			if prev_end ~= nil and start_row <= prev_end then
				start_row = prev_end + 1
			end

			table.insert(chunks, { key = key, index = #chunks + 1, start_row = start_row, pair = child })
			pending = nil
			prev_end = node_end_row(child)
		elseif kind == "comment" and pending == nil then
			pending = child:start()
		end
	end

	if #chunks == 0 then
		return nil
	end

	for i = 1, #chunks - 1 do
		chunks[i].end_row = chunks[i + 1].start_row - 1
	end
	chunks[#chunks].end_row = prev_end

	local span_start = chunks[1].start_row
	local span_end = chunks[#chunks].end_row
	local lines = vim.api.nvim_buf_get_lines(bufnr, span_start, span_end + 1, false)

	for _, chunk in ipairs(chunks) do
		apply_nested(chunk.pair, bufnr, span_start, lines)
	end

	for _, chunk in ipairs(chunks) do
		chunk.lines = {}
		for row = chunk.start_row, chunk.end_row do
			table.insert(chunk.lines, lines[row - span_start + 1])
		end
	end

	local _, start_col = mapping:start()
	local prefix = chunks[1].lines[1]:sub(1, start_col)
	local has_prefix = string.match(prefix, "%S") ~= nil
	if has_prefix then
		chunks[1].lines[1] = string.rep(" ", start_col) .. chunks[1].lines[1]:sub(start_col + 1)
	end

	table.sort(chunks, function(a, b)
		if a.key == b.key then
			return a.index < b.index
		end
		return a.key < b.key
	end)

	if has_prefix then
		local first = chunks[1].lines[1]
		if string.match(first:sub(1, start_col), "%S") ~= nil then
			return nil
		end
		chunks[1].lines[1] = prefix .. first:sub(start_col + 1)
	end

	local sorted = {}
	for _, chunk in ipairs(chunks) do
		for _, line in ipairs(chunk.lines) do
			table.insert(sorted, line)
		end
	end

	return span_start, span_end, sorted
end

local function sort_within(node, bufnr)
	local start_row = node:start()
	local end_row = node_end_row(node)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
	if not apply_nested(node, bufnr, start_row, lines) then
		return nil
	end
	return start_row, end_row, lines
end

M.sort = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local parser = vim.treesitter.get_parser(bufnr, "yaml")
	local root = parser:parse()[1]:root()

	local pair = vim.treesitter.get_node()
	while pair ~= nil and pair:type() ~= "block_mapping_pair" do
		pair = pair:parent()
	end

	local start_row, end_row, lines
	if pair == nil then
		start_row, end_row, lines = sort_within(root, bufnr)
	else
		local nested = {}
		find_nested_mappings(pair, nested)
		if #nested > 0 then
			start_row, end_row, lines = sort_within(pair, bufnr)
		elseif pair:parent() ~= nil then
			start_row, end_row, lines = sort_mapping(pair:parent(), bufnr)
		end
	end

	if lines == nil then
		vim.notify("yaml.nvim: no YAML mapping to sort", vim.log.levels.WARN)
		return
	end

	vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, lines)
end

return M
