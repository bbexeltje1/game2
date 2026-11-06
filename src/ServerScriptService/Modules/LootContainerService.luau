--!strict
-- World Loot Containers (`OpenXRay` `InventoryBox` pattern), Dropped Loot Parcels (Diablo rarity
-- light beams), and Authoritative 2D Grid Inventory Mutation Service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local AffixCatalog = require(ReplicatedStorage.Shared.Loot.AffixCatalog)
local LootRoller = require(ReplicatedStorage.Shared.Loot.LootRoller)
local GridContainer = require(ReplicatedStorage.Shared.Inventory.GridContainer)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local PlayerDataService = require(script.Parent.PlayerDataService)

export type WorldContainerRecord = {
	id: string,
	kind: string,
	title: string,
	position: Vector3,
	treasureClass: string,
	locked: boolean,
	grid: GridContainer.GridData,
	model: Model,
	restockAt: number,
}

export type WorldDropRecord = {
	id: string,
	item: LootRoller.ItemInstance,
	position: Vector3,
	model: Model,
	expiresAt: number,
}

local containers: { [string]: WorldContainerRecord } = {}
local worldDrops: { [string]: WorldDropRecord } = {}
local containersFolder: Folder? = nil
local dropsFolder: Folder? = nil
local worldRng = Rng.new(987654321)
local dropSeq = 0

local LootContainerService = {}

local function populateContainer(rec: WorldContainerRecord, rarityFind: number?)
	GridContainer.clearAll(rec.grid)
	local itemCount = if rec.kind == "KeycardVault"
		then worldRng:nextInt(3, 5)
		elseif rec.kind == "MilitaryLocker" then worldRng:nextInt(2, 4)
		else worldRng:nextInt(2, 3)

	for _ = 1, itemCount do
		local rolled = LootRoller.rollFromTreasureClass(rec.treasureClass, worldRng, rarityFind or 0)
		GridContainer.autoPlace(rec.grid, rolled)
	end
end

function LootContainerService.init(cFolder: Folder, dFolder: Folder)
	containersFolder = cFolder
	dropsFolder = dFolder

	for _, spec in ipairs(WorldZones.LootContainers) do
		local pos = Vector3.new(spec.pos.x, spec.pos.y, spec.pos.z)
		local model = PrefabBuilder.buildContainer(spec.kind, CFrame.new(pos), spec.locked)
		model.Name = spec.id
		model:SetAttribute("ContainerId", spec.id)
		model:SetAttribute("ContainerKind", spec.kind)
		model:SetAttribute("Locked", spec.locked)
		model.Parent = cFolder

		local title = if spec.kind == "KeycardVault"
			then "ARMORY VAULT (KEYCARD)"
			elseif spec.kind == "MilitaryLocker" then "MILITARY LOCKER"
			else "SUPPLY CRATE"

		local rec: WorldContainerRecord = {
			id = spec.id,
			kind = spec.kind,
			title = title,
			position = pos,
			treasureClass = spec.tc,
			locked = spec.locked,
			grid = GridContainer.new(Config.grid.crateWidth, Config.grid.crateHeight),
			model = model,
			restockAt = 0,
		}
		populateContainer(rec, 0)
		containers[spec.id] = rec
	end
end

function LootContainerService.tick(_dt: number)
	local now = os.clock()
	for _, rec in pairs(containers) do
		if rec.restockAt > 0 and now >= rec.restockAt then
			rec.restockAt = 0
			populateContainer(rec, 0)
		end
	end
	for id, drop in pairs(worldDrops) do
		if now >= drop.expiresAt then
			if drop.model then
				drop.model:Destroy()
			end
			worldDrops[id] = nil
		end
	end
end

function LootContainerService.spawnWorldDrop(item: LootRoller.ItemInstance, origin: Vector3): string
	dropSeq += 1
	local dropId = "drop_" .. tostring(dropSeq)
	local jitter = Vector3.new((worldRng:nextFloat() - 0.5) * 4.0, 0, (worldRng:nextFloat() - 0.5) * 4.0)
	local pos = Vector3.new(origin.X + jitter.X, math.max(0.5, origin.Y), origin.Z + jitter.Z)
	local rDef = AffixCatalog.Rarities[item.rarity] or AffixCatalog.Rarities.Common

	local label = if item.stack > 1 then (item.name .. " x" .. tostring(item.stack)) else item.name
	local model = PrefabBuilder.buildLootDrop(label, rDef.color, pos)
	model.Name = dropId
	model:SetAttribute("DropId", dropId)
	if dropsFolder then
		model.Parent = dropsFolder
	end

	worldDrops[dropId] = {
		id = dropId,
		item = item,
		position = pos,
		model = model,
		expiresAt = os.clock() + 240,
	}
	return dropId
end

local function consumeKeycard(profile: PlayerDataService.PlayerProfile): boolean
	for _, grid in ipairs({ profile.backpack, profile.secureCase }) do
		for uid, entry in pairs(grid.entries) do
			if entry.item.baseId == "VaultKeycard" then
				entry.item.stack -= 1
				if entry.item.stack <= 0 then
					GridContainer.remove(grid, uid)
				end
				return true
			end
		end
	end
	return false
