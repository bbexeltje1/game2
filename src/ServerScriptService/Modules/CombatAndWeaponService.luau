--!strict
-- Authoritative Combat, Halo Shield/Health Tick, Weapon Ballistics, Plasma Heat/Vent, Ordnance,
-- Co-op Downed/Revive, and Wasteland Wipe Durability Tax Service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local WeaponCatalog = require(ReplicatedStorage.Shared.Weapons.WeaponCatalog)
local DurabilityMath = require(ReplicatedStorage.Shared.Economy.DurabilityMath)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)
local EnemyService = require(script.Parent.EnemyService)

local combatFeedbackRemote: RemoteEvent? = nil
local raidSummaryRemote: RemoteEvent? = nil
local playerSprintState: { [Player]: { sprinting: boolean, ads: boolean, dodgeUntil: number } } = {}
local snapshotAccum = 0
local hazardAccum = 0

local CombatAndWeaponService = {}

function CombatAndWeaponService.init(feedbackRemote: RemoteEvent, summaryRemote: RemoteEvent)
	combatFeedbackRemote = feedbackRemote
	raidSummaryRemote = summaryRemote
end

-- Attaches both the active graybox weapon (in right hand, angled forward) AND the holstered
-- secondary weapon (slung diagonally across the player's back, Halo-style!).
function CombatAndWeaponService.refreshCharacterWeapon(player: Player)
	local char = player.Character
	local profile = PlayerDataService.get(player)
	if not char or not profile then
		return
	end

	for _, oldName in ipairs({ "EquippedGrayboxWeapon", "HolsteredGrayboxWeapon" }) do
		local existing = char:FindFirstChild(oldName)
		if existing then
			existing:Destroy()
		end
	end

	local activeSlot = profile.activeWeaponSlot
	local otherSlot = if activeSlot == "Primary1" then "Primary2" else "Primary1"
	local activeItem = profile.paperdoll[activeSlot]
	local holsteredItem = profile.paperdoll[otherSlot]

	if activeItem then
		local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if hand then
			local weaponModel = PrefabBuilder.buildWeapon(activeItem.baseId)
			weaponModel.Name = "EquippedGrayboxWeapon"
			local handle = weaponModel.PrimaryPart
			if handle then
				local gripCf = if hand.Name == "HumanoidRootPart"
					then (hand.CFrame * CFrame.new(1.2, 0.2, -1.6))
					else (hand.CFrame * CFrame.new(0, -0.85, -0.35) * CFrame.Angles(math.rad(-90), 0, 0))
				weaponModel:PivotTo(gripCf)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hand
				weld.Part1 = handle
				weld.Parent = handle
			end
			weaponModel.Parent = char
		end
	end

	if holsteredItem then
		local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if torso then
			local backModel = PrefabBuilder.buildWeapon(holsteredItem.baseId)
			backModel.Name = "HolsteredGrayboxWeapon"
			local handle = backModel.PrimaryPart
			if handle then
				backModel:PivotTo(torso.CFrame * CFrame.new(0.15, 0.25, 0.85) * CFrame.Angles(math.rad(35), math.rad(90), math.rad(28)))
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = handle
				weld.Parent = handle
			end
			backModel.Parent = char
		end
	end
end

local function hasOtherLivingRaidTeammate(victim: Player): boolean
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= victim then
			local p = PlayerDataService.get(other)
			if p and p.inRaid and not p.vitality.dead and not p.vitality.downed then
				return true
			end
		end
	end
	return false
end

local function handlePlayerWipe(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local deathPos = if root then root.Position else Vector3.new(-140, 3, 140)

	local penalty = DurabilityMath.applyWipePenalty(profile.backpack, profile.paperdoll)
	-- Spawn dropped Backpack items on the Wasteland surface so co-op allies (or your next run!) can recover them!
	for _, droppedItem in ipairs(penalty.droppedItems) do
		LootContainerService.spawnWorldDrop(droppedItem, deathPos)
	end

	profile.inRaid = false
	profile.currentZoneId = "Bunker"
	profile.openContainerId = nil
	PlayerDataService.recomputeStats(profile)
	DamageMath.fullRestore(profile.vitality)

	if char then
		local sp = WorldZones.Bunker.spawn
		char:PivotTo(CFrame.new(sp.x, sp.y + 3, sp.z))
	end

	LootContainerService.syncPlayer(player)
	if raidSummaryRemote then
		raidSummaryRemote:FireClient(player, {
			outcome = "WIPED",
			droppedCount = #penalty.droppedItems,
			durabilityLost = penalty.totalDurabilityLost,
			affectedSlots = penalty.affectedSlots,
		})
	end
end

function CombatAndWeaponService.damagePlayer(
	player: Player,
	packet: DamageMath.DamagePacket,
	_attackerOrigin: Vector3?
)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.inRaid or profile.vitality.dead then
		return
	end

	-- Brief i-frame window during Directional Combat Roll / Thruster Dodge
	local moveSt = playerSprintState[player]
	if moveSt and os.clock() < moveSt.dodgeUntil and packet.damageType ~= "Hazard" then
		return
	end

	local canDown = hasOtherLivingRaidTeammate(player)
	local res = DamageMath.applyDamage(profile.vitality, packet, canDown)

	-- Visual Halo Energy Shield Shimmer on the player's character rig
	local pChar = player.Character
	if pChar and res.totalDamage > 0 then
		local aura = pChar:FindFirstChild("PlayerShieldAura") :: Highlight?
		if not aura then
			aura = Instance.new("Highlight")
			aura.Name = "PlayerShieldAura"
			aura.DepthMode = Enum.HighlightDepthMode.Occluded
			aura.Parent = pChar
		end
		if aura then
			aura.OutlineColor = if res.shieldPopped
				then Color3.fromRGB(255, 82, 82)
				elseif res.shieldDamage > 0 then Color3.fromRGB(72, 218, 255)
				else Color3.fromRGB(255, 132, 92)
			aura.FillColor = aura.OutlineColor
			aura.FillTransparency = 0.72
			aura.OutlineTransparency = 0.15
			task.delay(0.22, function()
				if aura and aura.Parent then
					aura.FillTransparency = 1
					aura.OutlineTransparency = 1
				end
			end)
		end
	end

	-- Trigger Halo Overload Shield Core EMP Nova when player's shield pops!
	if res.shieldPopped then
		local novaDmg = profile.aggregatedStats.shieldBreakNova or 0
		if novaDmg > 0 then
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if root then
				for _, nearbyEnemy in ipairs(EnemyService.getEnemiesInRadius(root.Position, 22, false)) do
					EnemyService.damageEnemy(nearbyEnemy, player, {
						amount = novaDmg,
						damageType = "Plasma",
						sourceId = tostring(player.UserId),
					}, "TorsoHitbox")
				end
				if profile.aggregatedStats.perks and profile.aggregatedStats.perks.empShieldBreakNova then
					profile.vitality.health = math.min(
						profile.vitality.maxHealth,
						profile.vitality.health + math.floor(profile.vitality.maxHealth * 0.25)
					)
				end
				if combatFeedbackRemote then
					combatFeedbackRemote:FireAllClients({
						kind = "ShieldNova",
						position = root.Position,
					})
				end
			end
		end
	end

	if res.killed then
		handlePlayerWipe(player)
	elseif res.downedTriggered then
		PlayerDataService.notify(player, "CRITICAL — Downed! Teammates can press [E] to revive you!", "error")
		PlayerDataService.sendSnapshot(player, nil, nil)
	end
end

function CombatAndWeaponService.tryReviveTeammate(rescuer: Player, downedUserId: number)
	local rescuerProfile = PlayerDataService.get(rescuer)
	if not rescuerProfile or not rescuerProfile.inRaid or rescuerProfile.vitality.downed then
		return
	end

	for _, other in ipairs(Players:GetPlayers()) do
		if other.UserId == downedUserId then
			local otherProfile = PlayerDataService.get(other)
			if otherProfile and otherProfile.vitality.downed then
				local c1 = rescuer.Character
				local c2 = other.Character
				local r1 = if c1 then c1:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				local r2 = if c2 then c2:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if r1 and r2 and (r1.Position - r2.Position).Magnitude <= 16 then
					DamageMath.revive(otherProfile.vitality)
					PlayerDataService.notify(other, "Revived by " .. rescuer.Name .. "!", "success")
					PlayerDataService.notify(rescuer, "Revived " .. other.Name .. "!", "success")
					PlayerDataService.sendSnapshot(other, nil, nil)
				end
			end
			break
		end
	end
end

function CombatAndWeaponService.handleWeaponFire(player: Player, payload: { [string]: any })
	local profile = PlayerDataService.get(player)
	if not profile or profile.vitality.dead or profile.vitality.downed or type(payload) ~= "table" then
		return
	end

	local activeItem = profile.paperdoll[profile.activeWeaponSlot]
	local rt = profile.weaponRuntime[profile.activeWeaponSlot]
	if not activeItem or not rt then
		return
	end

	local now = os.clock()
	local wStats = WeaponCatalog.computeStats(activeItem, profile.aggregatedStats)

	-- Validate rate of fire (with slight tolerance for network jitter)
	if (now - rt.lastShotAt) < (wStats.shotInterval * 0.80) then
		return
	end
	if now < rt.reloadingUntil or now < rt.overheatedUntil then
		return
	end

	if wStats.usesHeat then
		rt.venting = false
		rt.heat += wStats.heatPerShot
		if rt.heat >= 100 then
			rt.heat = 100
			rt.overheatedUntil = now + wStats.overheatLockoutSeconds
			PlayerDataService.notify(player, "SOL-COIL OVERHEATED! Cooling...", "warn")
		end
	else
		if rt.ammo <= 0 then
			rt.reloadingUntil = now + wStats.reloadSeconds
			rt.ammo = wStats.magSize
			PlayerDataService.sendSnapshot(player, nil, nil)
			return
		end
		rt.ammo -= 1
	end
	rt.lastShotAt = now

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end

	local rawOrigin = payload.origin
	local rawDir = payload.direction
	local origin = if typeof(rawOrigin) == "Vector3" and (rawOrigin - root.Position).Magnitude <= 16
		then rawOrigin
		else (root.Position + Vector3.new(0, 2.0, 0))
	local baseDir = if typeof(rawDir) == "Vector3" and rawDir.Magnitude > 0.01
		then rawDir.Unit
		else root.CFrame.LookVector

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = if char then { char } else {}

	local moveSt = playerSprintState[player]
	local spreadDeg = wStats.spreadDeg * (if moveSt and moveSt.ads then wStats.def.adsSpreadMultiplier else 1.0)

	for pelletIdx = 1, wStats.pellets do
		local spreadRad = math.rad(spreadDeg)
		local rx = (profile.rng:nextFloat() - 0.5) * 2 * spreadRad
		local ry = (profile.rng:nextFloat() - 0.5) * 2 * spreadRad
		local shotDir = (CFrame.lookAt(Vector3.zero, baseDir) * CFrame.Angles(rx, ry, 0)).LookVector
		local castResult = Workspace:Raycast(origin, shotDir * wStats.rangeStuds, rayParams)
		local endPos = if castResult then castResult.Position else (origin + shotDir * wStats.rangeStuds)

		if wStats.splashRadius > 0 then
			local radius = wStats.splashRadius * (if activeItem.perkId == "clusterBombard" then 1.4 else 1.0)
			for _, enm in ipairs(EnemyService.getEnemiesInRadius(endPos, radius, true)) do
				local distFrac = math.clamp(1 - ((enm.position - endPos).Magnitude / (radius + 2)), 0.35, 1.0)
				local dmgRes = EnemyService.damageEnemy(enm, player, {
					amount = wStats.damage * distFrac,
					damageType = wStats.damageType,
					isHeadshot = false,
					critMultiplier = 1.0,
					sourceId = tostring(player.UserId),
				}, "TorsoHitbox")
				if combatFeedbackRemote and dmgRes.totalDamage > 0 then
					combatFeedbackRemote:FireClient(player, {
						kind = "Hitmarker",
						damage = math.floor(dmgRes.totalDamage + 0.5),
						isCrit = false,
						shieldPopped = dmgRes.shieldPopped,
						shieldHit = (dmgRes.shieldDamage > 0 and dmgRes.healthDamage == 0),
						killed = dmgRes.killed,
						position = enm.position + Vector3.new(0, 4, 0),
					})
				end
			end
		elseif castResult and castResult.Instance then
			local enemy, partName = EnemyService.findFromPart(castResult.Instance)
			if enemy then
				local dmgRes = EnemyService.damageEnemy(enemy, player, {
					amount = wStats.damage,
					damageType = wStats.damageType,
					isHeadshot = (partName == "HeadHitbox"),
					critMultiplier = wStats.critMultiplier,
					sourceId = tostring(player.UserId),
				}, partName)

				-- Legendary Perk: Halo's Echo chains plasma lightning & vents 40% heat on shield pop!
				if dmgRes.shieldPopped and activeItem.perkId == "chainShieldArc" then
					rt.heat = math.max(0, rt.heat - 40)
					for _, nearby in ipairs(EnemyService.getEnemiesInRadius(enemy.position, 24, false)) do
						if nearby.id ~= enemy.id then
							EnemyService.damageEnemy(nearby, player, {
								amount = 65,
								damageType = "Plasma",
								sourceId = tostring(player.UserId),
							}, "TorsoHitbox")
						end
					end
				end

				-- Legendary Perk: Valkyrie Spear refunds 1 round on precision crit!
				if dmgRes.isCrit and activeItem.perkId == "railCritRefund" then
					rt.ammo = math.min(wStats.magSize, rt.ammo + 1)
				end

				if combatFeedbackRemote and dmgRes.totalDamage > 0 then
					combatFeedbackRemote:FireClient(player, {
						kind = "Hitmarker",
						damage = math.floor(dmgRes.totalDamage + 0.5),
						isCrit = dmgRes.isCrit,
						shieldPopped = dmgRes.shieldPopped,
						shieldHit = (dmgRes.shieldDamage > 0 and dmgRes.healthDamage == 0),
						killed = dmgRes.killed,
						position = castResult.Position,
					})
				end
			end
		end

		if pelletIdx <= 3 and combatFeedbackRemote then
			combatFeedbackRemote:FireAllClients({
				kind = "Tracer",
				from = origin,
				to = endPos,
				damageType = wStats.damageType,
				shooterId = player.UserId,
			})
		end
	end
end

function CombatAndWeaponService.handleWeaponAction(player: Player, payload: { [string]: any })
	local profile = PlayerDataService.get(player)
	if not profile or type(payload) ~= "table" then
		return
	end

	local now = os.clock()
	local action = payload.action
	local activeItem = profile.paperdoll[profile.activeWeaponSlot]
	local rt = profile.weaponRuntime[profile.activeWeaponSlot]

	if action == "SwapSlot" then
		local desired = if payload.slot == "Primary2" then "Primary2" else "Primary1"
		if profile.activeWeaponSlot ~= desired and profile.paperdoll[desired] ~= nil then
			profile.activeWeaponSlot = desired :: "Primary1" | "Primary2"
			CombatAndWeaponService.refreshCharacterWeapon(player)
		end
	elseif action == "ReloadOrVent" and activeItem and rt then
		local wStats = WeaponCatalog.computeStats(activeItem, profile.aggregatedStats)
		if wStats.usesHeat then
			if now >= rt.overheatedUntil and rt.heat > 0 then
				rt.venting = true
			end
		else
			if rt.ammo < wStats.magSize and now >= rt.reloadingUntil then
				rt.reloadingUntil = now + wStats.reloadSeconds
				rt.ammo = wStats.magSize
			end
		end
	elseif action == "ThrowOrdnance" then
		if now < profile.ordnanceReadyAt or profile.vitality.dead or profile.vitality.downed then
			return
		end
		local ord = WeaponCatalog.Ordnance[profile.ordnanceId] or WeaponCatalog.Ordnance.EmpGrenade
		profile.ordnanceReadyAt = now + ord.cooldown

		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local targetPos = if typeof(payload.targetPos) == "Vector3"
			then payload.targetPos
			elseif root then (root.Position + root.CFrame.LookVector * 28)
			else Vector3.zero

		if root and (targetPos - root.Position).Magnitude > 95 then
			targetPos = root.Position + (targetPos - root.Position).Unit * 95
		end

		for _, enm in ipairs(EnemyService.getEnemiesInRadius(targetPos, ord.radius, true)) do
			local res = EnemyService.damageEnemy(enm, player, {
				amount = ord.baseDamage,
				damageType = ord.damageType,
				sourceId = tostring(player.UserId),
			}, "TorsoHitbox")
			if combatFeedbackRemote and res.totalDamage > 0 then
				combatFeedbackRemote:FireClient(player, {
					kind = "Hitmarker",
					damage = math.floor(res.totalDamage + 0.5),
					isCrit = false,
					shieldPopped = res.shieldPopped,
					shieldHit = (res.shieldDamage > 0 and res.healthDamage == 0),
					killed = res.killed,
					position = enm.position + Vector3.new(0, 4, 0),
				})
			end
		end
		if combatFeedbackRemote then
			combatFeedbackRemote:FireAllClients({
				kind = "OrdnanceBlast",
				position = targetPos,
				damageType = ord.damageType,
				radius = ord.radius,
			})
		end
	elseif action == "ToggleOrdnanceType" then
		profile.ordnanceId = if profile.ordnanceId == "EmpGrenade" then "FragGrenade" else "EmpGrenade"
		PlayerDataService.notify(player, "Equipped " .. WeaponCatalog.Ordnance[profile.ordnanceId].name, "info")
	end

	LootContainerService.syncPlayer(player)
end

function CombatAndWeaponService.handleTacticalMove(player: Player, payload: { [string]: any })
	if type(payload) ~= "table" then
		return
	end
	local st = playerSprintState[player]
	if not st then
		st = { sprinting = false, ads = false, dodgeUntil = 0 }
		playerSprintState[player] = st
	end
	if type(payload.sprinting) == "boolean" then
		st.sprinting = payload.sprinting
	end
	if type(payload.ads) == "boolean" then
		st.ads = payload.ads
	end
	if payload.dodge == true then
		st.dodgeUntil = os.clock() + Config.movement.dodgeDuration
	end

	local profile = PlayerDataService.get(player)
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if profile and hum then
		local speedMult = 1 + (profile.aggregatedStats.moveSpeedPct or 0)
		if profile.vitality.downed then
			hum.WalkSpeed = 4
		elseif st.ads then
			hum.WalkSpeed = Config.movement.adsSpeed * speedMult
		elseif st.sprinting then
			hum.WalkSpeed = Config.movement.sprintSpeed * speedMult
		else
			hum.WalkSpeed = Config.movement.walkSpeed * speedMult
		end
	end
end

function CombatAndWeaponService.cleanupPlayer(player: Player)
	playerSprintState[player] = nil
end

function CombatAndWeaponService.tick(dt: number)
	snapshotAccum += dt
	hazardAccum += dt
	local doHazardTick = false
	if hazardAccum >= 0.5 then
		hazardAccum = 0
		doHazardTick = true
	end

	for player, profile in pairs(PlayerDataService.getAll()) do
		-- Cool Plasma weapons passively or via active manual vent!
		for _, slotKey in ipairs({ "Primary1", "Primary2" }) do
			local item = profile.paperdoll[slotKey]
			local rt = profile.weaponRuntime[slotKey]
			if item and rt and rt.heat > 0 then
				local wStats = WeaponCatalog.computeStats(item, profile.aggregatedStats)
				if wStats.usesHeat then
					local rate = if rt.venting then wStats.manualVentRate else wStats.passiveCoolRate
					rt.heat = math.max(0, rt.heat - rate * dt)
					if rt.heat <= 0 then
						rt.venting = false
					end
				end
			end
		end

		local tickRes = DamageMath.tick(profile.vitality, dt)
		if tickRes.bledOut then
			handlePlayerWipe(player)
		end

		-- Check Wasteland Zone tracking & Radiation / Spore Hazard exposure
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			local z = WorldZones.getZoneAtPosition(root.Position)
			if z then
				profile.inRaid = true
				profile.currentZoneId = z.id
			else
				profile.inRaid = false
				profile.currentZoneId = "Bunker"
			end
		end
	end

	-- Push lightweight 4Hz state snapshots so client shield bars, heat gauges & timers stay crisp
	if snapshotAccum >= 0.25 then
		snapshotAccum = 0
		for player, _ in pairs(PlayerDataService.getAll()) do
			LootContainerService.syncPlayer(player)
		end
	end
end

return CombatAndWeaponService
