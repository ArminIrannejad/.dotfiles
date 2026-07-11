vim.pack.add({
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/stevearc/conform.nvim" },
  { src = "https://github.com/williamboman/mason.nvim" },
  { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
  { src = "https://github.com/Saghen/blink.cmp",                 version = vim.version.range("1.*") },
  { src = "https://github.com/L3MON4D3/LuaSnip" },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
  -- SQL table-name dictionary completion
  { src = "https://github.com/Kaiser-Yang/blink-cmp-dictionary" },

  -- { src = "https://github.com/j-hui/fidget.nvim" },
})

require("conform").setup({
  formatters_by_ft = {
    -- haskell = { "ormolu" },
    json = { "prettier" },
    jsonc = { "prettier" },
    yaml = { "prettier" },
  },
})

require("blink.cmp").setup({
  fuzzy = {
    implementation = "prefer_rust",
  },

  completion = {
    menu = {
      auto_show = true,
      draw = {
        columns = {
          { "label",     "label_description", gap = 2 },
          { "kind_icon", "kind",              gap = 1 },
        },
      },
    },

    documentation = {
      auto_show = true,
    },

    ghost_text = {
      enabled = false,
      show_with_menu = false,
    },

    accept = {
      auto_brackets = {
        enabled = true,
      },
    },
  },

  cmdline = {
    enabled = true,
    keymap = {
      preset = "cmdline",
    },
    completion = {
      menu = {
        auto_show = false,
      },
    },
  },

  sources = {
    default = { "lsp", "path", "buffer", "snippets" },

    per_filetype = {
      sql = { "lsp", "path", "buffer", "snippets", "dictionary" },
    },

    providers = {
      dictionary = {
        module = "blink-cmp-dictionary",
        name = "DB Tables",
        min_keyword_length = 1,
        opts = {
          dictionary_files = vim.tbl_filter(function(path)
            return vim.fn.filereadable(path) == 1
          end, {
            vim.fn.expand("~/.config/nvim/dictionary/databricks_tables.txt"),
            vim.fn.stdpath("state") .. "/dictionary/databricks_tables.txt",
          }),
          force_fallback = true,
        },
      },
    },
  },

  appearance = {
    nerd_font_variant = "mono",
  },

  signature = {
    enabled = true,
  },
})

local capabilities = require("blink.cmp").get_lsp_capabilities()

require("mason").setup()

require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",
    "basedpyright",
    "ruff",
    "tflint",
  },
  automatic_enable = {
    exclude = {
      "hls",
    },
  },
})

vim.lsp.config("ocamllsp", {
  cmd = { "ocamllsp" },
  capabilities = capabilities,
})

vim.lsp.enable("ocamllsp")

vim.lsp.config("basedpyright", {
  capabilities = capabilities,
  settings = {
    python = {
      pythonPath = vim.fn.getcwd() .. "/.venv/bin/python",
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        completeFunctionCalls = true,
      },
    },
  },
})

vim.lsp.config("lua_ls", {
  capabilities = capabilities,

  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
        path = vim.split(package.path, ";"),
      },

      diagnostics = {
        globals = { "vim" },
      },

      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },

      telemetry = {
        enable = false,
      },
    },
  },
})

vim.lsp.config("tflint", {
  cmd = { "tflint", "--langserver" },
  filetypes = { "terraform", "terraform-vars" },
  root_markers = { ".terraform", ".git", "*.tfvars", ".tflint.hcl" },
  capabilities = capabilities,
})
vim.lsp.enable("tflint")

vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = false,
  signs = true,
  underline = true,
  update_in_insert = false,

  float = {
    focusable = true,
    border = "rounded",
    header = "",
    prefix = "",
  },
})

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {
  desc = "Diagnostics to loclist",
})

local virtual_lines_enabled = false

vim.keymap.set("n", "<leader>er", function()
  virtual_lines_enabled = not virtual_lines_enabled
  vim.diagnostic.config({
    virtual_lines = virtual_lines_enabled,
  })
end, {
  desc = "Toggle diagnostic virtual lines",
})
