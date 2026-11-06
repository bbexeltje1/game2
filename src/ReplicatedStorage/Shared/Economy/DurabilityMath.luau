--!strict
-- Extraction & Wipe Durability Tax economy (Diablo Griswold repair + Salvage + Reroll +
-- Quartermaster Vendor + Repeatable PvE Wasteland Contracts).

local Config = require(script.Parent.Parent.Config)
local AffixCatalog = require(script.Parent.Parent.Loot.AffixCatalog)
local LootRoller = require(script.Parent.Parent.Loot.LootRoller)
local GridContainer = require(script.Parent.Parent.Inventory.GridContainer)

export type ContractDef = {
	id: string,
	title: string,
	description: string,
	kind: "KillArchetype" | "KillAny" | "ExtractCount" | "ExtractItem",
	targetKey: string,
	goal: number,
	rewardScrap: number,
	rewardCredits: number,
	rewardXp: number,
	rewardRarity: AffixCatalog.RarityId?,
	rewardBaseId: string?,
	rewardIlvl: number?,
}

local VENDOR_CATALOG = {
	{ id = "Buy_MedInjector", baseId = "MedInjector", rarity = "Common" :: "Common", ilvl = 1, stack = 2, costCredits = 45 },
	{ id = "Buy_ShieldCell", baseId = "ShieldCell", rarity = "Common" :: "Common", ilvl = 1, stack = 2, costCredits = 55 },
	{ id = "Buy_RadFlush", baseId = "RadFlush", rarity = "Common" :: "Common", ilvl = 1, stack = 2, costCredits = 50 },
	{ id = "Buy_VaultKeycard", baseId = "VaultKeycard", rarity = "Rare" :: "Rare", ilvl = 10, stack = 1, costCredits = 190 },
	{ id = "Buy_SolCoil", baseId = "SolCoilCarbine", rarity = "Uncommon" :: "Uncommon", ilvl = 6, stack = 1, costCredits = 220 },
	{ id = "Buy_BR55", baseId = "BR55Burst", rarity = "Uncommon" :: "Uncommon", ilvl = 6, stack = 1, costCredits = 210 },
	{ id = "Buy_SiphonCore", baseId = "SiphonCore", rarity = "Rare" :: "Rare", ilvl = 8, stack = 1, costCredits = 290 },
	{ id = "Buy_HazmatHood", baseId = "HazmatHood", rarity = "Uncommon" :: "Uncommon", ilvl = 8, stack = 1, costCredits = 165 },
}

local CONTRACTS: { ContractDef } = {
	{
		id = "Contract_OutskirtsSweep",
		title = "Overpass Clearance",
		description = "Eliminate 6 Wasteland hostiles across any surface sector.",
		kind = "KillAny",
		targetKey = "Any",
		goal = 6,
		rewardScrap = 75,
		rewardCredits = 140,
		rewardXp = 120,
		rewardRarity = "Uncommon",
		rewardBaseId = "BR55Burst",
		rewardIlvl = 6,
	},
	{
		id = "Contract_ShieldBreakers",
		title = "Break the Aegis",
		description = "Eliminate 3 Shielded Aegis Enforcers in Zones 2–4.",
		kind = "KillArchetype",
		targetKey = "AegisEnforcer",
		goal = 3,
		rewardScrap = 120,
		rewardCredits = 240,
		rewardXp = 220,
		rewardRarity = "Rare",
		rewardBaseId = "SolCoilCarbine",
		rewardIlvl = 12,
	},
	{
		id = "Contract_StalkerCull",
		title = "Bio-Metro Purge",
		description = "Eliminate 5 Feral Stalkers before they overrun the airlocks.",
		kind = "KillArchetype",
		targetKey = "FeralStalker",
		goal = 5,
		rewardScrap = 95,
		rewardCredits = 180,
		rewardXp = 165,
		rewardRarity = "Rare",
		rewardBaseId = "TrenchSweeper",
		rewardIlvl = 10,
	},
	{
		id = "Contract_BeaconRunner",
		title = "Signal Verified",
		description = "Complete 1 successful Extraction Beacon holdout from the surface.",
		kind = "ExtractCount",
		targetKey = "Any",
		goal = 1,
		rewardScrap = 85,
		rewardCredits = 160,
		rewardXp = 150,
		rewardRarity = "Rare",
		rewardBaseId = "NovaCore",
		rewardIlvl = 10,
	},
	{
		id = "Contract_CoreRecovery",
		title = "Reactor Salvage",
		description = "Extract alive carrying an Intact Fusion Core from Zone 3/4 or Vaults.",
		kind = "ExtractItem",
		targetKey = "ReactorCoreRelic",
		goal = 1,
		rewardScrap = 180,
		rewardCredits = 420,
		rewardXp = 350,
		rewardRarity = "Epic",
		rewardBaseId = "FerroRail",
		rewardIlvl = 18,
	},
	{
		id = "Contract_WardenProtocol",
		title = "Protocol: Goliath",
		description = "Defeat Warden Goliath in the Shattered Reactor Crater.",
		kind = "KillArchetype",
		targetKey = "WardenGoliath",
		goal = 1,
		rewardScrap = 260,
		rewardCredits = 600,
		rewardXp = 550,
		rewardRarity = "Legendary",
		rewardBaseId = "SolCoilCarbine",
		rewardIlvl = 25,
	},
}

