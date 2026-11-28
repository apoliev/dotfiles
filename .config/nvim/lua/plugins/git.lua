-- Git integration
return {
  -- Gutter diff signs, hunk staging (replaces vim-gitgutter)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end
        -- pass ]c/[c through to vim's diff navigation in diff mode
        map("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, "next hunk")
        map("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, "previous hunk")
        map("n", "<leader>hs", gs.stage_hunk, "stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "reset hunk")
        map("n", "<leader>hp", gs.preview_hunk, "preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "blame line")
      end,
    },
  },

  -- :Git / :Gstatus / :Gdiff — unchanged from the vim setup
  "tpope/vim-fugitive",

  -- VSCode Source Control-like viewer: changed-file panel + side-by-side
  -- diffs, file history, merge tool. <leader>gd toggles the view.
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- commands exist from startup; the plugin loads on first use
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewRefresh", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", function()
          local view = require("diffview.lib").get_current_view()
          if view then
            view:close()
          else
            vim.cmd("DiffviewOpen")
          end
        end, desc = "Git diff view (toggle)" },
      { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
      { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "Git repo history" },
    },
    opts = {
      use_icons = true,
    },
  },
}
