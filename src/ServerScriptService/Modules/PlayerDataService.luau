--!strict
-- Authoritative Player Profile, Loadout, 2D Grids & Studio-Safe Persistence Service.
--
-- TEMPLATE RULE #2 ENFORCED: `DataStoreService` is NEVER touched at module load!
-- Studio sessions automatically use temporary in-memory profiles (`OfflineSave = true`), while
-- published live servers access `DataStoreService` lazily inside `pcall` at player join/leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local WeaponCatalog = require(ReplicatedStorage.Shared.Weapons.WeaponCatalog)
local LootRoller = require(ReplicatedStorage.Shared.Loot.LootRoller)
local GridContainer = require(ReplicatedStorage.Shared.Inventory.GridContainer)
local DurabilityMath = require(ReplicatedStorage.Shared.Economy.DurabilityMath)
local SkillTreeCatalog = require(ReplicatedStorage.Shared.Progression.SkillTreeCatalog)

export type WeaponSlotRuntime = {
	ammo: number,
	maxAmmo: number,
	heat: number,
	overheatedUntil: number,
	reloadingUntil: number,
	venting: boolean,
	lastShotAt: number,
}

export type ContractProgress = {
	accepted: boolean,
	progress: number,
	claimedCount: number,
}

export type PlayerProfile = {
	userId: number,
	level: number,
	xp: number,
	scrap: number,
	credits: number,
	extractions: number,
	kills: number,
	inRaid: boolean,
	currentZoneId: string,
	activeWeaponSlot: "Primary1" | "Primary2",
	ordnanceId: "EmpGrenade" | "FragGrenade",
	ordnanceReadyAt: number,
	openContainerId: string?,
	paperdoll: { [string]: LootRoller.ItemInstance? },
	belt: { [number]: LootRoller.ItemInstance? },
	backpack: GridContainer.GridData,
	stash: GridContainer.GridData,
	secureCase: GridContainer.GridData,
	contracts: { [string]: ContractProgress },
	skills: { [string]: number },
	aggregatedStats: { [string]: any },
	vitality: DamageMath.VitalityState,
	weaponRuntime: { [string]: WeaponSlotRuntime },
	rng: Rng.RngStream,
}

local profiles: { [Player]: PlayerProfile } = {}
local stateSnapshotRemote: RemoteEvent? = nil
local notificationRemote: RemoteEvent? = nil

local PlayerDataService = {}

function PlayerDataService.bindRemotes(snapshotEvent: RemoteEvent, notifyEvent: RemoteEvent)
	stateSnapshotRemote = snapshotEvent
	notificationRemote = notifyEvent
end

local function makeFreshWeaponRuntime(item: LootRoller.ItemInstance?): WeaponSlotRuntime
	if not item then
		return {
			ammo = 0,
			maxAmmo = 0,
			heat = 0,
			overheatedUntil = 0,
			reloadingUntil = 0,
			venting = false,
			lastShotAt = 0,
		}
	end
	local computed = WeaponCatalog.computeStats(item, nil)
	return {
		ammo = computed.magSize,
		maxAmmo = computed.magSize,
		heat = 0,
		overheatedUntil = 0,
		reloadingUntil = 0,
		venting = false,
		lastShotAt = 0,
	}
end

function PlayerDataService.recomputeStats(profile: PlayerProfile)
	local agg = LootRoller.aggregateLoadoutStats(profile.paperdoll)
	SkillTreeCatalog.applySkillBonuses(agg, profile.skills)
	profile.aggregatedStats = agg
	DamageMath.syncMaxStats(profile.vitality, agg)

	for _, slotKey in ipairs({ "Primary1", "Primary2" }) do
		local wItem = profile.paperdoll[slotKey]
		local rt = profile.weaponRuntime[slotKey]
		if wItem then
			local wStats = WeaponCatalog.computeStats(wItem, agg)
			if not rt then
				profile.weaponRuntime[slotKey] = makeFreshWeaponRuntime(wItem)
			else
				rt.maxAmmo = wStats.magSize
				rt.ammo = math.min(rt.ammo, rt.maxAmmo)
			end
		else
			profile.weaponRuntime[slotKey] = makeFreshWeaponRuntime(nil)
		end
	end
