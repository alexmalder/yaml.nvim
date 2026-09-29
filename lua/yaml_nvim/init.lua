local has_snacks, snacks = pcall(require, "snacks")
local has_telescope, telescope = pcall(require, "telescope.builtin")
local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
local document = require("yaml_nvim.document")
local pair = require("yaml_nvim.pair")
local sort = require("yaml_nvim.sort")

local M = {}
local parser_exists = false

local has_parser = function()
	if parser_exists then
		return true
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "yaml")
	if not ok or not parser then
		vim.notify("yaml.nvim: tree-sitter-yaml parser not found", vim.log.levels.ERROR)
		return false
	end

	parser_exists = true
	return true
end

local is_yaml = function()
	local curr = vim.bo.filetype
	for _, ft in ipairs(M.config.ft) do
		if curr == ft then
			return true
		end
	end

	return false
end

local get_current_yaml_node = function()
	if not is_yaml() then
		return
	end

	if not has_parser() then
		return
	end

	local node = document.get_key_relevant_to_cursor()
	if node == nil then
		return
	end

	return pair.parse(node)
end

local yank = function(node, key, value, register)
	if node == nil then
		return
	end

	register = register or [["]]
	if not key and not value then
		return
	end

	local contents = ""
	if key and value then
		contents = node.human
	elseif key then
		contents = node.key
	elseif value then
		contents = node.cleaned_value
	end

	contents = string.gsub(contents, "'", "''")
	contents = string.gsub(contents, "\n", ", ")
	contents = string.gsub(contents, "\r", "")
	vim.fn.setreg(register, contents)
end

-- Public API

M.default_config = {
	ft = { "yaml", "eruby.yaml" },
}

M.config = vim.deepcopy(M.default_config)

M.setup = function(opts)
	if opts == nil then
		return
	end

	for k, _ in pairs(M.default_config) do
		local custom = opts[k]
		if custom ~= nil then
			M.config[k] = custom
		end
	end
end

M.view = function()
	local node = get_current_yaml_node()
	if node == nil then
		return
	end

	vim.notify(node.human)
end

M.get_yaml_key_and_value = function()
	local node = get_current_yaml_node()
	if node == nil then
		return
	end

	return node.human
end

M.get_yaml_key = function()
	local node = get_current_yaml_node()
	if node == nil then
		return
	end
	return node.key
end

M.yank = function(register)
	yank(get_current_yaml_node(), true, true, register)
end

M.yank_key = function(register)
	yank(get_current_yaml_node(), true, false, register)
end

M.yank_value = function(register)
	yank(get_current_yaml_node(), false, true, register)
end

M.current_highlight = nil

M.highlight = function(key)
	if not is_yaml() then
		return
	end

	if not has_parser() then
		return
	end

	local target = nil
	for _, node in pairs(document.all_keys()) do
		if not document.is_value_a_block(node) then
			local parsed = pair.parse(node)
			if parsed.key == key then
				target = parsed
				break
			end
		end
	end
	if target == nil then
		vim.notify(key .. " not found")
		return
	end

	local pattern = "\\%" .. target.lines[1] .. "l"
	if target.lines[2] > target.lines[1] then
		pattern = "\\%>" .. target.lines[1] .. "l\\%<" .. target.lines[2] .. "l"
	end

	M.remove_highlight()
	M.current_highlight = vim.fn.matchadd("Visual", pattern)
end

M.remove_highlight = function()
	if M.current_highlight == nil then
		return
	end

	vim.fn.matchdelete(M.current_highlight)
	M.current_highlight = nil
end

M.sort = function()
	if not is_yaml() then
		return
	end

	if not has_parser() then
		return
	end

	sort.sort()
end

M.quickfix = function()
	if not is_yaml() then
		return false
	end

	if not has_parser() then
		return false
	end

	local lines = {}
	for _, key in pairs(document.all_keys()) do
		if not document.is_value_a_block(key) then
			local parsed = pair.parse(key)
			table.insert(lines, parsed.quickfix)
		end
	end

	vim.fn.setqflist(lines)
	return true
end

M.snacks = function()
	if not has_snacks then
		return
	end

	if M.quickfix() then
		snacks.picker.qflist()
	end
end

M.telescope = function()
	if not has_telescope then
		return
	end

	if M.quickfix() then
		telescope.quickfix()
	end
end

M.fzf_lua = function()
	if not has_fzf_lua then
		return
	end

	if M.quickfix() then
		fzf_lua.quickfix()
	end
end

-- Commands

vim.cmd("command! YAMLView lua require('yaml_nvim').view()")
vim.cmd("command! -nargs=? YAMLYank lua require('yaml_nvim').yank(<f-args>)")
vim.cmd("command! -nargs=? YAMLYankKey lua require('yaml_nvim').yank_key(<f-args>)")
vim.cmd("command! -nargs=? YAMLYankValue lua require('yaml_nvim').yank_value(<f-args>)")
vim.cmd("command! -nargs=? YAMLHighlight lua require('yaml_nvim').highlight(<f-args>)")
vim.cmd("command! YAMLRemoveHighlight lua require('yaml_nvim').remove_highlight()")
vim.cmd("command! YAMLQuickfix lua require('yaml_nvim').quickfix()")
vim.cmd("command! YAMLSort lua require('yaml_nvim').sort()")

if has_snacks then
	vim.cmd("command! YAMLSnacks lua require('yaml_nvim').snacks()")
end

if has_telescope then
	vim.cmd("command! YAMLTelescope lua require('yaml_nvim').telescope()")
end

if has_fzf_lua then
	vim.cmd("command! YAMLFzfLua lua require('yaml_nvim').fzf_lua()")
end

return M
