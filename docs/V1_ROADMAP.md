# Wasteland Halo-Diablo Extraction Shooter — V1 Game Design & Production Roadmap

> **Working Title:** *ASHFALL: Bastion Protocol* (configurable in `Shared/Config.luau`)  
> **Engine & Toolchain:** Roblox (Rojo 7.7.1 + `--!strict` Luau + `luau-web` automated test harness + GitHub Actions CI)  
> **Visual Strategy for V1:** 100% Procedural Graybox (`BasePart` silhouettes + standardized `Attachment` contracts) engineered for zero-code `MeshPart` swapping post-V1.  
> **V1 Implementation Status:** **Milestones M1–M8 Complete (`35` `--!strict` Luau source files, all unit/client/place CI checks green)** — see `- [x]` / `- [ ]` checklists below.

---

## 0. Executive Progress Tracker

- [x] **Milestone 1** — Foundation: `Nerve` Core, `Sensor`, `PrefabBuilder` Graybox Kit & `DevilutionX` 2D Spatial Grid Engine
- [x] **Milestone 2** — Halo Vitality (`Energy Shield` + `Body Health`), 3rd-Person Camera Director & Tactical Movement
- [x] **Milestone 3** — 8-Archetype Weapon Sandbox (Kinetic + Sol-Coil Plasma Heat/Vent), Holstered Back-Weapons & Bunker Firing Range
- [x] **Milestone 4** — Nintendo `LayoutActor` UI Suite: Pro-HUD, 3D NavPoints, Floating Damage Numbers, Responsive `UIScale` & 2D Grid Inventory
- [x] **Milestone 5** — Seamless Single-Place World: Underground Bastion Bunker + 4-Zone Graybox Wasteland, Containers & Anomaly Hazards
- [x] **Milestone 6** — `Nerve`-Driven AI Enemy Factions (6 Archetypes + Raycast Steering) & 3-Phase *Warden Goliath* Sector Boss
- [x] **Milestone 7** — Co-op Extraction Holdout Beacons (Zones 1–4), Keep-Equipped + `2x2` Secure Case + `-20%` Durability Tax & Bunker Stations
- [x] **Milestone 8** — Lazy `DataStore` Persistence (Studio Offline Safe), Co-op Scaling, `SoundController` Studio Audio Pool & CI Verification
- [ ] **Post-V1 Art & Platform Pass** — High-detail `MeshPart` asset swaps into `ReplicatedStorage.Assets`, custom character animations & Gamepad/Mobile controls

---

## 1. Core Vision & Locked Design Pillars

A **Third-Person Post-Apocalyptic Co-op PvE Extraction Looter-Shooter** combining **Halo's** two-layer shield/health combat dance and tactical weapon sandbox with **Diablo's** deep procedural affix loot, durability economy, and 2D spatial grid inventory—built with **Nintendo's** state-machine rigor (`Nerve`) and clean UI lifecycle (`LayoutActor`).

| Pillar | V1 Locked Decision | Gameplay Impact |
| :--- | :--- | :--- |
| **Combat Structure** | **Co-op PvE Extraction (1–4 Players)** | Solo-viable or seamless co-op squads fighting post-apocalyptic AI factions, bosses, and extraction holdout waves. Zero PvP griefing; squadmates can revive downed allies and share extraction beacons. |
| **World Topology** | **Seamless Bunker + Wasteland (1 Place)** | Players spawn inside **Bastion Bunker** (Stash, Vendors, Repair/Salvage Bench, Contracts, Firing Range) and ride the **Surface Airlock Elevator** straight into the Wasteland on the same server. Instant playtesting in Roblox Studio with no `TeleportService` dependency. |
| **Death & Extraction Stakes** | **Keep Equipped Gear + Secure Case + Durability Tax** | Extracting via an active **Extraction Beacon** banks your entire raid backpack. Dying in the Wasteland drops unextracted raid backpack items, **keeps all equipped gear + your `2x2` Secure Case**, and applies a **Durability Tax** (`-20%` durability on equipped items, repaired at the Bunker with Scrap/Credits). |
| **Inventory & Loadout** | **Diablo / Tarkov 2D Spatial Grid + Full Paperdoll** | `10x5` Raid Backpack Grid, `10x12` Bunker Stash Grid, `2x2` Secure Case, item rotation (`R`), cursor ghost drag-and-drop, right-click quick-equip/transfer, `[AUTO-SORT]`, plus a full RPG Paperdoll (`Weapon 1`, `Weapon 2`, `Ordnance`, `Shield Core`, `Head`, `Chest`, `Legs`, `2x Relic`, `4-Slot Belt`). |

