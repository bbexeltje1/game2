--!strict
-- Halo + Zelda: Breath of the Wild inspired Minimalist Combat Pro-HUD (`LayoutActor`).
--
-- Features:
--   1. Top-Center Halo Energy Shield Bar (with stun/depleted warning pulse) + Body Health Bar + Sector Tag
--   2. Active Extraction Holdout Banner (visible across the surface whenever a Beacon is active)
--   3. Bottom-Left 25m Halo Motion Tracker Radar (live enemy, boss, squad & beacon blips) + Currency/XP
--   4. Bottom-Right 2-Weapon Cards, Ammo / Sol-Coil Plasma Heat Gauge, [Q] Ordnance & [3-6] Belt Slots
--   5. Center Dynamic Bloom Crosshair + Color-Coded Hitmarker + Damage Readout + [E] Contextual Prompt

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)

local Config = require(Shared:WaitForChild("Config", 10))
local WorldZones = require(Shared:WaitForChild("World", 10):WaitForChild("WorldZones", 10))
local WeaponCatalog = require(Shared:WaitForChild("Weapons", 10):WaitForChild("WeaponCatalog", 10))
local LayoutActor = require(ClientModules:WaitForChild("Core", 10):WaitForChild("LayoutActor", 10))
local Theme = require(ClientModules:WaitForChild("UI", 10):WaitForChild("Theme", 10))
local ClientStore = require(ClientModules:WaitForChild("UI", 10):WaitForChild("ClientStore", 10))

local CombatHudActor = {}

