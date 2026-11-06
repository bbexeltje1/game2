--!strict
-- Nintendo `sead` / Halo-inspired Procedural Spring Combat & World Prop Animator.
-- Runs 100% procedurally with zero external Roblox AnimationId asset dependencies so Studio
-- sessions never suffer third-party animation permission failures.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local ProceduralAnimator = {}

function ProceduralAnimator.start(): {
	step: (dt: number) -> (),
}
	local player = Players.LocalPlayer
	local phase = 0
	local baseRightShoulderC0: CFrame? = nil
	local trackedShoulder: Motor6D? = nil

	local function step(dt: number)
		phase += dt * 3.2
		ClientStore.ui.recoilKick = math.max(0, ClientStore.ui.recoilKick - dt * 6.5)
		ClientStore.ui.meleeSwing = math.max(0, ClientStore.ui.meleeSwing - dt * 4.5)

		-- 1. Procedural Character Right-Arm Recoil Kick, ADS Raise, Reload Tilt & Melee Thrust
		pcall(function()
			local char = player.Character
			if not char then
				return
			end
			local upperArm = char:FindFirstChild("RightUpperArm")
			local torso = char:FindFirstChild("Torso")
			local shoulder: Motor6D? = nil
			if upperArm then
				shoulder = upperArm:FindFirstChild("RightShoulder") :: Motor6D?
			elseif torso then
				shoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
			end

			if shoulder then
				if trackedShoulder ~= shoulder then
					trackedShoulder = shoulder
					baseRightShoulderC0 = shoulder.C0
				end
				if baseRightShoulderC0 then
					local rt = ClientStore.snapshot.weaponRuntime[ClientStore.snapshot.activeWeaponSlot]
					local reloading = (rt ~= nil and rt.isReloading == true)
					local adsLift = if ClientStore.ui.adsActive then 0.26 else 0.08
					local recoilPitch = ClientStore.ui.recoilKick * 0.24
					local meleePitch = ClientStore.ui.meleeSwing * 0.75
					local reloadRoll = if reloading then -0.48 else 0
					local breathe = math.sin(phase * 0.8) * 0.02

					shoulder.C0 = baseRightShoulderC0
						* CFrame.new(0, 0, ClientStore.ui.recoilKick * 0.14 - ClientStore.ui.meleeSwing * 0.35)
						* CFrame.Angles(adsLift + recoilPitch + meleePitch + breathe, 0, reloadRoll)
				end
			end
		end)

		-- 2. Levitate & Spin S.T.A.L.K.E.R. Anomaly Crystals in the World
		pcall(function()
			local worldRoot = Workspace:FindFirstChild("AshfallWorld")
			if not worldRoot then
				return
			end
			local anomalies = worldRoot:FindFirstChild("WorldAnomalies")
			if anomalies then
				for idx, aModel in ipairs(anomalies:GetChildren()) do
					local ped = if aModel:IsA("Model") then aModel.PrimaryPart else nil
					local core = aModel:FindFirstChild("CrystalCore") :: BasePart?
					if ped and core and core.Transparency < 0.8 then
						local bob = math.sin(phase + idx) * 0.35
						core.CFrame = CFrame.new(ped.Position + Vector3.new(0, 2.5 + bob, 0))
							* CFrame.Angles(math.rad(20), phase * 0.9 + idx, math.rad(14))
					end
				end
			end
		end)
	end

	return {
		step = step,
	}
end

return ProceduralAnimator
