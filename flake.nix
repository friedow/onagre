{
  description = "Rust example flake for Zero to Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    crane.url = "github:ipetkov/crane";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay, crane }:
    let
      # Overlays enable you to customize the Nixpkgs attribute set
      overlays = [
        # Makes a `rust-bin` attribute available in Nixpkgs
        (import rust-overlay)
        # Provides a `rustToolchain` attribute for Nixpkgs that we can use to
        # create a Rust environment
        (self: super: { rustToolchain = super.rust-bin.stable.latest.default; })
      ];

      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f:
        nixpkgs.lib.genAttrs allSystems
        (system: f { pkgs = import nixpkgs { inherit overlays system; }; });

      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      src = ./.;
      cargoTOML = builtins.fromTOML (builtins.readFile (src + /Cargo.toml));
      inherit (cargoTOML.package) version name;
      craneLib = crane.mkLib pkgs;
      pname = name;
      stdenv = if pkgs.stdenv.isLinux then
        pkgs.stdenvAdapters.useMoldLinker pkgs.stdenv
      else
        pkgs.stdenv;
    in {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          # The Nix packages provided in the environment
          packages = (with pkgs; [
            # The package provided by our custom overlay. Includes cargo, Clippy, cargo-fmt,
            # rustdoc, rustfmt, and other tools.
            # rust
            rustToolchain
            # nativeBuildInputs
            cmake
            pkgconf
            makeWrapper
            # bin dependencies
            pop-launcher
            papirus-icon-theme
            # buildInputs
            freetype
            expat
            libGL
            libglvnd
            fontconfig
            libxkbcommon
          ]) ++ (with pkgs.xorg; [ libX11 libXcursor libXi libXrandr libxcb ])
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
            (with pkgs; [ libiconv ]);

          shellHook = ''
            export LD_LIBRARY_PATH=${
              pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader pkgs.libGL ]
            }
          '';
        };
      });

      packages."x86_64-linux" = {
        default = craneLib.buildPackage {
          inherit version name pname stdenv src;
          nativeBuildInputs = with pkgs; [ cmake pkgconf makeWrapper ];
          buildInputs = with pkgs;
            [ freetype expat libGL libglvnd fontconfig libxkbcommon ]
            ++ (with pkgs.xorg; [ libX11 libXcursor libXi libXrandr libxcb ]);

          doCheck = false;

          postInstall = ''
            wrapProgram "$out/bin/${pname}" \
              --prefix LD_LIBRARY_PATH : ${
                pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader pkgs.libGL ]
              } \
              --suffix XDG_DATA_DIRS : "${pkgs.papirus-icon-theme}/share"
          '';
        };
      };
    };
}
