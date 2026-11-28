-- UI helpers: statusline, key hints, problems panel, TODO list,
-- symbols outline, terminal, autosave
return {
  -- Statusline (replaces lightline), with icons (Nerd Font in the terminal)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
      },
    },
  },

  -- Keybinding hints — press <leader> and wait
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Problems panel: diagnostics and TODO lists (VSCode-style)
  {
    "folke/trouble.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- TODO/FIXME highlighting and list (replaces todo-vim)
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim", "folke/trouble.nvim" },
    keys = {
      { "<F5>", "<cmd>TodoTrouble<cr>", desc = "TODO list" },
    },
    opts = {
      -- plain-text icons: readable in any terminal font
      keywords = {
        FIX = { icon = "F", color = "error" },
        TODO = { icon = "T", color = "info" },
        HACK = { icon = "H", color = "warning" },
        PERF = { icon = "P", color = "default" },
        NOTE = { icon = "N", color = "hint" },
        TEST = { icon = "S", color = "test" },
      },
    },
  },

  -- Symbols outline (replaces tagbar). Auto-detects nvim-web-devicons and
  -- uses Nerd Font symbol icons when it is installed.
  {
    "stevearc/aerial.nvim",
    keys = {
      { "<F8>", "<cmd>AerialToggle!<cr>", desc = "Symbols outline" },
    },
    opts = {},
  },

  -- Terminal panel
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
    opts = {
      direction = "float",
      float_opts = { border = "rounded" },
    },
  },

  -- Autosave (replaces vim-auto-save)
  {
    "okuuva/auto-save.nvim",
    event = { "InsertLeave", "TextChanged" },
    opts = {},
  },
}
