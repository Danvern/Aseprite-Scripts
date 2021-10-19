function init(plugin)
    if plugin.preferences.aliasMax == nil then
        plugin.preferences.aliasMax = 50
    end
        if plugin.preferences.aliasMin == nil then
        plugin.preferences.aliasMin = 0
    end
        if plugin.preferences.aliasInside == nil then
        plugin.preferences.aliasInside = false
    end
    if plugin.preferences.aliasAutomatic == nil then
        plugin.preferences.aliasAutomatic = false
    end

    plugin:newCommand{
        id="AATool",
        title="AA Tool",
        group="sprite_properties",
        onclick=function()
            local spr = app.activeSprite
            if not spr then return end

            local baseSelection = spr.selection
            if baseSelection.isEmpty then return end

            local info = Dialog()
                info:label{ 
                    id=string,
                    label="-------- AA Assist Control Panel --------",
                    text="Set percentages and other values to control the selection area."
                }
                info:slider{
                    id="aliasMax",
                    label="Max Threshold",
                    min=0,
                    max=100,
                    value=plugin.preferences.aliasMax
                }
                info:slider{
                    id="aliasMin",
                    label="Min Threshold",
                    min=0,
                    max=100,
                    value=plugin.preferences.aliasMin
                }
                info:check{
                    id="aliasInside", 
                    label="AA Inside Selection", 
                    text="Anti-alias inside of the selection versus outside of it.", 
                    selected=plugin.preferences.aliasInside
                }
                info:check{
                    id="aliasAutomatic",
                    label="AA Automatically", 
                    text="Automatically apply colors instead of stenciling the selection.", 
                    selected=plugin.preferences.aliasAutomatic
                }
                info:button{
                    id="resetSettings",
                    text="Reset Settings", 
                    onclick=function()
                        info.data.aliasMax=50
                        info.data.aliasMin=0
                        info.data.aliasInside=false
                        info.data.aliasAutomatic=false
                        print("(WIP) Settings Have Been Reset")
                    end
                }
                info:button{id="ok",text="OK"}
                info:show()
                local aMax=info.data.aliasMax
                local aMin=info.data.aliasMin
                local aScale=1.0
                local aInside=info.data.aliasInside
                local aAutomate=info.data.aliasAutomatic
                plugin.preferences.aliasMax=aMax
                plugin.preferences.aliasMin=aMin
                plugin.preferences.aliasInside=aInside
                plugin.preferences.aliasAutomatic=aAutomate

            function run()
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
                    adj = getAdjacent(x, y)
                    if adjacencyCount(adj) == 3 or adjacencyCount(adj) == 2 then
                        -- print(string.format("Found corner here: %d, %d", x, y))
                        return true
                    end
                end
                
                -- iterate through the boundaries of selection to add corner pixels to a table
                local rectangle = baseSelection.bounds
                local corners = {}
                -- print(rectangle) 
                for x = rectangle.x, rectangle.width + rectangle.x, 1 do
                    for y = rectangle.y, rectangle.height + rectangle.y, 1 do
                        -- print("test0")
                        if checkCorner(x, y) and baseSelection:contains(x, y) then
                            table.insert(corners, {x, y})
                        end
                    end
                end
                
                exploitedCorners = {}
                webCluster = {}
                -- generate a series of looped border data
                for index, coord in ipairs(corners) do
                    -- clockwise starting from the top middle
                    local directionsX = {0, 1, 1, 1, 0, -1, -1, -1}
                    local directionsY = {-1, -1, 0, 1, 1, 1, 0, -1}
                    local facing = 1
                    local spinDirection = 0
                    local driver = {coord[1], coord[2]}
                    local borderWeb = {}
                    
                    -- compared two coordinates for equivalency
                    function sameCoord(coordinate, coordinate2)
                        return coordinate[1] == coordinate2[1] and coordinate[2] == coordinate2[2]
                    end
                    
                    -- Rotate facing by specified amount of offsets. Positive is clockwise.
                    function rotateFacing(facing, spin)
                        face = facing - 1 + spin
                        if face < 0 then
                            face = face % -8 + 8
                        else
                            face = face % 8
                        end
                        return face + 1
                    end
                    
                    -- 
                    function checkFacingEdge(direction)
                        checkX = directionsX[direction] + driver[1]
                        checkY = directionsY[direction] + driver[2]
                        checkAdjacency = adjac5encyCount(checkX, checkY)
                        return baseSelection:contains(checkX, checkY) and checkAdjacency > 0 and checkAdjacency < 4
                    end
                    
                    -- Check if facing is navigable then return direction of nearby border. Favors counter clockwise movement due to top left corner ordering.
                    function checkHugDirection(direction)
                        clockX = directionsX[rotateFacing(direction, 1)] + driver[1]
                        clockY = directionsY[rotateFacing(direction, 1)] + driver[2]
                        counterX = directionsX[rotateFacing(direction, -1)] + driver[1]
                        counterY = directionsY[rotateFacing(direction, -1)] + driver[2]
                        
                        if checkFacingEdge(direction) then
                            if not baseSelection:contains(counterX, counterY) then
                                return 1
                            elseif not baseSelection:contains(clockX, clockY) then
                                return -1
                            end
                        end
                        return 0
                    end
                    
                    -- Check if corner and add to exploited corners list so calculation is not repeated unnecessarily.
                    function markCorner()
                        if adjacencyCount(driver[1], driver[2]) == 2 or adjacencyCount(driver[1], driver[2]) == 3 then
                            exploitedCorners[driver[1] * rectangle.height + driver[2]] = true
                        end
                    end
                        
                    --
                    function driveForwards()
                        driver[1] = driver[1] + directionsX[facing]
                        driver[2] = driver[2] + directionsY[facing]
                    end
                    
                    -- Perform calculations if not already exploited.
                    if exploitedCorners[driver[1] * rectangle.height + driver[2]] == nil then
                        repeat
                            spinDirection = checkHugDirection(facing)
                            facing = rotateFacing(facing, 1)
                        until(spinDirection ~= 0)
                        -- Create strands until original location reached. (webCluster, borderWeb, strand, pixel)
                        repeat
                            -- Check if facing is navigable without direction change, advance and add the coordinate to strand.
                            strand = {}
                            while(checkFacingEdge(facing)) do
                                table.insert(strand, {["x"] = driver[1], ["y"] = driver[2]})
                                markCorner()
                                driveForwards()
                            end
                            table.insert(strand, {["x"] = driver[1], ["y"] = driver[2]})
                            markCorner()
                            table.insert(borderWeb, {["components"] = strand, ["normalFacing"] = rotateFacing(facing, spinDirection * -2)})
                            
                            -- Rotate until navigable starting 90 degrees offset to hug border, advance and terminate strand.
                            facing = rotateFacing(facing, spinDirection * -2)
                            repeat
                                facing = rotateFacing(facing, spinDirection)
                            until(checkFacingEdge(facing))
                        until(sameCoord(driver, coord))
                        table.insert(webCluster, borderWeb)
                    end
                end
                
                -- general purpose calculation
                function calculatePixel(point, strand, primaryVertexOffset)
                    pixel = {}
                    cornerIndex = 1
                    normalOffset = 2
                    if primaryVertexOffset > 0 then
                        cornerIndex = 1
                        normalOffset = -2
                    else
                        cornerIndex = #strand.components
                        normalOffset = 2
                    end
                    pixel.x = point.x
                    pixel.y = point.y
                    pixel.sourceX = strand.components[cornerIndex].x
                    pixel.sourceY = strand.components[cornerIndex].y
                    pixel.compareX = strand.components[cornerIndex].x - directionsX[rotateFacing(strand.normalFacing, normalOffset)]
                    pixel.compareY = strand.components[cornerIndex].y - directionsY[rotateFacing(strand.normalFacing, normalOffset)]
                    percent = 0.0
                    if aInside then
                        percent = clamp(1.0, index / (#strand.components * aScale), 0.0)
                    else
                        percent = 1.0 - clamp(1.0, index / ((#strand.components) * aScale), 0.0)
                    end
                    pixel.percent = percent
                    return pixel
                end
                
                function facingChange(strandIndex, offset, web)
                    comparisonIndex = strandIndex - 1 + offset
                    if comparisonIndex < 0 then
                        comparisonIndex = comparisonIndex % -#web + #web
                    else
                        comparisonIndex = comparisonIndex % #web
                    end
                    comparisonIndex = comparisonIndex + 1
                    return web[comparisonIndex].normalFacing - web[strandIndex].normalFacing
                end
                
                aliasPixels = {}
                --
                function generateAliasData(squid)
                    for strandIndex, strand in ipairs(squid) do
                        if strand.normalFacing % 2 == 1 then
                            if facingChange(strandIndex, -1, squid) == -1 and facingChange(strandIndex, 1, squid) == -1 then
                                for index, point in ipairs(strand.components) do
                                    table.insert(aliasPixels, calculatePixel(point, strand, 1))
                                end
                            elseif facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) == 1 then
                                for index, point in ipairs(strand.components) do
                                    table.insert(aliasPixels, calculatePixel(point, strand, -1))
                                end
                            elseif facingChange(strandIndex, -1, squid) == 1 and facingChange(strandIndex, 1, squid) == -1 then
                            
                            end
                        end
                        
                    end
                end

                for squidex, tendril in ipairs(webCluster) do
                    generateAliasData(tendril)
                end
                
                -- expand outwards from corner pixel to define a partial outline based on thresholds
                edgeCrawl=function(x, y, borderWeb)
                    for index, coord in ipairs(getAdjacent(x, y)) do
                        ax = coord[1]
                        ay = coord[2]
                        strand = {}
                        
                        d = 0
                        -- strand cell core
                        cx = (ax - x)
                        cy = (ay - y)
                        -- adjacent to current strand cell
                        sx = math.abs(ay - y)
                        sy = math.abs(ax - x)
                        
                        if not baseSelection:contains(ax, ay) and not aInside then
                            -- if the selected region is in a positive direction relative to the border
                            positive = baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)
                            while ((positive and baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)) or
                            (not positive and baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)))
                            and not baseSelection:contains(ax + cx * d, ay + cy * d) do
                                pixel = {ax + cx * d, ay + cy * d, x, y, sx, sy, 0}
                                table.insert(strand, pixel)
                                --print(string.format("Tested: %d, %d, %d, %d, %d, %d", pixel[1], pixel[2], pixel[3], pixel[4], pixel[5], pixel[6]))
                                d = d + 1
                            end
                        elseif aInside then
                            -- inside corner is part of selection
                            table.insert(strand, 1, {x, y, x, y, sx, sy, 1})
                            -- if the selected region is in a positive direction relative to the border
                            positive = not baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)
                            while ((positive and not baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)) or
                            (not positive and not baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)))
                            and baseSelection:contains(ax + cx * d, ay + cy * d) do
                                -- the coordinates of the target pixel, origin pixel, and sx/sy
                                pixel = {ax + cx * d, ay + cy * d, x, y, sx, sy, 1}
                                table.insert(strand, pixel)
                                --print(string.format("Tested: %d, %d, %d, %d, %d, %d", pixel[1], pixel[2], pixel[3], pixel[4], pixel[5], pixel[6]))
                                d = d + 1
                            end
                        end
                            
                        if #strand > 0 then
                            for i=math.floor(#strand*(aMin/100)), math.floor(#strand*(aMax/100)), 1 do
                                if strand[i] ~= nil then
                             -- print(#strand)
                                -- table.insert(borderWeb, {strand[i], i / #strand})
                                --  print(strand[i])
                                -- print(string.format("Tested: %d, %d for total %d", strand[i], strand[i][1], strand[i][2]))
                                --print("wooo")
                                    -- TO DO: add custom scaling threshold
                                    if aInside then
                                        strand[i][7] = clamp(1.0, i / (#strand * aScale), 0.0)
                                    else
                                        strand[i][7] = 1.0 - clamp(1.0, i / ((#strand) * aScale), 0.0)
                                    end
                                    --table.insert(borderWeb, strand[i])
                                end
                            end
                            table.insert(borderWeb, {strand, cx, cy})
                        end
                    end
                end
                
                -- for index, coord in ipairs(corners) do
                    -- edgeCrawl(coord[1], coord[2], borderWeb)
                -- end
                            
                
                -- color selection
                if aAutomate then
                    spr.selection = Selection()
                    local image = app.activeImage:clone()
                    local sourceImage = app.activeImage
                    local cel = app.activeImage.cel
                    local pc = app.pixelColor
                    
                    -- for index, strand in ipairs(borderWeb) do
                        -- for index, coord in ipairs(strand[1]) do
                            -- --print(table.concat(coord, " "))
                            -- --print(cel.position)
                            -- --print(cel.position.x)
                            -- --print(image)
                            -- function mixClean(c1, c2, source, colorFunction, percent)
                                -- if source ~= nil then
                                    -- if source == c1 then c1 = c2
                                    -- elseif source == c2 then c2 = c1
                                    -- end
                                -- end
                                -- return colorFunction(c1) * percent + colorFunction(c2) * (1 - percent)
                            -- end
                            -- function mixColour(c1, c2, mask, percent)
                                -- rVal = mixClean(c1, c2, mask, pc.rgbaR, percent)
                                -- gVal = mixClean(c1, c2, mask, pc.rgbaG, percent)
                                -- bVal = mixClean(c1, c2, mask, pc.rgbaB, percent)
                                -- return pc.rgba(rVal, gVal, bVal)
                            -- end

                            -- if aInside and coord[7] < 1 then
                                -- sourceValue = sourceImage:getPixel(coord[1] - cel.position.x, coord[2] - cel.position.y)
                                -- --inletX = coord[3] - clamp(-1, coord[1] - coord[3], 1)
                                -- --inletY = coord[4] - clamp(-1, coord[2] - coord[4], 1)
                                -- inletX = coord[3] - strand[2]
                                -- inletY = coord[4] - strand[3]
                                -- inletValue = sourceImage:getPixel(inletX - cel.position.x, inletY - cel.position.y)
                                -- --pAdjacent = image:getPixel(coord[1] + coord[5] - cel.position.x, coord[2] + coord[6] - cel.position.y)
                                -- --nAdjacent = image:getPixel(coord[1] - coord[5] - cel.position.x, coord[2] - coord[6] - cel.position.y)
                                -- --targetValue = mixColour(pAdjacent, nAdjacent, sourceValue, 0.5)
                                -- image:drawPixel(coord[1] - cel.position.x, coord[2] - cel.position.y, mixColour(sourceValue, inletValue, nil, coord[7]))
                            -- elseif not aInside and coord[7] > 0 then
                                -- sourceValue = sourceImage:getPixel(coord[3] - cel.position.x, coord[4] - cel.position.y)
                                -- underValue = sourceImage:getPixel(coord[1] - cel.position.x, coord[2] - cel.position.y)
                                -- image:drawPixel(coord[1] - cel.position.x, coord[2] - cel.position.y, mixColour(sourceValue, underValue, nil, coord[7]))
                            -- end
                        -- end
                    -- end
                    
                    for index, pixel in ipairs(aliasPixels) do
                        --print(table.concat(coord, " "))
                        --print(cel.position)
                        --print(cel.position.x)
                        --print(image)
                        function mixClean(c1, c2, source, colorFunction, percent)
                            if source ~= nil then
                                if source == c1 then c1 = c2
                                elseif source == c2 then c2 = c1
                                end
                            end
                            return colorFunction(c1) * percent + colorFunction(c2) * (1 - percent)
                        end
                        
                        function mixColour(c1, c2, mask, percent)
                            rVal = mixClean(c1, c2, mask, pc.rgbaR, percent)
                            gVal = mixClean(c1, c2, mask, pc.rgbaG, percent)
                            bVal = mixClean(c1, c2, mask, pc.rgbaB, percent)
                            return pc.rgba(rVal, gVal, bVal)
                        end

                        if aInside and pixel.percent < 1 then
                            sourceValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
                            inletValue = sourceImage:getPixel(pixel.compareX - cel.position.x, pixel.compareY - cel.position.y)
                            image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y, mixColour(sourceValue, inletValue, nil, pixel.percent))
                        elseif not aInside and pixel.percent > 0 then
                            sourceValue = sourceImage:getPixel(pixel.sourceX - cel.position.x, pixel.sourceY - cel.position.y)
                            underValue = sourceImage:getPixel(pixel.x - cel.position.x, pixel.y - cel.position.y)
                            image:drawPixel(pixel.x - cel.position.x, pixel.y - cel.position.y, mixColour(sourceValue, underValue, nil, pixel.percent))
                        end
                    end
                    
                    app.activeImage:drawImage(image)
                else
                     -- returned found pixels as a selection
                    newSelection = Selection()
                    for index, pixel in ipairs(aliasPixels) do
                        if (pixel.percent > 0 and not aInside) or (pixel.percent < 1 and aInside) then
                            newSelection:add(Selection(Rectangle(pixel.x, pixel.y, 1, 1)))
                        end
                    end
                    spr.selection = newSelection
                end
            end

            -- if info.data.ok then
            if true then
                app.transaction(run)
            end

            app.refresh()
        end
    }
end

function exit(plugin)

end