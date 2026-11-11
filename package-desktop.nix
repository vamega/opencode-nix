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
  version = "2.2.7";

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
    "linux-amd64" = "sha256-Iogf+2Esut5o5C3SYFC7kT/Xq7ly0m7nYFF0Iwgte+U=";
    "linux-arm64" = "sha256-qY9+MbSNovQ7coVM/Ut78Vy9HcMEbzmFM+5+5zD5y/k=";
    "mac-x64" = "sha256-SaXXMPW13lysmwWXgrUjfZ/T45HAOarDdeFI/R/dtQk=";
    "mac-arm64" = "sha256-1Rm0gjliUMT/b+QBzf1crZMvikZPqkbbLEXqIrRbZJg=";
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
        desktopBinary="$out/lib/opencode-desktop/OpenCode/ai.opencode"
        if [ ! -x "$desktopBinary" ]; then
          desktopBinary="$out/lib/opencode-desktop/OpenCode/ai.opencode.desktop"
        fi
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
