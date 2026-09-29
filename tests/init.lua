-- In Nixery (container test and CI) fzf-lua fails to load with LuaJIT 5.1 (the
-- version in the Nix package), but it is something we can ignore for simple
-- tests.
if vim.fn.isdirectory("/nix/store") == 1 then
	_VERSION = "Lua 5.2"
end

local install_from_github = function(uri)
	local repo = string.gsub(uri, "^[^/]+/", "")
	local name = string.gsub(repo, "%p?nvim%p?", "")
	local env = string.upper(name) .. "_DIR"
	local dir = os.getenv(env)
	if dir == nil then
		dir = "/tmp/" .. repo
	end

	if vim.fn.isdirectory(dir) == 0 then
		print(vim.fn.system({ "git", "clone", "https://github.com/" .. uri, dir }))
	end

	vim.opt.rtp:append(dir)
	vim.cmd("runtime plugin/" .. repo)
end

local dependencies = {
	"folke/snacks.nvim",
	"ibhagwan/fzf-lua",
	"nvim-lua/plenary.nvim",
	"nvim-telescope/telescope.nvim",
	"nvim-treesitter/nvim-treesitter",
}
for _, dep in pairs(dependencies) do
	install_from_github(dep)
end

vim.opt.rtp:append(".")
vim.cmd("runtime plugin/yaml.vim")
vim.cmd("set noswapfile")

require("nvim-treesitter").install({ "yaml" }):wait()

-- The Nix Neovim package does not search the user data directory for
-- tree-sitter parsers. Ensure the standard path is searched so that parsers
-- installed by nvim-treesitter can be found.
if vim.fn.isdirectory("/nix/store") == 1 then
	vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")
end

require("plenary.busted")
