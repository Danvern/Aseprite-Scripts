local pixelcolor = {}


local function mixClean(c1, c2, source, colorFunction, percent, aTransparency, pc)
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

local function mixColour(c1, c2, mask, percent, pc, aTransparency)
	local rVal = mixClean(c1, c2, mask, pc.rgbaR, percent, pc)
	local gVal = mixClean(c1, c2, mask, pc.rgbaG, percent, pc)
	local bVal = mixClean(c1, c2, mask, pc.rgbaB, percent, pc)
	local aVal = 255
	if aTransparency then
		aVal = mixClean(c1, c2, mask, pc.rgbaA, percent, pc)
	end
	return pc.rgba(rVal, gVal, bVal, aVal)
end

function pixelcolor.colorPixels(sourceImage, cel, aliasPixels, currentSprite, aAverageInsideColorFormula,
								aAverageInsideColor, image, aInside, pc, aTransparency)
	for _, pixel in ipairs(aliasPixels) do
		if aInside and pixel.percent < 1 then
			local sourceValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
			local inletValue = sourceImage:getPixel(pixel.compareX - cel.position.x, pixel.compareY - cel.position.y)
			if aAverageInsideColor and 0 <= pixel.normalX - cel.position.x and pixel.normalX - cel.position.x < currentSprite.width
				and 0 <= pixel.normalY - cel.position.y and pixel.normalY - cel.position.y < currentSprite.height then
				local normalValue = sourceImage:getPixel(pixel.normalX - cel.position.x,
					pixel.normalY - cel.position.y)
				local cornerValue = sourceImage:getPixel(pixel.sourceX - cel.position.x,
					pixel.sourceY - cel.position.y)
				if aAverageInsideColorFormula == "linear" then
					inletValue = mixColour(normalValue, inletValue, nil, pixel.percent, pc, aTransparency)
				elseif aAverageInsideColorFormula == "normal bias" then
					-- print(string.format("Normal Bias: (%d/%d)", pixel.place, pixel.max))
					if pixel.place == 1 then
						inletValue = mixColour(normalValue, inletValue, nil, 0.0, pc, aTransparency)
					else
						inletValue = mixColour(normalValue, inletValue, nil, 1.0, pc, aTransparency)
					end
				else
					inletValue = mixColour(normalValue, inletValue, nil, 0.5, pc, aTransparency)
				end
			end
			-- if pixel.x - cel.position.x == 169 then
			-- print(string.format("S:(%d, %d), C:(%d, %d), %f P", pixel.x, pixel.y, pixel.compareX, pixel.compareY, pixel.percent))
			-- end
			image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y,
				mixColour(sourceValue, inletValue, nil, pixel.percent, pc, aTransparency))
		elseif not aInside and pixel.percent > 0 then
			local sourceValue = sourceImage:getPixel(pixel.sourceX - cel.position.x, pixel.sourceY - cel.position.y)
			local underValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
			-- print(string.format("U:(%d, %d), S:(%d, %d), %f P", pixel.x, pixel.y, pixel.sourceX, pixel.sourceY, pixel.percent))
			image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y,
				mixColour(sourceValue, underValue, nil, pixel.percent, pc, aTransparency))
		end
	end
end

return pixelcolor
