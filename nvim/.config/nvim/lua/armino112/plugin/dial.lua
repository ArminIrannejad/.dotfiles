return {
  "monaqa/dial.nvim",
  version = "*",

  keys = {
    { "<C-a>",  function() require("dial.map").manipulate("increment", "normal")  end, mode = "n", desc = "Dial increment" },
    { "<C-x>",  function() require("dial.map").manipulate("decrement", "normal")  end, mode = "n", desc = "Dial decrement" },
    { "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, mode = "n", desc = "Dial g-increment" },
    { "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, mode = "n", desc = "Dial g-decrement" },

    -- V and VB mode
    { "<C-a>",  function() require("dial.map").manipulate("increment", "visual")  end, mode = "x", desc = "Dial increment (visual)" },
    { "<C-x>",  function() require("dial.map").manipulate("decrement", "visual")  end, mode = "x", desc = "Dial decrement (visual)" },
    { "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, mode = "x", desc = "Dial g-increment (visual)" },
    { "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, mode = "x", desc = "Dial g-decrement (visual)" },
  },

  config = function()
    local augend = require("dial.augend")

    require("dial.config").augends:register_group({
      default = {
        augend.integer.alias.decimal,
        augend.integer.alias.hex,
        augend.date.alias["%Y-%m-%d"],
        augend.constant.new({ elements = { "true", "false" }, word = true, cyclic = true }), -- Enum a
        augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }),
        --augend.constalt.alias.bool this should work but the above one does the job atm
      },
    })
  end,
}

