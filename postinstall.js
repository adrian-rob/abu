const fs = require("fs");
const path = require("path");

const initCwd = process.env.INIT_CWD;
if (!initCwd) process.exit(0);

const hostPkg = path.join(initCwd, "package.json");
if (!fs.existsSync(hostPkg)) process.exit(0);

try {
  const pkg = JSON.parse(fs.readFileSync(hostPkg, "utf8"));
  if (!pkg.scripts) pkg.scripts = {};
  if (!pkg.scripts.abu) {
    pkg.scripts.abu = "abu";
    fs.writeFileSync(hostPkg, JSON.stringify(pkg, null, 2) + "\n");
    console.log('✅ Added "abu" script to package.json');
  }
} catch (e) {
  // Fail silently — don't break install
}
