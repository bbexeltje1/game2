--!strict
-- Spatial & gameplay layout for the Seamless 1-Place World:
--   1. Bastion Bunker (Underground Safe Hub at Y = -120) + Live Firing Range
--   2. Ashen Wasteland Surface (4 Tiered Zones across 1200x1200 studs at Y = 0)
--   3. Extraction Beacons (Alpha, Bravo, Omega), Hazard Pockets, Loot Crates & Enemy Camps

export type ZoneDef = {
	id: string,
	name: string,
	tierLabel: string,
	minIlvl: number,
	maxIlvl: number,
	treasureClass: string,
	center: { x: number, y: number, z: number },
	size: { x: number, z: number },
	dropSpawn: { x: number, y: number, z: number },
	groundColor: { r: number, g: number, b: number },
}

export type BeaconDef = {
	id: string,
	name: string,
	zoneId: string,
	position: { x: number, y: number, z: number },
	holdoutSeconds: number,
	boardingSeconds: number,
	cooldownSeconds: number,
	radius: number,
	waveArchetypes: { string },
}

local BUNKER = {
	floorY = -120,
	spawn = { x = 0, y = -116, z = 8 },
	stations = {
		{
			id = "StashTerminal",
			kind = "Stash",
			title = "PERSONAL STASH [10x12]",
			subtitle = "Store weapons, armor & relics safely",
			pos = { x = -28, y = -116, z = -14 },
			color = { r = 72, g = 168, b = 255 },
		},
		{
			id = "Workbench",
			kind = "Workbench",
			title = "REPAIR & SALVAGE BENCH",
			subtitle = "Repair durability, salvage scrap & reroll affixes",
			pos = { x = 0, y = -116, z = -22 },
			color = { r = 255, g = 168, b = 58 },
		},
		{
			id = "Quartermaster",
			kind = "Vendor",
			title = "QUARTERMASTER VENDOR",
			subtitle = "Buy injectors, shield cells, keycards & gear",
			pos = { x = 28, y = -116, z = -14 },
			color = { r = 98, g = 232, b = 142 },
		},
		{
			id = "ContractBoard",
			kind = "Contracts",
			title = "BOUNTY CONTRACT BOARD",
			subtitle = "Accept repeatable Wasteland PvE contracts",
			pos = { x = -28, y = -116, z = 18 },
			color = { r = 212, g = 132, b = 255 },
		},
		{
			id = "AirlockZone1",
			kind = "Deploy",
			zoneId = "Zone1",
			title = "DEPLOY: ZONE 1 (OVERPASS)",
			subtitle = "Tier I [ilvl 1-6] - Low Threat",
			pos = { x = 24, y = -116, z = 12 },
			color = { r = 88, g = 228, b = 132 },
		},
		{
			id = "AirlockZone2",
			kind = "Deploy",
			zoneId = "Zone2",
			title = "DEPLOY: ZONE 2 (RAIL YARD)",
			subtitle = "Tier II [ilvl 7-14] - Medium Threat",
			pos = { x = 34, y = -116, z = 12 },
			color = { r = 255, g = 208, b = 74 },
		},
		{
			id = "AirlockZone3",
			kind = "Deploy",
			zoneId = "Zone3",
			title = "DEPLOY: ZONE 3 (BIO-METRO)",
			subtitle = "Tier III [ilvl 15-22] - Spore Hazard",
			pos = { x = 24, y = -116, z = 24 },
			color = { r = 192, g = 104, b = 255 },
		},
		{
			id = "AirlockZone4",
			kind = "Deploy",
			zoneId = "Zone4",
			title = "DEPLOY: ZONE 4 (REACTOR CRATER)",
			subtitle = "Tier IV [ilvl 23-30] - Boss Sector",
			pos = { x = 34, y = -116, z = 24 },
			color = { r = 255, g = 98, b = 58 },
		},
	},
	rangeDummies = {
		{
			id = "Dummy_Shielded",
			name = "Shielded Enforcer Target",
			pos = { x = -10, y = -116, z = -62 },
			maxShield = 120,
			maxHealth = 150,
			armorRating = 15,
		},
		{
			id = "Dummy_Unshielded",
			name = "Armored Ballistic Target",
			pos = { x = 10, y = -116, z = -62 },
			maxShield = 0,
			maxHealth = 200,
			armorRating = 25,
		},
	},
}

