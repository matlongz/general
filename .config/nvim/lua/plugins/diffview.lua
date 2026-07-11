-- Side-by-side git diff (VSCode diff-editor replacement).
-- Boundaries: diffview = review surface; gitsigns = in-buffer hunks; lazygit = actions.
return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
      { "<leader>gD", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
    },
    -- Per-window diff colours (deletions red left, additions green right, neutral
    -- filler) like VSCode, instead of vanilla vim diff. Colours tuned in plugins/colorscheme.lua.
    opts = {
      enhanced_diff_hl = true,
    },
  },
}
