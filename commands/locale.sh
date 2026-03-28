#!/usr/bin/env bash
set -euo pipefail

LOCALES_DIR="src/process/locales"
NAME=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    -*) echo "Unknown flag: $arg"; exit 1 ;;
    *) NAME="$arg" ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: abu locale <name>"
  echo "  e.g. abu locale toast"
  echo "  e.g. abu l accessPoints"
  exit 1
fi

# Check if locales directory exists
if [ ! -d "$LOCALES_DIR" ]; then
  echo "❌ Locales directory not found: $LOCALES_DIR"
  echo "   Please create it with at least one language folder (e.g. en, sr)"
  exit 1
fi

# Find all language folders
LANGS=$(find "$LOCALES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)

if [ -z "$LANGS" ]; then
  echo "❌ No language folders found in $LOCALES_DIR"
  echo "   Please create at least one language folder (e.g. en, sr)"
  exit 1
fi

# Step 1: Create the JSON file in all language folders
for LANG in $LANGS; do
  LANG_DIR="$LOCALES_DIR/$LANG"
  JSON_FILE="$LANG_DIR/$NAME.json"

  if [ -f "$JSON_FILE" ]; then
    echo "⚠️  Already exists: $JSON_FILE (skipped)"
  else
    echo "{}" > "$JSON_FILE"
    echo "✅ Created: $JSON_FILE"
  fi
done

# Step 2: Update index.ts for each language folder
for LANG in $LANGS; do
  LANG_DIR="$LOCALES_DIR/$LANG"
  BARREL="$LANG_DIR/index.ts"

  # Find all JSON files in this language folder
  JSON_FILES=$(find "$LANG_DIR" -maxdepth 1 -name "*.json" -exec basename {} .json \; 2>/dev/null | sort)
  [ -z "$JSON_FILES" ] && continue

  TMPFILE=$(mktemp)

  # Imports sorted by line length
  IMPORT_LINES=""
  while IFS= read -r file; do
    IMPORT_LINES="${IMPORT_LINES}import ${file} from './${file}.json';
"
  done <<< "$JSON_FILES"
  echo "$IMPORT_LINES" | sed '/^$/d' | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2- >> "$TMPFILE"

  # Exports sorted alphabetically
  SORTED_EXPORTS=$(echo "$JSON_FILES" | sort -f | tr '\n' ',' | sed 's/,/, /g' | sed 's/, $//')

  echo "" >> "$TMPFILE"
  echo "const ${LANG} = { ${SORTED_EXPORTS} };" >> "$TMPFILE"
  echo "" >> "$TMPFILE"
  echo "export default ${LANG};" >> "$TMPFILE"

  mv "$TMPFILE" "$BARREL"
  echo "📦 Updated barrel: $BARREL"
done
