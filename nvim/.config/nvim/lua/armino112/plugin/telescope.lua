return {
	{
		"nvim-telescope/telescope.nvim",

		tag = "0.1.8",

		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		config = function()
			require("telescope").setup {
				pickers = {
					find_files = {
						theme = "ivy"
					},
                    colorscheme = {
                        enable_preview = true
                    }
				},
				extensions = {
					fzf = {}
				}
			}

			require("telescope").load_extension("fzf")
			vim.keymap.set("n", "<leader>ff", require("telescope.builtin").find_files)
			vim.keymap.set("n", "<leader>fh", require("telescope.builtin").help_tags)
			vim.keymap.set("n", "<leader>th", require("telescope.builtin").colorscheme)
			vim.keymap.set("n", "<leader>en", function()
				require("telescope.builtin").find_files {
					cwd = vim.fn.stdpath("config")
				}
			end)
			vim.keymap.set("n", "<leader>ep", function()
				require("telescope.builtin").find_files {
					cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
				}
			end)
			require "armino112.telescope.multigrep".setup()
		end
	}
}

