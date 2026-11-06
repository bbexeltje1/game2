--!strict
-- Dynamic Wasteland World Event Service (`SupplyDropService`).
-- Drops Halo ODST-style Orbital Supply Pods into surface sectors with a golden sky-flare,
-- Elite Raider ambush guards, and a 3D HUD Waypoint (`buildSupplyDropSnapshot`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rng = require(ReplicatedStorage.Shared.Core.Rng)
local WorldZones = require(ReplicatedStorage.Shared.World.WorldZones)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LootContainerService = require(script.Parent.LootContainerService)
local EnemyService = require(script.Parent.EnemyService)

type DropSite = {
	zoneId: string,
	zoneName: string,
	pos: Vector3,
	tc: string,
	guards: { string },
}

local DROP_SITES: { DropSite } = {
	{
		zoneId = "Zone1",
		zoneName = "Collapsed Overpass",
		pos = Vector3.new(-225, 0, 290),
		tc = "Tier2_RailYard",
		guards = { "AshScavenger", "AegisEnforcer" },
	},
	{
		zoneId = "Zone2",
		zoneName = "Rusted Rail Yard",
		pos = Vector3.new(255, 0, 250),
		tc = "Tier3_BioMetro",
		guards = { "AegisEnforcer", "RaiderMarksman" },
	},
	{
		zoneId = "Zone3",
		zoneName = "Spore Bio-Metro",
		pos = Vector3.new(-280, 0, -250),
		tc = "Tier4_Reactor",
		guards = { "SporeHazmat", "AegisEnforcer" },
	},
	{
		zoneId = "Zone4",
		zoneName = "Reactor Crater",
		pos = Vector3.new(255, 0, -255),
		tc = "Boss_WardenGoliath",
		guards = { "ScrapJuggernaut", "AegisEnforcer" },
	},
}

local activePod: {
	id: string,
	zoneName: string,
	pos: Vector3,
	expiresAt: number,
}? = nil

local nextDropAt = 0
local dropRng = Rng.new(31415926)
local podSeq = 0

local SupplyDropService = {}

function SupplyDropService.init()
	-- First Orbital Supply Pod arrives 22 seconds into the session so Studio playtesters can experience it fast!
	nextDropAt = os.clock() + 22
end

function SupplyDropService.tick(_dt: number)
	local now = os.clock()

	if activePod and now >= activePod.expiresAt then
		LootContainerService.removeDynamicContainer(activePod.id)
		activePod = nil
		nextDropAt = now + 45
	end

	if not activePod and now >= nextDropAt then
		local site = DROP_SITES[dropRng:nextInt(1, #DROP_SITES)]
		podSeq += 1
		local podId = "SupplyPod_" .. tostring(podSeq)
		LootContainerService.spawnDynamicSupplyPod(
			podId,
			"ORBITAL SUPPLY POD • " .. string.upper(site.zoneName),
			site.pos,
			site.tc
		)
		-- Spawn an affixed Elite Champion + escort guarding the freshly crashed Supply Pod!
		for idx, arch in ipairs(site.guards) do
			local offset = Vector3.new(math.cos(idx * 2.4) * 9, 1, math.sin(idx * 2.4) * 9)
			local guard = EnemyService.spawnEnemy(
				arch,
				site.pos + offset,
				nil,
				if idx == 1 then "Overcharged" else nil
			)
			guard.nerve:setNerve("Engage")
		end

		activePod = {
			id = podId,
			zoneName = site.zoneName,
			pos = site.pos,
			expiresAt = now + 95,
		}

		for _, p in ipairs(Players:GetPlayers()) do
			PlayerDataService.notify(
				p,
				"★ ORBITAL SUPPLY POD CRASHED IN " .. string.upper(site.zoneName) .. "! ★",
				"success"
			)
		end
	end
end

function SupplyDropService.buildSnapshot(): { [string]: any }?
	if not activePod then
		return nil
	end
	return {
		id = activePod.id,
		zoneName = activePod.zoneName,
		timer = math.max(0, math.ceil(activePod.expiresAt - os.clock())),
		x = math.floor(activePod.pos.X),
		y = math.floor(activePod.pos.Y),
		z = math.floor(activePod.pos.Z),
	}
end

return SupplyDropService
