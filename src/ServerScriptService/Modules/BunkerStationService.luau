--!strict
-- Bastion Bunker Station Service:
--   1. Surface Airlock Deployment (Zones 1–4)
--   2. Repair & Salvage Workbench (Repair Item, Repair All Equipped, Salvage Item, Bulk Salvage Commons, Reroll Affixes)
--   3. Quartermaster Vendor Purchases
--   4. Repeatable PvE Bounty Contracts (Accept & Claim Rewards)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local LootRoller = require(ReplicatedStorage.Shared.Loot.LootRoller)
local GridContainer = require(ReplicatedStorage.Shared.Inventory.GridContainer)
local DurabilityMath = require(ReplicatedStorage.Shared.Economy.DurabilityMath)
local SkillTreeCatalog = require(ReplicatedStorage.Shared.Progression.SkillTreeCatalog)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)

local BunkerStationService = {}

local function findItemInPlayerStorage(
	profile: PlayerDataService.PlayerProfile,
	uid: string
): (LootRoller.ItemInstance?, GridContainer.GridData?, string?)
	for _, slotName in ipairs(GridContainer.PaperdollSlots) do
		local eq = profile.paperdoll[slotName]
		if eq and eq.uid == uid then
			return eq, nil, slotName
		end
	end
	for _, g in ipairs({ profile.backpack, profile.stash, profile.secureCase }) do
		if g.entries[uid] then
			return g.entries[uid].item, g, nil
		end
	end
	return nil, nil, nil
end

function BunkerStationService.deployToZone(player: Player, zoneId: string)
	local profile = PlayerDataService.get(player)
	local zone = WorldZones.Zones[zoneId]
	if not profile or not zone then
		return
	end
	if profile.inRaid then
		PlayerDataService.notify(player, "Already deployed on the Wasteland surface!", "warn")
		return
	end

	profile.inRaid = true
	profile.currentZoneId = zone.id
	profile.openContainerId = nil
	PlayerDataService.recomputeStats(profile)
	DamageMath.fullRestore(profile.vitality)

	-- Top off weapon magazines on fresh deployment from Bastion Bunker
	for _, slotKey in ipairs({ "Primary1", "Primary2" }) do
		local rt = profile.weaponRuntime[slotKey]
		if rt then
			rt.ammo = rt.maxAmmo
			rt.heat = 0
			rt.overheatedUntil = 0
			rt.reloadingUntil = 0
		end
	end

	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(zone.dropSpawn.x, zone.dropSpawn.y, zone.dropSpawn.z))
	end

	PlayerDataService.notify(player, "Deployed to " .. zone.name .. " — Reach an Extraction Beacon to bank loot!", "info")
	LootContainerService.syncPlayer(player)
end

