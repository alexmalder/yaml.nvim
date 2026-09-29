local stub = require("luassert.stub")

local set_yaml = function(lines)
	vim.cmd(":enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.cmd("set ft=yaml")
end

local buffer_lines = function()
	return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("Sorting YAML keys:", function()
	after_each(function()
		vim.cmd(":bw!")
	end)

	it("sorts top-level keys", function()
		set_yaml({
			"banana: yellow",
			"apple: red",
			"cherry: dark",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"apple: red",
			"banana: yellow",
			"cherry: dark",
		}, buffer_lines())
	end)

	it("sorts nested keys recursively", function()
		set_yaml({
			"zebra: animal",
			"car:",
			"  wheel: 4",
			"  brand: vw",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"car:",
			"  brand: vw",
			"  wheel: 4",
			"zebra: animal",
		}, buffer_lines())
	end)

	it("sorts only the current node and sub-nodes, not parents", function()
		set_yaml({
			"zoo:",
			"  lion: 1",
			"  ape: 2",
			"car:",
			"  wheel: 4",
			"  brand: vw",
		})
		vim.api.nvim_win_set_cursor(0, { 2, 2 })
		require("yaml_nvim").sort()
		assert.are.same({
			"zoo:",
			"  ape: 2",
			"  lion: 1",
			"car:",
			"  wheel: 4",
			"  brand: vw",
		}, buffer_lines())
	end)

	it("sorts within the key under the cursor, not its siblings", function()
		set_yaml({
			"zoo:",
			"  lion: 1",
			"  ape: 2",
			"car:",
			"  wheel: 4",
			"  brand: vw",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"zoo:",
			"  ape: 2",
			"  lion: 1",
			"car:",
			"  wheel: 4",
			"  brand: vw",
		}, buffer_lines())
	end)

	it("keeps sequence order but sorts mappings inside items", function()
		set_yaml({
			"matches:",
			"  - home: 1",
			"    away: 7",
			"  - score: 3",
			"    goals: 0",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"matches:",
			"  - away: 7",
			"    home: 1",
			"  - goals: 0",
			"    score: 3",
		}, buffer_lines())
	end)

	it("moves comments together with the key below them", function()
		set_yaml({
			"banana: yellow",
			"# apples are red",
			"apple: red",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"# apples are red",
			"apple: red",
			"banana: yellow",
		}, buffer_lines())
	end)

	it("moves consecutive comments together with the key below them", function()
		set_yaml({
			"banana: yellow",
			"# apples are red",
			"# and tasty",
			"apple: red",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"# apples are red",
			"# and tasty",
			"apple: red",
			"banana: yellow",
		}, buffer_lines())
	end)

	it("moves block scalar values intact", function()
		set_yaml({
			"intro: |",
			"  two",
			"  lines",
			"answer: 42",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"answer: 42",
			"intro: |",
			"  two",
			"  lines",
		}, buffer_lines())
	end)

	it("keeps blank lines attached to the key above them", function()
		set_yaml({
			"banana: yellow",
			"",
			"apple: red",
		})
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"apple: red",
			"banana: yellow",
			"",
		}, buffer_lines())
	end)

	it("is stable for duplicated keys", function()
		set_yaml({
			"banana: yellow",
			"apple: red",
			"apple: green",
		})
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		require("yaml_nvim").sort()
		assert.are.same({
			"apple: red",
			"apple: green",
			"banana: yellow",
		}, buffer_lines())
	end)

	it("ignores filetypes that are not YAML", function()
		vim.cmd(":enew")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "b = 2", "a = 1" })
		vim.cmd("set ft=lua")
		require("yaml_nvim").sort()
		assert.are.same({ "b = 2", "a = 1" }, buffer_lines())
	end)
end)

describe("YAMLSort command:", function()
	before_each(function()
		vim.cmd("set ft=yaml")
	end)

	after_each(function()
		vim.cmd(":bw!")
	end)

	it("calls Lua function", function()
		local sort = stub(require("yaml_nvim"), "sort")
		vim.cmd("YAMLSort")
		assert.stub(sort).was_called_with()
	end)
end)