local DurabilityMath = {
	VendorCatalog = VENDOR_CATALOG,
	Contracts = CONTRACTS,
}

function DurabilityMath.getRepairCost(item: LootRoller.ItemInstance): number
	if item.maxDurability <= 0 or item.durability >= item.maxDurability then
		return 0
	end
	local missing = item.maxDurability - item.durability
	local rDef = AffixCatalog.Rarities[item.rarity]
	local rarityScale = if rDef then (0.8 + rDef.order * 0.25) else 1.0
	return math.max(1, math.ceil(missing * Config.economy.scrapPerDurabilityPoint * rarityScale))
end

function DurabilityMath.getSalvageYield(item: LootRoller.ItemInstance): { scrap: number, credits: number }
	if item.baseId == "ScrapBundle" then
		return { scrap = item.stack, credits = 0 }
	end
	local rDef = AffixCatalog.Rarities[item.rarity]
	local order = if rDef then rDef.order else 1
	local scrap = math.max(2, math.floor((4 + item.ilvl * 0.9) * order * item.stack))
	local credits = math.max(5, math.floor(item.value * 0.45 * item.stack))
	return { scrap = scrap, credits = credits }
end

function DurabilityMath.getRerollCost(item: LootRoller.ItemInstance): number
	local rDef = AffixCatalog.Rarities[item.rarity]
	local order = if rDef then rDef.order else 1
	return math.floor(Config.economy.rerollBaseScrap * (0.7 + order * 0.45) + item.ilvl * 2)
end

-- Applies the locked V1 Death Penalty:
-- 1. Unextracted Raid Backpack items are dropped & returned as a list.
-- 2. Paperdoll Equipped Gear + 2x2 Secure Case + Belt are KEPT!
-- 3. Equipped Gear suffers -20% of maxDurability (Griswold's Edge perk halves durability loss).
function DurabilityMath.applyWipePenalty(
	backpack: GridContainer.GridData,
	paperdoll: { [string]: LootRoller.ItemInstance? }
): {
	droppedItems: { LootRoller.ItemInstance },
	totalDurabilityLost: number,
	affectedSlots: number,
}
	local dropped = GridContainer.clearAll(backpack)
	local totalLost = 0
	local affected = 0

	for _, slotName in ipairs(GridContainer.PaperdollSlots) do
		local equipped = paperdoll[slotName]
		if equipped and equipped.maxDurability > 0 then
			local taxFrac = Config.economy.deathDurabilityTaxFraction
			if equipped.perkId == "pelletShieldRestore" then
				taxFrac *= 0.5 -- Griswold's Trench-Breaker Legendary perk
			end
			local loss = math.max(1, math.floor(equipped.maxDurability * taxFrac + 0.5))
			local before = equipped.durability
			equipped.durability = math.max(0, equipped.durability - loss)
			totalLost += (before - equipped.durability)
			affected += 1
		end
	end

	return {
		droppedItems = dropped,
		totalDurabilityLost = totalLost,
		affectedSlots = affected,
	}
end

return DurabilityMath
