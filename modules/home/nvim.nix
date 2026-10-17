{ config, pkgs, lib, osConfig, ... }:
# Full IDE-replacement Neovim setup, entirely Nix-native: plugins come from
# nixpkgs (programs.neovim.plugins below), LSP/DAP/formatter/linter binaries
# from extraPackages — no Mason, nothing fetched at runtime, fully
# reproducible via `nixos-rebuild switch` like the rest of this flake.
#
# Behavioural config (options/keymaps/plugin setup) lives as plain Lua under
# ./files/nvim/lua/config/*.lua, symlinked to ~/.config/nvim/lua/config via
# xdg.configFile below; programs.neovim.extraLuaConfig just does
# `require("config")`. Edit the Lua files directly, then `home-manager switch`
# (or the system-wide `nixos-rebuild switch`) to apply.
let
  t = osConfig.dotfiles.theme;
  # "#0A0D10" -> "10,13,16" for zathura's rgba() colours.
  rgb = hex: lib.concatMapStringsSep "," (i: toString (lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex)))) [ 0 2 4 ];

  # debugpy needs to live in a Python environment nvim-dap-python can point
  # at directly; kept separate from the plain `python3` on PATH below so
  # debugging doesn't pull debugpy into every project's import path.
  pythonWithDebugpy = pkgs.python3.withPackages (ps: [ ps.debugpy ]);

  # ── Notes vault (obsidian.nvim) ─────────────────────────────────────────
  # Plain markdown on disk at ~/Notes — the same format the real Obsidian
  # app reads, so this stays portable even though nothing here depends on
  # it. Seeded once by the activation script below, then it's yours: unlike
  # the rest of this config, note *content* (including these two templates)
  # is deliberately NOT a Nix-store symlink, since it's meant to be edited
  # directly, not redeployed.
  notesDailyTemplate = pkgs.writeText "obsidian-daily-template.md" ''
    ---
    id: {{date}}
    aliases: []
    tags: [daily]
    ---

    # {{date}}

    ## Log


    ## Tasks

    - [ ]
  '';
  notesNoteTemplate = pkgs.writeText "obsidian-note-template.md" ''
    ---
    id: {{id}}
    aliases: []
    tags: []
    ---

    # {{title}}

  '';