local ZONES: { [string]: ZoneDef } = {
	Zone1 = {
		id = "Zone1",
		name = "Collapsed Overpass",
		tierLabel = "TIER I • OUTSKIRTS",
		minIlvl = 1,
		maxIlvl = 6,
		treasureClass = "Tier1_Outskirts",
		center = { x = -260, y = 0, z = 260 },
		size = { x = 520, z = 520 },
		dropSpawn = { x = -140, y = 5, z = 140 },
		groundColor = { r = 98, g = 92, b = 82 },
	},
	Zone2 = {
		id = "Zone2",
		name = "Rusted Rail Yard",
		tierLabel = "TIER II • INDUSTRIAL",
		minIlvl = 7,
		maxIlvl = 14,
		treasureClass = "Tier2_RailYard",
		center = { x = 260, y = 0, z = 260 },
		size = { x = 520, z = 520 },
		dropSpawn = { x = 140, y = 5, z = 140 },
		groundColor = { r = 88, g = 78, b = 70 },
	},
	Zone3 = {
		id = "Zone3",
		name = "Spore-Flooded Bio-Metro",
		tierLabel = "TIER III • BIO-HAZARD",
		minIlvl = 15,
		maxIlvl = 22,
		treasureClass = "Tier3_BioMetro",
		center = { x = -260, y = 0, z = -260 },
		size = { x = 520, z = 520 },
		dropSpawn = { x = -140, y = 5, z = -140 },
		groundColor = { r = 64, g = 78, b = 68 },
	},
	Zone4 = {
		id = "Zone4",
		name = "Shattered Reactor Crater",
		tierLabel = "TIER IV • ENDGAME BOSS",
		minIlvl = 23,
		maxIlvl = 30,
		treasureClass = "Tier4_Reactor",
		center = { x = 260, y = 0, z = -260 },
		size = { x = 520, z = 520 },
		dropSpawn = { x = 140, y = 5, z = -140 },
		groundColor = { r = 58, g = 54, b = 64 },
	},
}

local EXTRACTION_BEACONS: { BeaconDef } = {
	{
		id = "Beacon_Alpha",
		name = "EXTRACTION ALPHA (Overpass)",
		zoneId = "Zone1",
		position = { x = -370, y = 1, z = 370 },
		holdoutSeconds = 35,
		boardingSeconds = 15,
		cooldownSeconds = 20,
		radius = 22,
		waveArchetypes = { "AshScavenger", "FeralStalker", "AshScavenger" },
	},
	{
		id = "Beacon_Bravo",
		name = "EXTRACTION BRAVO (Rail Yard)",
		zoneId = "Zone2",
		position = { x = 380, y = 1, z = 360 },
		holdoutSeconds = 45,
		boardingSeconds = 15,
		cooldownSeconds = 25,
		radius = 22,
		waveArchetypes = { "AshScavenger", "RaiderMarksman", "AegisEnforcer", "FeralStalker" },
	},
	{
		id = "Beacon_Delta",
		name = "METRO LIFT DELTA (Bio-Metro)",
		zoneId = "Zone3",
		position = { x = -395, y = 1, z = -380 },
		holdoutSeconds = 50,
		boardingSeconds = 16,
		cooldownSeconds = 28,
		radius = 24,
		waveArchetypes = { "FeralStalker", "SporeHazmat", "AegisEnforcer", "FeralStalker" },
	},
	{
		id = "Beacon_Omega",
		name = "DROPSHIP OMEGA (Reactor)",
		zoneId = "Zone4",
		position = { x = 410, y = 1, z = -210 },
		holdoutSeconds = 55,
		boardingSeconds = 18,
		cooldownSeconds = 30,
		radius = 26,
		waveArchetypes = { "AegisEnforcer", "SporeHazmat", "ScrapJuggernaut", "FeralStalker" },
	},
}

