-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>r", function()
  vim.cmd(
    "TermExec cmd='cd /d-matrix/software/dynamix && ./build/bin/dynamix --dlir-to-qjson examples/DLIR/dlir_example.dlir.mlir' direction=float"
  )
end, {
  noremap = true,
  silent = true,
  desc = "Run dynamix --dlir-to-qjson",
})

vim.keymap.set("n", "<leader>a", function()
  vim.cmd(
    "TermExec cmd='cd /d-matrix/software/dynamix && cmake --build build -j9 && ./build/bin/dynamix --dlir-to-qjson examples/DLIR/dlir_example.dlir.mlir' direction=float"
  )
end, {
  noremap = true,
  silent = true,
  desc = "Build and run dynamix",
})
