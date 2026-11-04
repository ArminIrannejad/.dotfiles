vim.pack.add({
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/stevearc/conform.nvim" },
  { src = "https://github.com/williamboman/mason.nvim" },
  { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
  { src = "https://github.com/Saghen/blink.cmp",                 version = vim.version.range("1.*") },
  { src = "https://github.com/L3MON4D3/LuaSnip" },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
  -- { src = "https://github.com/j-hui/fidget.nvim" },
})

require("conform").setup({
  formatters_by_ft = {
    -- haskell = { "ormolu" },
    json = { "prettier" },
    jsonc = { "prettier" },
    yaml = { "prettier" },
    plsql = { "sqlcl" }, -- sql joins in from dbee/plsql.lua while on oracle
  },

  formatters = {
    -- oracle's own formatter, the one sql developer uses. it only formats files,
    -- so round trip the buffer through one, and never hand back an empty result
    sqlcl = {
      command = "sh",
      args = {
        "-c",
        [[f=$(mktemp --suffix=.sql) && cat > "$f" &&
          printf 'format file "%s" "%s.out"\nexit\n' "$f" "$f" | sql -S /nolog >/dev/null 2>&1;
          [ -s "$f.out" ] && cat "$f.out"; s=$?; rm -f "$f" "$f.out"; exit $s]],
      },
      stdin = true,
      condition = function()
        return vim.fn.executable("sql") == 1
      end,
    },
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
      sql = { "dbee", "lsp", "path", "buffer", "snippets" },
    },

    providers = {
      dbee = {
        name = "dbee",
        module = "blink.compat.source",
        score_offset = 100,
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

-- formatters/linters mason-lspconfig won't handle
require("mason-registry").refresh(function()
  for _, tool in ipairs({ "prettier" }) do
    local pkg = require("mason-registry").get_package(tool)
    if not pkg:is_installed() then
      pkg:install()
    end
  end
end)

require("mason-lspconfig").setup({
  ensure_installed = {
    "basedpyright",
    "clangd",
    "gopls",
    "jsonls",
    "lua_ls",
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

vim.lsp.config("jsonls", {
  capabilities = capabilities,

  init_options = {
    provideFormatter = false,
  },
})

vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = false,
  signs = true,
  underline = false,
  update_in_insert = false,

  float = {
    focusable = true,
    border = "rounded",
    header = "",
    prefix = "",
  },
})


vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to def" })
vim.keymap.set("n", "<leader>eq", vim.diagnostic.setloclist, {
  desc = "Diagnostics to loclist",
})

vim.keymap.set("n", "<leader>eQ", vim.diagnostic.setqflist, {
  desc = "Workspace diagnostics to quickfix",
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
