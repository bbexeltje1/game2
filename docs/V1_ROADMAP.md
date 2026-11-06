# Wasteland Halo-Diablo Extraction Shooter — V1 Game Design & Production Roadmap

> **Working Title:** *ASHFALL: Bastion Protocol* (configurable in `Shared/Config.luau`)  
> **Engine & Toolchain:** Roblox (Rojo + `--!strict` Luau + `luau-web` automated test harness)  
> **Visual Strategy for V1:** 100% Procedural Graybox (`BasePart` silhouettes + standardized `Attachment` contracts) engineered for zero-code `MeshPart` swapping post-V1.

---

## 1. Core Vision & Locked Design Pillars

A **Third-Person Post-Apocalyptic Co-op PvE Extraction Looter-Shooter** combining **Halo's** two-layer shield/health combat dance and tactical weapon sandbox with **Diablo's** deep procedural affix loot, durability economy, and 2D spatial grid inventory—built with **Nintendo's** state-machine rigor (`Nerve`) and clean UI lifecycle (`LayoutActor`).

| Pillar | V1 Locked Decision | Gameplay Impact |
| :--- | :--- | :--- |
| **Combat Structure** | **Co-op PvE Extraction (1–4 Players)** | Solo-viable or seamless co-op squads fighting post-apocalyptic AI factions, bosses, and extraction holdout waves. Zero PvP griefing; squadmates can revive downed allies and share extraction beacons. |
| **World Topology** | **Seamless Bunker + Wasteland (1 Place)** | Players spawn inside **Bastion Bunker** (Stash, Vendors, Repair/Salvage Bench, Contracts, Firing Range) and ride the **Surface Airlock Elevator** straight into the Wasteland on the same server. Instant playtesting in Roblox Studio with no `TeleportService` dependency. |
| **Death & Extraction Stakes** | **Keep Equipped Gear + Secure Case + Durability Tax** | Extracting via an active **Extraction Beacon** banks your entire raid backpack. Dying in the Wasteland drops unextracted raid backpack items, **keeps all equipped gear + your `2x2` Secure Case**, and applies a **Durability Tax** (`-20%` durability on equipped items, repaired at the Bunker with Scrap/Credits). |
| **Inventory & Loadout** | **Diablo / Tarkov 2D Spatial Grid + Full Paperdoll** | `10x5` Raid Backpack Grid, `10x12` Bunker Stash Grid, `2x2` Secure Case, item rotation (`R`), drag-and-drop, quick-transfer (`Shift+Click`), plus a full RPG Paperdoll (`Weapon 1`, `Weapon 2`, `Ordnance`, `Shield Core`, `Head`, `Chest`, `Legs`, `2x Relic/Artifact`, `4-Slot Belt`). |

---

## 2. GitHub Reference Repositories & Clean-Room Luau Architecture

> **Engineering & Licensing Principle:** Console/PC decompilation repositories do not grant redistribution licenses for proprietary C/C++ code. We use them as **clean-room architectural blueprints**—studying their state-machine structures, data schemas, mathematical formulas, and UI lifecycles, and writing original, server-authoritative `--!strict` Luau modules tailored to Roblox.

