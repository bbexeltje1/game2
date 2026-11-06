-- Unit specs for Diablo LootRoller, Named Legendaries, Plasma Heat stats & Wipe Durability Tax.
local rng = Rng.new(20261106)

-- 1. Roll 40 items across Tier 1 -> Boss TreasureClass and verify invariants
local sawAffix = false
local sawHighRarity = false
for i = 1, 40 do
	local tc = if i <= 15 then "Tier1_Outskirts" elseif i <= 30 then "Tier3_BioMetro" else "Boss_WardenGoliath"
	local item = LootRoller.rollFromTreasureClass(tc, rng, 0.5)
	assert(type(item.uid) == "string" and #item.name > 0, "Rolled item has uid and name")
	if #item.affixes > 0 then
		sawAffix = true
	end
	if item.rarity == "Epic" or item.rarity == "Legendary" then
		sawHighRarity = true
	end
end
assert(sawAffix, "LootRoller generates Prefix/Suffix affixes")
assert(sawHighRarity, "Boss/High-tier TreasureClass drops Epic/Legendary gear")

-- 2. Verify Named Legendary perks & Plasma Heat weapon stats
local halosEcho = LootRoller.createSpecificItem("SolCoilCarbine", "Legendary", 20, 1, 777)
assert(halosEcho.name == "Halo's Echo" and halosEcho.perkId == "chainShieldArc", "Sol-Coil Legendary resolves to Halo's Echo")
local wStats = WeaponCatalog.computeStats(halosEcho, nil)
assert(wStats.usesHeat == true and wStats.damageType == "Plasma", "Sol-Coil uses Halo Plasma Heat/Vent mechanics")

-- 0-durability broken items deal 50% damage instead of deleting themselves
local fullDmg = wStats.damage
halosEcho.durability = 0
local brokenStats = WeaponCatalog.computeStats(halosEcho, nil)
assert(brokenStats.isBroken == true and math.abs(brokenStats.damage - fullDmg * 0.5) < 0.2, "0-durability weapon scales to 50% without deleting")
halosEcho.durability = halosEcho.maxDurability

-- 3. Verify Wipe Penalty: Backpack dropped, Paperdoll + 2x2 Secure Case KEPT, -20% Durability Tax!
local backpack = GridContainer.new(10, 5)
local secureCase = GridContainer.new(2, 2)
local raidLoot = LootRoller.createSpecificItem("ReactorCoreRelic", "Epic", 25, 1, 888) -- 1x2 fits in 2x2 Secure Case!
local looseScrap = LootRoller.createSpecificItem("ScrapBundle", "Common", 1, 35, 889)
assert(GridContainer.autoPlace(secureCase, raidLoot) == true, "1x2 Fusion Core fits inside 2x2 Secure Case")
assert(GridContainer.autoPlace(backpack, looseScrap) == true, "Loose scrap placed in Raid Backpack")

local griswoldShotgun = LootRoller.createSpecificItem("TrenchSweeper", "Legendary", 15, 1, 890) -- 50% less durability loss perk!
local armor = LootRoller.createSpecificItem("VanguardRig", "Rare", 15, 1, 891)
local paperdoll = {
	Primary1 = halosEcho, -- maxDur 60 -> loses 12 -> 48
	Primary2 = griswoldShotgun, -- maxDur 60 -> halved perk loses 6 -> 54
	Chest = armor, -- maxDur 85 -> loses 17 -> 68
}

local penalty = DurabilityMath.applyWipePenalty(backpack, paperdoll)
assert(#penalty.droppedItems == 1 and penalty.droppedItems[1].uid == looseScrap.uid, "Unextracted Backpack items drop on wipe")
assert(#GridContainer.listItems(backpack) == 0, "Backpack is emptied on wipe")
assert(secureCase.entries[raidLoot.uid] ~= nil, "2x2 Secure Case item is 100% preserved on wipe!")
assert(paperdoll.Primary1 == halosEcho and halosEcho.durability == 48, "Standard equipped weapon takes -20% durability tax (60 -> 48)")
assert(griswoldShotgun.durability == 54, "Griswold's Trench-Breaker Legendary perk halves durability tax (60 -> 54)")
assert(DurabilityMath.getRepairCost(halosEcho) > 0, "Damaged gear reports positive Scrap repair cost")

-- 4. Verify WorldZones (4 Surface Beacons across Zones 1-4 + 4 Anomaly Nodes) & PrefabBuilder Contracts
assert(#WorldZones.ExtractionBeacons == 4, "All 4 surface Wasteland zones have dedicated Extraction Beacons")
assert(#WorldZones.AnomalyNodes == 4, "4 S.T.A.L.K.E.R. harvestable Anomaly Relic nodes configured")

local gunModel = PrefabBuilder.buildWeapon("MA7Rifle")
assert(gunModel.PrimaryPart ~= nil and gunModel.PrimaryPart:FindFirstChild("MuzzleAttachment") ~= nil, "Weapon prefab exposes MuzzleAttachment contract")
assert(gunModel.PrimaryPart:FindFirstChild("GripAttachment") ~= nil and gunModel.PrimaryPart:FindFirstChild("SightAttachment") ~= nil, "Weapon prefab exposes Grip & Sight attachments")

local enforcerDef = EnemyCatalog.Enemies.AegisEnforcer
local enemyModel = PrefabBuilder.buildEnemyRig({
	id = enforcerDef.id,
	name = enforcerDef.name,
	scale = enforcerDef.scale,
	bodyColor = enforcerDef.bodyColor,
	accentColor = enforcerDef.accentColor,
	hasShield = enforcerDef.maxShield > 0,
	hasFrontPlate = enforcerDef.hasFrontPlate,
	isBoss = enforcerDef.isBoss,
})
local headPart = enemyModel:FindFirstChild("HeadHitbox")
assert(headPart ~= nil and headPart:FindFirstChild("HealthBarAnchor") ~= nil, "Enemy prefab exposes HeadHitbox + HealthBarAnchor contract")

local crateModel = PrefabBuilder.buildContainer("MilitaryLocker", CFrame.new(0, 0, 0), false)
assert(crateModel:FindFirstChild("LidPivot") ~= nil, "Container prefab exposes LidPivot contract")

local beaconModel = PrefabBuilder.buildExtractionBeacon("EXTRACTION ALPHA", Vector3.new(0, 1, 0), 22)
assert(beaconModel:FindFirstChild("ZoneRadiusValue") ~= nil, "Beacon prefab exposes ZoneRadiusValue contract")
assert(PrefabBuilder.buildAnomalyNode("Anomaly_Spore1", Vector3.new(0, 1, 0)).PrimaryPart ~= nil, "AnomalyNode prefab builds cleanly")
assert(PrefabBuilder.buildRustedVehicle(CFrame.new(0, 0, 0)).PrimaryPart ~= nil, "RustedVehicle prefab builds cleanly")

print("PASS Loot, Plasma Weapons, Wipe Tax & Graybox Prefab Contracts verified")
