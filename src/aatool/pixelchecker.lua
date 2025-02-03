local grid = require("grid")

local pixelchecker = {}

function pixelchecker.getAdjacent(x, y)
	local adj = {}
	adj[1] = { x - 1, y }
	adj[2] = { x + 1, y }
	adj[3] = { x, y - 1 }
	adj[4] = { x, y + 1 }
	return adj
end

function pixelchecker.clamp(maximum, number, minimum)
	return math.max(math.min(maximum, number), minimum)
end

function pixelchecker.adjacencyCount(baseSelection, x, y)
	local result = 0
	-- print(adj)
	-- print(string.format("%d, %d", x, y))
	local adj = pixelchecker.getAdjacent(x, y)
	for index, coord in ipairs(adj) do
		local adjacentX = coord[1]
		local adjacentY = coord[2]
		-- print(ax, ", ", ay)
		if baseSelection:contains(adjacentX, adjacentY) then
			result = result + 1
		end
		-- result = result + (baseSelection.contains(ax, ay) and 1 or 0)
		-- print(string.format("Tested: %d, %d for total %d", ax, ay, result))
	end
	-- print(result)
	return result
end

-- check if a pixel is a corner of the selection boundary
function pixelchecker.checkCorner(baseSelection, x, y)
	if baseSelection:contains(x, y) and pixelchecker.adjacencyCount(baseSelection, x, y) < 3 then
		-- print(string.format("Found corner here: %d, %d", x, y))
		return true
	end
end

-- compared two coordinates for equivalence
function pixelchecker.sameCoord(coordinate, coordinate2)
	return coordinate[1] == coordinate2[1] and coordinate[2] == coordinate2[2]
end

function pixelchecker.checkDirection(direction, driverXY)
	local checkX = grid.directionsX[direction] + driverXY[1]
	local checkY = grid.directionsY[direction] + driverXY[2]
	return { ["x"] = checkX, ["y"] = checkY }
end

--
function pixelchecker.checkFacingEdge(baseSelection, direction, driverXY)
	local point = pixelchecker.checkDirection(direction, driverXY)
	local checkAdjacency = pixelchecker.adjacencyCount(baseSelection, point.x, point.y)
	-- print(string.format("(%d, %d) adjacent %d", checkX, checkY, checkAdjacency))
	return baseSelection:contains(point.x, point.y) and checkAdjacency < 4
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