| GitHub Repository | Studied Engine Subsystems | Clean-Room Luau Target in `src/` |
| :--- | :--- | :--- |
| **`MonsterDruide1/OdysseyDecomp`** & **`open-ead/sead`** | `lib/al/Library/Nerve/NerveKeeper.h` (tick-counted `Nerve` state machines), `HitSensor/` (decoupled actor messaging), `Layout/LayoutActor.h` (`appear -> wait -> action -> kill` UI lifecycle) | `Shared/Core/Nerve.luau`<br>`Shared/Core/Sensor.luau`<br>`Client/UI/LayoutActor.luau` |
| **`zeldaret/botw`** (*Breath of the Wild*) | `src/KingSystem/Camera/` (3rd-person shoulder framing + raycast collision), `src/Game/UI/uiPauseMenuDataMgr.h` (strict separation of inventory data store from UI views + live stat comparison deltas + minimalist "Pro HUD") | `Client/Camera/CameraDirector.luau`<br>`Client/UI/InventoryDataView.luau` |
| **`halo-re/halo`** & **`bnunu/halo-ce-universal`** (*Halo: CE*) | `source/objects/damage.c` & `damage.h` (Energy Shield + Body Health vitality, stun delay, recharge rate, kinetic vs. plasma shield multipliers, bleedthrough), `source/items/weapons.c` (2-weapon + grenade sandbox, heat vs. mag), `source/interface/hud_unit.c`, `motion_sensor.c`, `hud_nav_points.c` | `Shared/Combat/DamageMath.luau`<br>`Shared/Weapons/WeaponCatalog.luau`<br>`Client/UI/Hud/CombatHud.luau`<br>`ServerScriptService/Combat/VitalityService.luau` |
| **`diasurgical/DevilutionX`** (*Diablo 1*) & **`OpenDiablo2/OpenDiablo2`** (*Diablo 2*) | `Source/inv.h` & `inv.cpp` (signed-index 2D occupancy grid: `+itemIdx` anchor, `-itemIdx` covered cells), `Source/items.h` & D2 `TreasureClass` / `MagicPrefix` / `MagicSuffix` (`ilvl` rarity rolls, prefix/suffix stat ranges, `_iDurability`, unique perks, repair/salvage cost math) | `Shared/Inventory/GridContainer.luau`<br>`Shared/Loot/AffixCatalog.luau`<br>`Shared/Loot/LootRoller.luau`<br>`Shared/Economy/DurabilityMath.luau` |
| **`OpenXRay/xray-16`** (*S.T.A.L.K.E.R.*) & **`alexbatalov/fallout2-ce`** | `src/xrGame/InventoryBox.cpp` (searchable world loot containers), `CustomOutfit.cpp` (environmental hazard resistances), `Artefact.cpp` (high-risk/high-reward wasteland relics with stat trade-offs) | `ServerScriptService/World/ContainerService.luau`<br>`ServerScriptService/World/HazardZoneService.luau`<br>`Shared/Loot/ArtifactCatalog.luau` |
| **`n64decomp/perfect_dark`** | Mission/contract difficulty scaling, secondary weapon fire modes, extraction objective state triggers | `ServerScriptService/Missions/ContractService.luau`<br>`ServerScriptService/World/ExtractionService.luau` |

### Strict Adherence to This Repository's Four Rojo Rules
Every module across all milestones obeys the existing template constraints enforced by `npm test`:
1. **Client modules live strictly in `src/ReplicatedStorage/Client` (`ReplicatedStorage.ClientModules`)**, never beside `Main.client.luau`.
2. **`DataStoreService` is never touched at module load**—Studio sessions automatically run against an in-memory profile store with `OfflineSave = true`, while published servers wrap `DataStoreService` inside lazy `pcall` session locks.
3. **UI renders immediately before server round-trips**, and every `WaitForChild` carries an explicit timeout with visible diagnostic text on failure.
4. **Zero functions attached onto Roblox `Instance`s**—all entities, AI actors, weapons, and UI `LayoutActor`s are plain Luau tables/modules linked to `Instance`s via registries or `CollectionService` IDs.

---

## 3. Graybox-First (`BasePart`) Architecture & Model-Swap Contract

To build 100% of V1 out of basic Roblox `Part`, `WedgePart`, and `Cylinder` primitives while guaranteeing effortless art upgrades later, **no gameplay or UI script ever constructs raw geometry inline**. Everything goes through `Shared/Assets/AssetRegistry.luau` and `Shared/Assets/PrefabBuilder.luau`.

