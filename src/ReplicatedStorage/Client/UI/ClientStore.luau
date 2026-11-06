--!strict
-- Unidirectional Client State Store (`zeldaret/botw` `uiPauseMenuDataMgr` pattern).
-- UI LayoutActors subscribe to state snapshots and never mutate gameplay tables directly.

export type HeldDragItem = {
	srcGrid: string, -- "Backpack" | "Stash" | "SecureCase" | "Crate"
	uid: string,
	item: { [string]: any },
	rotated: boolean,
}

local listeners: { () -> () } = {}

local ClientStore = {
	snapshot = {
		level = 1,
		xp = 0,
		xpNext = 150,
		scrap = 180,
		credits = 250,
		extractions = 0,
		kills = 0,
		inRaid = false,
		currentZoneId = "Bunker",
		activeWeaponSlot = "Primary1",
		ordnanceId = "EmpGrenade",
		ordnanceCooldown = 0,
		vitality = {
			shield = 100,
			maxShield = 100,
			shieldStunRemaining = 0,
			health = 100,
			maxHealth = 100,
			corrosive = false,
			downed = false,
			bleedoutRemaining = 15,
		},
		stats = {
			maxShield = 100,
			shieldRegenRate = 28,
			shieldStunDelay = 3.4,
			maxHealth = 100,
			armorRating = 10,
			hazardResist = 0,
			moveSpeedPct = 0,
			rarityFind = 0,
		},
		paperdoll = {} :: { [string]: any },
		belt = {} :: { [number]: any },
		backpack = { width = 10, height = 5, list = {} },
		stash = { width = 10, height = 12, list = {} },
		secureCase = { width = 2, height = 2, list = {} },
		openContainer = nil :: any,
		weaponRuntime = {
			Primary1 = { ammo = 32, maxAmmo = 32, heat = 0, isOverheated = false, isReloading = false, venting = false },
			Primary2 = { ammo = 12, maxAmmo = 12, heat = 0, isOverheated = false, isReloading = false, venting = false },
		},
		contracts = {} :: { [string]: any },
	},

	world = {
		beacons = {} :: { any },
		radarBlips = {} :: { any },
		squad = {} :: { any },
	},

	ui = {
		inventoryOpen = false,
		rightTab = "Stash" :: string, -- "Crate" | "Stash" | "Workbench" | "Vendor" | "Contracts" | "Deploy"
		heldItem = nil :: HeldDragItem?,
		selectedItem = nil :: { item: any, srcGrid: string? }?,
		interactPrompt = nil :: string?,
		adsActive = false,
		sprinting = false,
		reticleBloom = 0,
		raidSummary = nil :: any,
	},
}

function ClientStore.subscribe(fn: () -> ())
	table.insert(listeners, fn)
end

function ClientStore.notify()
	for _, fn in ipairs(listeners) do
		fn()
	end
end

function ClientStore.applySnapshot(payload: { [string]: any })
	local prevOpenContainer = ClientStore.snapshot.openContainer
	ClientStore.snapshot = payload

	-- Automatically pop open the Inventory on the [CRATE] tab when opening a world container!
	if payload.openContainer and not prevOpenContainer then
		ClientStore.ui.inventoryOpen = true
		ClientStore.ui.rightTab = "Crate"
	elseif not payload.openContainer and ClientStore.ui.rightTab == "Crate" then
		ClientStore.ui.rightTab = if payload.inRaid then "Contracts" else "Stash"
	end

	-- Clear held drag item if it no longer exists after server reconciliation
	if ClientStore.ui.heldItem then
		ClientStore.ui.heldItem = nil
	end

	ClientStore.notify()
end

function ClientStore.applyWorldState(payload: { [string]: any })
	if type(payload) == "table" then
		ClientStore.world.beacons = payload.beacons or {}
		ClientStore.world.radarBlips = payload.radarBlips or {}
		ClientStore.world.squad = payload.squad or {}
	end
	ClientStore.notify()
end

return ClientStore
