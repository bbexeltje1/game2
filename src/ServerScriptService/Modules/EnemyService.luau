--!strict
-- Nintendo `Nerve`-driven Enemy AI Service (6 Wasteland Archetypes + Warden Goliath 3-Phase Boss +
-- Bunker Firing Range Target Dummies).
--
-- States per Enemy NerveKeeper:
--   "Patrol" -> "Engage" -> "SniperTelegraph" -> "ShieldBreakEvade" -> "BossOverdrive" -> "Dead"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Nerve = require(ReplicatedStorage.Shared.Core.Nerve)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local LootRoller = require(ReplicatedStorage.Shared.Loot.LootRoller)
local EnemyCatalog = require(ReplicatedStorage.Shared.World.EnemyCatalog)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)
local HazardZoneService = require(script.Parent.HazardZoneService)

export type EnemyInstance = {
	id: string,
	archetypeId: string,
	def: EnemyCatalog.EnemyDef,
	isDummy: boolean,
	campId: string?,
	homePos: Vector3,
	position: Vector3,
	facingYaw: number,
	strafeSign: number,
	attackCooldown: number,
	bossPhase: number,
	vitality: DamageMath.VitalityState,
	model: Model,
	nerve: Nerve.NerveKeeper<any>,
}

export type CampState = {
	spec: { [string]: any },
	aliveCount: number,
	respawnAt: number,
}

local enemies: { [string]: EnemyInstance } = {}
local camps: { [string]: CampState } = {}
local enemiesFolder: Folder? = nil
local combatFeedbackRemote: RemoteEvent? = nil
local onDamagePlayerCallback: ((Player, DamageMath.DamagePacket, Vector3) -> ())? = nil
local aiRng = Rng.new(44556677)
local enemySeq = 0

local EnemyService = {}

local function syncRigTransform(enemy: EnemyInstance)
	local model = enemy.model
	if not model or not model.Parent then
		return
	end
	local s = enemy.def.scale or 1.0
	local baseCf = CFrame.new(enemy.position + Vector3.new(0, 3.0 * s, 0)) * CFrame.Angles(0, enemy.facingYaw, 0)

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			if child.Name == "Root" or child.Name == "TorsoHitbox" then
				child.CFrame = baseCf
			elseif child.Name == "HeadHitbox" then
				child.CFrame = baseCf * CFrame.new(0, 2.15 * s, 0)
			elseif child.Name == "Visor" then
				child.CFrame = baseCf * CFrame.new(0, 2.2 * s, -0.68 * s)
			elseif child.Name == "Legs" then
				child.CFrame = baseCf * CFrame.new(0, -2.1 * s, 0)
			elseif child.Name == "FrontArmorPlate" then
				child.CFrame = baseCf * CFrame.new(0, -0.1 * s, -0.9 * s)
			elseif child.Name == "WeakpointCore" then
				child.CFrame = baseCf * CFrame.new(0, 0.3 * s, 0.85 * s)
			elseif child.Name == "ShieldBubblePart" then
				child.CFrame = baseCf * CFrame.new(0, 0.1 * s, 0)
				child.Transparency = if enemy.vitality.shield > 0 then 0.62 else 1.0
			end
		end
	end

	local bb = model:FindFirstChild("VitalityBillboard")
	if bb then
		local sBg = bb:FindFirstChild("ShieldBg")
		local hBg = bb:FindFirstChild("HealthBg")
		if sBg then
			local sFill = sBg:FindFirstChild("ShieldFill") :: Frame?
			if sFill then
				local frac = if enemy.vitality.maxShield > 0
					then math.clamp(enemy.vitality.shield / enemy.vitality.maxShield, 0, 1)
					else 0
				sFill.Size = UDim2.fromScale(frac, 1)
			end
		end
		if hBg then
			local hFill = hBg:FindFirstChild("HealthFill") :: Frame?
			if hFill then
				local frac = math.clamp(enemy.vitality.health / math.max(1, enemy.vitality.maxHealth), 0, 1)
				hFill.Size = UDim2.fromScale(frac, 1)
			end
		end
	end
end

