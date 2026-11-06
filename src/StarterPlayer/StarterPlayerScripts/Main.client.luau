--!strict
-- Client entry point for ASHFALL: Bastion Protocol.
-- TEMPLATE RULE #3 ENFORCED: Builds the entire GameHud & LayoutActor interface FIRST before
-- awaiting server remotes, and uses explicit timeouts on every WaitForChild!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local player = Players.LocalPlayer

-- 1. Build stamp: proves in-game which commit is running.
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local tagOk, tagModule = pcall(function()
	return require(sharedFolder:WaitForChild("BuildTag", 10))
end)
local tag = if tagOk and type(tagModule) == "table" then tostring(tagModule.tag) else "dev"

local Config = require(sharedFolder:WaitForChild("Config", 10))
local RemotesSchema = require(sharedFolder:WaitForChild("Net", 10):WaitForChild("RemotesSchema", 10))

-- 2. Client modules live strictly in ReplicatedStorage.ClientModules (Template Rule #1).
local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
local Hud = require(clientModules:WaitForChild("Hud", 10))
local SoundController = require(clientModules:WaitForChild("Audio", 10):WaitForChild("SoundController", 10))
local ClientStore = require(clientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))
local CombatHudActor = require(clientModules:WaitForChild("UI", 10):WaitForChild("CombatHudActor", 10))
local InventoryLayoutActor = require(clientModules:WaitForChild("UI", 10):WaitForChild("InventoryLayoutActor", 10))
local RaidSummaryActor = require(clientModules:WaitForChild("UI", 10):WaitForChild("RaidSummaryActor", 10))
local TouchControlsActor = require(clientModules:WaitForChild("UI", 10):WaitForChild("TouchControlsActor", 10))
local CameraDirector = require(clientModules:WaitForChild("Camera", 10):WaitForChild("CameraDirector", 10))
local MovementController = require(clientModules:WaitForChild("Controllers", 10):WaitForChild("MovementController", 10))
local WeaponClientController = require(clientModules:WaitForChild("Controllers", 10):WaitForChild("WeaponClientController", 10))
local ProceduralAnimator = require(clientModules:WaitForChild("Controllers", 10):WaitForChild("ProceduralAnimator", 10))

-- 3. Render interface BEFORE awaiting server remotes!
local playerGui = player:WaitForChild("PlayerGui", 10)
local screen = Hud.build(playerGui, Config.displayName)

local status = Hud.label(screen, "BUILD " .. tag, UDim2.fromOffset(220, 20), UDim2.fromOffset(16, 42))
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextSize = 12

ScriptContext.Error:Connect(function(message)
	status.Text = "ERROR: " .. tostring(message)
	status.TextColor3 = Color3.fromRGB(255, 130, 130)
end)

-- Outgoing intent bridge (queues/ignores gracefully until Remotes resolve)
local resolvedRemotes: Folder? = nil
local function sendServerIntent(remoteName: string, payload: { [string]: any })
	if not resolvedRemotes then
		return
	end
	local ev = resolvedRemotes:FindFirstChild(remoteName)
	if ev and ev:IsA("RemoteEvent") then
		ev:FireServer(payload)
	end
end

local combatHud = CombatHudActor.create(screen)
local inventoryUi = InventoryLayoutActor.create(screen, sendServerIntent)
local raidSummaryUi = RaidSummaryActor.create(screen)

local cameraCtrl = CameraDirector.start(function(adsActive: boolean)
	sendServerIntent(RemotesSchema.events.TacticalMove, { ads = adsActive })
end)

local moveCtrl = MovementController.start(function(movePayload: { [string]: any })
	sendServerIntent(RemotesSchema.events.TacticalMove, movePayload)
end)

local weaponCtrl = WeaponClientController.start({
	sendAction = sendServerIntent,
	getAimRay = cameraCtrl.getAimRay,
	rotateHeldItem = inventoryUi.rotateHeldItem,
})

local procAnim = ProceduralAnimator.start()

local touchUi = TouchControlsActor.create(screen, {
	setTriggerHeld = weaponCtrl.setTriggerHeld,
	toggleAds = function()
		cameraCtrl.setAds(not ClientStore.ui.adsActive)
	end,
	triggerMelee = weaponCtrl.triggerMelee,
	triggerDodge = moveCtrl.triggerDodge,
	triggerReload = weaponCtrl.triggerReload,
	triggerSwap = weaponCtrl.triggerSwap,
	triggerOrdnance = weaponCtrl.triggerOrdnance,
	triggerInteract = weaponCtrl.triggerInteract,
	toggleInventory = weaponCtrl.toggleInventory,
})

RunService.RenderStepped:Connect(function(dt: number)
	local clampedDt = math.min(dt, 0.1)
	cameraCtrl.step(clampedDt)
	weaponCtrl.step(clampedDt)
	procAnim.step(clampedDt)
	combatHud.actor:update(clampedDt)
	inventoryUi.actor:update(clampedDt)
	raidSummaryUi.actor:update(clampedDt)
	touchUi.actor:update(clampedDt)

	local lookXZ, pPos = cameraCtrl.getCameraLookXZ()
	combatHud.updateRadarHeading(lookXZ, pPos)
end)

print("[game] client: HUD built (" .. tag .. ")")

-- 4. Bounded remote wait (Template Rule #3: never freeze silently if server failed to boot)
local remotes = ReplicatedStorage:WaitForChild(RemotesSchema.folderName, 15)
if not remotes then
	status.Text = "SERVER NOT READY — no Remotes folder. Check Output."
	return
end
resolvedRemotes = remotes

local function bindClientEvent(name: string, fn: (any) -> ())
	local ev = remotes:WaitForChild(name, 10)
	if ev and ev:IsA("RemoteEvent") then
		ev.OnClientEvent:Connect(fn)
	end
end

bindClientEvent(RemotesSchema.events.StateSnapshot, function(payload)
	if type(payload) == "table" then
		ClientStore.applySnapshot(payload)
	end
end)

bindClientEvent(RemotesSchema.events.WorldState, function(payload)
	if type(payload) == "table" then
		ClientStore.applyWorldState(payload)
	end
end)

bindClientEvent(RemotesSchema.events.CombatFeedback, function(payload)
	if type(payload) == "table" then
		if payload.kind == "Hitmarker" then
			combatHud.flashHitmarker(payload)
		elseif payload.kind == "IncomingHit" then
			combatHud.flashIncomingHit(payload)
		else
			weaponCtrl.renderFeedback(payload)
		end
	end
end)

bindClientEvent(RemotesSchema.events.Notification, function(payload)
	if type(payload) == "table" and type(payload.message) == "string" then
		if payload.tone == "error" then
			SoundController.playError()
		elseif payload.tone == "success" then
			SoundController.playLootChime(false)
		end
		combatHud.showToast(payload.message, payload.tone)
	end
end)

bindClientEvent(RemotesSchema.events.RaidSummary, function(payload)
	if type(payload) == "table" then
		if payload.extracted then
			SoundController.playLootChime(true)
		else
			SoundController.playError()
		end
		raidSummaryUi.presentSummary(payload)
	end
end)

print("[game] client: ready")
