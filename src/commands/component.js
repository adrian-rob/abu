const path = require("path");
const fs = require("fs");
const {
  sortAlpha,
  sortByLength,
  getDirs,
  ensureDir,
  writeFile,
  connectedIndex,
  componentView,
} = require("../utils");

const COMPONENTS_DIR = "src/show/components";

function component({ name, connect }) {
  if (!name) {
    console.log("Usage: abu component <n> [--connect]");
    process.exit(1);
  }

  const dir = path.join(COMPONENTS_DIR, name);

  if (fs.existsSync(dir)) {
    console.log(`❌ Directory already exists: ${dir}`);
    process.exit(1);
  }

  ensureDir(dir);

  if (connect) {
    writeFile(path.join(dir, "index.ts"), connectedIndex(name));
    writeFile(path.join(dir, "view.tsx"), componentView(name));
    console.log(`✅ Created connected component: ${dir}`);
    console.log("   ├── index.ts");
    console.log("   └── view.tsx");
  } else {
    writeFile(path.join(dir, "index.tsx"), componentView(name));
    console.log(`✅ Created component: ${dir}`);
    console.log("   └── index.tsx");
  }

  updateBarrel(name);
}

function updateBarrel() {
  const barrel = path.join(COMPONENTS_DIR, "index.ts");
  const components = getDirs(COMPONENTS_DIR);

  // Imports sorted by line length
  const imports = components.map((c) => `import ${c} from './${c}';`);
  const sortedImports = sortByLength(imports);

  // Exports sorted alphabetically
  const sortedExports = sortAlpha(components);
  const exportLines = sortedExports.map((c) => `  ${c},`).join("\n");

  const content = `${sortedImports.join("\n")}

export {
${exportLines}
};
`;

  writeFile(barrel, content);
  console.log(`📦 Updated barrel: ${barrel}`);
}

module.exports = component;