in
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = ''
      vim.g.nvim_python_debug = "${pythonWithDebugpy}/bin/python3"
      require("config")
    '';

    extraPackages = with pkgs; [
      # ── Core search/format tooling used by Telescope/Conform ─────────────
      ripgrep
      fd

      # ── Rust ───────────────────────────────────────────────────────────
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy

      # ── Python (+ CUDA-adjacent: debugpy env defined above) ─────────────
      python3
      pyright
      ruff

      # ── C / C++ / CUDA host code ──────────────────────────────────────
      gcc
      clang-tools # clangd + clang-format
      gdb
      lldb
      cmake
      gnumake
      bear

      # ── Arduino (.ino) ────────────────────────────────────────────────
      # Wraps clangd with arduino-cli's build flags for the board.
      arduino-language-server
      arduino-cli

      # ── Nix ───────────────────────────────────────────────────────────
      nil
      alejandra
      statix

      # ── Lua ───────────────────────────────────────────────────────────
      lua-language-server
      stylua
      lua5_4

      # ── JavaScript / TypeScript / web ────────────────────────────────
      nodejs
      typescript
      typescript-language-server
      vscode-langservers-extracted # html, css, json
      eslint_d
      prettierd
      live-server

      # ── Go ────────────────────────────────────────────────────────────
      go
      gopls
      delve
      golangci-lint
      gofumpt

      # ── Bash ──────────────────────────────────────────────────────────
      bash-language-server
      shellcheck
      shfmt

      # ── C# ────────────────────────────────────────────────────────────
      dotnet-sdk
      omnisharp-roslyn
      netcoredbg

      # ── SQL (dadbod handles the DB connection itself; these are LSP/fmt) ─
      sqls
      sqlfluff

      # ── YAML / TOML / Dockerfile / Markdown ──────────────────────────
      yaml-language-server
      taplo
      dockerfile-language-server
      hadolint
      marksman

      # ── LaTeX ─────────────────────────────────────────────────────────
      texlab
      texliveFull
    ];

    plugins = with pkgs.vimPlugins; [
      # ── Core UI ────────────────────────────────────────────────────────
      plenary-nvim
      nvim-web-devicons
      tokyonight-nvim
      lualine-nvim
      bufferline-nvim
      which-key-nvim
      nvim-tree-lua
      telescope-nvim
      telescope-fzf-native-nvim
      telescope-ui-select-nvim
      indent-blankline-nvim
      gitsigns-nvim
      comment-nvim
      nvim-autopairs
      nvim-surround
      toggleterm-nvim
      trouble-nvim
      todo-comments-nvim

      # ── LSP / completion ──────────────────────────────────────────────
      nvim-lspconfig
      fidget-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      luasnip
      cmp_luasnip
      friendly-snippets
      lspkind-nvim

      # ── Treesitter (all grammars — the Nix store is read-only, so
      #    :TSInstall isn't an option; this bakes every parser in up front) ─
      # nixpkgs-unstable tracks nvim-treesitter's "main" branch, a full
      # incompatible rewrite that dropped the classic
      # `require('nvim-treesitter.configs').setup{}` API entirely (along
      # with incremental_selection and its own textobjects module). The
      # rest of the plugin ecosystem (textobjects, context, most configs
      # people copy from the internet) still targets the old "master" API,
      # so this deliberately pins to nixpkgs' `-legacy` builds, which track
      # "master" and keep `.withAllGrammars` working the classic way.
      nvim-treesitter-legacy.withAllGrammars
      nvim-treesitter-textobjects-legacy
      nvim-treesitter-context

      # ── Debugging ──────────────────────────────────────────────────────
      nvim-dap
      nvim-dap-ui
      nvim-nio
      nvim-dap-virtual-text
      nvim-dap-python
      nvim-dap-go

      # ── Format / lint ──────────────────────────────────────────────────
      conform-nvim
      nvim-lint

      # ── LaTeX ──────────────────────────────────────────────────────────
      vimtex

      # ── SQL database UI ──────────────────────────────────────────────
      vim-dadbod
      vim-dadbod-ui
      vim-dadbod-completion

      # ── Note taking (obsidian.nvim vault at ~/Notes) ──────────────────
      obsidian-nvim
      render-markdown-nvim
    ];
  };

  xdg.configFile."nvim/lua/config" = {
    source = ./files/nvim/lua/config;
    recursive = true;
  };
  # The host palette for theme.lua.
  xdg.configFile."nvim/lua/config/palette.lua".text = ''
    return {
      bg = "${t.surface}",
      bg_float = "${t.surfaceVariant}",
      bg_hover = "${t.hover}",
      fg = "${t.onSurface}",
      fg_bright = "${t.onSecondary}",
      fg_dim = "${t.onSurfaceVariant}",
      border = "${t.secondary}",
      primary = "${t.primary}",
      secondary = "${t.secondary}",
      black = "${t.ansi.black}",
      red = "${t.ansi.red}",
      green = "${t.success}",
      yellow = "${t.ansi.yellow}",
      blue = "${t.secondary}",
      magenta = "${t.ansi.magenta}",
      cyan = "${t.primary}",
      white = "${t.onSurface}",
      bright_black = "${t.ansiBright.black}",
    }
  '';

  # Create the vault + seed its two templates on first activation only;
  # never touches files that already exist, so edits to daily.md/note.md
  # (or new notes) survive every future `nixos-rebuild switch`.
  home.activation.createNotesVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Notes/daily" "$HOME/Notes/templates"
    if [ ! -e "$HOME/Notes/templates/daily.md" ]; then
      run install -m 644 "${notesDailyTemplate}" "$HOME/Notes/templates/daily.md"
    fi
    if [ ! -e "$HOME/Notes/templates/note.md" ]; then
      run install -m 644 "${notesNoteTemplate}" "$HOME/Notes/templates/note.md"
    fi
  '';

  # ── Zathura (LaTeX preview target for vimtex) ───────────────────────────
  # Also the default PDF viewer. Native (not Flatpak), so vimtex's synctex
  # forward/inverse search works.
  programs.zathura.enable = true;
  xdg.configFile."zathura/zathurarc".text = ''
    set selection-clipboard clipboard
    set incremental-search true
    # dark-mode PDFs to match everything else on this box
    set recolor true
    set font "SF Pro 11"

    # Always translucent exactly like foot (colors-dark alpha 0.80 over the
    # surface colour); niri blurs behind it with foot's rule (niri.nix).
    # Recolored pages are fully transparent so the page and the gap around it
    # are the same single 0.80 layer instead of stacking to ~0.96.
    set default-bg                  "rgba(${rgb t.surface},0.80)"
    set default-fg                  "${t.onSurface}"
    set recolor-lightcolor          "rgba(0,0,0,0)"
    set recolor-darkcolor           "${t.onSurface}"
    set statusbar-bg                "rgba(${rgb t.surface},0.80)"
    set statusbar-fg                "${t.onSurfaceVariant}"
    set inputbar-bg                 "rgba(${rgb t.surface},0.80)"
    set inputbar-fg                 "${t.onSurface}"
    set completion-bg               "rgba(${rgb t.surfaceVariant},0.80)"
    set completion-fg               "${t.onSurface}"
    set completion-group-bg         "rgba(${rgb t.surfaceVariant},0.80)"
    set completion-group-fg         "${t.primary}"
    set completion-highlight-bg     "${t.secondary}"
    set completion-highlight-fg     "${t.onSecondary}"
    set index-bg                    "rgba(${rgb t.surface},0.80)"
    set index-fg                    "${t.onSurface}"
    set index-active-bg             "${t.secondary}"
    set index-active-fg             "${t.onSecondary}"
    set notification-bg             "rgba(${rgb t.surfaceVariant},0.80)"
    set notification-fg             "${t.onSurface}"
    set notification-error-bg       "${t.error}"
    set notification-error-fg       "${t.surface}"
    set notification-warning-bg     "${t.ansi.yellow}"
    set notification-warning-fg     "${t.surface}"
    set highlight-color             "rgba(${rgb t.primary},0.35)"
    set highlight-active-color      "rgba(${rgb t.primary},0.60)"
    set highlight-fg                "${t.surface}"
  '';
}
