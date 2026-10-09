# RandomGuy Development Environment

This repository is the discovery catalog for installable RandomGuy/BAR mods.

## How a mod is discovered

Add an entry to `mods.json`. The Chobby **Mods** tab downloads this catalog and shows every enabled entry.

Required fields:

- `id`: stable unique id
- `name`: display name
- `description`: short description
- `rapid_tag`: Rapid package tag to install, for example `my-mod:test`
- `rapid_repo`: Rapid `repos.gz` URL containing that tag

Optional fields:

- `author`
- `version`
- `homepage`
- `enabled` (defaults to true)
- `dependencies` (array of other catalog mod ids or exact `dev-mods:` Rapid tags)

The catalog only makes a Rapid package discoverable before it is installed. The package itself is still a normal Spring/Recoil game or mutator and therefore needs its own `modinfo.lua`.


## Mod Hub dependencies: automatic installation and removal

To require another **optional Mod Hub mod**, declare `dependencies` in your
entry in this repository's `mods.json`. Use the other mod's exact catalog
`id` (recommended) or its full `dev-mods:...` Rapid tag.

```json
{
  "schema_version": 1,
  "mods": [
    {
      "id": "shared-effects",
      "name": "Shared Effects",
      "rapid_tag": "dev-mods:shared-effects",
      "rapid_repo": "https://randomguyrapid.duckdns.org/repos.gz",
      "enabled": true
    },
    {
      "id": "ocean-units",
      "name": "Ocean Units",
      "rapid_tag": "dev-mods:ocean-units",
      "rapid_repo": "https://randomguyrapid.duckdns.org/repos.gz",
      "dependencies": ["shared-effects"],
      "enabled": true
    }
  ]
}
```

When a player clicks **Install** for Ocean Units, the Mod Hub resolves its
dependency graph from the published catalog, installs Shared Effects first,
then Ocean Units. This also works for dependencies of dependencies.
Already-installed dependencies are not downloaded again. Missing or disabled
dependencies, invalid Rapid tags, and dependency cycles stop the installation
before any download begins. If a download fails, remaining downloads are
cancelled; successfully downloaded prerequisites remain installed.

**Uninstall:** The trash icon removes only the selected mod's Rapid package
manifest (`data/packages/<package-hash>.sdp`) and its Mod Hub installed state.
It does **not** automatically uninstall dependencies: another mod may use them,
or the player may want to keep them. The Mod Hub refuses to uninstall a mod
while another **installed** catalog mod lists it as a dependency. Remove
dependent mods first, then uninstall the prerequisite if desired.
Disabling a mod is not uninstalling it.

**Storage safety:** Rapid's `data/pool` contains files shared by multiple
packages and is not deleted by Mod Hub uninstall. Base BAR, Chobby and
RandomGuy Hosting packages are never optional Mod Hub uninstall targets.
A successful uninstall therefore may free little disk space.

**Important distinction:** `mods.json` `dependencies` controls the Mod
Hub's *download and uninstall management*. The package's own
`modinfo.lua` `depend = { ... }` controls Spring/Recoil archive loading.
Declare the appropriate engine dependencies in `modinfo.lua` too; the Mod
Hub catalog field does not replace them. Mod Hub dependency references must
point to mods in the same published catalog, not arbitrary external URLs.
This initial implementation does not support version constraints or automatic
orphan-dependency cleanup.

## Spring/BAR mod package structure

A RandomGuy mod is an overlay package. Its directory layout should mirror the BAR paths it wants to add or replace. Files not supplied by the mod continue to come from its dependency.

A minimal mutator can look like this:

```text
my-mod/
├── modinfo.lua
├── units/
│   └── MyFaction/
│       └── myunit.lua
├── objects3d/
│   └── Units/
│       └── myunit.s3o
├── scripts/
│   └── Units/
│       └── myunit.lua
├── unittextures/
│   └── ...
├── LuaRules/
│   ├── Gadgets/
│   └── Configs/
└── LuaUI/
    ├── Widgets/
    └── configs/
```

Only include directories the mod actually needs. Do not copy all of BAR into a mutator.

