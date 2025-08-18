-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>r", function()
  vim.cmd(
    "TermExec cmd='cd /workspace && ./build/bin/baremetalai example.mlir' direction=float"
  )
end, {
  noremap = true,
  silent = true,
  desc = "Run baremetalai",
})

vim.keymap.set("n", "<leader>a", function()
  vim.cmd(
    "TermExec cmd='cd /workspace && cmake --build build -j9 && ./build/bin/baremetalai example.dlir.mlir' direction=float"
  )
end, {
  noremap = true,
  silent = true,
  desc = "Build and run baremetalai",
})
