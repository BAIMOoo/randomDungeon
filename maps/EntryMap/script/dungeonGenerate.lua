local M ={}
local map_min_x = -6300
local map_min_y = -6300
local map_max_x = 6300
local map_max_y = 6300
local wall_size = 100
-- 1为路，0为墙
local map = {}
local wall_queue = {}
local existing_rooms

---map[x][y]
---{
--- type string -- 'road' or 'room'
--- x number 格点坐标x
--- y number 格点坐标y
--- isVisited boolean --是否被访问过
--- searchDirection
--- sfx
---}
---
---{
--- type string -- 'wall'
--- x number 格点坐标x
--- y number 格点坐标y
--- unit Unit
---}


---分帧处理墙队列
M.wallQueueExec= function ()
    ---每阵创建单位数量
    local num = 200
    y3.ltimer.loop_frame(3,function (timer, count)
        local c = 0
        for i,u in pairs(wall_queue) do
            if u.type == 'create' then
                if c > num then
                    break
                end
                
                local point = M.getPosByXy(u.x,u.y)
                local unit = y3.unit.create_unit(y3.player(32),134231560,point,0)
                map[u.x][u.y].unit = unit   
                wall_queue[i] = nil
                else if u.type == 'remove' then
                    if u.sfx then
                        u.sfx:remove()
                    end
                    M.removeWall(u.x,u.y)
                    wall_queue[i] = nil
                end
            end
            c = c + 1
        end
    end)
end

---格点转化为世界坐标
M.getPosByXy = function (x,y)
    return y3.point(x*wall_size, y*wall_size, 0)
end

--- 添加墙到队列
--- x - point 格点坐标
--- y - point 格点坐标
M.addWallToQueue = function (x, y)
    map[x][y].type = 'wall'
    table.insert(wall_queue,{
        x = x,
        y = y,
        type = 'create',
    })
end

M.addWallRemoveToQueue = function (x,y)
    map[x][y].type = 'road'
    table.insert(wall_queue,{
        x = x,
        y = y,
        type = 'remove',
    })
end

---获取格点处的墙体
M.getUnitByPos = function (x,y)
    -- local shape = y3.shape.create_circular_shape(50)
    -- local selector = y3.selector.create()
    -- local unitGroup = selector
    --     :in_shape(y3.point(x*wall_size, y*wall_size, 0), shape)
    --     :is_unit_type(134231560)
    --     :count(1)
    --     :sort_type("由近到远")
    --     :get()
    --     :pick()
    -- if #unitGroup == 0 then
    --     return nil
    -- end
    if map[x][y].unit then
        return map[x][y].unit
    end
    return nil
    
end

--- 删除格点处的墙体
M.removeWall = function (x,y)
    local wall = M.getUnitByPos(x,y)
    if wall then
        wall:remove()
    end
end


--- 在地图边缘创建墙
M.createWallOnMapEdge = function ()
    -- 沿着底部边缘创建墙体
    for x = map_min_x, map_max_x, wall_size do
        local point = y3.point(x, map_min_y)
        local wall = M.addWallToQueue(point)
    end

    -- 沿着顶部边缘创建墙体
    for x = map_min_x, map_max_x, wall_size do
        local point = y3.point(x, map_max_y)
        local wall = M.addWallToQueue(point)
    end

    -- 沿着左边缘创建墙体
    for y = map_min_y + 1, map_max_y - 1, wall_size do
        local point = y3.point(map_min_x, y)
        local wall = M.addWallToQueue(point)
    end

    -- 沿着右边缘创建墙体
    for y = map_min_y + 1, map_max_y - 1, wall_size do
        local point = y3.point(map_max_x, y)
        local wall = M.addWallToQueue(point)
    end
end

