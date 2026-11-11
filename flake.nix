{
  description = "linuxmeeter development environment";

  inputs = {
    # Same nixpkgs revision as the ago system: the toolchain and libraries
    # are already in the local store, so entering the shell builds nothing.
    nixpkgs.url = "github:NixOS/nixpkgs/ac588ef1c914865dad517b337ea0eb9694a4021c";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            # Rust
            cargo
            rustc
            clippy
            rustfmt
            rust-analyzer
            rustPlatform.bindgenHook # pipewire / libspa crates use bindgen
            pkg-config

            # Frontend and Tauri (the Makefile runs `pnpm tauri`)
            nodejs
            pnpm_10_latest # lockfile format 9.0; pnpm_10 is marked insecure
            cargo-tauri
            gnumake

            # `make test-audio` starts a private PipeWire daemon
            pipewire
          ];

          buildInputs = with pkgs; [
            dbus
            glib-networking
            gtk3
            libayatana-appindicator
            librsvg
            libsoup_3
            openssl
            pipewire
            webkitgtk_4_1
          ];

          env = {
            # The tray dlopens libayatana-appindicator3; it is not in RUNPATH.
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libayatana-appindicator ];
            # The engine loads the PipeWire filter-chain module in-process; it
            # finds the LSP plugins through LV2_PATH.
            LV2_PATH = "${pkgs.lsp-plugins}/lib/lv2";
            # TLS for WebKitGTK / libsoup.
            GIO_EXTRA_MODULES = "${pkgs.glib-networking}/lib/gio/modules";
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };

          # GSettings schemas (what wrapGAppsHook3 adds in the package build).
          shellHook = ''
            export SHELL=${pkgs.zsh}/bin/zsh
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
            echo "linuxmeeter dev shell: rustc $(rustc --version | cut -d' ' -f2), node $(node --version), pnpm $(pnpm --version)"
            echo "First time: make install; then make check / make test / make app"
            # Interactive `nix develop` drops into zsh. Not under direnv (it
            # evaluates this hook in bash) and not for `nix develop --command`.
            if [ -z "''${DIRENV_IN_ENVRC:-}" ] && [[ $- == *i* ]] && [ -z "''${ZSH_VERSION:-}" ]; then
              exec ${pkgs.zsh}/bin/zsh
            fi
          '';
        };
      }
    );
}