end

local function buildDefaultProfile(userId: number): PlayerProfile
	local seed = math.abs(userId) * 1103515245 + 12345
	local rng = Rng.new(seed)

	local backpack = GridContainer.new(Config.grid.backpackWidth, Config.grid.backpackHeight)
	local stash = GridContainer.new(Config.grid.stashWidth, Config.grid.stashHeight)
	local secureCase = GridContainer.new(Config.grid.secureWidth, Config.grid.secureHeight)

	-- Equipped starter Halo x Wasteland kit
	local paperdoll: { [string]: LootRoller.ItemInstance? } = {
		Primary1 = LootRoller.createSpecificItem("MA7Rifle", "Uncommon", 2, 1, rng:nextU32()),
		Primary2 = LootRoller.createSpecificItem("M6DSidearm", "Common", 1, 1, rng:nextU32()),
		ShieldCore = LootRoller.createSpecificItem("StandardCore", "Uncommon", 2, 1, rng:nextU32()),
		Head = LootRoller.createSpecificItem("ReconVisor", "Common", 1, 1, rng:nextU32()),
		Chest = LootRoller.createSpecificItem("ScavPlate", "Common", 1, 1, rng:nextU32()),
		Legs = LootRoller.createSpecificItem("DrifterGreaves", "Common", 1, 1, rng:nextU32()),
		Relic1 = nil,
		Relic2 = nil,
	}

	local belt: { [number]: LootRoller.ItemInstance? } = {
		[1] = LootRoller.createSpecificItem("MedInjector", "Common", 1, 3, rng:nextU32()),
		[2] = LootRoller.createSpecificItem("ShieldCell", "Common", 1, 2, rng:nextU32()),
		[3] = LootRoller.createSpecificItem("RadFlush", "Common", 1, 1, rng:nextU32()),
		[4] = nil,
	}

	-- Pre-stock Stash with a Sol-Coil Plasma Carbine, Trench Sweeper, and BR-55 so players can
	-- immediately experiment with 2D grid rotation, weapon swapping, and Halo shield-breaking!
	GridContainer.autoPlace(stash, LootRoller.createSpecificItem("SolCoilCarbine", "Rare", 4, 1, rng:nextU32()))
	GridContainer.autoPlace(stash, LootRoller.createSpecificItem("BR55Burst", "Uncommon", 3, 1, rng:nextU32()))
	GridContainer.autoPlace(stash, LootRoller.createSpecificItem("TrenchSweeper", "Common", 2, 1, rng:nextU32()))
	GridContainer.autoPlace(stash, LootRoller.createSpecificItem("SolarShard", "Rare", 5, 1, rng:nextU32()))

	-- Starter emergency injector inside the 2x2 Secure Case
	GridContainer.autoPlace(secureCase, LootRoller.createSpecificItem("MedInjector", "Common", 1, 2, rng:nextU32()))

	local contracts: { [string]: ContractProgress } = {}
	for i, c in ipairs(DurabilityMath.Contracts) do
		contracts[c.id] = {
			accepted = (i <= 3), -- First 3 contracts active right away!
			progress = 0,
			claimedCount = 0,
		}
	end

	local agg = LootRoller.aggregateLoadoutStats(paperdoll)
	local vit = DamageMath.newVitality(agg)
	DamageMath.fullRestore(vit)

	local profile: PlayerProfile = {
		userId = userId,
		level = 1,
		xp = 0,
		scrap = Config.economy.startingScrap,
		credits = Config.economy.startingCredits,
		extractions = 0,
		kills = 0,
		inRaid = false,
		currentZoneId = "Bunker",
		activeWeaponSlot = "Primary1",
		ordnanceId = "EmpGrenade",
		ordnanceReadyAt = 0,
		openContainerId = nil,
		paperdoll = paperdoll,
		belt = belt,
		backpack = backpack,
		stash = stash,
		secureCase = secureCase,
		contracts = contracts,
		skills = {},
		aggregatedStats = agg,
		vitality = vit,
		weaponRuntime = {
			Primary1 = makeFreshWeaponRuntime(paperdoll.Primary1),
			Primary2 = makeFreshWeaponRuntime(paperdoll.Primary2),
		},
		rng = rng,
	}

	return profile
