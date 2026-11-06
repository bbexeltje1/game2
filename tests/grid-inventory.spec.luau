-- Unit specs for DevilutionX 2D Spatial Grid (`inv.cpp`), 90-degree rotation, swaps & serialization.
local backpack = GridContainer.new(10, 5)
local stash = GridContainer.new(10, 12)

local rifle = LootRoller.createSpecificItem("FerroRail", "Epic", 16, 1, 101) -- 4x2 sniper
local pistol = LootRoller.createSpecificItem("M6DSidearm", "Rare", 8, 1, 102) -- 2x1 pistol
local med1 = LootRoller.createSpecificItem("MedInjector", "Common", 1, 3, 103) -- 1x1 stack 3/5
local med2 = LootRoller.createSpecificItem("MedInjector", "Common", 1, 4, 104) -- 1x1 stack 4/5

assert(rifle.gridW == 4 and rifle.gridH == 2, "Ferro-Rail has 4x2 footprint")
assert(GridContainer.place(backpack, rifle, 8, 1, false) == false, "Out-of-bounds 4x2 placement at x=8 rejected")
assert(GridContainer.place(backpack, rifle, 1, 1, false) == true, "Valid 4x2 placement at (1,1) succeeds")
assert(GridContainer.getUidAt(backpack, 4, 2) == rifle.uid, "Covered cell (4,2) resolves back to rifle uid")
assert(GridContainer.place(backpack, pistol, 3, 2, false) == false, "Overlapping placement rejected")

-- Rotate Ferro-Rail 90 degrees (4x2 -> 2x4) at (9, 1) inside 10x5 grid!
assert(GridContainer.place(backpack, rifle, 9, 1, true) == true, "Rotated 2x4 placement at (9,1) fits inside 10x5")
assert(GridContainer.getUidAt(backpack, 1, 1) == nil, "Old cells cleared on move")
assert(GridContainer.getUidAt(backpack, 10, 4) == rifle.uid, "Rotated footprint covers (10,4)")

-- Single-blocker swap across Backpack <-> Stash
assert(GridContainer.place(stash, pistol, 1, 1, false) == true, "Pistol placed in Stash")
local swapped, err = GridContainer.moveAcrossGrids(backpack, stash, rifle.uid, 1, 1, false)
assert(swapped == true and err == nil, "Moving rifle onto single pistol in Stash swaps pistol into Backpack")
assert(stash.entries[rifle.uid] ~= nil and backpack.entries[pistol.uid] ~= nil, "Swap completed cleanly")

-- Partial stack auto-merge (3 + 4 -> 5 + 2)
assert(GridContainer.autoPlace(backpack, med1) == true, "First med stack placed")
assert(GridContainer.autoPlace(backpack, med2) == true, "Second med stack merged & overflow placed")
assert(med1.stack == 5 and med2.stack == 2, "Stackable consumables merge up to maxStack=5")

-- Serialization round-trip
local encoded = GridContainer.serialize(backpack)
local decoded = GridContainer.deserialize(encoded)
assert(#GridContainer.listItems(decoded) == #GridContainer.listItems(backpack), "Grid serialize/deserialize preserves all items")

-- Compact Auto-Sort (`compactSort`) packs scattered items into top-left sorted by area & rarity
local messy = GridContainer.new(10, 5)
local smallCommon = LootRoller.createSpecificItem("ScrapBundle", "Common", 1, 10, 201) -- 1x1
local bigLegendary = LootRoller.createSpecificItem("ArcMortar", "Legendary", 25, 1, 202) -- 3x2
assert(GridContainer.place(messy, smallCommon, 10, 5, false) == true, "Small item placed at bottom-right (10,5)")
assert(GridContainer.place(messy, bigLegendary, 5, 3, false) == true, "Big 3x2 placed in middle (5,3)")
GridContainer.compactSort(messy)
assert(messy.entries[bigLegendary.uid].x == 1 and messy.entries[bigLegendary.uid].y == 1, "compactSort packs largest/rarest 3x2 item at (1,1)")
assert(messy.entries[smallCommon.uid] ~= nil and messy.entries[smallCommon.uid].y == 1, "compactSort packs remaining 1x1 item into top row")

print("PASS 2D Grid Inventory: footprints, 90-deg rotation, swap, stack merge & compactSort verified")
