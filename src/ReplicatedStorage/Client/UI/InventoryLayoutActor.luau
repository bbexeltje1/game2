--!strict
-- Interactive Diablo (`DevilutionX` `inv.cpp`) + Tarkov 2D Spatial Grid Inventory, RPG Paperdoll,
-- 2x2 Secure Case, BotW Comparison Tooltip & Bastion Bunker Station Suite (`[TAB]`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local AffixCatalog = require(Shared:WaitForChild("Loot", 10):WaitForChild("AffixCatalog", 10))
local LootRoller = require(Shared:WaitForChild("Loot", 10):WaitForChild("LootRoller", 10))
local GridContainer = require(Shared:WaitForChild("Inventory", 10):WaitForChild("GridContainer", 10))
local DurabilityMath = require(Shared:WaitForChild("Economy", 10):WaitForChild("DurabilityMath", 10))
local SkillTreeCatalog = require(Shared:WaitForChild("Progression", 10):WaitForChild("SkillTreeCatalog", 10))
local LayoutActor = require(ClientModules:WaitForChild("Core", 10):WaitForChild("LayoutActor", 10))
local SoundController = require(ClientModules:WaitForChild("Audio", 10):WaitForChild("SoundController", 10))
local Theme = require(ClientModules:WaitForChild("UI", 10):WaitForChild("Theme", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local CELL_PX = 31
local STASH_CELL_PX = 25

local InventoryLayoutActor = {}

export type ActionSender = (remoteName: string, payload: { [string]: any }) -> ()

function InventoryLayoutActor.create(screenGui: ScreenGui, sendAction: ActionSender): {
	actor: LayoutActor.LayoutActorObj,
	rotateHeldItem: () -> (),
}
	local modal = Theme.frame(
		screenGui,
		"TacticalInventoryModal",
		UDim2.fromOffset(1040, 580),
		UDim2.new(0.5, -520, 0.5, -290),
		Theme.bgRoot,
		0.05
	)
	Theme.addCorner(modal, 10)
	Theme.addStroke(modal, Theme.borderBright, 1.5, 0.25)

	local actor = LayoutActor.new("TacticalInventoryModal", modal, false)

	-- Top Header Bar
	local header = Theme.frame(modal, "Header", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 0), Theme.bgPanel, 0)
	Theme.addCorner(header, 10)
	Theme.label(
		header,
		"Title",
		"TACTICAL LOADOUT & 2D GRID INVENTORY",
		UDim2.fromOffset(380, 40),
		UDim2.fromOffset(16, 0),
		Enum.Font.GothamBold,
		14,
		Theme.shieldCyan,
		Enum.TextXAlignment.Left
	)
	local heldStatusLbl = Theme.label(
		header,
		"HeldItemBanner",
		"Click item to move  •  [R] Rotate  •  [SHIFT+CLICK] Quick-Transfer",
		UDim2.fromOffset(470, 40),
		UDim2.fromOffset(390, 0),
		Enum.Font.GothamMedium,
		11,
		Theme.scrapAmber,
		Enum.TextXAlignment.Center
	)
	local closeBtn = Theme.button(
		header,
		"CloseBtn",
		"CLOSE [TAB]",
		UDim2.fromOffset(104, 28),
		UDim2.new(1, -114, 0, 6),
		Theme.bgElevated,
		Theme.textPrimary,
		11
	)
	closeBtn.MouseButton1Click:Connect(function()
		ClientStore.ui.inventoryOpen = false
		ClientStore.ui.heldItem = nil
		if ClientStore.snapshot.openContainer then
			sendAction("InventoryAction", { action = "CloseContainer" })
		end
		ClientStore.notify()
	end)

	-- =========================================================================
	-- LEFT COLUMN (265px): CHARACTER PAPERDOLL + BELT + AGGREGATED STATS
	-- =========================================================================
	local leftCol = Theme.frame(modal, "LeftPaperdollCol", UDim2.fromOffset(265, 524), UDim2.fromOffset(12, 48), Theme.bgPanel, 0)
	Theme.addCorner(leftCol, 8)
	Theme.addStroke(leftCol, Theme.borderSubtle, 1, 0.35)

	Theme.label(
		leftCol,
		"ColHeader",
		"EQUIPPED PAPERDOLL (KEPT ON DEATH)",
		UDim2.new(1, -16, 0, 22),
		UDim2.fromOffset(10, 6),
		Enum.Font.GothamBold,
		11,
		Theme.positiveGreen
	)

	local slotButtons: { [string]: TextButton } = {}
	local slotDefs = {
		{ key = "Primary1", label = "[1] PRIMARY WEAPON" },
		{ key = "Primary2", label = "[2] SECONDARY WEAPON" },
		{ key = "ShieldCore", label = "HALO SHIELD CORE" },
		{ key = "Head", label = "HEAD / VISOR" },
		{ key = "Chest", label = "CHEST RIG" },
		{ key = "Legs", label = "THRUSTER GREAVES" },
		{ key = "Relic1", label = "ANOMALY RELIC I" },
		{ key = "Relic2", label = "ANOMALY RELIC II" },
	}

	for idx, sDef in ipairs(slotDefs) do
		local btn = Theme.button(
			leftCol,
			"Slot_" .. sDef.key,
			sDef.label .. ": Empty",
			UDim2.new(1, -16, 0, 34),
			UDim2.fromOffset(8, 30 + (idx - 1) * 38),
			Theme.bgSlot,
			Theme.textSecondary,
			11
		)
		Theme.addStroke(btn, Theme.borderSubtle, 1, 0.35)
		slotButtons[sDef.key] = btn

		btn.MouseButton1Click:Connect(function()
			local held = ClientStore.ui.heldItem
			if held then
				sendAction("InventoryAction", {
					action = "EquipFromGrid",
					srcGrid = held.srcGrid,
					uid = held.uid,
					slot = sDef.key,
				})
				ClientStore.ui.heldItem = nil
			else
				local eq = ClientStore.snapshot.paperdoll[sDef.key]
				if eq then
					ClientStore.ui.selectedItem = { item = eq, srcGrid = nil }
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						sendAction("InventoryAction", {
							action = "UnequipToGrid",
							slot = sDef.key,
							dstGrid = "Backpack",
						})
					end
					ClientStore.notify()
				end
			end
		end)

		btn.MouseEnter:Connect(function()
			local eq = ClientStore.snapshot.paperdoll[sDef.key]
			if eq then
				ClientStore.ui.selectedItem = { item = eq, srcGrid = nil }
				ClientStore.notify()
			end
		end)
	end

	-- Belt equip buttons [3..6]
	for bIdx = 1, 4 do
		local bBtn = Theme.button(
			leftCol,
			"EquipBelt_" .. tostring(bIdx),
			string.format("[%d] Belt", bIdx + 2),
			UDim2.fromOffset(58, 28),
			UDim2.fromOffset(8 + (bIdx - 1) * 63, 338),
			Theme.bgSlot,
			Theme.textSecondary,
			10
		)
		slotButtons["Belt" .. tostring(bIdx)] = bBtn
		bBtn.MouseButton1Click:Connect(function()
			local held = ClientStore.ui.heldItem
			if held then
				sendAction("InventoryAction", {
					action = "EquipBeltFromGrid",
					srcGrid = held.srcGrid,
					uid = held.uid,
					beltIndex = bIdx,
				})
				ClientStore.ui.heldItem = nil
			else
				sendAction("InventoryAction", { action = "UseBelt", beltIndex = bIdx })
			end
		end)
	end

	local statsReadout = Theme.label(
		leftCol,
		"AggregatedStats",
		"",
		UDim2.new(1, -16, 0, 144),
		UDim2.fromOffset(8, 372),
		Enum.Font.GothamMedium,
		11,
		Theme.textSecondary,
		Enum.TextXAlignment.Left
	)
	statsReadout.TextYAlignment = Enum.TextYAlignment.Top
	statsReadout.TextWrapped = true

	-- =========================================================================
	-- CENTER COLUMN (352px): 10x5 RAID BACKPACK + 2x2 SECURE CASE + TOOLTIP
	-- =========================================================================
	local centerCol = Theme.frame(modal, "CenterGridCol", UDim2.fromOffset(352, 524), UDim2.fromOffset(285, 48), Theme.bgPanel, 0)
	Theme.addCorner(centerCol, 8)
	Theme.addStroke(centerCol, Theme.borderSubtle, 1, 0.35)

	Theme.label(
		centerCol,
		"BackpackTitle",
		"RAID BACKPACK [10x5]",
		UDim2.fromOffset(175, 22),
		UDim2.fromOffset(10, 6),
		Enum.Font.GothamBold,
		11,
		Theme.scrapAmber
	)

	local sortBackpackBtn = Theme.button(
		centerCol,
		"AutoSortBackpackBtn",
		"AUTO-SORT",
		UDim2.fromOffset(76, 22),
		UDim2.new(1, -172, 0, 6),
		Theme.bgElevated,
		Theme.positiveGreen,
		10
	)
	sortBackpackBtn.MouseButton1Click:Connect(function()
		SoundController.playUiClick()
		sendAction("InventoryAction", { action = "CompactSort", gridName = "Backpack" })
	end)

	local rotateBtn = Theme.button(
		centerCol,
		"RotateBtn",
		"ROTATE [R]",
		UDim2.fromOffset(82, 22),
		UDim2.new(1, -90, 0, 6),
		Theme.bgElevated,
		Theme.shieldCyan,
		10
	)

	-- Helper to build an interactive 2D Spatial Grid Widget (`Backpack`, `SecureCase`, `Stash`, `Crate`)
	local function createGridWidget(
		parent: Instance,
		gridName: string,
		cols: number,
		rows: number,
		cellSize: number,
		pos: UDim2
	): {
		container: Frame,
		cells: { [number]: TextButton },
		itemsLayer: Frame,
		render: (serializedGrid: { [string]: any }?) -> (),
	}
		local wPx = cols * cellSize
		local hPx = rows * cellSize
		local wrap = Theme.frame(parent, "Grid_" .. gridName, UDim2.fromOffset(wPx, hPx), pos, Theme.bgCellEmpty, 0)
		Theme.addStroke(wrap, Theme.borderSubtle, 1, 0.25)

		local cells: { [number]: TextButton } = {}
		local hoverX: number? = nil
		local hoverY: number? = nil

		local itemsLayer = Theme.frame(wrap, "ItemsLayer", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.bgRoot, 1)
		itemsLayer.ZIndex = 4

		local currentGridData = GridContainer.new(cols, rows)

		local function refreshHoverHighlight()
			local held = ClientStore.ui.heldItem
			for y = 1, rows do
				for x = 1, cols do
					local idx = (y - 1) * cols + x
					local btn = cells[idx]
					btn.BackgroundColor3 = Theme.bgCellEmpty
				end
			end
			if held and hoverX and hoverY then
				local fakeItem: any = table.clone(held.item)
				local check = GridContainer.inspectFootprint(
					currentGridData,
					fakeItem,
					hoverX,
					hoverY,
					held.rotated,
					if held.srcGrid == gridName then held.uid else nil
				)
				local iw, ih = GridContainer.getDimensions(fakeItem, held.rotated)
				local valid = check.inBounds and (#check.blockerUids <= 1)
				local highlightCol = if valid then Theme.bgCellValid else Theme.bgCellInvalid
				for dy = 0, ih - 1 do
					for dx = 0, iw - 1 do
						local tx, ty = hoverX + dx, hoverY + dy
						if tx >= 1 and tx <= cols and ty >= 1 and ty <= rows then
							cells[(ty - 1) * cols + tx].BackgroundColor3 = highlightCol
						end
					end
				end
			end
		end

		for y = 1, rows do
			for x = 1, cols do
				local idx = (y - 1) * cols + x
				local cellBtn = Instance.new("TextButton")
				cellBtn.Name = string.format("C_%d_%d", x, y)
				cellBtn.Size = UDim2.fromOffset(cellSize - 1, cellSize - 1)
				cellBtn.Position = UDim2.fromOffset((x - 1) * cellSize, (y - 1) * cellSize)
				cellBtn.BackgroundColor3 = Theme.bgCellEmpty
				cellBtn.BorderSizePixel = 0
				cellBtn.Text = ""
				cellBtn.AutoButtonColor = false
				cellBtn.ZIndex = 2
				cellBtn.Parent = wrap
				cells[idx] = cellBtn

				cellBtn.MouseEnter:Connect(function()
					hoverX, hoverY = x, y
					refreshHoverHighlight()
				end)
				cellBtn.MouseLeave:Connect(function()
					if hoverX == x and hoverY == y then
						hoverX, hoverY = nil, nil
						refreshHoverHighlight()
					end
				end)
				cellBtn.MouseButton1Click:Connect(function()
					local held = ClientStore.ui.heldItem
					if held then
						sendAction("InventoryAction", {
							action = "MoveGrid",
							srcGrid = held.srcGrid,
							dstGrid = gridName,
							uid = held.uid,
							x = x,
							y = y,
							rotated = held.rotated,
						})
						ClientStore.ui.heldItem = nil
						ClientStore.notify()
					end
				end)
			end
		end

		local function render(serializedGrid: { [string]: any }?)
			for _, child in ipairs(itemsLayer:GetChildren()) do
				child:Destroy()
			end
			if not serializedGrid then
				return
			end
			currentGridData = GridContainer.deserialize(serializedGrid)

			for _, entry in ipairs(serializedGrid.list or {}) do
				local item = entry.item
				local iw = if item.rotated then item.gridH else item.gridW
				local ih = if item.rotated then item.gridW else item.gridH
				local rCol = Theme.rarityColor(item.rarity)

				local card = Instance.new("TextButton")
				card.Name = "Item_" .. tostring(item.uid)
				card.Size = UDim2.fromOffset(iw * cellSize - 3, ih * cellSize - 3)
				card.Position = UDim2.fromOffset((entry.x - 1) * cellSize + 1, (entry.y - 1) * cellSize + 1)
				card.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
				card.BorderSizePixel = 0
				card.Text = ""
				card.ZIndex = 5
				card.Parent = itemsLayer
				Theme.addCorner(card, 4)
				Theme.addStroke(card, rCol, 1.5, 0.1)

				local shortName = string.sub(item.name, 1, math.max(6, iw * 6))
				local title = Theme.label(
					card,
					"Title",
					shortName,
					UDim2.new(1, -6, 0, 14),
					UDim2.fromOffset(3, 2),
					Enum.Font.GothamBold,
					9,
					rCol,
					Enum.TextXAlignment.Left
				)
				title.ZIndex = 6
				title.TextTruncate = Enum.TextTruncate.AtEnd

				local meta = if (item.stack or 1) > 1
					then ("x" .. tostring(item.stack))
					else ("L" .. tostring(item.ilvl or 1))
				local badge = Theme.label(
					card,
					"Badge",
					meta,
					UDim2.new(1, -6, 0, 12),
					UDim2.new(0, 3, 1, -14),
					Enum.Font.GothamBold,
					9,
					Theme.textSecondary,
					Enum.TextXAlignment.Right
				)
				badge.ZIndex = 6

				card.MouseEnter:Connect(function()
					ClientStore.ui.selectedItem = { item = item, srcGrid = gridName }
					hoverX, hoverY = entry.x, entry.y
					refreshHoverHighlight()
					ClientStore.notify()
				end)

				card.MouseButton1Click:Connect(function()
					SoundController.playUiClick()
					local held = ClientStore.ui.heldItem
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						sendAction("InventoryAction", {
							action = "QuickTransfer",
							srcGrid = gridName,
							uid = item.uid,
						})
						return
					end
					if held then
						-- Drop/swap onto this occupied item's origin cell
						sendAction("InventoryAction", {
							action = "MoveGrid",
							srcGrid = held.srcGrid,
							dstGrid = gridName,
							uid = held.uid,
							x = entry.x,
							y = entry.y,
							rotated = held.rotated,
						})
						ClientStore.ui.heldItem = nil
					else
						ClientStore.ui.heldItem = {
							srcGrid = gridName,
							uid = item.uid,
							item = item,
							rotated = (item.rotated == true),
						}
						ClientStore.ui.selectedItem = { item = item, srcGrid = gridName }
					end
					ClientStore.notify()
				end)

				-- Right-Click: Quick-Equip/Belt from Backpack, or Quick-Transfer from Crate/Stash!
				card.MouseButton2Click:Connect(function()
					SoundController.playUiClick()
					ClientStore.ui.heldItem = nil
					if gridName == "Backpack" then
						sendAction("InventoryAction", {
							action = "AutoEquipOrUse",
							srcGrid = "Backpack",
							uid = item.uid,
						})
					else
						sendAction("InventoryAction", {
							action = "QuickTransfer",
							srcGrid = gridName,
							uid = item.uid,
						})
					end
					ClientStore.notify()
				end)
			end
			refreshHoverHighlight()
		end

		return {
			container = wrap,
			cells = cells,
			itemsLayer = itemsLayer,
			render = render,
		}
	end

	local backpackWidget = createGridWidget(centerCol, "Backpack", 10, 5, CELL_PX, UDim2.fromOffset(21, 32))

	-- 2x2 Secure Case + Drop Button row
	Theme.label(
		centerCol,
		"SecureTitle",
		"SECURE CASE [2x2] (SAFE ON DEATH)",
		UDim2.fromOffset(220, 18),
		UDim2.fromOffset(21, 194),
		Enum.Font.GothamBold,
		10,
		Theme.shieldCyan
	)
	local secureWidget = createGridWidget(centerCol, "SecureCase", 2, 2, CELL_PX, UDim2.fromOffset(21, 214))

	local dropItemBtn = Theme.button(
		centerCol,
		"DropHeldBtn",
		"DROP SELECTED ON GROUND",
		UDim2.fromOffset(180, 28),
		UDim2.fromOffset(150, 218),
		Theme.bgElevated,
		Theme.negativeRed,
		10
	)
	dropItemBtn.MouseButton1Click:Connect(function()
		local sel = ClientStore.ui.selectedItem
		if sel and sel.srcGrid then
			sendAction("InventoryAction", {
				action = "DropFromGrid",
				srcGrid = sel.srcGrid,
				uid = sel.item.uid,
			})
			ClientStore.ui.heldItem = nil
			ClientStore.ui.selectedItem = nil
		end
	end)

	-- BotW-Inspired Item Inspector & Live Stat Delta Comparison Card
	local inspectorBox = Theme.frame(
		centerCol,
		"ItemComparisonCard",
		UDim2.new(1, -20, 0, 232),
		UDim2.fromOffset(10, 284),
		Theme.bgSlot,
		0
	)
	Theme.addCorner(inspectorBox, 6)
	local inspectorStroke = Theme.addStroke(inspectorBox, Theme.borderSubtle, 1.2, 0.2)

	local inspTitle = Theme.label(
		inspectorBox,
		"ItemTitle",
		"Hover or click any item to inspect & compare",
		UDim2.new(1, -16, 0, 22),
		UDim2.fromOffset(8, 6),
		Enum.Font.GothamBold,
		12,
		Theme.textPrimary
	)
	local inspMeta = Theme.label(
		inspectorBox,
		"ItemMeta",
		"",
		UDim2.new(1, -16, 0, 16),
		UDim2.fromOffset(8, 26),
		Enum.Font.GothamMedium,
		10,
		Theme.textSecondary
	)
	local inspBody = Theme.label(
		inspectorBox,
		"ItemAffixesAndDiff",
		"",
		UDim2.new(1, -16, 0, 180),
		UDim2.fromOffset(8, 44),
		Enum.Font.GothamMedium,
		11,
		Theme.textPrimary
	)
	inspBody.TextYAlignment = Enum.TextYAlignment.Top
	inspBody.TextWrapped = true

	-- =========================================================================
	-- RIGHT COLUMN (383px): CONTEXTUAL TABS (CRATE | STASH | BENCH | VENDOR | CONTRACTS | DEPLOY)
	-- =========================================================================
	local rightCol = Theme.frame(modal, "RightStationCol", UDim2.fromOffset(383, 524), UDim2.fromOffset(645, 48), Theme.bgPanel, 0)
	Theme.addCorner(rightCol, 8)
	Theme.addStroke(rightCol, Theme.borderSubtle, 1, 0.35)

	local tabNames = {
		{ id = "Stash", label = "STASH" },
		{ id = "Crate", label = "CRATE" },
		{ id = "Workbench", label = "BENCH" },
		{ id = "Vendor", label = "SHOP" },
		{ id = "Contracts", label = "BOUNTY" },
		{ id = "Tech", label = "TECH" },
		{ id = "Deploy", label = "DEPLOY" },
	}
	local tabButtons: { [string]: TextButton } = {}
	for i, t in ipairs(tabNames) do
		local tb = Theme.button(
			rightCol,
			"Tab_" .. t.id,
			t.label,
			UDim2.fromOffset(50, 26),
			UDim2.fromOffset(7 + (i - 1) * 53, 8),
			Theme.bgElevated,
			Theme.textSecondary,
			10
		)
		tabButtons[t.id] = tb
		tb.MouseButton1Click:Connect(function()
			ClientStore.ui.rightTab = t.id
			ClientStore.notify()
		end)
	end

	-- Tab Views
	local stashView = Theme.frame(rightCol, "StashView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	Theme.label(stashView, "Hdr", "PERSONAL STASH [10x12] (BUNKER)", UDim2.fromOffset(250, 20), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 11, Theme.shieldCyan)
	local sortStashBtn = Theme.button(
		stashView,
		"AutoSortStashBtn",
		"AUTO-SORT",
		UDim2.fromOffset(80, 20),
		UDim2.new(1, -84, 0, 0),
		Theme.bgElevated,
		Theme.positiveGreen,
		10
	)
	sortStashBtn.MouseButton1Click:Connect(function()
		SoundController.playUiClick()
		sendAction("InventoryAction", { action = "CompactSort", gridName = "Stash" })
	end)
	local stashWidget = createGridWidget(stashView, "Stash", 10, 12, STASH_CELL_PX, UDim2.fromOffset(58, 24))
	local stashRaidLockLbl = Theme.label(
		stashView,
		"RaidLockedNotice",
		"STASH LOCKED WHILE ON SURFACE — EXTRACT TO BANK LOOT!",
		UDim2.new(1, 0, 0, 40),
		UDim2.fromOffset(0, 340),
		Enum.Font.GothamBold,
		11,
		Theme.scrapAmber,
		Enum.TextXAlignment.Center
	)

	local crateView = Theme.frame(rightCol, "CrateView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	local crateTitleLbl = Theme.label(crateView, "CrateHdr", "WORLD LOOT CONTAINER [6x4]", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 11, Theme.positiveGreen)
	local crateWidget = createGridWidget(crateView, "Crate", 6, 4, CELL_PX + 4, UDim2.fromOffset(72, 34))

	local benchView = Theme.frame(rightCol, "BenchView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	Theme.label(benchView, "Hdr", "REPAIR, SALVAGE & AFFIX FORGE", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 12, Theme.scrapAmber)
	local repairAllBtn = Theme.button(benchView, "RepairAllBtn", "REPAIR ALL EQUIPPED GEAR", UDim2.new(1, -8, 0, 38), UDim2.fromOffset(4, 34), Color3.fromRGB(36, 98, 72), Theme.textPrimary, 12)
	local salvageCommonsBtn = Theme.button(benchView, "SalvageCommonsBtn", "BULK SALVAGE BACKPACK COMMONS & SCRAP", UDim2.new(1, -8, 0, 38), UDim2.fromOffset(4, 80), Theme.bgElevated, Theme.scrapAmber, 11)
	local repairSelBtn = Theme.button(benchView, "RepairSelBtn", "REPAIR SELECTED ITEM", UDim2.new(1, -8, 0, 36), UDim2.fromOffset(4, 140), Theme.bgElevated, Theme.positiveGreen, 11)
	local rerollSelBtn = Theme.button(benchView, "RerollSelBtn", "REFORGE SELECTED ITEM AFFIXES", UDim2.new(1, -8, 0, 36), UDim2.fromOffset(4, 184), Color3.fromRGB(72, 52, 118), Theme.textPrimary, 11)
	local salvageSelBtn = Theme.button(benchView, "SalvageSelBtn", "SALVAGE SELECTED UNEQUIPPED ITEM", UDim2.new(1, -8, 0, 36), UDim2.fromOffset(4, 228), Color3.fromRGB(98, 38, 44), Theme.textPrimary, 11)

	repairAllBtn.MouseButton1Click:Connect(function()
		sendAction("BunkerAction", { action = "RepairAllEquipped" })
	end)
	salvageCommonsBtn.MouseButton1Click:Connect(function()
		sendAction("BunkerAction", { action = "SalvageBackpackCommons" })
	end)
	repairSelBtn.MouseButton1Click:Connect(function()
		local sel = ClientStore.ui.selectedItem
		if sel and sel.item then
			sendAction("BunkerAction", { action = "RepairItem", uid = sel.item.uid })
		end
	end)
	rerollSelBtn.MouseButton1Click:Connect(function()
		local sel = ClientStore.ui.selectedItem
		if sel and sel.item then
			sendAction("BunkerAction", { action = "RerollAffixes", uid = sel.item.uid })
		end
	end)
	salvageSelBtn.MouseButton1Click:Connect(function()
		local sel = ClientStore.ui.selectedItem
		if sel and sel.item then
			sendAction("BunkerAction", { action = "SalvageItem", uid = sel.item.uid })
		end
	end)

	local vendorView = Theme.frame(rightCol, "VendorView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	Theme.label(vendorView, "Hdr", "QUARTERMASTER REQUISITIONS", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 12, Theme.creditMint)
	for i, offer in ipairs(DurabilityMath.VendorCatalog) do
		local base = AffixCatalog.BaseItems[offer.baseId]
		local bName = if base then base.name else offer.baseId
		local buyBtn = Theme.button(
			vendorView,
			"Vendor_" .. offer.id,
			string.format("%s (x%d)  —  %d CR", bName, offer.stack, offer.costCredits),
			UDim2.new(1, -8, 0, 32),
			UDim2.fromOffset(4, 28 + (i - 1) * 36),
			Theme.bgSlot,
			Theme.rarityColor(offer.rarity),
			11
		)
		buyBtn.MouseButton1Click:Connect(function()
			sendAction("BunkerAction", { action = "BuyVendor", offerId = offer.id })
		end)
	end

	local contractsView = Theme.frame(rightCol, "ContractsView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	Theme.label(contractsView, "Hdr", "WASTELAND PVE BOUNTY CONTRACTS", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 12, Theme.plasmaViolet)
	local contractButtons: { [string]: TextButton } = {}
	for i, cDef in ipairs(DurabilityMath.Contracts) do
		local cBtn = Theme.button(
			contractsView,
			"Contract_" .. cDef.id,
			cDef.title,
			UDim2.new(1, -8, 0, 68),
			UDim2.fromOffset(4, 26 + (i - 1) * 74),
			Theme.bgSlot,
			Theme.textPrimary,
			10
		)
		cBtn.TextWrapped = true
		contractButtons[cDef.id] = cBtn
		cBtn.MouseButton1Click:Connect(function()
			local st = ClientStore.snapshot.contracts[cDef.id]
			if st and st.accepted and st.progress >= cDef.goal then
				sendAction("BunkerAction", { action = "ClaimContract", contractId = cDef.id })
			elseif not st or not st.accepted then
				sendAction("BunkerAction", { action = "AcceptContract", contractId = cDef.id })
			end
		end)
	end

	local deployView = Theme.frame(rightCol, "DeployView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	Theme.label(deployView, "Hdr", "SURFACE AIRLOCK DEPLOYMENT", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(4, 0), Enum.Font.GothamBold, 12, Theme.positiveGreen)
	local deploySpecs = {
		{ zoneId = "Zone1", title = "DEPLOY ZONE 1: COLLAPSED OVERPASS\nTier I [ilvl 1–6] • Low Threat • Beacon Alpha" },
		{ zoneId = "Zone2", title = "DEPLOY ZONE 2: RUSTED RAIL YARD\nTier II [ilvl 7–14] • Snipers & Enforcers • Armory Vault" },
		{ zoneId = "Zone3", title = "DEPLOY ZONE 3: SPORE BIO-METRO\nTier III [ilvl 15–22] • Spore Hazard • High-Rarity Relics" },
		{ zoneId = "Zone4", title = "DEPLOY ZONE 4: SHATTERED REACTOR CRATER\nTier IV [ilvl 23–30] • WARDEN GOLIATH BOSS • Dropship Omega" },
	}
	for i, ds in ipairs(deploySpecs) do
		local dBtn = Theme.button(
			deployView,
			"Deploy_" .. ds.zoneId,
			ds.title,
			UDim2.new(1, -8, 0, 66),
			UDim2.fromOffset(4, 34 + (i - 1) * 76),
			Theme.bgElevated,
			Theme.shieldCyan,
			11
		)
		dBtn.MouseButton1Click:Connect(function()
			ClientStore.ui.inventoryOpen = false
			sendAction("BunkerAction", { action = "DeployZone", zoneId = ds.zoneId })
			ClientStore.notify()
		end)
	end

	-- Raider Progression Tech Tree View (`[TECH]`)
	local techView = Theme.frame(rightCol, "TechView", UDim2.new(1, -16, 1, -46), UDim2.fromOffset(8, 40), Theme.bgPanel, 1)
	local techHdrLbl = Theme.label(
		techView,
		"Hdr",
		"RAIDER SPECIALIZATION TECH (1 PT AVAILABLE)",
		UDim2.new(1, -8, 0, 22),
		UDim2.fromOffset(4, 0),
		Enum.Font.GothamBold,
		11,
		Theme.positiveGreen
	)
	local skillButtons: { [string]: TextButton } = {}
	for i, sNode in ipairs(SkillTreeCatalog.Nodes) do
		local sBtn = Theme.button(
			techView,
			"Skill_" .. sNode.id,
			sNode.name,
			UDim2.new(1, -8, 0, 62),
			UDim2.fromOffset(4, 26 + (i - 1) * 67),
			Theme.bgSlot,
			Theme.textPrimary,
			10
		)
		sBtn.TextWrapped = true
		skillButtons[sNode.id] = sBtn
		sBtn.MouseButton1Click:Connect(function()
			SoundController.playUiClick()
			sendAction("BunkerAction", { action = "UnlockSkill", skillId = sNode.id })
		end)
	end
	local resetTechBtn = Theme.button(
		techView,
		"ResetTechBtn",
		"REFUND ALL TECH POINTS (BUNKER)",
		UDim2.new(1, -8, 0, 32),
		UDim2.fromOffset(4, 434),
		Theme.bgElevated,
		Theme.scrapAmber,
		10
	)
	resetTechBtn.MouseButton1Click:Connect(function()
		SoundController.playUiClick()
		sendAction("BunkerAction", { action = "ResetSkills" })
	end)

	-- Floating Held-Item Cursor Ghost Card (`DevilutionX` / Tarkov spatial drag feel!)
	local heldGhost = Theme.frame(
		screenGui,
		"HeldItemGhost",
		UDim2.fromOffset(CELL_PX, CELL_PX),
		UDim2.fromOffset(0, 0),
		Color3.fromRGB(36, 48, 68),
		0.25
	)
	heldGhost.Visible = false
	heldGhost.ZIndex = 50
	Theme.addCorner(heldGhost, 4)
	local heldGhostStroke = Theme.addStroke(heldGhost, Theme.shieldCyan, 1.5, 0.05)
	local heldGhostLbl = Theme.label(
		heldGhost,
		"GhostName",
		"",
		UDim2.new(1, -6, 1, -4),
		UDim2.fromOffset(3, 2),
		Enum.Font.GothamBold,
		10,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)
	heldGhostLbl.ZIndex = 51
	heldGhostLbl.TextWrapped = true

	actor.onUpdate = function(_dt: number)
		local held = ClientStore.ui.heldItem
		if ClientStore.ui.inventoryOpen and held then
			local w = if held.rotated then held.item.gridH else held.item.gridW
			local h = if held.rotated then held.item.gridW else held.item.gridH
			heldGhost.Visible = true
			heldGhost.Size = UDim2.fromOffset(w * CELL_PX - 2, h * CELL_PX - 2)
			heldGhostStroke.Color = Theme.rarityColor(held.item.rarity)
			heldGhostLbl.Text = string.format("%s\n[%dx%d]", string.sub(held.item.name, 1, 14), w, h)
			pcall(function()
				local mousePos = UserInputService:GetMouseLocation()
				local scaleObj = screenGui:FindFirstChild("ResponsiveScale") :: UIScale?
				local invScale = if scaleObj and scaleObj.Scale > 0 then (1 / scaleObj.Scale) else 1
				heldGhost.Position = UDim2.fromOffset(
					math.floor(mousePos.X * invScale + 10),
					math.floor(mousePos.Y * invScale + 10)
				)
			end)
		else
			heldGhost.Visible = false
		end
	end

	local function rotateHeldItem()
		SoundController.playItemRotate()
		if ClientStore.ui.heldItem then
			ClientStore.ui.heldItem.rotated = not ClientStore.ui.heldItem.rotated
			ClientStore.notify()
		elseif ClientStore.ui.selectedItem and ClientStore.ui.selectedItem.srcGrid then
			sendAction("InventoryAction", {
				action = "RotateInPlace",
				srcGrid = ClientStore.ui.selectedItem.srcGrid,
				uid = ClientStore.ui.selectedItem.item.uid,
			})
		end
	end
	rotateBtn.MouseButton1Click:Connect(rotateHeldItem)

	local function refreshAll()
		if ClientStore.ui.inventoryOpen then
			actor:appear()
		else
			heldGhost.Visible = false
			actor:disappear()
			return
		end

		local snap = ClientStore.snapshot
		local held = ClientStore.ui.heldItem
		if held then
			local w = if held.rotated then held.item.gridH else held.item.gridW
			local h = if held.rotated then held.item.gridW else held.item.gridH
			heldStatusLbl.Text = string.format("HOLDING: %s [%dx%d]  •  [R] Rotate  •  Click cell/slot to place", held.item.name, w, h)
			if actor.onUpdate then
				actor.onUpdate(0)
			end
		else
			heldGhost.Visible = false
			heldStatusLbl.Text = "Click: Move  •  Right-Click: Quick-Equip/Loot  •  [R] Rotate"
		end

		-- Refresh Paperdoll
		for _, sDef in ipairs(slotDefs) do
			local btn = slotButtons[sDef.key]
			local eq = snap.paperdoll[sDef.key]
			if eq then
				local durTxt = if (eq.maxDurability or 0) > 0
					then string.format(" (%d/%d)", eq.durability, eq.maxDurability)
					else ""
				btn.Text = sDef.label .. ": " .. eq.name .. durTxt
				btn.TextColor3 = Theme.rarityColor(eq.rarity)
			else
				btn.Text = sDef.label .. ": [Empty]"
				btn.TextColor3 = Theme.textMuted
			end
		end

		for bIdx = 1, 4 do
			local bBtn = slotButtons["Belt" .. tostring(bIdx)]
			local bi = snap.belt[bIdx]
			bBtn.Text = if bi then string.format("[%d] x%d", bIdx + 2, bi.stack or 1) else string.format("[%d] --", bIdx + 2)
			bBtn.TextColor3 = if bi then Theme.positiveGreen else Theme.textMuted
		end

		local st = snap.stats or {}
		statsReadout.Text = string.format(
			"MAX SHIELD: %d  (%d/s, %.1fs delay)\nMAX HEALTH: %d   •   ARMOR: %d\nHAZARD RESIST: %d%%   •   SPEED: %+d%%\nLOOT RARITY FIND: %+d%%\nDEATH RULE: Keep Paperdoll + 2x2 Case (-20%% Dur)",
			st.maxShield or 100,
			st.shieldRegenRate or 28,
			st.shieldStunDelay or 3.4,
			st.maxHealth or 100,
			st.armorRating or 10,
			math.floor((st.hazardResist or 0) * 100 + 0.5),
			math.floor((st.moveSpeedPct or 0) * 100 + 0.5),
			math.floor((st.rarityFind or 0) * 100 + 0.5)
		)

		-- Grids
		backpackWidget.render(snap.backpack)
		secureWidget.render(snap.secureCase)
		stashWidget.render(if not snap.inRaid then snap.stash else nil)
		stashRaidLockLbl.Visible = snap.inRaid

		if snap.openContainer then
			crateTitleLbl.Text = snap.openContainer.title
			crateWidget.render(snap.openContainer.grid)
		else
			crateTitleLbl.Text = "NO CONTAINER OPEN (Approach crate & press [E])"
			crateWidget.render(nil)
		end

		-- Contracts
		for _, cDef in ipairs(DurabilityMath.Contracts) do
			local cBtn = contractButtons[cDef.id]
			local cst = snap.contracts[cDef.id]
			if cBtn then
				if cst and cst.accepted then
					local done = (cst.progress >= cDef.goal)
					cBtn.Text = string.format(
						"%s [%d/%d] %s\n%s (+%d Scrap, +%d CR)",
						cDef.title,
						cst.progress,
						cDef.goal,
						if done then "★ CLICK TO CLAIM! ★" else "(ACTIVE)",
						cDef.description,
						cDef.rewardScrap,
						cDef.rewardCredits
					)
					cBtn.TextColor3 = if done then Theme.positiveGreen else Theme.textPrimary
				else
					cBtn.Text = string.format("%s [CLICK TO ACCEPT]\n%s", cDef.title, cDef.description)
					cBtn.TextColor3 = Theme.textSecondary
				end
			end
		end

		-- Tech Tree
		local pts = snap.skillPoints or 0
		techHdrLbl.Text = string.format("RAIDER SPECIALIZATION TECH  •  %d PT%s AVAILABLE", pts, if pts == 1 then "" else "S")
		local curSkills = snap.skills or {}
		for _, sNode in ipairs(SkillTreeCatalog.Nodes) do
			local sb = skillButtons[sNode.id]
			if sb then
				local rnk = curSkills[sNode.id] or 0
				local maxed = (rnk >= sNode.maxRank)
				sb.Text = string.format(
					"[%s] %s  •  Rank %d/%d %s\n%s",
					sNode.category,
					sNode.name,
					rnk,
					sNode.maxRank,
					if maxed then "(MAX)" elseif pts > 0 then "[+ UPGRADE]" else "",
					sNode.description
				)
				sb.TextColor3 = if maxed then Theme.scrapAmber elseif rnk > 0 then Theme.positiveGreen else Theme.textPrimary
			end
		end

		-- Active Right Tab visibility
		local rTab = ClientStore.ui.rightTab
		stashView.Visible = (rTab == "Stash")
		crateView.Visible = (rTab == "Crate")
		benchView.Visible = (rTab == "Workbench")
		vendorView.Visible = (rTab == "Vendor")
		contractsView.Visible = (rTab == "Contracts")
		techView.Visible = (rTab == "Tech")
		deployView.Visible = (rTab == "Deploy")
		for id, tb in pairs(tabButtons) do
			tb.BackgroundColor3 = if id == rTab then Color3.fromRGB(48, 72, 108) else Theme.bgElevated
			tb.TextColor3 = if id == rTab then Theme.shieldCyan else Theme.textSecondary
		end

		-- Item Comparison Inspector (`BotW` delta card)
		local sel = ClientStore.ui.selectedItem
		if sel and sel.item then
			local itm = sel.item
			local rCol = Theme.rarityColor(itm.rarity)
			inspectorStroke.Color = rCol
			inspTitle.Text = itm.name
			inspTitle.TextColor3 = rCol
			local durPart = if (itm.maxDurability or 0) > 0
				then string.format("  •  Dur %d/%d", itm.durability, itm.maxDurability)
				else ""
			inspMeta.Text = string.format(
				"%s %s  •  ilvl %d  •  [%dx%d]%s  •  Val %d CR",
				itm.rarity,
				itm.category,
				itm.ilvl or 1,
				itm.gridW,
				itm.gridH,
				durPart,
				itm.value or 0
			)

			local lines: { string } = {}
			local diffs = LootRoller.compareItemToPaperdoll(itm, snap.paperdoll)
			for _, d in ipairs(diffs) do
				local good = if d.higherIsBetter then (d.delta > 0) else (d.delta < 0)
				local arrow = if d.delta == 0 then "=" elseif good then "▲" else "▼"
				table.insert(lines, string.format("%s %s: %s (%+g vs equipped)", arrow, d.label, tostring(d.newVal), d.delta))
			end
			for _, af in ipairs(itm.affixes or {}) do
				table.insert(lines, "• " .. af.label)
			end
			if itm.perkTitle and itm.perkDescription then
				table.insert(lines, "★ " .. itm.perkTitle .. ": " .. itm.perkDescription)
			end
			inspBody.Text = table.concat(lines, "\n")

			local repCost = DurabilityMath.getRepairCost(itm)
			local rerollCost = DurabilityMath.getRerollCost(itm)
			repairSelBtn.Text = string.format("REPAIR %s (%d SCRAP)", string.sub(itm.name, 1, 18), repCost)
			rerollSelBtn.Text = string.format("REFORGE AFFIXES (%d SCRAP)", rerollCost)
		else
			inspectorStroke.Color = Theme.borderSubtle
			inspTitle.Text = "Hover or click any item to inspect & compare"
			inspTitle.TextColor3 = Theme.textSecondary
			inspMeta.Text = ""
			inspBody.Text = "Diablo Rarity Tiers: Common -> Uncommon -> Rare -> Epic -> Legendary\nItems in your Paperdoll & 2x2 Secure Case are ALWAYS kept if you fall in the Wasteland."
		end
	end

	ClientStore.subscribe(refreshAll)

	return {
		actor = actor,
		rotateHeldItem = rotateHeldItem,
	}
end

return InventoryLayoutActor
