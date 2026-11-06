import fs from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { LuauState } from "luau-web";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceRoot = path.join(root, "src");
const testRoot = path.join(root, "tests");
const read = (p) => fs.readFile(path.join(root, p), "utf8");

async function findLuau(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await findLuau(full)));
    else if (entry.isFile() && entry.name.endsWith(".luau")) files.push(full);
  }
  return files.sort();
}

const state = await LuauState.createAsync();
try {
  // 1. Every source file in src/ must compile cleanly as valid Luau.
  const sources = await findLuau(sourceRoot);
  for (const file of sources) {
    const source = await fs.readFile(file, "utf8");
    state.loadstring(source, path.relative(root, file), true);
  }
  console.log(`PASS Luau syntax: ${sources.length} source files`);

  // 2. Shared config must be a plain table with the keys the docs promise.
  const config = await read("src/ReplicatedStorage/Shared/Config.luau");
  const configSpec = await read("tests/config.spec.luau");
  await state.loadstring(`local Config=(function()\n${config}\nend)()\n${configSpec}`, "config.spec.luau", true)();

  // 3. Unit & Integration Specs for Shared Gameplay Engines (Nerve, Sensor, Halo Combat,
  //    DevilutionX 2D Spatial Grid, Diablo LootRoller, Plasma Weapons & Wipe Durability Tax).
  const sharedModulesOrder = [
    { root: "Shared", segs: ["Config"], path: "src/ReplicatedStorage/Shared/Config.luau" },
    { root: "Shared", segs: ["Core", "Nerve"], path: "src/ReplicatedStorage/Shared/Core/Nerve.luau" },
    { root: "Shared", segs: ["Core", "Sensor"], path: "src/ReplicatedStorage/Shared/Core/Sensor.luau" },
    { root: "Shared", segs: ["Core", "Rng"], path: "src/ReplicatedStorage/Shared/Core/Rng.luau" },
    { root: "Shared", segs: ["Net", "RemotesSchema"], path: "src/ReplicatedStorage/Shared/Net/RemotesSchema.luau" },
    { root: "Shared", segs: ["Combat", "DamageMath"], path: "src/ReplicatedStorage/Shared/Combat/DamageMath.luau" },
    { root: "Shared", segs: ["Weapons", "WeaponCatalog"], path: "src/ReplicatedStorage/Shared/Weapons/WeaponCatalog.luau" },
    { root: "Shared", segs: ["Loot", "AffixCatalog"], path: "src/ReplicatedStorage/Shared/Loot/AffixCatalog.luau" },
    { root: "Shared", segs: ["Loot", "LootRoller"], path: "src/ReplicatedStorage/Shared/Loot/LootRoller.luau" },
    { root: "Shared", segs: ["Inventory", "GridContainer"], path: "src/ReplicatedStorage/Shared/Inventory/GridContainer.luau" },
    { root: "Shared", segs: ["Economy", "DurabilityMath"], path: "src/ReplicatedStorage/Shared/Economy/DurabilityMath.luau" },
    { root: "Shared", segs: ["World", "EnemyCatalog"], path: "src/ReplicatedStorage/Shared/World/EnemyCatalog.luau" },
    { root: "Shared", segs: ["World", "WorldZones"], path: "src/ReplicatedStorage/Shared/World/WorldZones.luau" },
  ];

  const clientModulesOrder = [
    { root: "ClientModules", segs: ["Hud"], path: "src/ReplicatedStorage/Client/Hud.luau" },
    { root: "ClientModules", segs: ["UI", "Theme"], path: "src/ReplicatedStorage/Client/UI/Theme.luau" },
    { root: "ClientModules", segs: ["Core", "LayoutActor"], path: "src/ReplicatedStorage/Client/Core/LayoutActor.luau" },
    { root: "ClientModules", segs: ["UI", "ClientStore"], path: "src/ReplicatedStorage/Client/UI/ClientStore.luau" },
    { root: "ClientModules", segs: ["UI", "CombatHudActor"], path: "src/ReplicatedStorage/Client/UI/CombatHudActor.luau" },
    { root: "ClientModules", segs: ["UI", "InventoryLayoutActor"], path: "src/ReplicatedStorage/Client/UI/InventoryLayoutActor.luau" },
    { root: "ClientModules", segs: ["UI", "RaidSummaryActor"], path: "src/ReplicatedStorage/Client/UI/RaidSummaryActor.luau" },
    { root: "ClientModules", segs: ["Camera", "CameraDirector"], path: "src/ReplicatedStorage/Client/Camera/CameraDirector.luau" },
    { root: "ClientModules", segs: ["Controllers", "MovementController"], path: "src/ReplicatedStorage/Client/Controllers/MovementController.luau" },
    { root: "ClientModules", segs: ["Controllers", "WeaponClientController"], path: "src/ReplicatedStorage/Client/Controllers/WeaponClientController.luau" },
  ];

  const stub = await read("tests/client-stub.luau");
  const tag = await read("src/ReplicatedStorage/Shared/BuildTag.luau").catch(() => 'return { tag = "dev" }\n');

  // Build identity-based Roblox module loader in Luau so `script.Parent...` & `WaitForChild`
  // resolve real ModuleScript instances in topological order.
  let moduleBootstrap = `
local __byModule = {}
require = function(mod)
  local val = __byModule[mod]
  if val == nil then
    error("no module registered for " .. tostring(mod and mod.Name))
  end
  return val
end
__byModule[tagModule] = (function()\n${tag}\nend)()
`;

  for (const m of [...sharedModulesOrder, ...clientModulesOrder]) {
    const code = await read(m.path);
    const segList = m.segs.map((s) => `"${s}"`).join(", ");
    const varExport = m.segs[m.segs.length - 1];
    const isPrecreated =
      (m.root === "Shared" && m.segs.length === 1 && m.segs[0] === "Config") ||
      (m.root === "ClientModules" && m.segs.length === 1 && m.segs[0] === "Hud");
    const nodeExpr = isPrecreated
      ? m.segs[0] === "Config"
        ? "configModule"
        : "hudModule"
      : `makeModuleNode(${m.root}, { ${segList} })`;
    moduleBootstrap += `
local ${varExport}
do
  local __modInst = ${nodeExpr}
  ${varExport} = (function()
    local script = __modInst
${code}
  end)()
  __byModule[__modInst] = ${varExport}
end
`;
  }

  for (const specFile of [
    "tests/nerve-and-sensor.spec.luau",
    "tests/halo-combat.spec.luau",
    "tests/grid-inventory.spec.luau",
    "tests/loot-and-economy.spec.luau",
  ]) {
    const specCode = await read(specFile);
    await state.loadstring(`${stub}\n${moduleBootstrap}\n${specCode}`, path.basename(specFile), true)();
  }

  // 4. Boot the real Main.client.luau (including full Pro-HUD, 2D Grid Inventory, Raid Summary &
  //    Controllers) against the strict stub: HUD built, build stamp shown, remotes found.
  const client = await read("src/StarterPlayer/StarterPlayerScripts/Main.client.luau");
  const clientSpec = await read("tests/client.spec.luau");
  const clientInteractionSpec = await read("tests/client-interaction.spec.luau");
  const extraClientChecks = `
assert(gui:FindFirstChild("CombatProHud") ~= nil, "CombatProHud LayoutActor mounted")
assert(gui:FindFirstChild("TacticalInventoryModal") ~= nil, "2D Grid TacticalInventoryModal mounted")
assert(gui:FindFirstChild("RaidSummaryModal") ~= nil, "RaidSummaryModal mounted")
`;
  await state.loadstring(
    `${stub}\n${moduleBootstrap}\nlocal function bootClient()\n${client}\nend\nbootClient()\n${clientSpec}\n${extraClientChecks}\n${clientInteractionSpec}`,
    "client.spec.luau",
    true
  )();

  // Second variant: the server never published its remotes. The client must still draw its
  // interface and say so, instead of freezing on an endless wait.
  const missingSpec = await read("tests/client-missing-remotes.spec.luau");
  await state.loadstring(
    `${stub}\n${moduleBootstrap}\nHARNESS_DROP_REMOTES()\nlocal function bootClient()\n${client}\nend\nbootClient()\n${missingSpec}`,
    "client-missing-remotes.spec.luau",
    true
  )();

  // 5. Place layout verification.
  const placeFile = process.argv[2] || path.join(root, "build", "game.rbxlx");
  if (!existsSync(placeFile)) {
    console.log(`FAIL Place file: ${placeFile} is missing. Run .\\scripts\\play.ps1 (or rojo build) first.`);
    process.exitCode = 1;
  } else {
    execFileSync(process.execPath, [path.join(testRoot, "place-check.mjs"), placeFile], { stdio: "inherit" });
  }
} finally {
  state.destroy();
}