### How Asset Resolution Works
1. Gameplay requests an asset by canonical ID, e.g. `PrefabBuilder.spawn("Weapon.KineticAR")` or `PrefabBuilder.spawn("Enemy.AegisEnforcer")`.
2. `PrefabBuilder` first checks `ReplicatedStorage:FindFirstChild("Assets")` for a custom authored `Model` matching that ID.
3. If none exists (all of V1), it executes the procedural `BasePart` recipe to generate a clean, color-coded, properly scaled graybox `Model` with identical hierarchy and `Attachment` contracts.

### Mandatory Attachment & Hitbox Contracts
| Category | Required Child Instances / Attachments | Purpose |
| :--- | :--- | :--- |
| **Weapons** | `PrimaryPart` (`Handle`), `MuzzleAttachment`, `GripAttachment`, `OffhandAttachment`, `SightAttachment` | Muzzle flash/ray origin, character right/left hand welds, ADS camera alignment. |
| **Characters & Enemies** | `PrimaryPart` (`Root`), `HeadHitbox`, `TorsoHitbox`, `ShieldBubblePart`, `HealthBarAnchor` | Precision crit detection, Halo energy shield shimmer/pop VFX, floating enemy shield/HP bars. |
| **World Containers** | `PrimaryPart` (`Base`), `LidPivot`, `InteractAnchor`, `LootBeamAttachment` | Lid open tween, `ProximityPrompt` placement, rarity light beam. |
| **Extraction Beacons** | `PrimaryPart` (`Pad`), `SkyBeamAttachment`, `SirenAttachment`, `ZoneRadiusValue` | Skyward extraction flare, audio pulse, holdout radius ring. |

---

## 4. Core Gameplay Systems Specification

### 4.1 Third-Person Camera & Character Movement (`BotW` + `Halo`)
- **Camera Director + Observer (`Client/Camera/`)**:
  - Over-the-shoulder 3rd-person camera (`Right` default, `V` swaps shoulder) with smooth velocity look-ahead.
  - Spring-damped `Observer` raycasts from character neck pivot to camera target, pulling forward smoothly along wall normals so the camera never clips through Bunker corridors or ruins.
  - Dynamic FOV & framing states driven by `Nerve`: `Explore` -> `Sprint` -> `AimDownSights (ADS)` -> `Slide/Dodge` -> `Downed` -> `MenuInspect`.
- **Tactical Movement**:
  - Sprint, Tactical Slide (down slopes or into cover), Ledge Mantle (raycast chest/head check onto graybox ruins), and Directional Combat Roll/Thruster Dodge (short cooldown, modified by Leg Armor affixes).

### 4.2 Halo Vitality & Damage Matrix (`Halo: CE` `damage.c` Model)
Every player and shielded enemy has two vitality layers:
1. **Energy Shield (`MaxShield`, `ShieldRegenRate`, `ShieldStunDelay`)**:
   - Absorbs incoming damage first. Any hit resets the `ShieldStunDelay` timer (base `3.5s`).
   - Once `ShieldStunDelay` expires without taking damage, shields recharge smoothly at `ShieldRegenRate`/sec.
   - Kinetic damage cannot crit through active shields; breaking a shield triggers an iconic **Shield Pop** visual/audio burst (and triggers *On-Shield-Break* Shield Core perks!).
2. **Body Health (`MaxHealth`, `ArmorRating`)**:
   - Exposed once shields hit `0` (or bypassed by Toxic/Bleed hazards).
   - Precision hits (`HeadHitbox`) apply weapon crit multipliers (`1.5x–2.5x`) against unshielded targets.
   - Body Health does **not** passively regenerate to full in combat—restored via **Med-Injectors** on the 4-slot Belt or Bunker restocking.

| Damage Type | vs. Energy Shield | vs. Unshielded Health / Crit | Special Status |
| :--- | :---: | :---: | :--- |
| **Kinetic** (Ballistic) | `0.80x` | `1.25x` (+ Full Headshot Crit) | High stagger against unshielded foes |
| **Plasma / Energy** | `1.65x` | `0.85x` | Overloads shields; brief EMP slow on shield pop |
| **Corrosive / Rad** | `1.00x` | `1.10x` | Shreds `ArmorRating` by `20%` for `5s` |
| **Explosive** | `1.20x` | `1.20x` | AoE radius + knockback |

