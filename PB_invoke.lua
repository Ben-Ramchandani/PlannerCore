PB_invoke = {}

function PB_invoke.set_up_config(conf)
    local prototype = game.entity_prototypes[conf.pole]
    conf.wire_distance = prototype.max_wire_distance
    conf.supply_distance = prototype.supply_area_distance
    conf.prototype = prototype
    local size = math.ceil(prototype.collision_box.right_bottom.x - prototype.collision_box.left_top.x)
    if
        not (size == math.ceil(prototype.collision_box.right_bottom.y - prototype.collision_box.left_top.y) and
            prototype.collision_box.right_bottom.x == -prototype.collision_box.left_top.x and
            prototype.collision_box.right_bottom.y == -prototype.collision_box.left_top.y)
     then
        gane.print("PoleBuilder Error: Electric pole is not square.")
    end
    if size % 2 == 1 then
        conf.offset = 0.5
        conf.collision_left = math.floor(prototype.collision_box.left_top.x + 0.5)
        conf.collision_top = math.floor(prototype.collision_box.left_top.y + 0.5)
        conf.collision_right = math.ceil(prototype.collision_box.right_bottom.x - 0.5)
        conf.collision_bottom = math.ceil(prototype.collision_box.right_bottom.y - 0.5)
    else
        conf.offset = 0
        conf.collision_left = math.floor(prototype.collision_box.left_top.x)
        conf.collision_top = math.floor(prototype.collision_box.left_top.y)
        conf.collision_right = math.ceil(prototype.collision_box.right_bottom.x)
        conf.collision_bottom = math.ceil(prototype.collision_box.right_bottom.y)
    end

    return conf
end

function PB_invoke.run_pole_builder_opt(data)
    local player = data.player
    local force = player.force
    local surface = player.surface
    local conf = data.conf

    local area = data.area
    if not area then
        area = util.find_bounding_box_positions(data.possible_pole_positions)
    end
    local top = math.floor(area.left_top.y) - 1
    local left = math.floor(area.left_top.x) - 1
    local bottom = math.floor(area.right_bottom.y)
    local right = math.floor(area.right_bottom.x)

    stages = {
        "set_up_area",
        "initialise_counts",
        "place_initial_pole",
        "place_best_pole"
    }
    local initial_pole_position
    if data.initial_pole_index then
        initial_pole_position = data.possible_pole_positions[data.initial_pole_index]
    end

    local state = {
        surface = surface,
        player = player,
        force = force,
        top = top,
        bottom = bottom,
        left = left,
        right = right,
        width = right - left,
        height = bottom - top,
        area = {},
        entities = data.entities,
        entity_count = #data.entities,
        pole_positions = {},
        initial_poles = {},
        placement_stage = "searching",
        stage = 0,
        count = 0,
        conf = conf,
        surpress_info = data.surpress_info,
        surpress_warnings = data.surpress_warnings,
        stages = stages,
        stage_namespace = "PB_opt_stage",
        entities_per_tick = 10,
        pole_positions_per_tick = 50,
        possible_pole_positions = data.possible_pole_positions,
        initial_pole_position = initial_pole_position,
        reachable_list = {},
        reachable_zero_list = {}
    }

    if conf.run_over_multiple_ticks then
        PB_helper.print_info(state, {"pole-builder.starting"})
        remote.call("PlannerCore", "register", state)
    else
        remote.call("PlannerCore", "run_immediately", state)
    end
end

function PB_invoke.run_pole_builder(data)
    local player = data.player
    local force = player.force
    local surface = player.surface
    local conf = data.conf

    local area = data.area
    if not area then
        area = util.find_collision_bounding_box(data.entities)
    end
    data.padding = data.padding or 1
    local top = math.floor(area.left_top.y - data.padding) - 1
    local left = math.floor(area.left_top.x - data.padding) - 1
    local bottom = math.ceil(area.right_bottom.y + data.padding) - 1
    local right = math.ceil(area.right_bottom.x + data.padding) - 1

    local entities = data.entities
    if not entities then
        entities = surface.find_entities_filtered({area = area, force = force})
    end
    local stages = {
        "set_up_area",
        "filter_entities",
        "initial_poles",
        "initialise_counts",
        "collision_check",
        "place_initial_pole",
        "place_best_pole"
    }
    local namespace = "PB_stages"
    local entity_count, reachable_list, reachable_zero_list, initial_pole_position

    if data.possible_pole_positions then
        stages = {
            "set_up_area",
            "initialise_counts",
            "place_initial_pole",
            "place_best_pole"
        }
        namespace = "PB_opt_stage"
        entity_count = #entities
        reachable_list = {}
        reachable_zero_list = {}
        initial_pole_position = data.possible_pole_positions[data.initial_pole_index]
    end

    local state = {
        surface = surface,
        player = player,
        force = force,
        top = top,
        bottom = bottom,
        left = left,
        right = right,
        width = right - left,
        height = bottom - top,
        area = {},
        entities = entities,
        entity_count = entity_count,
        pole_positions = {},
        initial_poles = {},
        placement_stage = "searching",
        stage = 0,
        count = 0,
        conf = conf,
        surpress_info = data.surpress_info,
        surpress_warnings = data.surpress_warnings,
        stages = stages,
        stage_namespace = namespace,
        entities_per_tick = 10,
        pole_positions_per_tick = 50,
        possible_pole_positions = data.possible_pole_positions,
        initial_pole_position = initial_pole_position,
        reachable_list = reachable_list,
        reachable_zero_list = reachable_zero_list
    }

    if conf.run_over_multiple_ticks then
        PB_helper.print_info(state, {"pole-builder.starting"})
        remote.call("PlannerCore", "register", state)
    else
        remote.call("PlannerCore", "run_immediately", state)
    end
end

function PB_invoke.remote_invoke(data)
    if not data or type(data) ~= "table" or not data.player or (not data.area and not data.entities) then
        game.print("PoleBuilder Error: bad remote invocation.")
        return nil
    end
    if
        not data.pole or not game.entity_prototypes[data.pole] or
            game.entity_prototypes[data.pole].type ~= "electric-pole"
     then
        data.player.print("PoleBuilder Error: bad remote invocation - pole does not exist.")
        return nil
    end
    if not data.conf then
        data.conf = {run_over_multiple_ticks = true}
    end
    if data.possible_pole_positions and (not data.entities) then
        game.print("PoleBuilder Error: bad remote invocation.")
        return nil
    end
    data.conf.pole = data.pole
    data.conf = PB_invoke.set_up_config(data.conf)
    if data.possible_pole_positions then
        PB_invoke.run_pole_builder_opt(data)
    else
        PB_invoke.run_pole_builder(data)
    end
    return true
end

PlannerCore.remote_invoke.PoleBuilder = PB_invoke.remote_invoke
PlannerCore.remote_invoke.run_pole_builder = PB_invoke.run_pole_builder
