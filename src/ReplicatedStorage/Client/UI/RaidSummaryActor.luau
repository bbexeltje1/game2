--!strict
-- Post-Raid Extraction Victory / Wasteland Wipe Durability Tax Summary Modal (`LayoutActor`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local LayoutActor = require(ClientModules:WaitForChild("Core", 10):WaitForChild("LayoutActor", 10))
local Theme = require(ClientModules:WaitForChild("UI", 10):WaitForChild("Theme", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local RaidSummaryActor = {}

function RaidSummaryActor.create(screenGui: ScreenGui): {
	actor: LayoutActor.LayoutActorObj,
	presentSummary: (summary: { [string]: any }) -> (),
}
	local card = Theme.frame(
		screenGui,
		"RaidSummaryModal",
		UDim2.fromOffset(460, 290),
		UDim2.new(0.5, -230, 0.5, -145),
		Theme.bgPanel,
		0.04
	)
	Theme.addCorner(card, 12)
	local border = Theme.addStroke(card, Theme.positiveGreen, 2, 0.1)

	local actor = LayoutActor.new("RaidSummaryModal", card, false)

	local title = Theme.label(
		card,
		"OutcomeTitle",
		"EXTRACTION SUCCESSFUL",
		UDim2.new(1, -24, 0, 36),
		UDim2.fromOffset(12, 16),
		Enum.Font.GothamBold,
		20,
		Theme.positiveGreen,
		Enum.TextXAlignment.Center
	)

	local body = Theme.label(
		card,
		"OutcomeDetails",
		"",
		UDim2.new(1, -36, 0, 155),
		UDim2.fromOffset(18, 62),
		Enum.Font.GothamMedium,
		13,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)
	body.TextWrapped = true

	local dismissBtn = Theme.button(
		card,
		"ContinueBtn",
		"RETURN TO BASTION BUNKER",
		UDim2.fromOffset(260, 40),
		UDim2.new(0.5, -130, 1, -56),
		Theme.bgElevated,
		Theme.shieldCyan,
		13
	)

	dismissBtn.MouseButton1Click:Connect(function()
		ClientStore.ui.raidSummary = nil
		actor:disappear()
		ClientStore.notify()
	end)

	local function presentSummary(summary: { [string]: any })
		ClientStore.ui.raidSummary = summary
		ClientStore.ui.inventoryOpen = false

		if summary.outcome == "EXTRACTED" then
			border.Color = Theme.positiveGreen
			title.Text = "★ EXTRACTION COMPLETE ★"
			title.TextColor3 = Theme.positiveGreen
			body.Text = string.format(
				"Extracted via %s\n\nItems Banked: %d  (Est. Value: %d CR)\nScrap Awarded: +%d   •   Credits Awarded: +%d\nExperience Gained: +%d XP",
				tostring(summary.beaconName or "Beacon"),
				tonumber(summary.itemsExtracted) or 0,
				tonumber(summary.lootValue) or 0,
				tonumber(summary.scrapEarned) or 0,
				tonumber(summary.creditsEarned) or 0,
				tonumber(summary.xpEarned) or 0
			)
		else
			border.Color = Theme.shieldWarning
			title.Text = "▲ WASTELAND WIPE — EMERGENCY RECALL ▲"
			title.TextColor3 = Theme.shieldWarning
			body.Text = string.format(
				"Equipped Paperdoll Gear & 2x2 Secure Case PRESERVED!\n\nUnextracted Backpack Items Dropped: %d\nDurability Tax Applied: -%d total pts across %d equipped slots\n\nVisit the Bunker Workbench to repair equipped gear with Scrap.",
				tonumber(summary.droppedCount) or 0,
				tonumber(summary.durabilityLost) or 0,
				tonumber(summary.affectedSlots) or 0
			)
		end

		actor:appear()
		ClientStore.notify()
	end

	return {
		actor = actor,
		presentSummary = presentSummary,
	}
end

return RaidSummaryActor