--- 随机生成不重叠的矩形房间并用墙围起来
--- @param max_attempts integer --最大尝试生成次数
--- @param min_room_size integer --房间最小尺寸 (width, height)
--- @param max_room_size integer --房间最大尺寸 (width, height)
--- @param existing_rooms table --已有房间的坐标表 { {left, right, top, bottom} }
--- @return existing_rooms table --更新后的已有房间列表
--- @return reduce_road_number integer --减少的道路数量
M.generateRandomRoom = function(max_attempts, min_room_size, max_room_size, existing_rooms)
    local reduce_road_number = 0
    for attempt = 1, max_attempts do
        
        -- 随机生成房间大小
        local room_width = math.random(min_room_size[1], max_room_size[1]-1)
        local room_height = math.random(min_room_size[2], max_room_size[2]-1)
        -- print("房间尺寸:", room_width, room_height)
        -- 在地图范围内随机选择一个起点
        local start_x = math.random(math.floor(map_min_x/wall_size)+1, math.floor(map_max_x/wall_size)-room_width-1)
        local start_y = math.random(math.floor(map_min_y/wall_size)+1, math.floor(map_max_y/wall_size)-room_height-1)
        -- print("房间起点:", start_x, start_y)
        -- 计算房间边界(非世界坐标，格点坐标)
        local left = start_x
        local right = start_x + room_width
        local top = start_y + room_height
        local bottom = start_y
        -- 确保房间的边界是奇数
        if left % 2 == 0 then
            left = left + 1
        end
        if top % 2 == 0 then
            top = top - 1
        end
        if right % 2 == 0 then
            right = right - 1
        end
        if bottom % 2 == 0 then
            bottom = bottom + 1
        end
        -- print("房间边界:", left, right, top, bottom)
        -- 检测是否与已有房间重叠
        local overlap = false
        local buffer = 1
        for _, existing in ipairs(existing_rooms) do
            local ex_left, ex_right, ex_top, ex_bottom = table.unpack(existing)
            if not (right < ex_left-buffer or left > ex_right+buffer or top < ex_bottom-buffer or bottom > ex_top+buffer) then
                overlap = true
                break
            end
        end

        if not overlap then
            -- 添加新的房间到列表
            table.insert(existing_rooms, {
                [1] = left, 
                [2] = right, 
                [3] =top, 
                [4] = bottom
            })


            for x = left, right do
                for y = bottom, top do
                    if map[x][y].type == 'wall' then
                        M.addWallRemoveToQueue(x,y)
                    elseif map[x][y].type == 'road' and (x~=left or x~=right or y~=bottom or y~=top) then
                        map[x][y].type = 'room'
                        map[x][y].isVisited = true
                        reduce_road_number = reduce_road_number + 1

                    end
                end
            end

            -- 创建房间周围的墙
            -- 底部和顶部墙体
            for x = left, right do
                M.addWallToQueue(x, bottom) -- 底部墙
                M.addWallToQueue(x, top)     -- 顶部墙
            end

            -- 左侧和右侧墙体（排除角落以避免重复）
            for y = bottom + 1, top - 1 do
                M.addWallToQueue(left, y)   -- 左侧墙
                M.addWallToQueue(right, y)  -- 右侧墙
            end

            -- print("成功生成一个新房间")
        end
    end
    return existing_rooms, reduce_road_number
end

