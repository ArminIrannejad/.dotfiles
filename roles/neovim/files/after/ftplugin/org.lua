vim.b.minihipatterns_disable = true
if _G.MiniHipatterns then _G.MiniHipatterns.disable(0) end

local undo = vim.b.undo_ftplugin
vim.b.undo_ftplugin = (undo and undo .. " | " or "") .. "unlet! b:minihipatterns_disable"
