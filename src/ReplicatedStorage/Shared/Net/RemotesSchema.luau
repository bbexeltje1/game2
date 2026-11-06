--!strict
-- Canonical RemoteEvent names created at server boot before any heavy initialization.
return {
	folderName = "Remotes",
	events = {
		Ready = "Ready",
		StateSnapshot = "StateSnapshot",
		WorldState = "WorldState",
		CombatFeedback = "CombatFeedback",
		RaidSummary = "RaidSummary",
		Notification = "Notification",

		-- Client -> Server authoritative intents
		WeaponFire = "WeaponFire",
		WeaponAction = "WeaponAction", -- Reload / Vent / Swap / Grenade
		InventoryAction = "InventoryAction", -- Move / Rotate / Equip / Unequip / QuickTransfer / UseBelt / Drop
		InteractWorld = "InteractWorld", -- OpenCrate / PickupDrop / DeployZone / TriggerExtraction / ReviveAlly
		BunkerAction = "BunkerAction", -- RepairItem / RepairAll / SalvageItem / SalvageCommon / RerollAffix / BuyVendor / AcceptContract / ClaimContract
		TacticalMove = "TacticalMove", -- Dodge / Slide / Mantle
	},
}
