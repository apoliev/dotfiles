-- Editor options, ported from the old ~/.vimrc
local opt = vim.opt

opt.background = "dark"
opt.number = true
opt.cursorline = true

-- Indentation: 4 spaces everywhere (Ruby overrides to 2, see autocmds.lua)
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true

opt.showmatch = true
opt.showmode = false -- lualine shows the mode
opt.updatetime = 100
opt.incsearch = true
opt.hlsearch = true

-- Completion popup behaviour (rendered by nvim-cmp)
opt.completeopt = { "menuone", "noinsert" }

opt.termguicolors = true

-- Yank to the system clipboard. On a desktop session this uses xclip/wl-copy
-- (nvim's own provider detection). Over plain SSH (no DISPLAY) it falls back
-- to OSC 52: modern terminals apply the escape sequence to the local machine
-- clipboard, and tmux >= 3.3 forwards it when ~/.tmux.conf enables
-- `clipboard` in terminal-features.
opt.clipboard = "unnamedplus"
if not vim.env.DISPLAY or vim.env.DISPLAY == "" then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end
