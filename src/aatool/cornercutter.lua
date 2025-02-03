local pixelchecker = require("pixelchecker")
local pixeldriver = require("pixeldriver")
local grid = require("grid")

local cornercutter = {}


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
		grid.directionsX[pixelchecker.rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
	pixel.compareY = strand.components[cornerIndex].y +
		grid.directionsY[pixelchecker.rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
	local thresholdPercent = index / #strand.components
	local percent = 0.0
	if aInside then
		percent = 1.0
		if primaryVertexOffset > 0 then
			-- print(index)
			-- print(#strand.components)
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = pixelchecker.clamp(1.0, index / (#strand.components * aScale * scale), 0.0)
			end
		else
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = pixelchecker.clamp(1.0, (1.0 - (index - 1) / #strand.components) / (aScale * scale), 0.0)
			end
		end
	else
		if primaryVertexOffset > 0 then
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = pixelchecker.clamp(1.0, (index - 1 - (#strand.components * (1.0 - aScale * scale)))
					/ (#strand.components * aScale * scale), 0.0)
			end
		else
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = 1.0 - pixelchecker.clamp(1.0, (index / #strand.components) / (aScale * scale), 0.0)
			end
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

local function markAliasInside(squid, aliasPixels, strand, strandIndex)
	if facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) == -1 then
		-- print("slope up ahead")
		if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
			if (facingChange(strandIndex, -1, squid) == -2) then
				-- print("-tried to round the corner")
			else
				-- print("-gentle slope down behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
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
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
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
						table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 0.5))
					else
						table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 0.5))
					end
				end
			elseif (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
				-- print("-gentle convex slope behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
				end
			elseif (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle convex slope ahead")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
				end
			end
		elseif facingChange(strandIndex, -1, squid) == -1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
			end
		elseif facingChange(strandIndex, 1, squid) == 1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
			end
		end
	end
end

local function markAliasOutside(squid, aliasPixels, strand, strandIndex)
	if facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) == -1 then
		-- print("slope up ahead")
		if (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
			-- print("-gentle slope up ahead")
			for index, point in ipairs(strand.components) do
				table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
			end
		end
	elseif facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("slope up behind")
		if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
			-- print("-gentle slope up behind")
			for index, point in ipairs(strand.components) do
				table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
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
						table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 0.5))
					else
						table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 0.5))
					end
				end
			elseif (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
				-- print("-gentle concave slope behind")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
				end
			elseif (facingChange(strandIndex, 2, squid) == 0 or strandSize(strandIndex, 1, squid) > 2) then
				-- print("-gentle concave slope ahead")
				for index, point in ipairs(strand.components) do
					table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
				end
			end
		elseif facingChange(strandIndex, -1, squid) == -1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, 1, 1))
			end
		elseif facingChange(strandIndex, 1, squid) == 1 then
			for index, point in ipairs(strand.components) do
				-- table.insert(aliasPixels, calculatePixel(point, strand, index, -1, 1))
			end
		end
	elseif facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) > 0 then
		-- print("convex")
	end
end


local function generateAliasData(squid, aliasPixels, aInside)
	for strandIndex, strand in ipairs(squid) do
		if strand.normalFacing % 2 == 1 then
			if aInside then
				markAliasInside(squid, aliasPixels, strand, strandIndex)
			else
				markAliasOutside(squid, aliasPixels, strand, strandIndex)
			end
		end
	end
end

function cornercutter.cutCorners(baseSelection)
	-- iterate through the boundaries of selection to add corner pixels to a table
	local selectionBounds = baseSelection.bounds
	local corners = {}
	for x = selectionBounds.x, selectionBounds.width + selectionBounds.x, 1 do
		for y = selectionBounds.y, selectionBounds.height + selectionBounds.y, 1 do
			-- print("test0")
			if pixelchecker.checkCorner(x, y) then
				table.insert(corners, { x, y })
			end
		end
	end

	local driverData = pixeldriver.driveAll(baseSelection, corners)




	local aliasPixels = {}
	--


	if #driverData.webCluster > 0 then
		for squidex, tendril in ipairs(driverData.webCluster) do
			generateAliasData(tendril)
			-- print("border pixel data generation complete")
		end
	end

	return aliasPixels;
end

return cornercutter