--- 随机从表里取一对键值对
--- @param tbl table --表
--- @param isRemove boolean --是否从表中删除该键值对
--- @return any --随机的键值对
--- @return any --随机键值对的值  
table.random_kv = function(tbl, isRemove)
    if not tbl then return end
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    
    if #keys > 0 then
        local rand_key = keys[math.random(#keys)]
        local value = tbl[rand_key]
        if isRemove then
            tbl[rand_key] = nil
        end
        return rand_key, value
    end
    
    return nil, nil
end

--- 破坏房间的墙壁，能让玩家从外面进入房间
M.detoryRoomWall = function ()
    ---获取一个随机墙壁
    for k,room in pairs(existing_rooms) do
        -- 随机选取一个边
        --ex_left, ex_right, ex_top, ex_bottom
        
        local x,y
        local count = math.random(1,4)
        for i = 1, count do
            local key, random_edge = table.random_kv(room, false)
            -- print(room[1],room[2],room[3],room[4])
            if key == 1 or key == 2 then
                x = random_edge
                y = math.random(room[4]+1, room[3]-1)
            end

            if key == 3 or key == 4 then
                x = math.random(room[1]+1, room[2]-1)
                y = random_edge
            end
            M.addWallRemoveToQueue(x,y)
        end

    end
end

-- 删除死胡同
---comment
M.removeDeadAlley = function ()
    local function count_neighbors(road)
        local x = road.x
        local y = road.y
        local count = 0
        if x and y then
            if map[x+1][y].type == 'wall' then
                count = count + 1
            end
            if map[x-1][y].type == 'wall' then
                count = count + 1
            end
            if map[x][y+1].type == 'wall' then
                count = count + 1
            end
            if map[x][y-1].type == 'wall' then
                count = count + 1
            end
        end
        return count
    end

    local checkDeadAlley = function ()
        local finished = true
        for x = map_min_x/wall_size+1, map_max_x/wall_size-1, 1 do
            for y = map_min_y/wall_size+1, map_max_y/wall_size-1, 1 do 
                local cell = map[x][y]
                if cell.type == 'road' then
                    local count = count_neighbors(cell)
                    if count >= 3 then
                        finished = false
                        break
                    end
                end
            end
        end
        return finished
    end


    for x = map_min_x/wall_size+1, map_max_x/wall_size-1, 1 do
        for y = map_min_y/wall_size+1, map_max_y/wall_size-1, 1 do 
            local cell = map[x][y]
            if cell.type == 'road' then
                local count = count_neighbors(cell)
                if count >= 3 then
                    -- print("死胡同:", x, y)
                    M.addWallToQueue(x, y) 
                    -- y3.particle.create({
                    --     type = 134268468,
                    --     target = M.getPosByXy(x,y)
                    -- })
                end
            end
        end
    end
    if checkDeadAlley() == false then
        M.removeDeadAlley()
    else
        print("没有死胡同")
        y3.game:event_notify('地图生成结束')
    end
    -- y3.ltimer.wait_frame(1, function (timer, count)
    --     if checkDeadAlley() == false then
    --         M.removeDeadAlley()
    --     else
    --         print("没有死胡同")
    --     end
    -- end)
end

function M.mapInit()
    -- 收集靠近边缘的点
    local edge_points = {}
    -- 初始道路数量
    local init_road_num = 0
    -- 初始化格点
    print(map_min_x/wall_size, map_max_x/wall_size)
    for x = map_min_x/wall_size, map_max_x/wall_size, 1 do
        for y = map_min_y/wall_size, map_max_y/wall_size, 1 do
            if x%2 ==0 and y%2 ==0 then
                if not map[x] then
                    map[x] = {}
                end
                local sfx = y3.particle.create({
                    type = 100000,
                    target = M.getPosByXy(x,y)
                })
                map[x][y] = {
                    type = 'road',
                    searchDirection = {{0, -1},{1, 0},{0, 1},{-1, 0}},
                    x = x,
                    y = y,
                    isVisited = false,
                    sfx = sfx
                }
                init_road_num= init_road_num + 1
                if x == map_min_x/wall_size+1 or x==map_max_x/wall_size-1 or y == map_min_y/wall_size+1 or y == map_max_y/wall_size-1 then
                    table.insert(edge_points, map[x][y])
                end

            else
                if not map[x] then
                    map[x] = {}
                end
                map[x][y] = {
                    type = 'wall',
                    x = x,
                    y = y,
                }
                M.addWallToQueue(x,y)
                
            end
        end
    end
    
    local exist_rooms, reduce_number = M.generateRandomRoom(200, {15, 15}, {27, 27}, {})
    existing_rooms = exist_rooms
    init_road_num = init_road_num - reduce_number
    -- print('xxxxx'..init_road_num)
    -- 随机选择一个边缘点作为起点
    local start_point
    local road = {}
    local serachedNode = {}

    if #edge_points > 0 then
        local selected_index = math.random(1, #edge_points)
        start_point = edge_points[selected_index]
        start_point.isVisited = true
        start_point.sfx:remove()
        -- print("起点:", start_point.x, start_point.y)
        road[#road+1] = start_point
        serachedNode[#serachedNode+1] = start_point
    end

    local num_per_frame = 200
    y3.ltimer.loop_frame(1,function (timer, count)
        for i = 1, num_per_frame do
            local directions = start_point.searchDirection
            -- print('loop count:', count, start_point.x, start_point.y)   
            if #directions > 0 then
                --- 获取随机方向
                -- print(y3.util.dump(directions))

                local random_key, direction = table.random_kv(directions, true)
                if random_key and direction then
                    local random_direction = direction
                    if map[start_point.x + 2*random_direction[1]] then
                        local next_point = map[start_point.x + 2*random_direction[1]][start_point.y + 2*random_direction[2]]
                        if next_point and next_point.type == 'road' and next_point.isVisited==false then
                            local between_point = map[start_point.x + random_direction[1]][start_point.y + random_direction[2]]
                            M.addWallRemoveToQueue(between_point.x, between_point.y)
                            --- 从当前方向表中删除该方向
                            start_point.searchDirection[random_key] = nil
                            -- M.addWallToQueue(between_point.x, between_point.y)
                            start_point = next_point
                            next_point.isVisited = true
                            next_point.sfx:remove()
                            start_point.road_key = #road + 1
                            road[#road+1] = start_point

                        end
                    end
                end
            else
                if #road >= init_road_num then
                    print("所有节点都探索完毕", #road, init_road_num)
                    timer:remove()
                    M.detoryRoomWall()
                    M.removeDeadAlley()
                    break
                    
                else
                    -- 如果所有方向都已经搜索完毕，则返回上一节点
                    start_point = road[start_point.road_key-1]
                    -- print("返回上一节点", start_point.x, start_point.y)
                end
            end
        end

    end)

end


y3.game:event('游戏-初始化', function (trg, data)
    M.wallQueueExec()
    M.mapInit()
    -- M.createWallOnMapEdge()
    --local existing_rooms = M.generateRandomRoom(100, {12,12},{32,32},{})

end)

-- y3.game:event("鼠标-双击单位", y3.const.MouseKey['LEFT'], function (_,data)
--     print(data.unit:get_point():get_x(), data.unit:get_point():get_y())
--     local x = data.unit:get_point():get_x()/wall_size
--     local y = data.unit:get_point():get_y()/wall_size
    
-- end)

-- y3.game:event("键盘-按下", "A", function (trg, data)
--     M.removeDeadAlley()
-- end)

-- y3.game:event("玩家-发送消息", function (trg, data)
--     local result = {}
--     data.str1:gsub("[^" .. '|' .. "]+", function(w)
--         table.insert(result, w)
--     end)
--     local x = tonumber(result[1])
--     local y = tonumber(result[2])

--     y3.particle.create({
--         type = 100700,
--         target = M.getPosByXy(x,y),
--         time = 3
--     })
--     print(y3.util.dump(map[x][y]))
-- end)