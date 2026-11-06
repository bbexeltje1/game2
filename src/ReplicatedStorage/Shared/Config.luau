--!strict
-- Shared tuning and authoritative constants read by both server and client.
return {
	displayName = "ASHFALL: Bastion Protocol",
	buildLabel = "1.0.0",
	-- Publish this attribute and the client knows the server finished starting up.
	readyAttribute = "ServerReady",

	-- 2D Spatial Grid dimensions (DevilutionX / Tarkov inspired)
	grid = {
		backpackWidth = 10,
		backpackHeight = 5,
		stashWidth = 10,
		stashHeight = 12,
		secureWidth = 2,
		secureHeight = 2,
		crateWidth = 6,
		crateHeight = 4,
		beltSlots = 4,
	},

	-- Base player vitality (Halo: CE two-layer Shield + Body Health model)
	vitality = {
		baseMaxShield = 100,
		baseShieldRegenRate = 28, -- shield/sec once stun expires
		baseShieldStunDelay = 3.5, -- seconds after taking hit before shield recharges
		baseMaxHealth = 100,
		baseArmorRating = 10,
		baseHazardResist = 0,
		downedBleedoutSeconds = 15,
		reviveHoldSeconds = 2.5,
	},

	-- Movement tuning (3rd-person tactical controller)
	movement = {
		walkSpeed = 16,
		sprintSpeed = 24,
		adsSpeed = 11,
		slideImpulse = 46,
		slideDuration = 0.55,
		slideCooldown = 1.4,
		dodgeImpulse = 52,
		dodgeDuration = 0.28,
		dodgeCooldown = 1.8,
		mantleMaxHeight = 7.5,
	},

	-- Extraction & Death Durability Tax economy
	economy = {
		startingScrap = 180,
		startingCredits = 250,
		deathDurabilityTaxFraction = 0.20, -- -20% of maxDurability on equipped items on wipe
		brokenEffectivenessMultiplier = 0.50, -- 0-durability items deal/block 50%, never deleted
		scrapPerDurabilityPoint = 1.2,
		rerollBaseScrap = 45,
	},

	-- Radar & HUD tuning
	hud = {
		motionTrackerRangeStuds = 85,
		interactRangeStuds = 12,
	},
}
