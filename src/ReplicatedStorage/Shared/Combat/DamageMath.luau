--!strict
-- Clean-room Luau implementation of Halo: Combat Evolved's two-layer Shield + Body Health
-- vitality & damage resistance math (studied from `halo-re/halo` & `bnunu/halo-ce-universal`
-- `source/objects/damage.c` and `damage.h`).

local Config = require(script.Parent.Parent.Config)

export type DamageType = "Kinetic" | "Plasma" | "Corrosive" | "Explosive" | "Hazard"

export type VitalityState = {
	shield: number,
	maxShield: number,
	shieldRegenRate: number,
	shieldStunDelay: number,
	shieldStunRemaining: number,
	health: number,
	maxHealth: number,
	armorRating: number,
	hazardResist: number, -- 0..0.85 fraction
	corrosiveTimer: number,
	downed: boolean,
	bleedoutRemaining: number,
	dead: boolean,
}

export type DamagePacket = {
	amount: number,
	damageType: DamageType,
	isHeadshot: boolean?,
	critMultiplier: number?,
	bypassShield: boolean?,
	sourceId: string?,
}

export type DamageResult = {
	shieldDamage: number,
	healthDamage: number,
	totalDamage: number,
	shieldPopped: boolean,
	isCrit: boolean,
	downedTriggered: boolean,
	killed: boolean,
}

local TYPE_MULTIPLIERS: { [DamageType]: { shield: number, flesh: number } } = {
	Kinetic = { shield = 0.80, flesh = 1.25 },
	Plasma = { shield = 1.65, flesh = 0.85 },
	Corrosive = { shield = 1.00, flesh = 1.10 },
	Explosive = { shield = 1.20, flesh = 1.20 },
	Hazard = { shield = 0.50, flesh = 1.00 },
}

local DamageMath = {}

function DamageMath.newVitality(overrides: { [string]: any }?): VitalityState
	local o = overrides or {}
	local maxShield = if type(o.maxShield) == "number" then math.max(0, o.maxShield) else Config.vitality.baseMaxShield
	local maxHealth = if type(o.maxHealth) == "number" then math.max(1, o.maxHealth) else Config.vitality.baseMaxHealth
	return {
		shield = if type(o.shield) == "number" then math.clamp(o.shield, 0, maxShield) else maxShield,
		maxShield = maxShield,
		shieldRegenRate = if type(o.shieldRegenRate) == "number"
			then math.max(0, o.shieldRegenRate)
			else Config.vitality.baseShieldRegenRate,
		shieldStunDelay = if type(o.shieldStunDelay) == "number"
			then math.max(0.4, o.shieldStunDelay)
			else Config.vitality.baseShieldStunDelay,
		shieldStunRemaining = 0,
		health = if type(o.health) == "number" then math.clamp(o.health, 0, maxHealth) else maxHealth,
		maxHealth = maxHealth,
		armorRating = if type(o.armorRating) == "number" then math.max(0, o.armorRating) else Config.vitality.baseArmorRating,
		hazardResist = if type(o.hazardResist) == "number"
			then math.clamp(o.hazardResist, 0, 0.85)
			else Config.vitality.baseHazardResist,
		corrosiveTimer = 0,
		downed = false,
		bleedoutRemaining = Config.vitality.downedBleedoutSeconds,
		dead = false,
	}
end

function DamageMath.syncMaxStats(vitality: VitalityState, stats: { [string]: number })
	local prevMaxShield = vitality.maxShield
	local prevMaxHealth = vitality.maxHealth
	vitality.maxShield = math.max(0, stats.maxShield or prevMaxShield)
	vitality.shieldRegenRate = math.max(1, stats.shieldRegenRate or vitality.shieldRegenRate)
	vitality.shieldStunDelay = math.max(0.5, stats.shieldStunDelay or vitality.shieldStunDelay)
	vitality.maxHealth = math.max(10, stats.maxHealth or prevMaxHealth)
	vitality.armorRating = math.max(0, stats.armorRating or vitality.armorRating)
	vitality.hazardResist = math.clamp(stats.hazardResist or vitality.hazardResist, 0, 0.85)

	vitality.shield = math.clamp(vitality.shield, 0, vitality.maxShield)
	vitality.health = math.clamp(vitality.health, 0, vitality.maxHealth)
end

