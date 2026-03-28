const path = require("path");
const fs = require("fs");
const {
  sortAlpha,
  sortByLength,
  getDirs,
  getFiles,
  ensureDir,
  writeFile,
} = require("../utils");

const LOCALES_DIR = "src/process/locales";

function locale({ name }) {
  if (!name) {
    console.log("Usage: abu locale <n>");
    console.log("  e.g. abu locale toast");
    console.log("  e.g. abu l accessPoints");
    process.exit(1);
  }

  if (!fs.existsSync(LOCALES_DIR)) {
    console.log(`❌ Locales directory not found: ${LOCALES_DIR}`);
    console.log(
      "   Please create it with at least one language folder (e.g. en, sr)",
    );
    process.exit(1);
  }

  const langs = getDirs(LOCALES_DIR);

  if (langs.length === 0) {
    console.log(`❌ No language folders found in ${LOCALES_DIR}`);
    console.log("   Please create at least one language folder (e.g. en, sr)");
    process.exit(1);
  }

  // Step 1: Create JSON file in all language folders
  for (const lang of langs) {
    const jsonFile = path.join(LOCALES_DIR, lang, `${name}.json`);
    if (fs.existsSync(jsonFile)) {
      console.log(`⚠️  Already exists: ${jsonFile} (skipped)`);
    } else {
      writeFile(jsonFile, "{}");
      console.log(`✅ Created: ${jsonFile}`);
    }
  }

  // Step 2: Update index.ts for each language folder
  for (const lang of langs) {
    const langDir = path.join(LOCALES_DIR, lang);
    const barrel = path.join(langDir, "index.ts");
    const files = getFiles(langDir, ".json");

    if (files.length === 0) continue;

    // Imports sorted by line length
    const imports = files.map((f) => `import ${f} from './${f}.json';`);
    const sortedImports = sortByLength(imports);

    // Exports sorted alphabetically
    const sortedExports = sortAlpha(files);

    const content = `${sortedImports.join("\n")}

const ${lang} = { ${sortedExports.join(", ")} };

export default ${lang};
`;

    writeFile(barrel, content);
    console.log(`📦 Updated barrel: ${barrel}`);
  }
}

module.exports = locale;
