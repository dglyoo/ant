local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local hn_test_sys = ecs.system "hitch_node_test_system"
local hitch_test_group_id<const> = 1000
local skeleton_test_group_id<const> = 1001

local function create_simple_test_group()
    local defgroup = ecs.group(0)
    defgroup:create_hitch{
        t = {0, 3, 0},
        children = hitch_test_group_id,
    }
    defgroup:create_hitch{
        t = {1, 2, 0},
        children = hitch_test_group_id,
    }
    defgroup:create_hitch{
        t = {0, 0, 3},
        children = hitch_test_group_id,
    }

    local static_group = ecs.group(hitch_test_group_id)
    --standalone sub tree
    static_group:enable "scene_update"
    local p1 = static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/lambert1.001.material",
            filter_state = "main_view",
            scene = {},
            on_ready = function (e)
                w:sync("scene:in id:in", e)
                iom.set_position(e, math3d.vector(0, 2, 0))
                iom.set_scale(e, 3)
                w:sync("scene:out", e)
            end,
            standalone_scene_object=true,
            name = "virtual_node_p1",
        },
    }

    static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cone.glb|materials/lambert1.material",
            filter_state = "main_view",
            scene = {
                parent = p1,
            },
            on_ready = function (e)
                w:sync("scene:in id:in", e)
                iom.set_position(e, math3d.vector(1, 2, 3))
                w:sync("scene:out", e)
            end,
            standalone_scene_object = true,
            name = "virtual_node",
        },
    }
end

local function create_skeleton_test_group()
    --dynamic
    ecs.create_hitch{
        s = 0.1,
        t = {0.0, 0.0, -5.0},
        children = skeleton_test_group_id,
    }
    local dynamic_group = ecs.group(skeleton_test_group_id)
    dynamic_group:enable "scene_update"
    local p = dynamic_group:create_instance "/pkg/ant.test.features/assets/glb/headquater.glb|mesh.prefab"
    p.on_init = function ()
        world:entity(p.root).standalone_scene_object = true
        for _, eid in ipairs(p.tag["*"]) do
            world:entity(eid).standalone_scene_object = true
        end
    end
    world:create_object(p)
end

function hn_test_sys:init()
    create_simple_test_group()
    create_skeleton_test_group()
end