#!/usr/bin/env bash
# setup_xcode.sh
# Erstellt das Xcode-Projekt (xcodeproj) aus dem Swift Package.
# Voraussetzung: Xcode Command Line Tools installiert.
#
# Verwendung:
#   chmod +x setup_xcode.sh
#   ./setup_xcode.sh

set -e

PROJECT="iMailSecure"
BUNDLE_ID="io.imailsecure.app"
TEAM_ID="DEIN_TEAM_ID"   # ← Hier deine Apple Developer Team-ID eintragen

echo "▶ Abhängigkeiten auflösen…"
swift package resolve

echo "▶ Xcode-Projektdatei generieren…"
# Erfordert: gem install xcodeproj   ODER   mint install tuist/tuist
# Option A: Mit 'xcodegen' (empfohlen)
if command -v xcodegen &> /dev/null; then
    xcodegen generate --spec project.yml
    echo "✅ Xcode-Projekt mit XcodeGen erstellt."
else
    echo "⚠️  XcodeGen nicht gefunden."
    echo "   Installiere es mit: brew install xcodegen"
    echo "   Danach: xcodegen generate --spec project.yml"
fi

echo ""
echo "📋 Nächste Schritte:"
echo "   1. open ${PROJECT}.xcodeproj"
echo "   2. Signing & Capabilities → Team: ${TEAM_ID} eintragen"
echo "   3. Bundle Identifier: ${BUNDLE_ID}"
echo "   4. Entitlements-Datei verknüpfen: Sources/iMailSecure/Resources/iMailSecure.entitlements"
echo "   5. CoreData-Modell hinzufügen: Sources/iMailSecure/Resources/iMailSecure.xcdatamodeld"
echo "   6. App-Icons in AppIcon.appiconset/ hinterlegen"
echo "   7. cmd+B → Build testen"
