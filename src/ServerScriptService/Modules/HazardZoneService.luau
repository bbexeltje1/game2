--!strict
-- Clean-room S.T.A.L.K.E.R. (`OpenXRay` `Artefact.cpp` & Anomaly Zone) Service.
-- Manages:
--   1. Static Radiation & Bio-Spore Hazard Zones (mitigated by `hazardResist` affixes & Relics)
--   2. Dynamic lingering Corrosive Acid Pools lobbed by `SporeHazmat` enemies
--   3. Harvestable Anomaly Relic Nodes inside Hazard Zones (high-risk/high-reward Relic farming!)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local LootRoller = require(ReplicatedStorage.Shared.Loot.LootRoller)
local GridContainer = require(ReplicatedStorage.Shared.Inventory.GridContainer)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)

export type AcidPool = {
	position: Vector3,
	radius: number,
	dps: number,
	expiresAt: number,
	part: Part,
}

export type AnomalyRecord = {
	id: string,
	position: Vector3,
	relicPool: { string },
	respawnSec: number,
	available: boolean,
	respawnAt: number,
	model: Model,
}

local acidPools: { AcidPool } = {}
local anomalies: { [string]: AnomalyRecord } = {}
local hazardsFolder: Folder? = nil
local anomalyRng = Rng.new(31415926)
local tickAccum = 0

local HazardZoneService = {}

local function setAnomalyVisual(rec: AnomalyRecord, active: boolean)
	local crystal = rec.model:FindFirstChild("CrystalCore") :: BasePart?
	if crystal then
		crystal.Transparency = if active then 0.05 else 0.85
	end
	local bb = rec.model:FindFirstChild("AnomalyLabel")
	local lbl = if bb then bb:FindFirstChild("StatusText") :: TextLabel? else nil
	if lbl then
		lbl.Text = if active then "★ ANOMALY RELIC [E] HARVEST" else "ANOMALY DEPLETED (Reforming...)"
		lbl.TextColor3 = if active then Color3.fromRGB(205, 145, 255) else Color3.fromRGB(130, 136, 150)
	end
end

function HazardZoneService.init(worldRoot: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "HazardsAndAnomalies"
	folder.Parent = worldRoot
	hazardsFolder = folder

	for _, spec in ipairs(WorldZones.AnomalyNodes) do
		local pos = Vector3.new(spec.pos.x, spec.pos.y, spec.pos.z)
		local model = PrefabBuilder.buildAnomalyNode(spec.id, pos)
		model:SetAttribute("AnomalyId", spec.id)
		model:SetAttribute("Available", true)
		model.Parent = folder

		anomalies[spec.id] = {
			id = spec.id,
			position = pos,
			relicPool = spec.relicPool,
			respawnSec = spec.respawnSec,
			available = true,
			respawnAt = 0,
			model = model,
		}
	end
end

function HazardZoneService.spawnAcidPool(pos: Vector3, radius: number, dps: number, durationSec: number)
	if not hazardsFolder then
		return
	end
	local p = Instance.new("Part")
	p.Name = "CorrosiveSporePool"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.35, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos.X, math.max(0.25, pos.Y), pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(125, 245, 85)
	p.Transparency = 0.55
	p.Parent = hazardsFolder

	table.insert(acidPools, {
		position = pos,
		radius = radius,
		dps = dps,
		expiresAt = os.clock() + durationSec,
		part = p,
	})
end

function HazardZoneService.harvestAnomaly(player: Player, anomalyId: string)
	local profile = PlayerDataService.get(player)
	local rec = anomalies[anomalyId]
	if not profile or not rec then
		return
	end
	if not rec.available then
		PlayerDataService.notify(player, "This anomaly is still reforming!", "warn")
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root and (root.Position - rec.position).Magnitude > 18 then
		PlayerDataService.notify(player, "Move closer to harvest the Anomaly Relic.", "warn")
		return
	end

	local baseId = rec.relicPool[anomalyRng:nextInt(1, #rec.relicPool)]
	local rarityRoll = anomalyRng:nextFloat() + (profile.aggregatedStats.rarityFind or 0) * 0.25
	local rarity: "Rare" | "Epic" | "Legendary" = if rarityRoll > 0.90
		then "Legendary"
		elseif rarityRoll > 0.55 then "Epic"
		else "Rare"

	local relicItem = LootRoller.createSpecificItem(baseId, rarity, 18, 1, anomalyRng:nextU32())
	if not GridContainer.autoPlace(profile.backpack, relicItem) then
		LootContainerService.spawnWorldDrop(relicItem, rec.position + Vector3.new(0, 1, 0))
		PlayerDataService.notify(player, "Backpack full — Anomaly Relic dropped beside pedestal!", "warn")
	else
		PlayerDataService.notify(player, "Harvested " .. relicItem.name .. " (" .. rarity .. ")!", "success")
	end

	rec.available = false
	rec.respawnAt = os.clock() + rec.respawnSec
	rec.model:SetAttribute("Available", false)
	setAnomalyVisual(rec, false)
	LootContainerService.syncPlayer(player)
end

function HazardZoneService.tick(
	dt: number,
	damagePlayerCb: (Player, DamageMath.DamagePacket, Vector3?) -> ()
)
	local now = os.clock()

	-- Cleanup expired acid pools
	for idx = #acidPools, 1, -1 do
		local pool = acidPools[idx]
		if now >= pool.expiresAt then
			if pool.part then
				pool.part:Destroy()
			end
			table.remove(acidPools, idx)
		end
	end

	-- Respawn depleted Anomaly Relic nodes
	for _, rec in pairs(anomalies) do
		if not rec.available and rec.respawnAt > 0 and now >= rec.respawnAt then
			rec.available = true
			rec.respawnAt = 0
			rec.model:SetAttribute("Available", true)
			setAnomalyVisual(rec, true)
		end
	end

	tickAccum += dt
	if tickAccum < 0.5 then
		return
	end
	tickAccum = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataService.get(player)
		if profile and profile.inRaid and not profile.vitality.dead then
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if root then
				for _, hz in ipairs(WorldZones.HazardZones) do
					local hPos = Vector3.new(hz.position.x, root.Position.Y, hz.position.z)
					if (root.Position - hPos).Magnitude <= hz.radius then
						damagePlayerCb(player, {
							amount = hz.dps * 0.5,
							damageType = "Hazard",
							sourceId = hz.id,
						}, nil)
					end
				end

				for _, pool in ipairs(acidPools) do
					local pPos = Vector3.new(pool.position.X, root.Position.Y, pool.position.Z)
					if (root.Position - pPos).Magnitude <= pool.radius then
						damagePlayerCb(player, {
							amount = pool.dps * 0.5,
							damageType = "Corrosive",
							sourceId = "AcidPool",
						}, nil)
					end
				end
			end
		end
	end
end

return HazardZoneService