function DamageMath.applyDamage(
	vitality: VitalityState,
	packet: DamagePacket,
	canEnterDowned: boolean?
): DamageResult
	if vitality.dead then
		return {
			shieldDamage = 0,
			healthDamage = 0,
			totalDamage = 0,
			shieldPopped = false,
			isCrit = false,
			downedTriggered = false,
			killed = false,
		}
	end

	local raw = math.max(0, packet.amount)
	if packet.damageType == "Hazard" then
		raw = raw * (1 - vitality.hazardResist)
	end

	if raw <= 0 then
		return {
			shieldDamage = 0,
			healthDamage = 0,
			totalDamage = 0,
			shieldPopped = false,
			isCrit = false,
			downedTriggered = false,
			killed = false,
		}
	end

	-- Any hit resets Halo's shield recharge stun timer.
	vitality.shieldStunRemaining = vitality.shieldStunDelay
	if packet.damageType == "Corrosive" then
		vitality.corrosiveTimer = math.max(vitality.corrosiveTimer, 5.0)
	end

	local mults = TYPE_MULTIPLIERS[packet.damageType] or TYPE_MULTIPLIERS.Kinetic
	local shieldDamage = 0
	local shieldPopped = false
	local remainingRaw = raw

	-- Layer 1: Energy Shield absorbs damage first unless bypassed.
	if not packet.bypassShield and vitality.shield > 0 then
		local effectiveVsShield = remainingRaw * mults.shield
		if effectiveVsShield >= vitality.shield then
			shieldDamage = vitality.shield
			local fractionUsed = vitality.shield / effectiveVsShield
			remainingRaw = math.max(0, remainingRaw * (1 - fractionUsed))
			vitality.shield = 0
			shieldPopped = true
		else
			shieldDamage = effectiveVsShield
			vitality.shield -= effectiveVsShield
			remainingRaw = 0
		end
	end

	-- Layer 2: Unshielded Body Health (with Armor mitigation + Headshot crit gating).
	local healthDamage = 0
	local isCrit = false
	if remainingRaw > 0 then
		local fleshDamage = remainingRaw * mults.flesh
		-- Halo rule: headshots only score precision crits once shields are down!
		if packet.isHeadshot and vitality.shield <= 0 and packet.damageType ~= "Explosive" and packet.damageType ~= "Hazard" then
			local critMult = math.max(1.0, packet.critMultiplier or 1.75)
			fleshDamage *= critMult
			isCrit = true
		end

		local effectiveArmor = vitality.armorRating
		if vitality.corrosiveTimer > 0 then
			effectiveArmor *= 0.80 -- Corrosive shreds 20% armor
		end
		-- Diablo/ARPG diminishing-returns armor formula: reduction = armor / (armor + 100)
		local mitigation = effectiveArmor / (effectiveArmor + 100)
		healthDamage = fleshDamage * (1 - mitigation)

		if vitality.downed then
			vitality.bleedoutRemaining = math.max(0, vitality.bleedoutRemaining - (healthDamage * 0.15))
		else
			vitality.health = math.max(0, vitality.health - healthDamage)
		end
	end

	local downedTriggered = false
	local killed = false

	if not vitality.downed and vitality.health <= 0 then
		if canEnterDowned then
			vitality.downed = true
			vitality.bleedoutRemaining = Config.vitality.downedBleedoutSeconds
			downedTriggered = true
		else
			vitality.dead = true
			killed = true
		end
	elseif vitality.downed and vitality.bleedoutRemaining <= 0 then
		vitality.dead = true
		killed = true
	end

	return {
		shieldDamage = shieldDamage,
		healthDamage = healthDamage,
		totalDamage = shieldDamage + healthDamage,
		shieldPopped = shieldPopped,
		isCrit = isCrit,
		downedTriggered = downedTriggered,
		killed = killed,
	}
end

function DamageMath.tick(vitality: VitalityState, dt: number): { shieldRecharging: boolean, bledOut: boolean }
	if vitality.dead or dt <= 0 then
		return { shieldRecharging = false, bledOut = false }
	end

	if vitality.corrosiveTimer > 0 then
		vitality.corrosiveTimer = math.max(0, vitality.corrosiveTimer - dt)
	end

	if vitality.downed then
		vitality.bleedoutRemaining = math.max(0, vitality.bleedoutRemaining - dt)
		if vitality.bleedoutRemaining <= 0 then
			vitality.dead = true
			return { shieldRecharging = false, bledOut = true }
		end
		return { shieldRecharging = false, bledOut = false }
	end

	if vitality.shieldStunRemaining > 0 then
		vitality.shieldStunRemaining = math.max(0, vitality.shieldStunRemaining - dt)
		return { shieldRecharging = false, bledOut = false }
	end

	if vitality.shield < vitality.maxShield then
		vitality.shield = math.min(vitality.maxShield, vitality.shield + vitality.shieldRegenRate * dt)
		return { shieldRecharging = true, bledOut = false }
	end

	return { shieldRecharging = false, bledOut = false }
end

function DamageMath.revive(vitality: VitalityState)
	vitality.downed = false
	vitality.dead = false
	vitality.health = math.max(vitality.health, math.floor(vitality.maxHealth * 0.40))
	vitality.shield = math.max(vitality.shield, math.floor(vitality.maxShield * 0.50))
	vitality.shieldStunRemaining = 0
	vitality.bleedoutRemaining = Config.vitality.downedBleedoutSeconds
end

function DamageMath.fullRestore(vitality: VitalityState)
	vitality.downed = false
	vitality.dead = false
	vitality.health = vitality.maxHealth
	vitality.shield = vitality.maxShield
	vitality.shieldStunRemaining = 0
	vitality.corrosiveTimer = 0
	vitality.bleedoutRemaining = Config.vitality.downedBleedoutSeconds
end

return DamageMath
