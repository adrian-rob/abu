#!/usr/bin/env bash
set -euo pipefail

REDUCERS_DIR="src/process/reducers"
STORE_FILE="src/process/redux/index.ts"
NAME=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    -*) echo "Unknown flag: $arg"; exit 1 ;;
    *) NAME="$arg" ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: abu reducer <n>"
  echo "  e.g. abu reducer user"
  echo "  e.g. abu r accessPoints"
  exit 1
fi

# Convert first letter to uppercase for PascalCase
PASCAL_NAME="$(echo "${NAME:0:1}" | tr '[:lower:]' '[:upper:]')${NAME:1}"

DIR="$REDUCERS_DIR/$NAME"

# ─── Step 1: Create reducer folder + index.ts ─────────
if [ -d "$DIR" ]; then
  echo "❌ Reducer already exists: $DIR"
  exit 1
fi

mkdir -p "$DIR"

cat > "$DIR/index.ts" <<EOF
import { createSlice } from '@reduxjs/toolkit';

import { updateProps } from '../shared';

interface ${PASCAL_NAME}State {}

const initialState = {};

const ${NAME}Slice = createSlice({
  name: '${NAME}',
  initialState,
  reducers: {
    updateProps,
  },
});

export const ${NAME}Actions = ${NAME}Slice.actions;

export default ${NAME}Slice;
EOF

echo "✅ Created reducer: $DIR/index.ts"

# ─── Step 2: Update reducers barrel ───────────────────
BARREL="$REDUCERS_DIR/index.ts"
TMPFILE=$(mktemp)

# Find all reducer folders (exclude shared)
REDUCERS=$(find "$REDUCERS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "shared" -exec basename {} \; 2>/dev/null | sort)

# Imports sorted by line length
IMPORT_LINES=""
while IFS= read -r reducer; do
  IMPORT_LINES="${IMPORT_LINES}import ${reducer} from './${reducer}';
"
done <<< "$REDUCERS"
echo "$IMPORT_LINES" | sed '/^$/d' | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2- >> "$TMPFILE"

# Exports sorted alphabetically
SORTED_EXPORTS=$(echo "$REDUCERS" | sort -f | tr '\n' ',' | sed 's/,/, /g' | sed 's/, $//')

echo "" >> "$TMPFILE"
echo "export { ${SORTED_EXPORTS} };" >> "$TMPFILE"

mv "$TMPFILE" "$BARREL"
echo "📦 Updated barrel: $BARREL"

# ─── Step 3: Update store ─────────────────────────────
if [ ! -f "$STORE_FILE" ]; then
  echo "⚠️  Store file not found: $STORE_FILE"
  echo "   Please manually import and add the reducer to your store."
  exit 0
fi

node -e "
const fs = require('fs');
const name = '$NAME';
const storeFile = '$STORE_FILE';

let content = fs.readFileSync(storeFile, 'utf8');

// 3a: Update Reducers import
const importRegex = /import\s*\{([^}]+)\}\s*from\s*'Reducers'/;
const importMatch = content.match(importRegex);
if (importMatch) {
  const existing = importMatch[1].split(',').map(s => s.trim()).filter(Boolean);
  if (!existing.includes(name)) {
    existing.push(name);
    existing.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
    content = content.replace(importRegex, 'import { ' + existing.join(', ') + ' } from \'Reducers\'');
  }
}

// 3b: Add to combineReducers
const combineRegex = /(combineReducers\(\{)([\s\S]*?)(\}\))/;
const combineMatch = content.match(combineRegex);
if (combineMatch && !combineMatch[2].includes('[' + name + '.name]')) {
  // Extract existing entries
  const entries = combineMatch[2].match(/\[.*?\.name\]:\s*\w+\.reducer,?/g) || [];
  entries.push('[' + name + '.name]: ' + name + '.reducer,');

  // Sort alphabetically
  entries.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

  const newBlock = 'combineReducers({\n' + entries.map(e => '  ' + e.trim().replace(/,?\$/, ',')).join('\n') + '\n})';
  content = content.replace(combineRegex, newBlock);
}

// 3c: Add to rootReducer reset object (the undefined entries)
// Match the return reducer( block inside the logout check
const resetRegex = /(return reducer\(\s*\{)([\s\S]*?)(\},\s*\{ type: 'app\/RESET' \})/;
const resetMatch = content.match(resetRegex);
if (resetMatch && !resetMatch[2].includes(name + ': undefined') && name !== 'user') {
  // Extract existing undefined entries
  const undefs = resetMatch[2].match(/\w+:\s*undefined,?/g) || [];
  undefs.push(name + ': undefined,');

  // Sort alphabetically
  undefs.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

  // Find the user block if it exists
  const userBlockMatch = resetMatch[2].match(/(user:\s*\{[\s\S]*?\},?)/);
  const userBlock = userBlockMatch ? userBlockMatch[1].trim() : null;

  let newReset = 'return reducer(\n      {\n';
  undefs.forEach(u => {
    newReset += '        ' + u.trim().replace(/,?\$/, ',') + '\n';
  });
  if (userBlock) {
    newReset += '        user: {\n          language: state.user.language,\n          userSession: false,\n        },\n';
  }
  newReset += '      },\n      { type: \'app/RESET\' }';

  content = content.replace(resetRegex, newReset);
}

fs.writeFileSync(storeFile, content);
console.log('🏪 Updated store: ' + storeFile);
" 2>/dev/null || echo "⚠️  Could not update store automatically. Please add the reducer manually."

echo ""
echo "⚠️  Please review $STORE_FILE to ensure the reducer is correctly placed."