local function findNearestSurfacePlayer(origin: Vector3, maxRange: number): (Player?, Vector3?, number)
	local bestPlayer: Player? = nil
	local bestPos: Vector3? = nil
	local bestDist = maxRange

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataService.get(player)
		if profile and profile.inRaid and not profile.vitality.dead and not profile.vitality.downed then
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if root and root.Position.Y > -30 then
				local d = (root.Position - origin).Magnitude
				if d <= bestDist then
					bestDist = d
					bestPlayer = player
					bestPos = root.Position
				end
			end
		end
	end
	return bestPlayer, bestPos, bestDist
end

local function advanceEnemyPosition(enemy: EnemyInstance, flatDir: Vector3, stepDist: number)
	if stepDist <= 0.001 or flatDir.Magnitude <= 0.001 then
		return
	end
	local unitDir = Vector3.new(flatDir.X, 0, flatDir.Z).Unit
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = if enemiesFolder then { enemiesFolder } else {}

	local chestOrigin = enemy.position + Vector3.new(0, 2.4, 0)
	local blocked = Workspace:Raycast(chestOrigin, unitDir * (stepDist + 2.2), rayParams)
	local chosenDir = unitDir
	if blocked then
		-- Steer tangentially around graybox containers & cover walls
		local tangent = Vector3.new(-unitDir.Z * enemy.strafeSign, 0, unitDir.X * enemy.strafeSign)
		if not Workspace:Raycast(chestOrigin, tangent * (stepDist + 2.0), rayParams) then
			chosenDir = tangent
		else
			enemy.strafeSign = -enemy.strafeSign
			return
		end
	end

	local nextPos = enemy.position + chosenDir * stepDist
	local downHit = Workspace:Raycast(nextPos + Vector3.new(0, 12, 0), Vector3.new(0, -28, 0), rayParams)
	if downHit and math.abs(downHit.Position.Y - enemy.position.Y) <= 8 then
		nextPos = Vector3.new(nextPos.X, downHit.Position.Y, nextPos.Z)
	end
	enemy.position = nextPos
end

local function fireEnemyAttack(enemy: EnemyInstance, targetPlayer: Player, targetPos: Vector3, damageScale: number?)
	if not onDamagePlayerCallback then
		return
	end
	local mult = damageScale or 1.0
	local hitRoll = aiRng:nextFloat()
	local hitChance = if enemy.def.hasSniperTelegraph then 0.85 else 0.72
	if hitRoll <= hitChance then
		onDamagePlayerCallback(targetPlayer, {
			amount = enemy.def.attackDamage * mult,
			damageType = enemy.def.damageType,
			isHeadshot = false,
			sourceId = enemy.id,
		}, enemy.position)
	end
	if enemy.archetypeId == "SporeHazmat" then
		HazardZoneService.spawnAcidPool(Vector3.new(targetPos.X, 0.25, targetPos.Z), 9.5, 10, 6.5)
	end
	if combatFeedbackRemote then
		combatFeedbackRemote:FireAllClients({
			kind = "Tracer",
			from = enemy.position + Vector3.new(0, 3.2, 0),
			to = targetPos,
			damageType = enemy.def.damageType,
		})
	end
end

