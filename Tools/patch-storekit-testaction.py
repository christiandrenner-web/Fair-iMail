#!/usr/bin/env python3
"""Trägt die StoreKit-Testkonfiguration in die Test-Action des Schemas ein.

XcodeGen (2.46) schreibt `storeKitConfiguration` nur in die Launch-Action.
Für UI-Tests muss die Konfiguration aber auch in der Test-Action stehen,
sonst lädt die App unter dem Test keine Testprodukte.

Das Skript ist idempotent und wird von `options.postGenCommand` nach jedem
`xcodegen generate` ausgeführt.
"""

import pathlib
import sys

SCHEME = pathlib.Path(__file__).resolve().parent.parent / \
    "iMailSecure.xcodeproj/xcshareddata/xcschemes/iMailSecure.xcscheme"

# Pfad relativ zum Scheme-Ordner (xcshareddata/xcschemes) bis zum
# Projektordner: drei Ebenen hoch.
IDENTIFIER = "../../../iMailSecure.storekit"

BLOCK = f"""      <StoreKitConfigurationFileReference
         identifier = "{IDENTIFIER}">
      </StoreKitConfigurationFileReference>
"""


def main() -> int:
    if not SCHEME.exists():
        print(f"Schema nicht gefunden: {SCHEME}", file=sys.stderr)
        return 1

    text = SCHEME.read_text(encoding="utf-8")
    start = text.find("<TestAction")
    end = text.find("</TestAction>")
    if start == -1 or end == -1:
        print("TestAction im Schema nicht gefunden", file=sys.stderr)
        return 1

    test_action = text[start:end]
    if "StoreKitConfigurationFileReference" in test_action:
        if IDENTIFIER in test_action:
            return 0
        # Falscher Pfad aus einer früheren Fassung: ersetzen.
        begin = test_action.find("<StoreKitConfigurationFileReference")
        finish = test_action.find("</StoreKitConfigurationFileReference>") + len(
            "</StoreKitConfigurationFileReference>")
        test_action = test_action[:begin] + BLOCK.strip() + test_action[finish:]
        SCHEME.write_text(text[:start] + test_action + text[end:], encoding="utf-8")
        return 0

    macro = test_action.find("      <MacroExpansion>")
    if macro == -1:
        print("MacroExpansion in der TestAction nicht gefunden", file=sys.stderr)
        return 1

    patched = test_action[:macro] + BLOCK + test_action[macro:]
    SCHEME.write_text(text[:start] + patched + text[end:], encoding="utf-8")
    print("StoreKit-Konfiguration in die Test-Action eingetragen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
