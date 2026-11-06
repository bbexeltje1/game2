--!strict
-- Clean-room Halo `director.c` + `observer.c` + Zelda: BotW Over-the-Shoulder 3rd-Person Camera.
--
-- Features:
--   • Mouse-locked over-the-shoulder framing in combat; unlocks automatically when [TAB] is open
--   • [V] Shoulder Swap (right <-> left shoulder)
--   • [RMB] Aim-Down-Sights (ADS) zoom using active weapon's `adsFov`
--   • Observer raycast collision pull-in so camera never clips inside Bunker walls or ruins

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local WeaponCatalog = require(Shared:WaitForChild("Weapons", 10):WaitForChild("WeaponCatalog", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local CameraDirector = {}

function CameraDirector.start(onAdsChanged: ((boolean) -> ())?): {
	getAimRay: () -> (Vector3, Vector3),
	getCameraLookXZ: () -> (Vector2, Vector3),
	setAds: (active: boolean) -> (),
	step: (dt: number) -> (),
}
	local player = Players.LocalPlayer
	local yaw = 0
	local pitch = -0.12
	local shoulderSide = 1 -- +1 right shoulder, -1 left shoulder
	local currentSide = 2.4
	local currentDist = 8.6
	local currentFov = 70
	local stickDelta = Vector2.new(0, 0)

	local function setAds(active: boolean)
		if active and (ClientStore.ui.inventoryOpen or ClientStore.ui.raidSummary ~= nil) then
			return
		end
		if ClientStore.ui.adsActive ~= active then
			ClientStore.ui.adsActive = active
			if onAdsChanged then
				onAdsChanged(active)
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input: any, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.DPadDown then
			shoulderSide = -shoulderSide
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAds(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: any)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAds(false)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stickDelta = Vector2.new(0, 0)
		end
	end)

	local okChanged, inputChangedSig = pcall(function()
		return (UserInputService :: any).InputChanged
	end)
	if okChanged and inputChangedSig then
		inputChangedSig:Connect(function(input: any)
			if ClientStore.ui.inventoryOpen or ClientStore.ui.raidSummary ~= nil then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local sens = if ClientStore.ui.adsActive then 0.0024 else 0.0038
				yaw -= input.Delta.X * sens
				pitch = math.clamp(pitch - input.Delta.Y * sens, -1.22, 1.05)
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local pos = input.Position
				local dx = if math.abs(pos.X) > 0.14 then pos.X else 0
				local dy = if math.abs(pos.Y) > 0.14 then pos.Y else 0
				stickDelta = Vector2.new(dx, dy)
			end
		end)
	end

	local function getCameraSafe(): Camera?
		local ok, cam = pcall(function()
			return Workspace.CurrentCamera
		end)
		if ok and cam then
			return cam
		end
		return nil
	end

	local function step(dt: number)
		local cam = getCameraSafe()
		if not cam then
			return
		end

		local menuOpen = ClientStore.ui.inventoryOpen or (ClientStore.ui.raidSummary ~= nil)
		if not menuOpen and (stickDelta.X ~= 0 or stickDelta.Y ~= 0) then
			local stickSens = if ClientStore.ui.adsActive then 1.65 else 2.65
			yaw -= stickDelta.X * stickSens * dt
			pitch = math.clamp(pitch + stickDelta.Y * stickSens * 0.8 * dt, -1.22, 1.05)
		end
		pcall(function()
			UserInputService.MouseBehavior = if menuOpen
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = menuOpen
		end)

		local okChar, char = pcall(function()
			return player.Character
		end)
		if not okChar or not char then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		cam.CameraType = Enum.CameraType.Scriptable

		local activeGun = ClientStore.snapshot.paperdoll[ClientStore.snapshot.activeWeaponSlot]
		local wDef = if activeGun then WeaponCatalog.get(activeGun.baseId) else nil
		local targetFov = if ClientStore.ui.adsActive
			then (if wDef then wDef.adsFov else 52)
			elseif ClientStore.ui.sprinting then 78
			else 70

		local targetSide = shoulderSide * (if ClientStore.ui.adsActive then 1.85 else 2.45)
		local targetDist = if ClientStore.ui.adsActive then 5.2 else 8.8
		local alpha = math.clamp(dt * 14, 0, 1)

		currentSide += (targetSide - currentSide) * alpha
		currentDist += (targetDist - currentDist) * alpha
		currentFov += (targetFov - currentFov) * alpha
		cam.FieldOfView = currentFov

		local neckPivot = root.Position + Vector3.new(0, 2.15, 0)
		local camRot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local desiredCamCf = CFrame.new(neckPivot) * camRot * CFrame.new(currentSide, 0.35, currentDist)
		local desiredPos = desiredCamCf.Position

		-- Halo `observer.c` wall-clipping prevention raycast
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char }
		local toCam = desiredPos - neckPivot
		local hit = Workspace:Raycast(neckPivot, toCam, rayParams)
		local finalPos = if hit
			then (neckPivot + toCam.Unit * math.max(1.2, (hit.Position - neckPivot).Magnitude - 0.65))
			else desiredPos

		cam.CFrame = CFrame.new(finalPos) * camRot

		-- Align character torso smoothly toward camera yaw when aiming or moving in combat
		if not menuOpen then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.AutoRotate = false
			end
			local lookFlat = (CFrame.Angles(0, yaw, 0)).LookVector
			root.CFrame = CFrame.lookAt(root.Position, root.Position + lookFlat)
		end
	end

	local function getAimRay(): (Vector3, Vector3)
		local cam = getCameraSafe()
		if not cam then
			return Vector3.zero, Vector3.new(0, 0, -1)
		end
		local camPos = cam.CFrame.Position
		local camLook = cam.CFrame.LookVector

		local okChar, char = pcall(function()
			return player.Character
		end)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = if okChar and char then { char } else {}

		local aimHit = Workspace:Raycast(camPos, camLook * 450, rayParams)
		local targetPoint = if aimHit then aimHit.Position else (camPos + camLook * 450)

		local muzzleOrigin = camPos + camLook * 2.0
		if okChar and char then
			local gun = char:FindFirstChild("EquippedGrayboxWeapon")
			local handle = if gun then gun:FindFirstChild("Handle") :: BasePart? else nil
			local muzzleAtt = if handle then handle:FindFirstChild("MuzzleAttachment") :: Attachment? else nil
			if muzzleAtt then
				muzzleOrigin = muzzleAtt.WorldPosition
			else
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					muzzleOrigin = root.Position + Vector3.new(0, 2.1, 0) + camLook * 1.4
				end
			end
		end

		local shotVec = targetPoint - muzzleOrigin
		local dir = if shotVec.Magnitude > 0.05 then shotVec.Unit else camLook
		return muzzleOrigin, dir
	end

	local function getCameraLookXZ(): (Vector2, Vector3)
		local cam = getCameraSafe()
		local look = if cam then cam.CFrame.LookVector else Vector3.new(0, 0, -1)
		local flatLen = math.sqrt(look.X * look.X + look.Z * look.Z)
		local flat2 = if flatLen > 0.01 then Vector2.new(look.X / flatLen, look.Z / flatLen) else Vector2.new(0, -1)

		local pPos = Vector3.zero
		local okChar, char = pcall(function()
			return player.Character
		end)
		if okChar and char then
			local r = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				pPos = r.Position
			end
		end
		return flat2, pPos
	end

	return {
		getAimRay = getAimRay,
		getCameraLookXZ = getCameraLookXZ,
		setAds = setAds,
		step = step,
	}
end

return CameraDirector
