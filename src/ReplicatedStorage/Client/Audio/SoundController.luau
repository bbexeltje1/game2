--!strict
-- Clean-room Nintendo `AudioKeeper` + Halo HUD Audio Synthesizer (`SoundController`).
-- Uses 100% built-in `rbxasset://sounds/...` Studio assets with pitch/volume shaping so every
-- gunshot, plasma bolt, Halo shield warning beep, shield pop, recharge hum, Diablo rarity chime,
-- and 2D grid click works offline in Roblox Studio with zero asset-permission errors.

local SoundService = game:GetService("SoundService")

export type CueName =
	"ShootKinetic"
	| "ShootPlasma"
	| "ShootRail"
	| "ShootScatter"
	| "ShootLauncher"
	| "HitNormal"
	| "HitCrit"
	| "ShieldPop"
	| "ShieldLowBeep"
	| "ShieldRecharge"
	| "Reload"
	| "PlasmaVent"
	| "UiClick"
	| "UiRotate"
	| "UiEquip"
	| "UiError"
	| "LootCommon"
	| "LootHighRarity"
	| "ExtractionSiren"
	| "ExtractSuccess"

type CueSpec = {
	soundId: string,
	volume: number,
	speed: number,
}

local CUES: { [CueName]: CueSpec } = {
	ShootKinetic = { soundId = "rbxasset://sounds/collide.wav", volume = 0.42, speed = 1.55 },
	ShootPlasma = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.38, speed = 0.78 },
	ShootRail = { soundId = "rbxasset://sounds/Rocket shot.wav", volume = 0.52, speed = 1.75 },
	ShootScatter = { soundId = "rbxasset://sounds/collide.wav", volume = 0.58, speed = 0.88 },
	ShootLauncher = { soundId = "rbxasset://sounds/Rocket shot.wav", volume = 0.55, speed = 0.95 },

	HitNormal = { soundId = "rbxasset://sounds/clickfast.wav", volume = 0.36, speed = 1.35 },
	HitCrit = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.50, speed = 1.65 },
	ShieldPop = { soundId = "rbxasset://sounds/bass.mp3", volume = 0.65, speed = 1.25 },
	ShieldLowBeep = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.30, speed = 1.95 },
	ShieldRecharge = { soundId = "rbxasset://sounds/swoosh.wav", volume = 0.32, speed = 1.30 },

	Reload = { soundId = "rbxasset://sounds/Snap.mp3", volume = 0.45, speed = 1.05 },
	PlasmaVent = { soundId = "rbxasset://sounds/swoosh.wav", volume = 0.42, speed = 0.75 },

	UiClick = { soundId = "rbxasset://sounds/clickfast.wav", volume = 0.28, speed = 1.15 },
	UiRotate = { soundId = "rbxasset://sounds/Snap.mp3", volume = 0.32, speed = 1.40 },
	UiEquip = { soundId = "rbxasset://sounds/button.wav", volume = 0.38, speed = 1.10 },
	UiError = { soundId = "rbxasset://sounds/bass.mp3", volume = 0.35, speed = 0.68 },

	LootCommon = { soundId = "rbxasset://sounds/button.wav", volume = 0.35, speed = 1.30 },
	LootHighRarity = { soundId = "rbxasset://sounds/victory.ogg", volume = 0.48, speed = 1.35 },
	ExtractionSiren = { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.44, speed = 0.62 },
	ExtractSuccess = { soundId = "rbxasset://sounds/victory.ogg", volume = 0.60, speed = 1.0 },
}

local pool: { [CueName]: Sound } = {}
local initialized = false

local SoundController = {}

local function ensurePool()
	if initialized then
		return
	end
	initialized = true
	pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "AshfallAudioPool"
		folder.Parent = SoundService
		for cueName, spec in pairs(CUES) do
			local snd = Instance.new("Sound")
			snd.Name = cueName
			snd.SoundId = spec.soundId
			snd.Volume = spec.volume
			snd.PlaybackSpeed = spec.speed
			snd.Parent = folder
			pool[cueName :: CueName] = snd
		end
	end)
end

function SoundController.play(cue: CueName, pitchJitter: number?)
	ensurePool()
	local snd = pool[cue]
	if not snd then
		return
	end
	pcall(function()
		local base = CUES[cue]
		if pitchJitter and base then
			snd.PlaybackSpeed = base.speed + (math.random() - 0.5) * 2 * pitchJitter
		elseif base then
			snd.PlaybackSpeed = base.speed
		end
		snd:Play()
	end)
end

function SoundController.playWeaponFire(baseId: string)
	if baseId == "SolCoilCarbine" then
		SoundController.play("ShootPlasma", 0.06)
	elseif baseId == "FerroRail" then
		SoundController.play("ShootRail", 0.03)
	elseif baseId == "TrenchSweeper" then
		SoundController.play("ShootScatter", 0.05)
	elseif baseId == "ArcMortar" then
		SoundController.play("ShootLauncher", 0.04)
	else
		SoundController.play("ShootKinetic", 0.06)
	end
end

function SoundController.playHitmarker(isCrit: boolean, shieldPopped: boolean, killed: boolean)
	if shieldPopped then
		SoundController.play("ShieldPop", 0.04)
	elseif isCrit or killed then
		SoundController.play("HitCrit", 0.04)
	else
		SoundController.play("HitNormal", 0.05)
	end
end

function SoundController.playShieldPop()
	SoundController.play("ShieldPop", 0.03)
end

function SoundController.playLowShieldBeep()
	SoundController.play("ShieldLowBeep", 0.0)
end

function SoundController.playShieldRecharge()
	SoundController.play("ShieldRecharge", 0.02)
end

function SoundController.playReload(isPlasmaVent: boolean)
	SoundController.play(if isPlasmaVent then "PlasmaVent" else "Reload", 0.03)
end

function SoundController.playUiClick()
	SoundController.play("UiClick", 0.03)
end

function SoundController.playItemRotate()
	SoundController.play("UiRotate", 0.03)
end

function SoundController.playError()
	SoundController.play("UiError", 0.0)
end

function SoundController.playLootChime(highRarity: boolean)
	SoundController.play(if highRarity then "LootHighRarity" else "LootCommon", 0.03)
end

function SoundController.playExtractionSiren()
	SoundController.play("ExtractionSiren", 0.0)
end

return SoundController
