const path = require("path");
const fs = require("fs");
const {
  sortAlpha,
  sortByLength,
  toSnakeUpper,
  toKebab,
  getDirs,
  ensureDir,
  writeFile,
  readFile,
  connectedIndex,
  componentView,
} = require("../utils");

const PAGES_DIR = "src/show/pages";
const PATHS_FILE = "src/show/navigator/paths.ts";
const ROUTES_FILE = "src/show/navigator/routes.tsx";

function page({ name, connect, scope }) {
  scope = scope || "shared";

  if (!name) {
    console.log("Usage: abu page <n> [--connect] [--<scope>]");
    console.log("  e.g. abu page Login --public --connect");
    console.log("  e.g. abu page Dashboard --admin");
    console.log("  No scope flag defaults to 'shared'");
    process.exit(1);
  }

  const dir = path.join(PAGES_DIR, scope, name);

  if (fs.existsSync(dir)) {
    console.log(`❌ Directory already exists: ${dir}`);
    process.exit(1);
  }

  ensureDir(dir);

  if (connect) {
    writeFile(path.join(dir, "index.ts"), connectedIndex(name));
    writeFile(path.join(dir, "view.tsx"), componentView(name));
    console.log(`✅ Created connected page: ${dir}`);
    console.log("   ├── index.ts");
    console.log("   └── view.tsx");
  } else {
    writeFile(path.join(dir, "index.tsx"), componentView(name));
    console.log(`✅ Created page: ${dir}`);
    console.log("   └── index.tsx");
  }

  updateBarrel();
  updatePaths();
  updateRoutes();

  console.log("");
  console.log(
    "⚠️  Note: Route entries have been scaffolded, but this process is not fully automated.",
  );
  console.log(
    `   Please review ${ROUTES_FILE} and ensure each route is placed in the`,
  );
  console.log(
    "   correct layout (Root, PublicLayout, ProtectedLayout) and order.",
  );
}

function updateBarrel() {
  const scopes = getDirs(PAGES_DIR);
  const lines = [];
  const exportSections = [];
  let first = true;

  for (const scope of scopes) {
    const components = getDirs(path.join(PAGES_DIR, scope));
    if (components.length === 0) continue;

    const upper = scope.toUpperCase();

    if (!first) lines.push("");
    first = false;

    // Imports sorted by line length
    lines.push(`//${upper}`);
    const imports = components.map(
      (c) => `import ${c} from './${scope}/${c}';`,
    );
    sortByLength(imports).forEach((i) => lines.push(i));

    // Export section sorted alphabetically
    const sorted = sortAlpha(components);
    exportSections.push(
      `  ${upper}: {\n${sorted.map((c) => `    ${c},`).join("\n")}\n  },`,
    );
  }

  lines.push("");
  lines.push("export default {");
  lines.push(exportSections.join("\n"));
  lines.push("};");
  lines.push("");

  const barrel = path.join(PAGES_DIR, "index.ts");
  writeFile(barrel, lines.join("\n"));
  console.log(`📦 Updated barrel: ${barrel}`);
}

function updatePaths() {
  ensureDir(path.dirname(PATHS_FILE));

  // Collect manual entries from existing file
  let manualEntries = [];
  const existing = readFile(PATHS_FILE);
  if (existing) {
    const match = existing.match(/const PATHS = \{([\s\S]*?)\};/);
    if (match) {
      const entries = match[1]
        .split("\n")
        .map((l) => l.trim())
        .filter((l) => l && l.includes(":"));
      // Collect all auto-generated keys
      const autoKeys = new Set();
      for (const scope of getDirs(PAGES_DIR)) {
        for (const comp of getDirs(path.join(PAGES_DIR, scope))) {
          autoKeys.add(`${toSnakeUpper(comp)}_PATH`);
        }
      }
      manualEntries = entries.filter((e) => {
        const key = e.match(/^(\w+):/);
        return key && !autoKeys.has(key[1]);
      });
    }
  }

  if (manualEntries.length === 0) {
    manualEntries.push("DEFAULT_PATH: '/',");
  }

  // Auto entries from folder structure
  const autoEntries = [];
  for (const scope of getDirs(PAGES_DIR)) {
    for (const comp of getDirs(path.join(PAGES_DIR, scope))) {
      autoEntries.push(`  ${toSnakeUpper(comp)}_PATH: '/${toKebab(comp)}',`);
    }
  }
  autoEntries.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

  const lines = [
    "const PATHS = {",
    ...manualEntries.map((e) => `  ${e}`),
    ...autoEntries,
    "};",
    "",
    "export default PATHS;",
    "",
  ];

  writeFile(PATHS_FILE, lines.join("\n"));
  console.log(`🛤️  Updated paths: ${PATHS_FILE}`);
}

function updateRoutes() {
  // Preserve header and footer from existing file
  let header = null;
  let footer = "";
  const existing = readFile(ROUTES_FILE);

  if (existing) {
    // Find 'export const ROUTES' line
    const routesStart = existing.indexOf("export const ROUTES");
    if (routesStart > 0) {
      header = existing.substring(0, routesStart);
    }

    // Find the closing '};' of the ROUTES object
    const routesMatch = existing.match(/export const ROUTES[\s\S]*?\n\};/);
    if (routesMatch) {
      const routesEnd =
        existing.indexOf(routesMatch[0]) + routesMatch[0].length;
      if (routesEnd < existing.length) {
        footer = existing.substring(routesEnd);
      }
    }
  }

  if (!header) {
    header = `import { createBrowserRouter, type RouteObject } from 'react-router';

import PATHS from './paths';
import Pages from '../pages';
import Root from './Layouts/Root';
import PublicLayout from './Layouts/PublicLayout';
import ProtectedLayout from './Layouts/ProtectedLayout';

`;
  }

  // Build ROUTES object
  const scopes = getDirs(PAGES_DIR);
  const sections = [];

  for (const scope of scopes) {
    const components = getDirs(path.join(PAGES_DIR, scope));
    if (components.length === 0) continue;

    const upper = scope.toUpperCase();
    const sorted = sortAlpha(components);

    const entries = sorted.map((comp) => {
      const constName = `${toSnakeUpper(comp)}_PATH`;
      return `    ${comp}: {\n      path: PATHS.${constName},\n      element: <Pages.${upper}.${comp} />,\n    },`;
    });

    sections.push(`  ${upper}: {\n${entries.join("\n")}\n  },`);
  }

  const routesObj = `export const ROUTES: Record<string, Record<string, RouteObject>> = {\n${sections.join("\n\n")}\n};`;

  ensureDir(path.dirname(ROUTES_FILE));
  writeFile(ROUTES_FILE, header + routesObj + footer);
  console.log(`🗺️  Updated routes: ${ROUTES_FILE}`);
}

module.exports = page;
