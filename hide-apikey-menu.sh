#!/bin/bash

# Protection Script: Hide API Key Menu from UI
# By @baniwwwXD
# GitHub: github.com/Xbanz22
# Repo: security-pterodactyl-baniww

# This script completely hides the API Key menu from the panel UI

ACCOUNT_OVERVIEW_PATH="/var/www/pterodactyl/resources/scripts/components/dashboard/AccountOverviewContainer.tsx"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${ACCOUNT_OVERVIEW_PATH}.bak_${TIMESTAMP}"

clear
echo "════════════════════════════════════════════"
echo "  🙈 HIDE API KEY MENU FROM UI"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""
echo "This script will HIDE the API Key menu from"
echo "the panel interface for ALL users."
echo ""
echo "⚠️  NOTE: Super admin (ID 1) can still access"
echo "    API keys via direct URL if needed."
echo ""
read -p "Continue? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Installation cancelled."
    exit 1
fi

echo ""
echo "📦 Backing up original file..."
if [ -f "$ACCOUNT_OVERVIEW_PATH" ]; then
    cp "$ACCOUNT_OVERVIEW_PATH" "$BACKUP_PATH"
    echo "✅ Backup created: $(basename $BACKUP_PATH)"
else
    echo "❌ Error: File not found at $ACCOUNT_OVERVIEW_PATH"
    exit 1
fi

echo ""
echo "🔧 Modifying UI to hide API Key menu..."

# Remove API Key link from navigation
sed -i '/API Keys/d' "$ACCOUNT_OVERVIEW_PATH"
sed -i '/api-keys/d' "$ACCOUNT_OVERVIEW_PATH"
sed -i '/NavLink.*account\/api/d' "$ACCOUNT_OVERVIEW_PATH"

echo "✅ UI modified successfully!"
echo ""
echo "🔨 Building production assets..."
cd /var/www/pterodactyl

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build production
echo "🔨 Building..."
npm run build:production

echo "✅ Build complete!"
echo ""
echo "🔄 Clearing Laravel cache..."
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1

echo "✅ Cache cleared!"
echo ""
echo "════════════════════════════════════════════"
echo "  ✅ API KEY MENU HIDDEN"
echo "════════════════════════════════════════════"
echo ""
echo "📊 Changes Applied:"
echo "  • API Key menu removed from UI"
echo "  • Link hidden from navigation"
echo "  • Regular users cannot see menu"
echo ""
echo "💡 Super Admin Access:"
echo "  Direct URL: /account/api"
echo "  (Only if you also use protect-apikey.sh)"
echo ""
echo "💾 Backup saved at:"
echo "  $(basename $BACKUP_PATH)"
echo ""
echo "🔓 To restore original UI:"
echo "  mv $BACKUP_PATH $ACCOUNT_OVERVIEW_PATH"
echo "  cd /var/www/pterodactyl && npm run build:production"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