local ENEMY_NERVES: { [string]: Nerve.NerveHandler<EnemyInstance> } = {
	Patrol = function(self, keeper, dt)
		if self.isDummy then
			return
		end
		if keeper:isFirstStep() then
			self.strafeSign = if aiRng:nextFloat() > 0.5 then 1 else -1
		end
		-- Gentle patrol orbit around homePos
		local angle = os.clock() * 0.45 * self.strafeSign + (enemySeq * 0.7)
		local goal = self.homePos + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
		local delta = goal - self.position
		if delta.Magnitude > 0.5 then
			local dir = delta.Unit
			self.position += dir * math.min(delta.Magnitude, self.def.moveSpeed * 0.45 * dt)
			self.facingYaw = math.atan2(-dir.X, -dir.Z)
		end

		local target, _, _ = findNearestSurfacePlayer(self.position, self.def.aggroRange)
		if target then
			keeper:setNerve("Engage")
		end
	end,

	Engage = function(self, keeper, dt)
		local target, targetPos, dist = findNearestSurfacePlayer(self.position, self.def.aggroRange * 1.35)
		if not target or not targetPos then
			if keeper:isGreaterEqualTime(3.0) then
				keeper:setNerve("Patrol")
			end
			return
		end

		local flatDelta = Vector3.new(targetPos.X - self.position.X, 0, targetPos.Z - self.position.Z)
		local flatDist = flatDelta.Magnitude
		local forward = if flatDist > 0.05 then flatDelta.Unit else Vector3.new(0, 0, -1)
		local right = Vector3.new(-forward.Z, 0, forward.X)
		self.facingYaw = math.atan2(-forward.X, -forward.Z)

		-- Move toward preferred range + tactical strafe
		local moveVec = Vector3.zero
		if flatDist > self.def.preferredRange + 4 then
			moveVec += forward
		elseif flatDist < self.def.preferredRange - 5 and self.def.preferredRange > 10 then
			moveVec -= forward * 0.75
		end
		if self.def.preferredRange > 10 then
			if keeper:getStep() % 70 == 0 then
				self.strafeSign = -self.strafeSign
			end
			moveVec += right * (0.55 * self.strafeSign)
		end
		if moveVec.Magnitude > 0.05 then
			advanceEnemyPosition(self, moveVec, self.def.moveSpeed * dt)
		end
		-- Tether max 145 studs from camp home so enemies don't wander off the map
		local fromHome = self.position - self.homePos
		if fromHome.Magnitude > 145 then
			self.position = self.homePos + fromHome.Unit * 145
		end

		self.attackCooldown = math.max(0, self.attackCooldown - dt)
		-- Feral Stalker close-mid range LeapPounce!
		if self.archetypeId == "FeralStalker" and flatDist >= 12 and flatDist <= 28 and self.attackCooldown <= 0 then
			keeper:setNerve("LeapPounce")
			return
		end
		if dist <= self.def.attackRange and self.attackCooldown <= 0 then
			if self.def.hasSniperTelegraph then
				keeper:setNerve("SniperTelegraph")
				return
			end
			self.attackCooldown = self.def.attackInterval
			fireEnemyAttack(self, target, targetPos, if self.bossPhase >= 2 then 1.25 else 1.0)
		end

		-- Boss Phase 2/3 Overdrive transition
		if self.def.isBoss and self.bossPhase == 1 and self.vitality.health <= self.vitality.maxHealth * 0.60 then
			self.bossPhase = 2
			keeper:setNerve("BossOverdrive")
		elseif self.def.isBoss and self.bossPhase == 2 and self.vitality.health <= self.vitality.maxHealth * 0.28 then
			self.bossPhase = 3
			keeper:setNerve("BossOverdrive")
		end
	end,

	SniperTelegraph = function(self, keeper, _dt)
		local target, targetPos, _ = findNearestSurfacePlayer(self.position, self.def.attackRange * 1.15)
		if not target or not targetPos then
			keeper:setNerve("Engage")
			return
		end
		local flatDelta = Vector3.new(targetPos.X - self.position.X, 0, targetPos.Z - self.position.Z)
		if flatDelta.Magnitude > 0.1 then
			self.facingYaw = math.atan2(-flatDelta.X, -flatDelta.Z)
		end
		if keeper:isFirstStep() and combatFeedbackRemote then
			combatFeedbackRemote:FireAllClients({
				kind = "SniperLock",
				from = self.position + Vector3.new(0, 4.2, 0),
				to = targetPos,
			})
		end
		if keeper:isGreaterEqualTime(1.05) then
			self.attackCooldown = self.def.attackInterval
			fireEnemyAttack(self, target, targetPos, 1.15)
			keeper:setNerve("Engage")
		end
	end,

	LeapPounce = function(self, keeper, dt)
		local fwd = Vector3.new(-math.sin(self.facingYaw), 0, -math.cos(self.facingYaw))
		advanceEnemyPosition(self, fwd, 38 * dt)
		if keeper:isGreaterEqualTime(0.38) then
			self.attackCooldown = 1.6
			local target, targetPos, _ = findNearestSurfacePlayer(self.position, 10)
			if target and targetPos then
				fireEnemyAttack(self, target, targetPos, 1.30)
			end
			keeper:setNerve("Engage")
		end
	end,

	ShieldBreakEvade = function(self, keeper, dt)
		-- Halo Sangheili homage: when an Aegis Enforcer's energy shield pops, it bursts sideways!
		local right = Vector3.new(math.cos(self.facingYaw), 0, -math.sin(self.facingYaw))
		advanceEnemyPosition(self, right * self.strafeSign, 28 * dt)
		if keeper:isGreaterEqualTime(0.42) then
			keeper:setNerve("Engage")
		end
	end,

	BossOverdrive = function(self, keeper, _dt)
		if keeper:isFirstStep() then
			-- Refill 50% of Warden Goliath's energy shield & summon two Feral Stalker escorts!
			self.vitality.shield = math.max(self.vitality.shield, math.floor(self.vitality.maxShield * 0.65))
			self.vitality.shieldStunRemaining = 0
			EnemyService.spawnEnemy("FeralStalker", self.position + Vector3.new(10, 0, 8), nil)
			EnemyService.spawnEnemy("AegisEnforcer", self.position + Vector3.new(-10, 0, -8), nil)
			if combatFeedbackRemote then
				combatFeedbackRemote:FireAllClients({
					kind = "BossSurge",
					position = self.position,
					phase = self.bossPhase,
				})
			end
		end
		if keeper:isGreaterEqualTime(1.1) then
			keeper:setNerve("Engage")
		end
	end,

	Dead = function(_self, _keeper, _dt) end,
}

