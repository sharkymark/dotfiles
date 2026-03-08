-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

vim.opt.clipboard = "unnamedplus"

-- Set leader key to space
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lazy").setup({
  -- plugins
  "nvim-treesitter/nvim-treesitter",
  "nvim-lua/plenary.nvim",
  "nvim-telescope/telescope.nvim",
  "neovim/nvim-lspconfig",
  -- Added MCP Hub Plugin
  {
    "ravitemer/mcphub.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    build = "npm install -g mcp-hub@latest", 
    config = function()
      local claude_json_path = vim.fn.expand("~/.claude.json")

      local function check_claude_json()
        local f = io.open(claude_json_path, "r")
        if not f then return false, "not_found" end
        local content = f:read("*a"); f:close()
        local ok, parsed = pcall(vim.json.decode, content)
        if not ok or type(parsed) ~= "table" then return false, "invalid_json" end
        local has_mcp = parsed.mcpServers and type(parsed.mcpServers) == "table"
        local has_srv = parsed.servers    and type(parsed.servers)    == "table"
        if not has_mcp and not has_srv then return false, "no_servers_key" end
        return true, nil
      end

      local ok, reason = check_claude_json()
      if not ok then
        local msgs = {
          not_found      = "~/.claude.json not found. Add MCP servers via Claude Code (`claude mcp add ...`) and restart nvim.",
          invalid_json   = "~/.claude.json is not valid JSON. mcphub will not start.",
          no_servers_key = "~/.claude.json has no 'mcpServers' key — mcphub will not start.\nAdd servers via Claude Code: `claude mcp add <name> <cmd>`",
        }
        vim.schedule(function()
          vim.notify("[mcphub] " .. (msgs[reason] or "Unknown config issue — mcphub will not start."), vim.log.levels.WARN)
        end)
        return
      end

      require("mcphub").setup({
        config = claude_json_path,
      })
    end,
  },

  -- amp plugin 
  {
    "sourcegraph/amp.nvim",
    branch = "main",
    lazy = false,
    opts = { auto_start = true, log_level = "info" },
  },

  -- avante plugin
  {
    "yetone/avante.nvim",
    dir = (function()
      local f = io.open(vim.fn.stdpath("config") .. "/.avante_pref", "r")
      if f then
        local v = tonumber(f:read("*l")); f:close()
        if v == 1 then
          local fork_path = vim.fn.expand(
            os.getenv("AVANTE_FORK_PATH") or "~/Documents/dev_and_debug/src/mark/avante.nvim"
          )
          if vim.fn.isdirectory(fork_path) == 1 then
            vim.g.avante_fork_loaded = "jon"
            return fork_path
          else
            -- Fork not found — reset pref to 2 (upstream) so next start is clean
            vim.g.avante_fork_loaded = "upstream"
            local pf = io.open(vim.fn.stdpath("config") .. "/.avante_pref", "w")
            if pf then pf:write("2"); pf:close() end
            vim.notify("Avante fork not found at " .. fork_path .. " — falling back to upstream", vim.log.levels.WARN)
          end
        end
      end
      vim.g.avante_fork_loaded = "upstream"
      return nil
    end)(),
    event = "VeryLazy",
    lazy = false,
    version = false,
    config = function(_, opts)
      local has_mcphub, mcphub_avante = pcall(require, "mcphub.extensions.avante")

-- 2. System Prompt Logic (Only Local Files)
      opts.system_prompt = function()
        -- Get active MCP servers for tool-naming context
        local hub = require('mcphub').get_hub_instance()
        local mcp_context = hub and hub:get_active_servers_prompt() or ""
        
        -- Use git root of current file, falling back to cwd
        local file_dir = vim.fn.expand("%:p:h")
        local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(file_dir) .. " rev-parse --show-toplevel 2>/dev/null")[1]
        local project_root = (git_root and git_root ~= "") and git_root or vim.fn.getcwd()
        local local_instructions = ""
        local files_to_check = { project_root .. "/CLAUDE.md", project_root .. "/AGENTS.md" }

        for _, file_path in ipairs(files_to_check) do
          local f = io.open(file_path, "r")
          if f then
            local_instructions = local_instructions .. "\n\nProject Context (" .. file_path .. "):\n" .. f:read("*all")
            f:close()
          end
        end

        return "You are a helpful AI assistant." .. "\n" .. mcp_context .. local_instructions
      end

      
      
      if has_mcphub then
        opts.custom_tools = opts.custom_tools or {}
        local mcp_tool = mcphub_avante.mcp_tool()
        if mcp_tool then
          table.insert(opts.custom_tools, mcp_tool)
        end
      end     

      -- Provider configurations — add new providers here
      local pref_file = vim.fn.stdpath("config") .. "/.avante_pref"
      local provider_configs = {
        { label = "jon's avante  (claude-code)", provider = "claude-code", mode = "agentic", fork = "jon"      },
        { label = "claude-code   (agentic)",     provider = "claude-code", mode = "agentic", fork = "upstream" },
        { label = "claude        (direct API)",  provider = "claude",      mode = nil,       fork = "upstream" },
      }

      local function apply_pref(idx)
        local cfg = provider_configs[idx]
        -- Guard: if jon's fork is selected but directory not present, warn and skip
        if cfg.fork == "jon" then
          local fork_path = vim.fn.expand(
            os.getenv("AVANTE_FORK_PATH") or "~/Documents/dev_and_debug/src/mark/avante.nvim"
          )
          if vim.fn.isdirectory(fork_path) ~= 1 then
            vim.notify("Jon's avante fork not found at " .. fork_path .. ".\nClone: https://github.com/jonmorehouse/avante.nvim\nOr set AVANTE_FORK_PATH env var.", vim.log.levels.ERROR)
            return
          end
        end
        opts.provider = cfg.provider
        opts.mode = cfg.mode
        local f = io.open(pref_file, "w")
        if f then f:write(tostring(idx)); f:close() end
        require("avante").setup(opts)
        if cfg.fork ~= (vim.g.avante_fork_loaded or "upstream") then
          vim.notify("Avante fork will switch to '" .. cfg.label .. "' on next restart", vim.log.levels.WARN)
        end
      end

      -- Apply saved preference silently on startup; default to 2 (claude-code upstream)
      local saved_idx = 2
      local pf = io.open(pref_file, "r")
      if pf then
        local v = tonumber(pf:read("*l")); pf:close()
        if v and provider_configs[v] then saved_idx = v end
      end
      apply_pref(saved_idx)

      -- :AvanteSelect to change preference (fork changes take effect on next restart)
      vim.api.nvim_create_user_command("AvanteSelect", function()
        vim.ui.select(
          vim.tbl_map(function(p) return p.label end, provider_configs),
          { prompt = "Select Avante provider:" },
          function(_, idx)
            if not idx then return end
            apply_pref(idx)
          end
        )
      end, { desc = "Select Avante provider" })

    end,
    opts = {
      -- ====================================================
      -- Provider/mode loaded from .avante_pref on startup (default: claude-code upstream).
      -- Use :AvanteSelect to change. Fork changes take effect on next restart.
      -- To add a new provider, add an entry to provider_configs in config above.
      -- ====================================================

      shortcuts_directory = vim.fn.expand("~/Documents/dev_and_debug/src/mark/avante-shortcuts"),

      -- ACP provider configuration for Claude Code
      -- This section is only used when provider = "claude-code"
      acp_providers = {
        ["claude-code"] = {
          command = "npx",
          args = { "-y", "@zed-industries/claude-code-acp" },
          env = {
            NODE_NO_WARNINGS = "1",
            ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
            -- Path to your local claude CLI executable
            ACP_PATH_TO_CLAUDE_CODE_EXECUTABLE = vim.fn.exepath("claude") ~= "" and vim.fn.exepath("claude") or "/opt/homebrew/bin/claude",
            -- Permission mode: "bypassPermissions" allows autonomous operations
            -- Change to "normal" if you want to approve each action
            ACP_PERMISSION_MODE = "bypassPermissions",
          },
        },
      },

      -- Keep this section for fallback to direct API
      -- Used when provider = "claude" instead of "claude-code"
      providers = {
        claude = {
          api_key_name = "ANTHROPIC_API_KEY",
        },
      },
    },
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false", -- use this on Windows
    dependencies = {
      "stevearc/dressing.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },


  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        sources = cmp.config.sources({
          { name = "buffer" },
          { name = "path" },
          -- avante sources (shortcuts, commands, mentions) are registered
          -- automatically by avante when it loads
        }),
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<CR>"]  = cmp.mapping.confirm({ select = true }),
          ["<C-e>"] = cmp.mapping.abort(),
        }),
      })
    end,
  },

})