end

local function serializeProfileForSave(profile: PlayerProfile): { [string]: any }
	return {
		version = 1,
		level = profile.level,
		xp = profile.xp,
		scrap = profile.scrap,
		credits = profile.credits,
		extractions = profile.extractions,
		kills = profile.kills,
		paperdoll = profile.paperdoll,
		belt = profile.belt,
		backpack = GridContainer.serialize(profile.backpack),
		stash = GridContainer.serialize(profile.stash),
		secureCase = GridContainer.serialize(profile.secureCase),
		contracts = profile.contracts,
		skills = profile.skills,
	}
end

local function hydrateSavedProfile(userId: number, saved: { [string]: any }): PlayerProfile
	local profile = buildDefaultProfile(userId)
	if type(saved) ~= "table" or saved.version ~= 1 then
		return profile
	end
	profile.level = saved.level or profile.level
	profile.xp = saved.xp or profile.xp
	profile.scrap = saved.scrap or profile.scrap
	profile.credits = saved.credits or profile.credits
	profile.extractions = saved.extractions or 0
	profile.kills = saved.kills or 0
	if type(saved.paperdoll) == "table" then
		profile.paperdoll = saved.paperdoll
	end
	if type(saved.belt) == "table" then
		profile.belt = saved.belt
	end
	if type(saved.backpack) == "table" then
		profile.backpack = GridContainer.deserialize(saved.backpack)
	end
	if type(saved.stash) == "table" then
		profile.stash = GridContainer.deserialize(saved.stash)
	end
	if type(saved.secureCase) == "table" then
		profile.secureCase = GridContainer.deserialize(saved.secureCase)
	end
	if type(saved.contracts) == "table" then
		for k, v in pairs(saved.contracts) do
			profile.contracts[k] = v
		end
	end
	if type(saved.skills) == "table" then
		for k, v in pairs(saved.skills) do
			if type(v) == "number" then
				profile.skills[k] = math.floor(v)
			end
		end
	end
	PlayerDataService.recomputeStats(profile)
	DamageMath.fullRestore(profile.vitality)
	return profile
end

function PlayerDataService.loadForPlayer(player: Player): PlayerProfile
	local profile: PlayerProfile? = nil

	-- Lazy runtime check: NEVER touch DataStoreService in Studio!
	if RunService:IsStudio() then
		player:SetAttribute("OfflineSave", true)
		profile = buildDefaultProfile(player.UserId)
	else
		local ok, savedData = pcall(function()
			local DataStoreService = game:GetService("DataStoreService")
			local store = DataStoreService:GetDataStore("AshfallBastionV1")
			return store:GetAsync("u_" .. tostring(player.UserId))
		end)
		if ok and type(savedData) == "table" then
			profile = hydrateSavedProfile(player.UserId, savedData)
		else
			if not ok then
				player:SetAttribute("OfflineSave", true)
			end
			profile = buildDefaultProfile(player.UserId)
		end
	end

	local resolved = profile :: PlayerProfile
	profiles[player] = resolved
	return resolved
end

function PlayerDataService.saveForPlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if RunService:IsStudio() or player:GetAttribute("OfflineSave") == true then
		return
	end
	local payload = serializeProfileForSave(profile)
	pcall(function()
		local DataStoreService = game:GetService("DataStoreService")
		local store = DataStoreService:GetDataStore("AshfallBastionV1")
		store:SetAsync("u_" .. tostring(player.UserId), payload)
	end)
end

function PlayerDataService.cleanupPlayer(player: Player)
	PlayerDataService.saveForPlayer(player)
	profiles[player] = nil
