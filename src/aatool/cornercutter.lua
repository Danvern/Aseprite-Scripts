local pixelchecker = require("pixelchecker")
local pixeldriver = require("pixeldriver")
local grid = require("grid")
local utility = require("utility")

local cornercutter = {}

local maxSteps = 3


-- general purpose calculation
local function calculatePixel(point, strand, index, primaryVertexOffset, scale, aScale, aMin, aMax, aInside)
	local pixel = {}
	local cornerIndex = 1
	local normalOffset = 2
	if primaryVertexOffset > 0 then
		cornerIndex = 1
		normalOffset = -2
	else
		cornerIndex = #strand.components
		normalOffset = 2
	end
	pixel.normalX = point.x + grid.directionsX[strand.normalFacing]
	pixel.normalY = point.y + grid.directionsY[strand.normalFacing]
	if aInside then
		pixel.x = point.x
		pixel.y = point.y
	else
		pixel.x = pixel.normalX
		pixel.y = pixel.normalY
	end
	pixel.sourceX = strand.components[cornerIndex].x
	pixel.sourceY = strand.components[cornerIndex].y
	pixel.compareX = strand.components[cornerIndex].x +
		grid.directionsX[pixelchecker.rotateFacingTwo(strand.normalFacing, normalOffset * strand.spin)]
	pixel.compareY = strand.components[cornerIndex].y +
		grid.directionsY[pixelchecker.rotateFacingTwo(strand.normalFacing, normalOffset * strand.spin)]
	local thresholdPercent = index / #strand.components
	local percent = 0.0
	if aInside then
		percent = 1.0
		if primaryVertexOffset > 0 then
			-- print(index)
			-- print(#strand.components)
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = utility.clamp(1.0, index / (#strand.components * aScale * scale), 0.0)
			end
			if #strand.components - index > 3 then percent = 0 end --#TODO: Quick test of limiter
		else
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = utility.clamp(1.0, (1.0 - (index - 1) / #strand.components) / (aScale * scale), 0.0)
			end
			if index > 2 then percent = 0 end --#TODO: Quick test of limiter
		end
	else
		if primaryVertexOffset > 0 then
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = utility.clamp(1.0, (index - 1 - (#strand.components * (1.0 - aScale * scale)))
					/ (#strand.components * aScale * scale), 0.0)
			end
			if #strand.components - index > maxSteps - 1 then percent = 0 end --#TODO: Quick test of limiter needs to be one less than below
		else
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = 1.0 - utility.clamp(1.0, (index / #strand.components) / (aScale * scale), 0.0)
			end
			if index > maxSteps then percent = 0 end --#TODO: Quick test of limiter
		end
	end
	pixel.percent = percent
	pixel.max = math.ceil(#strand.components * aScale * scale)
	pixel.place = math.ceil(percent * pixel.max)
	-- print(string.format("(%d, %d) Pixel %d / %d (%f) - Normal %d + %d - Spin %d", pixel.x, pixel.y, index, #strand.components, pixel.percent, strand.normalFacing, normalOffset, strand.spin))
	return pixel
end

local function strandSize(strandIndex, offset, web)
	local comparisonIndex = strandIndex - 1 + offset
	if comparisonIndex < 0 then
		comparisonIndex = comparisonIndex % - #web + #web
	else
		comparisonIndex = comparisonIndex % #web
	end
	if comparisonIndex > #web then
		return 0
	end
	comparisonIndex = comparisonIndex + 1
	-- print(comparisonIndex.."/"..#web)
	return #web[comparisonIndex].components
end

local function facingChange(strandIndex, offset, web)
	local comparisonIndex = strandIndex - 1 + offset
	if comparisonIndex < 0 then
		comparisonIndex = comparisonIndex % - #web + #web
	else
		comparisonIndex = comparisonIndex % #web
	end
	comparisonIndex = comparisonIndex + 1
	if comparisonIndex > #web then
		return 0
	end
	local difference = 0
	local clockDifference = web[comparisonIndex].normalFacing - web[strandIndex].normalFacing
	local counterDifference = math.max(clockDifference - 8, -clockDifference - 8)
	if clockDifference < 0 then
		counterDifference = counterDifference * -1
	end
	if math.abs(clockDifference) < math.abs(counterDifference) then
		difference = clockDifference
	else
		difference = counterDifference
	end
	-- so suggested rotation matches
	if difference == 4 and web[strandIndex].spin < 1 then
		difference = -4
	elseif difference == -4 and web[strandIndex].spin > 1 then
		difference = 4
	end
	-- print(string.format("Difference between strand normals %d and %d is (%d - %d = %d)", strandIndex, comparisonIndex, web[strandIndex].normalFacing, web[comparisonIndex].normalFacing, difference))
	return difference * web[strandIndex].spin
end

local function markAliasInside(squid, aliasPixels, strand, strandIndex, aScale, aMin, aMax, aInside)
	if facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) == -1 then
		-- print("slope up ahead")
		if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
			if (facingChange(strandIndex, -1, squid) == -2) then
				-- print("-tried to round the corner")
			else
				-- print("-gentle slope down behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, aInside))
				end
			end
		end
	elseif facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("slope up behind")
		if (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
			if (facingChange(strandIndex, 1, squid) == 2) then
				-- print("-tried to round the corner")
			else
				-- print("-gentle slope down ahead (no rounded corner)")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, aInside))
				end
			end
		end
	elseif facingChange(strandIndex, -1, squid) > 0 and facingChange(strandIndex, 1, squid) < 0 then

	elseif facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("convex")
		if facingChange(strandIndex, -1, squid) == -1 and facingChange(strandIndex, 1, squid) == 1 then
			if (facingChange(strandIndex, -2, squid) % 2 == 0 or strandSize(strandIndex, -1, squid) > 2)
				and (facingChange(strandIndex, 2, squid) % 2 == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle convex")
				for index, point in ipairs(strand.components) do
					if index <= #strand.components / 2 then
						table.insert(aliasPixels,
							calculatePixel(point, strand, index, 1, 0.5, aScale, aMin, aMax, aInside))
					else
						table.insert(aliasPixels,
							calculatePixel(point, strand, index, -1, 0.5, aScale, aMin, aMax, aInside))
					end
				end
			elseif (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
				-- print("-gentle convex slope behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, aInside))
				end
			elseif (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle convex slope ahead")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, aInside))
				end
			end
		elseif facingChange(strandIndex, -1, squid) == -1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, aInside))
			end
		elseif facingChange(strandIndex, 1, squid) == 1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, aInside))
			end
		end
	end
end

local function markAliasOutside(squid, aliasPixels, strand, strandIndex, aScale, aMin, aMax)
	if facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) == -1 then
		-- print("slope up ahead")
		if (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
			-- print("-gentle slope up ahead")
			for index, point in ipairs(strand.components) do
				table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, false))
			end
		end
	elseif facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("slope up behind")
		if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
			-- print("-gentle slope up behind")
			for index, point in ipairs(strand.components) do
				table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, false))
			end
		end
	elseif facingChange(strandIndex, -1, squid) > 0 and facingChange(strandIndex, 1, squid) < 0 then
		-- print("concave")
		if facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) == -1 then
			-- print("test")
			if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2)
				and (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle concave")
				for index, point in ipairs(strand.components) do
					if index <= #strand.components / 2 then
						table.insert(aliasPixels,
							calculatePixel(point, strand, index, -1, 0.5, aScale, aMin, aMax, false))
					else
						table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 0.5, aScale, aMin, aMax, false))
					end
				end
			elseif (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
				-- print("-gentle concave slope behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, false))
				end
			elseif (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle concave slope ahead")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, false))
				end
			end
		elseif facingChange(strandIndex, -1, squid) == -1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1, aScale, aMin, aMax, aInside))
			end
		elseif facingChange(strandIndex, 1, squid) == 1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1, aScale, aMin, aMax, aInside))
			end
		end
	elseif facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("convex")
	end
end


local function generateAliasData(squid, aliasPixels, aInside, aScale, aMin, aMax)
	for strandIndex, strand in ipairs(squid) do
		if strand.normalFacing % 2 == 1 then
			if aInside then
				markAliasInside(squid, aliasPixels, strand, strandIndex, aScale, aMin, aMax, aInside)
			else
				markAliasOutside(squid, aliasPixels, strand, strandIndex, aScale, aMin, aMax)
			end
		end
	end
end

-- #TODO Make this read only within the bounds + 1 ?
function cornercutter.cutCorners(baseSelection, aInside, aScale, aMin, aMax)
	-- iterate through the boundaries of selection to add corner pixels to a table
	local selectionBounds = baseSelection.bounds
	local corners = {}
	for x = selectionBounds.x, selectionBounds.width + selectionBounds.x, 1 do
		for y = selectionBounds.y, selectionBounds.height + selectionBounds.y, 1 do
			-- print("test0")
			if pixelchecker.isValidSelectionCorner(baseSelection, x, y) then
				table.insert(corners, { x, y })
			end
		end
	end

	local aliasPixels = {}
	local driverData = pixeldriver.driveAll(baseSelection, corners)
	for _, coord in ipairs(corners) do
		if #driverData.webCluster > 0 then
			for squidex, tendril in ipairs(driverData.webCluster) do
				generateAliasData(tendril, aliasPixels, aInside, aScale, aMin, aMax)
				-- print("border pixel data generation complete")
			end
		end
	end





	--




	return aliasPixels;
end

return cornercutter
