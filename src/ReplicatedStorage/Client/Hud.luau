--!strict
-- Client-only root HUD helper. Lives in ReplicatedStorage.ClientModules so both `Main.client.luau`
-- and `npm test` reach it cleanly (Template Rule #1).
local Hud = {}

function Hud.label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local instance = Instance.new("TextLabel")
	instance.Size = size
	instance.Position = position
	instance.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	instance.TextColor3 = Color3.new(1, 1, 1)
	instance.Text = text
	instance.Font = Enum.Font.GothamBold
	instance.TextScaled = true
	instance.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = instance
	return instance
end

function Hud.build(playerGui: Instance, titleText: string): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "GameHud"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.Parent = playerGui
	local title = Hud.label(screen, titleText, UDim2.fromOffset(230, 26), UDim2.fromOffset(16, 14))
	title.BackgroundTransparency = 0.35
	title.TextColor3 = Color3.fromRGB(115, 224, 255)
	return screen
end

return Hud
