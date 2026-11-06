--!strict
-- 3rd-Person Tactical Movement Controller:
--   • [LeftShift] Sprint
--   • [C] Tactical Slide
--   • [LeftAlt] Thruster Combat Dodge (with server i-frame sync)
--   • [Space] Ledge Mantle onto waist/chest-high graybox ruins

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local Config = require(Shared:WaitForChild("Config", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local MovementController = {}

function MovementController.start(sendTacticalMove: (payload: { [string]: any }) -> ()): {
	triggerDodge: () -> (),
	triggerSlide: () -> (),
}
	local player = Players.LocalPlayer
	local lastSlideAt = 0
	local lastDodgeAt = 0

	local function getRootAndHumanoid(): (BasePart?, Humanoid?, Model?)
		local ok, char = pcall(function()
			return player.Character
		end)
		if not ok or not char then
			return nil, nil, nil
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char:FindFirstChildOfClass("Humanoid")
		return root, hum, char
	end

	local function tryLedgeMantle()
		local root, hum, char = getRootAndHumanoid()
		if not root or not hum or not char then
			return
		end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char }

		local fwd = root.CFrame.LookVector
		-- Check obstacle directly ahead at waist/chest level, and clear air above head
		local chestHit = Workspace:Raycast(root.Position + Vector3.new(0, 0.8, 0), fwd * 4.2, rayParams)
		local headClear = Workspace:Raycast(root.Position + Vector3.new(0, Config.movement.mantleMaxHeight, 0), fwd * 4.6, rayParams)
		if chestHit and not headClear then
			local topProbe = chestHit.Position + fwd * 1.4 + Vector3.new(0, Config.movement.mantleMaxHeight, 0)
			local downHit = Workspace:Raycast(topProbe, Vector3.new(0, -Config.movement.mantleMaxHeight - 2, 0), rayParams)
			if downHit and (downHit.Position.Y - root.Position.Y) <= Config.movement.mantleMaxHeight then
				char:PivotTo(CFrame.new(downHit.Position + Vector3.new(0, 3.2, 0)) * root.CFrame.Rotation)
			end
		end
	end

	local function triggerSlide()
		local now = os.clock()
		if (now - lastSlideAt) >= Config.movement.slideCooldown then
			lastSlideAt = now
			local root, hum, _ = getRootAndHumanoid()
			if root and hum then
				local dir = if hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection.Unit else root.CFrame.LookVector
				root.AssemblyLinearVelocity = Vector3.new(
					dir.X * Config.movement.slideImpulse,
					root.AssemblyLinearVelocity.Y,
					dir.Z * Config.movement.slideImpulse
				)
				sendTacticalMove({ slide = true })
			end
		end
	end

	local function triggerDodge()
		local now = os.clock()
		if (now - lastDodgeAt) >= Config.movement.dodgeCooldown then
			lastDodgeAt = now
			local root, hum, _ = getRootAndHumanoid()
			if root and hum then
				local dir = if hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection.Unit else -root.CFrame.LookVector
				root.AssemblyLinearVelocity = Vector3.new(
					dir.X * Config.movement.dodgeImpulse,
					8,
					dir.Z * Config.movement.dodgeImpulse
				)
				sendTacticalMove({ dodge = true })
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input: any, gameProcessed: boolean)
		if gameProcessed or ClientStore.ui.inventoryOpen or ClientStore.ui.raidSummary ~= nil then
			return
		end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			ClientStore.ui.sprinting = true
			sendTacticalMove({ sprinting = true })

		elseif input.KeyCode == Enum.KeyCode.C then
			triggerSlide()

		elseif input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.ButtonB then
			triggerDodge()

		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			tryLedgeMantle()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: any)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			if ClientStore.ui.sprinting then
				ClientStore.ui.sprinting = false
				sendTacticalMove({ sprinting = false })
			end
		end
	end)

	return {
		triggerDodge = triggerDodge,
		triggerSlide = triggerSlide,
	}
end

return MovementController
