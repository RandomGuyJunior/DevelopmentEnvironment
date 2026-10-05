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

The actual Spring package still uses its normal `modinfo.lua`. The catalog does not replace `modinfo.lua`; it only makes Rapid packages discoverable before they are installed.

## Example

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
