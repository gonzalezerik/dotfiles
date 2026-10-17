-- ── Debugging (nvim-dap) ─────────────────────────────────────────────────────
-- Adapters/debuggers (lldb-dap, debugpy, delve, netcoredbg) come from Nix —
-- see extraPackages / the Python interpreter wired in nvim.nix.
local dap = require("dap")
local dapui = require("dapui")

dapui.setup({})
require("nvim-dap-virtual-text").setup({})

dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open({}) end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close({}) end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close({}) end

-- ── C / C++ / Rust / CUDA host code: lldb-dap ───────────────────────────────
local lldb_dap = vim.fn.exepath("lldb-dap")
if lldb_dap == "" then lldb_dap = vim.fn.exepath("lldb-vscode") end
if lldb_dap ~= "" then
  dap.adapters.lldb = { type = "executable", command = lldb_dap, name = "lldb" }
  local lldb_cfg = {
    {
      name = "Launch",
      type = "lldb",
      request = "launch",
      program = function()
        return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }
  dap.configurations.c = lldb_cfg
  dap.configurations.cpp = lldb_cfg
  dap.configurations.cuda = lldb_cfg
  dap.configurations.rust = {
    {
      name = "Launch (cargo build first)",
      type = "lldb",
      request = "launch",
      program = function()
        vim.fn.system("cargo build")
        local name = vim.fn.system("grep -m1 '^name' Cargo.toml | cut -d '\"' -f2"):gsub("%s+$", "")
        return vim.fn.getcwd() .. "/target/debug/" .. name
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }
end

-- ── Python: debugpy ──────────────────────────────────────────────────────────
if vim.g.nvim_python_debug then
  require("dap-python").setup(vim.g.nvim_python_debug)
end

-- ── Go: delve ────────────────────────────────────────────────────────────────
require("dap-go").setup()

-- ── C#: netcoredbg ───────────────────────────────────────────────────────────
local netcoredbg = vim.fn.exepath("netcoredbg")
if netcoredbg ~= "" then
  dap.adapters.coreclr = { type = "executable", command = netcoredbg, args = { "--interpreter=vscode" } }
  dap.configurations.cs = {
    {
      type = "coreclr",
      name = "launch - netcoredbg",
      request = "launch",
      program = function()
        return vim.fn.input("dll path: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
      end,
    },
  }
end

-- ── Keymaps (VSCode parity: F5/F9/F10/F11/Shift+F11) ────────────────────────
local map = vim.keymap.set
map("n", "<F5>", dap.continue, { desc = "Debug: continue/start" })
map("n", "<F9>", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
map("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
map("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
map("n", "<S-F11>", dap.step_out, { desc = "Debug: step out" })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
map("n", "<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "Conditional breakpoint" })
map("n", "<leader>dc", dap.continue, { desc = "Continue" })
map("n", "<leader>dt", dap.terminate, { desc = "Terminate" })
map("n", "<leader>du", dapui.toggle, { desc = "Toggle debug UI" })
map("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
