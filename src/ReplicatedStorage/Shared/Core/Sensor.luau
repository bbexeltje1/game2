--!strict
-- Clean-room Luau implementation of Nintendo's `HitSensor` & `SensorMsg` decoupled actor
-- messaging (studied from OdysseyDecomp `lib/al/Library/HitSensor/` & BotW `ActorSystem`).
-- Gameplay never stores functions on Roblox Instances (Template Rule #4): actors register plain
-- Luau sensor records keyed by ID, allowing graybox `BasePart` models to be swapped freely.

export type SensorType = "CombatBody" | "CombatHead" | "Interact" | "Loot" | "Hazard" | "Extraction"

export type SensorMsg = {
	kind: string, -- "Damage" | "ShieldEmp" | "Interact" | "Pickup" | "HazardTick" | "Revive"
	sourceId: string?,
	payload: { [string]: any }?,
}

export type SensorReceiver = (sensor: SensorRecord, msg: SensorMsg) -> boolean

export type SensorRecord = {
	id: string,
	actorId: string,
	sensorType: SensorType,
	team: string, -- "Player" | "Enemy" | "Neutral" | "Dummy"
	positionGetter: () -> Vector3,
	radius: number,
	active: boolean,
	metadata: { [string]: any },
	onMessage: SensorReceiver?,
}

export type SensorWorld = {
	sensors: { [string]: SensorRecord },
	register: (
		self: SensorWorld,
		spec: {
			id: string,
			actorId: string,
			sensorType: SensorType,
			team: string,
			positionGetter: () -> Vector3,
			radius: number,
			metadata: { [string]: any }?,
			onMessage: SensorReceiver?,
		}
	) -> SensorRecord,
	unregister: (self: SensorWorld, id: string) -> (),
	unregisterActor: (self: SensorWorld, actorId: string) -> (),
	sendMessage: (self: SensorWorld, targetSensorId: string, msg: SensorMsg) -> boolean,
	querySphere: (
		self: SensorWorld,
		origin: Vector3,
		radius: number,
		filterType: SensorType?,
		excludeTeam: string?
	) -> { SensorRecord },
}

local Sensor = {}

local function distanceBetween(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Sensor.newWorld(): SensorWorld
	local world: any = {
		sensors = {},
	}

	function world:register(spec): SensorRecord
		local record: SensorRecord = {
			id = spec.id,
			actorId = spec.actorId,
			sensorType = spec.sensorType,
			team = spec.team,
			positionGetter = spec.positionGetter,
			radius = spec.radius,
			active = true,
			metadata = spec.metadata or {},
			onMessage = spec.onMessage,
		}
		self.sensors[spec.id] = record
		return record
	end

	function world:unregister(id: string)
		self.sensors[id] = nil
	end

	function world:unregisterActor(actorId: string)
		for id, rec in pairs(self.sensors) do
			if rec.actorId == actorId then
				self.sensors[id] = nil
			end
		end
	end

	function world:sendMessage(targetSensorId: string, msg: SensorMsg): boolean
		local target: SensorRecord? = self.sensors[targetSensorId]
		if not target or not target.active or not target.onMessage then
			return false
		end
		return target.onMessage(target, msg)
	end

	function world:querySphere(
		origin: Vector3,
		radius: number,
		filterType: SensorType?,
		excludeTeam: string?
	): { SensorRecord }
		local results: { SensorRecord } = {}
		for _, rec: SensorRecord in pairs(self.sensors) do
			if rec.active then
				if (filterType == nil or rec.sensorType == filterType) and (excludeTeam == nil or rec.team ~= excludeTeam) then
					local pos = rec.positionGetter()
					local d = distanceBetween(origin, pos)
					if d <= (radius + rec.radius) then
						table.insert(results, rec)
					end
				end
			end
		end
		return results
	end

	return world :: SensorWorld
end

return Sensor
