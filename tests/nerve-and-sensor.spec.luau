-- Unit specs for Nintendo `Nerve` state machine (`OdysseyDecomp` pattern) & `Sensor` world.
local actor = { log = {} }
local keeper = Nerve.new(actor, "Idle", {
	Idle = function(self, k, _dt)
		if k:isFirstStep() then
			table.insert(self.log, "Idle:enter")
		end
		if k:isGreaterEqualStep(2) then
			k:setNerve("Charge")
		end
	end,
	Charge = function(self, k, _dt)
		if k:isFirstStep() then
			table.insert(self.log, "Charge:enter")
		end
		if k:isGreaterEqualTime(1.0) then
			k:setNerve("Fire")
		end
	end,
	Fire = function(self, k, _dt)
		if k:isFirstStep() then
			table.insert(self.log, "Fire:enter")
		end
	end,
})

keeper:update(0.2) -- step 0 -> 1
assert(keeper:getState() == "Idle" and keeper:getStep() == 1, "Nerve advances step in Idle")
keeper:update(0.2) -- step 1 -> 2
keeper:update(0.2) -- step 2 triggers transition to Charge
assert(keeper:getState() == "Charge", "Nerve transitions to Charge on step >= 2")
keeper:update(0.6) -- Charge step 0 -> ends at 0.6s
assert(keeper:getState() == "Charge", "Nerve stays in Charge before 1.0s")
keeper:update(0.5) -- Charge step 1 -> ends at 1.1s
keeper:update(0.1) -- Charge sees 1.1s >= 1.0s -> queues Fire
assert(keeper:getState() == "Fire", "Nerve transitions to Fire once elapsed >= 1.0s")
keeper:update(0.1) -- Fire step 0 runs!
assert(actor.log[1] == "Idle:enter" and actor.log[2] == "Charge:enter" and actor.log[3] == "Fire:enter", "isFirstStep fires once per state")

-- Sensor world spatial & team filtering
local world = Sensor.newWorld()
local receivedDamage = 0
world:register({
	id = "enm_1_head",
	actorId = "enm_1",
	sensorType = "CombatHead",
	team = "Enemy",
	positionGetter = function()
		return { X = 10, Y = 0, Z = 0 }
	end,
	radius = 1.5,
	onMessage = function(_s, msg)
		if msg.kind == "Damage" then
			receivedDamage += (msg.payload and msg.payload.amount or 0)
			return true
		end
		return false
	end,
})
world:register({
	id = "ally_1_body",
	actorId = "ally_1",
	sensorType = "CombatHead",
	team = "Player",
	positionGetter = function()
		return { X = 8, Y = 0, Z = 0 }
	end,
	radius = 1.5,
})

local hits = world:querySphere({ X = 0, Y = 0, Z = 0 }, 15, "CombatHead", "Player")
assert(#hits == 1 and hits[1].id == "enm_1_head", "Sensor querySphere filters by type and excludes friendly team")
assert(world:sendMessage("enm_1_head", { kind = "Damage", payload = { amount = 42 } }) == true, "Sensor delivers message")
assert(receivedDamage == 42, "Sensor receiver processed payload")

print("PASS Nerve & Sensor: state transitions and decoupled messaging verified")
