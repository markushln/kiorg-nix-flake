{
  description = "Prebuilt Kiorg file manager for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      version = "1.6.2";

      runtimeLibs = lib.makeLibraryPath (with pkgs; [
        wayland
        libxkbcommon
        libGL
        vulkan-loader
        fontconfig
        freetype
        openssl
        stdenv.cc.cc.lib
        zlib
        xorg.libX11
        xorg.libXcursor
        xorg.libXi
        xorg.libXrandr
      ]);

      kiorg = pkgs.stdenvNoCC.mkDerivation {
        pname = "kiorg";
        inherit version;

        src = pkgs.fetchzip {
          url = "https://github.com/houqp/kiorg/releases/download/v${version}/kiorg-v${version}-x86_64-linux.zip";
          hash = "sha256-hACM8TJ0zfUaJTbdEgsKlKYEUDN5sUNNwqUGHM++OtI=";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          patchelf
          makeWrapper
        ];

        buildInputs = with pkgs; [
          wayland
          libxkbcommon
          libGL
          vulkan-loader
          fontconfig
          freetype
          openssl
          stdenv.cc.cc.lib
          zlib
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
        ];

        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/bin" "$out/lib"

          # ZIP archives do not always preserve executable permissions.
          binary="$(find . -type f -name kiorg -print -quit)"

          if [ -z "$binary" ]; then
            echo "Could not find executable named kiorg in release archive."
            find . -maxdepth 3 -type f
            exit 1
          fi

          install -m755 "$binary" "$out/bin/kiorg"

          # Preserve any shared libraries shipped with the release.
          find . -type f -name '*.so*' \
            -exec cp -n -t "$out/lib" {} + || true

          runHook postInstall
        '';

        postFixup = ''
          # Provide libraries loaded dynamically by winit, including Wayland.
          patchelf \
            --set-rpath "${runtimeLibs}:$out/lib" \
            "$out/bin/kiorg"

          wrapProgram "$out/bin/kiorg" \
            --prefix LD_LIBRARY_PATH : "${runtimeLibs}:$out/lib"
        '';

        meta = {
          description = "A Vim-inspired file manager";
          homepage = "https://github.com/houqp/kiorg";
          license = lib.licenses.mit;
          mainProgram = "kiorg";
          platforms = [ "x86_64-linux" ];
        };
      };
    in
    {
      packages.${system} = {
        default = kiorg;
        kiorg = kiorg;
      };
    };
}