function EnemyService.spawnEnemy(archetypeId: string, pos: Vector3, campId: string?): EnemyInstance
	local def = EnemyCatalog.Enemies[archetypeId] or EnemyCatalog.Enemies.AshScavenger
	enemySeq += 1
	local id = "enm_" .. tostring(enemySeq)

	local model = PrefabBuilder.buildEnemyRig({
		id = def.id,
		name = def.name,
		scale = def.scale,
		bodyColor = def.bodyColor,
		accentColor = def.accentColor,
		hasShield = (def.maxShield > 0),
		hasFrontPlate = def.hasFrontShieldPlate,
		isBoss = def.isBoss,
	})
	model.Name = id
	model:SetAttribute("EnemyId", id)
	model:SetAttribute("ArchetypeId", def.id)
	if enemiesFolder then
		model.Parent = enemiesFolder
	end

	local vit = DamageMath.newVitality({
		maxShield = def.maxShield,
		shieldRegenRate = def.shieldRegenRate,
		shieldStunDelay = def.shieldStunDelay,
		maxHealth = def.maxHealth,
		armorRating = def.armorRating,
	})

	local inst: any = {
		id = id,
		archetypeId = def.id,
		def = def,
		isDummy = false,
		campId = campId,
		homePos = pos,
		position = pos,
		facingYaw = 0,
		strafeSign = 1,
		attackCooldown = 0.8,
		bossPhase = 1,
		vitality = vit,
		model = model,
	}
	inst.nerve = Nerve.new(inst, "Patrol", ENEMY_NERVES)
	enemies[id] = inst
	syncRigTransform(inst)
	return inst
end

local function spawnRangeDummies()
	for _, dSpec in ipairs(WorldZones.Bunker.rangeDummies) do
		enemySeq += 1
		local id = dSpec.id
		local model = PrefabBuilder.buildEnemyRig({
			id = id,
			name = dSpec.name,
			scale = 1.05,
			bodyColor = { r = 74, g = 82, b = 96 },
			accentColor = if dSpec.maxShield > 0 then { r = 72, g = 212, b = 255 } else { r = 255, g = 185, b = 72 },
			hasShield = (dSpec.maxShield > 0),
			hasFrontPlate = false,
			isBoss = false,
		})
		model.Name = id
		model:SetAttribute("EnemyId", id)
		model:SetAttribute("IsDummy", true)
		if enemiesFolder then
			model.Parent = enemiesFolder
		end

		local vit = DamageMath.newVitality({
			maxShield = dSpec.maxShield,
			shieldRegenRate = 35,
			shieldStunDelay = 2.6,
			maxHealth = dSpec.maxHealth,
			armorRating = dSpec.armorRating,
		})

		local fakeDef: EnemyCatalog.EnemyDef = {
			id = id,
			name = dSpec.name,
			title = "DPS Target",
			isBoss = false,
			maxShield = dSpec.maxShield,
			shieldRegenRate = 35,
			shieldStunDelay = 2.6,
			maxHealth = dSpec.maxHealth,
			armorRating = dSpec.armorRating,
			moveSpeed = 0,
			aggroRange = 0,
			preferredRange = 0,
			attackRange = 0,
			attackInterval = 99,
			attackDamage = 0,
			damageType = "Kinetic",
			treasureClass = "Tier1_Outskirts",
			dropCount = 0,
			xpReward = 0,
			creditReward = 0,
			scale = 1.05,
			bodyColor = { r = 74, g = 82, b = 96 },
			accentColor = { r = 72, g = 212, b = 255 },
		}

		local pos = Vector3.new(dSpec.pos.x, dSpec.pos.y, dSpec.pos.z)
		local inst: any = {
			id = id,
			archetypeId = id,
			def = fakeDef,
			isDummy = true,
			campId = nil,
			homePos = pos,
			position = pos,
			facingYaw = 0,
			strafeSign = 1,
			attackCooldown = 99,
			bossPhase = 1,
			vitality = vit,
			model = model,
		}
		inst.nerve = Nerve.new(inst, "Patrol", ENEMY_NERVES)
		enemies[id] = inst
		syncRigTransform(inst)
	end
