-- VSCode-accurate diff (two-tier line+char highlighting, side-by-side/inline) as a
-- trial alongside diffview.nvim (<leader>gd). Own tab + explorer, so the two coexist.
-- Prebuilt C binary auto-downloads on first :CodeDiff -- no build step.
return {
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<leader>gC", "<cmd>CodeDiff<cr>", desc = "CodeDiff: changed files (VSCode-style)" },
    },
  },
}
