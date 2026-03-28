const component = require("./commands/component");
const page = require("./commands/page");
const locale = require("./commands/locale");
const reducer = require("./commands/reducer");

const COMMANDS = {
  component: component,
  c: component,
  page: page,
  p: page,
  locale: locale,
  l: locale,
  reducer: reducer,
  r: reducer,
};

function showHelp() {
  console.log(`
⚛️  abu — React Boilerplate CLI

Usage:
  abu <command> <n> [options]

Commands:
  component   Create a component in src/show/components/    (alias: c)
  page        Create a page in src/show/pages/              (alias: p)
  locale      Create a locale JSON in all language folders   (alias: l)
  reducer     Create a Redux Toolkit reducer                 (alias: r)

Options:
  --connect       Wrap with Redux connect (index.ts + view.tsx)
  --<scope>       (pages only) Target subfolder, e.g. --public, --session, --admin
                  Defaults to 'shared' if no scope provided

Arguments can be in any order:
  abu c MyButton --connect
  abu --connect c MyButton
  abu MyButton --connect c
`);
}

function parseArgs(argv) {
  let command = null;
  const flags = [];
  const positional = [];

  for (const arg of argv) {
    if (COMMANDS[arg] && !command) {
      command = COMMANDS[arg];
    } else if (arg === "help" || arg === "--help" || arg === "-h") {
      showHelp();
      process.exit(0);
    } else if (arg.startsWith("--")) {
      flags.push(arg.slice(2));
    } else {
      positional.push(arg);
    }
  }

  return { command, flags, positional };
}

function run(argv) {
  const { command, flags, positional } = parseArgs(argv);

  if (!command) {
    showHelp();
    process.exit(0);
  }

  const name = positional[0] || null;
  const connect = flags.includes("connect");
  const scope = flags.find((f) => f !== "connect") || null;

  command({ name, connect, scope, flags });
}

module.exports = { run };