end

function PlayerDataService.get(player: Player): PlayerProfile?
	return profiles[player]
end

function PlayerDataService.getAll(): { [Player]: PlayerProfile }
	return profiles
end

function PlayerDataService.grantXp(profile: PlayerProfile, amount: number)
	profile.xp += math.max(0, math.floor(amount))
	while profile.xp >= (profile.level * 150) do
		profile.xp -= (profile.level * 150)
		profile.level += 1
	end
end

function PlayerDataService.recordContractEvent(profile: PlayerProfile, kind: string, targetKey: string, count: number)
	for _, def in ipairs(DurabilityMath.Contracts) do
		local st = profile.contracts[def.id]
		if st and st.accepted and def.kind == kind then
			if def.targetKey == "Any" or def.targetKey == targetKey then
				st.progress = math.min(def.goal, st.progress + count)
			end
		end
	end
end

function PlayerDataService.notify(player: Player, message: string, tone: string?)
	if notificationRemote then
		notificationRemote:FireClient(player, {
			message = message,
			tone = tone or "info",
		})
	end
end

function PlayerDataService.buildClientPayload(
	profile: PlayerProfile,
	extraContainerGrid: GridContainer.GridData?,
	extraContainerTitle: string?
): { [string]: any }
	local now = os.clock()
	local wRuntimeOut = {}
	for slotKey, rt in pairs(profile.weaponRuntime) do
		wRuntimeOut[slotKey] = {
			ammo = rt.ammo,
			maxAmmo = rt.maxAmmo,
			heat = math.floor(rt.heat * 10) / 10,
			isOverheated = (now < rt.overheatedUntil),
			isReloading = (now < rt.reloadingUntil),
			venting = rt.venting,
		}
	end

	return {
		level = profile.level,
		xp = profile.xp,
		xpNext = profile.level * 150,
		scrap = profile.scrap,
		credits = profile.credits,
		extractions = profile.extractions,
		kills = profile.kills,
		inRaid = profile.inRaid,
		currentZoneId = profile.currentZoneId,
		activeWeaponSlot = profile.activeWeaponSlot,
		ordnanceId = profile.ordnanceId,
		ordnanceCooldown = math.max(0, math.ceil((profile.ordnanceReadyAt - now) * 10) / 10),
		vitality = {
			shield = math.floor(profile.vitality.shield + 0.5),
			maxShield = profile.vitality.maxShield,
			shieldStunRemaining = math.floor(profile.vitality.shieldStunRemaining * 10) / 10,
			health = math.floor(profile.vitality.health + 0.5),
			maxHealth = profile.vitality.maxHealth,
			corrosive = (profile.vitality.corrosiveTimer > 0),
			downed = profile.vitality.downed,
			bleedoutRemaining = math.ceil(profile.vitality.bleedoutRemaining),
		},
		stats = profile.aggregatedStats,
		paperdoll = profile.paperdoll,
		belt = profile.belt,
		backpack = GridContainer.serialize(profile.backpack),
		stash = GridContainer.serialize(profile.stash),
		secureCase = GridContainer.serialize(profile.secureCase),
		openContainer = if extraContainerGrid
			then {
				id = profile.openContainerId,
				title = extraContainerTitle or "LOOT CONTAINER",
				grid = GridContainer.serialize(extraContainerGrid),
			}
			else nil,
		weaponRuntime = wRuntimeOut,
		contracts = profile.contracts,
		skills = profile.skills,
		skillPoints = SkillTreeCatalog.getAvailablePoints(profile.level, profile.skills),
	}
end

function PlayerDataService.sendSnapshot(
	player: Player,
	extraContainerGrid: GridContainer.GridData?,
	extraContainerTitle: string?
)
	local profile = profiles[player]
	if not profile or not stateSnapshotRemote then
		return
	end
	stateSnapshotRemote:FireClient(player, PlayerDataService.buildClientPayload(profile, extraContainerGrid, extraContainerTitle))
end

return PlayerDataService
