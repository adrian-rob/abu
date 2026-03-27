#!/usr/bin/env bash
set -euo pipefail

# ─── Usage ───────────────────────────────────────────
# ./gen-page.sh <PageName> [--connect] [--<scope>]
# Any --flag (except --connect) becomes the subfolder.
# Default folder: shared
# ─────────────────────────────────────────────────────

CONNECT=false
SCOPE="shared"
NAME=""

# ─── Helper functions ────────────────────────────────
# CamelCase → SCREAMING_SNAKE_CASE (e.g. AccessPoints → ACCESS_POINTS)
to_snake_upper() {
  echo "$1" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:lower:]' '[:upper:]'
}

# CamelCase → kebab-case (e.g. AccessPoints → access-points)
to_kebab() {
  echo "$1" | sed 's/\([A-Z]\)/-\1/g' | sed 's/^-//' | tr '[:upper:]' '[:lower:]'
}

# Parse args
for arg in "$@"; do
  case "$arg" in
    --connect) CONNECT=true ;;
    --*) SCOPE="${arg#--}" ;;
    *) NAME="$arg" ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: ./gen-page.sh <PageName> [--connect] [--<scope>]"
  echo "  e.g. ./gen-page.sh Login --public --connect"
  echo "  e.g. ./gen-page.sh Dashboard --admin"
  echo "  No scope flag defaults to 'shared'"
  exit 1
fi

DIR="src/show/pages/$SCOPE/$NAME"

if [ -d "$DIR" ]; then
  echo "❌ Directory already exists: $DIR"
  exit 1
fi

mkdir -p "$DIR"

if [ "$CONNECT" = true ]; then
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

  cat > "$DIR/view.tsx" <<EOF
interface ${NAME}Props {}

const ${NAME} = ({}: ${NAME}Props) => {
};

export default ${NAME};
EOF

  echo "✅ Created connected page: $DIR"
  echo "   ├── index.ts"
  echo "   └── view.tsx"

else
  cat > "$DIR/index.tsx" <<EOF
interface ${NAME}Props {}

const ${NAME} = ({}: ${NAME}Props) => {
};

export default ${NAME};
EOF

  echo "✅ Created page: $DIR"
  echo "   └── index.tsx"
fi

# ─── Update barrel index.ts ─────────────────────────
BARREL="src/show/pages/index.ts"
TMPFILE=$(mktemp)
PAGES_DIR="src/show/pages"

