--!strict
-- Halo-inspired 8-archetype weapon sandbox + 2 ordnance types.
-- Includes both traditional magazine-fed kinetic weapons and Halo's signature Plasma Heat/Vent
-- energy rifle (`SolCoilCarbine`), plus effective stat scaling with Diablo affixes & durability.

local Config = require(script.Parent.Parent.Config)

export type FireMode = "Auto" | "Burst3" | "Semi" | "Scatter" | "Launcher"

export type WeaponDef = {
	id: string,
	name: string,
	archetype: string,
	description: string,
	damageType: "Kinetic" | "Plasma" | "Corrosive" | "Explosive",
	fireMode: FireMode,
	baseDamage: number,
	pellets: number,
	rpm: number,
	critMultiplier: number,
	rangeStuds: number,
	spreadDeg: number,
	adsSpreadMultiplier: number,
	adsFov: number,
	-- Magazine OR Heat system
	usesHeat: boolean,
	magSize: number,
	reloadSeconds: number,
	heatPerShot: number,
	passiveCoolRate: number,
	manualVentRate: number,
	overheatLockoutSeconds: number,
	splashRadius: number,
	-- 2D Grid footprint & graybox asset key
	gridW: number,
	gridH: number,
	assetId: string,
}

local WEAPONS: { [string]: WeaponDef } = {
	MA7Rifle = {
		id = "MA7Rifle",
		name = "MA-7 Wasteland Rifle",
		archetype = "Assault Rifle",
		description = "Reliable gas-operated kinetic workhorse built for mid-range wasteland firefights.",
		damageType = "Kinetic",
		fireMode = "Auto",
		baseDamage = 19,
		pellets = 1,
		rpm = 600,
		critMultiplier = 1.65,
		rangeStuds = 220,
		spreadDeg = 1.8,
		adsSpreadMultiplier = 0.45,
		adsFov = 58,
		usesHeat = false,
		magSize = 32,
		reloadSeconds = 1.9,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 3,
		gridH = 2,
		assetId = "Weapon.MA7Rifle",
	},
	BR55Burst = {
		id = "BR55Burst",
		name = "BR-55 Recon Burst",
		archetype = "Battle Rifle",
		description = "Crisp 3-round kinetic burst rifle; lethal headshot finisher once enemy shields pop.",
		damageType = "Kinetic",
		fireMode = "Burst3",
		baseDamage = 21,
		pellets = 1,
		rpm = 540,
		critMultiplier = 2.0,
		rangeStuds = 280,
		spreadDeg = 0.85,
		adsSpreadMultiplier = 0.25,
		adsFov = 48,
		usesHeat = false,
		magSize = 36,
		reloadSeconds = 2.0,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 3,
		gridH = 2,
		assetId = "Weapon.BR55Burst",
	},
	SolCoilCarbine = {
		id = "SolCoilCarbine",
		name = "Sol-Coil Plasma Carbine",
		archetype = "Plasma Rifle",
		description = "Battery-fed plasma repeater that shreds energy shields. Press R to vent heat before overheating.",
		damageType = "Plasma",
		fireMode = "Auto",
		baseDamage = 22,
		pellets = 1,
		rpm = 520,
		critMultiplier = 1.35,
		rangeStuds = 190,
		spreadDeg = 1.5,
		adsSpreadMultiplier = 0.50,
		adsFov = 56,
		usesHeat = true,
		magSize = 0,
		reloadSeconds = 0,
		heatPerShot = 8.5,
		passiveCoolRate = 22,
		manualVentRate = 56,
		overheatLockoutSeconds = 2.1,
		splashRadius = 0,
		gridW = 2,
		gridH = 2,
		assetId = "Weapon.SolCoilCarbine",
	},
	TrenchSweeper = {
		id = "TrenchSweeper",
		name = "Trench Sweeper",
		archetype = "Scattergun",
		description = "Heavy 8-pellet pump scattergun built to stop rushing Feral Stalkers cold.",
		damageType = "Kinetic",
		fireMode = "Scatter",
		baseDamage = 12,
		pellets = 8,
		rpm = 95,
		critMultiplier = 1.55,
		rangeStuds = 85,
		spreadDeg = 5.4,
		adsSpreadMultiplier = 0.70,
		adsFov = 62,
		usesHeat = false,
		magSize = 8,
		reloadSeconds = 2.3,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 3,
		gridH = 2,
		assetId = "Weapon.TrenchSweeper",
	},
	ViperPDW = {
		id = "ViperPDW",
		name = "Viper 9mm PDW",
		archetype = "Submachine Gun",
		description = "Featherweight close-quarters SMG with blazing rate of fire and snappy handling.",
		damageType = "Kinetic",
		fireMode = "Auto",
		baseDamage = 14,
		pellets = 1,
		rpm = 840,
		critMultiplier = 1.55,
		rangeStuds = 145,
		spreadDeg = 2.6,
		adsSpreadMultiplier = 0.55,
		adsFov = 62,
		usesHeat = false,
		magSize = 42,
		reloadSeconds = 1.55,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 2,
		gridH = 2,
		assetId = "Weapon.ViperPDW",
	},
	FerroRail = {
		id = "FerroRail",
		name = "Ferro-Rail Marksman",
		archetype = "Rail Sniper",
		description = "Electromagnetic long-rifle firing hyper-velocity slugs with devastating weakpoint crits.",
		damageType = "Kinetic",
		fireMode = "Semi",
		baseDamage = 92,
		pellets = 1,
		rpm = 72,
		critMultiplier = 2.45,
		rangeStuds = 420,
		spreadDeg = 0.25,
		adsSpreadMultiplier = 0.05,
		adsFov = 34,
		usesHeat = false,
		magSize = 5,
		reloadSeconds = 2.4,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 4,
		gridH = 2,
		assetId = "Weapon.FerroRail",
	},
	M6DSidearm = {
		id = "M6DSidearm",
		name = "M6D Bastion Sidearm",
		archetype = "Precision Pistol",
		description = "Oversized tactical magnum with smart-link optics. Fast swap and punishing headshots.",
		damageType = "Kinetic",
		fireMode = "Semi",
		baseDamage = 35,
		pellets = 1,
		rpm = 240,
		critMultiplier = 2.10,
		rangeStuds = 210,
		spreadDeg = 0.9,
		adsSpreadMultiplier = 0.25,
		adsFov = 52,
		usesHeat = false,
		magSize = 12,
		reloadSeconds = 1.35,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 0,
		gridW = 2,
		gridH = 1,
		assetId = "Weapon.M6DSidearm",
	},
	ArcMortar = {
		id = "ArcMortar",
		name = "Arc-7 Siege Mortar",
		archetype = "Heavy Launcher",
		description = "Heavy ordnance launcher lobbing unstable plasma shells that strip clustered enemy shields.",
		damageType = "Explosive",
		fireMode = "Launcher",
		baseDamage = 88,
		pellets = 1,
		rpm = 65,
		critMultiplier = 1.0,
		rangeStuds = 260,
		spreadDeg = 1.2,
		adsSpreadMultiplier = 0.6,
		adsFov = 58,
		usesHeat = false,
		magSize = 4,
		reloadSeconds = 2.8,
		heatPerShot = 0,
		passiveCoolRate = 0,
		manualVentRate = 0,
		overheatLockoutSeconds = 0,
		splashRadius = 15,
		gridW = 4,
		gridH = 2,
		assetId = "Weapon.ArcMortar",
	},
}

