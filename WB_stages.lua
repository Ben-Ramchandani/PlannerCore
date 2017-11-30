-- require("on_init")
require("util")
-- require("blueprints")
-- require("config")
-- require("on_tick")
-- require("gui_button")

-- function place_ghost(state, data)
--     data.inner_name = data.name
--     data.name = "entity-ghost"
--     data.expires = false
--     if not state.surface.create_entity(data) then
--         game.print("Failed to place " .. serpent.block(data))
--     end
-- end

-- function is_car(entity)
--     return entity.prototype.friction_force
-- end

-- function place_other_entity(state, data)
--     data.force = state.force
--     place_ghost(state, data)
-- end

-- function place_wall(state, position, is_horizontal)
--     local data = {name = state.conf.wall, position = position, force = state.force}
--     if state.surface.can_place_entity(data) then
--         place_ghost(state, data)
--     elseif not table.contains(state.conf.water_tiles, state.surface.get_tile(position.x, position.y).name) then
--         local colliding = state.surface.find_entities_filtered({area = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}})
--         if #colliding == 0 then
--             game.print("WallBuilder: Couldn't place wall, but couldn't find a colliding entity or tile.")
--             return
--         end
--         local still_colliding = false
--         local place_gate = false
--         for i, entity in ipairs(colliding) do
--             if entity.prototype.collision_box and entity.prototype.collision_mask and entity.prototype.collision_mask["object-layer"] and not entity.to_be_deconstructed(state.force) and not (entity.name == "player") and not is_car(entity) then
--                 if entity.name == "straight-rail"
--                         and ((entity.direction == defines.direction.north or entity.direction == defines.direction.south and is_horizontal)
--                         or (entity.direction == defines.direction.east or entity.direction == defines.direction.west and not is_horizontal)) then
--                     place_gate = true
--                 else
--                     still_colliding = true
--                     -- if state.deconstruct_friendly then
--                     --     if not entity.order_deconstruction(state.force) then
--                     --         still_colliding = true
--                     --     end
--                     -- else
--                     --     if entity.force == state.force then
--                     --         still_colliding = true
--                     --     elseif entity.force.name == "neutral" then
--                     --         if not entity.order_deconstruction(state.force) then
--                     --             still_colliding = true
--                     --         end
--                     --     end
--                     -- end
--                 end
--             end
--         end
--         if not still_colliding then
--             if place_gate then
--                 if is_horizontal then
--                     place_ghost(state, {name = "gate", position = position, force = state.force, direction = defines.direction.east})
--                 else
--                     place_ghost(state, {name = "gate", position = position, force = state.force, direction = defines.direction.north})
--                 end
--             else
--                 place_ghost(state, data)
--             end
--         end
--     end
-- end

--[[  Placement functions  ]]
WB_stage = {}
PlannerCore.stage_function_table.WB_stage = WB_stage