function CombatHudActor.create(screenGui: ScreenGui): {
	actor: LayoutActor.LayoutActorObj,
	flashHitmarker: (info: { [string]: any }) -> (),
	showToast: (text: string, tone: string?) -> (),
	updateRadarHeading: (cameraLookXZ: Vector2, playerPos: Vector3) -> (),
}
	local root = Theme.frame(screenGui, "CombatProHud", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.bgRoot, 1)
	local actor = LayoutActor.new("CombatProHud", root, true)

	-- =========================================================================
	-- 1. TOP-CENTER: HALO ENERGY SHIELD + BODY HEALTH + ZONE / EXTRACTION BANNER
	-- =========================================================================
	local topCluster = Theme.frame(
		root,
		"TopVitalityCluster",
		UDim2.fromOffset(420, 88),
		UDim2.new(0.5, -210, 0, 14),
		Theme.bgPanel,
		0.18
	)
	Theme.addCorner(topCluster, 8)
	local shieldStroke = Theme.addStroke(topCluster, Theme.shieldCyan, 1.5, 0.25)

	local sectorLbl = Theme.label(
		topCluster,
		"SectorLabel",
		"BASTION BUNKER • SAFE HUB",
		UDim2.new(1, -20, 0, 18),
		UDim2.fromOffset(10, 5),
		Enum.Font.GothamBold,
		12,
		Theme.textSecondary,
		Enum.TextXAlignment.Center
	)

	-- Energy Shield Bar (wide Halo bar)
	local shieldBg = Theme.frame(topCluster, "ShieldBarBg", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 26), Theme.bgSlot, 0)
	Theme.addCorner(shieldBg, 5)
	local shieldFill = Theme.frame(shieldBg, "ShieldFill", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.shieldCyan, 0.1)
	Theme.addCorner(shieldFill, 5)
	local shieldText = Theme.label(
		shieldBg,
		"ShieldText",
		"SHIELD 100 / 100",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		12,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)

	-- Body Health Bar (slim secondary bar underneath)
	local hpBg = Theme.frame(topCluster, "HealthBarBg", UDim2.new(1, -64, 0, 14), UDim2.fromOffset(32, 54), Theme.bgSlot, 0)
	Theme.addCorner(hpBg, 4)
	local hpFill = Theme.frame(hpBg, "HealthFill", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.healthRed, 0.1)
	Theme.addCorner(hpFill, 4)
	local hpText = Theme.label(
		hpBg,
		"HealthText",
		"HP 100 / 100",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		10,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)

	local warningLbl = Theme.label(
		topCluster,
		"ShieldWarning",
		"",
		UDim2.new(1, 0, 0, 16),
		UDim2.fromOffset(0, 70),
		Enum.Font.GothamBold,
		11,
		Theme.shieldWarning,
		Enum.TextXAlignment.Center
	)

	-- Active Extraction Holdout Banner right below TopVitalityCluster
	local extractBanner = Theme.frame(
		root,
		"ExtractionBanner",
		UDim2.fromOffset(420, 34),
		UDim2.new(0.5, -210, 0, 108),
		Color3.fromRGB(24, 38, 34),
		0.12
	)
	extractBanner.Visible = false
	Theme.addCorner(extractBanner, 6)
	local extractStroke = Theme.addStroke(extractBanner, Theme.positiveGreen, 1.5, 0)
	local extractText = Theme.label(
		extractBanner,
		"ExtractionText",
		"EXTRACTION ACTIVE",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		12,
		Theme.positiveGreen,
		Enum.TextXAlignment.Center
	)

	-- =========================================================================
	-- 2. BOTTOM-LEFT: 25M HALO MOTION TRACKER RADAR + ECONOMY / LEVEL STRIP
	-- =========================================================================
	local radarFrame = Theme.frame(
		root,
		"MotionTracker",
		UDim2.fromOffset(154, 154),
		UDim2.new(0, 18, 1, -206),
		Color3.fromRGB(14, 22, 32),
		0.18
	)
	Theme.addCorner(radarFrame, 77)
	Theme.addStroke(radarFrame, Theme.shieldCyan, 1.5, 0.35)

	local innerRing = Theme.frame(
		radarFrame,
		"InnerRing",
		UDim2.fromOffset(78, 78),
		UDim2.fromOffset(38, 38),
		Theme.bgRoot,
		1
	)
	Theme.addCorner(innerRing, 39)
	Theme.addStroke(innerRing, Theme.shieldCyan, 1, 0.72)

	local selfDot = Theme.frame(
		radarFrame,
		"SelfDot",
		UDim2.fromOffset(8, 8),
		UDim2.fromOffset(73, 73),
		Theme.shieldCyan,
		0
	)
	Theme.addCorner(selfDot, 4)

	-- Pre-allocate 24 radar blip dots (zero per-frame Instance creation!)
	local radarDots: { Frame } = {}
	for i = 1, 24 do
		local d = Theme.frame(radarFrame, "Blip_" .. tostring(i), UDim2.fromOffset(6, 6), UDim2.fromOffset(74, 74), Theme.healthRed, 0)
		d.Visible = false
		Theme.addCorner(d, 3)
		table.insert(radarDots, d)
	end

	local profileStrip = Theme.frame(
		root,
		"ProfileEconomyStrip",
		UDim2.fromOffset(270, 32),
		UDim2.new(0, 18, 1, -44),
		Theme.bgPanel,
		0.16
	)
	Theme.addCorner(profileStrip, 6)
	Theme.addStroke(profileStrip, Theme.borderSubtle, 1, 0.2)
	local economyText = Theme.label(
		profileStrip,
		"EconomyText",
		"LV 1  •  180 SCRAP  •  250 CR",
		UDim2.new(1, -16, 1, 0),
		UDim2.fromOffset(8, 0),
		Enum.Font.GothamBold,
		12,
		Theme.scrapAmber,
		Enum.TextXAlignment.Left
	)

	-- =========================================================================
	-- 3. BOTTOM-RIGHT: 2 WEAPON SLOTS + AMMO / HEAT + ORDNANCE + 4 BELT SLOTS
	-- =========================================================================
	local weaponHud = Theme.frame(
		root,
		"WeaponDeck",
		UDim2.fromOffset(330, 134),
		UDim2.new(1, -348, 1, -150),
		Theme.bgPanel,
		0.16
	)
	Theme.addCorner(weaponHud, 8)
	Theme.addStroke(weaponHud, Theme.borderSubtle, 1.2, 0.2)

	local activeGunName = Theme.label(
		weaponHud,
		"ActiveWeaponName",
		"[1] MA-7 Wasteland Rifle",
		UDim2.new(1, -20, 0, 22),
		UDim2.fromOffset(10, 6),
		Enum.Font.GothamBold,
		14,
		Theme.textPrimary,
		Enum.TextXAlignment.Left
	)
	local holsteredGunName = Theme.label(
		weaponHud,
		"HolsteredWeaponName",
		"[2] M6D Bastion Sidearm",
		UDim2.new(1, -20, 0, 16),
		UDim2.fromOffset(10, 28),
		Enum.Font.GothamMedium,
		11,
		Theme.textSecondary,
		Enum.TextXAlignment.Left
	)

	local ammoOrHeatBg = Theme.frame(weaponHud, "AmmoOrHeatBg", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 50), Theme.bgSlot, 0)
	Theme.addCorner(ammoOrHeatBg, 5)
	local ammoOrHeatFill = Theme.frame(ammoOrHeatBg, "Fill", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), Theme.shieldCyan, 0.25)
	Theme.addCorner(ammoOrHeatFill, 5)
	local ammoOrHeatText = Theme.label(
		ammoOrHeatBg,
		"Readout",
		"AMMO 32 / 32",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		12,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)

	-- Belt Quickslots [3..6] + [Q] Ordnance
	local beltLabels: { TextLabel } = {}
	for i = 1, 4 do
		local slotBox = Theme.frame(
			weaponHud,
			"BeltSlot_" .. tostring(i),
			UDim2.fromOffset(58, 34),
			UDim2.fromOffset(10 + (i - 1) * 63, 78),
			Theme.bgSlot,
			0
		)
		Theme.addCorner(slotBox, 5)
		Theme.addStroke(slotBox, Theme.borderSubtle, 1, 0.3)
		local bl = Theme.label(
			slotBox,
			"Label",
			string.format("[%d] --", i + 2),
			UDim2.fromScale(1, 1),
			UDim2.fromOffset(0, 0),
			Enum.Font.GothamBold,
			10,
			Theme.textSecondary,
			Enum.TextXAlignment.Center
		)
		bl.TextWrapped = true
		table.insert(beltLabels, bl)
	end

	local ordBox = Theme.frame(weaponHud, "OrdnanceBox", UDim2.fromOffset(58, 34), UDim2.fromOffset(262, 78), Theme.bgSlot, 0)
	Theme.addCorner(ordBox, 5)
	Theme.addStroke(ordBox, Theme.shieldCyan, 1, 0.3)
	local ordLabel = Theme.label(
		ordBox,
		"OrdLabel",
		"[Q] EMP",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		10,
		Theme.shieldCyan,
		Enum.TextXAlignment.Center
	)

	Theme.label(
		weaponHud,
		"ControlsHint",
		"[TAB] Inventory/Bunker  •  [E] Interact  •  [V] Shoulder  •  [C] Slide  •  [ALT] Dodge",
		UDim2.new(1, -12, 0, 14),
		UDim2.fromOffset(6, 116),
		Enum.Font.GothamMedium,
		9,
		Theme.textMuted,
		Enum.TextXAlignment.Center
	)

	-- =========================================================================
	-- 4. CENTER SCREEN: DYNAMIC RETICLE, HITMARKER, TOAST & [E] INTERACT PROMPT
	-- =========================================================================
	local reticleRoot = Theme.frame(root, "ReticleRoot", UDim2.fromOffset(60, 60), UDim2.new(0.5, -30, 0.5, -30), Theme.bgRoot, 1)
	local tickTop = Theme.frame(reticleRoot, "TickTop", UDim2.fromOffset(2, 8), UDim2.fromOffset(29, 14), Theme.shieldCyan, 0.1)
	local tickBot = Theme.frame(reticleRoot, "TickBot", UDim2.fromOffset(2, 8), UDim2.fromOffset(29, 38), Theme.shieldCyan, 0.1)
	local tickLeft = Theme.frame(reticleRoot, "TickLeft", UDim2.fromOffset(8, 2), UDim2.fromOffset(14, 29), Theme.shieldCyan, 0.1)
	local tickRight = Theme.frame(reticleRoot, "TickRight", UDim2.fromOffset(8, 2), UDim2.fromOffset(38, 29), Theme.shieldCyan, 0.1)

	local hitmarkerLbl = Theme.label(
		reticleRoot,
		"Hitmarker",
		"",
		UDim2.fromOffset(140, 26),
		UDim2.fromOffset(-40, 44),
		Enum.Font.GothamBold,
		13,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)
	hitmarkerLbl.Visible = false

	local interactBox = Theme.frame(
		root,
		"InteractPrompt",
		UDim2.fromOffset(320, 34),
		UDim2.new(0.5, -160, 0.64, 0),
		Theme.bgPanel,
		0.14
	)
	interactBox.Visible = false
	Theme.addCorner(interactBox, 6)
	Theme.addStroke(interactBox, Theme.borderBright, 1.4, 0.1)
	local interactLbl = Theme.label(
		interactBox,
		"PromptLabel",
		"[E] INTERACT",
		UDim2.fromScale(1, 1),
		UDim2.fromOffset(0, 0),
		Enum.Font.GothamBold,
		13,
		Theme.textPrimary,
		Enum.TextXAlignment.Center
	)

	local toastLbl = Theme.label(
		root,
		"ToastNotification",
		"",
		UDim2.fromOffset(480, 28),
		UDim2.new(0.5, -240, 0, 148),
		Enum.Font.GothamBold,
		13,
		Theme.scrapAmber,
		Enum.TextXAlignment.Center
	)
	toastLbl.Visible = false

	local hitmarkerHideAt = 0
	local toastHideAt = 0

	local function refreshFromStore()
		local snap = ClientStore.snapshot
		local vit = snap.vitality
		local maxSh = math.max(1, vit.maxShield)
		local shFrac = math.clamp(vit.shield / maxSh, 0, 1)
		shieldFill.Size = UDim2.fromScale(shFrac, 1)
		shieldText.Text = string.format("ENERGY SHIELD  %d / %d", vit.shield, vit.maxShield)

		if vit.shield <= 0 then
			shieldFill.BackgroundColor3 = Theme.shieldWarning
			shieldStroke.Color = Theme.shieldWarning
			warningLbl.Text = string.format("! SHIELD DEPLETED — RECHARGING IN %.1fs !", vit.shieldStunRemaining)
		elseif vit.shieldStunRemaining > 0 then
			shieldFill.BackgroundColor3 = Theme.shieldCyan
			shieldStroke.Color = Theme.scrapAmber
			warningLbl.Text = string.format("SHIELD STUNNED (%.1fs)", vit.shieldStunRemaining)
		else
			shieldFill.BackgroundColor3 = Theme.shieldCyan
			shieldStroke.Color = Theme.shieldCyan
			warningLbl.Text = if vit.downed
				then string.format("DOWNED! BLEEDOUT IN %ds", vit.bleedoutRemaining)
				elseif vit.corrosive then "CORROSIVE ARMOR SHRED ACTIVE"
				else ""
		end

		local maxHp = math.max(1, vit.maxHealth)
		hpFill.Size = UDim2.fromScale(math.clamp(vit.health / maxHp, 0, 1), 1)
		hpText.Text = string.format("HEALTH  %d / %d", vit.health, vit.maxHealth)

		if not snap.inRaid then
			sectorLbl.Text = "BASTION BUNKER  •  SAFE UNDERGROUND HUB"
			sectorLbl.TextColor3 = Theme.shieldCyan
		else
			local zDef = WorldZones.Zones[snap.currentZoneId]
			sectorLbl.Text = if zDef then (zDef.name .. "  •  " .. zDef.tierLabel) else "ASHEN WASTELAND"
			sectorLbl.TextColor3 = Theme.scrapAmber
		end

		-- Active Extraction Holdout Banner
		local activeBeacon = nil
		for _, b in ipairs(ClientStore.world.beacons) do
			if b.state == "Charging" or b.state == "Surge" or b.state == "BoardingWindow" then
				activeBeacon = b
				break
			end
		end
		if activeBeacon then
			extractBanner.Visible = true
			if activeBeacon.state == "BoardingWindow" then
				extractText.Text = string.format("★ %s — BOARDING OPEN (%ds)! ENTER GREEN RING! ★", activeBeacon.name, activeBeacon.timer)
				extractText.TextColor3 = Theme.positiveGreen
				extractStroke.Color = Theme.positiveGreen
			else
				extractText.Text = string.format("▲ %s — HOLDOUT IN PROGRESS (%ds)", activeBeacon.name, activeBeacon.timer)
				extractText.TextColor3 = Theme.scrapAmber
				extractStroke.Color = Theme.scrapAmber
			end
		else
			extractBanner.Visible = false
		end

		economyText.Text = string.format("LV %d  •  %d SCRAP  •  %d CR", snap.level, snap.scrap, snap.credits)

		-- Active & Holstered Weapons
		local activeSlot = snap.activeWeaponSlot
		local otherSlot = if activeSlot == "Primary1" then "Primary2" else "Primary1"
		local activeGun = snap.paperdoll[activeSlot]
		local otherGun = snap.paperdoll[otherSlot]
		local activeIdx = if activeSlot == "Primary1" then 1 else 2
		local otherIdx = if activeSlot == "Primary1" then 2 else 1

		if activeGun then
			activeGunName.Text = string.format("[%d] %s", activeIdx, activeGun.name)
			activeGunName.TextColor3 = Theme.rarityColor(activeGun.rarity)
			local wDef = WeaponCatalog.get(activeGun.baseId)
			local rt = snap.weaponRuntime[activeSlot]
			if wDef and wDef.usesHeat and rt then
				local heatFrac = math.clamp((rt.heat or 0) / 100, 0, 1)
				ammoOrHeatFill.Size = UDim2.fromScale(heatFrac, 1)
				ammoOrHeatFill.BackgroundColor3 = if rt.isOverheated then Theme.shieldWarning else Theme.plasmaViolet
				ammoOrHeatText.Text = if rt.isOverheated
					then "OVERHEATED! COOLING..."
					elseif rt.venting then string.format("VENTING PLASMA... %d%%", math.floor(rt.heat))
					else string.format("PLASMA HEAT %d%%  •  [R] VENT", math.floor(rt.heat))
			elseif rt then
				local magMax = math.max(1, rt.maxAmmo or 1)
				ammoOrHeatFill.Size = UDim2.fromScale(math.clamp((rt.ammo or 0) / magMax, 0, 1), 1)
				ammoOrHeatFill.BackgroundColor3 = Theme.shieldCyan
				ammoOrHeatText.Text = if rt.isReloading
					then "RELOADING..."
					else string.format("AMMO  %d / %d   •   [R] RELOAD", rt.ammo or 0, rt.maxAmmo or 0)
			end
		else
			activeGunName.Text = string.format("[%d] UNARMED", activeIdx)
			activeGunName.TextColor3 = Theme.textMuted
			ammoOrHeatFill.Size = UDim2.fromScale(0, 1)
			ammoOrHeatText.Text = "EQUIP WEAPON IN [TAB]"
		end

		holsteredGunName.Text = if otherGun
			then string.format("[%d] %s", otherIdx, otherGun.name)
			else string.format("[%d] Empty Weapon Slot", otherIdx)

		-- Belt Quickslots [3..6]
		for i = 1, 4 do
			local bItem = snap.belt[i]
			if bItem then
				local short = string.sub(bItem.name, 1, 8)
				beltLabels[i].Text = string.format("[%d] %s\nx%d", i + 2, short, bItem.stack or 1)
				beltLabels[i].TextColor3 = Theme.textPrimary
			else
				beltLabels[i].Text = string.format("[%d]\n--", i + 2)
				beltLabels[i].TextColor3 = Theme.textMuted
			end
		end

		local ordTag = if snap.ordnanceId == "EmpGrenade" then "EMP" else "FRAG"
		if (snap.ordnanceCooldown or 0) > 0 then
			ordLabel.Text = string.format("[Q] %s\n%.0fs", ordTag, snap.ordnanceCooldown)
			ordLabel.TextColor3 = Theme.textMuted
		else
			ordLabel.Text = string.format("[Q] %s\nREADY", ordTag)
			ordLabel.TextColor3 = Theme.shieldCyan
		end

		-- Reticle visibility & prompt
		reticleRoot.Visible = not ClientStore.ui.inventoryOpen and ClientStore.ui.raidSummary == nil
		if ClientStore.ui.interactPrompt and not ClientStore.ui.inventoryOpen then
			interactBox.Visible = true
			interactLbl.Text = ClientStore.ui.interactPrompt
		else
			interactBox.Visible = false
		end
	end

	ClientStore.subscribe(refreshFromStore)
	refreshFromStore()

	actor.onUpdate = function(_dt: number)
		local now = os.clock()
		if hitmarkerHideAt > 0 and now >= hitmarkerHideAt then
			hitmarkerHideAt = 0
			hitmarkerLbl.Visible = false
		end
		if toastHideAt > 0 and now >= toastHideAt then
			toastHideAt = 0
			toastLbl.Visible = false
		end

		local gap = math.floor(8 + ClientStore.ui.reticleBloom * 14)
		tickTop.Position = UDim2.fromOffset(29, 29 - gap - 8)
		tickBot.Position = UDim2.fromOffset(29, 29 + gap)
		tickLeft.Position = UDim2.fromOffset(29 - gap - 8, 29)
		tickRight.Position = UDim2.fromOffset(29 + gap, 29)
	end

	local function flashHitmarker(info: { [string]: any })
		hitmarkerLbl.Visible = true
		hitmarkerHideAt = os.clock() + 0.45
		local dmg = tostring(info.damage or 0)
		if info.killed then
			hitmarkerLbl.Text = "✕ ELIMINATED (" .. dmg .. ")"
			hitmarkerLbl.TextColor3 = Theme.positiveGreen
		elseif info.shieldPopped then
			hitmarkerLbl.Text = "⚡ SHIELD POP! (" .. dmg .. ")"
			hitmarkerLbl.TextColor3 = Theme.shieldCyan
		elseif info.isCrit then
			hitmarkerLbl.Text = "★ CRIT " .. dmg
			hitmarkerLbl.TextColor3 = Theme.scrapAmber
		elseif info.shieldHit then
			hitmarkerLbl.Text = "◈ " .. dmg
			hitmarkerLbl.TextColor3 = Theme.shieldCyan
		else
			hitmarkerLbl.Text = "• " .. dmg
			hitmarkerLbl.TextColor3 = Theme.textPrimary
		end
	end

	local function showToast(text: string, tone: string?)
		toastLbl.Visible = true
		toastLbl.Text = text
		toastHideAt = os.clock() + 3.2
		if tone == "error" then
			toastLbl.TextColor3 = Theme.negativeRed
		elseif tone == "success" then
			toastLbl.TextColor3 = Theme.positiveGreen
		else
			toastLbl.TextColor3 = Theme.scrapAmber
		end
	end

	local function updateRadarHeading(cameraLookXZ: Vector2, playerPos: Vector3)
		local range = Config.hud.motionTrackerRangeStuds
		local radiusPx = 68
		local fwdX, fwdZ = cameraLookXZ.X, cameraLookXZ.Y
		local rightX, rightZ = -fwdZ, fwdX

		local used = 0
		-- Enemy blips (red / orange for boss)
		for _, blip in ipairs(ClientStore.world.radarBlips) do
			if used >= #radarDots then
				break
			end
			local dx = blip.x - playerPos.X
			local dz = blip.z - playerPos.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= range and math.abs(blip.y - playerPos.Y) < 40 then
				used += 1
				local localX = (dx * rightX + dz * rightZ) / range
				local localY = -(dx * fwdX + dz * fwdZ) / range
				local dot = radarDots[used]
				dot.Visible = true
				dot.BackgroundColor3 = if blip.boss then Theme.scrapAmber else Theme.healthRed
				dot.Position = UDim2.fromOffset(74 + math.floor(localX * radiusPx), 74 + math.floor(localY * radiusPx))
			end
		end

		-- Extraction Beacon direction markers on outer rim (cyan/green)
		if ClientStore.snapshot.inRaid then
			for _, b in ipairs(ClientStore.world.beacons) do
				if used >= #radarDots then
					break
				end
				local dx = b.x - playerPos.X
				local dz = b.z - playerPos.Z
				local dist = math.max(1, math.sqrt(dx * dx + dz * dz))
				local clamped = math.min(1, dist / (range * 3))
				used += 1
				local localX = ((dx / dist) * rightX + (dz / dist) * rightZ) * clamped
				local localY = -((dx / dist) * fwdX + (dz / dist) * fwdZ) * clamped
				local dot = radarDots[used]
				dot.Visible = true
				dot.BackgroundColor3 = if b.state == "BoardingWindow" then Theme.positiveGreen else Theme.shieldCyan
				dot.Position = UDim2.fromOffset(74 + math.floor(localX * radiusPx), 74 + math.floor(localY * radiusPx))
			end
		end

		for i = used + 1, #radarDots do
			radarDots[i].Visible = false
		end
	end

	return {
		actor = actor,
		flashHitmarker = flashHitmarker,
		showToast = showToast,
		updateRadarHeading = updateRadarHeading,
	}
end

return CombatHudActor
