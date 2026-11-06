--!strict
-- Raider Specialization Tech Tree (`Bastion Tech Points`).
-- Players earn 1 Tech Point per Raider Level (starting with 1 point at Level 1) and can invest
-- up to 5 ranks per node or reset anytime at Bastion Bunker.

export type SkillNodeDef = {
	id: string,
	name: string,
	category: string,
	maxRank: number,
	description: string,
	perRankStats: { [string]: number },
}

local NODES: { SkillNodeDef } = {
	{
		id = "AegisCapacitor",
		name = "Aegis Shield Capacitor",
		category = "DEFENSE",
		maxRank = 5,
		description = "+14 Max Energy Shield & -0.12s Shield Stun Delay per rank",
		perRankStats = {
			maxShield = 14,
			shieldStunReduction = 0.12,
		},
	},
	{
		id = "BallisticPrecision",
		name = "Precision Targeting Core",
		category = "OFFENSE",
		maxRank = 5,
		description = "+5% All Weapon Damage & +8% Precision Crit Bonus per rank",
		perRankStats = {
			damagePct = 0.05,
			critPct = 0.08,
		},
	},
	{
		id = "CryoHeatsinks",
		name = "Cryo-Vent Heatsinks",
		category = "WEAPONS",
		maxRank = 5,
		description = "+8% Reload & Sol-Coil Plasma Vent Speed per rank",
		perRankStats = {
			reloadSpeedPct = 0.08,
		},
	},
	{
		id = "ExoThrusters",
		name = "Exo-Thruster Actuators",
		category = "MOBILITY",
		maxRank = 5,
		description = "+3% Sprint/Walk Speed & +10% Melee Lunge Power per rank",
		perRankStats = {
			moveSpeedPct = 0.03,
			meleeDamagePct = 0.10,
		},
	},
	{
		id = "LeadBioweave",
		name = "Lead-Lined Bioweave",
		category = "SURVIVAL",
		maxRank = 5,
		description = "+12 Max Body Health & +9% Rad/Spore Hazard Resist per rank",
		perRankStats = {
			maxHealth = 12,
			hazardResist = 0.09,
		},
	},
	{
		id = "ProspectorScanner",
		name = "Prospector's Loot Scanner",
		category = "SCAVENGING",
		maxRank = 5,
		description = "+10% Diablo Rarity Find & +4 Armor Rating per rank",
		perRankStats = {
			rarityFind = 0.10,
			armorRating = 4,
		},
	},
}

local BY_ID: { [string]: SkillNodeDef } = {}
for _, node in ipairs(NODES) do
	BY_ID[node.id] = node
end

local SkillTreeCatalog = {
	Nodes = NODES,
	ById = BY_ID,
}

function SkillTreeCatalog.getSpentPoints(skills: { [string]: number }?): number
	if not skills then
		return 0
	end
	local spent = 0
	for id, rank in pairs(skills) do
		if BY_ID[id] and type(rank) == "number" and rank > 0 then
			spent += math.floor(rank)
		end
	end
	return spent
end

function SkillTreeCatalog.getAvailablePoints(level: number, skills: { [string]: number }?): number
	local totalEarned = math.max(1, math.floor(level))
	return math.max(0, totalEarned - SkillTreeCatalog.getSpentPoints(skills))
end

function SkillTreeCatalog.applySkillBonuses(baseStats: { [string]: any }, skills: { [string]: number }?)
	if not skills then
		return
	end
	for _, node in ipairs(NODES) do
		local rank = math.clamp(math.floor(tonumber(skills[node.id]) or 0), 0, node.maxRank)
		if rank > 0 then
			for statKey, perRankVal in pairs(node.perRankStats) do
				if statKey == "shieldStunReduction" then
					baseStats.shieldStunDelay = math.max(1.2, (baseStats.shieldStunDelay or 3.5) - perRankVal * rank)
				elseif statKey == "damagePct" then
					baseStats.kineticPct = (baseStats.kineticPct or 0) + perRankVal * rank
					baseStats.plasmaPct = (baseStats.plasmaPct or 0) + perRankVal * rank
				else
					baseStats[statKey] = (baseStats[statKey] or 0) + perRankVal * rank
				end
			end
			if node.perRankStats.hazardResist then
				baseStats.hazardResist = math.clamp(baseStats.hazardResist or 0, 0, 0.85)
			end
		end
	end
end

return SkillTreeCatalog