# Discover all scope folders dynamically, sorted alphabetically
SCOPES=$(find "$PAGES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

FIRST_SECTION=true

for SECTION in $SCOPES; do
  SECTION_DIR="$PAGES_DIR/$SECTION"

  COMPONENTS=$(find "$SECTION_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
  [ -z "$COMPONENTS" ] && continue

  SECTION_UPPER=$(echo "$SECTION" | tr '[:lower:]' '[:upper:]')

  # Blank line between sections (not before first)
  if [ "$FIRST_SECTION" = true ]; then
    FIRST_SECTION=false
  else
    echo "" >> "$TMPFILE"
  fi

  # Imports sorted by line length
  echo "//${SECTION_UPPER}" >> "$TMPFILE"
  IMPORT_LINES=""
  while IFS= read -r comp; do
    IMPORT_LINES="${IMPORT_LINES}import ${comp} from './${SECTION}/${comp}';
"
  done <<< "$COMPONENTS"
  echo "$IMPORT_LINES" | sed '/^$/d' | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2- >> "$TMPFILE"

done

# Export block
echo "" >> "$TMPFILE"
echo "export default {" >> "$TMPFILE"

for SECTION in $SCOPES; do
  SECTION_DIR="$PAGES_DIR/$SECTION"

  COMPONENTS=$(find "$SECTION_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
  [ -z "$COMPONENTS" ] && continue

  SECTION_UPPER=$(echo "$SECTION" | tr '[:lower:]' '[:upper:]')

  echo "  ${SECTION_UPPER}: {" >> "$TMPFILE"
  echo "$COMPONENTS" | sort -f | sed 's/^/    /; s/$/,/' >> "$TMPFILE"
  echo "  }," >> "$TMPFILE"
done

echo "};" >> "$TMPFILE"

mv "$TMPFILE" "$BARREL"
echo "📦 Updated barrel: $BARREL"

# ─── Update paths.ts ────────────────────────────────
PATHS_FILE="src/show/navigator/paths.ts"
mkdir -p "$(dirname "$PATHS_FILE")"

PATHS_TMP=$(mktemp)

# Collect all path entries from the folder structure
ALL_ENTRIES=""
for SECTION in $SCOPES; do
  SECTION_DIR="$PAGES_DIR/$SECTION"
  COMPONENTS=$(find "$SECTION_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
  [ -z "$COMPONENTS" ] && continue

  while IFS= read -r comp; do
    CONST_NAME="$(to_snake_upper "$comp")_PATH"
    KEBAB_PATH="/$(to_kebab "$comp")"
    ALL_ENTRIES="${ALL_ENTRIES}  ${CONST_NAME}: '${KEBAB_PATH}',
"
  done <<< "$COMPONENTS"
done

# If paths.ts exists, preserve any manually added entries (like DEFAULT_PATH)
MANUAL_ENTRIES=""
if [ -f "$PATHS_FILE" ]; then
  # Extract lines inside the PATHS object that we did NOT generate (no matching component folder)
  while IFS= read -r line; do
    KEY=$(echo "$line" | sed -n "s/^[[:space:]]*\([A-Z_]*\):.*/\1/p")
    [ -z "$KEY" ] && continue
    # Check if this key is one we auto-generate
    if ! echo "$ALL_ENTRIES" | grep -q "  ${KEY}:"; then
      MANUAL_ENTRIES="${MANUAL_ENTRIES}${line}
"
    fi
  done < <(sed -n '/^const PATHS/,/^};/p' "$PATHS_FILE" | grep -v "^const PATHS" | grep -v "^};")
fi

# Write paths.ts
{
  echo "const PATHS = {"
  # Manual entries first (like DEFAULT_PATH)
  if [ -n "$MANUAL_ENTRIES" ]; then
    echo -n "$MANUAL_ENTRIES"
  else
    echo "  DEFAULT_PATH: '/',"
  fi
  # Auto-generated entries, sorted alphabetically
  echo -n "$ALL_ENTRIES" | sort
  echo "};"
  echo ""
  echo "export default PATHS;"
} > "$PATHS_TMP"

mv "$PATHS_TMP" "$PATHS_FILE"
echo "🛤️  Updated paths: $PATHS_FILE"

# ─── Update routes.tsx ──────────────────────────────
ROUTES_FILE="src/show/navigator/routes.tsx"
ROUTES_TMP=$(mktemp)

# Preserve everything after the ROUTES object closing '};'
ROUTES_FOOTER=""
if [ -f "$ROUTES_FILE" ]; then
  # Find the line number of the first '};\n' that closes the ROUTES object
  # The ROUTES object starts with 'export const ROUTES' and ends with '};' at column 1
  ROUTES_START=$(grep -n "^export const ROUTES" "$ROUTES_FILE" | head -1 | cut -d: -f1)
  if [ -n "$ROUTES_START" ]; then
    # Find the matching closing '};' — first '};' at start of line after ROUTES_START
    ROUTES_END=$(tail -n +"$((ROUTES_START + 1))" "$ROUTES_FILE" | grep -n "^};" | head -1 | cut -d: -f1)
    if [ -n "$ROUTES_END" ]; then
      ROUTES_END=$((ROUTES_START + ROUTES_END))
      TOTAL_LINES=$(wc -l < "$ROUTES_FILE")
      if [ "$ROUTES_END" -lt "$TOTAL_LINES" ]; then
        ROUTES_FOOTER=$(tail -n +"$((ROUTES_END + 1))" "$ROUTES_FILE")
      fi
    fi
  fi

  # Preserve the header (imports) — everything before 'export const ROUTES'
  if [ -n "$ROUTES_START" ] && [ "$ROUTES_START" -gt 1 ]; then
    head -n "$((ROUTES_START - 1))" "$ROUTES_FILE" > "$ROUTES_TMP"
  else
    # No existing header, write the default
    cat <<'HEADER' > "$ROUTES_TMP"
import { createBrowserRouter, type RouteObject } from 'react-router';

import PATHS from './paths';
import Pages from '../pages';
import Root from './Layouts/Root';
import PublicLayout from './Layouts/PublicLayout';
import ProtectedLayout from './Layouts/ProtectedLayout';

HEADER
  fi
else
  # Brand new file — write default header
  cat <<'HEADER' > "$ROUTES_TMP"
import { createBrowserRouter, type RouteObject } from 'react-router';

import PATHS from './paths';
import Pages from '../pages';
import Root from './Layouts/Root';
import PublicLayout from './Layouts/PublicLayout';
import ProtectedLayout from './Layouts/ProtectedLayout';

HEADER
fi

# Write the ROUTES object
{
  echo "export const ROUTES: Record<string, Record<string, RouteObject>> = {"

  FIRST_SCOPE=true
  for SECTION in $SCOPES; do
    SECTION_DIR="$PAGES_DIR/$SECTION"
    COMPONENTS=$(find "$SECTION_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
    [ -z "$COMPONENTS" ] && continue

    SECTION_UPPER=$(echo "$SECTION" | tr '[:lower:]' '[:upper:]')

    if [ "$FIRST_SCOPE" = true ]; then
      FIRST_SCOPE=false
    else
      echo ""
    fi

    echo "  ${SECTION_UPPER}: {"

    SORTED_COMPS=$(echo "$COMPONENTS" | sort -f)
    while IFS= read -r comp; do
      CONST_NAME="$(to_snake_upper "$comp")_PATH"
      echo "    ${comp}: {"
      echo "      path: PATHS.${CONST_NAME},"
      echo "      element: <Pages.${SECTION_UPPER}.${comp} />,"
      echo "    },"
    done <<< "$SORTED_COMPS"

    echo "  },"
  done

  echo "};"
} >> "$ROUTES_TMP"

# Append preserved footer
if [ -n "$ROUTES_FOOTER" ]; then
  echo "$ROUTES_FOOTER" >> "$ROUTES_TMP"
fi

mv "$ROUTES_TMP" "$ROUTES_FILE"
echo "🗺️  Updated routes: $ROUTES_FILE"
echo ""
echo "⚠️  Note: Route entries have been scaffolded, but this process is not fully automated."
echo "   Please review $ROUTES_FILE and ensure each route is placed in the"
echo "   correct layout (Root, PublicLayout, ProtectedLayout) and order."
