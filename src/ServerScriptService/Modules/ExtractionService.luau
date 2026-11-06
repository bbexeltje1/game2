--!strict
-- Nintendo `Nerve`-driven Co-op PvE Extraction Beacon Service.
--
-- Each Beacon runs a deterministic 5-state Nerve sequence:
--   "Idle" -> "Charging" (Wave 1) -> "Surge" (Wave 2) -> "BoardingWindow" (Green Extract) -> "Cooldown"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nerve = require(ReplicatedStorage.Shared.Core.Nerve)
local DamageMath = require(ReplicatedStorage.Shared.Combat.DamageMath)
local GridContainer = require(ReplicatedStorage.Shared.Inventory.GridContainer)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)
local EnemyService = require(script.Parent.EnemyService)

export type BeaconInstance = {
	def: WorldZones.BeaconDef,
	position: Vector3,
	model: Model,
	nerve: Nerve.NerveKeeper<any>,
	timeRemaining: number,
}

local beacons: { [string]: BeaconInstance } = {}
local raidSummaryRemote: RemoteEvent? = nil

local ExtractionService = {}

local function countPlayersNear(pos: Vector3, radius: number): number
	local n = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataService.get(player)
		if profile and profile.inRaid and not profile.vitality.dead then
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if root and (root.Position - pos).Magnitude <= radius then
				n += 1
			end
		end
	end
	return math.max(1, n)
end

local function updateBeaconVisuals(b: BeaconInstance, state: string, labelText: string, color: Color3)
	local beam = b.model:FindFirstChild("SkyBeam") :: BasePart?
	local ring = b.model:FindFirstChild("ZoneRing") :: BasePart?
	if beam then
		beam.Color = color
		beam.Transparency = if state == "Idle" or state == "Cooldown" then 0.85 else 0.25
	end
	if ring then
		ring.Color = color
		ring.Transparency = if state == "BoardingWindow" then 0.45 else 0.78
	end
	local bb = b.model:FindFirstChild("BeaconBillboard")
	if bb then
		local lbl = bb:FindFirstChild("StatusLabel") :: TextLabel?
		if lbl then
			lbl.Text = labelText
			lbl.TextColor3 = color
		end
	end
end

local function extractPlayerSuccess(player: Player, beaconName: string)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.inRaid then
		return
	end

	local itemsExtracted = 0
	local totalValue = 0
	local scrapConverted = 0

	for _, entry in ipairs(GridContainer.listItems(profile.backpack)) do
		local itm = entry.item
		itemsExtracted += itm.stack
		totalValue += (itm.value * itm.stack)
		PlayerDataService.recordContractEvent(profile, "ExtractItem", itm.baseId, itm.stack)

		-- Automatically bank raw ScrapBundles into permanent workbench scrap!
		if itm.baseId == "ScrapBundle" then
			scrapConverted += itm.stack
			GridContainer.remove(profile.backpack, itm.uid)
		end
	end

	local bonusScrap = 25 + scrapConverted
	local bonusCredits = 65 + math.floor(totalValue * 0.25)
	local bonusXp = 110 + itemsExtracted * 15

	profile.scrap += bonusScrap
	profile.credits += bonusCredits
	profile.extractions += 1
	profile.inRaid = false
	profile.currentZoneId = "Bunker"
	profile.openContainerId = nil

	PlayerDataService.grantXp(profile, bonusXp)
	PlayerDataService.recordContractEvent(profile, "ExtractCount", "Any", 1)
	DamageMath.fullRestore(profile.vitality)

	-- Teleport survivor cleanly back to Bastion Bunker
	local char = player.Character
	if char then
		local sp = WorldZones.Bunker.spawn
		char:PivotTo(CFrame.new(sp.x, sp.y + 3, sp.z))
	end

	LootContainerService.syncPlayer(player)
	if raidSummaryRemote then
		raidSummaryRemote:FireClient(player, {
			outcome = "EXTRACTED",
			beaconName = beaconName,
			itemsExtracted = itemsExtracted,
			lootValue = totalValue,
			scrapEarned = bonusScrap,
			creditsEarned = bonusCredits,
			xpEarned = bonusXp,
		})
	end
end

