#!/bin/bash
# Sync k8s deployment files from remote to avoid merge conflicts
# This script pulls the latest k8s files updated by GitHub Actions workflow

BRANCH=${1:-master}

echo "🔄 Syncing k8s deployment files from remote..."

# Fetch latest changes
echo "📥 Fetching latest changes from remote..."
git fetch origin "$BRANCH" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Failed to fetch from remote"
    exit 1
fi

# K8s deployment files that are updated by GitHub Actions workflow
K8S_FILES=(
    "k8s/04-backend-deployment.yaml"
    "k8s/05-frontend-deployment.yaml"
    "k8s/11-event-processor.yaml"
    "k8s/13-argocd-application.yaml"
)

NEEDS_UPDATE=false

# Check if files have changed on remote
for file in "${K8S_FILES[@]}"; do
    if [ -f "$file" ]; then
        REMOTE_FILE="origin/$BRANCH:$file"
        if ! git diff --quiet "HEAD" "$REMOTE_FILE" 2>/dev/null; then
            NEEDS_UPDATE=true
            echo "⚠️  $file has been updated on remote"
        fi
    fi
done

if [ "$NEEDS_UPDATE" = true ]; then
    echo "📥 Pulling latest k8s deployment files..."
    
    # Stash any local changes to k8s files
    HAS_STASH=false
    for file in "${K8S_FILES[@]}"; do
        if [ -f "$file" ]; then
            if ! git diff --quiet "$file" 2>/dev/null || ! git diff --cached --quiet "$file" 2>/dev/null; then
                echo "💾 Stashing local changes to $file..."
                git stash push -m "Auto-stash: sync k8s files" "$file" 2>/dev/null
                HAS_STASH=true
            fi
        fi
    done
    
    # Pull latest k8s files from remote
    for file in "${K8S_FILES[@]}"; do
        REMOTE_FILE="origin/$BRANCH:$file"
        if git show "$REMOTE_FILE" >/dev/null 2>&1; then
            echo "✅ Updating $file"
            git checkout "$REMOTE_FILE" -- "$file" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "   ✅ $file updated successfully"
            else
                echo "   ⚠️  Failed to update $file"
            fi
        fi
    done
    
    if [ "$HAS_STASH" = true ]; then
        echo ""
        echo "💡 Local changes were stashed. Use 'git stash pop' to restore them if needed."
    fi
    
    echo ""
    echo "✅ K8s files synced successfully!"
    echo "💡 Review changes with: git diff"
else
    echo "✅ K8s files are already up to date"
fi