local HAZARD_ZONES = {
	{
		id = "Hazard_SporeWest",
		name = "Toxic Spore Pocket",
		position = { x = -270, y = 2, z = -250 },
		radius = 58,
		dps = 9,
		color = { r = 110, g = 235, b = 95 },
	},
	{
		id = "Hazard_SporeVault",
		name = "Bio-Metro Containment Leak",
		position = { x = -360, y = 2, z = -340 },
		radius = 46,
		dps = 12,
		color = { r = 110, g = 235, b = 95 },
	},
	{
		id = "Hazard_ReactorCore",
		name = "Ionizing Reactor Fallout",
		position = { x = 310, y = 2, z = -320 },
		radius = 74,
		dps = 15,
		color = { r = 255, g = 125, b = 45 },
	},
}

local ANOMALY_NODES = {
	{ id = "Anomaly_Spore1", pos = { x = -268, y = 2.5, z = -248 }, relicPool = { "SporePearl", "QuickSilverCoil" }, respawnSec = 85 },
	{ id = "Anomaly_Spore2", pos = { x = -358, y = 2.5, z = -338 }, relicPool = { "SporePearl", "FortuneCompass" }, respawnSec = 95 },
	{ id = "Anomaly_Reactor1", pos = { x = 308, y = 2.5, z = -318 }, relicPool = { "SolarShard", "FortuneCompass" }, respawnSec = 100 },
	{ id = "Anomaly_Reactor2", pos = { x = 335, y = 2.5, z = -355 }, relicPool = { "SolarShard", "QuickSilverCoil" }, respawnSec = 110 },
}

local LOOT_CONTAINERS = {
	-- Zone 1 Crates
	{ id = "Crate_Z1_1", kind = "SupplyCrate", pos = { x = -195, y = 2, z = 205 }, tc = "Tier1_Outskirts", locked = false },
	{ id = "Crate_Z1_2", kind = "SupplyCrate", pos = { x = -265, y = 2, z = 240 }, tc = "Tier1_Outskirts", locked = false },
	{ id = "Crate_Z1_3", kind = "MilitaryLocker", pos = { x = -315, y = 2, z = 290 }, tc = "Tier1_Outskirts", locked = false },
	{ id = "Crate_Z1_4", kind = "SupplyCrate", pos = { x = -230, y = 2, z = 340 }, tc = "Tier1_Outskirts", locked = false },
	-- Zone 2 Crates + Keycard Vault
	{ id = "Crate_Z2_1", kind = "SupplyCrate", pos = { x = 205, y = 2, z = 210 }, tc = "Tier2_RailYard", locked = false },
	{ id = "Crate_Z2_2", kind = "MilitaryLocker", pos = { x = 275, y = 2, z = 265 }, tc = "Tier2_RailYard", locked = false },
	{ id = "Crate_Z2_3", kind = "MilitaryLocker", pos = { x = 330, y = 2, z = 230 }, tc = "Tier2_RailYard", locked = false },
	{ id = "Vault_Z2_Armory", kind = "KeycardVault", pos = { x = 310, y = 2, z = 345 }, tc = "Vault_Locked", locked = true },
	-- Zone 3 Crates + Keycard Vault
	{ id = "Crate_Z3_1", kind = "MilitaryLocker", pos = { x = -210, y = 2, z = -200 }, tc = "Tier3_BioMetro", locked = false },
	{ id = "Crate_Z3_2", kind = "SupplyCrate", pos = { x = -275, y = 2, z = -255 }, tc = "Tier3_BioMetro", locked = false },
	{ id = "Crate_Z3_3", kind = "MilitaryLocker", pos = { x = -335, y = 2, z = -290 }, tc = "Tier3_BioMetro", locked = false },
	{ id = "Vault_Z3_Bio", kind = "KeycardVault", pos = { x = -370, y = 2, z = -355 }, tc = "Vault_Locked", locked = true },
	-- Zone 4 Endgame Reactor Caches
	{ id = "Crate_Z4_1", kind = "MilitaryLocker", pos = { x = 215, y = 2, z = -215 }, tc = "Tier4_Reactor", locked = false },
	{ id = "Crate_Z4_2", kind = "MilitaryLocker", pos = { x = 295, y = 2, z = -285 }, tc = "Tier4_Reactor", locked = false },
	{ id = "Crate_Z4_3", kind = "KeycardVault", pos = { x = 365, y = 2, z = -375 }, tc = "Vault_Locked", locked = true },
}