end

local function spawnCamp(campState: CampState)
	local spec = campState.spec
	local list = spec.enemies :: { string }
	campState.aliveCount = #list
	for i, arch in ipairs(list) do
		local offset = Vector3.new(math.cos(i * 2.1) * 7, 0, math.sin(i * 2.1) * 7)
		local pos = Vector3.new(spec.pos.x, spec.pos.y, spec.pos.z) + offset
		EnemyService.spawnEnemy(arch, pos, spec.id)
	end
end

function EnemyService.init(
	eFolder: Folder,
	feedbackRemote: RemoteEvent,
	damagePlayerCb: (Player, DamageMath.DamagePacket, Vector3) -> ()
)
	enemiesFolder = eFolder
	combatFeedbackRemote = feedbackRemote
	onDamagePlayerCallback = damagePlayerCb

	spawnRangeDummies()

	for _, cSpec in ipairs(WorldZones.EnemyCamps) do
		local st: CampState = {
			spec = cSpec,
			aliveCount = 0,
			respawnAt = 0,
		}
		camps[cSpec.id] = st
		spawnCamp(st)
	end
end

function EnemyService.spawnExtractionWave(center: Vector3, archetypes: { string }, coopPlayerCount: number)
	local extraCount = math.clamp(coopPlayerCount - 1, 0, 3)
	local totalToSpawn = #archetypes + extraCount
	for i = 1, totalToSpawn do
		local arch = archetypes[((i - 1) % #archetypes) + 1]
		local angle = (i / totalToSpawn) * math.pi * 2 + aiRng:nextFloat() * 0.4
		local spawnPos = center + Vector3.new(math.cos(angle) * 48, 2, math.sin(angle) * 48)
		local enm = EnemyService.spawnEnemy(arch, spawnPos, nil)
		enm.nerve:setNerve("Engage")
	end
end

function EnemyService.findFromPart(hitPart: Instance?): (EnemyInstance?, string)
	local cur: Instance? = hitPart
	local hitPartName = if hitPart then hitPart.Name else ""
	while cur and cur ~= enemiesFolder do
		local eid = cur:GetAttribute("EnemyId")
		if type(eid) == "string" and enemies[eid] then
			return enemies[eid], hitPartName
		end
		cur = cur.Parent
	end
	return nil, hitPartName
end

function EnemyService.damageEnemy(
	enemy: EnemyInstance,
	attacker: Player?,
	packet: DamageMath.DamagePacket,
	hitPartName: string?
): DamageMath.DamageResult
	if enemy.vitality.dead then
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

	-- Scrap Juggernaut directional armor & glowing back weakpoint!
	local adjustedAmount = packet.amount
	local isHeadshot = packet.isHeadshot == true or hitPartName == "HeadHitbox"
	if hitPartName == "FrontArmorPlate" then
		adjustedAmount *= 0.35
		isHeadshot = false
	elseif hitPartName == "WeakpointCore" then
		adjustedAmount *= 1.45
		isHeadshot = true
	end

	local res = DamageMath.applyDamage(enemy.vitality, {
		amount = adjustedAmount,
		damageType = packet.damageType,
		isHeadshot = isHeadshot,
		critMultiplier = packet.critMultiplier,
		bypassShield = packet.bypassShield,
		sourceId = packet.sourceId,
	}, false)

	-- Firing Range Dummies instantly restore to full when "killed" so players can test DPS forever!
	if enemy.isDummy and res.killed then
		DamageMath.fullRestore(enemy.vitality)
		res.killed = false
		syncRigTransform(enemy)
		return res
	end

	if res.shieldPopped and enemy.def.canEvadeOnShieldBreak and not res.killed then
		enemy.strafeSign = -enemy.strafeSign
		enemy.nerve:setNerve("ShieldBreakEvade")
	elseif not res.killed and enemy.nerve:getState() == "Patrol" then
		enemy.nerve:setNerve("Engage")
	end

	if res.killed then
		enemy.nerve:setNerve("Dead")
		if enemy.campId and camps[enemy.campId] then
			local c = camps[enemy.campId]
			c.aliveCount = math.max(0, c.aliveCount - 1)
			if c.aliveCount == 0 then
				c.respawnAt = os.clock() + (c.spec.respawnSec or 45)
			end
		end

		local killerProfile = if attacker then PlayerDataService.get(attacker) else nil
		local rarityFind = if killerProfile then (killerProfile.aggregatedStats.rarityFind or 0) else 0

		if attacker and killerProfile then
			killerProfile.kills += 1
			killerProfile.credits += enemy.def.creditReward
			PlayerDataService.grantXp(killerProfile, enemy.def.xpReward)
			PlayerDataService.recordContractEvent(killerProfile, "KillAny", "Any", 1)
			PlayerDataService.recordContractEvent(killerProfile, "KillArchetype", enemy.def.id, 1)

			-- Diablo / Halo On-Kill sustain affixes & Legendary perks!
			local lifeOnKill = killerProfile.aggregatedStats.lifeOnKill or 0
			local shieldOnKill = killerProfile.aggregatedStats.shieldOnKill or 0
			local activeGun = killerProfile.paperdoll[killerProfile.activeWeaponSlot]
			if activeGun then
				lifeOnKill += (activeGun.stats.lifeOnKill or 0)
				shieldOnKill += (activeGun.stats.shieldOnKill or 0)
			end
			if lifeOnKill > 0 then
				killerProfile.vitality.health = math.min(killerProfile.vitality.maxHealth, killerProfile.vitality.health + lifeOnKill)
			end
			if shieldOnKill > 0 then
				killerProfile.vitality.shield = math.min(killerProfile.vitality.maxShield, killerProfile.vitality.shield + shieldOnKill)
			end
			LootContainerService.syncPlayer(attacker)
		end

		for _ = 1, enemy.def.dropCount do
			local dropItem = LootRoller.rollFromTreasureClass(enemy.def.treasureClass, aiRng, rarityFind)
			LootContainerService.spawnWorldDrop(dropItem, enemy.position)
		end
		if enemy.def.isBoss then
			-- Guaranteed Reactor Core Relic trophy + extra Scrap drop from Warden Goliath!
			local trophy = LootRoller.createSpecificItem("ReactorCoreRelic", "Epic", 28, 1, aiRng:nextU32())
			LootContainerService.spawnWorldDrop(trophy, enemy.position)
		end

		if enemy.model then
			enemy.model:Destroy()
		end
		enemies[enemy.id] = nil
	else
		syncRigTransform(enemy)
	end

	return res
end

function EnemyService.getEnemiesInRadius(origin: Vector3, radius: number, includeDummies: boolean?): { EnemyInstance }
	local out: { EnemyInstance } = {}
	for _, enm in pairs(enemies) do
		if not enm.vitality.dead and (includeDummies or not enm.isDummy) then
			if (enm.position - origin).Magnitude <= radius then
				table.insert(out, enm)
			end
		end
	end
	return out
end

function EnemyService.tick(dt: number)
	local now = os.clock()
	for _, camp in pairs(camps) do
		if camp.aliveCount == 0 and camp.respawnAt > 0 and now >= camp.respawnAt then
			camp.respawnAt = 0
			spawnCamp(camp)
		end
	end

	for _, enm in pairs(enemies) do
		if not enm.vitality.dead then
			local tickRes = DamageMath.tick(enm.vitality, dt)
			enm.nerve:update(dt)
			if tickRes.shieldRecharging or not enm.isDummy then
				syncRigTransform(enm)
			end
		end
	end
end

function EnemyService.buildRadarBlips(): { { x: number, y: number, z: number, boss: boolean } }
	local blips = {}
	for _, enm in pairs(enemies) do
		if not enm.isDummy and not enm.vitality.dead then
			table.insert(blips, {
				x = math.floor(enm.position.X),
				y = math.floor(enm.position.Y),
				z = math.floor(enm.position.Z),
				boss = enm.def.isBoss,
			})
		end
	end
	return blips
end

return EnemyService
