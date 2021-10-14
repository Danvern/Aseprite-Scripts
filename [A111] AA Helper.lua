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
                
                -- check if a pixel is a corner of the selection boundary
                function checkCorner(x, y)
                    bounded=function(adj)
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
                    adj = getAdjacent(x, y)
                    if bounded(adj) == 2 then
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
                
                -- expand outwards from corner pixel to define a partial outline based on thresholds
                border = {}
                edgeCrawl=function(x, y, border)
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
                            table.insert(strand, 1, {x, y, x, y, sx, sy, 0})
                            -- if the selected region is in a positive direction relative to the border
                            positive = not baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)
                            while ((positive and not baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)) or
                            (not positive and not baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)))
                            and baseSelection:contains(ax + cx * d, ay + cy * d) do
                                -- the coordinates of the target pixel, origin pixel, and sx/sy
                                pixel = {ax + cx * d, ay + cy * d, x, y, sx, sy, 0}
                                table.insert(strand, pixel)
                                --print(string.format("Tested: %d, %d, %d, %d, %d, %d", pixel[1], pixel[2], pixel[3], pixel[4], pixel[5], pixel[6]))
                                d = d + 1
                            end
                        end
                            
                        if #strand > 0 then
                            for i=math.floor(#strand*(aMin/100)), math.floor(#strand*(aMax/100)), 1 do
                                if strand[i] ~= nil then
                             -- print(#strand)
                                -- table.insert(border, {strand[i], i / #strand})
                                --  print(strand[i])
                                -- print(string.format("Tested: %d, %d for total %d", strand[i], strand[i][1], strand[i][2]))
                                --print("wooo")
                                    -- TO DO: add custom scaling threshold
                                    if aInside then
                                        strand[i][7] = clamp(1.0, i / (#strand * aScale), 0.0)
                                    else
                                        strand[i][7] = 1.0 - clamp(1.0, i / ((#strand) * aScale), 0.0)
                                    end
                                    table.insert(border, strand[i])
                                end
                            end
                        end
                        
                    end
                end
                for index, coord in ipairs(corners) do
                    edgeCrawl(coord[1], coord[2], border)
                end
                            
               
                
                -- color selection
                if aAutomate then
                    spr.selection = Selection()
                    local image = app.activeImage:clone()
                    local cel = app.activeImage.cel
                    local pc = app.pixelColor
                    
                    for index, coord in ipairs(border) do
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

                        if aInside then
                            sourceValue = image:getPixel(coord[3] - cel.position.x, coord[4] - cel.position.y)
                            pAdjacent = image:getPixel(coord[1] + coord[5] - cel.position.x, coord[2] + coord[6] - cel.position.y)
                            nAdjacent = image:getPixel(coord[1] - coord[5] - cel.position.x, coord[2] - coord[6] - cel.position.y)
                            targetValue = mixColour(pAdjacent, nAdjacent, sourceValue, 0.5)
                            image:drawPixel(coord[1] - cel.position.x, coord[2] - cel.position.y, mixColour(sourceValue, targetValue, nil, coord[7]))
                        else
                            sourceValue = image:getPixel(coord[3] - cel.position.x, coord[4] - cel.position.y)
                            underValue = image:getPixel(coord[1] - cel.position.x, coord[2] - cel.position.y)
                            image:drawPixel(coord[1] - cel.position.x, coord[2] - cel.position.y, mixColour(sourceValue, underValue, nil, coord[7]))
                        end
                    end
                    app.activeImage:drawImage(image)
                else
                     -- returned found pixels as a selection
                    newSelection = Selection()
                    for index, coord in ipairs(border) do
                        newSelection:add(Selection(Rectangle(coord[1], coord[2], 1, 1)))
                        -- print(newSelection.bounds)
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

