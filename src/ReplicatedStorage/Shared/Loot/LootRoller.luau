--!strict
-- Clean-room Diablo 3-stage Loot Generator + Loadout Character Sheet Aggregator + BotW-style
-- side-by-side Item Comparison Delta Calculator (`zeldaret/botw` `uiPauseMenuDataMgr` pattern).

local Config = require(script.Parent.Parent.Config)
local Rng = require(script.Parent.Parent.Core.Rng)
local WeaponCatalog = require(script.Parent.Parent.Weapons.WeaponCatalog)
local AffixCatalog = require(script.Parent.AffixCatalog)

export type RolledAffix = {
	id: string,
	name: string,
	kind: "Prefix" | "Suffix",
	statKey: string,
	value: number,
	label: string,
}

export type ItemInstance = {
	uid: string,
	baseId: string,
	name: string,
	category: AffixCatalog.ItemCategory,
	rarity: AffixCatalog.RarityId,
	ilvl: number,
	gridW: number,
	gridH: number,
	rotated: boolean,
	stack: number,
	maxStack: number,
	durability: number,
	maxDurability: number,
	value: number,
	rarityPowerMult: number,
	affixes: { RolledAffix },
	stats: { [string]: number },
	perkId: string?,
	perkTitle: string?,
	perkDescription: string?,
}

export type TreasureClass = {
	id: string,
	minIlvl: number,
	maxIlvl: number,
	rarityBonus: number,
	pool: { { key: string, weight: number } },
}

local TREASURE_CLASSES: { [string]: TreasureClass } = {
	Tier1_Outskirts = {
		id = "Tier1_Outskirts",
		minIlvl = 1,
		maxIlvl = 6,
		rarityBonus = 0.0,
		pool = {
			{ key = "MA7Rifle", weight = 14 },
			{ key = "ViperPDW", weight = 14 },
			{ key = "M6DSidearm", weight = 14 },
			{ key = "TrenchSweeper", weight = 10 },
			{ key = "StandardCore", weight = 12 },
			{ key = "ReconVisor", weight = 10 },
			{ key = "ScavPlate", weight = 10 },
			{ key = "DrifterGreaves", weight = 10 },
			{ key = "MedInjector", weight = 18 },
			{ key = "ShieldCell", weight = 14 },
			{ key = "ScrapBundle", weight = 24 },
		},
	},
	Tier2_RailYard = {
		id = "Tier2_RailYard",
		minIlvl = 7,
		maxIlvl = 14,
		rarityBonus = 0.25,
		pool = {
			{ key = "BR55Burst", weight = 14 },
			{ key = "SolCoilCarbine", weight = 14 },
			{ key = "TrenchSweeper", weight = 12 },
			{ key = "MA7Rifle", weight = 10 },
			{ key = "BulwarkCore", weight = 12 },
			{ key = "SiphonCore", weight = 10 },
			{ key = "HazmatHood", weight = 10 },
			{ key = "ScavPlate", weight = 10 },
			{ key = "StalkerBoots", weight = 10 },
			{ key = "QuickSilverCoil", weight = 6 },
			{ key = "VaultKeycard", weight = 6 },
			{ key = "MedInjector", weight = 14 },
			{ key = "ShieldCell", weight = 14 },
			{ key = "ScrapBundle", weight = 20 },
		},
	},
	Tier3_BioMetro = {
		id = "Tier3_BioMetro",
		minIlvl = 15,
		maxIlvl = 22,
		rarityBonus = 0.55,
		pool = {
			{ key = "SolCoilCarbine", weight = 14 },
			{ key = "FerroRail", weight = 12 },
			{ key = "BR55Burst", weight = 12 },
			{ key = "ArcMortar", weight = 8 },
			{ key = "NovaCore", weight = 12 },
			{ key = "SiphonCore", weight = 12 },
			{ key = "VanguardRig", weight = 12 },
			{ key = "HazmatHood", weight = 10 },
			{ key = "SporePearl", weight = 10 },
			{ key = "SolarShard", weight = 8 },
			{ key = "RadFlush", weight = 14 },
			{ key = "VaultKeycard", weight = 8 },
			{ key = "ScrapBundle", weight = 18 },
		},
	},
	Tier4_Reactor = {
		id = "Tier4_Reactor",
		minIlvl = 23,
		maxIlvl = 30,
		rarityBonus = 1.0,
		pool = {
			{ key = "FerroRail", weight = 14 },
			{ key = "ArcMortar", weight = 12 },
			{ key = "SolCoilCarbine", weight = 14 },
			{ key = "BR55Burst", weight = 12 },
			{ key = "NovaCore", weight = 14 },
			{ key = "VanguardRig", weight = 14 },
			{ key = "SolarShard", weight = 12 },
			{ key = "FortuneCompass", weight = 10 },
			{ key = "ReactorCoreRelic", weight = 12 },
			{ key = "ShieldCell", weight = 12 },
		},
	},
	Vault_Locked = {
		id = "Vault_Locked",
		minIlvl = 12,
		maxIlvl = 28,
		rarityBonus = 1.45,
		pool = {
			{ key = "FerroRail", weight = 15 },
			{ key = "SolCoilCarbine", weight = 15 },
			{ key = "ArcMortar", weight = 12 },
			{ key = "VanguardRig", weight = 15 },
			{ key = "NovaCore", weight = 15 },
			{ key = "FortuneCompass", weight = 12 },
			{ key = "ReactorCoreRelic", weight = 16 },
		},
	},
	Boss_WardenGoliath = {
		id = "Boss_WardenGoliath",
		minIlvl = 25,
		maxIlvl = 30,
		rarityBonus = 2.6,
		pool = {
			{ key = "SolCoilCarbine", weight = 18 },
			{ key = "FerroRail", weight = 18 },
			{ key = "ArcMortar", weight = 16 },
			{ key = "NovaCore", weight = 18 },
			{ key = "VanguardRig", weight = 16 },
			{ key = "SolarShard", weight = 14 },
			{ key = "ReactorCoreRelic", weight = 22 },
		},
	},
}

