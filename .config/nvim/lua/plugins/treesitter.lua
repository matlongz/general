-- sql: highlighting only — lang.sql extra deliberately NOT enabled (edit-only need;
-- the extra pulls the vim-dadbod DB-client stack).
-- htmldjango: pairs with the filetype rule in config/options.lua.
return {
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "sql", "htmldjango" } } },
}
