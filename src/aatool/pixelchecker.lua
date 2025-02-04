local grid = require("grid")
local math = require("math")

local pixelchecker = {}

-- Returns adjacent pixels in the order of (left, right, up, down)
local function getAdjacentCoordinates(x, y)
	local adj = {
		{ x - 1, y },
		{ x + 1, y },
		{ x,     y - 1 },
		{ x,     y + 1 },
	}
	return adj
end


-- Returns the count of adjacent pixels which are inside of the provided selection.
local function countAdjacentPixelsInSelection(baseSelection, x, y)
	local result = 0
	local adj = getAdjacentCoordinates(x, y)
	for index, coord in ipairs(adj) do
		local adjacentX = coord[1]
		local adjacentY = coord[2]
		if baseSelection:contains(adjacentX, adjacentY) then
			result = result + 1
		end
	end
	return result
end

-- Check if a pixel is a corner of the selection boundary
function pixelchecker.isValidSelectionCorner(baseSelection, x, y)
	if baseSelection:contains(x, y) and countAdjacentPixelsInSelection(baseSelection, x, y) < 3 then
		-- print(string.format("Found corner here: %d, %d", x, y))
		return true
	end
end

-- Check if a pixel is on the border of the selection boundary
function pixelchecker.isValidSelectionBorder(baseSelection, x, y)
	if baseSelection:contains(x, y) and countAdjacentPixelsInSelection(baseSelection, x, y) < 4 then
		-- print(string.format("Found corner here: %d, %d", x, y))
		return true
	end
end

function pixelchecker.rotateFacingTwo(facing, spin)
	local face = facing - 1 + spin
	if face < 0 then
		face = face % -8 + 8
	else
		face = face % 8
	end
	return face + 1
end

return pixelchecker
