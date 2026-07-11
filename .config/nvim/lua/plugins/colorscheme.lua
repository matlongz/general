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
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "vscode" } },
}