end

function LootContainerService.openContainer(player: Player, containerId: string)
	local profile = PlayerDataService.get(player)
	local rec = containers[containerId]
	if not profile or not rec then
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root and (root.Position - rec.position).Magnitude > 20 then
		PlayerDataService.notify(player, "Move closer to search container.", "warn")
		return
	end

	if rec.locked then
		if not consumeKeycard(profile) then
			PlayerDataService.notify(player, "Requires a Bastion Armory Keycard!", "error")
			return
		end
		rec.locked = false
		rec.model:SetAttribute("Locked", false)
		populateContainer(rec, profile.aggregatedStats.rarityFind or 0)
		PlayerDataService.notify(player, "Armory Keycard accepted — Vault unlocked!", "success")
	end

	profile.openContainerId = containerId
	PlayerDataService.sendSnapshot(player, rec.grid, rec.title)
end

function LootContainerService.pickupDrop(player: Player, dropId: string)
	local profile = PlayerDataService.get(player)
	local drop = worldDrops[dropId]
	if not profile or not drop then
		return
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root and (root.Position - drop.position).Magnitude > 20 then
		return
	end

	local placed = false
	if drop.item.category == "Consumable" then
		for i = 1, Config.grid.beltSlots do
			local bItem = profile.belt[i]
			if bItem and bItem.baseId == drop.item.baseId and bItem.stack < bItem.maxStack then
				local add = math.min(bItem.maxStack - bItem.stack, drop.item.stack)
				bItem.stack += add
				drop.item.stack -= add
				if drop.item.stack <= 0 then
					placed = true
					break
				end
			elseif not bItem then
				profile.belt[i] = drop.item
				placed = true
				break
			end
		end
	end

	if not placed then
		placed = GridContainer.autoPlace(profile.backpack, drop.item)
	end

	if not placed then
		PlayerDataService.notify(player, "Backpack grid full! Press [TAB] to reorganize or rotate [R].", "warn")
		return
	end

	if drop.model then
		drop.model:Destroy()
	end
	worldDrops[dropId] = nil
	PlayerDataService.notify(player, "Looted " .. drop.item.name, "success")
	LootContainerService.syncPlayer(player)
end

local function resolveGridByName(
	profile: PlayerDataService.PlayerProfile,
	gridName: string
): GridContainer.GridData?
	if gridName == "Backpack" then
		return profile.backpack
	elseif gridName == "SecureCase" then
		return profile.secureCase
	elseif gridName == "Stash" then
		if profile.inRaid then
			return nil -- Cannot access Bunker Stash while out on the Wasteland surface!
		end
		return profile.stash
	elseif gridName == "Crate" and profile.openContainerId then
		local rec = containers[profile.openContainerId]
		if rec then
			return rec.grid
		end
	end
	return nil
end

