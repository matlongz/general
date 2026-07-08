#!/bin/sh
# THE Mason tool manifest — exact versions only, frozen at the first validated
# macOS install (2026-07-08). lazy-lock.json pins plugins; THIS pins Mason tools.
# Run order matters (see README): after `nvim --headless "+Lazy! restore" +qa`,
# BEFORE the first interactive nvim launch.
# Upgrades: bump versions here deliberately, validate, commit — never implicitly.
set -e
nvim --headless "+Lazy load mason.nvim" "+MasonInstall --force \
  pyright@1.1.411 \
  ruff@0.15.20 \
  vtsls@0.3.0 \
  yaml-language-server@1.23.0 \
  json-lsp@4.10.0 \
  marksman@2026-02-08 \
  bash-language-server@5.6.0 \
  prettier@3.9.4 \
  markdownlint-cli2@0.23.0 \
  markdown-toc@1.2.0 \
  shfmt@v3.13.1 \
  stylua@v2.5.2 \
  tree-sitter-cli@v0.26.10" +qa
echo "mason manifest installed"
