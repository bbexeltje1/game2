--!strict
-- Client Weapon, Input & Contextual World Interaction Controller.
--
-- Handles:
--   • [LMB] Auto / 3-Round Burst / Semi / Scattergun / Launcher firing + Reticle Bloom
--   • [R] Reload / Plasma Heat Vent (or Rotate Item 90° when [TAB] Inventory is open!)
--   • [1] / [2] Active Weapon Swap, [Q] Ordnance Throw, [G] Cycle EMP/Frag, [3-6] Belt Consumables
--   • [TAB] Toggle Tactical 2D Grid Inventory & Bunker Station Suite
--   • [E] Contextual World Interact (Crates, Vaults, Ground Drops, Beacons, Bunker Stations, Ally Revive)
--   • 3D Visual Tracers, EMP Shockwaves & Sniper Laser Telegraphs

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local Config = require(Shared:WaitForChild("Config", 10))
local WeaponCatalog = require(Shared:WaitForChild("Weapons", 10):WaitForChild("WeaponCatalog", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

export type InteractTarget = {
	promptText: string,
	execute: () -> (),
}

local WeaponClientController = {}

function WeaponClientController.start(deps: {
	sendAction: (remoteName: string, payload: { [string]: any }) -> (),
	getAimRay: () -> (Vector3, Vector3),
	rotateHeldItem: () -> (),
}): {
	step: (dt: number) -> (),
	renderFeedback: (eventData: { [string]: any }) -> (),
}
	local player = Players.LocalPlayer
	local triggerHeld = false
	local nextClientShotAt = 0
	local currentInteract: InteractTarget? = nil

	local function fireSingleRound()
		local snap = ClientStore.snapshot
		local activeItem = snap.paperdoll[snap.activeWeaponSlot]
		if not activeItem then
			return
		end
		local wStats = WeaponCatalog.computeStats(activeItem, snap.stats)
		local origin, dir = deps.getAimRay()
		deps.sendAction("WeaponFire", {
			origin = origin,
			direction = dir,
		})
		ClientStore.ui.reticleBloom = math.min(1.5, ClientStore.ui.reticleBloom + 0.28)
		nextClientShotAt = os.clock() + wStats.shotInterval
	end

	local function scanNearestInteractable(): InteractTarget?
		local okChar, char = pcall(function()
			return player.Character
		end)
		if not okChar or not char then
			return nil
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return nil
		end
		local pPos = root.Position
		local maxDist = Config.hud.interactRangeStuds

		-- 1. Downed Co-op Teammate Priority!
		for _, sq in ipairs(ClientStore.world.squad) do
			if sq.userId ~= player.UserId and sq.downed then
				local sPos = Vector3.new(sq.x, sq.y, sq.z)
				if (sPos - pPos).Magnitude <= (maxDist + 3) then
					return {
						promptText = "[E] REVIVE TEAMMATE " .. tostring(sq.name),
						execute = function()
							deps.sendAction("InteractWorld", { kind = "ReviveAlly", userId = sq.userId })
						end,
					}
				end
			end
		end

		local worldFolder = Workspace:FindFirstChild("AshfallWorld")
		if not worldFolder then
			return nil
		end

		local bestDist = maxDist
		local bestTarget: InteractTarget? = nil

		-- 2. Dropped World Loot Parcels
		local dropsFolder = worldFolder:FindFirstChild("WorldDrops")
		if dropsFolder then
			for _, dropModel in ipairs(dropsFolder:GetChildren()) do
				local prim = if dropModel:IsA("Model") then dropModel.PrimaryPart else nil
				local dropId = dropModel:GetAttribute("DropId")
				if prim and type(dropId) == "string" then
					local d = (prim.Position - pPos).Magnitude
					if d <= bestDist then
						bestDist = d
						local bb = dropModel:FindFirstChild("LootLabel")
						local lbl = if bb then bb:FindFirstChildOfClass("TextLabel") else nil
						local itemName = if lbl then lbl.Text else "ITEM"
						bestTarget = {
							promptText = "[E] LOOT " .. itemName,
							execute = function()
								deps.sendAction("InteractWorld", { kind = "PickupDrop", id = dropId })
							end,
						}
					end
				end
			end
		end

		-- 3. Extraction Beacons
		local beaconsFolder = worldFolder:FindFirstChild("ExtractionBeacons")
		if beaconsFolder then
			for _, bModel in ipairs(beaconsFolder:GetChildren()) do
				local prim = if bModel:IsA("Model") then bModel.PrimaryPart else nil
				local beaconId = bModel:GetAttribute("BeaconId")
				if prim and type(beaconId) == "string" then
					local d = (prim.Position - pPos).Magnitude
					if d <= 20 then
						bestDist = math.min(bestDist, d)
						bestTarget = {
							promptText = "[E] ACTIVATE " .. bModel.Name,
							execute = function()
								deps.sendAction("InteractWorld", { kind = "TriggerExtraction", id = beaconId })
							end,
						}
					end
				end
			end
		end

		-- 4. World Loot Containers & Locked Keycard Vaults
		local containersFolder = worldFolder:FindFirstChild("Containers")
		if containersFolder then
			for _, cModel in ipairs(containersFolder:GetChildren()) do
				local prim = if cModel:IsA("Model") then cModel.PrimaryPart else nil
				local cid = cModel:GetAttribute("ContainerId")
				if prim and type(cid) == "string" then
					local d = (prim.Position - pPos).Magnitude
					if d <= bestDist then
						bestDist = d
						local locked = (cModel:GetAttribute("Locked") == true)
						bestTarget = {
							promptText = if locked
								then "[E] UNLOCK ARMORY VAULT (Requires Keycard)"
								else "[E] SEARCH LOOT CONTAINER",
							execute = function()
								deps.sendAction("InteractWorld", { kind = "OpenCrate", id = cid })
							end,
						}
					end
				end
			end
		end

		-- 5. Bastion Bunker Stations (Stash, Workbench, Vendor, Contracts, Zone 1–4 Airlocks)
		local bunkerFolder = worldFolder:FindFirstChild("BastionBunker")
		if bunkerFolder then
			for _, inst in ipairs(bunkerFolder:GetChildren()) do
				if inst:IsA("BasePart") then
					local kind = inst:GetAttribute("StationKind")
					if type(kind) == "string" then
						local d = (inst.Position - pPos).Magnitude
						if d <= (maxDist + 2) then
							bestDist = d
							local deployZone = inst:GetAttribute("DeployZoneId")
							if kind == "Deploy" and type(deployZone) == "string" then
								bestTarget = {
									promptText = "[E] DEPLOY SURFACE -> " .. deployZone,
									execute = function()
										deps.sendAction("InteractWorld", { kind = "DeployZone", zoneId = deployZone })
									end,
								}
							else
								local tabMap: { [string]: string } = {
									Stash = "Stash",
									Workbench = "Workbench",
									Vendor = "Vendor",
									Contracts = "Contracts",
								}
								local targetTab = tabMap[kind] or "Stash"
								bestTarget = {
									promptText = "[E] OPEN " .. string.upper(kind),
									execute = function()
										ClientStore.ui.rightTab = targetTab
										ClientStore.ui.inventoryOpen = true
										ClientStore.notify()
									end,
								}
							end
						end
					end
				end
			end
		end

		return bestTarget
	end

	UserInputService.InputBegan:Connect(function(input: any, gameProcessed: boolean)
		if input.KeyCode == Enum.KeyCode.Tab then
			ClientStore.ui.inventoryOpen = not ClientStore.ui.inventoryOpen
			ClientStore.ui.heldItem = nil
			if not ClientStore.ui.inventoryOpen and ClientStore.snapshot.openContainer then
				deps.sendAction("InventoryAction", { action = "CloseContainer" })
			end
			ClientStore.notify()
			return
		end

		if ClientStore.ui.inventoryOpen then
			if input.KeyCode == Enum.KeyCode.R then
				deps.rotateHeldItem()
			end
			return
		end

		if gameProcessed or ClientStore.ui.raidSummary ~= nil then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerHeld = true
			if os.clock() >= nextClientShotAt then
				local activeItem = ClientStore.snapshot.paperdoll[ClientStore.snapshot.activeWeaponSlot]
				local wDef = if activeItem then WeaponCatalog.get(activeItem.baseId) else nil
				if wDef and wDef.fireMode == "Burst3" then
					task.spawn(function()
						for b = 1, 3 do
							fireSingleRound()
							if b < 3 then
								task.wait(0.065)
							end
						end
					end)
				else
					fireSingleRound()
				end
			end

		elseif input.KeyCode == Enum.KeyCode.One then
			deps.sendAction("WeaponAction", { action = "SwapSlot", slot = "Primary1" })
		elseif input.KeyCode == Enum.KeyCode.Two then
			deps.sendAction("WeaponAction", { action = "SwapSlot", slot = "Primary2" })
		elseif input.KeyCode == Enum.KeyCode.R then
			deps.sendAction("WeaponAction", { action = "ReloadOrVent" })
		elseif input.KeyCode == Enum.KeyCode.Q then
			local origin, dir = deps.getAimRay()
			deps.sendAction("WeaponAction", {
				action = "ThrowOrdnance",
				targetPos = origin + dir * 32,
			})
		elseif input.KeyCode == Enum.KeyCode.G then
			deps.sendAction("WeaponAction", { action = "ToggleOrdnanceType" })
		elseif input.KeyCode == Enum.KeyCode.Three then
			deps.sendAction("InventoryAction", { action = "UseBelt", beltIndex = 1 })
		elseif input.KeyCode == Enum.KeyCode.Four then
			deps.sendAction("InventoryAction", { action = "UseBelt", beltIndex = 2 })
		elseif input.KeyCode == Enum.KeyCode.Five then
			deps.sendAction("InventoryAction", { action = "UseBelt", beltIndex = 3 })
		elseif input.KeyCode == Enum.KeyCode.Six then
			deps.sendAction("InventoryAction", { action = "UseBelt", beltIndex = 4 })
		elseif input.KeyCode == Enum.KeyCode.E then
			if currentInteract then
				currentInteract.execute()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: any)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerHeld = false
		end
	end)

	local promptScanAccum = 0
	local function step(dt: number)
		ClientStore.ui.reticleBloom = math.max(0, ClientStore.ui.reticleBloom - dt * 2.4)

		-- Full-auto sustained fire
		if triggerHeld and not ClientStore.ui.inventoryOpen and ClientStore.ui.raidSummary == nil then
			local activeItem = ClientStore.snapshot.paperdoll[ClientStore.snapshot.activeWeaponSlot]
			local wDef = if activeItem then WeaponCatalog.get(activeItem.baseId) else nil
			if wDef and wDef.fireMode == "Auto" and os.clock() >= nextClientShotAt then
				fireSingleRound()
			end
		end

		promptScanAccum += dt
		if promptScanAccum >= 0.15 then
			promptScanAccum = 0
			currentInteract = scanNearestInteractable()
			local nextText = if currentInteract then currentInteract.promptText else nil
			if nextText ~= ClientStore.ui.interactPrompt then
				ClientStore.ui.interactPrompt = nextText
				ClientStore.notify()
			end
		end
	end

	-- Procedural graybox visual tracers, sniper telegraphs & EMP blasts!
	local function renderFeedback(ev: { [string]: any })
		if ev.kind == "Tracer" or ev.kind == "SniperLock" then
			local p0 = ev.from :: Vector3
			local p1 = ev.to :: Vector3
			local seg = p1 - p0
			local dist = seg.Magnitude
			if dist > 0.2 then
				local beam = Instance.new("Part")
				beam.Name = "VisualTracer"
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.Material = Enum.Material.Neon
				beam.Size = if ev.kind == "SniperLock"
					then Vector3.new(0.14, 0.14, dist)
					else Vector3.new(0.10, 0.10, dist)
				beam.Color = if ev.kind == "SniperLock"
					then Color3.fromRGB(255, 58, 58)
					elseif ev.damageType == "Plasma" then Color3.fromRGB(72, 222, 255)
					elseif ev.damageType == "Corrosive" then Color3.fromRGB(132, 255, 92)
					else Color3.fromRGB(255, 222, 132)
				beam.Transparency = if ev.kind == "SniperLock" then 0.35 else 0.15
				beam.CFrame = CFrame.lookAt(p0 + seg * 0.5, p1)
				beam.Parent = Workspace
				Debris:AddItem(beam, if ev.kind == "SniperLock" then 0.85 else 0.08)
			end
		elseif ev.kind == "OrdnanceBlast" or ev.kind == "ShieldNova" or ev.kind == "BossSurge" then
			local sphere = Instance.new("Part")
			sphere.Name = "VisualBlast"
			sphere.Shape = Enum.PartType.Ball
			sphere.Anchored = true
			sphere.CanCollide = false
			sphere.CanQuery = false
			sphere.Material = Enum.Material.Neon
			local rad = tonumber(ev.radius) or 16
			sphere.Size = Vector3.new(rad * 1.6, rad * 1.6, rad * 1.6)
			sphere.Position = ev.position :: Vector3
			sphere.Color = if ev.damageType == "Plasma" or ev.kind == "ShieldNova"
				then Color3.fromRGB(72, 215, 255)
				else Color3.fromRGB(255, 148, 58)
			sphere.Transparency = 0.52
			sphere.Parent = Workspace
			Debris:AddItem(sphere, 0.25)
		end
	end

	return {
		step = step,
		renderFeedback = renderFeedback,
	}
end

return WeaponClientController
