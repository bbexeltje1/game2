--!strict
-- Clean-room Luau implementation of Nintendo's `al::NerveKeeper` state machine pattern
-- (studied from MonsterDruide1/OdysseyDecomp `lib/al/Library/Nerve/NerveKeeper.h`).
-- Every actor, enemy AI, extraction beacon, weapon controller, and UI LayoutActor uses a
-- lightweight tick-counted Nerve state machine instead of ad-hoc boolean flags.

export type NerveHandler<T> = (owner: T, keeper: NerveKeeper<T>, dt: number) -> ()

export type NerveKeeper<T> = {
	owner: T,
	currentState: string,
	nextState: string?,
	step: number,
	elapsedInState: number,
	handlers: { [string]: NerveHandler<T> },
	setNerve: (self: NerveKeeper<T>, stateName: string) -> (),
	getState: (self: NerveKeeper<T>) -> string,
	getStep: (self: NerveKeeper<T>) -> number,
	getElapsed: (self: NerveKeeper<T>) -> number,
	isFirstStep: (self: NerveKeeper<T>) -> boolean,
	isGreaterEqualStep: (self: NerveKeeper<T>, targetStep: number) -> boolean,
	isGreaterEqualTime: (self: NerveKeeper<T>, seconds: number) -> boolean,
	update: (self: NerveKeeper<T>, dt: number) -> (),
}

local Nerve = {}

function Nerve.new<T>(
	owner: T,
	initialState: string,
	handlers: { [string]: NerveHandler<T> }
): NerveKeeper<T>
	assert(handlers[initialState] ~= nil, "Nerve.new: missing handler for initial state '" .. tostring(initialState) .. "'")

	local keeper: any = {
		owner = owner,
		currentState = initialState,
		nextState = initialState, -- triggers step 0 cleanly on the first update()
		step = 0,
		elapsedInState = 0,
		handlers = handlers,
	}

	function keeper:setNerve(stateName: string)
		if self.handlers[stateName] == nil then
			error("Nerve:setNerve unknown state '" .. tostring(stateName) .. "'")
		end
		self.nextState = stateName
	end

	function keeper:getState(): string
		return self.currentState
	end

	function keeper:getStep(): number
		return self.step
	end

	function keeper:getElapsed(): number
		return self.elapsedInState
	end

	function keeper:isFirstStep(): boolean
		return self.step == 0
	end

	function keeper:isGreaterEqualStep(targetStep: number): boolean
		return self.step >= targetStep
	end

	function keeper:isGreaterEqualTime(seconds: number): boolean
		return self.elapsedInState >= seconds
	end

	function keeper:update(dt: number)
		-- Apply pending transition before running the state body so step == 0 runs once.
		if self.nextState ~= nil then
			self.currentState = self.nextState
			self.nextState = nil
			self.step = 0
			self.elapsedInState = 0
		end

		local handler = self.handlers[self.currentState]
		if handler then
			handler(self.owner, self, dt)
		end

		-- If the handler did not queue another transition, advance the step & timer.
		if self.nextState == nil then
			self.step += 1
			self.elapsedInState += dt
		else
			-- Immediately settle queued state for callers inspecting getState() right after update,
			-- while preserving nextState so the next update() sees step == 0.
			self.currentState = self.nextState
		end
	end

	return keeper :: NerveKeeper<T>
end

return Nerve
