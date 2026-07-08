-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- The raw Linux console (TERM=linux) renders PSF bitmap fonts capped at ~256
-- glyphs, so Nerd Font icons (thousands of Private-Use-Area glyphs) can't display
-- there regardless of installed fonts. Fall back to ASCII in that case; every real
-- terminal emulator keeps full icons. Set before lazy.nvim reads it.
vim.g.have_nerd_font = vim.env.TERM ~= "linux"

-- Django templates: content-based detection misses templates without {% %} near the
-- top, so classify by path (Lua pattern, not glob). Pairs with the htmldjango
-- treesitter parser in plugins/treesitter.lua.
vim.filetype.add({
  pattern = {
    [".*/templates/.*%.html"] = "htmldjango",
  },
})

-- Over SSH (the Debian-remote case) route yanks to the local clipboard via the
-- terminal (OSC 52). Local sessions keep the native provider (pbcopy/wl-clipboard).
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end