-- Auto-cd to git root when opening a file so Avante sees the right project
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local buf = vim.api.nvim_buf_get_name(0)
    if buf == "" or vim.bo.buftype ~= "" then return end
    local git_root = vim.fn.systemlist(
      "git -C " .. vim.fn.shellescape(vim.fn.fnamemodify(buf, ":h")) .. " rev-parse --show-toplevel 2>/dev/null"
    )[1]
    if git_root and git_root ~= "" then
      vim.cmd("cd " .. vim.fn.fnameescape(git_root))
    end
  end,
})

-- Create :AmpX command
vim.api.nvim_create_user_command('AmpX', function(opts)
  local prompt = opts.args
  if prompt == '' then
    prompt = vim.fn.input('Amp prompt: ')
  end
  if prompt ~= '' then
    -- Run in terminal buffer so it stays within Neovim
    vim.cmd('botright split | terminal amp -x "' .. prompt .. '"')
  end
end, { nargs = '?' })

-- Optional: Add a keybinding that calls the command
vim.keymap.set('n', '<leader>ax', ':AmpX<CR>', { desc = 'Amp execute mode' })

-- ============================================
-- Avante History Access Keybindings
-- ============================================

-- View all threads across all projects (comprehensive Telescope picker)
vim.keymap.set('n', '<leader>at', ':AvanteThreads<CR>', {
  desc = 'Avante: All threads (all projects)'
})