function LootContainerService.syncPlayer(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local openRec = if profile.openContainerId then containers[profile.openContainerId] else nil
	if openRec and #GridContainer.listItems(openRec.grid) == 0 and openRec.restockAt == 0 then
		openRec.restockAt = os.clock() + 75
	end
	PlayerDataService.sendSnapshot(
		player,
		if openRec then openRec.grid else nil,
		if openRec then openRec.title else nil
	)
end

function LootContainerService.handleInventoryAction(
	player: Player,
	payload: { [string]: any },
	onWeaponChanged: ((Player) -> ())?
)
	local profile = PlayerDataService.get(player)
	if not profile or type(payload) ~= "table" then
		return
	end

	local action = payload.action
	if action == "CloseContainer" then
		profile.openContainerId = nil
		PlayerDataService.sendSnapshot(player, nil, nil)
		return
	elseif action == "MoveGrid" then
		local src = resolveGridByName(profile, tostring(payload.srcGrid or ""))
		local dst = resolveGridByName(profile, tostring(payload.dstGrid or ""))
		local uid = tostring(payload.uid or "")
		local dstX = tonumber(payload.x) or 1
		local dstY = tonumber(payload.y) or 1
		local rotated = if type(payload.rotated) == "boolean" then payload.rotated else nil
		if src and dst then
			local ok, reason = GridContainer.moveAcrossGrids(src, dst, uid, dstX, dstY, rotated)
			if not ok and reason then
				PlayerDataService.notify(player, reason, "warn")
			end
		end
	elseif action == "RotateInPlace" then
		local src = resolveGridByName(profile, tostring(payload.srcGrid or ""))
		local uid = tostring(payload.uid or "")
		if src and src.entries[uid] then
			local entry = src.entries[uid]
			local ok = GridContainer.place(src, entry.item, entry.x, entry.y, not entry.item.rotated)
			if not ok then
				PlayerDataService.notify(player, "Not enough space to rotate here.", "warn")
			end
		end
	elseif action == "EquipFromGrid" then
		local src = resolveGridByName(profile, tostring(payload.srcGrid or ""))
		local uid = tostring(payload.uid or "")
		local slotName = tostring(payload.slot or "")
		if src and src.entries[uid] then
			local item = src.entries[uid].item
			if GridContainer.canEquipSlot(slotName, item) then
				GridContainer.remove(src, uid)
				local prev = profile.paperdoll[slotName]
				profile.paperdoll[slotName] = item
				if prev then
					if not GridContainer.autoPlace(src, prev) and not GridContainer.autoPlace(profile.backpack, prev) then
						-- Rollback if nowhere to put displaced item
						profile.paperdoll[slotName] = prev
						GridContainer.autoPlace(src, item)
						PlayerDataService.notify(player, "No grid room for unequipped item.", "warn")
					end
				end
				PlayerDataService.recomputeStats(profile)
				if onWeaponChanged then
					onWeaponChanged(player)
				end
			end
		end
	elseif action == "UnequipToGrid" then
		local slotName = tostring(payload.slot or "")
		local dstName = tostring(payload.dstGrid or "Backpack")
		local dst = resolveGridByName(profile, dstName) or profile.backpack
		local item = profile.paperdoll[slotName]
		if item and dst then
			if GridContainer.autoPlace(dst, item) then
				profile.paperdoll[slotName] = nil
				PlayerDataService.recomputeStats(profile)
				if onWeaponChanged then
					onWeaponChanged(player)
				end
			else
				PlayerDataService.notify(player, "No room in target grid!", "warn")
			end
		end
	elseif action == "EquipBeltFromGrid" then
		local src = resolveGridByName(profile, tostring(payload.srcGrid or ""))
		local uid = tostring(payload.uid or "")
		local beltIdx = math.clamp(tonumber(payload.beltIndex) or 1, 1, Config.grid.beltSlots)
		if src and src.entries[uid] then
			local item = src.entries[uid].item
			if item.category == "Consumable" then
				GridContainer.remove(src, uid)
				local prev = profile.belt[beltIdx]
				profile.belt[beltIdx] = item
				if prev then
					GridContainer.autoPlace(src, prev)
				end
			end
		end
	elseif action == "UseBelt" then
		local beltIdx = math.clamp(tonumber(payload.beltIndex) or 1, 1, Config.grid.beltSlots)
		local item = profile.belt[beltIdx]
		if item and not profile.vitality.dead and not profile.vitality.downed then
			local healHp = item.stats.healHealth or 0
			local healSh = item.stats.healShield or 0
			if healHp > 0 then
				profile.vitality.health = math.min(profile.vitality.maxHealth, profile.vitality.health + healHp)
			end
			if healSh > 0 then
				profile.vitality.shield = math.min(profile.vitality.maxShield, profile.vitality.shield + healSh)
				profile.vitality.shieldStunRemaining = 0
			end
			if (item.stats.clearCorrosive or 0) > 0 then
				profile.vitality.corrosiveTimer = 0
			end
			item.stack -= 1
			if item.stack <= 0 then
				profile.belt[beltIdx] = nil
			end
			PlayerDataService.notify(player, "Used " .. item.name, "info")
		end
	elseif action == "QuickTransfer" then
		-- Shift+Click convenience: Crate -> Backpack, or Backpack <-> Stash / Equip
		local srcName = tostring(payload.srcGrid or "")
		local src = resolveGridByName(profile, srcName)
		local uid = tostring(payload.uid or "")
		if src and src.entries[uid] then
			local item = src.entries[uid].item
			local targetGrid: GridContainer.GridData? = nil
			if srcName == "Crate" or srcName == "Stash" or srcName == "SecureCase" then
				targetGrid = profile.backpack
			elseif srcName == "Backpack" then
				if profile.openContainerId and containers[profile.openContainerId] then
					targetGrid = containers[profile.openContainerId].grid
				elseif not profile.inRaid then
					targetGrid = profile.stash
				else
					targetGrid = profile.secureCase
				end
			end
			if targetGrid then
				GridContainer.remove(src, uid)
				if not GridContainer.autoPlace(targetGrid, item) then
					GridContainer.autoPlace(src, item)
					PlayerDataService.notify(player, "Target grid has no room!", "warn")
				end
			end
		end
	elseif action == "DropFromGrid" then
		local src = resolveGridByName(profile, tostring(payload.srcGrid or ""))
		local uid = tostring(payload.uid or "")
		if src and src.entries[uid] then
			local item = GridContainer.remove(src, uid)
			if item then
				local char = player.Character
				local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				local pos = if root then (root.Position - Vector3.new(0, 2.5, 0)) else Vector3.new(0, -118, 0)
				LootContainerService.spawnWorldDrop(item, pos)
			end
		end
	end

	LootContainerService.syncPlayer(player)
end

function LootContainerService.getContainers(): { [string]: WorldContainerRecord }
	return containers
end

function LootContainerService.getWorldDrops(): { [string]: WorldDropRecord }
	return worldDrops
end

return LootContainerService