---

## 2. GitHub Reference Repositories & Clean-Room Luau Architecture

> **Engineering & Licensing Principle:** Console/PC decompilation repositories do not grant redistribution licenses for proprietary C/C++ code. We use them as **clean-room architectural blueprints**—studying their state-machine structures, data schemas, mathematical formulas, and UI lifecycles, and writing original, server-authoritative `--!strict` Luau modules tailored to Roblox.

| GitHub Repository | Studied Engine Subsystems | Implemented Clean-Room Luau Target in `src/` |
| :--- | :--- | :--- |
| **`MonsterDruide1/OdysseyDecomp`** & **`open-ead/sead`** | `lib/al/Library/Nerve/NerveKeeper.h` (tick-counted `Nerve` state machines), `HitSensor/` (decoupled actor messaging), `Layout/LayoutActor.h` (`appear -> wait -> action -> kill` UI lifecycle) | `Shared/Core/Nerve.luau`<br>`Shared/Core/Sensor.luau`<br>`Client/Core/LayoutActor.luau`<br>`Client/Audio/SoundController.luau` |
| **`zeldaret/botw`** (*Breath of the Wild*) | `src/KingSystem/Camera/` (3rd-person shoulder framing + raycast collision), `src/Game/UI/uiPauseMenuDataMgr.h` (strict separation of inventory data store from UI views + live stat comparison deltas + minimalist "Pro HUD") | `Client/Camera/CameraDirector.luau`<br>`Client/UI/ClientStore.luau`<br>`Client/UI/InventoryLayoutActor.luau` |
| **`halo-re/halo`** & **`bnunu/halo-ce-universal`** (*Halo: CE*) | `source/objects/damage.c` & `damage.h` (Energy Shield + Body Health vitality, stun delay, recharge rate, kinetic vs. plasma shield multipliers, bleedthrough), `source/items/weapons.c` (2-weapon + grenade sandbox, heat vs. mag), `source/interface/hud_unit.c`, `motion_sensor.c`, `hud_nav_points.c` | `Shared/Combat/DamageMath.luau`<br>`Shared/Weapons/WeaponCatalog.luau`<br>`Client/UI/CombatHudActor.luau`<br>`ServerScriptService/Modules/CombatAndWeaponService.luau` |
| **`diasurgical/DevilutionX`** (*Diablo 1*) & **`OpenDiablo2/OpenDiablo2`** (*Diablo 2*) | `Source/inv.h` & `inv.cpp` (signed-index 2D occupancy grid: `+itemIdx` anchor, `-itemIdx` covered cells), `Source/items.h` & D2 `TreasureClass` / `MagicPrefix` / `MagicSuffix` (`ilvl` rarity rolls, prefix/suffix stat ranges, `_iDurability`, unique perks, repair/salvage cost math) | `Shared/Inventory/GridContainer.luau`<br>`Shared/Loot/AffixCatalog.luau`<br>`Shared/Loot/LootRoller.luau`<br>`Shared/Economy/DurabilityMath.luau` |
| **`OpenXRay/xray-16`** (*S.T.A.L.K.E.R.*) | `src/xrGame/InventoryBox.cpp` (searchable world loot containers), `CustomOutfit.cpp` (environmental hazard resistances), `Artefact.cpp` (high-risk/high-reward wasteland relics with stat trade-offs) | `ServerScriptService/Modules/LootContainerService.luau`<br>`ServerScriptService/Modules/HazardZoneService.luau` |
| **`n64decomp/perfect_dark`** | Mission/contract difficulty scaling, secondary weapon fire modes, extraction objective state triggers | `ServerScriptService/Modules/BunkerStationService.luau`<br>`ServerScriptService/Modules/ExtractionService.luau` |

