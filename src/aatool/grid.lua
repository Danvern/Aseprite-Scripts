local grid = {}

grid.directionsX = { 0, 1, 1, 1, 0, -1, -1, -1 }
grid.directionsY = { -1, -1, 0, 1, 1, 1, 0, -1 }

-- compared two coordinates for equivalence
function grid.sameCoord(coordinate, coordinate2)
	return coordinate[1] == coordinate2[1] and coordinate[2] == coordinate2[2]
end

return grid