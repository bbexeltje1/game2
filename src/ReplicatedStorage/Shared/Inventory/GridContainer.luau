--!strict
-- Clean-room Luau implementation of Diablo's 2D Spatial Grid Inventory (`diasurgical/DevilutionX`
-- `Source/inv.h` & `Source/inv.cpp` signed occupancy matrix) + Paperdoll + 2x2 Secure Case + Belt.
--
-- Cell matrix encoding:
--   nil               -> empty cell
--   "anchor:<uid>"    -> top-left origin cell of item `<uid>`
--   "ref:<uid>"       -> neighbor cell covered by item `<uid>`'s W x H footprint

local LootRoller = require(script.Parent.Parent.Loot.LootRoller)

export type PlacedEntry = {
	item: LootRoller.ItemInstance,
	x: number, -- 1-based column (1..width)
	y: number, -- 1-based row (1..height)
}

export type GridData = {
	width: number,
	height: number,
	cells: { [number]: string? }, -- linear index = (y - 1) * width + x
	entries: { [string]: PlacedEntry },
}

export type PaperdollSlot = "Primary1" | "Primary2" | "ShieldCore" | "Head" | "Chest" | "Legs" | "Relic1" | "Relic2"

local PAPERDOLL_ALLOWED: { [string]: string } = {
	Primary1 = "Weapon",
	Primary2 = "Weapon",
	ShieldCore = "ShieldCore",
	Head = "Head",
	Chest = "Chest",
	Legs = "Legs",
	Relic1 = "Relic",
	Relic2 = "Relic",
}

local PAPERDOLL_SLOTS: { PaperdollSlot } = {
	"Primary1",
	"Primary2",
	"ShieldCore",
	"Head",
	"Chest",
	"Legs",
	"Relic1",
	"Relic2",
}

local GridContainer = {
	PaperdollAllowed = PAPERDOLL_ALLOWED,
	PaperdollSlots = PAPERDOLL_SLOTS,
}

local function cellIndex(grid: GridData, x: number, y: number): number
	return (y - 1) * grid.width + x
end

local function extractUid(cellVal: string?): string?
	if not cellVal then
		return nil
	end
	local sep = string.find(cellVal, ":", 1, true)
	if not sep then
		return cellVal
	end
	return string.sub(cellVal, sep + 1)
end

function GridContainer.getDimensions(item: LootRoller.ItemInstance, rotated: boolean?): (number, number)
	local isRot = if rotated ~= nil then rotated else item.rotated
	if isRot then
		return item.gridH, item.gridW
	end
	return item.gridW, item.gridH
end

function GridContainer.new(width: number, height: number): GridData
	return {
		width = math.max(1, math.floor(width)),
		height = math.max(1, math.floor(height)),
		cells = {},
		entries = {},
	}
end

function GridContainer.inBounds(grid: GridData, x: number, y: number, w: number, h: number): boolean
	return x >= 1 and y >= 1 and (x + w - 1) <= grid.width and (y + h - 1) <= grid.height
end

function GridContainer.getUidAt(grid: GridData, x: number, y: number): string?
	if x < 1 or y < 1 or x > grid.width or y > grid.height then
		return nil
	end
	return extractUid(grid.cells[cellIndex(grid, x, y)])
end

function GridContainer.getEntryAt(grid: GridData, x: number, y: number): PlacedEntry?
	local uid = GridContainer.getUidAt(grid, x, y)
	if not uid then
		return nil
	end
	return grid.entries[uid]
end

-- Returns { ok = boolean, blockers = { [uid] = true } } so drag-and-drop swap (when exactly 1
-- blocker overlaps) works just like Diablo / Tarkov!
function GridContainer.inspectFootprint(
	grid: GridData,
	item: LootRoller.ItemInstance,
	x: number,
	y: number,
	rotated: boolean?,
	ignoreUid: string?
): { inBounds: boolean, blockerUids: { string } }
	local w, h = GridContainer.getDimensions(item, rotated)
	if not GridContainer.inBounds(grid, x, y, w, h) then
		return { inBounds = false, blockerUids = {} }
	end

	local seen: { [string]: boolean } = {}
	local blockers: { string } = {}
	for dy = 0, h - 1 do
		for dx = 0, w - 1 do
			local uid = GridContainer.getUidAt(grid, x + dx, y + dy)
			if uid and uid ~= ignoreUid and uid ~= item.uid and not seen[uid] then
				seen[uid] = true
				table.insert(blockers, uid)
			end
		end
	end

	return { inBounds = true, blockerUids = blockers }
