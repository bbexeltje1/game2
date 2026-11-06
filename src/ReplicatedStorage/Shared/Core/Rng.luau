--!strict
-- Deterministic pseudo-random generator (32-bit xorshift) used for Diablo loot rolls,
-- weapon pellet spread, and reproducible unit tests across client, server, and luau-web.

export type RngStream = {
	state: number,
	nextU32: (self: RngStream) -> number,
	nextFloat: (self: RngStream) -> number,
	nextRange: (self: RngStream, minVal: number, maxVal: number) -> number,
	nextInt: (self: RngStream, minVal: number, maxVal: number) -> number,
	weightedKey: <K>(self: RngStream, weights: { { key: K, weight: number } }) -> K,
}

local Rng = {}

function Rng.new(seed: number?): RngStream
	local initial = math.floor(math.abs(seed or 13379001)) % 4294967295
	if initial == 0 then
		initial = 2463534242
	end

	local stream: any = {
		state = initial,
	}

	function stream:nextU32(): number
		local x = self.state
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		if x == 0 then
			x = 2463534242
		end
		self.state = x
		return x
	end

	function stream:nextFloat(): number
		return self:nextU32() / 4294967296
	end

	function stream:nextRange(minVal: number, maxVal: number): number
		if maxVal <= minVal then
			return minVal
		end
		return minVal + (maxVal - minVal) * self:nextFloat()
	end

	function stream:nextInt(minVal: number, maxVal: number): number
		if maxVal <= minVal then
			return math.floor(minVal)
		end
		local span = (math.floor(maxVal) - math.floor(minVal)) + 1
		return math.floor(minVal) + (self:nextU32() % span)
	end

	function stream:weightedKey(entries: { { key: any, weight: number } }): any
		local total = 0
		for _, entry in ipairs(entries) do
			if entry.weight > 0 then
				total += entry.weight
			end
		end
		if total <= 0 then
			return entries[1] and entries[1].key or nil
		end
		local roll = self:nextFloat() * total
		local acc = 0
		for _, entry in ipairs(entries) do
			if entry.weight > 0 then
				acc += entry.weight
				if roll <= acc then
					return entry.key
				end
			end
		end
		return entries[#entries].key
	end

	return stream :: RngStream
end

return Rng
