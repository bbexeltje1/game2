--!strict
-- Tactical Sci-Fi x ARPG UI Design Tokens & Instance Helpers.
-- High contrast, dark slate glass, Halo shield cyan, and Diablo item rarity accents.
-- Strictly avoids attaching functions onto Roblox Instances (Template Rule #4).

local AffixCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10):WaitForChild("Loot", 10):WaitForChild("AffixCatalog", 10))

local Theme = {
	bgRoot = Color3.fromRGB(12, 15, 21),
	bgPanel = Color3.fromRGB(19, 23, 32),
	bgElevated = Color3.fromRGB(27, 33, 46),
	bgSlot = Color3.fromRGB(23, 28, 39),
	bgCellEmpty = Color3.fromRGB(20, 25, 35),
	bgCellValid = Color3.fromRGB(36, 118, 72),
	bgCellInvalid = Color3.fromRGB(132, 42, 48),
	bgCellHeld = Color3.fromRGB(58, 92, 145),

	borderSubtle = Color3.fromRGB(54, 64, 86),
	borderBright = Color3.fromRGB(102, 168, 235),

	textPrimary = Color3.fromRGB(240, 244, 252),
	textSecondary = Color3.fromRGB(168, 178, 198),
	textMuted = Color3.fromRGB(116, 126, 146),

	shieldCyan = Color3.fromRGB(72, 214, 255),
	shieldWarning = Color3.fromRGB(255, 92, 92),
	healthRed = Color3.fromRGB(238, 82, 88),
	plasmaViolet = Color3.fromRGB(168, 118, 255),
	positiveGreen = Color3.fromRGB(88, 236, 142),
	negativeRed = Color3.fromRGB(255, 98, 98),
	scrapAmber = Color3.fromRGB(255, 192, 78),
	creditMint = Color3.fromRGB(104, 238, 178),
}

function Theme.rarityColor(rarityId: string): Color3
	local def = AffixCatalog.Rarities[rarityId :: any]
	if def then
		return Color3.fromRGB(def.color.r, def.color.g, def.color.b)
	end
	return Color3.fromRGB(205, 212, 222)
end

function Theme.addCorner(parent: Instance, radiusPx: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = parent
	return c
end

function Theme.addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

function Theme.frame(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3,
	bgTransparency: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = bgColor
	f.BackgroundTransparency = bgTransparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Theme.label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	font: Enum.Font,
	textSize: number,
	color: Color3,
	xAlign: Enum.TextXAlignment?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

function Theme.button(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3,
	textColor: Color3,
	textSize: number?
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = bgColor
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = textSize or 12
	b.TextColor3 = textColor
	b.Text = text
	b.Parent = parent
	Theme.addCorner(b, 6)
	return b
end

return Theme