### Strict Adherence to This Repository's Four Rojo Rules
- [x] **Rule 1**: All client modules live strictly in `src/ReplicatedStorage/Client` (`ReplicatedStorage.ClientModules`), never beside `Main.client.luau`.
- [x] **Rule 2**: `DataStoreService` is never touched at module load—Studio sessions run automatically against an in-memory profile store, while published servers wrap `DataStoreService` inside lazy `pcall` handlers.
- [x] **Rule 3**: UI renders immediately before server round-trips, and 100% of `WaitForChild` calls across `src/` carry explicit timeouts with visible diagnostic status text on failure.
- [x] **Rule 4**: Zero functions attached onto Roblox `Instance`s—all entities, AI actors, weapons, and UI `LayoutActor`s are plain Luau tables/modules linked via registries and attributes.

---

## 3. Graybox-First (`BasePart`) Architecture & Model-Swap Contract

- [x] Centralized procedural geometry & override lookup in `Shared/Assets/PrefabBuilder.luau` (checks `ReplicatedStorage:FindFirstChild("Assets")` for drop-in `Model` overrides before building procedural `BasePart` graybox silhouettes).
- [x] **Weapons Contract** (`Weapon.<id>`): `PrimaryPart` (`Handle`), `MuzzleAttachment`, `GripAttachment`, `OffhandAttachment`, `SightAttachment`.
- [x] **Characters & Enemies Contract** (`Enemy.<id>`): `PrimaryPart` (`Root`), `HeadHitbox`, `TorsoHitbox`, `ShieldBubblePart`, `HealthBarAnchor`, `VitalityBillboard`.
- [x] **World Containers Contract** (`Container.<kind>`): `PrimaryPart` (`Base`), `LidPivot` (rotates open when searched), `InteractAnchor`, `LootBeamAttachment`.
- [x] **Extraction Beacons Contract** (`POI.ExtractionBeacon`): `PrimaryPart` (`Pad`), `BeaconPylon`, `SkyBeamAttachment`, `SirenAttachment`, `ZoneRadiusValue`.
- [x] **Wasteland Props & Anomalies**: `POI.AnomalyNode` (harvestable S.T.A.L.K.E.R. crystal clusters) & `Prop.RustedVehicle` (corroded road cover hulks).
- [ ] *(Post-V1 Optional)* Drop high-poly `MeshPart` art models into `ReplicatedStorage.Assets` matching the canonical IDs above.

---

## 4. Core Gameplay Systems Checklist

### 4.1 Third-Person Camera & Character Movement (`BotW` + `Halo`)
- [x] Over-the-shoulder 3rd-person `CameraDirector` (`Right` default, `[V]` swaps shoulder) with `[RMB]` ADS zoom framing.
- [x] Spring-damped raycast camera collision observer pulling smoothly forward along wall normals inside Bunker corridors and ruins.
- [x] `Nerve`-driven camera states: `Explore`, `Sprint`, `ADS`, `MenuInspect`.
- [x] Tactical movement (`MovementController.luau`): `[LeftShift]` Sprint, `[C]` Tactical Slide, `[LeftAlt]` Directional Thruster Dodge/Roll (modified by Leg Armor affixes), and forward raycast Ledge Mantle.

### 4.2 Halo Vitality & Damage Matrix (`Halo: CE` `damage.c` Model)
- [x] **Energy Shield Layer** (`MaxShield`, `ShieldRegenRate`, `ShieldStunDelay` base `3.5s`, stun reset on hit, smooth regen after stun expires).
- [x] **Shield Gating & Break Feedback**: Precision crits blocked while shield > `0`; shield depletion triggers **Shield Pop** visual shimmer (`PlayerShieldAura` / `ShieldBubblePart`), audio zap, and *On-Shield-Break* Shield Core perks.
- [x] **Body Health & Armor Layer** (`MaxHealth`, `ArmorRating` hyperbolic mitigation, unshielded `HeadHitbox` crits `1.5x–2.5x`, restored via Belt Med-Injectors or Bunker restock).
- [x] **Co-op Downed & Revive State**: Squadmates enter `15s` downed bleedout instead of instant wipe when living teammates are on the surface (`[E]` Revive).
- [x] **4-Element Damage Matrix**:
  - [x] **Kinetic** (`0.80x` vs. Shield / `1.25x` vs. Health + Headshot Crits)
  - [x] **Plasma** (`1.65x` vs. Shield / `0.85x` vs. Health)
  - [x] **Corrosive / Hazard** (`1.00x` vs. Shield / `1.10x` vs. Health + `20%` `ArmorRating` shred for `5s`)
  - [x] **Explosive** (`1.20x` vs. Shield & Health + splash radius falloff)

