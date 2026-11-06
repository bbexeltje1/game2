--!strict
-- Mobile & Tablet Tactical Touch Action Pad (`TouchControlsActor`).
-- Automatically displays on touch devices (`UserInputService.TouchEnabled == true`) and hides
-- cleanly on desktop Keyboard/Mouse or when modals are open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
local LayoutActor = require(ClientModules:WaitForChild("Core", 10):WaitForChild("LayoutActor", 10))
local Theme = require(ClientModules:WaitForChild("UI", 10):WaitForChild("Theme", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local TouchControlsActor = {}

export type TouchActions = {
	setTriggerHeld: (held: boolean) -> (),
	toggleAds: () -> (),
	triggerMelee: () -> (),
	triggerDodge: () -> (),
	triggerReload: () -> (),
	triggerSwap: () -> (),
	triggerOrdnance: () -> (),
	triggerInteract: () -> (),
	toggleInventory: () -> (),
}

function TouchControlsActor.create(screenGui: ScreenGui, actions: TouchActions): {
	actor: LayoutActor.LayoutActorObj,
}
	local isTouch = UserInputService.TouchEnabled == true
	local root = Theme.frame(
		screenGui,
		"TouchControlsHud",
		UDim2.fromOffset(250, 210),
		UDim2.new(1, -264, 1, -365),
		Theme.bgRoot,
		1
	)
	local actor = LayoutActor.new("TouchControlsHud", root, isTouch)

	local function makePadBtn(name: string, label: string, size: UDim2, pos: UDim2, accent: Color3): TextButton
		local btn = Theme.button(root, name, label, size, pos, Theme.bgPanel, accent, 11)
		btn.BackgroundTransparency = 0.25
		Theme.addCorner(btn, 24)
		Theme.addStroke(btn, accent, 1.4, 0.25)
		return btn
	end

	local fireBtn = makePadBtn("TouchFireBtn", "FIRE", UDim2.fromOffset(74, 74), UDim2.fromOffset(164, 96), Theme.scrapAmber)
	local adsBtn = makePadBtn("TouchAdsBtn", "ADS", UDim2.fromOffset(54, 54), UDim2.fromOffset(98, 108), Theme.shieldCyan)
	local meleeBtn = makePadBtn("TouchMeleeBtn", "MELEE", UDim2.fromOffset(54, 54), UDim2.fromOffset(108, 44), Theme.healthRed)
	local dodgeBtn = makePadBtn("TouchDodgeBtn", "DODGE", UDim2.fromOffset(54, 54), UDim2.fromOffset(36, 118), Theme.positiveGreen)
	local reloadBtn = makePadBtn("TouchReloadBtn", "RLD", UDim2.fromOffset(48, 44), UDim2.fromOffset(180, 42), Theme.textPrimary)
	local swapBtn = makePadBtn("TouchSwapBtn", "SWAP", UDim2.fromOffset(52, 38), UDim2.fromOffset(122, 0), Theme.textSecondary)
	local ordBtn = makePadBtn("TouchOrdBtn", "EMP", UDim2.fromOffset(50, 38), UDim2.fromOffset(64, 0), Theme.plasmaViolet)
	local useBtn = makePadBtn("TouchUseBtn", "USE", UDim2.fromOffset(56, 44), UDim2.fromOffset(38, 56), Theme.shieldCyan)
	local bagBtn = makePadBtn("TouchBagBtn", "BAG", UDim2.fromOffset(52, 38), UDim2.fromOffset(184, 0), Theme.scrapAmber)

	local fireToggled = false
	fireBtn.MouseButton1Click:Connect(function()
		fireToggled = not fireToggled
		actions.setTriggerHeld(fireToggled)
		fireBtn.BackgroundColor3 = if fireToggled then Color3.fromRGB(92, 58, 28) else Theme.bgPanel
	end)
	adsBtn.MouseButton1Click:Connect(actions.toggleAds)
	meleeBtn.MouseButton1Click:Connect(actions.triggerMelee)
	dodgeBtn.MouseButton1Click:Connect(actions.triggerDodge)
	reloadBtn.MouseButton1Click:Connect(actions.triggerReload)
	swapBtn.MouseButton1Click:Connect(actions.triggerSwap)
	ordBtn.MouseButton1Click:Connect(actions.triggerOrdnance)
	useBtn.MouseButton1Click:Connect(actions.triggerInteract)
	bagBtn.MouseButton1Click:Connect(actions.toggleInventory)

	local function refreshVisibility()
		local touchActive = (UserInputService.TouchEnabled == true)
		local modalOpen = ClientStore.ui.inventoryOpen or (ClientStore.ui.raidSummary ~= nil)
		if touchActive and not modalOpen then
			actor:appear()
		else
			if fireToggled then
				fireToggled = false
				actions.setTriggerHeld(false)
			end
			actor:disappear()
		end
	end

	ClientStore.subscribe(refreshVisibility)
	refreshVisibility()

	return {
		actor = actor,
	}
end

return TouchControlsActor
