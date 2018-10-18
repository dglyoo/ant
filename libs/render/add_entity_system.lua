local ecs = ...
local world = ecs.world
local fs_util = require "filesystem.util"
local component_util = require "render.components.util"
local lu = require "render.light.util"
local mu = require "math.util"
local bgfx = require "bgfx"


local update_direction_light_sys = ecs.system "direction_light_system"
update_direction_light_sys.singleton "math_stack"

function update_direction_light_sys:update()
    if true then
        return
    end

	local ms = self.math_stack

	local function get_delta_time_op()
		local baselib = require "bgfx.baselib"
		local lasttime = baselib.HP_time("s")
		return function()
			local curtime = baselib.HP_time("s")
			local delta = curtime - lasttime
			lasttime = curtime
			return delta
		end
	end

	local angleXpresecond = 20
	local angleYpresecond = 15

	local deltatime_op = get_delta_time_op()
	for _, eid in world:each("directional_light") do		
		local e = world[eid]

		local delta = deltatime_op()

		local rot = ms(e.rotation.v, "T")
		rot[1] = rot[1] + delta * angleXpresecond
		rot[2] = rot[2] + delta * angleYpresecond

		ms(e.rotation.v, rot, "=")
	end
end

local add_entity_sys = ecs.system "add_entities_system"

add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "iup_message"