### 4.3 Weapon Sandbox (8 Graybox Archetypes + Ordnance)
- [x] Active right-hand grip weld (`EquippedGrayboxWeapon`) + Halo-style diagonal back-holstered secondary weapon weld (`HolsteredGrayboxWeapon`).
- [x] **MA-7 Wasteland Rifle** — Kinetic full-auto assault rifle (`3x2`).
- [x] **BR-55 Recon Burst** — Kinetic 3-round burst precision rifle (`3x2`).
- [x] **Sol-Coil Carbine** — Plasma rapid-fire rifle (`2x2`) using a **`0–100%` Heat Gauge**, `[R]` manual plasma vent, and `2.2s` overheat lockout.
- [x] **Trench Sweeper** — Kinetic 8-pellet pump scattergun (`3x2`).
- [x] **Viper PDW** — High-ROF close-quarters Kinetic SMG (`2x2`).
- [x] **Ferro-Rail Marksman** — High-velocity precision rail sniper (`4x2`, `2.35x` crit multiplier).
- [x] **M6D Bastion Sidearm** — High-caliber scoped utility pistol (`2x1`, `1.85x` crit multiplier).
- [x] **Arc Mortar** — Heavy plasma-explosive splash launcher (`3x2`).
- [x] **Tactical Ordnance (`[Q]` Throw / `[G]` Cycle)**: **EMP Plasma Grenade** (strips enemy shields in AoE) & **Shrapnel Frag Grenade**.

### 4.4 Diablo Itemization, Affixes, Durability & 2D Grid Inventory
- [x] **5 Rarity Tiers** (`Common`, `Uncommon`, `Rare`, `Epic`, `Legendary`) rolled from zone `TreasureClass` tables (`ilvl 1–30`) boosted by player `rarityFind`.
- [x] **Prefix & Suffix Affix Pool** (*Overcharged*, *High-Caliber*, *Hair-Trigger*, *Vampiric*, *Capacitive*, *Reinforced*, *of the Wasp*, *of Quick-Hands*, *of Scavenging*, *of Lead-Lining*, *of Thrusters*).
- [x] **8 Curated Named Legendaries** with bespoke gameplay perks (*Halo's Echo*, *Griswold's Trench-Breaker*, *Valkyrie Spear*, *Bastion's Last Word*, *Banshee's Wail*, *Thunderhead*, *Zero-Hour Aegis*, *Heart of Pripyat*).
- [x] **4 Halo Shield Core Archetypes** (*Standard*, *Wasp Fast-Charge*, *Bulwark Heavy*, *Nova EMP Core*) + **S.T.A.L.K.E.R. Trade-off Relics**.
- [x] **`DevilutionX` 2D Spatial Grid Engine (`GridContainer.luau`)**:
  - [x] `10x5` Raid Backpack, `10x12` Bunker Stash, `2x2` Secure Case, `6x4` World Loot Containers.
  - [x] `[R]` `90°` item rotation (`W x H` <-> `H x W`), single-blocker swap, stack merging, and one-click `compactSort` (`[AUTO-SORT]`).
- [x] **Death & Durability Tax Economy (`DurabilityMath.luau`)**:
  - [x] Raid wipe drops unextracted `10x5` Raid Backpack as world loot parcels, **preserves 100% of Paperdoll Equipped Gear + `2x2` Secure Case**, and applies `-20%` durability tax on equipped gear.
  - [x] Zero permanent item deletion at `0` durability (`50%` effectiveness *Damaged* state until repaired with Scrap at the Bunker).

---

## 5. Seamless World Map, Enemy Factions & Extraction Loop Checklist

