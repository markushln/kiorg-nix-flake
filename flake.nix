{
  description = "Prebuilt Kiorg file manager and XDG portal backend for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Source code for the portal backend.
    kiorgSrc = {
      url = "github:markushln/kiorg";
      flake = false;
    };
  };

  outputs = { nixpkgs, kiorgSrc, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      version = "1.7.0";

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
        libx11
        libxcursor
        libxi
        libxrandr
      ]);

      # Existing prebuilt Kiorg release package.
      kiorg = pkgs.stdenvNoCC.mkDerivation {
        pname = "kiorg";
        inherit version;

        src = pkgs.fetchzip {
          url = "https://github.com/markushln/kiorg/releases/download/v${version}/kiorg-v${version}-x86_64-linux.zip";
          hash = "sha256-fXrg5HwocLHNtikf83a4v6pb0Vdh/XN4AWzLQxPP6Cw=";
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
          libx11
          libxcursor
          libxi
          libxrandr
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
          patchelf \
            --set-rpath "${runtimeLibs}:$out/lib" \
            "$out/bin/kiorg"

          wrapProgram "$out/bin/kiorg" \
            --prefix LD_LIBRARY_PATH : "${runtimeLibs}:$out/lib"
        '';

        meta = {
          description = "A Vim-inspired file manager";
          homepage = "https://github.com/markushln/kiorg";
          license = lib.licenses.mit;
          mainProgram = "kiorg";
          platforms = [ "x86_64-linux" ];
        };
      };

      # Portal backend built from the Kiorg repository.
      xdg-desktop-portal-kiorg =
        pkgs.rustPlatform.buildRustPackage {
          pname = "xdg-desktop-portal-kiorg";
          version = "0.1.0";

          src = kiorgSrc;

          cargoLock = {
            lockFile = "${kiorgSrc}/Cargo.lock";
            outputHashes = {
              "egui_nerdfonts-0.1.3" = lib.fakeHash;;
            };
          }

          cargoBuildFlags = [
            "-p"
            "xdg-desktop-portal-kiorg"
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p \
              "$out/bin" \
              "$out/share/xdg-desktop-portal/portals" \
              "$out/share/dbus-1/services" \
              "$out/lib/systemd/user"

            # Install the portal executable.
            install -Dm755 \
              target/release/xdg-desktop-portal-kiorg \
              "$out/bin/xdg-desktop-portal-kiorg"

            # Register the backend with xdg-desktop-portal.
            install -Dm644 \
              crates/xdg-desktop-portal-kiorg/data/kiorg.portal \
              "$out/share/xdg-desktop-portal/portals/kiorg.portal"

            # D-Bus activation service.
            substitute \
              crates/xdg-desktop-portal-kiorg/data/org.freedesktop.impl.portal.desktop.kiorg.service \
              "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kiorg.service" \
              --replace-fail \
                "/usr/libexec/xdg-desktop-portal-kiorg" \
                "$out/bin/xdg-desktop-portal-kiorg"

            # systemd user service.
            substitute \
              crates/xdg-desktop-portal-kiorg/data/xdg-desktop-portal-kiorg.service \
              "$out/lib/systemd/user/xdg-desktop-portal-kiorg.service" \
              --replace-fail \
                "/usr/libexec/xdg-desktop-portal-kiorg" \
                "$out/bin/xdg-desktop-portal-kiorg"

            # Use the prebuilt Kiorg release for picker requests.
            sed -i \
              "/^ExecStart=/i Environment=\"KIORG_PICKER_BIN=${kiorg}/bin/kiorg\"" \
              "$out/lib/systemd/user/xdg-desktop-portal-kiorg.service"

            runHook postInstall
          '';

          meta = {
            description = "XDG Desktop Portal FileChooser backend for Kiorg";
            homepage = "https://github.com/markushln/kiorg";
            license = lib.licenses.mit;
            platforms = [ "x86_64-linux" ];
          };
        };
    in
    {
      packages.${system} = {
        default = kiorg;
        inherit kiorg xdg-desktop-portal-kiorg;
      };
    };
}
