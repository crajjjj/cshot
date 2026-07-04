# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Mod Is

**Hentairim p+ Cumshot** is a Skyrim Special Edition mod: a lightly customized build of **SexLab Cumshot 2.x** (SLC, "Cumshot 2.3") that adds visible ejaculation effects to sex scenes. The one custom change over stock Cumshot is the **ejaculation gate** in the SexLab handler (see [Ejaculation gating](#ejaculation-gating)): the external cumshot is suppressed while the penis is inside a partner (mouth/vagina/anus), so it never clips through the head in oral or sprays from inside the body in vaginal/anal.

Cumshot displays an ejaculation on an actor via one of four techniques, and derives per-actor amount/power/opacity from MCM globals, arousal, and a "draining/recovery" model. It detects an actor's genital type (SOS Full/Light, SAM, esp-less body replacer, equipable schlong, or "special body" with an integrated penis) and positions the effect at the skeleton's `Urethra` node using NiOverride transforms.

All script identifiers are prefixed **`CS2`**.

## Build

The project compiles Papyrus scripts using [Pyro](https://github.com/fireundubh/pyro) via the VSCode task.

**Default build task (VSCode `Ctrl+Shift+B`):**
```
pyro: Compile Project (skyrimse.ppj)
```

This compiles all `.psc` files in `Scripts\Source\` and outputs `.pex` bytecode to `Scripts\`. With `Zip="true"` in `skyrimse.ppj`, it also produces `Build\Hentairim Cumshot patch.zip` containing only this project's own source (`Scripts\Source\*.psc`) and the six `CS2*.pex` files listed in the `<ZipFiles>` block.

**Manual Pyro invocation (from repo root):**
```
pyro -i skyrimse.ppj
```

Skyrim SE game path: `C:\SteamLibrary\steamapps\common\Skyrim Special Edition\`

**Papyrus debugger** (VSCode `F5`): attaches to the running Skyrim SE process using the `papyrus-lang` extension.

## Script Architecture

Six scripts in `Scripts\Source\`:

| Script | Extends | Role |
|---|---|---|
| `CS2GameScript` | `Quest` | **Main controller** (`Main`). Detects installed frameworks, builds genital databases, and does all the actual ejaculation rendering. |
| `CS2ConfigScript` | `SKI_ConfigBase` | MCM menu (`Config`). Pages: General, Visuals, Genital data (+ a commented-out SexLab Animations page). Holds nearly all user settings as properties. |
| `CS2SexLabScript` | `Quest` | SexLab event handler. Listens for orgasm/scene-end events and decides per-actor whether to ejaculate. Contains the **Hentairim tags hook**. |
| `CS2DropScript` | `ObjectReference` | Attached to each launched cum-drop object; runs the Havok impulse + lifetime/cleanup state machine. |
| `CS2PlayerAliasScript` | `ReferenceAlias` | Player alias on the main quest; `OnPlayerLoadGame` → `CS2GameScript.InitOnLoad()`. |
| `CS2PlayerAliasSLScript` | `ReferenceAlias` | Player alias on the SexLab quest; `OnPlayerLoadGame` → `CS2SexLabScript.InitOnLoad()`. |

### Initialization flow

`OnInit` (first install) and `OnPlayerLoadGame` (each load, via the alias scripts) both funnel into `CS2GameScript.Initialize()`, which:
1. Detects SexLab / Flower Girls / Aroused / SAM via `Game.GetModByName()` and caches quest/faction forms.
2. Calls `Config.Initialize()` (which runs `Parent.OnGameReload()`, sets up MCM pages by mod health, and runs version-migration code — `GetVersion()` returns `230`, `versionString = "2.3"`).
3. Builds the equipable-schlong and special-body lists from JSON, and selects which armor to equip for the current ejaculation mode.

### Ejaculation modes (`CS2GameScript.Ejaculate`)

`Config.ejaculationMode` (1–4) selects the technique:

1. **Animated mesh** — equips an animated armor (`CumshotSOS` / `CumshotStatic`); opacity of spurts 1–4 and the final drip set via NiOverride `AddOverrideFloat`.
2. **Particles** — equips a particle-emitter armor chosen from `ParticlesSOS`/`ParticlesStatic` FormLists by cum amount.
3. **Drop objects** — `EjaculateObjects` launches spurts of physical cum-drop objects (`CS2DropsS/M/L`), each running `CS2DropScript`. This is the only mode that honors ejaculation power and spurt ratio.
4. **Projectiles** — `EjaculateProjectiles` casts a series of spurt spells (`CS2ProjectileSpellsV1–V4`) from a launcher placed at the urethra node.

Modes 1–2 can optionally emit invisible **tracer** objects (`EmitTracers`) so a trigger volume can detect the ejaculation. In first-person, a proxy activator is placed at the `Urethra` node because `MoveToNode` misplaces objects at player nodes in 1st person / TFC.

### Genital / body detection

`HasSchlongItem`, `HasSpecialBody`, and `IdentifyGenitals` classify an actor's genitals. Priority: equipable schlong (FormList `CS2EquipableSchlongs`) → SOS addon (faction membership) → slot-52 item → "special body" (ActorBase or Race in `.SpecialBodies`) → default body. `maleBodyClass`: `0` esp-less mesh replacer, `1` SOS Full, `2` SOS Light, `3` SAM. Transform adjustments (position/rotation, interpolated between weight 0 and 100) come from `AdjustValues.json` keyed by the resolved "transform key".

### Per-actor stats & RNG

Per-actor overrides live as `StorageUtil` float values on the actor: `CS2CumAmount`, `CS2EjaculationPower`, `CS2SpurtRatio`, `CS2CumOpacity` (`-1.0` = "use global"). `CS2_ejaculating` (form) marks an in-progress ejaculation; `CS2_LastOrgasmTime` drives the draining/recovery curve; `CS2_inFGScene` marks Flower Girls scenes. A **Wichmann-Hill generator** (`QRand`/`ResetQRand`) is used instead of `Utility.RandomFloat()` inside time-critical drop loops to avoid unlocking the script mid-spurt.

## Ejaculation gating

The only meaningful divergence from stock Cumshot is how `CS2SexLabScript.OrgasmSL` decides whether to show the cumshot. It uses SexLab P+'s **per-actor interaction detection** — which the framework itself documents as "Superior alternatives to tag-based detectors":

```papyrus
Bool Function PenisIsInside(SexLabThread slScene, Actor a)
    return slScene.IsOralComplex(a) || slScene.IsVaginalComplex(a) || slScene.IsAnalComplex(a)
EndFunction
; OrgasmSL ejaculates only when !PenisIsInside(slScene, orgasmee)
```

`IsOralComplex` / `IsVaginalComplex` / `IsAnalComplex` (on `SexLabThread`, really the `sslThreadModel` override) read the live per-actor interaction table. For a schlonged actor the passive interactions (`pOral`/`pDeepthroat`/`pVaginal`/`pAnal`) mean "his penis is currently inside a partner." When it is, the external cumshot is suppressed (it would otherwise clip through the head in oral, or spray from inside the body in vaginal/anal). Handjob / footjob / titfuck / pull-out / masturbation are **not** internal, so the cumshot shows.

This is framework-native and present on virtually every animation (Vaginal/Anal/Oral are core SexLab metadata), so it does **not** depend on any animation carrying custom SLATE tags. Earlier versions used a `ShowEjac` helper that called `HentaiRimTags.PenisActionLabel`/`EndingLabel`; that was replaced by `PenisIsInside`, which is why this project no longer imports the `Hentairim p+ 3.0.4` source. For finer control (distinguish "his penis is inside" from "he is giving oral"), use `slScene.GetCurrentInteractionFlags(a)` / `GetCurrentInteractionStringA(a)` and test only the passive (`p*`) entries.

## SexLab event handling (`CS2SexLabScript`)

Registers for `SexLabOrgasm`, `SexLabOrgasmSeparate` (SLSO), `HookOrgasmStart`, `HookOrgasmEnd`, `HookAnimationEnding`. `OrgasmSL` handles a single actor's orgasm (gates on `PenisIsInside`, then calls `Main.Ejaculate`). `orgasmDetectMode`: `0` individual only, `1` hybrid, `2` final-stage-everyone (legacy). `CleanUpSL` force-removes cumshots from all actors when a scene ends. The `RebuildAnimListSL` / per-animation rules system is present but **commented out** (`;/ … /;`); the animation-rules MCM page and `SLRules*.json` files are legacy scaffolding.

## Configuration storage

- **MCM / SkyUI**: driven by `CS2ConfigScript` (an `SKI_ConfigBase`); most settings are script properties, filled/defaulted in the CK.
- **StorageUtil (PapyrusUtil JSON)**: `SKSE\Plugins\StorageUtilData\Cumshot\`
  - `AdjustValues.json` — live genital-transform database: `.EquipObjects`, `.SOSAddons`, `.SpecialBodies`, `Static Bodies`/`SOS Light Bodies`, `Static Races`/`SAM Races`, and per-key float lists (`move0[0..2]`, `move100[3..5]`, `rotate[6..8]`).
  - `AdjustValuesDefaults.json` — pristine copy of the above.
  - `SLRulesDefaults.json` / `SLRulesCustom.json` — legacy per-animation ejaculation rules (unused while `RebuildAnimListSL` is disabled).

## ESP Files

| File | Purpose |
|---|---|
| `Cumshot.esp` | Main plugin — quests (`CS2GameScript`), MCM (`CS2ConfigScript`), armors/armor-addons, drop/projectile FormLists, markers, and all CK-filled script properties. |
| `CumshotSL.esp` | SexLab support module — hosts the `CS2SexLabScript` quest and sets the `CS2SexLabSupported` global to 1. Required for SexLab integration. |

A Flower Girls module (`CumshotFG.esp`, sets `CS2FlowerGirlsSupported`) is referenced in MCM text but is **not** shipped in this repo.

## Asset Layout

```
meshes\Cumshot\             ← cumshot / particle / drop / tracer meshes
textures\Cumshot\           ← cum textures
textures\effects\gradients\ ← gradient maps for effects
Seq\Cumshot.seq             ← start-enabled quest SEQ (main)
Seq\CumshotSL.seq           ← start-enabled quest SEQ (SexLab module)
```

## Build Import Notes

**Keep the full `<Imports>` list.** It is carried over verbatim from the `Hentairim p+ 3.0.4` project (the two share `ModsFolder`). Although the `CS2*` scripts only touch a handful of frameworks directly, compiling them drags in SexLab's whole transitive dependency tree — e.g. `SexLabThread` → `sslExpressionUtil` → `MfgConsoleFuncExt` — and every one of those must be resolvable at build time or the compile fails. Pruning the list to "just what CS2 uses" **breaks the build** (`MfgConsoleFuncExt is undefined`, etc.). Do not trim it.

Where the directly-referenced types resolve from:

| Need | Import path |
|---|---|
| `SexLabFramework` / `SexLabThread` / `SexlabRegistry` / `sslBaseAnimation` | `build\SexLab Framework PPLUS - V2.17.1\Source\Scripts` |
| `SOS_API` / `SOS_AddonQuest_Script` | `build\Schlongs of Skyrim SE\scripts\source` |
| `NiOverride` | `build\racemenu\scripts\source` |
| `SKI_ConfigBase` + SKI_* chain | `build\SkyUI_5.1_SDK\Scripts\Source` and `build\MCM SDK-…\Source\Scripts` |
| `MfgConsoleFuncExt` (transitive, via `sslExpressionUtil`) | `SKSE\Mfg-Fix-NG\dist\source\scripts` |
| `JsonUtil` / `StorageUtil` / `MiscUtil` / `PapyrusUtil` / `Input` / `NetImmerse` / `ModEvent` / `SKSE` | base game `…\Skyrim Special Edition\Data\Source\Scripts` (PapyrusUtil is installed there) |

The base-game import is kept **last** so the specific framework imports win on any name clash (e.g. `SexLabFramework` also exists in the base Data source). The `Hentairim tags` import stays commented out — the ejaculation gate now uses SexLab P+'s native detection (see [Ejaculation gating](#ejaculation-gating)), so no `HentaiRimTags` source is required.

## Important: CK-Filled Properties

Script properties filled via the Creation Kit in the ESP (e.g. the many `Auto` FormList/Armor/Global properties on `CS2GameScript`, and the settings properties on `CS2ConfigScript`) must NOT be removed from the `.psc` files even if unused in code — removing them breaks the form binding. To clean one up, also clear it in the ESP. When in doubt, leave it as dead weight.

## Papyrus Language Notes

### Reserved keywords (case-insensitive, cannot be used as identifiers)
`As`, `Auto`, `AutoReadOnly`, `Bool`, `Else`, `ElseIf`, `EndEvent`, `EndFunction`, `EndIf`, `EndProperty`, `EndState`, `EndWhile`, `Event`, `Extends`, `False`, `Float`, `Function`, `Global`, `If`, `Import`, `Int`, `Length`, `Native`, `New`, `None`, `Parent`, `Property`, `Return`, `ScriptName`, `Self`, `State`, `String`, `True`, `While`

### Control flow
- No `break` or `continue` — use flags or early `return` to exit loops (this code uses e.g. `f = installedSchlongs` / `i = numSpurts` to break `while` loops).
- Only `if/elseif/else/endif` and `while/endwhile`. No for-loops, switch, or do-while.
- Logical `||` and `&&` short-circuit.

### Variables & types
- Five base types: `Bool`, `Int`, `Float`, `String`, plus object references and arrays.
- Value types are copied on assignment; objects/arrays are by reference.
- Variables inside `while` loops persist across iterations (NOT reset each iteration). Always initialize explicitly.
- Script-level variables can only be initialized with literals, not expressions. Function-level can use expressions.
- Division by zero and modulus by zero produce undefined results (engine logs error).

### Arrays
- Max 128 elements. Size must be an integer literal (`new Float[3]`), not a variable — dynamic sizes use `Utility.CreateStringArray(n)` etc.
- `array[i] += 5` does NOT compile — use `array[i] = array[i] + 5`.
- No arrays of arrays. Arrays are passed/assigned by reference.
- `Find()`/`RFind()` and SKSE string functions are case-insensitive. `==` string comparison is case-sensitive.

### Properties & optional mod dependencies
- Global/static function calls (e.g. `SOS_API.Get()`, `SexLabRegistry.IsSceneTag(...)`) resolve lazily at call time, not script load — but the compiler still needs the type resolvable at **build** time. Safe to *call* optional mods at runtime if guarded by `Game.GetModByName()`.
- Properties typed to external scripts (e.g. `SexLabFramework Property SexLab Auto`) resolve at script load — the type must exist or the script fails to load entirely.
- Auto property getters/setters are external calls in threading context.

### States
- Script can be in only one state at a time. `GotoState("")` returns to empty state.
- State function signatures must exactly match the empty-state definition.
- Call `GotoState()` BEFORE external calls, not after (threading safety).

### Threading
- Only one thread can run a script instance at a time. Any external call (including `Debug.Trace()`, property access on other objects) unlocks the script, allowing other threads in. This is why `Ejaculate`/`ObjectsSpurt` guard on `StorageUtil.HasFormValue(a, "CS2_ejaculating")` after each latent call, and why `QRand` avoids `Utility.RandomFloat()` in tight loops.
- Internal operations (own variables, own properties, array ops) do NOT unlock.

### Misc gotchas
- `GetAnimationVariableInt()` only works on actors with loaded 3D in third-person view.
- Compiler does not check all code paths for return values — missing returns cause undefined behavior.
- `parent.FunctionName()` calls one level up, not necessarily the base definition.
- Unary minus can misbehave without spaces: write `x = y - 1` not `x = y-1`.
