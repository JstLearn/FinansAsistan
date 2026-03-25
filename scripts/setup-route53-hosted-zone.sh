#!/bin/bash
# ============================================================
# Route53 Hosted Zone Oluşturma Script'i
# finansasistan.com için dinamik DNS yönetimi
# ============================================================

set -e

DOMAIN="finansasistan.com"
REGION="eu-central-1"

echo "=========================================="
echo "Route53 Hosted Zone Oluşturma"
echo "Domain: $DOMAIN"
echo "=========================================="
echo ""

# AWS credentials kontrolü
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ AWS credentials bulunamadı!"
    echo "Lütfen AWS_ACCESS_KEY_ID ve AWS_SECRET_ACCESS_KEY environment variable'larını ayarlayın."
    exit 1
fi

# Mevcut hosted zone kontrolü
echo "🔍 Mevcut hosted zone kontrol ediliyor..."
EXISTING_ZONE=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.'].[Id,NameServers]" --output json 2>/dev/null || echo "[]")

if [ "$EXISTING_ZONE" != "[]" ] && [ -n "$EXISTING_ZONE" ]; then
    echo "✅ Hosted zone zaten mevcut!"
    ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.'].Id" --output text | sed 's|/hostedzone/||')
    echo "Zone ID: $ZONE_ID"
    echo ""
    echo "📋 Name Server'lar:"
    aws route53 get-hosted-zone --id "$ZONE_ID" --query "DelegationSet.NameServers" --output table
    echo ""
    echo "✅ Bu name server'ları Odeaweb'e ekleyin!"
    exit 0
fi

# Yeni hosted zone oluştur
echo "📝 Yeni hosted zone oluşturuluyor..."
ZONE_RESPONSE=$(aws route53 create-hosted-zone \
    --name "$DOMAIN" \
    --caller-reference "finans-asistan-$(date +%s)" \
    --hosted-zone-config Comment="FinansAsistan Dynamic DNS" \
    --output json)

ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.HostedZone.Id' | sed 's|/hostedzone/||')
NAME_SERVERS=$(echo "$ZONE_RESPONSE" | jq -r '.DelegationSet.NameServers[]')

echo ""
echo "✅ Hosted zone başarıyla oluşturuldu!"
echo "Zone ID: $ZONE_ID"
echo ""
echo "=========================================="
echo "📋 ODEAWEB'E EKLENECEK NAME SERVER'LAR:"
echo "=========================================="
echo ""
for ns in $NAME_SERVERS; do
    echo "$ns"
done
echo ""
echo "=========================================="
echo ""
echo "ℹ️  Bu name server'ları Odeaweb panelinden ekleyin:"
echo "   Odeaweb → Domain → finansasistan.com → İsim Sunucuları"
echo ""
echo "⏱️  DNS yayılımı 5 dakika - 24 saat sürebilir."

