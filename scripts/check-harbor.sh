#!/bin/bash

HARBOR_URL="http://34.32.141.92:30083"
PROJECT="javdes"

echo "🐳 Checking Harbor registry for bankapp images..."
echo "=================================================="

# Check if we can access Harbor
echo "📡 Testing Harbor connectivity..."
if curl -s -f "$HARBOR_URL" > /dev/null; then
    echo "✅ Harbor is accessible at $HARBOR_URL"
else
    echo "❌ Harbor is not accessible at $HARBOR_URL"
    exit 1
fi

echo ""
echo "🏷️  Available images in project '$PROJECT':"
echo "=================================================="

# Use Harbor API to list repositories
curl -s -u admin:Harbor12345 "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories" | jq -r '.[] | .name' 2>/dev/null || {
    echo "Note: jq not available or API error. Try manual check:"
    echo "Visit: $HARBOR_URL"
    echo "Login: admin / Harbor12345"
    echo "Navigate to Projects -> $PROJECT"
}

echo ""
echo "🔍 Checking for bankapp repository specifically..."
REPO_CHECK=$(curl -s -u admin:Harbor12345 "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories/bankapp" 2>/dev/null)
if echo "$REPO_CHECK" | grep -q "bankapp"; then
    echo "✅ bankapp repository exists"
    
    echo ""
    echo "🏷️  Available tags:"
    curl -s -u admin:Harbor12345 "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories/bankapp/artifacts" | jq -r '.[] | .tags[]?.name // "no-tags"' 2>/dev/null || {
        echo "Use Harbor web UI to check tags"
    }
else
    echo "❌ bankapp repository does not exist yet"
    echo "This is normal if GitHub Actions haven't completed yet"
fi

echo ""
echo "🔗 Harbor Web UI: $HARBOR_URL"
echo "📊 Check GitHub Actions: https://github.com/$(basename $(git remote get-url origin) .git)/actions"