local ORDNANCE = {
	EmpGrenade = {
		id = "EmpGrenade",
		name = "Pulse-EMP Grenade",
		damageType = "Plasma" :: "Plasma",
		baseDamage = 95,
		radius = 18,
		cooldown = 10,
	},
	FragGrenade = {
		id = "FragGrenade",
		name = "Shrapnel Frag Grenade",
		damageType = "Explosive" :: "Explosive",
		baseDamage = 115,
		radius = 16,
		cooldown = 9,
	},
}

local ORDERED_IDS = {
	"MA7Rifle",
	"BR55Burst",
	"SolCoilCarbine",
	"TrenchSweeper",
	"ViperPDW",
	"FerroRail",
	"M6DSidearm",
	"ArcMortar",
}

local WeaponCatalog = {
	Weapons = WEAPONS,
	Ordnance = ORDNANCE,
	OrderedIds = ORDERED_IDS,
}

function WeaponCatalog.get(weaponId: string): WeaponDef?
	return WEAPONS[weaponId]
end

-- Computes final combat numbers for an equipped weapon item instance (including item level scaling,
-- rolled Diablo affixes, rarity multiplier, and 0-durability penalty).
function WeaponCatalog.computeStats(item: { [string]: any }, bonusStats: { [string]: number }?): { [string]: any }
	local def = WEAPONS[item.baseId]
	if not def then
		def = WEAPONS.MA7Rifle
	end

	local stats = item.stats or {}
	local extra = bonusStats or {}
	local ilvlScale = 1 + math.max(0, (item.ilvl or 1) - 1) * 0.045
	local rarityMult = item.rarityPowerMult or 1.0

	local durMult = 1.0
	if type(item.durability) == "number" and item.durability <= 0 then
		durMult = Config.economy.brokenEffectivenessMultiplier
	end

	local dmgPct = (stats.damagePct or 0) + (extra.damagePct or 0)
	local plasmaPct = if def.damageType == "Plasma" then (stats.plasmaDamagePct or 0) else 0
	local fireRatePct = (stats.fireRatePct or 0) + (extra.fireRatePct or 0)
	local reloadPct = (stats.reloadSpeedPct or 0) + (extra.reloadSpeedPct or 0)
	local stabilityPct = (stats.stabilityPct or 0) + (extra.stabilityPct or 0)
	local critBonus = (stats.critDamageBonus or 0) + (extra.critDamageBonus or 0)
	local coolingPct = (stats.coolingPct or 0)

	local finalDamage = def.baseDamage * ilvlScale * rarityMult * (1 + dmgPct + plasmaPct) * durMult
	local finalRpm = def.rpm * (1 + math.clamp(fireRatePct, -0.4, 0.8))
	local shotInterval = 60 / math.max(30, finalRpm)
	local finalSpread = math.max(0.08, def.spreadDeg * (1 - math.clamp(stabilityPct, 0, 0.75)))
	local finalReload = if def.reloadSeconds > 0
		then math.max(0.55, def.reloadSeconds / (1 + math.max(0, reloadPct)))
		else 0
	local effectiveDamageType = if (stats.corrosiveRounds or 0) > 0 then "Corrosive" else def.damageType

	local dps = (finalDamage * def.pellets) / shotInterval

	return {
		def = def,
		damage = math.floor(finalDamage * 10 + 0.5) / 10,
		pellets = def.pellets,
		rpm = math.floor(finalRpm + 0.5),
		shotInterval = shotInterval,
		dps = math.floor(dps + 0.5),
		spreadDeg = finalSpread,
		critMultiplier = def.critMultiplier + critBonus,
		magSize = def.magSize + math.floor(stats.magBonus or 0),
		reloadSeconds = finalReload,
		usesHeat = def.usesHeat,
		heatPerShot = math.max(3, def.heatPerShot * (1 - math.clamp(coolingPct * 0.5, 0, 0.45))),
		passiveCoolRate = def.passiveCoolRate * (1 + coolingPct),
		manualVentRate = def.manualVentRate * (1 + coolingPct + math.max(0, reloadPct * 0.5)),
		overheatLockoutSeconds = def.overheatLockoutSeconds,
		damageType = effectiveDamageType,
		rangeStuds = def.rangeStuds,
		splashRadius = def.splashRadius,
		isBroken = (durMult < 1.0),
	}
end

return WeaponCatalog