local uidCounter = 0
local function nextUid(rng: Rng.RngStream): string
	uidCounter += 1
	return string.format("itm_%d_%06x", uidCounter, rng:nextU32() % 0xFFFFFF)
end

local function cloneStats(baseStats: { [string]: number }, ilvl: number, powerMult: number): { [string]: number }
	local out: { [string]: number } = {}
	local ilvlScale = 1 + math.max(0, ilvl - 1) * 0.035
	for k, v in pairs(baseStats) do
		-- Scale flat pool numbers (maxShield, maxHealth, armorRating) with item level & rarity;
		-- leave percentage/delay stats uninflated so stun delays don't balloon.
		if k == "maxShield" or k == "maxHealth" or k == "armorRating" or k == "shieldBreakNova" then
			out[k] = math.floor(v * ilvlScale * powerMult + 0.5)
		elseif k == "shieldRegenRate" then
			out[k] = math.floor(v * (1 + (powerMult - 1) * 0.5) + 0.5)
		else
			out[k] = v
		end
	end
	return out
end

local function pickAffixes(
	rng: Rng.RngStream,
	pool: { AffixCatalog.AffixDef },
	category: AffixCatalog.ItemCategory,
	ilvl: number,
	count: number
): { RolledAffix }
	if count <= 0 then
		return {}
	end
	local eligible: { AffixCatalog.AffixDef } = {}
	for _, affix in ipairs(pool) do
		if ilvl >= affix.minIlvl and affix.allowedCategories[category] then
			table.insert(eligible, affix)
		end
	end
	local chosen: { RolledAffix } = {}
	local usedIds: { [string]: boolean } = {}
	for _ = 1, count do
		local candidates: { AffixCatalog.AffixDef } = {}
		for _, a in ipairs(eligible) do
			if not usedIds[a.id] then
				table.insert(candidates, a)
			end
		end
		if #candidates == 0 then
			break
		end
		local pick = candidates[rng:nextInt(1, #candidates)]
		usedIds[pick.id] = true
		-- Higher ilvl biases slightly toward upper half of affix roll range
		local rawVal = rng:nextRange(pick.minVal, pick.maxVal)
		local rounded = if math.abs(pick.maxVal) >= 2 then math.floor(rawVal + 0.5) else math.floor(rawVal * 100 + 0.5) / 100
		table.insert(chosen, {
			id = pick.id,
			name = pick.name,
			kind = pick.kind,
			statKey = pick.statKey,
			value = rounded,
			label = pick.formatLabel(rounded),
		})
	end
	return chosen
end

local LootRoller = {
	TreasureClasses = TREASURE_CLASSES,
}

function LootRoller.createSpecificItem(
	baseId: string,
	rarityId: AffixCatalog.RarityId?,
	ilvl: number?,
	stackCount: number?,
	seed: number?
): ItemInstance
	local rng = Rng.new(seed or (uidCounter * 7919 + 104729))
	local base = AffixCatalog.BaseItems[baseId]
	assert(base ~= nil, "Unknown base item '" .. tostring(baseId) .. "'")

	local level = math.max(1, ilvl or 1)
	local rarity: AffixCatalog.RarityId = rarityId or "Common"
	if base.category == "Consumable" or base.category == "Material" then
		rarity = "Common"
	elseif base.id == "VaultKeycard" then
		rarity = "Rare"
	elseif base.id == "ReactorCoreRelic" then
		rarity = "Epic"
	end

	local rDef = AffixCatalog.Rarities[rarity]
	local stats = cloneStats(base.baseStats, level, rDef.powerMult)
	local affixes: { RolledAffix } = {}
	local itemName = base.name
	local perkId: string? = nil
	local perkTitle: string? = nil
	local perkDescription: string? = nil

	if base.category ~= "Consumable" and base.category ~= "Material" and base.category ~= "Quest" then
		if rarity == "Legendary" then
			-- Match a Named Legendary for this baseId if one exists, otherwise pick best match
			local legMatch: AffixCatalog.LegendaryDef? = nil
			for _, leg in ipairs(AffixCatalog.Legendaries) do
				if leg.baseId == baseId then
					legMatch = leg
					break
				end
			end
			if legMatch then
				itemName = legMatch.name
				perkId = legMatch.perkId
				perkTitle = legMatch.perkTitle
				perkDescription = legMatch.perkDescription
				for k, v in pairs(legMatch.fixedStats) do
					stats[k] = (stats[k] or 0) + v
				end
			end
		end

		local prefixes = pickAffixes(rng, AffixCatalog.Prefixes, base.category, level, rDef.prefixCount)
		local suffixes = pickAffixes(rng, AffixCatalog.Suffixes, base.category, level, rDef.suffixCount)
		for _, p in ipairs(prefixes) do
			table.insert(affixes, p)
			stats[p.statKey] = (stats[p.statKey] or 0) + p.value
		end
		for _, s in ipairs(suffixes) do
			table.insert(affixes, s)
			stats[s.statKey] = (stats[s.statKey] or 0) + s.value
		end

		if rarity ~= "Legendary" and #affixes > 0 then
			local firstPrefix = prefixes[1]
			local firstSuffix = suffixes[1]
			if firstPrefix and firstSuffix then
				itemName = firstPrefix.name .. " " .. base.name .. " " .. firstSuffix.name
			elseif firstPrefix then
				itemName = firstPrefix.name .. " " .. base.name
			elseif firstSuffix then
				itemName = base.name .. " " .. firstSuffix.name
			end
		end
	end

	local stack = math.clamp(stackCount or 1, 1, base.maxStack)
	local unitValue = math.max(1, math.floor(base.baseValue * rDef.valueMult * (1 + (level - 1) * 0.08) + #affixes * 12))

	return {
		uid = nextUid(rng),
		baseId = base.id,
		name = itemName,
		category = base.category,
		rarity = rarity,
		ilvl = level,
		gridW = base.gridW,
		gridH = base.gridH,
		rotated = false,
		stack = stack,
		maxStack = base.maxStack,
		durability = base.maxDurability,
		maxDurability = base.maxDurability,
		value = unitValue,
		rarityPowerMult = rDef.powerMult,
		affixes = affixes,
		stats = stats,
		perkId = perkId,
		perkTitle = perkTitle,
		perkDescription = perkDescription,
	}
end

function LootRoller.rollFromTreasureClass(
	tcId: string,
	rng: Rng.RngStream,
	playerRarityFind: number?
): ItemInstance
	local tc = TREASURE_CLASSES[tcId] or TREASURE_CLASSES.Tier1_Outskirts
	local ilvl = rng:nextInt(tc.minIlvl, tc.maxIlvl)
	local baseId: string = rng:weightedKey(tc.pool)
	local base = AffixCatalog.BaseItems[baseId]

	if base.category == "Material" then
		return LootRoller.createSpecificItem(baseId, "Common", ilvl, rng:nextInt(12, 38), rng:nextU32())
	elseif base.category == "Consumable" then
		return LootRoller.createSpecificItem(baseId, "Common", ilvl, rng:nextInt(1, 2), rng:nextU32())
	elseif base.category == "Quest" then
		return LootRoller.createSpecificItem(baseId, nil, ilvl, 1, rng:nextU32())
	end

	local mf = math.max(0, (playerRarityFind or 0) + tc.rarityBonus)
	local rarityWeights: { { key: AffixCatalog.RarityId, weight: number } } = {
		{ key = "Common", weight = math.max(8, AffixCatalog.Rarities.Common.baseWeight / (1 + mf * 0.8)) },
		{ key = "Uncommon", weight = AffixCatalog.Rarities.Uncommon.baseWeight * (1 + mf * 0.35) },
		{ key = "Rare", weight = AffixCatalog.Rarities.Rare.baseWeight * (1 + mf * 0.75) },
		{ key = "Epic", weight = AffixCatalog.Rarities.Epic.baseWeight * (1 + mf * 1.25) },
		{ key = "Legendary", weight = AffixCatalog.Rarities.Legendary.baseWeight * (1 + mf * 1.90) },
	}
	local rarity: AffixCatalog.RarityId = rng:weightedKey(rarityWeights)

	if rarity == "Legendary" then
		-- Prefer a base item that actually has a bespoke Legendary if one matches this ilvl
		local legPool: { AffixCatalog.LegendaryDef } = {}
		for _, leg in ipairs(AffixCatalog.Legendaries) do
			if ilvl >= leg.minIlvl then
				table.insert(legPool, leg)
			end
		end
		if #legPool > 0 then
			local pickedLeg = legPool[rng:nextInt(1, #legPool)]
			baseId = pickedLeg.baseId
		end
	end

	return LootRoller.createSpecificItem(baseId, rarity, ilvl, 1, rng:nextU32())
end

function LootRoller.rerollAffixes(item: ItemInstance, rng: Rng.RngStream): boolean
	if item.category == "Consumable" or item.category == "Material" or item.category == "Quest" then
		return false
	end
	local fresh = LootRoller.createSpecificItem(item.baseId, item.rarity, item.ilvl, 1, rng:nextU32())
	item.name = fresh.name
	item.affixes = fresh.affixes
	item.stats = fresh.stats
	item.perkId = fresh.perkId
	item.perkTitle = fresh.perkTitle
	item.perkDescription = fresh.perkDescription
	item.value = fresh.value
	return true
end

-- Aggregates all equipped Paperdoll gear into an authoritative RPG character sheet.
function LootRoller.aggregateLoadoutStats(paperdoll: { [string]: ItemInstance? }): { [string]: any }
	local totals: { [string]: any } = {
		maxShield = 0,
		shieldRegenRate = 0,
		shieldStunDelay = Config.vitality.baseShieldStunDelay,
		maxHealth = Config.vitality.baseMaxHealth,
		armorRating = Config.vitality.baseArmorRating,
		hazardResist = Config.vitality.baseHazardResist,
		moveSpeedPct = 0,
		reloadSpeedPct = 0,
		damagePct = 0,
		fireRatePct = 0,
		stabilityPct = 0,
		critDamageBonus = 0,
		lifeOnKill = 0,
		shieldOnKill = 0,
		shieldBreakNova = 0,
		rarityFind = 0,
		perks = {} :: { [string]: boolean },
	}

	local hasShieldCore = false
	-- Passive armor/shield/relic slots contribute globally; weapon stats apply to the active gun.
	local passiveSlots = { "ShieldCore", "Head", "Chest", "Legs", "Relic1", "Relic2" }
	for _, slotName in ipairs(passiveSlots) do
		local item = paperdoll[slotName]
		if item then
			if slotName == "ShieldCore" then
				hasShieldCore = true
				totals.shieldStunDelay = item.stats.shieldStunDelay or Config.vitality.baseShieldStunDelay
			end
			local durMult = if item.maxDurability > 0 and item.durability <= 0
				then Config.economy.brokenEffectivenessMultiplier
				else 1.0

			for k, v in pairs(item.stats) do
				if k == "shieldStunDelay" then
					-- handled as base on ShieldCore
				elseif k == "shieldStunDelta" then
					totals.shieldStunDelay += v
				elseif k == "maxShield" or k == "maxHealth" or k == "armorRating" or k == "shieldRegenRate" then
					totals[k] = (totals[k] or 0) + math.floor(v * durMult + 0.5)
				elseif totals[k] ~= nil and type(totals[k]) == "number" then
					totals[k] += v
				end
			end
			if item.perkId then
				totals.perks[item.perkId] = true
			end
		end
	end

	if not hasShieldCore then
		-- Fallback emergency personal shield if player unequipped their core
		totals.maxShield += 45
		totals.shieldRegenRate += 16
	end

	totals.maxShield = math.max(25, totals.maxShield)
	totals.shieldRegenRate = math.max(8, totals.shieldRegenRate)
	totals.shieldStunDelay = math.clamp(totals.shieldStunDelay, 1.1, 6.0)
	totals.maxHealth = math.max(50, totals.maxHealth)
	totals.armorRating = math.max(0, totals.armorRating)
	totals.hazardResist = math.clamp(totals.hazardResist, 0, 0.85)
	totals.moveSpeedPct = math.clamp(totals.moveSpeedPct, -0.20, 0.40)

	return totals
end

-- BotW `uiPauseMenuDataMgr`-inspired instant comparison between a hovered item and equipped slot.
function LootRoller.compareItemToPaperdoll(
	candidate: ItemInstance,
	paperdoll: { [string]: ItemInstance? }
): { { label: string, currentVal: number, newVal: number, delta: number, higherIsBetter: boolean } }
	local diffs = {}
	if candidate.category == "Weapon" then
		local equipped = paperdoll.Primary1 or paperdoll.Primary2
		local candStats = WeaponCatalog.computeStats(candidate, nil)
		local curStats = if equipped then WeaponCatalog.computeStats(equipped, nil) else nil
		local curDps = if curStats then curStats.dps else 0
		local curDmg = if curStats then curStats.damage * curStats.pellets else 0
		table.insert(diffs, {
			label = "DPS",
			currentVal = curDps,
			newVal = candStats.dps,
			delta = candStats.dps - curDps,
			higherIsBetter = true,
		})
		table.insert(diffs, {
			label = "Shot Damage",
			currentVal = curDmg,
			newVal = candStats.damage * candStats.pellets,
			delta = (candStats.damage * candStats.pellets) - curDmg,
			higherIsBetter = true,
		})
		return diffs
	end

	local slotMap: { [string]: string } = {
		ShieldCore = "ShieldCore",
		Head = "Head",
		Chest = "Chest",
		Legs = "Legs",
		Relic = "Relic1",
	}
	local targetSlot = slotMap[candidate.category]
	if not targetSlot then
		return diffs
	end
	local equipped = paperdoll[targetSlot]
	local keysToCompare = {
		{ key = "maxShield", label = "Max Shield", higher = true },
		{ key = "shieldRegenRate", label = "Shield Regen/s", higher = true },
		{ key = "shieldStunDelay", label = "Recharge Delay (s)", higher = false },
		{ key = "maxHealth", label = "Max Health", higher = true },
		{ key = "armorRating", label = "Armor", higher = true },
		{ key = "hazardResist", label = "Hazard Resist", higher = true },
	}
	for _, entry in ipairs(keysToCompare) do
		local newV = candidate.stats[entry.key] or 0
		local curV = if equipped then (equipped.stats[entry.key] or 0) else 0
		if newV ~= 0 or curV ~= 0 then
			table.insert(diffs, {
				label = entry.label,
				currentVal = curV,
				newVal = newV,
				delta = math.floor((newV - curV) * 100 + 0.5) / 100,
				higherIsBetter = entry.higher,
			})
		end
	end
	return diffs
end

return LootRoller
