local pixelchecker = require("pixelchecker")
local grid = require("grid")

local pixeldriver = {}


local function createDriver(coord, baseSelection)
	local newDriver = {
		-- clockwise starting from the top middle
		facing = 1,
		spinDirection = 0,
		driverXY = { 0, 0 },
		borderWeb = {},
		webCluster = {},
		visitedPixels = {},
		boundSelection = baseSelection,


	}

	-- Rotate facing by specified amount of offsets. Positive is clockwise.
	local function rotateFacing(facing, spin)
		local face = facing - 1 + spin
		if face < 0 then
			face = face % -8 + 8
		else
			face = face % 8
		end
		return face + 1
	end


	local function getAdjacentInDirection(driver, direction)
		local checkX = grid.directionsX[direction] + driver.driverXY[1]
		local checkY = grid.directionsY[direction] + driver.driverXY[2]
		return { ["x"] = checkX, ["y"] = checkY }
	end

	-- Returns the coordinates infront of the driver.
	function newDriver.getAheadImFacing(driver)
		return getAdjacentInDirection(driver, driver.facing)
	end

	-- Returns the coordinates infront if rotation without rotating the driver.
	function newDriver.getAheadWhenRotated(driver, direction)
		local checkX = grid.directionsX[direction] + driverXY[1]
		local checkY = grid.directionsY[direction] + driverXY[2]
		return { ["x"] = checkX, ["y"] = checkY }
	end

	-- Returns if driver is facing a selection edge that is within bounds.
	function newDriver.IsFacingEdge(driver)
		local point = driver:getAheadImFacing()
		local checkAdjacency = pixelchecker.isValidSelectionBorder(driver.boundSelection, point.x, point.y)
		return baseSelection:contains(point.x, point.y) and checkAdjacency < 4
	end

	function newDriver.IsFacingEdgeOffset(driver, rotationOffset)
		local point = driver:getAdjacentInDirection(driver.facing + rotationOffset)
		local checkAdjacency = pixelchecker.isValidSelectionBorder(driver.boundSelection, point.x, point.y)
		return baseSelection:contains(point.x, point.y) and checkAdjacency < 4
	end

	-- Check if facing edge then return direction of nearby border with offset rotation in mind. Favors counter clockwise movement due to top left corner ordering.
	function newDriver.checkHugDirectionOffset(driver, rotationOffset)
		-- hug direction check looks for empty space, so check is inverted
		local clockwiseAdjacent = driver:getAheadWhenRotated(1 + rotationOffset)
		local counterclockwiseAdjacent = driver:getAheadWhenRotated(-1 + rotationOffset)
		if driver.checkFacingEdge() then
			-- edge on right
			if not driver.boundSelection:contains(counterclockwiseAdjacent.x, counterclockwiseAdjacent.y) then
				return 1
				-- edge on left
			elseif not driver.boundSelection:contains(clockwiseAdjacent.x, counterclockwiseAdjacent.y) then
				return -1
			end
		end
		return 0
	end

	-- Check if facing edge then return direction of nearby border. Favors counter clockwise movement due to top left corner ordering.
	function newDriver.checkHugDirection(driver)
		return driver:checkHugDirectionOffset(baseSelection)
	end

	-- Move in facing direction.
	function newDriver.driveForwards(driver)
		driver.driverXY = driver.getAheadImFacing()
	end

	-- Add current position to exploited corners list so calculation is not repeated unnecessarily.
	function newDriver.markPixel(driver, selectionBounds)
		driver.visitedPixels[driver.driverXY[1] * selectionBounds.height + driver.driverXY[2]] = true
	end

	-- Rotate clockwise until outside edge is perpendicular to facing direction.
	-- Return if successful.
	function newDriver.rotateUntilTracingEdge(driver)
		local timeout = 0
		local spinDirection = driver:checkHugDirection(baseSelection)
		while (spinDirection == 0 and timeout < 7) do
			-- print(string.format("facing: %d", facing))
			timeout = timeout + 1
			spinDirection = driver:checkHugDirectionOffset(baseSelection, timeout)
		end
		if spinDirection ~= 0 then
			driver.facing = rotateFacing(driver.facing, timeout)
			return true
		end
		return false
	end

	function newDriver.driveAlongEdge(driver)
		if ! driver:rotateUntilTracingEdge() then
			-- print("border web was a dead end")
			return
		end
		local cleanOrigin = {}
		local iteration = 0
		repeat
			--print(" starting strand") - set the start point of the stand
			if #cleanOrigin == 0 and #driver.borderWeb > 0 then
				cleanOrigin = { driver.driverXY[1], driver.driverXY[2] }
			end

			-- Check if facing is navigable without direction change, advance and add the coordinate to strand. #TODO Optimize 16 checks to 8
			local strand = {}
			while (driver:checkFacingEdge() and not driver:checkFacingEdgeOffset(-1)
					and not (driver.checkFacingEdgeOffset(-2)
						and (baseSelection:contains(driver:checkHugDirectionOffset(-1).x, driver:checkHugDirectionOffset(-1).y) or #strand > 0))) do
				--print("  added pixel to strand : " .. table.concat(driver, ", "))
				table.insert(strand, { ["x"] = driver.driverXY[1], ["y"] = driver.driverXY[2] })
				driver:markPixel(baseSelection.bounds)
				driver:driveForwards()
			end

			-- 
			table.insert(strand, { ["x"] = driver.driverXY[1], ["y"] = driver.driverXY[2] })
			driver:markPixel(driver.visitedPixels, baseSelection.bounds)
			table.insert(driver.borderWeb,
				{
					["components"] = strand,
					["normalFacing"] = driver:rotateFacing(driver.facing, spinDirection * -2),
					["spin"] =
						spinDirection
				})
			if #webCluster == 0 then
				-- print(" completed strand at: "..table.concat(driver, ", ").." facing "..facing.." length "..#strand..". rotating...")
			end
			-- Rotate until navigable starting 90 degrees offset to hug border, advance and terminate strand.
			driver.facing = rotateFacing(driver.facing, spinDirection * -2)
			timeout = 0
			while (not pixelchecker.checkFacingEdge(baseSelection, driver.facing, driver.driverXY) and timeout < 8) do
				driver.facing = rotateFacing(driver.facing, spinDirection)
				timeout = timeout + 1
			end
			--print(" rotation complete at facing: "..facing)
			iteration = iteration + 1
		until ((grid.sameCoord(driver.driverXY, cleanOrigin) and driver.visitedPixels[pixelchecker.checkDirection(driver.facing, driver.driverXY).x * baseSelection.bounds.height + pixelchecker.checkDirection(driver.facing, driver.driverXY).y] == true)
				or iteration > #corners * 2)
		table.remove(driver.borderWeb, 1)
		table.insert(driver.webCluster, driver.borderWeb)
		-- print(string.format("completed border web %d of %d / %d strands", #webCluster, #borderWeb, #corners * 2))
	end

	function pixeldriver.drive(driver, baseSelection, webCluster, corners)
		-- Only perform calculations if not already visited.
		if driver.visitedPixels[driver.driverXY[1] * baseSelection.bounds.height + driver.driverXY[2]] ~= nil then
			return
		end

		driver:rotateUntilTracingEdge()

		-- print("started border web at: "..table.concat(driver, ", "))

		-- print(string.format(" determined spin direction to be: %d, with initial facing: %d", spinDirection, facing))

		-- Create strands until original location reached. (webCluster, borderWeb, strand, pixel)
		-- to ensure a clean starting strand
		driver:driveAlongEdge()
	end

	return newDriver
end


function pixeldriver.driveAll(baseSelection, corners)
	local driver = createDriver()
	-- generate a series of looped border data
	for _, coord in ipairs(corners) do
		driver.driverXY = coord
		pixeldriver.drive(driver, baseSelection, driver.visitedPixels, driver.webCluster, corners)
	end
	return driver
end

return pixeldriver
