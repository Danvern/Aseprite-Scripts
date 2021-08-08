function init(plugin)
    -- we can use "plugin.preferences" as a table with fields for
    -- our plugin (these fields are saved between sessions)
    if plugin.preferences.count == nil then
        plugin.preferences.count = 0
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
                info:label{ id=string,
                    label="-------- AA Assist Control Panel --------",
                    text="Set percentages and other values to control the selection area."
                }
                info:slider{
                    id="aliasMax",
                    label="Max Threshold",
                    min=0,
                    max=100,
                    value=50
                }
                info:slider{
                    id="aliasMin",
                    label="Min Threshold",
                    min=0,
                    max=100,
                    value=0
                }
                info:button{id="ok",text="OK"}
                info:show()
                local aMax=info.data.aliasMax
                local aMin=info.data.aliasMin

            function run()
                function getAdjacent(x, y)
                    adj={}
                    adj[1]={x-1, y}
                    adj[2]={x+1, y}
                    adj[3]={x, y-1}
                    adj[4]={x, y+1}
                    return adj
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
                        if not baseSelection:contains(ax, ay) then
                            d = 0
                            -- strand cell core
                            cx = (ax - x)
                            cy = (ay - y)
                            -- adjacent to current strand cell
                            sx = math.abs(ay - y)
                            sy = math.abs(ax - x)
                            -- started with empty space to upper right, or bottom left
                            positive = baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)
                            while ((positive and baseSelection:contains(ax + cx * d + sx, ay + cy * d + sy)) or
                            (not positive and baseSelection:contains(ax + cx * d - sx, ay + cy * d - sy)))
                            and not baseSelection:contains(ax + cx * d, ay + cy * d) do
                                table.insert(strand, {ax + (ax - x) * d, ay + (ay - y) * d})
                                d = d + 1
                            end
                            for i=math.floor(#strand*(aMin/100)+1), math.floor(#strand*(aMax/100)), 1
                            do
                             -- print(#strand)
                                table.insert(border, strand[i])
                            end
                        end
                    end
                end
                for index, coord in ipairs(corners) do
                    edgeCrawl(coord[1], coord[2], border)
                end
                            
                -- returned found pixels as a selection
                newSelection = Selection()
                for index, coord in ipairs(border) do
                    newSelection:add(Selection(Rectangle(coord[1], coord[2], 1, 1)))
                    -- print(newSelection.bounds)
                end
                spr.selection = newSelection
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
  print("Aseprite is closing my plugin, MyFirstCommand was called "
        .. plugin.preferences.count .. " times")
end