local ENEMY_CAMPS = {
	-- Zone 1
	{ id = "Camp_Z1_A", pos = { x = -210, y = 3, z = 225 }, enemies = { "AshScavenger", "AshScavenger" }, respawnSec = 38 },
	{ id = "Camp_Z1_B", pos = { x = -305, y = 3, z = 275 }, enemies = { "AshScavenger", "FeralStalker", "FeralStalker" }, respawnSec = 42 },
	{ id = "Camp_Z1_C", pos = { x = -250, y = 3, z = 345 }, enemies = { "AshScavenger", "FeralStalker" }, respawnSec = 40 },
	-- Zone 2
	{ id = "Camp_Z2_A", pos = { x = 220, y = 3, z = 225 }, enemies = { "AshScavenger", "RaiderMarksman" }, respawnSec = 45 },
	{ id = "Camp_Z2_B", pos = { x = 290, y = 3, z = 285 }, enemies = { "AegisEnforcer", "AshScavenger", "RaiderMarksman" }, respawnSec = 52 },
	{ id = "Camp_Z2_C", pos = { x = 330, y = 3, z = 335 }, enemies = { "AegisEnforcer", "FeralStalker" }, respawnSec = 50 },
	-- Zone 3
	{ id = "Camp_Z3_A", pos = { x = -225, y = 3, z = -220 }, enemies = { "FeralStalker", "FeralStalker", "SporeHazmat" }, respawnSec = 48 },
	{ id = "Camp_Z3_B", pos = { x = -315, y = 3, z = -285 }, enemies = { "AegisEnforcer", "SporeHazmat", "FeralStalker" }, respawnSec = 55 },
	{ id = "Camp_Z3_C", pos = { x = -355, y = 3, z = -345 }, enemies = { "ScrapJuggernaut", "SporeHazmat" }, respawnSec = 65 },
	-- Zone 4 + Boss Arena
	{ id = "Camp_Z4_A", pos = { x = 225, y = 3, z = -225 }, enemies = { "AegisEnforcer", "RaiderMarksman", "SporeHazmat" }, respawnSec = 55 },
	{ id = "Camp_Z4_B", pos = { x = 285, y = 3, z = -275 }, enemies = { "ScrapJuggernaut", "AegisEnforcer" }, respawnSec = 65 },
	{ id = "Camp_Z4_Boss", pos = { x = 345, y = 4, z = -345 }, enemies = { "WardenGoliath" }, respawnSec = 110 },
}

local WorldZones = {
	Bunker = BUNKER,
	Zones = ZONES,
	ExtractionBeacons = EXTRACTION_BEACONS,
	HazardZones = HAZARD_ZONES,
	AnomalyNodes = ANOMALY_NODES,
	LootContainers = LOOT_CONTAINERS,
	EnemyCamps = ENEMY_CAMPS,
}

function WorldZones.getZoneAtPosition(pos: Vector3): ZoneDef?
	if pos.Y < -40 then
		return nil -- Inside Bastion Bunker
	end
	for _, z in pairs(ZONES) do
		local halfX = z.size.x * 0.5
		local halfZ = z.size.z * 0.5
		if math.abs(pos.X - z.center.x) <= halfX and math.abs(pos.Z - z.center.z) <= halfZ then
			return z
		end
	end
	return ZONES.Zone1
end

return WorldZones