### 4.3 Weapon Sandbox (8 Archetypes + Halo Heat/Mag Mechanics)
Players equip **2 Primary/Special Weapons** + **Ordnance (Grenade)** and swap rapidly (`1` / `2` / `Q`):
1. **MA-7 Wasteland Rifle** — Kinetic full-auto assault rifle; reliable workhorse.
2. **BR-55 Recon Burst** — Kinetic 3-round burst precision rifle; surgical mid-long range crits once shields drop.
3. **Sol-Coil Carbine** — Plasma rapid-fire rifle using a **Heat Gauge (`0–100%`)** instead of magazines; press `R` to manually vent heat, or overheat at `100%` for a `2.2s` burn lockout. Melts enemy shields.
4. **Trench Sweeper** — Kinetic pump scattergun; shell-by-shell reload, devastating against rushing mutants.
5. **Viper PDW** — High-ROF close-quarters SMG; fast handling and sprint-to-fire speed.
6. **Ferro-Rail Marksman** — Chargeable electromagnetic sniper; high pierce and headshot multiplier.
7. **M6D Bastion Sidearm** — High-caliber scoped utility pistol; fast swap speed ("switching to your sidearm is faster than reloading").
8. **Arc Mortar** — Heavy plasma-explosive launcher; strips group shields in extraction waves.

### 4.4 Diablo Itemization, Affixes, Durability & 2D Grid Inventory
#### Item Rarity & Affix Budget (`DevilutionX` / `OpenDiablo2` Model)
| Rarity Tier | Color | Affix Budget | Source |
| :--- | :--- | :--- | :--- |
| **Common (Salvage-Grade)** | Slate White | Base stats only | Tier I crates, basic Scavengers |
| **Uncommon (Modified)** | Tactical Blue | `1 Prefix` **or** `1 Suffix` | Tier I–II enemies, weapon racks |
| **Rare (Field-Forged)** | Amber Yellow | `1 Prefix` + `1 Suffix` + `1 Minor Mod` | Elites, locked rooms, Tier II–III |
| **Epic (Pre-Collapse)** | Void Purple | `2 Prefixes` + `2 Suffixes` | Enforcers, Tier III–IV vaults, Contracts |
| **Legendary (Unique)** | Solar Orange | Curated affixes + **1 Bespoke Gameplay Perk** | Sector Boss, Tier IV Vaults, Rare World Drops |

- **Example Prefixes (Offensive / Element / Capacity)**: *Overcharged* (`+Plasma Damage`), *Vampiric* (`Leech Health on Kill`), *Capacitive* (`+Max Shield`), *Hair-Trigger* (`+Fire Rate`), *Irradiated* (`Adds Corrosive Shred`).
- **Example Suffixes (Utility / Regen / Mobility)**: *of the Wasp* (`-Shield Stun Delay`), *of Stability* (`-Recoil & Bloom`), *of Scavenging* (`+Scrap & Rarity Find`), *of Lead-Lining* (`+Rad/Spore Hazard Resist`), *of Quick-Hands* (`+Reload & Vent Speed`).
- **Example Named Legendaries (8 in V1)**:
  - *Halo's Echo (Sol-Coil Carbine)* — Breaking an enemy's shield chains an arc lightning bolt to nearby enemies and vents `40%` weapon heat.
  - *Griswold's Edge (Trench Sweeper)* — Pellet kills restore `15%` Energy Shield immediately and never consume durability.
  - *Aegis of Zero-Hour (Shield Core)* — When your shield breaks, emit a knockback EMP blast and gain `2s` sprint speed boost.

