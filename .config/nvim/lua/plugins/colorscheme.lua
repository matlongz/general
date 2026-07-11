-- VSCode Dark Modern colorscheme (Mofiqul/vscode.nvim ports Dark+; nudged toward Dark Modern).
return {
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      italic_comments = false, -- Dark Modern comments are upright, not italic
      color_overrides = {
        vscBack = "#1f1f1f", -- Dark Modern background (Dark+ port defaults to #1e1e1e)
      },
      group_overrides = {
        -- VSCode Dark Modern diff colours, composited over #1f1f1f (no alpha in
        -- nvim highlights). DiffDelete feeds diffview's deletion group.
        DiffDelete = { bg = "#4c1919" }, -- diffEditor.removedLineBackground
        -- Filler hatch; diffview only default-links this to Comment, so an
        -- explicit def wins.
        DiffviewDiffDeleteDim = { fg = "#424242", bg = "NONE" }, -- diffEditor.diagonalFill
      },
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "vscode" } },
}
