# Zest 🥝

Package manager for the [Kiwi Programming Language](https://github.com/fuseraft/kiwi).

Zest lets you install external Kiwi packages from GitHub, manage dependencies, and keep projects reproducible with a lock file.

## Installation

### Linux / macOS

```bash
curl -sSL https://raw.githubusercontent.com/fuseraft/zest/main/install.sh | bash
```

Or with options:

```bash
./install.sh            # user install  (~/.zest)
./install.sh --system   # system-wide   (/opt/zest, requires sudo)
./install.sh --update   # update to latest
./install.sh --help     # all options
```

### Windows

```powershell
irm https://raw.githubusercontent.com/fuseraft/zest/main/install.ps1 | iex
```

Or with options:

```powershell
.\install.ps1           # user install  (%LOCALAPPDATA%\zest)
.\install.ps1 -System   # system-wide   (%ProgramFiles%\zest, auto-elevates)
.\install.ps1 -Update   # update to latest
.\install.ps1 -Uninstall
```

Requires [Kiwi](https://github.com/fuseraft/kiwi) to be installed and available in your PATH.

### GitHub API rate limits

Set `GITHUB_TOKEN` in your environment to raise the rate limit from 60 to 5,000 requests/hr:

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

---

## Quick Start

```bash
# 1. Scaffold a project
cd my-project
zest init

# 2. Install a package
zest install owner/repo

# 3. Use it in your script
```

```kiwi
include ".zest/load.kiwi"

owner_package::do_something()
```

---

## Commands

### `zest init`
Scaffold a `kiwi.json` in the current directory. Prompts for name, version, and description.

```bash
zest init
```

---

### `zest install`

**Install all declared dependencies:**
```bash
zest install
```

**Install a specific package (saves to `kiwi.json`):**
```bash
zest install owner/repo
zest install owner/repo@1.2.3
zest install owner/repo@^1.0.0
zest install owner/repo@~1.2.0
zest install owner/repo@>=1.0.0,<2.0.0
```

**Install as a dev dependency:**
```bash
zest install owner/repo --dev
```

**Accepted URL forms:**
```bash
zest install owner/repo
zest install github.com/owner/repo@^1.0.0
zest install https://github.com/owner/repo@1.0.0
```

---

### `zest uninstall`
Remove a package from `kiwi.json`, `kiwi.lock`, and `.zest/load.kiwi`.

```bash
zest uninstall owner/repo
# aliases: remove, rm
```

The package files in `~/.zest/packages/` are kept (global cache). Run `zest cache clean` to remove them.

---

### `zest update`

**Update all packages** to the latest version satisfying their constraints:
```bash
zest update
# aliases: upgrade, up
```

**Update a specific package:**
```bash
zest update owner/repo
```

---

### `zest list`
List all installed packages for the current project.

```bash
zest list
# alias: ls
```

Output shows version, constraint, and whether each package satisfies its requirement.

---

### `zest info`
Show detailed information about an installed package.

```bash
zest info owner/repo
# alias: show
```

---

### `zest search`
Search the [community registry](https://github.com/fuseraft/zest-registry) for packages.

```bash
zest search              # list all registered packages
zest search colors       # filter by name, description, or tag
```

---

### `zest publish`
Tag the current version and create a GitHub release. Requires `GITHUB_TOKEN`.

```bash
zest publish             # tag + release using the version in kiwi.json
zest publish --patch     # bump patch version, then tag + release
zest publish --minor     # bump minor version, then tag + release
zest publish --major     # bump major version, then tag + release
```

Add `--register` to any of the above to print the `packages.json` entry and step-by-step instructions for submitting your package to the community registry:

```bash
zest publish --patch --register
```

---

### `zest cache clean`
Delete all cached tarballs from `~/.zest/cache/`. Installed packages in `~/.zest/packages/` are unaffected.

```bash
zest cache clean
```

---

## Version Constraints

| Constraint | Meaning |
|------------|---------|
| `*` or `latest` | Any version |
| `1.2.3` | Exact version |
| `^1.2.3` | Same major, `>= 1.2.3` (compatible) |
| `~1.2.3` | Same major.minor, `>= 1.2.3` (patch updates only) |
| `>=1.0.0` | Any version at or above 1.0.0 |
| `>1.0.0` | Strictly above 1.0.0 |
| `<=2.0.0` | At or below 2.0.0 |
| `<2.0.0` | Strictly below 2.0.0 |
| `>=1.0.0,<2.0.0` | Range (comma = AND) |

---

## Project Files

### `kiwi.json`
The project manifest. Created by `zest init`, updated by `zest install` / `zest uninstall`.

```json
{
  "name": "my-project",
  "version": "0.1.0",
  "description": "A Kiwi project",
  "kiwi": ">=1.4.0",
  "dependencies": {
    "owner/repo": "^1.0.0"
  },
  "dev_dependencies": {
    "owner/test-utils": "*"
  }
}
```

### `kiwi.lock`
Auto-generated. Pins exact resolved versions and SHA256 checksums for every package in the dependency graph.

**Commit `kiwi.lock` to version control.** It ensures every collaborator and CI run installs the exact same versions.

```json
{
  "lockfile_version": 1,
  "packages": {
    "owner/repo": {
      "version": "1.2.3",
      "resolved": "https://github.com/owner/repo/archive/refs/tags/v1.2.3.tar.gz",
      "sha256": "abc123...",
      "main": "repo.kiwi",
      "dependencies": {
        "owner/dep": "2.0.1"
      }
    }
  }
}
```

### `.zest/load.kiwi`
Auto-generated by `zest install`. Contains `include` statements for every installed package. **Do not edit manually.**

Add `.zest/` to `.gitignore` (zest does this automatically). Restore it by running `zest install`.

---

## Dependency Resolution

Zest uses **version unification** to avoid dependency hell:

1. The full dependency graph is traversed (BFS), collecting every version constraint placed on each package — including transitive constraints from dependencies of dependencies.
2. For each package, Zest finds the single highest version that satisfies **all** collected constraints simultaneously.
3. If no such version exists, Zest reports the conflict clearly — showing which packages demand incompatible requirements — rather than silently installing multiple versions or picking one arbitrarily.

This means there is always exactly **one copy** of each package installed per project, regardless of how many things depend on it.

**Example:** If package A requires `dep@^1.0.0` and package B requires `dep@~1.3.0`, Zest resolves `dep` to the highest `1.3.x` release, satisfying both.

**Conflict example:** If A requires `dep@^1.0.0` (i.e. `>=1.0.0 <2.0.0`) and B requires `dep@^2.0.0` (i.e. `>=2.0.0 <3.0.0`), Zest reports the conflict and aborts rather than installing a broken state.

---

## Publishing a Package

### 1. Set up your package

Add a `kiwi.json` to the root of your GitHub repo:

```json
{
  "name": "my-package",
  "version": "1.0.0",
  "description": "A useful Kiwi package",
  "main": "my_package.kiwi",
  "kiwi": ">=1.4.0",
  "dependencies": {}
}
```

Define your package in the main file using Kiwi's `package` syntax:

```kiwi
package my_package
  fn greet(name: string)
    println "Hello, ${name}!"
  end
end

export "my_package"
```

### 2. Publish a release

With `GITHUB_TOKEN` set, run from your repo directory:

```bash
zest publish          # tags + releases the current version
zest publish --patch  # bumps patch, commits kiwi.json, tags, releases
```

This creates a git tag (`v1.0.0`) and a GitHub release — making the package installable immediately:

```bash
zest install your-username/my-package
```

### 3. Register in the community registry

To make your package discoverable via `zest search`, submit it to [fuseraft/zest-registry](https://github.com/fuseraft/zest-registry):

```bash
zest publish --register   # prints the entry + PR instructions
```

Or add the entry manually to `packages.json` and open a pull request.

### 4. Using an installed package

```kiwi
include ".zest/load.kiwi"

my_package::greet("world")
```

---

## Global Cache

Zest stores downloaded packages globally at `~/.zest/`:

```
~/.zest/
  packages/
    owner/
      repo/
        1.0.0/          ← extracted package files
        1.2.3/
  cache/
    owner-repo-1.0.0.tar.gz   ← cached tarballs
```

Multiple projects sharing the same package version share the same installation on disk. Only one copy is ever downloaded per version.

---

## Community Registry

The [Zest Registry](https://github.com/fuseraft/zest-registry) is a community-maintained index of Kiwi packages. It's a single `packages.json` file hosted on GitHub — no account, no central server.

```bash
zest search              # browse all registered packages
zest search http         # filter by name, description, or tag
zest install owner/repo  # install any package directly (registry not required)
```

To register your package, see [fuseraft/zest-registry](https://github.com/fuseraft/zest-registry) for the submission guide.

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub personal access token. Required for `zest publish`. Raises API rate limit from 60 to 5,000 requests/hr for all other commands. |
| `ZEST_HOME` | Set automatically by the `zest` wrapper. Points to the zest installation directory. |