local BEACON_NERVES: { [string]: Nerve.NerveHandler<BeaconInstance> } = {
	Idle = function(self, keeper, _dt)
		if keeper:isFirstStep() then
			self.timeRemaining = 0
			updateBeaconVisuals(self, "Idle", self.def.name .. "\n[E] CALL EXTRACTION", Color3.fromRGB(95, 215, 255))
		end
	end,

	Charging = function(self, keeper, _dt)
		local phaseDur = self.def.holdoutSeconds * 0.55
		if keeper:isFirstStep() then
			local coopCount = countPlayersNear(self.position, 140)
			EnemyService.spawnExtractionWave(self.position, self.def.waveArchetypes, coopCount)
		end
		local left = math.max(0, math.ceil(self.def.holdoutSeconds - keeper:getElapsed()))
		self.timeRemaining = left
		updateBeaconVisuals(
			self,
			"Charging",
			string.format("%s\nHOLDOUT WAVE 1 • %ds", self.def.name, left),
			Color3.fromRGB(255, 208, 74)
		)
		if keeper:isGreaterEqualTime(phaseDur) then
			keeper:setNerve("Surge")
		end
	end,

	Surge = function(self, keeper, _dt)
		local phaseDur = self.def.holdoutSeconds * 0.45
		if keeper:isFirstStep() then
			local coopCount = countPlayersNear(self.position, 140)
			EnemyService.spawnExtractionWave(self.position, self.def.waveArchetypes, coopCount)
		end
		local left = math.max(0, math.ceil(phaseDur - keeper:getElapsed()))
		self.timeRemaining = left
		updateBeaconVisuals(
			self,
			"Surge",
			string.format("%s\nFINAL SURGE • %ds", self.def.name, left),
			Color3.fromRGB(255, 132, 58)
		)
		if keeper:isGreaterEqualTime(phaseDur) then
			keeper:setNerve("BoardingWindow")
		end
	end,

	BoardingWindow = function(self, keeper, _dt)
		local left = math.max(0, math.ceil(self.def.boardingSeconds - keeper:getElapsed()))
		self.timeRemaining = left
		updateBeaconVisuals(
			self,
			"BoardingWindow",
			string.format("%s\nENTER GREEN ZONE TO EXTRACT! (%ds)", self.def.name, left),
			Color3.fromRGB(88, 245, 148)
		)

		-- Any living surface player stepping inside the green extraction pad extracts immediately!
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = PlayerDataService.get(player)
			if profile and profile.inRaid and not profile.vitality.dead then
				local char = player.Character
				local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if root and (root.Position - self.position).Magnitude <= self.def.radius then
					extractPlayerSuccess(player, self.def.name)
				end
			end
		end

		if keeper:isGreaterEqualTime(self.def.boardingSeconds) then
			keeper:setNerve("Cooldown")
		end
	end,

	Cooldown = function(self, keeper, _dt)
		local left = math.max(0, math.ceil(self.def.cooldownSeconds - keeper:getElapsed()))
		self.timeRemaining = left
		updateBeaconVisuals(
			self,
			"Cooldown",
			string.format("%s\nRECHARGING (%ds)", self.def.name, left),
			Color3.fromRGB(135, 142, 158)
		)
		if keeper:isGreaterEqualTime(self.def.cooldownSeconds) then
			keeper:setNerve("Idle")
		end
	end,
}

function ExtractionService.init(beaconsFolder: Folder, summaryRemote: RemoteEvent)
	raidSummaryRemote = summaryRemote

	for _, def in ipairs(WorldZones.ExtractionBeacons) do
		local pos = Vector3.new(def.position.x, def.position.y, def.position.z)
		local model = PrefabBuilder.buildExtractionBeacon(def.name, pos, def.radius)
		model:SetAttribute("BeaconId", def.id)
		model.Parent = beaconsFolder

		local inst: any = {
			def = def,
			position = pos,
			model = model,
			timeRemaining = 0,
		}
		inst.nerve = Nerve.new(inst, "Idle", BEACON_NERVES)
		beacons[def.id] = inst
	end
end

function ExtractionService.triggerBeacon(player: Player, beaconId: string)
	local profile = PlayerDataService.get(player)
	local b = beacons[beaconId]
	if not profile or not profile.inRaid or not b then
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root and (root.Position - b.position).Magnitude > (b.def.radius + 10) then
		PlayerDataService.notify(player, "Step onto the Extraction Pad to activate the beacon.", "warn")
		return
	end

	local state = b.nerve:getState()
	if state ~= "Idle" then
		PlayerDataService.notify(player, "Beacon is currently " .. state .. "!", "info")
		return
	end

	b.nerve:setNerve("Charging")
	for _, p in ipairs(Players:GetPlayers()) do
		PlayerDataService.notify(p, player.Name .. " activated " .. b.def.name .. " — Holdout started!", "warn")
	end
end

function ExtractionService.tick(dt: number)
	for _, b in pairs(beacons) do
		b.nerve:update(dt)
	end
end

function ExtractionService.buildBeaconSnapshots(): { { id: string, name: string, state: string, timer: number, x: number, y: number, z: number } }
	local out = {}
	for _, b in pairs(beacons) do
		table.insert(out, {
			id = b.def.id,
			name = b.def.name,
			state = b.nerve:getState(),
			timer = b.timeRemaining,
			x = b.position.X,
			y = b.position.Y,
			z = b.position.Z,
		})
	end
	return out
end

return ExtractionService