### 5.1 Single-Place Seamless World (`WorldBuilderService.luau` + `WorldZones.luau`)
- [x] **Bastion Bunker (`Y = -120` Safe Underground Hub)**: `SpawnLocation`, Personal Stash Terminal, Repair/Salvage/Forge Workbench, Quartermaster Vendor, Bounty Contract Board, Live DPS Firing Range, and 4 Zone Deployment Airlock Pads.
- [x] **Zone 1 — Collapsed Overpass (`Tier I, ilvl 1–6`)**: Highway pillars, rusted vehicle cover hulks, Return Airlock, and **Extraction Beacon ALPHA**.
- [x] **Zone 2 — Rusted Rail Yard (`Tier II, ilvl 7–14`)**: Shipping container lanes, climbable Sniper Watchtower, locked Armory Keycard Vault, and **Extraction Beacon BRAVO**.
- [x] **Zone 3 — Spore-Flooded Bio-Metro (`Tier III, ilvl 15–22`)**: Toxic spore hazard pockets, bioluminescent spore pods, locked Bio-Vault, harvestable S.T.A.L.K.E.R. Anomaly Nodes, and **Metro Lift Beacon DELTA**.
- [x] **Zone 4 — Shattered Reactor Crater (`Tier IV, ilvl 23–30`)**: Heavy radiation hazard rings, harvestable Reactor Anomaly Nodes, locked Reactor Core Vault, **Warden Goliath Boss Arena**, and **Heavy Dropship OMEGA**.

### 5.2 `Nerve` AI Enemy Factions (`EnemyService.luau`)
- [x] Ground-height raycast snapping & forward obstacle-avoidance raycast steering around cover walls and containers.
- [x] **Ash Scavenger** (*Tier I Raider Grunt* — kinetic fire & strafe).
- [x] **Feral Stalker** (*Tier I–III Rush Mutant* — `LeapPounce` lunge attack).
- [x] **Raider Marksman** (*Tier II–III Sniper* — `1.05s` red laser `SniperTelegraph` lock-on beam before rail shot).
- [x] **Spore Hazmat** (*Tier II–III Area Denial* — corrosive blasts spawning lingering toxic acid pools via `HazardZoneService.spawnAcidPool`).
- [x] **Aegis Enforcer** (*Tier II–IV Shielded Elite* — regenerating Halo Energy Shield + `ShieldBreakEvade` lateral thruster burst on shield pop).
- [x] **Scrap Juggernaut** (*Tier III–IV Heavy* — `0.30x` frontal armor plate damage reduction + `1.75x` glowing rear `WeakpointCore`).
- [x] **Warden Goliath** (*Zone 4 3-Phase Sector Boss* — `450` Shield / `950` HP, Phase 2 Overdrive at `65%` HP, Phase 3 Reactor Surge shockwaves + Enforcer/Stalker add wave at `35%` HP, guaranteed high-tier `Boss_WardenGoliath` loot shower).

### 5.3 Co-op Extraction Holdout Sequence (`ExtractionService.luau`)
- [x] 5-state `Nerve` machine per beacon: `Idle -> Charging -> Surge -> BoardingWindow -> Cooldown` with co-op squad wave scaling.
- [x] Surface-wide HUD Extraction Banner + 3D screen-projected `hud_nav_points` distance waypoints + skyward neon flare beam.
- [x] Boarding ring extraction banking (`10x5` Backpack preserved, contracts progressed, bonus Credits/Scrap/XP awarded, full heal, return to Bastion Bunker + `RaidSummaryModal`).

---

## 6. UI/UX & Audio Suite Checklist

- [x] **`LayoutActor` Lifecycle (`Client/Core/LayoutActor.luau`)**: `Hidden -> Appearing -> Active -> Disappearing` `Nerve` state machine.
- [x] **Responsive Viewport Scaling (`Client/Hud.luau`)**: Automatic `ViewportSize`-driven `UIScale` (`0.56x–1.0x`) so docked Roblox Studio viewports (`~800x450`) and `1080p`/`1440p` monitors display every modal without clipping.
- [x] **Combat Pro-HUD (`CombatHudActor.luau`)**:
  - [x] Top-Center Halo Energy Shield Bar + stun/depleted warning pulse + Body Health Bar + Sector Indicator + Active Extraction Banner.
  - [x] Bottom-Left `25m` Halo Motion Tracker Radar (enemy, boss & extraction blips) + Level/Scrap/Credits strip.
  - [x] Bottom-Right Active & Holstered Weapon Deck, Ammo / Sol-Coil Plasma Heat Gauge, `[3–6]` Belt Quickslots & `[Q]` Ordnance status.
  - [x] Center Dynamic Bloom Reticle, color-coded Hitmarkers, 3D floating world `BillboardGui` damage numbers, 3D Extraction NavPoints, and `[E]` contextual prompt + `InteractHoverHighlight`.
