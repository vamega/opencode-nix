{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  xz,
  binutils,
  zlib,
  openssl,
  icu,
  nss,
  nspr,
  alsa-lib,
  libgbm,
  gtk3 ? null,
  gdk-pixbuf ? null,
  cairo ? null,
  glib ? null,
  binName ? "opencode-desktop",
}: let
  version = "1.19.5";

  platformMap = {
    "x86_64-linux" = {
      target = "linux-amd64";
      ext = "deb";
    };
    "aarch64-linux" = {
      target = "linux-arm64";
      ext = "deb";
    };
    "x86_64-darwin" = {
      target = "mac-x64";
      ext = "app.tar.gz";
    };
    "aarch64-darwin" = {
      target = "mac-arm64";
      ext = "app.tar.gz";
    };
  };

  platformInfo = platformMap.${stdenv.hostPlatform.system} or
    (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "linux-amd64" = "sha256-3jgqrLX0Kjuh+o1CprYwMZrq04ubp8knAL7l2jl3uzI=";
    "linux-arm64" = "sha256-aq78Psr46x+nigtIRXtG5RTpHzzUyxIfdcZWOm5CJKc=";
    "mac-x64" = "sha256-mR0YnlDAWP+qeQwkah0skIphRvMkFfF9K/7aQiT64pI=";
    "mac-arm64" = "sha256-gCEn4JpR0jnTW3OwIBD5pzbuoU0EkS8spEUz3foAW2c=";
  };

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-${platformInfo.target}.${platformInfo.ext}";
    sha256 = hashes.${platformInfo.target};
  };

  linuxLibs = [
    stdenv.cc.cc.lib
    zlib
    openssl
    icu
    nss
    nspr
    alsa-lib
    libgbm
    gtk3
    gdk-pixbuf
    cairo
    glib
  ];
in
  stdenv.mkDerivation {
    pname = "opencode-desktop";
    inherit version src;

    dontUnpack = true;
    dontStrip = true;
    autoPatchelfIgnoreMissingDeps = ["libc.musl-x86_64.so.1" "libc.musl-aarch64.so.1"];

    nativeBuildInputs =
      [makeBinaryWrapper xz]
      ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook binutils];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux linuxLibs;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"

      if [ "${stdenv.hostPlatform.system}" = "x86_64-linux" ] || [ "${stdenv.hostPlatform.system}" = "aarch64-linux" ]; then
        mkdir -p unpack
        cd unpack

        ar x "$src"
        if [ -f data.tar.gz ]; then
          tar -xzf data.tar.gz
        elif [ -f data.tar.xz ]; then
          tar -xJf data.tar.xz
        elif [ -f data.tar.zst ]; then
          tar --zstd -xf data.tar.zst
        else
          echo "Unsupported Debian data archive format" >&2
          exit 1
        fi

        mkdir -p "$out/lib/opencode-desktop"
        cp -R opt/OpenCode "$out/lib/opencode-desktop/"
        cp -R usr/share "$out/share"
        desktopBinary="$out/lib/opencode-desktop/OpenCode/ai.opencode.desktop"
      else
        tar -xzf "$src"

        mkdir -p "$out/Applications"
        cp -R OpenCode.app "$out/Applications/"
        desktopBinary="$out/Applications/OpenCode.app/Contents/MacOS/OpenCode"
      fi

      makeBinaryWrapper "$desktopBinary" "$out/bin/${binName}" \
        ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath linuxLibs}"''} \
        ${lib.optionalString stdenv.hostPlatform.isLinux ''--set OC_ALLOW_WAYLAND 1''}

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenCode Desktop - AI coding assistant GUI";
      homepage = "https://opencode.ai";
      license = licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      mainProgram = binName;
    };
  }
