#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# release.sh — Bump version, commit, tag, and push to trigger release
#
# Usage:
#   ./scripts/release.sh patch    # 0.1.0 → 0.1.1 (bug fixes)
#   ./scripts/release.sh minor    # 0.1.0 → 0.2.0 (new features)
#   ./scripts/release.sh major    # 0.1.0 → 1.0.0 (breaking changes)
#
# What it does:
#   1. Bumps MARKETING_VERSION in project.yml
#   2. Increments CURRENT_PROJECT_VERSION (build number)
#   3. Commits the change
#   4. Creates an annotated git tag vX.Y.Z
#   5. Pushes commit + tag → triggers GitHub Actions release pipeline
# ------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_YML="$PROJECT_DIR/project.yml"

# --- Validate argument ---
BUMP_TYPE="${1:-}"
if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "Usage: ./scripts/release.sh <patch|minor|major>"
    echo ""
    echo "  patch  — bug fixes, small corrections (0.1.0 → 0.1.1)"
    echo "  minor  — new features, improvements   (0.1.0 → 0.2.0)"
    echo "  major  — breaking changes              (0.1.0 → 1.0.0)"
    exit 1
fi

# --- Check clean working tree ---
cd "$PROJECT_DIR"
if ! git diff --quiet HEAD 2>/dev/null; then
    echo "Error: Working tree has uncommitted changes."
    echo "Commit or stash your changes before releasing."
    exit 1
fi

# --- Read current version ---
CURRENT_VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_YML" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_YML" | head -1 | sed 's/.*: *//')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not read MARKETING_VERSION from project.yml"
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# --- Compute new version ---
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))
TAG="v${NEW_VERSION}"

# --- Check tag doesn't already exist ---
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Tag $TAG already exists."
    exit 1
fi

# --- Confirm ---
echo "Release summary:"
echo "  Version:  $CURRENT_VERSION → $NEW_VERSION ($BUMP_TYPE)"
echo "  Build:    $CURRENT_BUILD → $NEW_BUILD"
echo "  Tag:      $TAG"
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# --- Update project.yml ---
sed -i '' "s/MARKETING_VERSION: \"$CURRENT_VERSION\"/MARKETING_VERSION: \"$NEW_VERSION\"/" "$PROJECT_YML"
sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"

echo "==> Updated project.yml"

# --- Commit, tag, push ---
git add "$PROJECT_YML"
git commit -m "Release v${NEW_VERSION}"
git tag -a "$TAG" -m "Release ${NEW_VERSION}"

echo "==> Created commit and tag $TAG"

git push origin HEAD --tags

echo ""
echo "==> Pushed! GitHub Actions will now build, sign, notarize, and publish the release."
echo "    Track progress: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
