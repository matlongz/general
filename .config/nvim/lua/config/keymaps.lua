-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Horizontal trackpad scroll: iTerm2 forwards the wheel-left/right events, which
-- Neovim doesn't act on by default. Scroll four columns per notch.
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", "z4l", { silent = true })
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", "z4h", { silent = true })