end

function GridContainer.canPlace(
	grid: GridData,
	item: LootRoller.ItemInstance,
	x: number,
	y: number,
	rotated: boolean?,
	ignoreUid: string?
): boolean
	local check = GridContainer.inspectFootprint(grid, item, x, y, rotated, ignoreUid)
	return check.inBounds and #check.blockerUids == 0
end

function GridContainer.remove(grid: GridData, uid: string): LootRoller.ItemInstance?
	local existing = grid.entries[uid]
	if not existing then
		return nil
	end
	local w, h = GridContainer.getDimensions(existing.item, existing.item.rotated)
	for dy = 0, h - 1 do
		for dx = 0, w - 1 do
			local idx = cellIndex(grid, existing.x + dx, existing.y + dy)
			if extractUid(grid.cells[idx]) == uid then
				grid.cells[idx] = nil
			end
		end
	end
	grid.entries[uid] = nil
	return existing.item
end

function GridContainer.place(
	grid: GridData,
	item: LootRoller.ItemInstance,
	x: number,
	y: number,
	rotated: boolean?
): boolean
	local useRot = if rotated ~= nil then rotated else item.rotated
	if not GridContainer.canPlace(grid, item, x, y, useRot, item.uid) then
		return false
	end

	-- Ensure any previous position of this same uid in this grid is cleared first.
	GridContainer.remove(grid, item.uid)

	item.rotated = useRot
	local w, h = GridContainer.getDimensions(item, useRot)
	for dy = 0, h - 1 do
		for dx = 0, w - 1 do
			local idx = cellIndex(grid, x + dx, y + dy)
			if dx == 0 and dy == 0 then
				grid.cells[idx] = "anchor:" .. item.uid
			else
				grid.cells[idx] = "ref:" .. item.uid
			end
		end
	end

	grid.entries[item.uid] = {
		item = item,
		x = x,
		y = y,
	}
	return true
end

-- Auto-stacks into matching partial stacks first, then scans row-by-row (trying current
-- orientation first, then rotated 90 deg if rectangular) to place the item cleanly.
function GridContainer.autoPlace(grid: GridData, item: LootRoller.ItemInstance): boolean
	if item.maxStack > 1 and item.stack > 0 then
		for _, entry in pairs(grid.entries) do
			local existing = entry.item
			if existing.baseId == item.baseId and existing.uid ~= item.uid and existing.stack < existing.maxStack then
				local space = existing.maxStack - existing.stack
				local transfer = math.min(space, item.stack)
				existing.stack += transfer
				item.stack -= transfer
				if item.stack <= 0 then
					return true
				end
			end
		end
	end

	local orientations = { item.rotated }
	if item.gridW ~= item.gridH then
		table.insert(orientations, not item.rotated)
	end

	for _, rot in ipairs(orientations) do
		local w, h = GridContainer.getDimensions(item, rot)
		for y = 1, grid.height - h + 1 do
			for x = 1, grid.width - w + 1 do
				if GridContainer.canPlace(grid, item, x, y, rot, item.uid) then
					return GridContainer.place(grid, item, x, y, rot)
				end
			end
		end
	end

	return false
end

