-- ── Per-language build/run/test keybinds + Live Server ──────────────────────
-- <leader>rr run, <leader>rb build, <leader>rt test — sent to the bottom
-- terminal panel (config/terminal.lua's M.run), same as VSCode's task runner.
-- Debugging is <leader>d* / F5 etc., wired per-language in config/dap.lua.
local run_in_term = require("config.terminal").run

-- %-register expansion helpers
local function file() return vim.fn.expand("%") end
local function file_noext() return vim.fn.expand("%:r") end
local function file_tail_noext() return vim.fn.expand("%:t:r") end

-- filetype -> { run, build, test }; each a function returning a shell string.
local commands = {
  rust = {
    run = function() return "cargo run" end,
    build = function() return "cargo build" end,
    test = function() return "cargo test" end,
  },
  python = {
    run = function() return "python3 " .. file() end,
    test = function() return "pytest" end,
  },
  c = {
    build = function() return "gcc -g -Wall " .. file() .. " -o /tmp/" .. file_tail_noext() end,
    run = function()
      return "gcc -g -Wall " .. file() .. " -o /tmp/" .. file_tail_noext() .. " && /tmp/" .. file_tail_noext()
    end,
  },
  cpp = {
    build = function() return "g++ -g -Wall -std=c++20 " .. file() .. " -o /tmp/" .. file_tail_noext() end,
    run = function()
      return "g++ -g -Wall -std=c++20 " .. file() .. " -o /tmp/" .. file_tail_noext() .. " && /tmp/" .. file_tail_noext()
    end,
  },
  -- nvcc isn't installed by this config — this is wired for compiling on a
  -- host that has the CUDA toolkit (e.g. over SSH). Will error clearly
  -- ("nvcc: command not found") rather than silently doing nothing.
  cuda = {
    build = function() return "nvcc " .. file() .. " -o /tmp/" .. file_tail_noext() end,
    run = function()
      return "nvcc " .. file() .. " -o /tmp/" .. file_tail_noext() .. " && /tmp/" .. file_tail_noext()
    end,
  },
  go = {
    run = function() return "go run " .. file() end,
    build = function() return "go build ./..." end,
    test = function() return "go test ./..." end,
  },
  javascript = {
    run = function() return "node " .. file() end,
    build = function() return "npm run build" end,
    test = function() return "npm test" end,
  },
  typescript = {
    run = function() return "npx tsx " .. file() end,
    build = function() return "npm run build" end,
    test = function() return "npm test" end,
  },
  sh = {
    run = function() return "bash " .. file() end,
  },
  lua = {
    run = function() return "lua " .. file() end,
  },
  cs = {
    run = function() return "dotnet run" end,
    build = function() return "dotnet build" end,
    test = function() return "dotnet test" end,
  },
  -- Nix: deliberately no "switch" keybind — that mutates the running system
  -- and shouldn't be one fat-fingered keypress away. `build`/`test` here are
  -- non-destructive; run `nixos-rebuild switch` by hand when you mean it.
  nix = {
    build = function() return "nix build ." end,
    test = function() return "nix flake check" end,
  },
  dockerfile = {
    build = function() return "docker build -t " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. " ." end,
  },
}
commands.javascriptreact = commands.javascript
commands.typescriptreact = commands.typescript

vim.api.nvim_create_augroup("lang-runners", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "lang-runners",
  callback = function(args)
    local spec = commands[vim.bo[args.buf].filetype]
    if not spec then return end
    local map = function(lhs, fn, desc)
      if not fn then return end
      vim.keymap.set("n", lhs, function() run_in_term(fn()) end, { buffer = args.buf, desc = desc })
    end
    map("<leader>rr", spec.run, "Run")
    map("<leader>rb", spec.build, "Build")
    map("<leader>rt", spec.test, "Test")
  end,
})

-- ── Live Server (web dev, VSCode "Go Live" parity) ──────────────────────────
-- live-server watches cwd and reloads the browser on save. Bound globally
-- since it's project-wide, not per-buffer.
-- Stop it the normal way: <leader>tt to focus the panel, then Ctrl-C.
vim.keymap.set("n", "<leader>ls", function()
  run_in_term("live-server " .. vim.fn.getcwd())
end, { desc = "Start Live Server" })