#### 2D Spatial Grid Inventory (`DevilutionX` `inv.cpp` Signed-Matrix Model)
- **Grid Representation**: Plain serializable table `{ width = W, height = H, cells = {...}, items = {[uid] = ItemInstance} }`.
  - Anchor top-left `(x, y)` stores `uid`; covered `(x + dx, y + dy)` cells store `@ref:uid` for `O(1)` hit-testing, drag validation, and swap detection.
  - Pressing `R` while dragging toggles `rotated = not rotated` (swapping item `w` and `h`, e.g. `3x1` <-> `1x3`).
- **Item Footprints**:
  - Rifles / Shotguns / Snipers / Launchers: `3x2` or `4x2`
  - SMGs / Carbines: `2x2`
  - Sidearms / Helmets / Boots: `2x1` or `1x2`
  - Chest Armor / Shield Cores: `2x2` or `2x3`
  - Relics / Grenades / Med-Injectors / Scrap Stacks / Keys: `1x1`
- **Durability & Death Tax**:
  - Every weapon and armor piece rolls `durability = maxDurability` (e.g. `60/60`).
  - Normal combat wear is minimal, **but failing to extract (dying in the Wasteland)** drops unextracted Raid Backpack items (`10x5`), preserves all **Paperdoll Equipped Gear + `2x2` Secure Case**, and inflicts `-20%` durability on equipped gear.
  - At `0` durability, an item **never deletes itself**—it enters a *Damaged (`50%` effectiveness)* state until repaired with Scrap at the Bunker Repair Bench.

---

## 5. Seamless World Map, Enemy Factions & Extraction Loop

### 5.1 Single-Place Seamless Layout
```
[ BASTION BUNKER (Underground Safe Hub: Y = -120) ]
   ├── Personal Stash Terminal (10x12 Grid)
   ├── Repair, Salvage & Reroll Workbench
   ├── Quartermaster Vendor & Contract Board
   ├── Live DPS Firing Range (Shielded + Unshielded Target Dummies)
   └── Surface Deployment Elevator / Airlock (Teleports CFrame to chosen Zone Drop-Pod / Tunnel)
                 │
                 ▼
[ ASHEN WASTELAND SURFACE (Contiguous Graybox Sector: 1400 x 1400 studs, Y = 0+) ]
   ├── Zone 1: Collapsed Overpass (Tier I, ilvl 1–6)      ──► Extraction Beacon ALPHA (60s Holdout)
   ├── Zone 2: Rusted Rail Yard (Tier II, ilvl 7–14)      ──► Extraction Beacon BRAVO (75s Holdout)
   ├── Zone 3: Spore-Flooded Bio-Metro (Tier III, 15–22)  ──► Hazard Zones + Locked Keycard Vaults
   └── Zone 4: Shattered Reactor Crater (Tier IV, 23–30)  ──► Boss Arena + Heavy Dropship OMEGA (90s)
```

### 5.2 AI Enemy Factions (`Nerve`-Driven State Machines)
1. **Ash Scavenger** (*Tier I Grunt*) — Light kinetic pistol/SMG, ducks behind graybox cover crates, flanks in pairs.
2. **Feral Stalker** (*Tier I–III Rush*) — Fast melee mutant (`Idle -> Stalk -> LeapTelegraph -> Pounce -> Recover`); pressures players out of cover so shields stay stressed.
3. **Raider Marksman** (*Tier II–III Sniper*) — Visible red laser sight telegraph (`1.1s` lock-on) before firing a high-shield-damage rail shot; teaches movement & cover timing.
4. **Spore Hazmat** (*Tier II–III Area Denial*) — Lobs corrosive/rad puddles that force repositioning and reward Hazard Resistance gear.
5. **Aegis Enforcer** (*Tier II–IV Elite — Halo Sangheili Homage*) — Equipped with a visible regenerating Energy Shield, plasma rifle, and sideways thruster roll when its shield breaks! Demands plasma weapons to strip shields + kinetic headshots to finish.
6. **Scrap Juggernaut** (*Tier III–IV Mini-Boss*) — Heavy front plating (`0.3x` frontal damage) with a glowing back power-cell weakpoint.
7. **Warden Goliath** (*Zone 4 Sector Boss*) — 3-phase `Nerve` boss (`Shielded Artillery -> Overheated Berserk -> Reactor Surge + Add Wave`) with guaranteed Epic/Legendary loot burst.

