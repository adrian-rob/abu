const path = require("path");
const fs = require("fs");
const {
  sortAlpha,
  sortByLength,
  capitalize,
  getDirs,
  ensureDir,
  writeFile,
  readFile,
} = require("../utils");

const REDUCERS_DIR = "src/process/reducers";
const STORE_FILE = "src/process/redux/index.ts";

function reducer({ name }) {
  if (!name) {
    console.log("Usage: abu reducer <n>");
    console.log("  e.g. abu reducer user");
    console.log("  e.g. abu r accessPoints");
    process.exit(1);
  }

  const pascal = capitalize(name);
  const dir = path.join(REDUCERS_DIR, name);

  if (fs.existsSync(dir)) {
    console.log(`❌ Reducer already exists: ${dir}`);
    process.exit(1);
  }

  // Step 1: Create reducer slice
  ensureDir(dir);
  writeFile(
    path.join(dir, "index.ts"),
    `import { createSlice } from '@reduxjs/toolkit';

import { updateProps } from '../shared';

interface ${pascal}State {}

const initialState: ${pascal}State = {};

const ${name}Slice = createSlice({
  name: '${name}',
  initialState,
  reducers: {
    updateProps,
  },
});

export const ${name}Actions = ${name}Slice.actions;

export default ${name}Slice;
`,
  );

  console.log(`✅ Created reducer: ${dir}/index.ts`);

  // Step 2: Update reducers barrel
  updateBarrel();

  // Step 3: Update store
  updateStore(name);
}

function updateBarrel() {
  const barrel = path.join(REDUCERS_DIR, "index.ts");
  const reducers = getDirs(REDUCERS_DIR).filter((d) => d !== "shared");

  // Imports sorted by line length
  const imports = reducers.map((r) => `import ${r} from './${r}';`);
  const sortedImports = sortByLength(imports);

  // Exports sorted alphabetically
  const sortedExports = sortAlpha(reducers);

  const content = `${sortedImports.join("\n")}

export { ${sortedExports.join(", ")} };
`;

  writeFile(barrel, content);
  console.log(`📦 Updated barrel: ${barrel}`);
}

function updateStore(name) {
  let content = readFile(STORE_FILE);

  if (!content) {
    console.log(`⚠️  Store file not found: ${STORE_FILE}`);
    console.log("   Please manually import and add the reducer to your store.");
    return;
  }

  try {
    // 3a: Update Reducers import
    const importRegex = /import\s*\{([^}]+)\}\s*from\s*'Reducers'/;
    const importMatch = content.match(importRegex);
    if (importMatch) {
      const existing = importMatch[1]
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      if (!existing.includes(name)) {
        existing.push(name);
        existing.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
        content = content.replace(
          importRegex,
          `import { ${existing.join(", ")} } from 'Reducers'`,
        );
      }
    }

    // 3b: Add to combineReducers
    const combineRegex = /(combineReducers\(\{)([\s\S]*?)(\}\))/;
    const combineMatch = content.match(combineRegex);
    if (combineMatch && !combineMatch[2].includes(`[${name}.name]`)) {
      const entries =
        combineMatch[2].match(/\[.*?\.name\]:\s*\w+\.reducer,?/g) || [];
      entries.push(`[${name}.name]: ${name}.reducer,`);
      entries.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

      const newBlock =
        "combineReducers({\n" +
        entries.map((e) => "  " + e.trim().replace(/,?$/, ",")).join("\n") +
        "\n})";
      content = content.replace(combineRegex, newBlock);
    }

    // 3c: Add to rootReducer reset object
    const resetRegex =
      /(return reducer\(\s*\{)([\s\S]*?)(\},\s*\{ type: 'app\/RESET' \})/;
    const resetMatch = content.match(resetRegex);
    if (
      resetMatch &&
      !resetMatch[2].includes(`${name}: undefined`) &&
      name !== "user"
    ) {
      const undefs = resetMatch[2].match(/\w+:\s*undefined,?/g) || [];
      undefs.push(`${name}: undefined,`);
      undefs.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

      // Check if user block exists
      const userBlockMatch = resetMatch[2].match(/user:\s*\{[\s\S]*?\},?/);

      let newReset = "return reducer(\n      {\n";
      undefs.forEach((u) => {
        newReset += "        " + u.trim().replace(/,?$/, ",") + "\n";
      });
      if (userBlockMatch) {
        newReset +=
          "        user: {\n          language: state.user.language,\n          userSession: false,\n        },\n";
      }
      newReset += "      },\n      { type: 'app/RESET' }";

      content = content.replace(resetRegex, newReset);
    }

    fs.writeFileSync(STORE_FILE, content);
    console.log(`🏪 Updated store: ${STORE_FILE}`);
  } catch (err) {
    console.log(
      "⚠️  Could not update store automatically. Please add the reducer manually.",
    );
  }

  console.log("");
  console.log(
    `⚠️  Please review ${STORE_FILE} to ensure the reducer is correctly placed.`,
  );
}

module.exports = reducer;