-- View history for current project only (focused view)
vim.keymap.set('n', '<leader>ah', ':AvanteHistory<CR>', {
  desc = 'Avante: History (current project)'
})

-- Quick start new chat thread
vim.keymap.set('n', '<leader>an', ':AvanteChatNew<CR>', {
  desc = 'Avante: New chat thread'
})

-- Create a command to open Amp in a right-hand vertical split

vim.api.nvim_create_user_command("AmpChat", function()
    -- 1. Create a vertical split on the far right
    -- 'botright' ensures it takes the full height of the editor
    vim.cmd("botright vsplit")
    
    -- 2. Resize to a sidebar width
    vim.cmd("vertical resize 55")
    
    -- 3. Open a fresh buffer for the terminal
    vim.cmd("enew")
    
    -- 4. Set window options (UI cleanup)
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.foldcolumn = "0"

    -- 5. Start Amp ONLY ONCE with the exit strategy
    vim.fn.termopen("amp --ide .", {
        on_exit = function()
            -- Automatically close the split when you quit Amp
            vim.cmd("bdelete!")
        end
    })

    -- 6. Immediately enter insert mode to start chatting
    vim.cmd("startinsert")
end, { desc = "Open Amp AI sidebar on the right" })

-------------------------------------------------------------------------------
-- Nuon LSP Setup 
-------------------------------------------------------------------------------
local nuon_group = vim.api.nvim_create_augroup("NuonLSP", { clear = true })

-- Check if port is open
function is_nuon_dev_running(port)
    local scanner = vim.loop.new_tcp()
    local is_open = false
    scanner:connect("127.0.0.1", port, function(err)
        if not err then
            is_open = true
        end
        scanner:close()
    end)
    vim.wait(300, function() return is_open end)
    return is_open
end

vim.api.nvim_create_autocmd("FileType", {
    group = nuon_group,
    pattern = "toml",
    callback = function()
        local nuon_port = 7001
        local cmd = nil
        local mode_msg = ""
        
        -- Check for Dev Stack First
        if is_nuon_dev_running(nuon_port) then
            mode_msg = "Dev Stack"
            cmd = vim.lsp.rpc.connect("127.0.0.1", nuon_port)
        else
            -- Binary Fallback Logic
            local bins = { vim.fn.expand("~/bin/nuon-lsp-dev"), vim.fn.expand("~/bin/nuon-lsp") }
            for _, path in ipairs(bins) do
                if vim.fn.executable(path) == 1 then
                    cmd = { path }
                    mode_msg = "Binary (" .. vim.fn.fnamemodify(path, ":t") .. ")"
                    break
                end
            end
        end

        if cmd then
            print("Nuon LSP: Connecting via " .. mode_msg .. "...")

            local root_dir = vim.fn.expand("%:p:h")

            vim.lsp.start({
                name = "nuon-lsp",
                cmd = cmd,
                root_dir = root_dir,
                on_attach = function()
                    -- Redraw to ensure the message is visible over the command bar
                    vim.cmd("redraw")
                    print("Nuon LSP: Connected via " .. mode_msg)
                end
            })
        end
    end,
})

-- Keybindings for LSP features (Only active when LSP is attached)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local opts = { buffer = args.buf }
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)              -- Show docs/schema
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)        -- Go to definition
        vim.keymap.set('i', '<C-Space>', '<C-x><C-o>', opts)          -- Trigger autocomplete
    end,
})
