local cornercutter = require("cornercutter")
local pixelcolor = require("pixelcolor")

local commandName = "Auto-Antialias"

local aMax = 0.5
local aMin = 0.0
local aScale = 1.0
local aInside = false
local aNewLayer = true
local aAutomate = true 
local aTransparency = true
local aConcaveSpacing = 2
local aConcaveScale = 1.0
local aAverageInsideColor = true
-- "constant", "linear", "normal bias"
local aAverageInsideColorFormula = "normal bias"

local function cutCornersDialogue(plugin)
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
			id = "aliasNewLayer",
			text = "Apply colors on a new layer instead of the selected layer.",
			selected = aNewLayer
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
		:radio {
			id = "aliasTransparency",
			text = "Allow blending transparent colours.",
			selected = aTransparency
		}
		:newrow()
		:radio {
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
	aNewLayer = info.data.aliasNewLayer
	aAutomate = info.data.aliasAutomatic
	aScale = info.data.aliasScale / 100
	aTransparency = info.data.aliasTransparency
	aAverageInsideColor = info.data.aliasAverageInsideColor
	aAverageInsideColorFormula = info.data.aliasAverageInsideColorFormula

	plugin.preferences.aliasMax = aMax
	plugin.preferences.aliasMin = aMin
	plugin.preferences.aliasScale = aScale
	plugin.preferences.aliasInside = aInside
	plugin.preferences.aliasNewLayer = aNewLayer
	plugin.preferences.aliasAutomatic = aAutomate
	plugin.preferences.aliasTransparency = aTransparency
	plugin.preferences.aliasAverageInsideColor = aAverageInsideColor
	plugin.preferences.aliasAverageInsideColorFormula = aAverageInsideColorFormula
	return info.data.ok
end

local function activate(baseSelection)
	local aliasPixels = cornercutter.cutCorners(baseSelection, aInside, aScale, aMin, aMax)
	local currentSprite = app.activeSprite

	currentSprite.selection = Selection()
	local image = app.activeImage:clone()
	local sourceImage = app.activeImage
	local cel = app.activeImage.cel
	local pc = app.pixelColor
	-- color selection
	if aAutomate and #aliasPixels > 0 then
		pixelcolor.colorPixels(sourceImage, cel, aliasPixels, currentSprite, aAverageInsideColor, aAverageInsideColor,
			image, aInside, pc, aTransparency)
	elseif #aliasPixels > 0 then
		-- returned found pixels as a selection
		local newSelection = Selection()
		for index, pixel in ipairs(aliasPixels) do
			if (pixel.percent > 0 and not aInside) or (pixel.percent < 1 and aInside) then
				newSelection:add(Selection(Rectangle(pixel.x, pixel.y, 1, 1)))
			end
		end
		currentSprite.selection = newSelection
	else
		print("Invalid selection. There's no smoothing out the hard life of an orphan.")
	end

	app.activeImage:drawImage(image)
end

local function checkValidSelection()
	local currentSprite = app.activeSprite
	if not currentSprite then return end

	local baseSelection = currentSprite.selection
	if baseSelection.isEmpty then
		print("Please select a region to anti-alias around (use the magic wand for best results)")
		return
	end
	return baseSelection
end

local function launchDialogue(plugin)
	local baseSelection = checkValidSelection()
	if cutCornersDialogue(plugin) and baseSelection then
		app.transaction(commandName, activate(baseSelection))
		app.refresh()
	end
end

local function skipDialogue()
	local baseSelection = checkValidSelection()
	if baseSelection then
		app.transaction(commandName, activate(baseSelection))
		app.refresh()
	end
end

-- Required Aseprite naming
---@diagnostic disable-next-line: lowercase-global
function init(plugin)
	if plugin.preferences.aliasMax == nil then
		plugin.preferences.aliasMax = aMax
	else
		aMax = plugin.preferences.aliasMax
	end
	if plugin.preferences.aliasMin == nil then
		plugin.preferences.aliasMin = aMin
	else
		aMin = plugin.preferences.aliasMin
	end
	if plugin.preferences.aliasScale == nil then
		plugin.preferences.aliasScale = aScale
	else
		aScale = plugin.preferences.aliasScale
	end
	if plugin.preferences.aliasInside == nil then
		plugin.preferences.aliasInside = aInside
	else
		aInside = plugin.preferences.aliasInside
	end
	if plugin.preferences.aliasNewLayer == nil then
		plugin.preferences.aliasNewLayer = aNewLayer
	else
		aNewLayer = plugin.preferences.aliasNewLayer
	end
	if plugin.preferences.aliasAutomatic == nil then
		plugin.preferences.aliasAutomatic = aAutomate
	else
		aAutomate = plugin.preferences.aliasAutomatic
	end
	if plugin.preferences.aliasTransparency == nil then
		plugin.preferences.aliasTransparency = aTransparency
	else
		aTransparency = plugin.preferences.aliasTransparency
	end
	if plugin.preferences.aliasAverageInsideColor == nil then
		plugin.preferences.aliasAverageInsideColor = aAverageInsideColor
	else
		aAverageInsideColor = plugin.preferences.aliasAverageInsideColor
	end
	if plugin.preferences.aliasAverageInsideColorFormula == nil then
		plugin.preferences.aliasAverageInsideColorFormula = aAverageInsideColorFormula
	else
		aAverageInsideColorFormula = plugin.preferences.aliasAverageInsideColorFormula
	end

	plugin:newCommand {
		id = "AATool",
		title = "AA Tool",
		group = "sprite_properties",
		onclick = function()
			launchDialogue(plugin)
		end
	}
	plugin:newCommand {
		id = "AAToolND)",
		title = "AA Tool (No Dialogue)",
		group = "sprite_properties",
		onclick = function()
			skipDialogue()
		end
	}
end

-- Required Aseprite naming
---@diagnostic disable-next-line: lowercase-global
function exit(plugin)

end
