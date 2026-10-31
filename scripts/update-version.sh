#!/usr/bin/env bash
set -euo pipefail

# Update OpenCode version in package.nix and package-desktop.nix
# Usage:
#   ./scripts/update-version.sh              # Update to latest
#   ./scripts/update-version.sh --check      # Check if update available
#   ./scripts/update-version.sh --latest      # Print latest stable version
#   ./scripts/update-version.sh --version X  # Update to specific version

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_only=false
print_latest=false
target_version=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) check_only=true; shift ;;
        --latest) print_latest=true; shift ;;
        --version) target_version="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--check] [--latest] [--version VERSION]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

current_version=$(grep -oP 'version = "\K[^"]+' "$REPO_DIR/package.nix" | head -1)
latest_version() {
    gh api 'repos/anomalyco/opencode/releases?per_page=100' --jq '
      [ .[]
        | select(.draft == false and .prerelease == false)
        | .tag_name
        | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))
        | ltrimstr("v")
        | split(".")
        | map(tonumber)
      ]
      | sort
      | last
      | map(tostring)
      | join(".")
    '
}

[[ -z "$target_version" ]] && target_version=$(latest_version)
if [[ -z "$target_version" || "$target_version" == "null" ]]; then
    echo "Could not determine the latest stable OpenCode release" >&2
    exit 1
fi
[[ "$print_latest" == "true" ]] && { echo "$target_version"; exit 0; }

echo "Current: $current_version -> Target: $target_version"

[[ "$current_version" == "$target_version" ]] && { echo "Already up to date!"; exit 0; }
[[ "$check_only" == "true" ]] && exit 0

fetch_hash() {
    nix store prefetch-file --json "$1" | jq -er '.hash'
}

release_json=$(gh api "repos/anomalyco/opencode/releases/tags/v${target_version}")

asset_hash() {
    local asset="$1" digest
    digest=$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest // empty' <<<"$release_json" 2>/dev/null || true)
    if [[ "$digest" == sha256:* ]]; then
        nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}"
    else
        fetch_hash "https://github.com/anomalyco/opencode/releases/download/v${target_version}/${asset}"
    fi
}

update_hash() {
    local file="$1" platform="$2" hash="$3"
    sed -i "s|\"${platform}\"[[:space:]]*= \"[^\"]*\"|\"${platform}\" = \"${hash}\"|" "$file"
}

echo "Fetching hashes..."

# CLI package
for platform in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
    ext=$([[ "$platform" == darwin* ]] && echo "zip" || echo "tar.gz")
    hash=$(asset_hash "opencode-${platform}.${ext}")
    echo "  $platform: $hash"
    update_hash "$REPO_DIR/package.nix" "$platform" "$hash"
done

# Desktop package. The upstream macOS asset names use mac-x64/mac-arm64,
# while Linux uses linux-amd64/linux-arm64.
declare -A desktop_ext=(
    ["linux-amd64"]="deb"
    ["linux-arm64"]="deb"
    ["mac-x64"]="app.tar.gz"
    ["mac-arm64"]="app.tar.gz"
)
for platform in "${!desktop_ext[@]}"; do
    hash=$(asset_hash "opencode-desktop-${platform}.${desktop_ext[$platform]}")
    echo "  desktop $platform: $hash"
    update_hash "$REPO_DIR/package-desktop.nix" "$platform" "$hash"
done

# Update versions
sed -i "s/version = \"${current_version}\"/version = \"${target_version}\"/" "$REPO_DIR/package.nix" "$REPO_DIR/package-desktop.nix"

echo "Done! Test with: nix build .#opencode .#opencode-desktop"
