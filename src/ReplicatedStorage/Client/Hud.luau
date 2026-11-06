--!strict
-- Client-only root HUD helper with responsive viewport UIScale so both full-screen 1080p/1440p
-- monitors AND docked Roblox Studio viewports (~800x450) fit the entire HUD & 1040x580 modals cleanly.
-- Lives in ReplicatedStorage.ClientModules so both `Main.client.luau` and `npm test` reach it cleanly.

local Workspace = game:GetService("Workspace")

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

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Scale = 1
	uiScale.Parent = screen

	local function refreshScale()
		local ok, cam = pcall(function()
			return Workspace.CurrentCamera
		end)
		if ok and cam then
			local okVp, vp = pcall(function()
				return cam.ViewportSize
			end)
			if okVp and vp and vp.X > 0 and vp.Y > 0 then
				local scale = math.clamp(math.min(vp.X / 1140, vp.Y / 660), 0.56, 1.0)
				uiScale.Scale = scale
			end
		end
	end

	refreshScale()
	pcall(function()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
		end
	end)

	local title = Hud.label(screen, titleText, UDim2.fromOffset(230, 26), UDim2.fromOffset(16, 14))
	title.BackgroundTransparency = 0.35
	title.TextColor3 = Color3.fromRGB(115, 224, 255)
	return screen
end

return Hud
