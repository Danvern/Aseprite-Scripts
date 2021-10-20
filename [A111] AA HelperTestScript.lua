local spr = app.activeSprite
if not spr then return end

local baseSelection = spr.selection
if baseSelection.isEmpty then print("Please select a region to anti-alias around (use the magic wand for best results)") return end

aMax=0.5
aMin=0.0
aScale=1.0
aInside=false
aAutomate=true
aTransparency=true
aConcaveSpacing=2
aConcaveScale=1.0
aAverageInsideColor=true
-- "constant", "linear", "normal bias"
aAverageInsideColorFormula="normal bias"

function cutCornersDialogue()
    local info = Dialog()
        info:label{ 
            id=string,
            label="\"Cutting Corners\" AA Assistant v0.4.1",
            text="Set percentages and other values to control the selection area."
        }
        :slider{
            id="aliasMax",
            label="Maximum Range",
            min=0,
            max=100,
            value=aMax*100
        }
        :slider{
            id="aliasMin",
            label="Minimum Range",
            min=0,
            max=100,
            value=aMin*100
        }
        :check{
            id="aliasInside", 
            text="Anti-alias / select inside of the selection versus outside of it.", 
            selected=aInside
        }
        :separator{ 
            id=string,
            text="Automatic Algorithm Settings:"
        }
        :check{
            id="aliasAutomatic",
            text="Automatically apply colors instead of stenciling the selection.", 
            selected=aAutomate
        }
        :slider{
            id="aliasScale",
            label="Range Scaling",
            min=0,
            max=100,
            value=aScale*100
        }
        :label{ 
            id=string,
            text="Colour Application Settings:"
        }
        :check{
            id="aliasTransparency",
            text="Allow blending transparent colours.",
            selected=aTransparency
        }
        :newrow()
        :check{
            id="aliasAverageInsideColor",
            text="Contextually pick colors from surface normals to increase accuracy.",
            selected=aAverageInsideColor
        }
        :combobox{
            id="aliasAverageInsideColorFormula",
            label="Color Blending Formula",
            option=aAverageInsideColorFormula,
            options={"constant", "linear", "normal bias"}
        }
        info:button{
            id="resetSettings",
            text="Reset Settings", 
            onclick=function()
                info.data.aliasMax=0.5
                info.data.aliasMin=0.0
                info.data.aliasInside=false
                info.data.aliasAutomatic=false
                print("(WIP) Settings Have Been Reset")
            end
        }
        info:button{id="cancel", text="Cancel"}
        info:button{id="ok", text="OK", focus=true}
        info:show()
        
    aMax=info.data.aliasMax/100
    aMin=info.data.aliasMin/100
    aInside=info.data.aliasInside
    aAutomate=info.data.aliasAutomatic
    aScale=info.data.aliasScale/100
    aTransparency=info.data.aliasTransparency
    aAverageInsideColor=info.data.aliasAverageInsideColor
    aAverageInsideColorFormula=info.data.aliasAverageInsideColorFormula
    return info.data.ok
end
        
