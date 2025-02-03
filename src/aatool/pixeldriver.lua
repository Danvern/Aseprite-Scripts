local pixelchecker = require("pixelchecker")
local grid = require("grid")

local pixeldriver = {}


local function createDriver(coord)
	local newDriver = {
		-- clockwise starting from the top middle
		facing = 1,
		spinDirection = 0,
		driverXY = { 0, 0 },
		borderWeb = {},
		webCluster = {},
		exploitedPixels = {},
	}
	return newDriver
end

-- Check if corner and add to exploited corners list so calculation is not repeated unnecessarily.
local function markPixel(exploitedPixels, driver, selectionBounds)
	exploitedPixels[driver.driverXY[1] * selectionBounds.height + driver.driverXY[2]] = true
end

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

-- Check if facing is navigable then return direction of nearby border. Favors counter clockwise movement due to top left corner ordering.
local function checkHugDirection(baseSelection, direction, driverXY)
	-- print("initiate hug direction check")
	local clockX = grid.directionsX[rotateFacing(direction, 1)] + driverXY[1]
	local clockY = grid.directionsY[rotateFacing(direction, 1)] + driverXY[2]
	local counterX = grid.directionsX[rotateFacing(direction, -1)] + driverXY[1]
	local counterY = grid.directionsY[rotateFacing(direction, -1)] + driverXY[2]
	-- print(string.format("Clock: %d, %d - Counter: %d, %d", clockX, clockY, counterX, counterY))
	-- print("checking direction...")
	if pixelchecker.checkFacingEdge(baseSelection, direction, driverXY) then
		-- print("is edge, checking for rotation...")
		if not baseSelection:contains(counterX, counterY) then
			return 1
		elseif not baseSelection:contains(clockX, clockY) then
			return -1
		end
	end
	return 0
end

local function driveForwards(driver)
	driver.driverXY[1] = driver.driverXY[1] + grid.directionsX[driver.facing]
	driver.driverXY[2] = driver.driverXY[2] + grid.directionsY[driver.facing]
	-- print("drove to " + table.concat(driver, ", "))
end

function pixeldriver.driveAll(baseSelection, corners)
	local driver = createDriver()
	-- generate a series of looped border data
	for _, coord in ipairs(corners) do
		driver.driverXY = coord
		pixeldriver.drive(driver, baseSelection, driver.exploitedPixels, driver.webCluster, corners)
	end
	return driver
end

function pixeldriver.drive(driver, baseSelection, exploitedPixels, webCluster, corners)
	-- Perform calculations if not already exploited.
	if exploitedPixels[driver.driverXY[1] * baseSelection.bounds.height + driver.driverXY[2]] == nil then
		-- print("started border web at: "..table.concat(driver, ", "))
		local iteration = 0
		local timeout = 0
		-- to ensure a clean starting strand
		local cleanOrigin = {}
		local spinDirection = checkHugDirection(baseSelection, driver.facing, driver.driverXY)
		while (spinDirection == 0 and timeout < 8) do
			-- print(string.format("facing: %d", facing))
			driver.facing = rotateFacing(driver.facing, 1)
			timeout = timeout + 1
			spinDirection = checkHugDirection(baseSelection, driver.facing, driver.driverXY)
		end
		-- print(string.format(" determined spin direction to be: %d, with initial facing: %d", spinDirection, facing))
		-- Create strands until original location reached. (webCluster, borderWeb, strand, pixel)
		if spinDirection ~= 0 then
			repeat
				--print(" starting strand")
				if #cleanOrigin == 0 and #driver.borderWeb > 0 then
					cleanOrigin = { driver.driverXY[1], driver.driverXY[2] }
				end
				-- Check if facing is navigable without direction change, advance and add the coordinate to strand.
				local strand = {}
				while (pixelchecker.checkFacingEdge(baseSelection, driver.facing, driver.driverXY) and not pixelchecker.checkFacingEdge(baseSelection, rotateFacing(driver.facing, spinDirection * -1), driver.driverXY)
						and not (pixelchecker.checkFacingEdge(baseSelection, rotateFacing(driver.facing, spinDirection * -2), driver.driverXY)
							and (baseSelection:contains(pixelchecker.checkDirection(rotateFacing(driver.facing, spinDirection * -1), driver.driverXY).x,
								pixelchecker.checkDirection(rotateFacing(driver.facing, spinDirection * -1), driver.driverXY).y) or #strand > 0))) do
					table.insert(strand, { ["x"] = driver.driverXY[1], ["y"] = driver.driverXY[2] })
					--print("  added pixel to strand : " .. table.concat(driver, ", "))
					markPixel(exploitedPixels, driver, baseSelection.bounds)
					driveForwards(driver)
				end
				table.insert(strand, { ["x"] = driver.driverXY[1], ["y"] = driver.driverXY[2] })
				markPixel(exploitedPixels, driver, baseSelection.bounds)
				table.insert(driver.borderWeb,
					{
						["components"] = strand,
						["normalFacing"] = rotateFacing(driver.facing, spinDirection * -2),
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
			until ((pixelchecker.sameCoord(driver.driverXY, cleanOrigin) and exploitedPixels[pixelchecker.checkDirection(driver.facing, driver.driverXY).x * baseSelection.bounds.height + pixelchecker.checkDirection(driver.facing, driver.driverXY).y] == true)
					or iteration > #corners * 2)
			table.remove(driver.borderWeb, 1)
			table.insert(webCluster, driver.borderWeb)
			-- print(string.format("completed border web %d of %d / %d strands", #webCluster, #borderWeb, #corners * 2))
		else
			-- print("border web was a dead end")
		end
	end
end

return pixeldriver
