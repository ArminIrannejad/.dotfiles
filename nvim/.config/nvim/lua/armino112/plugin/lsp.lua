return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "stevearc/conform.nvim",
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/nvim-cmp",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    --"j-hui/fidget.nvim",
  },

  config = function()
    require("conform").setup({
      formatters_by_ft = {
        json = { "prettier", stop_on_first = true, name = "dprint" },
        jsonc = { "prettier", stop_on_first = true, name = "dprint" },
        haskell = { "ormolu" },
        marksdown = { "marksman" },
      }
    })

    local cmp          = require("cmp")
    local cmp_lsp      = require("cmp_nvim_lsp")
    local capabilities = vim.tbl_deep_extend(
      "force", {},
      vim.lsp.protocol.make_client_capabilities(),
      cmp_lsp.default_capabilities()
    )
    vim.lsp.config("ocamllsp", {
      cmd = { "ocamllsp" }, -- found via PATH from opam I hope
      capabilities = capabilities,
    })
    vim.lsp.enable("ocamllsp")

    --require("fidget").setup({})
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "pyright" },
      automatic_enable = {
        exclude = { "hls" }, -- haskell-tools will start hls
      }
    })

    vim.lsp.config("pyright", {
      capabilities = capabilities,
      settings = {
        python = {
          analysis = {
            autoSearchPaths        = true,
            useLibraryCodeForTypes = true,
            diagnosticMode         = "workspace",
            completeFunctionCalls  = true,
          },
        },
      },
    })
    vim.lsp.enable("pyright")

    vim.lsp.config("lua_ls", {
      capabilities = capabilities,
      settings = {
        Lua = {
          runtime = {
            version = "LuaJIT",
            path    = vim.split(package.path, ";"),
          },
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library         = vim.api.nvim_get_runtime_file("", true),
            checkThirdParty = false,
          },
          telemetry = { enable = false },
        },
      },
    })
    vim.lsp.enable("lua_ls")

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    cmp.setup({
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-p>"]     = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"]     = cmp.mapping.select_next_item(cmp_select),
        ["<C-y>"]     = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
      }),
      sources = cmp.config.sources(
        { { name = "nvim_lsp" }, { name = "luasnip" } },
        { { name = "buffer" } }
      ),
    })

    vim.diagnostic.config({
      virtual_text     = false,
      signs            = true,
      underline        = true,
      update_in_insert = false,
      float            = {
        focusable = true,
        border    = "rounded",
        header    = "",
        prefix    = "",
      },
    })

    -- vim.keymap.set("n", "<leader>er", vim.diagnostic.open_float, { desc = "Show diagnostic" })
    vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
      end,
    })

    local toggle_virt_lines = false

    local function toggle_virt()
      toggle_virt_lines = not toggle_virt_lines

      if toggle_virt_lines then
        vim.diagnostic.config({
          virtual_lines = true,
        })
      else
        vim.diagnostic.config({
          virtual_lines = false,
        })
      end
    end

    vim.keymap.set("n", "<leader>er", toggle_virt)
  end
}
