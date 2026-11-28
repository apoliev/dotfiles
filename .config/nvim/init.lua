-- Neovim entry point. Plugins live in lua/plugins/, shared config in
-- lua/config/. Requires nvim >= 0.11 (vim.lsp.config/enable API); older
-- builds get a minimal fallback so `nvim` still works on stale hosts.
if vim.fn.has("nvim-0.11") == 0 then
  vim.opt.number = true
  vim.opt.expandtab = true
  vim.cmd("syntax enable")
  vim.notify("nvim >= 0.11 is required for the full config — minimal fallback loaded", vim.log.levels.WARN)
  return
end

-- Leader must be set before plugins load
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

-- neo-tree replaces netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Bootstrap lazy.nvim (clones once into ~/.local/share/nvim/lazy/lazy.nvim;
-- plugin state never lands in this repo)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  change_detection = { notify = false },
})