### Required `modinfo.lua`

`modinfo.lua` is a Lua file that returns one table. For a BAR mutator, use `modtype = 1` and declare BAR as a Rapid dependency.

Example:

```lua
return {
    name = "Example Mod",
    description = "Example BAR mutator",
    shortname = "EXAMPLE",
    version = "$VERSION",
    mutator = "Example",
    game = "Beyond All Reason",
    shortGame = "BYAR",
    modtype = 1,

    depend = {
        "rapid://byar:test",
    },
}
```

Important:

- The file is **Lua**, not JSON.
- It must literally `return { ... }`.
- `depend` is a Lua array of package dependencies.
- `rapid://byar:test` lets BAR provide every file your overlay does not replace.
- File paths are significant and Linux hosting is case-sensitive. Match BAR path/case conventions.

## Common mod file types

### Unit definitions

Unit definitions are `.lua` files under `units/`. They return a table keyed by the unit name.

```lua
return {
    myunit = {
        name = "My Unit",
        objectname = "Units/myunit.s3o",
        script = "Units/myunit.lua",
        buildpic = "myunit.dds",
        health = 1000,
        metalcost = 500,
        energycost = 5000,
        footprintx = 4,
        footprintz = 4,
    },
}
```

Use normal BAR/Recoil UnitDef fields and keep the unit key unique.

### 3D models

Spring models normally use the binary `.s3o` format and belong under:

```text
objects3d/Units/
```

A unit's `objectname` points to that model. S3O models contain a piece hierarchy, geometry, UVs, model bounds, and references to their unit textures.

If a unit script refers to pieces by name, those piece names must exist in the S3O.

### Unit scripts

Runtime unit animation/aiming scripts can be:

- Lua unit scripts: `scripts/Units/name.lua`
- compiled COB scripts: `scripts/Units/name.cob`

New RandomGuy work should prefer Lua when practical. A UnitDef's `script` field selects the script.

### Textures and build pictures

Common formats are:

- `.dds` for unit textures, decals, and build pictures
- `.png` for UI art where appropriate

Typical paths include:

```text
unittextures/
unittextures/decals/
unitpics/
LuaUI/Images/
LuaRules/Images/
```

S3O models reference their model textures internally. Build pictures referenced by `buildpic` normally live in `unitpics/`.

### LuaRules gadgets and configs

Synced or game-rule logic belongs under:

```text
LuaRules/Gadgets/
LuaRules/Configs/
```

Gadgets are Lua files and normally expose `gadget:GetInfo()`. Synced gameplay changes must remain deterministic for every client.

### LuaUI widgets and configs

Client/UI-only code belongs under:

```text
LuaUI/Widgets/
LuaUI/configs/
```

Widgets are Lua files and normally expose `widget:GetInfo()`. Use these for UI rendering, local visual effects, menus, cached portraits, and other unsynced presentation logic.

### Effects, weapons, and shared definitions

When needed, mirror BAR's existing directory and file conventions rather than inventing a parallel loader. Examples include CEG/effect definitions, shared configs, sounds, and model assets.

The overlay rule is simple:

> Put the replacement/addition at the same virtual path BAR expects. The mod supplies that path; the BAR dependency supplies everything else.

## Rapid publishing

A repository that is built as a Rapid package usually publishes a moving test tag such as:

```text
example-mod:test
```

The corresponding `mods.json` entry points at both that tag and the Rapid repository URL.

RandomGuy's Rapid repository is currently:

```text
https://randomguyrapid.duckdns.org/repos.gz
```

A GitHub-hosted mutator can use the BAR Rapid hosting action in a workflow on its publishing branch.

## Discovery entry example

```json
{
  "id": "example-mod",
  "name": "Example Mod",
  "author": "RandomGuyJunior",
  "description": "Example development mod",
  "version": "test",
  "rapid_tag": "example-mod:test",
  "rapid_repo": "https://randomguyrapid.duckdns.org/repos.gz",
  "enabled": true
}
```

The discovery file is JSON. The installed game package itself is Lua/assets/S3O/etc. as described above.
