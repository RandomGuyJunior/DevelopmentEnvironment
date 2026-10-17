# Additive starting factions — alpha.6

The 40K commanders are additional startunit choices. Genuine Armada, Cortex and
Legion commanders and build trees remain available. Use the existing Hosting
disable_armada, disable_cortex and disable_legion options for a 40K-only match;
use factionlimiter=0 for that combination. Positive faction-limit mode retains
the foundation's native fallback. Choose Start Position, select a commander in
the native pregame picker, then Ready. No custom commander spawn system is added.

The package follows rapid://randomguy-hosting:test. Earlier alpha.5 test results
are historical until the new namespace/selection checks are recorded separately.
Normal development and its single launcher are unchanged.

## Earlier alpha notes — lobby-alias replacement instructions superseded above

# Warhammer 40K BAR — alpha

Generated from normal development r107, retaining its shared four-faction gameplay.
Imperial Guard, Orks, Space Marines and Necrons are selectable; Random chooses
among the four starting commanders. Orks remain the main development priority.

The existing launcher lobby keeps its native names: Armada starts Imperial Guard,
Cortex starts Orks, and Legion (when enabled in the lobby) starts Space Marines.
For all four factions, select Choose Start Position before launching; in the
stock in-game prestart faction picker choose Imperial Guard, Orks, Space Marines
or Necrons before pressing Ready. Random uses the four 40K commanders. Fixed or
random-position quick starts can auto-start before selection; those modes do
not guarantee an opportunity to choose Necrons. AI teams retain their lobby
choice/Random; the human prestart picker does not select another team's faction.

This is an unfinished alpha, not complete faction acceptance. Some units and
routes remain unavailable. Temporary native constructor appearances are labelled
in their unit descriptions. Pending Gunship refinements and balance work are
not silently included. No funded diagnostic scene is enabled in ordinary play.

Use the launcher-provided engine and install the complete mod. This package is
prepared for the single Warhammer 40K Mod Stack; arbitrary mutator combinations
are not accepted. All players and the host need the same engine, stack and mod
files. Local preparation, catalog acceptance and download success do not by
themselves establish multiplayer readiness; consult the separate test record.

The normal development launcher and its independent previous backup are not
part of this download. Existing native loading/render safeguards are adapted
for this release context; loading failures should be reported, not bypassed.

## Controls compatibility difference

This release uses the launcher's stock Recoil engine and the player's existing
BAR control preferences. The private development engine's exact plain-WASD pan
and physical-key release ownership are not carried into this stock-engine
package. Normal development r107 remains unchanged. Native camera move bindings
in stock BAR tolerate modifiers (Any+); this package does not silently overwrite
your bindings or substitute another camera. This is an outstanding difference
for review before publication, not a claim of complete control compatibility.

Sources: [BAR's shared keybind contract](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/2f0a840/common/configs/keybinds.readme.md),
[pinned native camera press/release implementation](https://github.com/beyond-all-reason/RecoilEngine/blob/de69361239d8c8b1012dba3f5aa3122954ea4da3/rts/Game/UnsyncedGameCommands.cpp#L760).

This alpha.5 incorporates the commander birth/animation repair and half-radius plasma shield with standard native recharge costs. Release-specific validation is recorded separately.