### 5.3 Co-op Extraction Holdout Sequence
1. Any player approaches an **Extraction Beacon** and activates the console.
2. A tall skybeam ignites and all players on the surface receive a **3D HUD NavPoint** (`EXTRACTION INBOUND — 75s`) so nearby co-op survivors can rally together.
3. `ExtractionService` runs a 5-state `Nerve` sequence:
   - `Idle` -> `Charging (0–35s, Wave 1 spawns)` -> `Surge (35–65s, Elite/Wave 2 spawns)` -> `BoardingWindow (15s green extraction ring open)` -> `Cooldown (45s)`.
4. Every living player standing inside the extraction ring when `BoardingWindow` completes (or immediately if all squadmates inside confirm) **banks all Raid Backpack items**, completes raid contracts, earns XP, heals to full, and returns to **Bastion Bunker** with a **Raid Summary Screen**.

---

## 6. UI/UX Architecture (`Nintendo LayoutActor` + `BotW` + `Diablo Grid`)

### 6.1 Architectural Rules
- **`LayoutActor` Base (`Client/UI/Core/LayoutActor.luau`)**: Every screen and HUD widget implements `{ init, appear, update, disappear, destroy }` driven by its own `Nerve` state (`Hidden -> Appearing -> Active -> Disappearing`) with crisp `140ms` `Quint`/`Back` tweens.
- **Unidirectional Data Flow (`zeldaret/botw` `uiPauseMenuDataMgr` pattern)**: UI components never mutate item tables directly. Client state store receives authoritative snapshots/deltas from `Remotes`, computes derived view models (stat totals, comparison diffs, durability warnings), and notifies subscribed `LayoutActor`s.
- **Visual Language**:
  - Dark tactical slate glass (`RGB 18, 21, 28` @ `0.12` transparency) with crisp `1px` `UIStroke` borders, high-contrast typography (`GothamBold` headers, `RobotoMono` numbers/timers), and unmistakable Diablo rarity border/glow accents.
  - Zero tiny unreadable text; responsive `UIScale` controller scaling cleanly across `1080p`, `1440p`, laptop screens, and console/gamepad safe zones.

### 6.2 Full V1 UI Screen Roster
1. **Combat Pro-HUD (`CombatHud`)**:
   - *Top-Center*: Halo-style segmented **Energy Shield Bar** (cyan, flashes amber/red with alarm beep on break) + slim **Body Health Bar** underneath + compass strip.
   - *Bottom-Left*: **Halo Motion Tracker (`25m` radar)** showing moving enemies/allies + Co-op Squadmate vitality cards + active Hazard Resistance indicator.
   - *Bottom-Right*: Active & Holstered Weapon cards, Ammo / Plasma Heat bar, Grenade cooldown, and `4` Belt Quickslots (`3–6`).
   - *Center / World-Space*: Dynamic per-weapon reticle (bloom expansion + hitmarker + shield-break icon + red headshot `X`), world-space **3D Extraction & Squad NavPoints**, and floating **World Loot Cards** when aiming at dropped items.
2. **Tactical Inventory & Paperdoll (`InventoryLayout` — `Tab`)**:
   - *Left Column*: **Character Paperdoll** + Live Aggregated Stats Panel (DPS, Shield Pool, Recharge Delay, Armor, Hazard Resist).
   - *Center Column*: **`10x5` Raid Backpack 2D Grid** + **`2x2` Secure Case** + `4-Slot Belt`.
   - *Right Column (Contextual)*: Opens dynamically into **World Loot Container Grid** (when looting a crate), **`10x12` Bunker Stash Grid** (in Bunker), **Vendor Shop**, or **Item Comparison Tooltip**.
