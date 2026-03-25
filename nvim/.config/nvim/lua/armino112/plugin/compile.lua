return {
  "ej-shafran/compile-mode.nvim",
  version = "^5.0.0",
  -- you can just use the latest version:
  -- branch = "latest",
  -- or the most up-to-date updates:
  -- branch = "nightly",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- if you want to enable coloring of ANSI escape codes in
    -- compilation output, add:
    -- { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  config = function()
---@module "compile-mode"
---@type CompileModeOpts
vim.g.compile_mode = {
    -- The string to show in the compile prompt as a default.
    -- For an empty prompt, you can use:
    -- default_command = "",
    -- To use different defaults based on filetype, you can use a table:
    default_command = {
      python = "python %",
      lua = "lua %",
      c = "cc -o %:r % && time ./%:r",
      -- cpp = "cc -std=c++23 -o %:r % && ./%:r",
      -- java = "javac % && java %:r",
      go = "go run %",
      haskell = "ghc -o %:r % && time ./%:r"
    },
    -- A function which returns the default command string is also supported:
    -- default_command = function()
    --   local filetype = vim.bo.filetype
    --   if filetype == "python" then
    --     return "python %"
    --   else
    --     return "make -k "
    --   end
    -- end,
    -- :h compile_mode.default_command
    -- default_command = "make -k ",
    -- Use `baleia` for parsing ANSI escape codes in the output.
    -- :h compile_mode.baleia_setup
    baleia_setup = false,
    -- Expand commands, like `:!` (e.g. `:Compile echo %`)
    -- :h compile_mode.bang_expansion
    bang_expansion = true,
    -- Configure additional error regexes.
    -- :h compile-mode-errors
    error_regexp_table = {},
    -- List of filename regexes to ignore errors from.
    -- :h compile-mode.error_ignore_file_list
    error_ignore_file_list = {},
    -- The minimum error level to jump to.
    -- :h compile-mode.error_threshold
    error_threshold = require("compile-mode").level.WARNING,
    -- Automatically jump to the first error.
    -- :h compile-mode.auto_jump_to_first_error
    auto_jump_to_first_error = false,
    -- How long to highlight an error's location when jumping to it.
    -- :h compile-mode.error_locus_highlight
    error_locus_highlight = 500,
    -- Use Neovim diagnostics instead of opening the compilation buffer.
    -- :h compile-mode.use_diagnostics
    use_diagnostics = false,
    -- Default to calling `:Compile` for `:Recompile`
    -- when there's no previous command.
    -- :h compile-mode.recompile_no_fail
    recompile_no_fail = false,
    -- Ask to save unsaved buffers before compiling.
    -- :h compile-mode.ask_about_save
    ask_about_save = true,
    -- Ask to interrupt already running commands.
    -- :h compile-mode.ask_to_interrupt
    ask_to_interrupt = true,
    -- The name for the compilation buffer.
    -- :h compile-mode.buffer_name
    buffer_name = "*compilation*",
    -- The format for the time information
    -- at the top of the compilation buffer
    -- :h compile-mode.time_format
    time_format = "%a %b %e %H:%M:%S",
    -- List of regexes to hide from the output.
    -- :h compile-mode.hidden_output
    hidden_output = {},
    -- A table of environment variables to pass to commands.
    -- :h compile-mode.environment
    environment = nil,
    -- Clear all environment variables for each command.
    -- :h compile-mode.clear_environment
    clear_environment = false,
    -- Fix compilation for plugins like `nvim-cmp`.
    -- :h compile-mode.input_word_completion
    input_word_completion = false,
    -- Hide the compliation buffer.
    -- :h compile-mode.hidden_buffer
    hidden_buffer = false,
    -- Automatically focus the compilation buffer.
    -- :h compile-mode.focus_compilation_buffer
    focus_compilation_buffer = false,
    -- Automatically move the cursor to the end of the compilation buffer.
    -- :h compile-mode.auto_scroll
    auto_scroll = true,
    -- Jump back past the end/beginning of the errors
    -- with `:NextError`/`:PrevError`
    -- :h compile-mode.use_circular_error_navigation
    use_circular_error_navigation = false,
    -- Print debug information.
    -- :h compile-mode.debug
    debug = false,
    -- Use a pseudo terminal for command execution.
    -- :h compile-mode.use_pseudo_terminal
    use_pseudo_terminal = false,
}
  end
}
