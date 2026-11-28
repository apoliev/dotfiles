-- neo-tree: file explorer with git status (replaces NERDTree)
return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = { "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<C-o>", "<cmd>Neotree toggle<cr>", desc = "File tree" },
  },
  opts = {
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        -- NERDTree showed everything; keep that
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = { width = 30 },
  },
}
