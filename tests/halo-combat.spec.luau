-- Unit specs for Halo: CE Energy Shield + Body Health vitality & damage multipliers (`damage.c`).
local vit = DamageMath.newVitality({
	maxShield = 100,
	shieldRegenRate = 25,
	shieldStunDelay = 3.0,
	maxHealth = 100,
	armorRating = 0,
	hazardResist = 0.50,
})

-- 1. Kinetic vs Plasma against active Energy Shield:
-- 50 Kinetic -> 50 * 0.80 = 40 shield damage (Headshot MUST NOT crit while shielded!)
local r1 = DamageMath.applyDamage(vit, {
	amount = 50,
	damageType = "Kinetic",
	isHeadshot = true,
	critMultiplier = 2.5,
}, false)
assert(math.abs(r1.shieldDamage - 40) < 0.01 and r1.healthDamage == 0, "Kinetic deals 0.80x to shields")
assert(r1.isCrit == false, "Headshots do not crit through active Halo shields")
assert(vit.shield == 60 and vit.shieldStunRemaining == 3.0, "Shield stun delay resets on hit")

-- 2. Shield does not recharge while stunned, then recharges once stun expires:
DamageMath.tick(vit, 2.0)
assert(vit.shield == 60, "Shield waits for stun timer before recharging")
DamageMath.tick(vit, 1.0) -- stun hits 0
DamageMath.tick(vit, 1.0) -- +25 shield
assert(vit.shield == 85, "Shield recharges smoothly after stun delay expires")

-- 3. Plasma shreds shields at 1.65x and triggers shieldPopped + bleedthrough!
local r2 = DamageMath.applyDamage(vit, {
	amount = 60, -- 60 * 1.65 = 99 > 85 shield -> pops shield with remaining raw!
	damageType = "Plasma",
	isHeadshot = false,
}, false)
assert(r2.shieldPopped == true and vit.shield == 0, "Plasma overloads and pops shield")
assert(r2.healthDamage > 0, "Excess damage bleeds through onto unshielded health")

-- 4. Unshielded Kinetic Headshot scores full precision crit!
local hpBefore = vit.health
local r3 = DamageMath.applyDamage(vit, {
	amount = 20,
	damageType = "Kinetic", -- 20 * 1.25 * 2.0 = 50
	isHeadshot = true,
	critMultiplier = 2.0,
}, false)
assert(r3.isCrit == true and math.abs((hpBefore - vit.health) - 50) < 0.01, "Unshielded headshot scores full precision crit")

-- 5. Co-op Downed state + Revive
local r4 = DamageMath.applyDamage(vit, { amount = 500, damageType = "Kinetic" }, true)
assert(r4.downedTriggered == true and vit.downed == true and vit.dead == false, "Lethal hit enters Co-op Downed state when squadmate alive")
DamageMath.revive(vit)
assert(vit.downed == false and vit.health >= 40 and vit.shield >= 50, "Revive restores ally to fighting shape")

print("PASS Halo Combat: shield stun/regen, Kinetic vs Plasma matrix, crit gating & revive verified")