3. **Rich Item Comparison Tooltip (`ItemTooltipActor`)**:
   - Instant side-by-side comparison vs. currently equipped slot (`+18% Shield Damage ▲` in emerald green, `-0.3s Reload ▲`, durability bar `48/60`, Prefix/Suffix breakdown, Legendary perk callout, and Scrap value).
4. **Bunker Station Screens**:
   - **Repair & Salvage Bench**: One-click *"Repair All Equipped (`X` Scrap)"*, individual repair, bulk salvage junk by rarity, and Affix Reroll slot.
   - **Contract Board**: Pick up to 3 active PvE contracts (e.g., *"Eliminate 4 Aegis Enforcers"*, *"Extract with 2 Reactor Relics"*).
5. **Post-Raid Extraction / Wipe Summary (`RaidSummaryLayout`)**:
   - Animated tally of extracted loot value, contracts completed, XP earned, or (on wipe) Secure Case kept + Durability Tax summary.

---

## 7. Phased V1 Production Roadmap (Milestones M1–M8)

Every milestone produces runnable, Studio-playable progress and expands `npm test` (`tests/*.spec.luau`) so regressions are caught automatically.

### Milestone 1 — Foundation: `Nerve` Core, `AssetRegistry` Graybox Kit & 2D Grid Engine
- **Deliverables**:
  - `Shared/Core/Nerve.luau`, `Shared/Core/Signal.luau`, `Shared/Core/Rng.luau`, `Shared/Net/RemotesSchema.luau`.
  - `Shared/Assets/AssetRegistry.luau` & `PrefabBuilder.luau` (procedural `BasePart` prefabs + attachment verification).
  - `Shared/Inventory/GridContainer.luau` (complete `DevilutionX`-inspired 2D spatial grid: place, rotate, swap, stack, auto-pack, serialize).
  - `Shared/Loot/AffixCatalog.luau`, `ItemCatalog.luau`, `LootRoller.luau`, `DurabilityMath.luau`.
- **Verification Gate**: Unit specs verifying `Nerve` step transitions, `GridContainer` collision/rotation/serialization invariants, and deterministic `LootRoller` affix generation across all 5 rarities.

### Milestone 2 — Halo Vitality, 3rd-Person Camera Director & Tactical Movement
- **Deliverables**:
  - `Client/Camera/CameraDirector.luau` & `CameraObserver.luau` (over-the-shoulder, shoulder swap, ADS zoom, wall-collision spring raycast).
  - `Client/Movement/MovementController.luau` (sprint, tactical slide, combat dodge/roll, ledge mantle).
  - `Shared/Combat/DamageMath.luau` & `ServerScriptService/Combat/VitalityService.luau` (Halo Energy Shield + stun delay + recharge + Body Health + Kinetic/Plasma/Corrosive/Explosive multipliers + downed/revive state).
- **Verification Gate**: Specs covering shield bleedthrough, stun reset, recharge math, headshot gating on shielded vs. unshielded targets, and client boot stub tests.

### Milestone 3 — Weapon Sandbox, Ballistics & Bunker Firing Range
- **Deliverables**:
  - All **8 graybox weapon models** (`BasePart` silhouettes + `Muzzle`/`Grip`/`Sight` attachments) welded cleanly to character rigs.
  - `Client/Weapons/WeaponController.luau` & `ServerScriptService/Combat/WeaponService.luau` (server-verified raycast + plasma projectile ballistics, bloom/recoil, magazine reload + Sol-Coil **Heat/Vent** mechanic, frag/EMP grenades).
  - Bunker **Live Firing Range** with Shielded & Unshielded target dummies displaying live floating damage numbers.
- **Verification Gate**: Server validation tests (fire-rate clamping, reload/heat lockout, ammo consumption, range falloff).

