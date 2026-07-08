-- Graph guard: keep lang.python's pyright/ruff wiring, drop its debugger/test/venv
-- baggage (no-DAP decision; venv discovery is pyright-native via .venv).
-- Stubs are no-ops if the extra never activates these.
return {
  { "mfussenegger/nvim-dap-python", enabled = false },
  { "nvim-neotest/neotest-python", enabled = false },
  { "linux-cultist/venv-selector.nvim", enabled = false },
}
