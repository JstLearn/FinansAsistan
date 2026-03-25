#!/bin/bash
# ════════════════════════════════════════════════════════════
# GitHub Default Branch Değiştirme ve Master Silme Script'i
# ════════════════════════════════════════════════════════════

# GitHub repository bilgileri
REPO_OWNER="JstLearn"
REPO_NAME="FinansAsistan"
NEW_DEFAULT_BRANCH="main"
OLD_BRANCH="master"

echo "═══════════════════════════════════════════════════════════"
echo "  GitHub Repository Ayarları"
echo "═══════════════════════════════════════════════════════════"
echo ""

# GitHub Personal Access Token kontrolü
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "⚠️  GITHUB_TOKEN environment variable bulunamadı!"
    echo ""
    echo "GitHub Personal Access Token oluşturun:"
    echo "1. https://github.com/settings/tokens adresine gidin"
    echo "2. 'Generate new token (classic)' tıklayın"
    echo "3. 'repo' scope'unu seçin"
    echo "4. Token'ı kopyalayın"
    echo ""
    echo "Sonra şu komutu çalıştırın:"
    echo "  export GITHUB_TOKEN=your_token_here"
    echo "  ./scripts/change-default-branch.sh"
    echo ""
    exit 1
fi

echo "✅ GitHub Token bulundu"
echo ""

# 1. Default branch'ı main'e değiştir
echo "📝 Default branch'ı 'main' olarak değiştiriliyor..."
RESPONSE=$(curl -s -X PATCH \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}" \
  -d "{\"default_branch\":\"${NEW_DEFAULT_BRANCH}\"}")

if echo "$RESPONSE" | grep -q "default_branch"; then
    echo "✅ Default branch 'main' olarak değiştirildi"
else
    echo "❌ Hata: Default branch değiştirilemedi"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""

# 2. Master branch'ı sil
echo "🗑️  'master' branch'ı siliniyor..."
DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/refs/heads/${OLD_BRANCH}")

HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$DELETE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "204" ]; then
    echo "✅ 'master' branch başarıyla silindi"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  'master' branch zaten yok"
else
    echo "❌ Hata: 'master' branch silinemedi (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Repository ayarları:"
echo "  Default Branch: ${NEW_DEFAULT_BRANCH}"
echo "  Silinen Branch: ${OLD_BRANCH}"
echo ""