- [x] **Tactical 2D Grid Inventory & Bunker Station Suite (`InventoryLayoutActor.luau` — `[TAB]`)**:
  - [x] Left Column: 8-Slot Character Paperdoll + 4 Belt Slots + Live Aggregated Loadout Stats.
  - [x] Center Column: `10x5` Raid Backpack (`[AUTO-SORT]` + `[R]` Rotate), `2x2` Secure Case, Drop-to-Ground button, floating cursor `HeldItemGhost` drag preview, and `BotW` live stat-delta Item Comparison Card.
  - [x] Right Column Contextual Tabs: `STASH` (`10x12` + `[AUTO-SORT]`), `CRATE` (`6x4` world container), `BENCH` (Repair All, Individual Repair, Bulk Salvage Commons, Individual Salvage, Affix Reforge), `VENDOR` (Quartermaster Requisitions), `BOUNTIES` (PvE Contracts), and `DEPLOY` (Zone 1–4 Airlocks).
  - [x] Fast Looting Controls: `Left-Click` pick up/swap, `Right-Click` quick-equip/belt (from Backpack) or quick-loot (from Crate/Stash), `Shift+Click` quick-transfer.
- [x] **Procedural Studio Audio Pool (`Client/Audio/SoundController.luau`)**: Built-in `rbxasset://sounds/...` cues for Kinetic/Plasma/Rail/Scatter/Launcher weapons, normal/crit/kill hitmarkers, Halo low-shield warning beep, shield pop, shield recharge, reload/plasma vent, UI click/rotate/error, rarity loot chimes, and extraction sirens.

---

## 7. Phased V1 Milestones & Verification Gates (M1–M8)

### Milestone 1 — Foundation: `Nerve` Core, `PrefabBuilder` Graybox Kit & 2D Grid Engine
- [x] `Shared/Core/Nerve.luau`, `Shared/Core/Sensor.luau`, `Shared/Core/Rng.luau`, `Shared/Net/RemotesSchema.luau`.
- [x] `Shared/Assets/PrefabBuilder.luau` (procedural `BasePart` prefabs + mandatory attachment/value contracts).
- [x] `Shared/Inventory/GridContainer.luau` (place, 90° rotate, single-item swap, stack merge, `compactSort`, serialize/deserialize).
- [x] `Shared/Loot/AffixCatalog.luau`, `Shared/Loot/LootRoller.luau`, `Shared/Economy/DurabilityMath.luau`.
- [x] **Verification Gate**: `tests/nerve-and-sensor.spec.luau`, `tests/grid-inventory.spec.luau`, `tests/loot-and-economy.spec.luau` passing.

### Milestone 2 — Halo Vitality, 3rd-Person Camera Director & Tactical Movement
- [x] `Client/Camera/CameraDirector.luau` (over-the-shoulder, `[V]` shoulder swap, `[RMB]` ADS zoom, wall-collision raycast).
- [x] `Client/Controllers/MovementController.luau` (sprint, tactical slide, directional thruster dodge, ledge mantle).
- [x] `Shared/Combat/DamageMath.luau` & server vitality loop (Energy Shield + stun delay + recharge + Body Health + 4-type Damage Matrix + downed/revive).
- [x] **Verification Gate**: `tests/halo-combat.spec.luau` passing.

