-- Treesitter: AST highlighting + parsing. The `main` branch is a full
-- rewrite that requires nvim >= 0.12 and `tree-sitter` CLI (both come from
-- mise); older nvim builds keep regex highlighting (see init.lua).
return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false, -- the plugin does not support lazy-loading
  build = ":TSUpdate",
  enabled = function()
    return vim.fn.has("nvim-0.12") == 1
  end,
  config = function()
    -- First run compiles every parser (needs a C compiler + make); repeated
    -- runs are no-ops. Blocking keeps nvim/install.sh deterministic.
    local ok, err = pcall(function()
      require("nvim-treesitter").install({
        "bash", "css", "go", "html", "javascript", "json", "lua",
        "markdown", "markdown_inline", "python", "ruby", "tsx",
        "typescript", "vim", "vimdoc", "yaml", "zsh",
      }):wait(300000)
    end)
    if not ok then
      vim.notify("treesitter parsers: " .. err, vim.log.levels.WARN)
    end
  end,
}