function BunkerStationService.handleAction(player: Player, payload: { [string]: any })
	local profile = PlayerDataService.get(player)
	if not profile or type(payload) ~= "table" then
		return
	end

	-- Surface deployment can be triggered from Bunker Airlocks or UI Deploy Map while in Bunker
	if payload.action == "DeployZone" then
		BunkerStationService.deployToZone(player, tostring(payload.zoneId or "Zone1"))
		return
	end

	-- Raider Tech Tree unlocks can be invested anytime (including mid-raid upon leveling up!)
	if payload.action == "UnlockSkill" then
		local skillId = tostring(payload.skillId or "")
		local node = SkillTreeCatalog.ById[skillId]
		if node then
			local curRank = profile.skills[skillId] or 0
			local avail = SkillTreeCatalog.getAvailablePoints(profile.level, profile.skills)
			if curRank >= node.maxRank then
				PlayerDataService.notify(player, node.name .. " is already at MAX Rank!", "warn")
			elseif avail <= 0 then
				PlayerDataService.notify(player, "Level up to earn more Bastion Tech Points!", "warn")
			else
				profile.skills[skillId] = curRank + 1
				PlayerDataService.recomputeStats(profile)
				PlayerDataService.notify(
					player,
					string.format("Tech Upgraded: %s [Rank %d/%d]", node.name, curRank + 1, node.maxRank),
					"success"
				)
				LootContainerService.syncPlayer(player)
			end
		end
		return
	end

	if profile.inRaid then
		PlayerDataService.notify(player, "Bunker stations are only accessible inside Bastion Bunker!", "warn")
		return
	end

	local action = payload.action

	if action == "RepairAllEquipped" then
		local totalCost = 0
		local itemsToRepair: { LootRoller.ItemInstance } = {}
		for _, slotName in ipairs(GridContainer.PaperdollSlots) do
			local eq = profile.paperdoll[slotName]
			if eq then
				local c = DurabilityMath.getRepairCost(eq)
				if c > 0 then
					totalCost += c
					table.insert(itemsToRepair, eq)
				end
			end
		end
		if #itemsToRepair == 0 then
			PlayerDataService.notify(player, "All equipped gear is already at 100% durability.", "info")
			return
		end
		if profile.scrap < totalCost then
			PlayerDataService.notify(player, string.format("Need %d Scrap to repair all (have %d).", totalCost, profile.scrap), "error")
			return
		end
		profile.scrap -= totalCost
		for _, eq in ipairs(itemsToRepair) do
			eq.durability = eq.maxDurability
		end
		PlayerDataService.recomputeStats(profile)
		PlayerDataService.notify(player, string.format("Repaired %d equipped items (-%d Scrap).", #itemsToRepair, totalCost), "success")

	elseif action == "RepairItem" then
		local uid = tostring(payload.uid or "")
		local item, _, _ = findItemInPlayerStorage(profile, uid)
		if item then
			local cost = DurabilityMath.getRepairCost(item)
			if cost <= 0 then
				PlayerDataService.notify(player, item.name .. " is already fully repaired.", "info")
			elseif profile.scrap < cost then
				PlayerDataService.notify(player, string.format("Need %d Scrap to repair.", cost), "error")
			else
				profile.scrap -= cost
				item.durability = item.maxDurability
				PlayerDataService.recomputeStats(profile)
				PlayerDataService.notify(player, "Repaired " .. item.name .. "!", "success")
			end
		end

	elseif action == "SalvageItem" then
		local uid = tostring(payload.uid or "")
		local item, grid, slotName = findItemInPlayerStorage(profile, uid)
		if item and grid and not slotName then
			local yield = DurabilityMath.getSalvageYield(item)
			GridContainer.remove(grid, uid)
			profile.scrap += yield.scrap
			profile.credits += yield.credits
			PlayerDataService.notify(
				player,
				string.format("Salvaged %s (+%d Scrap, +%d Credits)", item.name, yield.scrap, yield.credits),
				"success"
			)
		elseif slotName then
			PlayerDataService.notify(player, "Unequip item before salvaging!", "warn")
		end

	elseif action == "SalvageBackpackCommons" then
		local count = 0
		local gainScrap = 0
		local gainCredits = 0
		for _, entry in ipairs(GridContainer.listItems(profile.backpack)) do
			local itm = entry.item
			if itm.rarity == "Common" and itm.category ~= "Consumable" and itm.category ~= "Quest" then
				local yield = DurabilityMath.getSalvageYield(itm)
				GridContainer.remove(profile.backpack, itm.uid)
				gainScrap += yield.scrap
				gainCredits += yield.credits
				count += 1
			elseif itm.baseId == "ScrapBundle" then
				gainScrap += itm.stack
				GridContainer.remove(profile.backpack, itm.uid)
				count += 1
			end
		end
		if count > 0 then
			profile.scrap += gainScrap
			profile.credits += gainCredits
			PlayerDataService.notify(
				player,
				string.format("Bulk salvaged %d items (+%d Scrap, +%d Credits)", count, gainScrap, gainCredits),
				"success"
			)
		else
			PlayerDataService.notify(player, "No Common gear or Scrap bundles in Backpack to salvage.", "info")
		end

	elseif action == "RerollAffixes" then
		local uid = tostring(payload.uid or "")
		local item, _, _ = findItemInPlayerStorage(profile, uid)
		if item then
			local cost = DurabilityMath.getRerollCost(item)
			if profile.scrap < cost then
				PlayerDataService.notify(player, string.format("Need %d Scrap to reroll affixes.", cost), "error")
			elseif LootRoller.rerollAffixes(item, profile.rng) then
				profile.scrap -= cost
				PlayerDataService.recomputeStats(profile)
				PlayerDataService.notify(player, "Reforged affixes: " .. item.name, "success")
			else
				PlayerDataService.notify(player, "This item type cannot have affixes reforged.", "warn")
			end
		end

	elseif action == "BuyVendor" then
		local offerId = tostring(payload.offerId or "")
		local foundOffer = nil
		for _, offer in ipairs(DurabilityMath.VendorCatalog) do
			if offer.id == offerId then
				foundOffer = offer
				break
			end
		end
		if foundOffer then
			if profile.credits < foundOffer.costCredits then
				PlayerDataService.notify(player, "Insufficient Credits!", "error")
			else
				local bought = LootRoller.createSpecificItem(
					foundOffer.baseId,
					foundOffer.rarity,
					math.max(foundOffer.ilvl, profile.level),
					foundOffer.stack,
					profile.rng:nextU32()
				)
				local placed = GridContainer.autoPlace(profile.backpack, bought)
					or GridContainer.autoPlace(profile.stash, bought)
				if not placed then
					PlayerDataService.notify(player, "Backpack & Stash grids are full!", "error")
				else
					profile.credits -= foundOffer.costCredits
					PlayerDataService.notify(player, "Purchased " .. bought.name, "success")
				end
			end
		end

	elseif action == "AcceptContract" then
		local cid = tostring(payload.contractId or "")
		local st = profile.contracts[cid]
		if st then
			st.accepted = true
			PlayerDataService.notify(player, "Contract accepted!", "info")
		end

	elseif action == "ClaimContract" then
		local cid = tostring(payload.contractId or "")
		local st = profile.contracts[cid]
		local cDef: DurabilityMath.ContractDef? = nil
		for _, d in ipairs(DurabilityMath.Contracts) do
			if d.id == cid then
				cDef = d
				break
			end
		end
		if st and cDef and st.accepted and st.progress >= cDef.goal then
			st.progress = 0
			st.claimedCount += 1
			profile.scrap += cDef.rewardScrap
			profile.credits += cDef.rewardCredits
			PlayerDataService.grantXp(profile, cDef.rewardXp)

			if cDef.rewardBaseId then
				local rewardItem = LootRoller.createSpecificItem(
					cDef.rewardBaseId,
					cDef.rewardRarity or "Rare",
					cDef.rewardIlvl or 8,
					1,
					profile.rng:nextU32()
				)
				if not GridContainer.autoPlace(profile.backpack, rewardItem) then
					GridContainer.autoPlace(profile.stash, rewardItem)
				end
			end
			PlayerDataService.notify(
				player,
				string.format("Contract Claimed: +%d Scrap, +%d Credits!", cDef.rewardScrap, cDef.rewardCredits),
				"success"
			)
		end

	elseif action == "ResetSkills" then
		table.clear(profile.skills)
		PlayerDataService.recomputeStats(profile)
		PlayerDataService.notify(player, "Bastion Tech Points refunded!", "info")
	end

	LootContainerService.syncPlayer(player)
end

return BunkerStationService