function WB_stage.bounding_box(state)
    local count = state.count * state.conf.iterations_per_tick + 1
    if count <= #state.entities then
        for i = count, math.min(#state.entities, count + state.conf.iterations_per_tick) do
            local entity = state.entities[i]
            if entity.valid and entity.force == state.force then
                if entity.name == "straight-rail" then
                    local collision_box = entity.prototype.collision_box
                    if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
                        state.left = math.min(state.left, entity.position.x + collision_box.left_top.x)
                        state.right = math.max(state.right, entity.position.x + collision_box.right_bottom.x)
                        if entity.position.y <= state.top + 1.5 or entity.position.y >= state.bottom - 1.5 then
                            table.insert(state.NS_rails, table.clone(entity.position))
                        end
                    elseif entity.direction == defines.direction.east or entity.direction == defines.direction.west then
                        state.top = math.min(state.top, entity.position.y + collision_box.left_top.y)
                        state.bottom = math.max(state.bottom, entity.position.y + collision_box.right_bottom.y)
                        if entity.position.x <= state.left + 1.5 or entity.position.x >= state.right - 1.5 then
                            table.insert(state.EW_rails, table.clone(entity.position))
                        end
                    end
                elseif entity.name == "curved-rail" then
                    local collision_box = {left_top = {x = -3, y = -3}, right_bottom = {x = 3, y = 3}}
                    state.top = math.min(state.top, entity.position.y + collision_box.left_top.y)
                    state.left = math.min(state.left, entity.position.x + collision_box.left_top.x)
                    state.bottom = math.max(state.bottom, entity.position.y + collision_box.right_bottom.y)
                    state.right = math.max(state.right, entity.position.x + collision_box.right_bottom.x)
                    state.entity_count = state.entity_count + 1
                else
                    state.entity_count = state.entity_count + 1
                    --TODO check for ghost
                    if entity.prototype.collision_box then
                        local collision_box = util.rotate_box(entity.prototype.collision_box, entity.direction)
                        state.top = math.min(state.top, entity.position.y + collision_box.left_top.y)
                        state.left = math.min(state.left, entity.position.x + collision_box.left_top.x)
                        state.bottom = math.max(state.bottom, entity.position.y + collision_box.right_bottom.y)
                        state.right = math.max(state.right, entity.position.x + collision_box.right_bottom.x)
                    else
                        state.top = math.min(state.top, entity.position.y)
                        state.left = math.min(state.left, entity.position.x)
                        state.bottom = math.max(state.bottom, entity.position.y)
                        state.right = math.max(state.right, entity.position.x)
                    end
                end
            end
        end
        return false
    else
        if state.entity_count == 0 then
            state.player.print("No entities found to build a wall around.")
            state.stage = 1000
            return true
        end
        -- state.left = math.floor(state.left - state.conf.clearance_tiles - state.conf.section_height)
        -- state.top = math.floor(state.top - state.conf.clearance_tiles - state.conf.section_height)
        -- state.right = math.ceil(state.right + state.conf.clearance_tiles + state.conf.section_height)
        -- state.bottom = math.ceil(state.bottom + state.conf.clearance_tiles + state.conf.section_height)
        -- state.width = state.right - state.left
        -- state.height = state.bottom - state.top
        -- if state.conf.has_other_entities then
        --     game.print(state.conf.section_width)
        --     state.sections_per_width =
        --         math.floor((state.width - state.conf.section_height * 2) / state.conf.section_width)
        --     state.sections_per_height =
        --         math.floor((state.height - state.conf.section_height * 2) / state.conf.section_width)
        --     game.print(state.sections_per_width)
        --     state.entities_per_width = state.sections_per_width * #state.other_entities
        --     state.entities_per_height = state.sections_per_height * #state.other_entities
        --     game.print(state.entities_per_width)
        --     state.sections_x_gap = math.floor((state.width - (state.sections_per_width * state.conf.section_width)))
        --     state.sections_y_gap = math.floor((state.height - (state.sections_per_height * state.conf.section_width)))
        -- end
        return true
    end
end

function WB_stage.NS_rail_positions(state)
    if #state.NS_rails == 0 then
        return true
    end
    table.sort(
        state.NS_rails,
        function(a, b)
            return a.y < b.y
        end
    )
    local min_y = state.NS_rails[1].y
    local max_y = state.NS_rails[#state.NS_rails].y

    if min_y <= state.top + 1.5 then
        state.top_rails =
            table.map(
            table.filter(
                state.NS_rails,
                function(a)
                    return a.y == min_y
                end
            ),
            function(a)
                return a.x - 1
            end
        )
    end

    if max_y >= state.bottom - 1.5 then
        state.bottom_rails =
            table.map(
            table.filter(
                state.NS_rails,
                function(a)
                    return a.y == max_y
                end
            ),
            function(a)
                return a.x - 1
            end
        )
    end
    state.NS_rails = nil
    return true
end

function WB_stage.EW_rail_positions(state)
    if #state.EW_rails == 0 then
        return true
    end
    table.sort(
        state.EW_rails,
        function(a, b)
            return a.x < b.x
        end
    )
    local min_x = state.EW_rails[1].x
    local max_x = state.EW_rails[#state.EW_rails].x

    if min_x <= state.left + 1.5 then
        state.left_rails =
            table.map(
            table.filter(
                state.EW_rails,
                function(a)
                    return a.x == min_x
                end
            ),
            function(a)
                return a.y - 1
            end
        )
    end

    if max_x >= state.right - 1.5 then
        state.right_rails =
            table.map(
            table.filter(
                state.EW_rails,
                function(a)
                    return a.x == max_x
                end
            ),
            function(a)
                return a.y - 1
            end
        )
    end
    state.EW_rails = nil
    return true
end

function WB_stage.plan(state)
    state.left = math.floor(state.left - state.conf.clearance_tiles)
    state.top = math.floor(state.top - state.conf.clearance_tiles)
    state.right = math.ceil(state.right + state.conf.clearance_tiles)
    state.bottom = math.ceil(state.bottom + state.conf.clearance_tiles)
    state.width = state.right - state.left
    state.height = state.bottom - state.top

    -- game.print(
    --     serpent.block(
    --         {
    --             state.left,
    --             state.top,
    --             state.right,
    --             state.bottom,
    --             state.width,
    --             state.height,
    --             state.top_rails,
    --             state.bottom_rails,
    --             state.right_rails,
    --             state.left_rails
    --         }
    --     )
    -- )

    -- Move corners around to fit sections exactly.
    -- Just round to section length, TODO improve behaviour with rails

    local top_wall_sections_length = state.right - state.left
    local num_sections = math.ceil(top_wall_sections_length / state.conf.section_width)
    local difference = num_sections * state.conf.section_width - top_wall_sections_length
    local shift_both = math.floor(difference / 2)
    state.left = state.left - shift_both
    state.right = state.right + shift_both
    if difference % 2 ~= 0 then
        state.left = state.left - 1
    end

    local left_wall_sections_length = state.bottom - state.top
    num_sections = math.ceil(left_wall_sections_length / state.conf.section_width)
    difference = num_sections * state.conf.section_width - left_wall_sections_length
    shift_both = math.floor(difference / 2)
    state.top = state.top - shift_both
    state.bottom = state.bottom + shift_both
    if difference % 2 ~= 0 then
        state.top = state.top - 1
    end

    -- Assume symmetry of rail wall piece
    for k, side in pairs(
        {
            {left = state.left, right = state.right, rails = state.top_rails, sections = state.top_section_list},
            {left = state.top, right = state.bottom, rails = state.left_rails, sections = state.left_section_list},
            {left = state.left, right = state.right, rails = state.bottom_rails, sections = state.bottom_section_list},
            {left = state.top, right = state.bottom, rails = state.right_rails, sections = state.right_section_list}
        }
    ) do
        table.sort(side.rails)
        side.rails[#side.rails + 1] = side.right
        local current_x = side.left
        for k, next_x in ipairs(side.rails) do
            local length = next_x - current_x
            local num_sections = math.floor(length / state.conf.section_width)
            local difference = length - num_sections * state.conf.section_width
            -- game.print(
            --     "Current_x: " ..
            --         current_x ..
            --             ", next_x: " ..
            --                 next_x ..
            --                     ", length: " ..
            --                         length .. ", num_sections: " .. num_sections .. ", difference: " .. difference
            -- )
            for i = 1, num_sections do
                table.insert(side.sections, "normal")
                current_x = current_x + state.conf.section_width
            end
            for i = 1, difference do
                table.insert(side.sections, "filler")
                current_x = current_x + 1
            end
            table.insert(side.sections, "rail")
        end
        -- Get rid of the last rail, it will be a corner instead
        side.sections[#side.sections] = nil
    end

    state.stage = 1000
    return true
end

function helper_place_entity(state, data)
    if state.use_pole_builder and game.entity_prototypes[data.name].type == "electric-pole" then
        table.insert(state.pole_positions, data.position)
    else
        return OB_helper.abs_place_entity(state, data)
    end
end

function WB_stage.place_entity(state)
    
end



function place_walls(state)
    local width = state.width + state.wall_thickness
    local height = state.height + state.wall_thickness
    if state.count <= width then
        for i = 0, state.wall_thickness do
            place_wall(state, {x = state.left + state.count, y = state.top - i}, true)
        end
    elseif state.count <= width + height then
        for i = 0, state.wall_thickness do
            place_wall(state, {x = state.right + i, y = state.top + state.count - width}, false)
        end
    elseif state.count <= width + height + width then
        for i = 0, state.wall_thickness do
            place_wall(state, {x = state.right - state.count + width + height, y = state.bottom + i}, true)
        end
    elseif state.count <= width + height + width + height then
        for i = 0, state.wall_thickness do
            place_wall(state, {x = state.left - i, y = state.bottom - state.count + width + height + width}, false)
        end
    else
        return false
    end
    return true
end

function place_other_entities(state)
    if not state.conf.has_other_entities then
        return false
    end
    if state.count <= state.entities_per_width then
        game.print("Placing")
        local entity = state.other_entities[((state.count - 1) % #state.other_entities) + 1]
        local section_number = math.floor((state.count - 1) / #state.other_entities)
        local x_offset = section_number * state.conf.section_width
        if section_number > (state.sections_per_width / 2) then
            x_offset = x_offset + state.sections_x_gap
        end
        place_other_entity(
            state,
            {
                name = entity.name,
                position = {x = entity.position.x + x_offset + state.left, y = entity.position.y + 1 + state.top},
                direction = entity.direction
            }
        )
    else
        return false
    end
    return true
end

function tick(state)
    if state.count > 5000 then
        game.print("Aborting in stage " .. state.stage .. ", count too high.")
        state.stage = 1000
        return
    end
    if state.stages[state.stage](state) then
        state.count = state.count + 1
    else
        state.stage = state.stage + 1
        state.count = 1
    end
end

--[[  Main funtion  ]]
function on_selected_area(event, deconstruct_friendly)
    local conf = get_config()

    local player = game.players[event.player_index]
    local force = player.force
    local surface = player.surface

    local state = {
        surface = surface,
        player = player,
        force = force,
        top = math.huge,
        bottom = -math.huge,
        left = math.huge,
        right = -math.huge,
        entities = event.entities,
        stages = {bounding_box, deconstruct, place_walls, place_other_entities},
        stage = 1,
        count = 1,
        conf = conf,
        entity_count = 0,
        deconstruct_friendly = deconstruct_friendly,
        wall_thickness = conf.wall_thickness - 1,
        other_entities = table.clone(conf.other_entities)
    }

    if conf.run_over_multiple_ticks then
        register(state)
    else
        while state.stage <= #stages do
            tick(state)
        end
    end
end
