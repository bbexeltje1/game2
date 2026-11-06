--!strict
-- Clean-room Luau implementation of Nintendo's `al::LayoutActor` UI component base
-- (studied from MonsterDruide1/OdysseyDecomp `lib/al/Library/Layout/LayoutActor.h`).
-- Pairs a root Roblox GuiObject with a deterministic Nerve lifecycle:
--   "Hidden" -> "Appearing" -> "Active" -> "Disappearing"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nerve = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("Core", 10):WaitForChild("Nerve", 10))

export type LayoutActorObj = {
	name: string,
	root: Frame,
	visible: boolean,
	nerve: Nerve.NerveKeeper<any>,
	onUpdate: ((dt: number) -> ())?,
	appear: (self: LayoutActorObj) -> (),
	disappear: (self: LayoutActorObj) -> (),
	toggle: (self: LayoutActorObj) -> boolean,
	isOpen: (self: LayoutActorObj) -> boolean,
	update: (self: LayoutActorObj, dt: number) -> (),
}

local LayoutActor = {}

local LAYOUT_NERVES: { [string]: Nerve.NerveHandler<LayoutActorObj> } = {
	Hidden = function(self, keeper, _dt)
		if keeper:isFirstStep() then
			self.visible = false
			self.root.Visible = false
		end
	end,

	Appearing = function(self, keeper, dt)
		if keeper:isFirstStep() then
			self.visible = true
			self.root.Visible = true
		end
		if self.onUpdate then
			self.onUpdate(dt)
		end
		if keeper:isGreaterEqualTime(0.10) then
			keeper:setNerve("Active")
		end
	end,

	Active = function(self, _keeper, dt)
		if self.onUpdate then
			self.onUpdate(dt)
		end
	end,

	Disappearing = function(self, keeper, _dt)
		if keeper:isGreaterEqualTime(0.08) then
			self.visible = false
			self.root.Visible = false
			keeper:setNerve("Hidden")
		end
	end,
}

function LayoutActor.new(name: string, root: Frame, startVisible: boolean?): LayoutActorObj
	local initVis = (startVisible == true)
	root.Visible = initVis

	local actor: any = {
		name = name,
		root = root,
		visible = initVis,
		onUpdate = nil,
	}

	actor.nerve = Nerve.new(actor, if initVis then "Active" else "Hidden", LAYOUT_NERVES)

	function actor:appear()
		if not self.visible then
			self.visible = true
			self.root.Visible = true
			self.nerve:setNerve("Appearing")
		end
	end

	function actor:disappear()
		if self.visible then
			self.visible = false
			self.root.Visible = false
			self.nerve:setNerve("Hidden")
		end
	end

	function actor:toggle(): boolean
		if self.visible then
			self:disappear()
		else
			self:appear()
		end
		return self.visible
	end

	function actor:isOpen(): boolean
		return self.visible
	end

	function actor:update(dt: number)
		self.nerve:update(dt)
	end

	return actor :: LayoutActorObj
end

return LayoutActor
