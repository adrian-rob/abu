const fs = require("fs");
const path = require("path");

// Sort strings case-insensitively
function sortAlpha(arr) {
  return [...arr].sort((a, b) =>
    a.toLowerCase().localeCompare(b.toLowerCase()),
  );
}

// Sort strings by length (shortest first), then alphabetically
function sortByLength(arr) {
  return [...arr].sort((a, b) => a.length - b.length || a.localeCompare(b));
}

// CamelCase → SCREAMING_SNAKE_CASE (e.g. AccessPoints → ACCESS_POINTS)
function toSnakeUpper(str) {
  return str
    .replace(/([A-Z])/g, "_$1")
    .replace(/^_/, "")
    .toUpperCase();
}

// CamelCase → kebab-case (e.g. AccessPoints → access-points)
function toKebab(str) {
  return str
    .replace(/([A-Z])/g, "-$1")
    .replace(/^-/, "")
    .toLowerCase();
}

// First letter uppercase
function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

// Get immediate subdirectory names (sorted)
function getDirs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

// Get filenames (without extension) matching a pattern
function getFiles(dir, ext) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(ext))
    .map((f) => f.replace(ext, ""))
    .sort();
}

// Ensure directory exists
function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

// Write file with content
function writeFile(filePath, content) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, content);
}

// Read file content (returns null if not found)
function readFile(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, "utf8");
}

// Generate the connected index.ts (Redux connect wrapper)
function connectedIndex(name) {
  return `import { connect } from 'react-redux';
import { RootState } from 'Redux';

import ${name} from './view';

export default connect(
  (state: RootState | any) => ({
  }),
  {},
)(${name});
`;
}

// Generate the view.tsx / standalone index.tsx
function componentView(name) {
  return `interface ${name}Props {}

const ${name} = ({}: ${name}Props) => {
};

export default ${name};
`;
}

module.exports = {
  sortAlpha,
  sortByLength,
  toSnakeUpper,
  toKebab,
  capitalize,
  getDirs,
  getFiles,
  ensureDir,
  writeFile,
  readFile,
  connectedIndex,
  componentView,
};
