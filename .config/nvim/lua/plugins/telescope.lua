-- Telescope: fuzzy finder (fzf-native for speed, built with make)
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    -- the same maps the old fzf.vim config had
    { "<C-p>", function() require("telescope.builtin").find_files() end, desc = "Find files" },
    { "<C-w>f", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
    { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
    { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        path_display = { "truncate" },
      },
    })
    telescope.load_extension("fzf")
  end,
}
