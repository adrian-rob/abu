# react-gen

React boilerplate generator CLI for Vite + Redux projects.

## Installation

```bash
yarn add -D git+https://github.com/<your-username>/react-gen.git
```

## Setup

Add to your `package.json` scripts:

```json
{
  "scripts": {
    "abu": "abu"
  }
}
```

## Usage

### Components

```bash
# Basic component → src/show/components/MyButton/index.tsx
yarn abu component MyButton

# Redux connected → src/show/components/MyButton/index.ts + view.tsx
yarn abu c MyButton --connect
```

### Pages

```bash
# Public page
yarn abu page Login --public

# Session page with Redux connect
yarn abu p Dashboard --session --connect

# Custom scope (creates the folder if needed)
yarn abu page Settings --admin

# No flag → defaults to 'shared'
yarn abu page NotFound
```

### What gets generated

**Components** create files in `src/show/components/<Name>/` and update the barrel `src/show/components/index.ts` (imports sorted by length, exports sorted alphabetically).

**Pages** do the above in `src/show/pages/<scope>/<Name>/`, plus:
- Add a path constant to `src/show/navigator/paths.ts`
- Scaffold a route entry in `src/show/navigator/routes.tsx`

> **Note:** Route entries are scaffolded but not fully wired. Review `routes.tsx` to place each route in the correct layout.

## Aliases

| Command     | Alias |
|-------------|-------|
| `component` | `c`   |
| `page`      | `p`   |
