local cornercutter = require("cornercutter")

local spr = app.activeSprite
if not spr then return end

local baseSelection = spr.selection
if baseSelection.isEmpty then
	print("Please select a region to anti-alias around (use the magic wand for best results)")
	return
end

local aMax = 0.5
local aMin = 0.0
local aScale = 1.0
local aInside = false
local aAutomate = true
local aTransparency = true
local aConcaveSpacing = 2
local aConcaveScale = 1.0
local aAverageInsideColor = true
-- "constant", "linear", "normal bias"
local aAverageInsideColorFormula = "normal bias"

function cutCornersDialogue()
	local info = Dialog()
	info:label {
		id = string,
		label = "\"Cutting Corners\" AA Assistant v0.4.1",
		text = "Set percentages and other values to control the selection area."
	}
		:slider {
			id = "aliasMax",
			label = "Maximum Range",
			min = 0,
			max = 100,
			value = aMax * 100
		}
		:slider {
			id = "aliasMin",
			label = "Minimum Range",
			min = 0,
			max = 100,
			value = aMin * 100
		}
		:check {
			id = "aliasInside",
			text = "Anti-alias / select inside of the selection versus outside of it.",
			selected = aInside
		}
		:separator {
			id = string,
			text = "Automatic Algorithm Settings:"
		}
		:check {
			id = "aliasAutomatic",
			text = "Automatically apply colors instead of stenciling the selection.",
			selected = aAutomate
		}
		:slider {
			id = "aliasScale",
			label = "Range Scaling",
			min = 0,
			max = 100,
			value = aScale * 100
		}
		:label {
			id = string,
			text = "Colour Application Settings:"
		}
		:check {
			id = "aliasTransparency",
			text = "Allow blending transparent colours.",
			selected = aTransparency
		}
		:newrow()
		:check {
			id = "aliasAverageInsideColor",
			text = "Contextually pick colors from surface normals to increase accuracy.",
			selected = aAverageInsideColor
		}
		:combobox {
			id = "aliasAverageInsideColorFormula",
			label = "Color Blending Formula",
			option = aAverageInsideColorFormula,
			options = { "constant", "linear", "normal bias" }
		}
	info:button {
		id = "resetSettings",
		text = "Reset Settings",
		onclick = function()
			info.data.aliasMax = 0.5
			info.data.aliasMin = 0.0
			info.data.aliasInside = false
			info.data.aliasAutomatic = false
			print("(WIP) Settings Have Been Reset")
		end
	}
	info:button { id = "cancel", text = "Cancel" }
	info:button { id = "ok", text = "OK", focus = true }
	info:show()

	aMax = info.data.aliasMax / 100
	aMin = info.data.aliasMin / 100
	aInside = info.data.aliasInside
	aAutomate = info.data.aliasAutomatic
	aScale = info.data.aliasScale / 100
	aTransparency = info.data.aliasTransparency
	aAverageInsideColor = info.data.aliasAverageInsideColor
	aAverageInsideColorFormula = info.data.aliasAverageInsideColorFormula
	return info.data.ok
end

if cutCornersDialogue() then
	app.transaction(cornercutter.cutCorners(baseSelection))
end

app.refresh()
