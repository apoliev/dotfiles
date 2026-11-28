-- LSP: mason installs the servers, nvim-lspconfig ships their default
-- configs (`lsp/<name>.lua` on the runtimepath), mason-lspconfig enables
-- them via vim.lsp.enable once installed.
--
-- Servers: ruby-lsp (Ruby/Rails, runs the project's RuboCop addon for lint +
-- format when the bundle has it), gopls (Go), pyright (Python),
-- typescript-language-server (JavaScript/TypeScript).
local servers = { "ruby_lsp", "gopls", "pyright", "ts_ls" }

-- lspconfig server name -> mason registry package name
local packages = {
  ruby_lsp = "ruby-lsp",
  gopls = "gopls",
  pyright = "pyright",
  ts_ls = "typescript-language-server",
}

local function missing_packages()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return {}
  end
  local missing = {}
  for _, server in ipairs(servers) do
    local ok_pkg, pkg = pcall(registry.get_package, packages[server])
    if ok_pkg and not pkg:is_installed() then
      table.insert(missing, packages[server])
    end
  end
  return missing
end

-- Install missing servers. `block` waits for completion (headless bootstrap
-- from nvim/install.sh must not quit while installs are still running).
local function install_missing(block)
  local missing = missing_packages()
  if #missing == 0 then
    return
  end
  -- pcall: installer progress output (e.g. `go install` download lines)
  -- surfaces as a vim.cmd error and must never abort startup or the wait
  pcall(vim.cmd, "MasonInstall " .. table.concat(missing, " "))
  if block then
    vim.wait(300000, function()
      return #missing_packages() == 0
    end, 2000)
  end
end

-- Headless-friendly bootstrap: nvim/install.sh calls it with +qa, but it is
-- handy manually after adding a server to the list above.
vim.api.nvim_create_user_command("MasonInstallAll", function()
  install_missing(true)
end, { desc = "Install all configured LSP servers via mason" })

return {
  {
    -- Not lazy: mason's README explicitly recommends against it, and
    -- :MasonInstallAll must exist in headless runs too.
    "mason-org/mason.nvim",
    lazy = false,
    dependencies = {
      "mason-org/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
      -- completion capabilities must be in place before the first LSP attach
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("mason").setup({})
      require("mason-lspconfig").setup({
        automatic_enable = true, -- enable every installed server
      })

      -- nvim-cmp capabilities for every server ("*" = the default overlay)
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- The maps the old vim-lsp config had, plus code actions
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = "LSP: " .. desc })
          end
          map("gd", vim.lsp.buf.definition, "go to definition")
          map("gD", vim.lsp.buf.declaration, "go to declaration")
          map("K", vim.lsp.buf.hover, "hover docs")
          map("gr", vim.lsp.buf.references, "references")
          map("<leader>rn", vim.lsp.buf.rename, "rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "code action")
        end,
      })

      -- Self-healing: fetch servers that are still missing (fresh machines).
      -- Deferred so the mason config itself always completes cleanly.
      vim.schedule(function()
        install_missing(false)
      end)
    end,
  },
}
