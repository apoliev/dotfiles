-- Filetype behaviour, ported from the old ~/.vimrc

-- Ruby: 2-space indent (everything else keeps the 4-space default)
vim.api.nvim_create_autocmd("Filetype", {
  pattern = "ruby",
  callback = function()
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})

-- Slim templates (vim-slim provides the syntax; make detection explicit)
vim.filetype.add({ extension = { slim = "slim" } })

-- Treesitter highlighting for every filetype that has a parser installed.
-- Buffers without one keep Neovim's regex highlighting (vim-ruby/vim-slim).
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang then
      return
    end
    -- Probe with language.add (raises for missing parsers). get_parser/start
    -- must not be used for the check: since nvim 0.12 they create parsers
    -- lazily and the "Parser could not be created" error escapes the pcall.
    if not pcall(vim.treesitter.language.add, lang) then
      return
    end
    pcall(vim.treesitter.start, args.buf)
  end,
})
