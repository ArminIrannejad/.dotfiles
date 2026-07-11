vim.loader.enable()
local ui2_ok, ui2 = pcall(require, "vim._core.ui2")
if ui2_ok then
  ui2.enable({})
end
require("armino112")
