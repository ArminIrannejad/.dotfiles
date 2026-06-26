vim.pack.add({
    {
        src = "https://github.com/jake-stewart/multicursor.nvim",
    },
})

local mc = require("multicursor-nvim")
mc.setup()

local set = vim.keymap.set

set({ "n", "x" }, "Q", mc.toggleCursor)

-- set({ "n", "x" }, "<M-k>", function() mc.lineAddCursor(-1) end)
-- set({ "n", "x" }, "<M-j>", function() mc.lineAddCursor(1) end)

-- Mouse support
-- set("n", "<c-leftmouse>", mc.handleMouse)
-- set("n", "<c-leftdrag>", mc.handleMouseDrag)
-- set("n", "<c-leftrelease>", mc.handleMouseRelease)

-- Multicursor-only keymaps
mc.addKeymapLayer(function(layerSet)
    -- layerSet({ "n", "x" }, "<left>", mc.prevCursor)
    -- layerSet({ "n", "x" }, "<right>", mc.nextCursor)
    -- layerSet({ "n", "x" }, "<leader>x", mc.deleteCursor)

    layerSet("n", "<esc>", function()
        if not mc.cursorsEnabled() then
            mc.enableCursors()
        else
            mc.clearCursors()
        end
    end)
end)

local hl = vim.api.nvim_set_hl
-- hl(0, "MultiCursorCursor", { reverse = true })
hl(0, "MultiCursorCursor", { bg = "#ff2222", fg = "#1e1e1e" })
hl(0, "MultiCursorVisual", { bg = "#ff2222", fg = "#1e1e1e" })
hl(0, "MultiCursorSign", { link = "SignColumn" })
hl(0, "MultiCursorMatchPreview", { link = "Search" })
hl(0, "MultiCursorDisabledCursor", { bg = "#ff2222", fg = "#1e1e1e" })
hl(0, "MultiCursorDisabledVisual", { bg = "#ff2222", fg = "#1e1e1e" })
hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
