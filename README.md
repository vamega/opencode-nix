# opencode-nix

Always up-to-date Nix package for [OpenCode](https://opencode.ai) - the open source AI coding agent.

New OpenCode releases are checked once per day and published as versioned source releases.

## Why?

OpenCode is distributed as a pre-built binary via GitHub releases and npm. While `nixpkgs` has an OpenCode package, updates depend on upstream PR review cycles which can take days. This flake:

- **Checks for new releases daily**, validates the CLI and desktop packages on Linux and macOS, then publishes a versioned source release
- **Fetches native binaries** directly from GitHub releases - no build from source needed
- **Patches for NixOS** via `autoPatchelfHook` so the binary just works
- **Provides an overlay** so `pkgs.opencode` slots into any Nix config

## Quick Start

```bash
# Try it without installing
nix run github:vamega/opencode-nix
nix run github:vamega/opencode-nix#opencode-desktop

# Install to your profile
nix profile install github:vamega/opencode-nix
nix profile install github:vamega/opencode-nix#opencode-desktop

# Update later
nix profile upgrade '.*opencode.*'
```

## Usage

### shell.nix

```nix
{ pkgs ? import <nixpkgs> {
    overlays = [
      (builtins.getFlake "github:vamega/opencode-nix").overlays.default
    ];
  }
}:

pkgs.mkShell {
  packages = [ pkgs.opencode ];
}
```

### flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:vamega/opencode-nix";
  };

  outputs = { nixpkgs, opencode, ... }: {
    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ opencode.overlays.default ];
      };
    in pkgs.mkShell {
      packages = [ pkgs.opencode ];
    };
  };
}
```

### Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    opencode.url = "github:vamega/opencode-nix";
  };

  outputs = { nixpkgs, home-manager, opencode, ... }: {
    homeConfigurations."you" = home-manager.lib.homeManagerConfiguration {
      modules = [{
        nixpkgs.overlays = [ opencode.overlays.default ];
        home.packages = [ pkgs.opencode ];
      }];
    };
  };
}
```

### NixOS

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:vamega/opencode-nix";
  };

  outputs = { nixpkgs, opencode, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
        nixpkgs.overlays = [ opencode.overlays.default ];
        environment.systemPackages = [ pkgs.opencode ];
      }];
    };
  };
}
```

## Supported Platforms

CLI package (`opencode`):

| Platform | Architecture | Archive |
|----------|-------------|---------|
| Linux | x86_64 | `.tar.gz` |
| Linux | aarch64 | `.tar.gz` |
| macOS | x86_64 (Intel) | `.zip` |
| macOS | aarch64 (Apple Silicon) | `.zip` |

Desktop package (`opencode-desktop`):

| Platform | Architecture | Archive |
|----------|-------------|---------|
| Linux | x86_64 | `.deb` |
| Linux | aarch64 | `.deb` |
| macOS | x86_64 (Intel) | `.app.tar.gz` |
| macOS | aarch64 (Apple Silicon) | `.app.tar.gz` |

## How Updates Work

A GitHub Actions workflow checks once per day:

1. Queries the [anomalyco/opencode](https://github.com/anomalyco/opencode) releases API for the latest version
2. Compares against the version in `package.nix`
3. If newer, refreshes the pinned hashes for the CLI and desktop assets on all four supported systems
4. Builds and validates the CLI and desktop packages on Linux and macOS
5. Commits the package version and publishes a versioned GitHub source release

The packages fetch OpenCode's upstream release binaries when users build them. CI does not publish or require a binary cache.

## Development

```bash
# Clone
git clone https://github.com/vamega/opencode-nix
cd opencode-nix

# Build locally
nix build
./result/bin/opencode --version

# Check for updates
./scripts/update-version.sh --check

# Update to latest
./scripts/update-version.sh

# Update to a specific version
./scripts/update-version.sh --version 1.2.0
```

## Acknowledgements

Inspired by [sadjow/claude-code-nix](https://github.com/sadjow/claude-code-nix), which does the same thing for Claude Code.

## License

MIT. OpenCode itself is [MIT licensed](https://github.com/anomalyco/opencode/blob/dev/LICENSE).
