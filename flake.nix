{
  description = "Prebuilt Kiorg file manager for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      version = "1.6.2";

      kiorg = pkgs.stdenvNoCC.mkDerivation {
        pname = "kiorg";
         inherit version system;

        src = pkgs.fetchzip {
          url = "https://github.com/houqp/kiorg/releases/download/v${version}/kiorg-v${version}-${system}.zip";
          hash = "sha256-hACM8TJ0zfUaJTbdEgsKlKYEUDN5sUNNwqUGHM++OtI=";
        };

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.unzip
        ];

        buildInputs = with pkgs; [
          fontconfig
          freetype
          libGL
          libxkbcommon
          openssl
          stdenv.cc.cc.lib
          vulkan-loader
          wayland
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
          zlib
        ];

        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/bin" "$out/lib"

          # Install the main executable.
          binary="$(find . -type f -name kiorg -perm /111 -print -quit)"
          if [ -z "$binary" ]; then
            echo "Could not find executable named kiorg in release archive."
            echo "Archive contents:"
            find . -maxdepth 3 -type f
            exit 1
          fi

          install -m755 "$binary" "$out/bin/kiorg"

          # Preserve any shared libraries shipped in the archive.
          find . -type f -name '*.so*' -exec cp -n -t "$out/lib" {} + || true

          runHook postInstall
        '';

        meta = {
          description = "A Vim-inspired file manager";
          homepage = "https://github.com/houqp/kiorg";
          license = lib.licenses.mit;
          mainProgram = "kiorg";
          platforms = [ "x86_64-linux" ];
        };
      };
    in {
      packages.${system} = {
        default = kiorg;
        kiorg = kiorg;
      };
    };
}