### Milestone 4 — Nintendo `LayoutActor` UI Suite: Pro-HUD, 2D Grid Inventory & Tooltips
- **Deliverables**:
  - `Client/UI/Core/LayoutActor.luau`, `Theme.luau`, `InputPrompts.luau`.
  - **Halo/BotW Combat Pro-HUD** (segmented shield/health bars, `25m` motion tracker radar, weapon/heat/belt HUD, dynamic reticles, hitmarkers).
  - **Interactive 2D Spatial Grid Inventory + Paperdoll + Secure Case UI** (drag-and-drop, `R` rotate preview, green/red cell footprint highlight, `Shift+Click` transfer, side-by-side `ItemTooltipActor` comparison cards).
- **Verification Gate**: Client UI harness tests verifying zero-freeze boot (HUD + Inventory built before server remotes resolve), bounded `WaitForChild`, and reactive state updates.

### Milestone 5 — Seamless Map: Bastion Bunker + 4-Zone Graybox Wasteland & Containers
- **Deliverables**:
  - Procedural/modular graybox construction of **Bastion Bunker** + **Zones 1–4** (Collapsed Overpass, Rusted Rail Yard, Spore Bio-Metro, Shattered Reactor Crater) with distinct silhouettes, cover props, lighting atmosphere, and **Surface Airlock Elevator**.
  - `ContainerService` (searchable crates, weapon lockers, keycard vault doors, dropped world loot beams with rarity pillars) + `HazardZoneService` (radiation/spore pockets mitigated by gear affixes/relics).
- **Verification Gate**: World layout & asset contract validation test ensuring every spawned container, hazard, and zone anchor exposes required attachments/tags.

### Milestone 6 — Enemy AI Factions (`Nerve` Brains) & Sector Boss
- **Deliverables**:
  - Graybox procedural rigs + `Nerve` AI controllers for all **6 enemy archetypes** (*Ash Scavenger*, *Feral Stalker*, *Raider Marksman*, *Spore Hazmat*, *Aegis Enforcer* with regenerating Halo shield & dodge, *Scrap Juggernaut*) + **Warden Goliath** 3-phase Sector Boss.
  - Zone encounter spawners, enemy shield/health bars, aggro perception sensors, and `TreasureClass` loot drops on death.
- **Verification Gate**: Headless AI `Nerve` simulation tests verifying state transitions (`Patrol -> Alert -> Engage -> ShieldBrokenRetreat -> Dead`) and loot drop generation.

### Milestone 7 — Extraction Holdout Loop, Death/Durability Tax & Bunker Economy
- **Deliverables**:
  - `ExtractionService` (Alpha, Bravo, and Omega extraction beacons, skybeams, 3D HUD NavPoints, multi-wave co-op holdout states, boarding bank transition, **Raid Summary Screen**).
  - Death/Wipe handler enforcing **Keep Equipped + `2x2` Secure Case + `-20%` Durability Tax** + dropped backpack cleanup.
  - Bunker **Repair & Salvage Bench** (repair durability, dismantle for Scrap, reroll affixes), **Quartermaster Vendor**, and **Contract Board**.
- **Verification Gate**: Full raid lifecycle integration spec (`Deploy -> Loot -> Fight -> Extract` AND `Deploy -> Loot -> Die -> Verify Secure Case + Equipped Kept + Durability Tax Applied`).

### Milestone 8 — Persistence, Co-op Scaling, Audio/VFX Polish & V1 Release Readiness
- **Deliverables**:
  - Safe `ProfileService`-style `DataStore` persistence (`ServerScriptService/Data/PlayerDataService.luau`) strictly obeying Template Rule #2 (zero `DataStoreService` access at load; automatic Studio offline fallback; schema migration & session locking).
  - Co-op squad scaling (enemy count/HP scales smoothly for 1–4 players on an extraction beacon), downed teammate revive prompt, procedural sound/VFX polish (shield pop, rarity drop chime, extraction siren), performance pooling, and full `build/game.rbxlx` verification.
- **Verification Gate**: Complete `npm test` suite green + place layout verification + full V1 playtest checklist.
