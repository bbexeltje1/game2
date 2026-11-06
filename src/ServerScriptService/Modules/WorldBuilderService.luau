--!strict
-- Procedural Graybox World Builder (`BasePart` architecture).
-- Constructs both the underground Bastion Bunker (Stash, Workbench, Vendor, Contracts, Airlocks,
-- and Firing Range) AND the 4-Zone Ashen Wasteland Surface in a single seamless Roblox place.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)
local PrefabBuilder = require(ReplicatedStorage.Shared.Assets.PrefabBuilder)

local WorldBuilderService = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Transparency = transparency or 0
	p.CanCollide = if canCollide ~= nil then canCollide else true
	p.Parent = parent
	return p
end

local function makeBanner(parent: BasePart, title: string, subtitle: string, accent: Color3, offsetStuds: number?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "StationBanner"
	bb.Size = UDim2.fromOffset(220, 48)
	bb.StudsOffset = Vector3.new(0, offsetStuds or 5.2, 0)
	bb.MaxDistance = 95
	bb.Adornee = parent
	bb.Parent = parent

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	bg.BackgroundTransparency = 0.16
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Parent = bg

	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.new(1, -10, 0, 22)
	t1.Position = UDim2.fromOffset(5, 4)
	t1.BackgroundTransparency = 1
	t1.Font = Enum.Font.GothamBold
	t1.TextSize = 13
	t1.TextColor3 = accent
	t1.Text = title
	t1.Parent = bg

	local t2 = Instance.new("TextLabel")
	t2.Size = UDim2.new(1, -10, 0, 18)
	t2.Position = UDim2.fromOffset(5, 25)
	t2.BackgroundTransparency = 1
	t2.Font = Enum.Font.GothamMedium
	t2.TextSize = 11
	t2.TextColor3 = Color3.fromRGB(215, 222, 235)
	t2.Text = "[E] " .. subtitle
	t2.Parent = bg
end

local function configureAtmosphere()
	Lighting.ClockTime = 16.6 -- Golden-dusk post-apocalyptic lighting
	Lighting.Brightness = 2.1
	Lighting.Ambient = Color3.fromRGB(58, 62, 72)
	Lighting.OutdoorAmbient = Color3.fromRGB(92, 86, 82)
	Lighting.FogEnd = 950
	Lighting.FogColor = Color3.fromRGB(122, 108, 96)
end

function WorldBuilderService.build(): {
	worldRoot: Folder,
	containersFolder: Folder,
	enemiesFolder: Folder,
	beaconsFolder: Folder,
	dropsFolder: Folder,
	stationParts: { [string]: BasePart },
}
	configureAtmosphere()

	local existing = Workspace:FindFirstChild("AshfallWorld")
	if existing then
		existing:Destroy()
	end
	local defaultBaseplate = Workspace:FindFirstChild("Baseplate")
	if defaultBaseplate then
		defaultBaseplate:Destroy()
	end

	local worldRoot = Instance.new("Folder")
	worldRoot.Name = "AshfallWorld"
	worldRoot.Parent = Workspace

	local bunkerFolder = Instance.new("Folder")
	bunkerFolder.Name = "BastionBunker"
	bunkerFolder.Parent = worldRoot

	local surfaceFolder = Instance.new("Folder")
	surfaceFolder.Name = "AshenWasteland"
	surfaceFolder.Parent = worldRoot

	local containersFolder = Instance.new("Folder")
	containersFolder.Name = "Containers"
	containersFolder.Parent = worldRoot

	local enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = worldRoot

	local beaconsFolder = Instance.new("Folder")
	beaconsFolder.Name = "ExtractionBeacons"
	beaconsFolder.Parent = worldRoot

	local dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "WorldDrops"
	dropsFolder.Parent = worldRoot

	-- =========================================================================
	-- 1. UNDERGROUND SAFE HUB: BASTION BUNKER (Y = -120)
	-- =========================================================================
	local by = WorldZones.Bunker.floorY
	part(bunkerFolder, "BunkerFloor", Vector3.new(110, 4, 140), CFrame.new(0, by - 2, -16), Color3.fromRGB(48, 52, 60), Enum.Material.Concrete)
	part(bunkerFolder, "BunkerCeiling", Vector3.new(110, 4, 140), CFrame.new(0, by + 24, -16), Color3.fromRGB(36, 40, 48), Enum.Material.Concrete)
	part(bunkerFolder, "WallNorth", Vector3.new(110, 26, 4), CFrame.new(0, by + 11, -86), Color3.fromRGB(56, 60, 70), Enum.Material.Concrete)
	part(bunkerFolder, "WallSouth", Vector3.new(110, 26, 4), CFrame.new(0, by + 11, 54), Color3.fromRGB(56, 60, 70), Enum.Material.Concrete)
	part(bunkerFolder, "WallWest", Vector3.new(4, 26, 140), CFrame.new(-55, by + 11, -16), Color3.fromRGB(56, 60, 70), Enum.Material.Concrete)
	part(bunkerFolder, "WallEast", Vector3.new(4, 26, 140), CFrame.new(55, by + 11, -16), Color3.fromRGB(56, 60, 70), Enum.Material.Concrete)

	-- SpawnLocation inside Bastion Bunker so every player boots cleanly inside the safe hub!
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "BastionSpawn"
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.CFrame = CFrame.new(WorldZones.Bunker.spawn.x, by + 0.5, WorldZones.Bunker.spawn.z)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(64, 152, 225)
	spawnLoc.Material = Enum.Material.Neon
	spawnLoc.Transparency = 0.45
	spawnLoc.Parent = bunkerFolder

	-- Warm Bunker overhead strip lights
	for _, zPos in ipairs({ -65, -35, -5, 25 }) do
		local lamp = part(
			bunkerFolder,
			"CeilingStripLight",
			Vector3.new(34, 0.6, 2.2),
			CFrame.new(0, by + 21.5, zPos),
			Color3.fromRGB(255, 224, 178),
			Enum.Material.Neon,
			0,
			false
		)
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.8
		pl.Range = 54
		pl.Color = Color3.fromRGB(255, 232, 200)
		pl.Parent = lamp
	end

	-- Firing Range safety divider & lane markings (North wing of Bunker)
	part(bunkerFolder, "FiringRangeBarrier", Vector3.new(44, 3.4, 2.0), CFrame.new(0, by + 1.7, -36), Color3.fromRGB(95, 82, 48), Enum.Material.DiamondPlate)
	local rangeSign = part(bunkerFolder, "RangeHeader", Vector3.new(26, 2.2, 1.0), CFrame.new(0, by + 11, -36), Color3.fromRGB(32, 36, 44), Enum.Material.Metal)
	makeBanner(rangeSign, "LIVE DPS FIRING RANGE", "Test Kinetic vs Plasma Shield Damage", Color3.fromRGB(78, 215, 255), 0)

	-- Interactive Bunker Stations
	local stationParts: { [string]: BasePart } = {}
	for _, st in ipairs(WorldZones.Bunker.stations) do
		local col = Color3.fromRGB(st.color.r, st.color.g, st.color.b)
		local isDeploy = (st.kind == "Deploy")
		local size = if isDeploy then Vector3.new(7.5, 1.2, 7.5) else Vector3.new(7.5, 5.2, 4.2)
		local yOffset = if isDeploy then 0.6 else 2.6
		local kiosk = part(
			bunkerFolder,
			st.id,
			size,
			CFrame.new(st.pos.x, by + yOffset, st.pos.z),
			if isDeploy then col else Color3.fromRGB(42, 48, 58),
			if isDeploy then Enum.Material.Neon else Enum.Material.Metal,
			if isDeploy then 0.30 else 0,
			true
		)
		if not isDeploy then
			part(
				bunkerFolder,
				st.id .. "_Screen",
				Vector3.new(6.2, 2.2, 0.3),
				CFrame.new(st.pos.x, by + 3.4, st.pos.z + (if st.pos.z < 0 then 2.15 else -2.15)),
				col,
				Enum.Material.Neon,
				0.15,
				false
			)
		end
		kiosk:SetAttribute("StationId", st.id)
		kiosk:SetAttribute("StationKind", st.kind)
		if st.zoneId then
			kiosk:SetAttribute("DeployZoneId", st.zoneId)
		end
		makeBanner(kiosk, st.title, st.subtitle, col, if isDeploy then 4.8 else 4.2)
		stationParts[st.id] = kiosk
	end

	-- =========================================================================
	-- 2. ASHEN WASTELAND SURFACE (4 Tiered Quadrants, 1040 x 1040 studs)
	-- =========================================================================
	for _, zone in pairs(WorldZones.Zones) do
		local zFolder = Instance.new("Folder")
		zFolder.Name = zone.id
		zFolder.Parent = surfaceFolder

		part(
			zFolder,
			"GroundPlate",
			Vector3.new(zone.size.x, 4, zone.size.z),
			CFrame.new(zone.center.x, -2, zone.center.z),
			Color3.fromRGB(zone.groundColor.r, zone.groundColor.g, zone.groundColor.b),
			Enum.Material.Slate
		)

		-- Return-to-Bunker Emergency Hatch at each Zone's Drop-In Pad (only usable when out of combat / full health, or visual landmark)
		local dropPad = part(
			zFolder,
			"DropInPad_" .. zone.id,
			Vector3.new(14, 0.8, 14),
			CFrame.new(zone.dropSpawn.x, 0.4, zone.dropSpawn.z),
			Color3.fromRGB(62, 132, 195),
			Enum.Material.DiamondPlate
		)
		makeBanner(dropPad, zone.name .. " (" .. zone.tierLabel .. ")", "Find Loot & Reach an Extraction Beacon!", Color3.fromRGB(130, 210, 255), 6)

		-- Scatter tactical waist-high & full-height graybox ruins/barriers for Halo cover firefights
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2
			local dist = 65 + (i % 3) * 58
			local cx = zone.center.x + math.cos(angle) * dist
			local cz = zone.center.z + math.sin(angle) * dist
			local rotY = angle + math.pi * 0.5
			part(
				zFolder,
				"CoverWall_" .. tostring(i),
				Vector3.new(14, 4.6, 2.4),
				CFrame.new(cx, 2.3, cz) * CFrame.Angles(0, rotY, 0),
				Color3.fromRGB(74, 72, 70),
				Enum.Material.Concrete
			)
			if i % 2 == 0 then
				-- Climbable/mantleable ruin platform beside cover
				part(
					zFolder,
					"RuinBlock_" .. tostring(i),
					Vector3.new(12, 6.2, 10),
					CFrame.new(cx + 8, 3.1, cz + 6),
					Color3.fromRGB(64, 62, 66),
					Enum.Material.Concrete
				)
			end
		end
	end

	-- Distinct Zone Landmarks & Graybox Props
	-- Zone 1: Collapsed Highway Overpass Deck + Rusted Vehicle Hulks
	part(surfaceFolder, "OverpassDeck", Vector3.new(180, 3.5, 28), CFrame.new(-260, 18, 260) * CFrame.Angles(0, math.rad(35), 0), Color3.fromRGB(82, 80, 78), Enum.Material.Concrete)
	part(surfaceFolder, "OverpassRamp", Vector3.new(54, 2.5, 24), CFrame.new(-188, 9, 210) * CFrame.Angles(0, math.rad(35), math.rad(-20)), Color3.fromRGB(82, 80, 78), Enum.Material.Concrete)
	for vIdx = 1, 4 do
		local veh = PrefabBuilder.buildRustedVehicle(
			CFrame.new(-195 - vIdx * 36, 0, 220 + (vIdx % 2) * 44) * CFrame.Angles(0, math.rad(vIdx * 47), 0)
		)
		veh.Parent = surfaceFolder
	end

	-- Zone 2: Rusted Rail Yard Shipping Containers + Climbable Sniper Watchtower
	for i = 1, 5 do
		part(
			surfaceFolder,
			"RailContainer_" .. tostring(i),
			Vector3.new(24, 9.5, 10),
			CFrame.new(220 + i * 28, 4.75, 240 + (i % 2) * 34) * CFrame.Angles(0, math.rad(i * 18), 0),
			if i % 2 == 0 then Color3.fromRGB(132, 64, 52) else Color3.fromRGB(58, 86, 112),
			Enum.Material.CorrodedMetal
		)
	end
	part(surfaceFolder, "WatchtowerPlatform", Vector3.new(18, 1.5, 18), CFrame.new(295, 14, 220), Color3.fromRGB(68, 72, 82), Enum.Material.DiamondPlate)
	part(surfaceFolder, "WatchtowerRamp", Vector3.new(6, 1.2, 28), CFrame.new(295, 7, 200) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(78, 82, 92), Enum.Material.DiamondPlate)

	-- Zone 3: Bio-Metro Arches + Glowing Spore Pods
	for i = 1, 4 do
		part(surfaceFolder, "MetroArch_" .. tostring(i), Vector3.new(34, 16, 5), CFrame.new(-220 - i * 36, 8, -220 - i * 32), Color3.fromRGB(52, 66, 58), Enum.Material.Concrete)
		local pod = part(surfaceFolder, "SporePod_" .. tostring(i), Vector3.new(4.5, 6.5, 4.5), CFrame.new(-235 - i * 34, 3.0, -205 - i * 30), Color3.fromRGB(115, 238, 92), Enum.Material.Neon, 0.25, true)
		pod.Shape = Enum.PartType.Ball
	end

	-- Zone 4: Shattered Reactor Cooling Tower & Glowing Core
	part(surfaceFolder, "ReactorCorePillar", Vector3.new(16, 48, 16), CFrame.new(345, 24, -345), Color3.fromRGB(255, 115, 42), Enum.Material.Neon, 0.25, true)
	part(surfaceFolder, "ReactorShieldWall1", Vector3.new(42, 22, 5), CFrame.new(345, 11, -305), Color3.fromRGB(48, 46, 54), Enum.Material.Concrete)
	part(surfaceFolder, "ReactorShieldWall2", Vector3.new(42, 22, 5), CFrame.new(345, 11, -385), Color3.fromRGB(48, 46, 54), Enum.Material.Concrete)

	-- Outer Wasteland Perimeter Walls so nobody falls into the void
	part(surfaceFolder, "PerimeterNorth", Vector3.new(1060, 36, 12), CFrame.new(0, 18, -526), Color3.fromRGB(44, 44, 48), Enum.Material.Rock)
	part(surfaceFolder, "PerimeterSouth", Vector3.new(1060, 36, 12), CFrame.new(0, 18, 526), Color3.fromRGB(44, 44, 48), Enum.Material.Rock)
	part(surfaceFolder, "PerimeterWest", Vector3.new(12, 36, 1060), CFrame.new(-526, 18, 0), Color3.fromRGB(44, 44, 48), Enum.Material.Rock)
	part(surfaceFolder, "PerimeterEast", Vector3.new(12, 36, 1060), CFrame.new(526, 18, 0), Color3.fromRGB(44, 44, 48), Enum.Material.Rock)

	-- Visual Hazard Zone Rings (Spore & Radiation Pockets)
	for _, hz in ipairs(WorldZones.HazardZones) do
		local ring = part(
			surfaceFolder,
			hz.id,
			Vector3.new(0.6, hz.radius * 2, hz.radius * 2),
			CFrame.new(hz.position.x, 0.35, hz.position.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(hz.color.r, hz.color.g, hz.color.b),
			Enum.Material.Neon,
			0.82,
			false
		)
		ring.Shape = Enum.PartType.Cylinder
	end

	return {
		worldRoot = worldRoot,
		containersFolder = containersFolder,
		enemiesFolder = enemiesFolder,
		beaconsFolder = beaconsFolder,
		dropsFolder = dropsFolder,
		stationParts = stationParts,
	}
end

return WorldBuilderService