function add_entity_sys:init()
	local ms = self.math_stack

	do
		local leid = lu.create_directional_light_entity(world)
		world:add_component(leid, "mesh", "material", "can_render", "scale", "name")
		local lentity = world[leid]

		local lightcomp = lentity.light.v
		lightcomp.color = {1,1,1,1}
		lightcomp.intensity = 2.0

		--ms(lentity.rotation.v, {50, -30, 0}, "=")
		--ms(lentity.rotation.v, {123.4, 234.22,28.2}, "=")
		--ms(lentity.rotation.v, {123.4, -34.22,-28.2}, "=")
		--ms(lentity.position.v, {5, 5, 2}, "=")
		ms(lentity.rotation.v, {45, -135, 45}, "=")
		ms(lentity.position.v, {100, 100, 100}, "=")

		ms(lentity.scale.v, {1, 1, 1}, "=")

		lentity.name.n = "directional_light"

		-- add tested for ambient 
		local am_eid = lu.create_ambient_light_entity(world)
		local am_entity = world[ am_eid]
		local ambient_comp = am_entity.ambient_light.data
		ambient_comp.mode = "gradient"
		ambient_comp.skycolor = {1,1,1,1}
		ambient_comp.midcolor  = {0.9,0.9,1,1}
		ambient_comp.groundcolor  = {0.50,0.74,0.68,1}
		--ambient_comp.skycolor = {0.8,0.8,0.8,1} --{0.28,0,1,1}
		--ambient_comp.midcolor = {0,1,0,1}
		--ambient_comp.groundcolor = {0,0,1,1}
		--ambient_comp.factor = 0.25
		lentity.name.n = "ambient_light"
		print("-------ambient entity  "..am_entity.name.n..'  '..am_eid)

		component_util.load_mesh(lentity, "sphere.mesh")
		local sphere_fn = "mem://light_bulb.material"
		fs_util.write_to_file(sphere_fn, [[
			shader = {
				vs = "simple/light_bulb/vs_bulb.sc",
				fs = "simple/light_bulb/fs_bulb.sc",
			}
			state = "default.state"
			properties = {
				u_color = {type="color", name = "color", default={1, 1, 1, 1}}
			}
		]])
		component_util.load_material(lentity, {sphere_fn})

		lentity.can_render.visible = false
	end

    do
        local bunny_eid = world:new_entity("position", "rotation", "scale", 
			"can_render", "mesh", "material",
			"name", "serialize",
            "can_select")
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file        
        ms(bunny.scale.v, {5, 5, 5, 0}, "=")
        ms(bunny.position.v, {0, 0, 3, 1}, "=")
		ms(bunny.rotation.v, {0, -60, 0, 0}, "=")

		bunny.mesh.path = "bunny.mesh"
		component_util.load_mesh(bunny)

		bunny.material.content[1] = {path = "bunny.material", properties = {}}
		component_util.load_material(bunny)
	end

    
	-- do	-- pochuan
	-- 	local pochuan_eid = world:new_entity("position", "rotation", "scale",
	-- 	"can_render", "mesh", "material",
	-- 	"name", "serialize",
	-- 	"can_select")
	-- 	local pochuan = world[pochuan_eid]
	-- 	pochuan.name.n = "PoChuan"

	-- 	--mu.identify_transform(ms, pochuan)
	-- 	ms(pochuan.scale.v, {0.1, 0.1, 0.1}, "=")
	-- 	ms(pochuan.rotation.v, {-90, 0, 0,}, "=")

	-- 	component_util.load_mesh(pochuan, "pochuan.mesh")--, {calctangent=false})
	-- 	component_util.load_material(pochuan, {"pochuan.material"})
	-- 	--component_util.load_material(pochuan, {"bunny.material"})
	-- end

    -- 测试场景时，打开 PVPScene 加载BnH模型
    local PVPScene = require "modelloader.PVPScene"
	PVPScene.init(world, component_util, ms)
	
	-- do
	-- 	local stone_eid = world:new_entity("position", "rotation", "scale",
	-- 	"can_render", "mesh", "material",
	-- 	"name", "serialize", "can_select")

	-- 	local stone = world[stone_eid]
	-- 	stone.name.n = "texture_stone"

	-- 	mu.identify_transform(ms, stone)

	-- 	local function create_plane_mesh()
	-- 		local vdecl = bgfx.vertex_decl {
	-- 			{ "POSITION", 3, "FLOAT" },
	-- 			{ "NORMAL", 3, "FLOAT"},
	-- 			{ "TANGENT", 4, "FLOAT"},
	-- 			{ "TEXCOORD0", 2, "FLOAT"},
	-- 		}

	-- 		local lensize = 5

	-- 		return {
	-- 			handle = {
	-- 				group = {
	-- 					{
	-- 						vdecl = vdecl,
	-- 						vb = bgfx.create_vertex_buffer(
	-- 							{"ffffffffffff",
	-- 						lensize, -lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						1.0, 0.0,

	-- 						lensize, lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						1.0, 1.0,

	-- 						-lensize, -lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						0.0, 0.0,

	-- 						-lensize, lensize, 0.0,
	-- 						0.0, 0.0, -1.0,
	-- 						0.0, 1.0, 0.0, 1.0,
	-- 						0.0, 1.0,
	-- 						}, vdecl)
	-- 					},
	-- 				}
	-- 			}
	-- 		}
	-- 	end

	-- 	stone.mesh.path = ""	-- runtime mesh info
	-- 	stone.mesh.assetinfo = create_plane_mesh()


	-- 	stone.material.content[1] = {path = "stone.material", properties={}}
	-- 	component_util.load_material(stone)
	-- end

    -- local function create_entity(name, meshfile, materialfile)
    --     local eid = world:new_entity("rotation", "position", "scale", 
	-- 	"mesh", "material",
	-- 	"name", "serialize",
	-- 	"can_select", "can_render")

    --     local entity = world[eid]
    --     entity.name.n = name

    --     ms(entity.scale.v, {1, 1, 1}, "=")
    --     ms(entity.position.v, {0, 0, 0, 1}, "=") 
    --     ms(entity.rotation.v, {0, 0, 0}, "=")

	-- 	entity.mesh.path = meshfile
	-- 	component_util.load_mesh(entity)
	-- 	entity.material.content[1] = {path=materialfile, properties={}}
	-- 	component_util.load_material(entity)
    --     return eid
    -- end

    -- do
    --     local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
    --         "scale", "rotation", "position", 
    --         "name", "serialize")
    --     local hierarchy_e = world[hierarchy_eid]

    --     hierarchy_e.name.n = "hierarchy_test"

    --     ms(hierarchy_e.scale.v, {1, 1, 1}, "=")
    --     ms(hierarchy_e.rotation.v, {0, 60, 0}, "=")
    --     ms(hierarchy_e.position.v, {10, 0, 0, 1}, "=")

    --     local hierarchy = hierarchy_e.editable_hierarchy.root

    --     hierarchy[1] = {
    --         name = "h1_cube",
    --         transform = {
    --             t = {3, 4, 5},
    --             s = {0.01, 0.01, 0.01},
    --         }
    --     }

    --     hierarchy[2] = {
    --         name = "h1_sphere",
    --         transform = {
    --             t = {1, 2, 3},
    --             s = {0.01, 0.01, 0.01},
    --         }
    --     }

    --     hierarchy[1][1] = {
    --         name = "h1_h1_cube",
    --         transform = {
    --             t = {3, 3, 3},
    --             s = {0.01, 0.01, 0.01},
    --         }
	-- 	}

	-- 	local material_path = "mem://hierarchy.material"
	-- 	fs_util.write_to_file(material_path, [[
	-- 		shader = {
	-- 			vs = "vs_mesh",
	-- 			fs = "fs_mesh",
	-- 		}
	-- 		state = "default.state"
	-- 		properties = {
	-- 			u_time = {name="u_time", type="v4", default={1, 0, 0, 1}}
	-- 		}
	-- 	]])

    --     local stone_eid = create_entity("h1_cube", "cube.mesh", material_path)
    --     local stone_eid_1 = create_entity("h1_h1_cube", "cube.mesh", material_path)
    --     do
    --         local e = world[stone_eid_1] 
    --         ms(e.scale.v, {0.5, 0.5, 0.5}, "=")
    --     end

    --     local sphere_eid = create_entity("h1_sphere", "sphere.mesh", material_path)
    --     local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)

    --     name_mapper.h1_cube     = stone_eid
    --     name_mapper.h1_h1_cube  = stone_eid_1
	-- 	name_mapper.h1_sphere   = sphere_eid

	-- 	world:change_component(hierarchy_eid, "rebuild_hierarchy")
	-- 	world:notify()
    -- end
end