### Milestone 3 — Weapon Sandbox, Ballistics & Bunker Firing Range
- [x] All 8 graybox weapon models welded to right hand (`EquippedGrayboxWeapon`) + holstered secondary on back (`HolsteredGrayboxWeapon`).
- [x] `Client/Controllers/WeaponClientController.luau` & `ServerScriptService/Modules/CombatAndWeaponService.luau` (raycast + splash ballistics, magazine reload + Sol-Coil Heat/Vent, EMP/Frag ordnance).
- [x] Bunker **Live DPS Firing Range** with Shielded & Armored target dummies + 3D floating damage numbers.
- [x] **Verification Gate**: Weapon stat, Plasma heat/broken-durability scaling & hitmarker feedback tests passing.

### Milestone 4 — Nintendo `LayoutActor` UI Suite: Pro-HUD, 2D Grid Inventory & Tooltips
- [x] `Client/Core/LayoutActor.luau`, `Client/UI/Theme.luau`, `Client/Hud.luau` (`ResponsiveScale` `UIScale`), `Client/UI/ClientStore.luau`.
- [x] `Client/UI/CombatHudActor.luau` (shield/health bars, `25m` radar, weapon/heat/belt deck, bloom reticle, 3D NavPoints, floating damage popups).
- [x] `Client/UI/InventoryLayoutActor.luau` (`HeldItemGhost`, `[R]` rotate, green/red footprint preview, `[AUTO-SORT]`, Right-Click quick-equip/transfer, `BotW` stat-delta comparison card).
- [x] **Verification Gate**: `tests/client.spec.luau`, `tests/client-interaction.spec.luau`, `tests/client-missing-remotes.spec.luau` passing.

### Milestone 5 — Seamless Map: Bastion Bunker + 4-Zone Graybox Wasteland & Containers
- [x] `ServerScriptService/Modules/WorldBuilderService.luau` & `Shared/World/WorldZones.luau` (Bastion Bunker + Zones 1–4 + Sniper Watchtower + Rusted Vehicles + Airlocks).
- [x] `ServerScriptService/Modules/LootContainerService.luau` (`LidPivot` crates/lockers, Keycard Vaults, Diablo rarity drop pillars) & `ServerScriptService/Modules/HazardZoneService.luau` (Rad/Spore hazards, lingering acid pools, harvestable `AnomalyNodes`).
- [x] **Verification Gate**: World zone, 4-beacon, anomaly node & prefab attachment contract assertions in `tests/loot-and-economy.spec.luau` passing.

### Milestone 6 — Enemy AI Factions (`Nerve` Brains) & Sector Boss
- [x] `Shared/World/EnemyCatalog.luau` & `ServerScriptService/Modules/EnemyService.luau` (6 faction archetypes + raycast ground/wall steering + `LeapPounce` + `SniperTelegraph` + `ShieldBreakEvade` + **Warden Goliath** 3-phase Sector Boss).
- [x] Zone camp spawners, world shield/HP billboards & `TreasureClass` loot bursts.
- [x] **Verification Gate**: AI `Nerve` & Halo shield/armor combat specs passing.

### Milestone 7 — Extraction Holdout Loop, Death/Durability Tax & Bunker Economy
- [x] `ServerScriptService/Modules/ExtractionService.luau` (Beacons *Alpha*, *Bravo*, *Delta*, *Omega*, 5-state holdout waves, `RaidSummaryActor.luau`).
- [x] Wipe handler enforcing **Keep Equipped Paperdoll + `2x2` Secure Case + `-20%` Durability Tax** + dropped raid backpack parcels.
- [x] `ServerScriptService/Modules/BunkerStationService.luau` (Repair, Salvage, Affix Reforge, Quartermaster Vendor, Bounty Contracts).
- [x] **Verification Gate**: Wipe penalty, Griswold Legendary durability perk, Secure Case preservation & Raid Summary specs passing.

### Milestone 8 — Persistence, Co-op Scaling, Audio/VFX Polish & V1 Release Readiness
- [x] `ServerScriptService/Modules/PlayerDataService.luau` (Rule #2 compliant lazy `DataStore` persistence + Studio offline fallback + `BindToClose`).
- [x] Co-op extraction scaling, `[E]` teammate revive, `Client/Audio/SoundController.luau` Studio audio pool, and GitHub Actions CI (`rojo build`, `npm test`, PowerShell syntax check, `place-check.mjs`).
- [x] **Verification Gate**: Full CI workflow green on `arena/fe593977-game2`.
