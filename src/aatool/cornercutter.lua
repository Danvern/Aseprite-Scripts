local pixelchecker = require("pixelchecker")
local pixeldriver = require("pixeldriver")
local grid = require("grid")

local cornercutter = {}

local function colorPixels()
	spr.selection = Selection()
	local image = app.activeImage:clone()
	local sourceImage = app.activeImage
	local cel = app.activeImage.cel
	local pc = app.pixelColor

	for index, pixel in ipairs(aliasPixels) do
		function mixClean(c1, c2, source, colorFunction, percent)
			if source ~= nil then
				if source == c1 then
					c1 = c2
				elseif source == c2 then
					c2 = c1
				end
			end
			local realPercent = percent
			if not aTransparency then
				if pc.rgbaA(c1) == 0 then
					realPercent = 0.0
				elseif pc.rgbaA(c2) == 0 then
					realPercent = 1.0
				end
			end
			return colorFunction(c1) * realPercent + colorFunction(c2) * (1 - realPercent)
		end

		function mixColour(c1, c2, mask, percent)
			local rVal = mixClean(c1, c2, mask, pc.rgbaR, percent)
			local gVal = mixClean(c1, c2, mask, pc.rgbaG, percent)
			local bVal = mixClean(c1, c2, mask, pc.rgbaB, percent)
			local aVal = 255
			if aTransparency then
				aVal = mixClean(c1, c2, mask, pc.rgbaA, percent)
			end
			return pc.rgba(rVal, gVal, bVal, aVal)
		end

		if aInside and pixel.percent < 1 then
			local sourceValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
			local inletValue = sourceImage:getPixel(pixel.compareX - cel.position.x, pixel.compareY - cel.position.y)
			if aAverageInsideColor and 0 <= pixel.normalX - cel.position.x and pixel.normalX - cel.position.x < spr.width
				and 0 <= pixel.normalY - cel.position.y and pixel.normalY - cel.position.y < spr.height then
				local normalValue = sourceImage:getPixel(pixel.normalX - cel.position.x,
					pixel.normalY - cel.position.y)
				local cornerValue = sourceImage:getPixel(pixel.sourceX - cel.position.x,
					pixel.sourceY - cel.position.y)
				if aAverageInsideColorFormula == "linear" then
					inletValue = mixColour(normalValue, inletValue, nil, pixel.percent)
				elseif aAverageInsideColorFormula == "normal bias" then
					-- print(string.format("Normal Bias: (%d/%d)", pixel.place, pixel.max))
					if pixel.place == 1 then
						inletValue = mixColour(normalValue, inletValue, nil, 0.0)
					else
						inletValue = mixColour(normalValue, inletValue, nil, 1.0)
					end
				else
					inletValue = mixColour(normalValue, inletValue, nil, 0.5)
				end
			end
			-- if pixel.x - cel.position.x == 169 then
			-- print(string.format("S:(%d, %d), C:(%d, %d), %f P", pixel.x, pixel.y, pixel.compareX, pixel.compareY, pixel.percent))
			-- end
			image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y,
				mixColour(sourceValue, inletValue, nil, pixel.percent))
		elseif not aInside and pixel.percent > 0 then
			local sourceValue = sourceImage:getPixel(pixel.sourceX - cel.position.x, pixel.sourceY - cel.position.y)
			local underValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
			-- print(string.format("U:(%d, %d), S:(%d, %d), %f P", pixel.x, pixel.y, pixel.sourceX, pixel.sourceY, pixel.percent))
			image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y,
				mixColour(sourceValue, underValue, nil, pixel.percent))
		end
	end

	app.activeImage:drawImage(image)
end

function generateAliasData(squid, aliasPixels)
	for strandIndex, strand in ipairs(squid) do
		if strand.normalFacing % 2 == 1 then
			if aInside then
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
			else
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
		end
	end
end

-- general purpose calculation
function calculatePixel(point, strand, index, primaryVertexOffset, scale)
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
		grid.directionsX[rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
	pixel.compareY = strand.components[cornerIndex].y +
		grid.directionsY[rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
	local thresholdPercent = index / #strand.components
	local percent = 0.0
	if aInside then
		percent = 1.0
		if primaryVertexOffset > 0 then
			-- print(index)
			-- print(#strand.components)
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = clamp(1.0, index / (#strand.components * aScale * scale), 0.0)
			end
		else
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = clamp(1.0, (1.0 - (index - 1) / #strand.components) / (aScale * scale), 0.0)
			end
		end
	else
		if primaryVertexOffset > 0 then
			if aMin <= 1.0 - thresholdPercent and 1.0 - thresholdPercent <= aMax then
				percent = clamp(1.0, (index - 1 - (#strand.components * (1.0 - aScale * scale)))
					/ (#strand.components * aScale * scale), 0.0)
			end
		else
			if aMin <= thresholdPercent and thresholdPercent <= aMax then
				percent = 1.0 - clamp(1.0, (index / #strand.components) / (aScale * scale), 0.0)
			end
		end
	end
	pixel.percent = percent
	pixel.max = math.ceil(#strand.components * aScale * scale)
	pixel.place = math.ceil(percent * pixel.max)
	-- print(string.format("(%d, %d) Pixel %d / %d (%f) - Normal %d + %d - Spin %d", pixel.x, pixel.y, index, #strand.components, pixel.percent, strand.normalFacing, normalOffset, strand.spin))
	return pixel
end

function strandSize(strandIndex, offset, web)
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

function facingChange(strandIndex, offset, web)
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

	pixeldriver.driveAll(baseSelection, corners)




	local aliasPixels = {}
	--


	if #webCluster > 0 then
		for squidex, tendril in ipairs(webCluster) do
			generateAliasData(tendril)
			-- print("border pixel data generation complete")
		end
	end

	-- color selection
	if aAutomate and #aliasPixels > 0 then
		colorPixels()
	elseif #aliasPixels > 0 then
		-- returned found pixels as a selection
		local newSelection = Selection()
		for index, pixel in ipairs(aliasPixels) do
			if (pixel.percent > 0 and not aInside) or (pixel.percent < 1 and aInside) then
				newSelection:add(Selection(Rectangle(pixel.x, pixel.y, 1, 1)))
			end
		end
		spr.selection = newSelection
	else
		print("Invalid selection. There's no smoothing out the hard life of an orphan.")
	end
end

return cornercutter
