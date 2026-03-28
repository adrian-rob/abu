# abu

React boilerplate generator CLI for Vite + Redux projects.

## Installation

```bash
# Global (use abu anywhere)
npm install -g git+https://github.com/adrian-rob/abu.git

# Per project
yarn add -D git+https://github.com/adrian-rob/abu.git
```

## Usage

Arguments can be in any order.

### Components

```bash
# Basic component → src/show/components/MyButton/index.tsx
abu component MyButton

# Redux connected → src/show/components/MyButton/index.ts + view.tsx
abu c MyButton --connect
```

### Pages

```bash
# Public page
abu page Login --public

# Session page with Redux connect
abu p Dashboard --session --connect

# Custom scope (creates the folder if needed)
abu page Settings --admin

# No flag → defaults to 'shared'
abu page NotFound
```

### Locales

```bash
# Create a locale JSON file in all language folders
abu locale toast
abu l accessPoints
```

Creates `<name>.json` in every language folder under `src/process/locales/` and updates each folder's `index.ts` (imports sorted by length, exports sorted alphabetically).

> Language folders (e.g. `en/`, `sr/`, `de/`) must already exist.

## What gets generated

**Components** create files in `src/show/components/<Name>/` and update the barrel `src/show/components/index.ts` (imports sorted by length, exports sorted alphabetically).

**Pages** do the above in `src/show/pages/<scope>/<Name>/`, plus:

- Add a path constant to `src/show/navigator/paths.ts`
- Scaffold a route entry in `src/show/navigator/routes.tsx`

> **Note:** Route entries are scaffolded but not fully wired. Review `routes.tsx` to place each route in the correct layout.

**Locales** create an empty JSON file in every language folder and update each folder's `index.ts` barrel.

## Aliases

| Command     | Alias |
| ----------- | ----- |
| `component` | `c`   |
| `page`      | `p`   |
| `locale`    | `l`   |
