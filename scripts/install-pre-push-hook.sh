#!/bin/bash
# Install pre-push git hook to automatically sync k8s files
# This prevents merge conflicts when GitHub Actions workflow updates k8s files

echo "🔧 Installing pre-push git hook..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SOURCE="$SCRIPT_DIR/pre-push-hook"
HOOK_TARGET="$(git rev-parse --git-dir)/hooks/pre-push"

if [ ! -f "$HOOK_SOURCE" ]; then
    echo "❌ Hook source file not found: $HOOK_SOURCE"
    exit 1
fi

# Copy hook to .git/hooks
cp "$HOOK_SOURCE" "$HOOK_TARGET"
chmod +x "$HOOK_TARGET"

if [ -f "$HOOK_TARGET" ]; then
    echo "✅ Pre-push hook installed successfully!"
    echo "📍 Location: $HOOK_TARGET"
    echo ""
    echo "💡 The hook will automatically sync k8s files before pushing to master/main"
else
    echo "❌ Failed to install hook"
    exit 1
fi