function cutCorners()
    function getAdjacent(x, y)
        adj={}
        adj[1]={x-1, y}
        adj[2]={x+1, y}
        adj[3]={x, y-1}
        adj[4]={x, y+1}
        return adj
    end
    
    function clamp(maximum, number, minimum)
        return math.max(math.min(maximum, number), minimum)
    end
    
    function adjacencyCount(x, y)
        result = 0
        -- print(adj)
        -- print(string.format("%d, %d", x, y))
        local adj = getAdjacent(x, y)
        for index, coord in ipairs(adj) do
            ax = coord[1]
            ay = coord[2]
            -- print(ax, ", ", ay)
            if baseSelection:contains(ax, ay) then
                result = result + 1
            end
            -- result = result + (baseSelection.contains(ax, ay) and 1 or 0)
            -- print(string.format("Tested: %d, %d for total %d", ax, ay, result))
        end
        -- print(result)
        return result
    end
    
    -- check if a pixel is a corner of the selection boundary
    function checkCorner(x, y)
        if baseSelection:contains(x, y) and adjacencyCount(x, y) < 3 then
            -- print(string.format("Found corner here: %d, %d", x, y))
            return true
        end
    end
    
    -- iterate through the boundaries of selection to add corner pixels to a table
    local rectangle = baseSelection.bounds
    local corners = {}
    for x = rectangle.x, rectangle.width + rectangle.x, 1 do
        for y = rectangle.y, rectangle.height + rectangle.y, 1 do
            -- print("test0")
            if checkCorner(x, y) then
                table.insert(corners, {x, y})
            end
        end
    end
    
    directionsX = {0, 1, 1, 1, 0, -1, -1, -1}
    directionsY = {-1, -1, 0, 1, 1, 1, 0, -1}
    exploitedPixels = {}
    webCluster = {}
    -- generate a series of looped border data
    for index, coord in ipairs(corners) do
        -- clockwise starting from the top middle
        local facing = 1
        local spinDirection = 0
        local driver = {coord[1], coord[2]}
        local borderWeb = {}
        
        -- compared two coordinates for equivalence
        function sameCoord(coordinate, coordinate2)
            return coordinate[1] == coordinate2[1] and coordinate[2] == coordinate2[2]
        end
        
        -- Rotate facing by specified amount of offsets. Positive is clockwise.
        function rotateFacing(facing, spin)
            local face = facing - 1 + spin
            if face < 0 then
                face = face % -8 + 8
            else
                face = face % 8
            end
            return face + 1
        end
        
        function checkDirection(direction)
            local checkX = directionsX[direction] + driver[1]
            local checkY = directionsY[direction] + driver[2]
            return {["x"] = checkX, ["y"] = checkY}
        end
        
        -- 
        function checkFacingEdge(direction)
            local point = checkDirection(direction)
            local checkAdjacency = adjacencyCount(point.x, point.y)
            -- print(string.format("(%d, %d) adjacent %d", checkX, checkY, checkAdjacency))
            return baseSelection:contains(point.x, point.y) and checkAdjacency < 4
        end
        
        -- Check if facing is navigable then return direction of nearby border. Favors counter clockwise movement due to top left corner ordering.
        function checkHugDirection(direction)
            -- print("initiate hug direction check")
            local clockX = directionsX[rotateFacing(direction, 1)] + driver[1]
            local clockY = directionsY[rotateFacing(direction, 1)] + driver[2]
            local counterX = directionsX[rotateFacing(direction, -1)] + driver[1]
            local counterY = directionsY[rotateFacing(direction, -1)] + driver[2]
            -- print(string.format("Clock: %d, %d - Counter: %d, %d", clockX, clockY, counterX, counterY))
            -- print("checking direction...")
            if checkFacingEdge(direction) then
                -- print("is edge, checking for rotation...")
                if not baseSelection:contains(counterX, counterY) then
                    return 1
                elseif not baseSelection:contains(clockX, clockY) then
                    return -1
                end
            end
            return 0
        end
        
        -- Check if corner and add to exploited corners list so calculation is not repeated unnecessarily.
        function markPixel()
            exploitedPixels[driver[1] * rectangle.height + driver[2]] = true
        end
            
        --
        function driveForwards()
            driver[1] = driver[1] + directionsX[facing]
            driver[2] = driver[2] + directionsY[facing]
            -- print("drove to " + table.concat(driver, ", "))
        end
        
        -- Perform calculations if not already exploited.
        if exploitedPixels[driver[1] * rectangle.height + driver[2]] == nil then
            -- print("started border web at: "..table.concat(driver, ", "))
            local iteration = 0
            local timeout = 0
            -- to ensure a clean starting strand
            local cleanOrigin = {}
            local spinDirection = checkHugDirection(facing)
            while(spinDirection == 0 and timeout < 8) do
                -- print(string.format("facing: %d", facing))
                facing = rotateFacing(facing, 1)
                timeout = timeout + 1
                spinDirection = checkHugDirection(facing)
            end
            -- print(string.format(" determined spin direction to be: %d, with initial facing: %d", spinDirection, facing))
            -- Create strands until original location reached. (webCluster, borderWeb, strand, pixel)
            if spinDirection ~= 0 then
                repeat
                    --print(" starting strand")
                    if #cleanOrigin == 0 and #borderWeb > 0 then
                        cleanOrigin = {driver[1], driver[2]}
                    end
                    -- Check if facing is navigable without direction change, advance and add the coordinate to strand.
                    strand = {}
                    while(checkFacingEdge(facing) and not checkFacingEdge(rotateFacing(facing, spinDirection * -1))
                    and not (checkFacingEdge(rotateFacing(facing, spinDirection * -2))
                    and (baseSelection:contains(checkDirection(rotateFacing(facing, spinDirection * -1)).x,
                    checkDirection(rotateFacing(facing, spinDirection * -1)).y) or #strand > 0))) do
                        table.insert(strand, {["x"] = driver[1], ["y"] = driver[2]})
                        --print("  added pixel to strand : " .. table.concat(driver, ", "))
                        markPixel()
                        driveForwards()
                    end
                    table.insert(strand, {["x"] = driver[1], ["y"] = driver[2]})
                    markPixel()
                    table.insert(borderWeb, {["components"] = strand, ["normalFacing"] = rotateFacing(facing, spinDirection * -2), ["spin"] = spinDirection})
                    if #webCluster == 0 then
                        -- print(" completed strand at: "..table.concat(driver, ", ").." facing "..facing.." length "..#strand..". rotating...")
                    end
                    -- Rotate until navigable starting 90 degrees offset to hug border, advance and terminate strand.
                    facing = rotateFacing(facing, spinDirection * -2)
                    timeout = 0
                    while(not checkFacingEdge(facing) and timeout < 8) do
                        facing = rotateFacing(facing, spinDirection)
                        timeout = timeout + 1                    
                    end
                    --print(" rotation complete at facing: "..facing)
                    iteration = iteration + 1
                until((sameCoord(driver, cleanOrigin) and exploitedPixels[checkDirection(facing).x * rectangle.height + checkDirection(facing).y] == true)
                or iteration > #corners * 2)
                table.remove(borderWeb, 1)
                table.insert(webCluster, borderWeb)
                -- print(string.format("completed border web %d of %d / %d strands", #webCluster, #borderWeb, #corners * 2))
            else
                -- print("border web was a dead end")
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
        pixel.normalX = point.x + directionsX[strand.normalFacing]
        pixel.normalY = point.y + directionsY[strand.normalFacing]
        if aInside then
            pixel.x = point.x
            pixel.y = point.y
        else
            pixel.x = pixel.normalX
            pixel.y = pixel.normalY
        end
        pixel.sourceX = strand.components[cornerIndex].x
        pixel.sourceY = strand.components[cornerIndex].y
        pixel.compareX = strand.components[cornerIndex].x + directionsX[rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
        pixel.compareY = strand.components[cornerIndex].y + directionsY[rotateFacing(strand.normalFacing, normalOffset * strand.spin)]
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
            comparisonIndex = comparisonIndex % -#web + #web
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
            comparisonIndex = comparisonIndex % -#web + #web
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
    
    aliasPixels = {}
    --
    function generateAliasData(squid)
        for strandIndex, strand in ipairs(squid) do
            if strand.normalFacing % 2 == 1 then
                if aInside then
                    if facingChange(strandIndex, -1, squid) < 0 and facingChange(strandIndex, 1, squid) == -1 then
                        -- print("slope up ahead")
                        if (facingChange(strandIndex, -2, squid) == 0 or strandSize(strandIndex, -1, squid) > 2) then
                            if(facingChange(strandIndex, -1, squid) == -2) then
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
                            if(facingChange(strandIndex, 1, squid) == 2) then
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

    if #webCluster > 0 then
        for squidex, tendril in ipairs(webCluster) do
            generateAliasData(tendril)
            -- print("border pixel data generation complete")
        end
    end

    -- color selection
    if aAutomate and #aliasPixels > 0 then
        spr.selection = Selection()
        local image = app.activeImage:clone()
        local sourceImage = app.activeImage
        local cel = app.activeImage.cel
        local pc = app.pixelColor
        
        for index, pixel in ipairs(aliasPixels) do
            function mixClean(c1, c2, source, colorFunction, percent)
                if source ~= nil then
                    if source == c1 then c1 = c2
                    elseif source == c2 then c2 = c1
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
                if aAverageInsideColor then
                    local normalValue = sourceImage:getPixel(pixel.normalX - cel.position.x, pixel.normalY - cel.position.y)
                    local cornerValue = sourceImage:getPixel(pixel.sourceX - cel.position.x, pixel.sourceY - cel.position.y)
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
                if pixel.x - cel.position.x == 169 then
                    print(string.format("S:(%d, %d), C:(%d, %d), %f P", pixel.x, pixel.y, pixel.compareX, pixel.compareY, pixel.percent))
                end
                image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y, mixColour(sourceValue, inletValue, nil, pixel.percent))
            elseif not aInside and pixel.percent > 0 then
                local sourceValue = sourceImage:getPixel(pixel.sourceX - cel.position.x, pixel.sourceY - cel.position.y)
                local underValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
                -- print(string.format("U:(%d, %d), S:(%d, %d), %f P", pixel.x, pixel.y, pixel.sourceX, pixel.sourceY, pixel.percent))
                image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y, mixColour(sourceValue, underValue, nil, pixel.percent))
            end
        end
        
        app.activeImage:drawImage(image)
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

if cutCornersDialogue() then
    app.transaction(cutCorners())
end

app.refresh()