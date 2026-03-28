#!/usr/bin/env bash

# Skip if installed globally
if [ -z "$INIT_CWD" ] || [ ! -f "${INIT_CWD}/package.json" ]; then
  exit 0
fi

HOST_PKG="${INIT_CWD}/package.json"

# Check if "abu" script already exists
if grep -q '"abu"' "$HOST_PKG" 2>/dev/null; then
  exit 0
fi

# Use node to safely add the script
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('$HOST_PKG', 'utf8'));
if (!pkg.scripts) pkg.scripts = {};
if (!pkg.scripts.abu) {
  pkg.scripts.abu = 'abu';
  fs.writeFileSync('$HOST_PKG', JSON.stringify(pkg, null, 2) + '\n');
  console.log('✅ Added \"abu\" script to package.json');
}
"