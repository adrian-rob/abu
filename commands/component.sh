#!/usr/bin/env bash
set -euo pipefail

# ─── Usage ───────────────────────────────────────────
# ./gen-component.sh <ComponentName> [--connect]
# ─────────────────────────────────────────────────────

CONNECT=false
NAME=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    --connect) CONNECT=true ;;
    -*) echo "Unknown flag: $arg"; exit 1 ;;
    *) NAME="$arg" ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: ./gen-component.sh <ComponentName> [--connect]"
  exit 1
fi

DIR="src/show/components/$NAME"

if [ -d "$DIR" ]; then
  echo "❌ Directory already exists: $DIR"
  exit 1
fi

mkdir -p "$DIR"

if [ "$CONNECT" = true ]; then
  # ── index.ts (Redux connect wrapper) ──
  cat > "$DIR/index.ts" <<EOF
import { connect } from 'react-redux';
import { RootState } from 'Redux';

import ${NAME} from './view';

export default connect(
  (state: RootState | any) => ({
  }),
  {},
)(${NAME});
EOF

  # ── view.tsx (Component) ──
  cat > "$DIR/view.tsx" <<EOF
interface ${NAME}Props {}

const ${NAME} = ({}: ${NAME}Props) => {
};

export default ${NAME};
EOF

  echo "✅ Created connected component: $DIR"
  echo "   ├── index.ts"
  echo "   └── view.tsx"

else
  # ── index.tsx (Standalone component) ──
  cat > "$DIR/index.tsx" <<EOF
interface ${NAME}Props {}

const ${NAME} = ({}: ${NAME}Props) => {
};

export default ${NAME};
EOF

  echo "✅ Created component: $DIR"
  echo "   └── index.tsx"
fi

# ─── Update barrel index.ts ─────────────────────────
BARREL="src/show/components/index.ts"
NEW_IMPORT="import ${NAME} from './${NAME}';"

if [ -f "$BARREL" ]; then
  # Add new import to existing imports, re-sort by line length
  # Extract existing import lines, append new one, sort by length
  IMPORTS=$(grep "^import " "$BARREL" | grep -v "^import ${NAME} from" || true)
  IMPORTS=$(printf "%s\n%s" "$IMPORTS" "$NEW_IMPORT" | sed '/^$/d' | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2-)

  # Extract existing export names, add new one, sort alphabetically
  EXPORTS=$(sed -n '/^export {/,/^};/p' "$BARREL" | grep -v "^export {" | grep -v "^};" | tr -d ' ,' | sed '/^$/d' || true)
  EXPORTS=$(printf "%s\n%s" "$EXPORTS" "$NAME" | sed '/^$/d' | sort -fu)

else
  IMPORTS="$NEW_IMPORT"
  EXPORTS="$NAME"
fi

# Format exports as indented, comma-separated lines
FORMATTED_EXPORTS=$(echo "$EXPORTS" | sed 's/^/  /' | sed 's/$/,/')

# Write the barrel file
cat > "$BARREL" <<EOF
${IMPORTS}

export {
${FORMATTED_EXPORTS}
};
EOF

echo "📦 Updated barrel: $BARREL"
