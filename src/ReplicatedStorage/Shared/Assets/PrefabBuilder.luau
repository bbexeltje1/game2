--!strict
-- Graybox-First (`BasePart`) Procedural Asset Factory & Model-Swap Registry.
--
-- Every weapon, enemy, loot container, drop beam, extraction beacon, and bunker station is built
-- here behind canonical asset IDs. If an authored `Model` with the same name is later placed inside
-- `ReplicatedStorage.Assets`, `PrefabBuilder` clones that high-detail asset automatically without
-- changing a single line of gameplay code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrefabBuilder = {}

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function findCustomOverride(assetId: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then
		local found = assetsFolder:FindFirstChild(assetId)
		if found and found:IsA("Model") then
			return found:Clone()
		end
	end
	return nil
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	anchored: boolean?,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = if anchored ~= nil then anchored else true
	p.CanCollide = if canCollide ~= nil then canCollide else false
	p.Parent = parent
	return p
end

local function weldParts(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
end

local function addAttachment(parent: BasePart, name: string, offset: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.Name = name
	att.Position = offset
	att.Parent = parent
	return att
end

-- Builds silhouette-distinct graybox weapon models with mandatory Handle + Muzzle/Grip/Sight attachments.
function PrefabBuilder.buildWeapon(weaponId: string): Model
	local assetId = "Weapon." .. weaponId
	local custom = findCustomOverride(assetId)
	if custom then
		return custom
	end

	local model = Instance.new("Model")
	model.Name = assetId

	-- Distinct proportions and accent colors per weapon archetype
	local length = 3.0
	local bodyColor = Color3.fromRGB(62, 68, 78)
	local accentColor = Color3.fromRGB(215, 162, 68)
	local hasScope = false
	local isLauncher = false
	local isPlasma = false

	if weaponId == "BR55Burst" then
		length = 3.3
		hasScope = true
		accentColor = Color3.fromRGB(110, 185, 255)
	elseif weaponId == "SolCoilCarbine" then
		length = 2.8
		bodyColor = Color3.fromRGB(44, 62, 98)
		accentColor = Color3.fromRGB(64, 232, 255)
		isPlasma = true
	elseif weaponId == "TrenchSweeper" then
		length = 3.1
		bodyColor = Color3.fromRGB(82, 68, 58)
		accentColor = Color3.fromRGB(235, 118, 52)
	elseif weaponId == "ViperPDW" then
		length = 2.0
		accentColor = Color3.fromRGB(152, 235, 112)
	elseif weaponId == "FerroRail" then
		length = 4.4
		hasScope = true
		bodyColor = Color3.fromRGB(48, 52, 62)
		accentColor = Color3.fromRGB(255, 196, 72)
	elseif weaponId == "M6DSidearm" then
		length = 1.35
		bodyColor = Color3.fromRGB(145, 152, 165)
		accentColor = Color3.fromRGB(72, 195, 255)
	elseif weaponId == "ArcMortar" then
		length = 3.8
		isLauncher = true
		bodyColor = Color3.fromRGB(72, 64, 82)
		accentColor = Color3.fromRGB(215, 95, 255)
	end

	local origin = CFrame.new(0, 0, 0)
	local handle = makePart(
		model,
		"Handle",
		Vector3.new(0.36, 0.52, length),
		origin,
		bodyColor,
		Enum.Material.Metal,
		false,
		false
	)
	handle.Massless = true
	model.PrimaryPart = handle

	local barrelWidth = if isLauncher then 0.55 else 0.20
	local barrel = makePart(
		model,
		"Barrel",
		Vector3.new(barrelWidth, barrelWidth, length * 0.55),
		origin * CFrame.new(0, 0.08, -length * 0.55),
		Color3.fromRGB(36, 40, 46),
		Enum.Material.Metal,
		false,
		false
	)
	barrel.Massless = true
	weldParts(handle, barrel)

	local accentStrip = makePart(
		model,
		"AccentCore",
		Vector3.new(0.40, 0.14, length * 0.55),
		origin * CFrame.new(0, 0.18, -0.15),
		accentColor,
		if isPlasma then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		false,
		false
	)
	accentStrip.Massless = true
	weldParts(handle, accentStrip)

	if hasScope then
		local scope = makePart(
			model,
			"OpticScope",
			Vector3.new(0.24, 0.24, length * 0.34),
			origin * CFrame.new(0, 0.42, -0.1),
			Color3.fromRGB(28, 32, 38),
			Enum.Material.Metal,
			false,
			false
		)
		scope.Massless = true
		weldParts(handle, scope)
	end

	addAttachment(handle, "MuzzleAttachment", Vector3.new(0, 0.08, -length * 0.82))
	addAttachment(handle, "GripAttachment", Vector3.new(0, -0.18, length * 0.18))
	addAttachment(handle, "OffhandAttachment", Vector3.new(0, -0.10, -length * 0.28))
	addAttachment(handle, "SightAttachment", Vector3.new(0, 0.42, 0))

	return model
end

-- Builds a graybox bipedal/boss enemy rig with Root, HeadHitbox, TorsoHitbox, ShieldBubblePart,
-- and floating Shield + Health BillboardGui.
function PrefabBuilder.buildEnemyRig(spec: {
	id: string,
	name: string,
	scale: number,
	bodyColor: { r: number, g: number, b: number },
	accentColor: { r: number, g: number, b: number },
	hasShield: boolean,
	hasFrontPlate: boolean?,
	isBoss: boolean?,
}): Model
	local assetId = "Enemy." .. spec.id
	local custom = findCustomOverride(assetId)
	if custom then
		return custom
	end

	local s = spec.scale or 1.0
	local model = Instance.new("Model")
	model.Name = spec.name

	local basePos = CFrame.new(0, 3.0 * s, 0)
	local root = makePart(
		model,
		"Root",
		Vector3.new(2.2 * s, 2.8 * s, 1.3 * s),
		basePos,
		rgb(spec.bodyColor),
		Enum.Material.Metal,
		true,
		true
	)
	model.PrimaryPart = root

	local torso = makePart(
		model,
		"TorsoHitbox",
		Vector3.new(2.3 * s, 2.6 * s, 1.4 * s),
		basePos,
		rgb(spec.bodyColor),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	torso.Transparency = 0.15

	local head = makePart(
		model,
		"HeadHitbox",
		Vector3.new(1.35 * s, 1.35 * s, 1.35 * s),
		basePos * CFrame.new(0, 2.15 * s, 0),
		Color3.fromRGB(48, 52, 60),
		Enum.Material.Metal,
		true,
		false
	)

	local visor = makePart(
		model,
		"Visor",
		Vector3.new(1.1 * s, 0.38 * s, 0.2 * s),
		basePos * CFrame.new(0, 2.2 * s, -0.68 * s),
		rgb(spec.accentColor),
		Enum.Material.Neon,
		true,
		false
	)

	local legs = makePart(
		model,
		"Legs",
		Vector3.new(2.0 * s, 1.8 * s, 1.1 * s),
		basePos * CFrame.new(0, -2.1 * s, 0),
		Color3.fromRGB(42, 44, 50),
		Enum.Material.SmoothPlastic,
		true,
		false
	)

	if spec.hasFrontPlate then
		makePart(
			model,
			"FrontArmorPlate",
			Vector3.new(2.7 * s, 3.2 * s, 0.35 * s),
			basePos * CFrame.new(0, -0.1 * s, -0.9 * s),
			Color3.fromRGB(68, 72, 80),
			Enum.Material.DiamondPlate,
			true,
			false
		)
		makePart(
			model,
			"WeakpointCore",
			Vector3.new(1.0 * s, 1.2 * s, 0.45 * s),
			basePos * CFrame.new(0, 0.3 * s, 0.85 * s),
			Color3.fromRGB(255, 138, 42),
			Enum.Material.Neon,
			true,
			false
		)
	end

	-- Halo Energy Shield Bubble (visible translucent cyan shell while shield > 0)
	local shieldBubble = makePart(
		model,
		"ShieldBubblePart",
		Vector3.new(4.4 * s, 6.4 * s, 3.6 * s),
		basePos * CFrame.new(0, 0.1 * s, 0),
		Color3.fromRGB(70, 208, 255),
		Enum.Material.ForceField,
		true,
		false
	)
	shieldBubble.Shape = Enum.PartType.Ball
	shieldBubble.Transparency = if spec.hasShield then 0.62 else 1.0

	addAttachment(head, "HealthBarAnchor", Vector3.new(0, 1.4 * s, 0))

	-- Floating Name + Shield Bar + Health Bar Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "VitalityBillboard"
	bb.Size = if spec.isBoss then UDim2.fromOffset(220, 48) else UDim2.fromOffset(145, 36)
	bb.StudsOffset = Vector3.new(0, 3.6 * s, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = if spec.isBoss then 180 else 110
	bb.Adornee = head
	bb.Parent = model

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLabel"
	nameLbl.Size = UDim2.new(1, 0, 0, 16)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = if spec.isBoss then 14 else 12
	nameLbl.TextColor3 = if spec.isBoss then Color3.fromRGB(255, 168, 68) else Color3.fromRGB(240, 244, 252)
	nameLbl.TextStrokeTransparency = 0.35
	nameLbl.Text = spec.name
	nameLbl.Parent = bb

	local shieldBg = Instance.new("Frame")
	shieldBg.Name = "ShieldBg"
	shieldBg.Size = UDim2.new(1, 0, 0, 6)
	shieldBg.Position = UDim2.fromOffset(0, 18)
	shieldBg.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
	shieldBg.BorderSizePixel = 0
	shieldBg.Parent = bb

	local shieldFill = Instance.new("Frame")
	shieldFill.Name = "ShieldFill"
	shieldFill.Size = UDim2.fromScale(if spec.hasShield then 1 else 0, 1)
	shieldFill.BackgroundColor3 = Color3.fromRGB(76, 212, 255)
	shieldFill.BorderSizePixel = 0
	shieldFill.Parent = shieldBg

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HealthBg"
	hpBg.Size = UDim2.new(1, 0, 0, 7)
	hpBg.Position = UDim2.fromOffset(0, 26)
	hpBg.BackgroundColor3 = Color3.fromRGB(36, 20, 22)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = bb

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HealthFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(235, 78, 78)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	-- Keep clean offset metadata so EnemyService can reposition multi-part anchored rigs smoothly
	torso:SetAttribute("OffsetY", 0)
	head:SetAttribute("OffsetY", 2.15 * s)
	visor:SetAttribute("OffsetY", 2.2 * s)
	visor:SetAttribute("OffsetZ", -0.68 * s)
	legs:SetAttribute("OffsetY", -2.1 * s)
	shieldBubble:SetAttribute("OffsetY", 0.1 * s)

	return model
end

-- Builds world loot containers (SupplyCrate, MilitaryLocker, KeycardVault)
function PrefabBuilder.buildContainer(kind: string, cframe: CFrame, locked: boolean): Model
	local assetId = "Container." .. kind
	local custom = findCustomOverride(assetId)
	if custom then
		custom:PivotTo(cframe)
		return custom
	end

	local model = Instance.new("Model")
	model.Name = assetId

	local size = Vector3.new(4.8, 3.0, 3.2)
	local baseColor = Color3.fromRGB(76, 86, 72)
	local trimColor = Color3.fromRGB(195, 205, 110)

	if kind == "MilitaryLocker" then
		size = Vector3.new(4.2, 6.2, 2.8)
		baseColor = Color3.fromRGB(58, 68, 82)
		trimColor = Color3.fromRGB(82, 185, 255)
	elseif kind == "KeycardVault" then
		size = Vector3.new(6.8, 6.8, 4.4)
		baseColor = Color3.fromRGB(48, 44, 58)
		trimColor = if locked then Color3.fromRGB(255, 118, 54) else Color3.fromRGB(98, 245, 152)
	end

	local base = makePart(
		model,
		"Base",
		size,
		cframe * CFrame.new(0, size.Y * 0.5, 0),
		baseColor,
		Enum.Material.Metal,
		true,
		true
	)
	model.PrimaryPart = base

	local lid = makePart(
		model,
		"LidPivot",
		Vector3.new(size.X * 1.02, 0.45, size.Z * 1.02),
		cframe * CFrame.new(0, size.Y + 0.2, 0),
		Color3.fromRGB(38, 42, 50),
		Enum.Material.Metal,
		true,
		true
	)
	lid:SetAttribute("ClosedY", size.Y + 0.2)

	makePart(
		model,
		"AccentStrip",
		Vector3.new(size.X * 0.85, 0.35, size.Z + 0.12),
		cframe * CFrame.new(0, size.Y * 0.72, 0),
		trimColor,
		Enum.Material.Neon,
		true,
		false
	)

	addAttachment(base, "InteractAnchor", Vector3.new(0, 1.2, 0))
	addAttachment(base, "LootBeamAttachment", Vector3.new(0, size.Y * 0.5, 0))

	return model
end

-- Builds a dropped loot world parcel with Diablo-style vertical Rarity Light Pillar
function PrefabBuilder.buildLootDrop(itemName: string, rarityColor: { r: number, g: number, b: number }, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "WorldLootDrop"
	local col = rgb(rarityColor)

	local box = makePart(
		model,
		"Parcel",
		Vector3.new(1.8, 1.1, 1.4),
		CFrame.new(pos + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(42, 46, 56),
		Enum.Material.Metal,
		true,
		false
	)
	model.PrimaryPart = box

	makePart(
		model,
		"RarityTrim",
		Vector3.new(1.9, 0.22, 1.5),
		CFrame.new(pos + Vector3.new(0, 0.9, 0)),
		col,
		Enum.Material.Neon,
		true,
		false
	)

	local beam = makePart(
		model,
		"LootPillar",
		Vector3.new(0.28, 13, 0.28),
		CFrame.new(pos + Vector3.new(0, 7.0, 0)),
		col,
		Enum.Material.Neon,
		true,
		false
	)
	beam.Transparency = 0.35

	local bb = Instance.new("BillboardGui")
	bb.Name = "LootLabel"
	bb.Size = UDim2.fromOffset(180, 26)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 55
	bb.Adornee = box
	bb.Parent = model

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	lbl.BackgroundTransparency = 0.25
	lbl.BorderSizePixel = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextColor3 = col
	lbl.Text = itemName
	lbl.Parent = bb

	return model
end

-- Builds an Extraction Beacon pad + skybeam pylon + capture zone ring
function PrefabBuilder.buildExtractionBeacon(name: string, pos: Vector3, radius: number): Model
	local custom = findCustomOverride("POI.ExtractionBeacon")
	if custom then
		custom:PivotTo(CFrame.new(pos))
		return custom
	end

	local model = Instance.new("Model")
	model.Name = name

	local pad = makePart(
		model,
		"Pad",
		Vector3.new(14, 1.2, 14),
		CFrame.new(pos),
		Color3.fromRGB(48, 54, 66),
		Enum.Material.DiamondPlate,
		true,
		true
	)
	model.PrimaryPart = pad

	local pylon = makePart(
		model,
		"BeaconPylon",
		Vector3.new(2.2, 14, 2.2),
		CFrame.new(pos + Vector3.new(0, 7.5, 0)),
		Color3.fromRGB(65, 74, 88),
		Enum.Material.Metal,
		true,
		true
	)

	local skyBeam = makePart(
		model,
		"SkyBeam",
		Vector3.new(1.6, 220, 1.6),
		CFrame.new(pos + Vector3.new(0, 118, 0)),
		Color3.fromRGB(78, 215, 255),
		Enum.Material.Neon,
		true,
		false
	)
	skyBeam.Transparency = 0.72

	local ring = makePart(
		model,
		"ZoneRing",
		Vector3.new(0.4, radius * 2, radius * 2),
		CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(78, 215, 255),
		Enum.Material.Neon,
		true,
		false
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.78

	addAttachment(pylon, "SkyBeamAttachment", Vector3.new(0, 7, 0))
	addAttachment(pylon, "SirenAttachment", Vector3.new(0, 5, 0))

	local radVal = Instance.new("NumberValue")
	radVal.Name = "ZoneRadiusValue"
	radVal.Value = radius
	radVal.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Name = "BeaconBillboard"
	bb.Size = UDim2.fromOffset(240, 44)
	bb.StudsOffset = Vector3.new(0, 11, 0)
	bb.MaxDistance = 260
	bb.Adornee = pylon
	bb.Parent = model

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "StatusLabel"
	statusLbl.Size = UDim2.fromScale(1, 1)
	statusLbl.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	statusLbl.BackgroundTransparency = 0.2
	statusLbl.BorderSizePixel = 0
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextSize = 13
	statusLbl.TextColor3 = Color3.fromRGB(115, 228, 255)
	statusLbl.Text = name .. "\n[E] CALL EXTRACTION"
	statusLbl.Parent = bb

	return model
end

-- Builds a harvestable S.T.A.L.K.E.R.-inspired Anomaly Relic Cluster inside Hazard Zones
function PrefabBuilder.buildAnomalyNode(id: string, pos: Vector3): Model
	local custom = findCustomOverride("POI.AnomalyNode")
	if custom then
		custom:PivotTo(CFrame.new(pos))
		return custom
	end

	local model = Instance.new("Model")
	model.Name = id

	local pedestal = makePart(
		model,
		"Pedestal",
		Vector3.new(3.4, 0.8, 3.4),
		CFrame.new(pos),
		Color3.fromRGB(48, 44, 58),
		Enum.Material.Slate,
		true,
		true
	)
	model.PrimaryPart = pedestal

	local crystal = makePart(
		model,
		"CrystalCore",
		Vector3.new(1.5, 2.8, 1.5),
		CFrame.new(pos + Vector3.new(0, 2.4, 0)) * CFrame.Angles(math.rad(18), math.rad(35), math.rad(12)),
		Color3.fromRGB(188, 112, 255),
		Enum.Material.Neon,
		true,
		false
	)

	local bb = Instance.new("BillboardGui")
	bb.Name = "AnomalyLabel"
	bb.Size = UDim2.fromOffset(180, 28)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 65
	bb.Adornee = crystal
	bb.Parent = model

	local lbl = Instance.new("TextLabel")
	lbl.Name = "StatusText"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
	lbl.BackgroundTransparency = 0.2
	lbl.BorderSizePixel = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(205, 145, 255)
	lbl.Text = "★ ANOMALY RELIC [E] HARVEST"
	lbl.Parent = bb

	return model
end

-- Builds a graybox post-apocalyptic rusted car/truck hulk for Wasteland road cover
function PrefabBuilder.buildRustedVehicle(cframe: CFrame): Model
	local custom = findCustomOverride("Prop.RustedVehicle")
	if custom then
		custom:PivotTo(cframe)
		return custom
	end

	local model = Instance.new("Model")
	model.Name = "Prop.RustedVehicle"

	local chassis = makePart(
		model,
		"Chassis",
		Vector3.new(6.8, 2.4, 13.5),
		cframe * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(96, 68, 56),
		Enum.Material.CorrodedMetal,
		true,
		true
	)
	model.PrimaryPart = chassis

	makePart(
		model,
		"Cabin",
		Vector3.new(6.2, 2.2, 6.4),
		cframe * CFrame.new(0, 4.0, 0.8),
		Color3.fromRGB(78, 58, 50),
		Enum.Material.CorrodedMetal,
		true,
		true
	)

	return model
end

return PrefabBuilder
