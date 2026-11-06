--!strict
-- Server entry point for ASHFALL: Bastion Protocol.
-- Keeps wiring clean: creates all Remotes FIRST (so clients never stall on WaitForChild),
-- builds the seamless Graybox Bunker + Wasteland world, and ticks authoritative services.

print("[game] server: booting ASHFALL: Bastion Protocol")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemotesSchema = require(ReplicatedStorage.Shared.Net.RemotesSchema)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)

-- 1. Create Remotes folder & every RemoteEvent BEFORE requiring or booting heavy services!
local remotes = Instance.new("Folder")
remotes.Name = RemotesSchema.folderName
remotes.Parent = ReplicatedStorage

local remoteMap: { [string]: RemoteEvent } = {}
for _, eventName in pairs(RemotesSchema.events) do
	local ev = Instance.new("RemoteEvent")
	ev.Name = eventName
	ev.Parent = remotes
	remoteMap[eventName] = ev
end

-- 2. Require Server Services
local Modules = script.Parent:WaitForChild("Modules", 10)
local PlayerDataService = require(Modules.PlayerDataService)
local WorldBuilderService = require(Modules.WorldBuilderService)
local LootContainerService = require(Modules.LootContainerService)
local HazardZoneService = require(Modules.HazardZoneService)
local EnemyService = require(Modules.EnemyService)
local ExtractionService = require(Modules.ExtractionService)
local CombatAndWeaponService = require(Modules.CombatAndWeaponService)
local BunkerStationService = require(Modules.BunkerStationService)

-- 3. Construct Graybox Bunker + 4-Zone Wasteland & Boot Services
PlayerDataService.bindRemotes(remoteMap.StateSnapshot, remoteMap.Notification)
local worldRefs = WorldBuilderService.build()
LootContainerService.init(worldRefs.containersFolder, worldRefs.dropsFolder)
HazardZoneService.init(worldRefs.worldRoot)
CombatAndWeaponService.init(remoteMap.CombatFeedback, remoteMap.RaidSummary)
EnemyService.init(worldRefs.enemiesFolder, remoteMap.CombatFeedback, CombatAndWeaponService.damagePlayer)
ExtractionService.init(worldRefs.beaconsFolder, remoteMap.RaidSummary)

-- 4. Bind Client -> Server Remote Intents
remoteMap.WeaponFire.OnServerEvent:Connect(function(player, payload)
	CombatAndWeaponService.handleWeaponFire(player, payload)
end)

remoteMap.WeaponAction.OnServerEvent:Connect(function(player, payload)
	CombatAndWeaponService.handleWeaponAction(player, payload)
end)

remoteMap.TacticalMove.OnServerEvent:Connect(function(player, payload)
	CombatAndWeaponService.handleTacticalMove(player, payload)
end)

remoteMap.InventoryAction.OnServerEvent:Connect(function(player, payload)
	LootContainerService.handleInventoryAction(player, payload, CombatAndWeaponService.refreshCharacterWeapon)
end)

remoteMap.BunkerAction.OnServerEvent:Connect(function(player, payload)
	BunkerStationService.handleAction(player, payload)
end)

remoteMap.InteractWorld.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "OpenCrate" then
		LootContainerService.openContainer(player, tostring(payload.id or ""))
	elseif kind == "PickupDrop" then
		LootContainerService.pickupDrop(player, tostring(payload.id or ""))
	elseif kind == "HarvestAnomaly" then
		HazardZoneService.harvestAnomaly(player, tostring(payload.id or ""))
	elseif kind == "TriggerExtraction" then
		ExtractionService.triggerBeacon(player, tostring(payload.id or ""))
	elseif kind == "DeployZone" then
		BunkerStationService.deployToZone(player, tostring(payload.zoneId or "Zone1"))
	elseif kind == "ReviveAlly" then
		CombatAndWeaponService.tryReviveTeammate(player, tonumber(payload.userId) or 0)
	end
end)

-- 5. Player Lifecycle
local function setupCharacter(player: Player, char: Model)
	task.defer(function()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			-- Prevent default Roblox health bar from fighting our authoritative Halo Shield + Health system
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.BreakJointsOnDeath = false
		end
		local sp = WorldZones.Bunker.spawn
		local profile = PlayerDataService.get(player)
		if profile and not profile.inRaid then
			char:PivotTo(CFrame.new(sp.x, sp.y + 3, sp.z))
		end
		CombatAndWeaponService.refreshCharacterWeapon(player)
		LootContainerService.syncPlayer(player)
	end)
end

local function onPlayerAdded(player: Player)
	if RunService:IsStudio() then
		print("[game] studio run: temporary progress, nothing to configure")
	end
	player:SetAttribute("JoinedAt", os.time())
	PlayerDataService.loadForPlayer(player)

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end

	LootContainerService.syncPlayer(player)
	remoteMap.Ready:FireClient(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	CombatAndWeaponService.cleanupPlayer(player)
	PlayerDataService.cleanupPlayer(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- 6. Authoritative Simulation Loop + 2Hz Radar & Beacon World Broadcast
local worldBroadcastAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
	local clampedDt = math.min(dt, 0.1)
	LootContainerService.tick(clampedDt)
	HazardZoneService.tick(clampedDt, CombatAndWeaponService.damagePlayer)
	EnemyService.tick(clampedDt)
	ExtractionService.tick(clampedDt)
	CombatAndWeaponService.tick(clampedDt)

	worldBroadcastAccum += clampedDt
	if worldBroadcastAccum >= 0.5 then
		worldBroadcastAccum = 0
		local squad = {}
		for p, prof in pairs(PlayerDataService.getAll()) do
			local c = p.Character
			local r = if c then c:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			table.insert(squad, {
				userId = p.UserId,
				name = p.Name,
				shield = math.floor(prof.vitality.shield + 0.5),
				maxShield = prof.vitality.maxShield,
				health = math.floor(prof.vitality.health + 0.5),
				maxHealth = prof.vitality.maxHealth,
				downed = prof.vitality.downed,
				inRaid = prof.inRaid,
				x = if r then math.floor(r.Position.X) else 0,
				y = if r then math.floor(r.Position.Y) else -116,
				z = if r then math.floor(r.Position.Z) else 0,
			})
		end
		remoteMap.WorldState:FireAllClients({
			beacons = ExtractionService.buildBeaconSnapshots(),
			radarBlips = EnemyService.buildRadarBlips(),
			squad = squad,
		})
	end
end)

ReplicatedStorage:SetAttribute(Config.readyAttribute, true)
print("[game] server: ready")