-- Moves or swaps an item within or across two grids (e.g. Backpack <-> Stash / Crate / SecureCase).
function GridContainer.moveAcrossGrids(
	srcGrid: GridData,
	dstGrid: GridData,
	uid: string,
	dstX: number,
	dstY: number,
	newRotated: boolean?
): (boolean, string?)
	local srcEntry = srcGrid.entries[uid]
	if not srcEntry then
		return false, "Item not found"
	end
	local item = srcEntry.item
	local oldX, oldY, oldRot = srcEntry.x, srcEntry.y, item.rotated
	local targetRot = if newRotated ~= nil then newRotated else item.rotated

	local check = GridContainer.inspectFootprint(
		dstGrid,
		item,
		dstX,
		dstY,
		targetRot,
		if srcGrid == dstGrid then uid else nil
	)
	if not check.inBounds then
		return false, "Out of bounds"
	end

	if #check.blockerUids == 0 then
		GridContainer.remove(srcGrid, uid)
		GridContainer.place(dstGrid, item, dstX, dstY, targetRot)
		return true, nil
	end

	-- Single blocker swap (Diablo cursor/slot swap convenience)
	if #check.blockerUids == 1 then
		local otherUid = check.blockerUids[1]
		local otherEntry = dstGrid.entries[otherUid]
		if otherEntry then
			local otherItem = otherEntry.item
			-- Stack merge if identical stackable item
			if otherItem.baseId == item.baseId and otherItem.maxStack > 1 and otherItem.stack < otherItem.maxStack then
				local transfer = math.min(otherItem.maxStack - otherItem.stack, item.stack)
				otherItem.stack += transfer
				item.stack -= transfer
				if item.stack <= 0 then
					GridContainer.remove(srcGrid, uid)
				end
				return true, nil
			end

			local otherX, otherY, otherRot = otherEntry.x, otherEntry.y, otherItem.rotated
			GridContainer.remove(srcGrid, uid)
			GridContainer.remove(dstGrid, otherUid)

			local placedMain = GridContainer.place(dstGrid, item, dstX, dstY, targetRot)
			local placedOther = false
			if placedMain then
				placedOther = GridContainer.place(srcGrid, otherItem, oldX, oldY, otherItem.rotated)
				if not placedOther then
					placedOther = GridContainer.autoPlace(srcGrid, otherItem)
				end
			end

			if placedMain and placedOther then
				return true, nil
			end

			-- Rollback cleanly if swap couldn't fit the displaced item back into srcGrid
			GridContainer.remove(dstGrid, uid)
			GridContainer.remove(srcGrid, otherUid)
			GridContainer.place(srcGrid, item, oldX, oldY, oldRot)
			GridContainer.place(dstGrid, otherItem, otherX, otherY, otherRot)
			return false, "Swap target does not fit origin space"
		end
	end

	return false, "Cells occupied"
end

function GridContainer.listItems(grid: GridData): { PlacedEntry }
	local list: { PlacedEntry } = {}
	for _, entry in pairs(grid.entries) do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	return list
end

function GridContainer.clearAll(grid: GridData): { LootRoller.ItemInstance }
	local dropped: { LootRoller.ItemInstance } = {}
	for _, entry in ipairs(GridContainer.listItems(grid)) do
		table.insert(dropped, entry.item)
	end
	grid.cells = {}
	grid.entries = {}
	return dropped
end

function GridContainer.canEquipSlot(slotName: string, item: LootRoller.ItemInstance): boolean
	local expectedCategory = PAPERDOLL_ALLOWED[slotName]
	if not expectedCategory then
		return false
	end
	return item.category == expectedCategory
end

function GridContainer.serialize(grid: GridData): { width: number, height: number, list: { { x: number, y: number, item: any } } }
	local list = {}
	for _, entry in ipairs(GridContainer.listItems(grid)) do
		table.insert(list, {
			x = entry.x,
			y = entry.y,
			item = entry.item,
		})
	end
	return {
		width = grid.width,
		height = grid.height,
		list = list,
	}
end

function GridContainer.deserialize(serialized: { [string]: any }): GridData
	local g = GridContainer.new(serialized.width or 10, serialized.height or 5)
	if type(serialized.list) == "table" then
		for _, rec in ipairs(serialized.list) do
			if rec and rec.item then
				GridContainer.place(g, rec.item, rec.x or 1, rec.y or 1, rec.item.rotated)
			end
		end
	end
	return g
end

return GridContainer
