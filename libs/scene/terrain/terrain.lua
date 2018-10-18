-- dofile "libs/init.lua"
-- terrain System 
local ecs = ...
local world = ecs.world

package.path = package.path..';../clibs/terrain/?.lua;./clibs/terrain/?.lua;./test/?.lua;' 
package.cpath = package.cpath..';../clibs/terrain/?.dll;./clibs/terrain/?.dll;'

-- local nk = require "bgfx.nuklear"
-- local nkmsg = require "inputmgr.nuklear"
-- local loadfile = require "tested.loadfile"
-- local ch_charset = require "tested.charset_chinese_range"

local bgfx = require "bgfx"
local math_util = require "math.util"
local shaderMgr = require "render.resources.shader_mgr"
local camera_util = require "render.camera.util"
local render_cu = require "render.components.util"

local terrainClass = require "terrainClass"

local UI_VIEW      = 255
local VIEWID_TERRAIN = 100 


-- 做成 component 
--local terrain = terrainClass.new()       	-- new terrain instance pvp
--local terrain_chibi = terrainClass.new()    -- chibi 

local math3d_stack = nil 					-- math3d.new()

local init_ambient = nil 					-- 


local ctx = { stats = {} }

--- ambient utils ---
local function gen_ambient_light_uniforms( terrain )
	for _,l_eid in world:each("ambient_light") do
		local am_ent = world[l_eid]
		local data = am_ent.ambient_light.data 

		local type = 1
		if data.mode == "factor" then 
			type = 0
		elseif data.mode == "gradient" then 
			type = 2
		end 
		terrain:set_uniform("ambient_mode",  {type, data.factor, 0, 0}  )
		terrain:set_uniform("ambient_skycolor", data.skycolor )  
		terrain:set_uniform("ambient_midcolor", data.midcolor  )
		terrain:set_uniform("ambient_groundcolor", data.groundcolor )
	end 
end 

local function gen_lighting_uniforms( terrain )
	for _,l_eid in world:each("directional_light") do 
		local dlight = world[l_eid]
		local l = dlight.light.v 
		terrain:set_uniform("u_lightDirection", math3d_stack(dlight.rotation.v, "dim") )
		terrain:set_uniform("u_lightIntensity", { l.intensity,0,0,0} )  
		terrain:set_uniform("u_lightColor",l.color  )
	end 
end 

local function get_shadow_properties()
	local properties = {} 
	for _,l_eid in world:each("shadow_maker") do 
		local  sm_ent   = world[l_eid]
		local  uniforms = sm_ent.shadow_rt.uniforms 

		properties["u_params1"] = { name = "u_params1",type="v4",value = { uniforms.shadowMapBias,
																		   uniforms.shadowMapOffset,
																		   0.5,1} } 
		properties["u_params2"] = { name = "u_params2",type="v4",
									value = { uniforms.depthValuePow,
											  uniforms.showSmCoverage,
											  uniforms.shadowMapTexelSize, 0 } }
		properties["u_smSamplingParams"] = { name = "u_smSamplingParams",
								   type  ="v4",
								   value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } }

		-- -- shadow matrices 
		properties["u_shadowMapMtx0"] = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 }
		properties["u_shadowMapMtx1"] = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 }
		properties["u_shadowMapMtx2"] = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 }
		properties["u_shadowMapMtx3"] = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 }
		--if sm_ent.shadow_rt.ready == true then 
			properties["s_shadowMap0"] = {  name = "s_shadowMap0", type = "texture", stage = 4, value = uniforms.s_shadowMap0 }
			properties["s_shadowMap1"] = {  name = "s_shadowMap1", type = "texture", stage = 5, value = uniforms.s_shadowMap1 }
			properties["s_shadowMap2"] = {  name = "s_shadowMap2", type = "texture", stage = 6, value = uniforms.s_shadowMap2 }
			properties["s_shadowMap3"] = {  name = "s_shadowMap3", type = "texture", stage = 7, value = uniforms.s_shadowMap3 }
		--end 
	end 
	return properties 
end 

local function update_property(name, property)
	local uniform = shaderMgr.get_uniform(name)        
	if uniform == nil  then
		log(string.format("property name : %s, is needed, but shadermgr not found!", name))
		return 
	end
	assert(uniform.name == name)
	--assert(property_type_description[property.type].type == uniform.type)
	
	if property.type == "texture" then 
		local stage = assert(property.stage)
		bgfx.set_texture(stage, assert(uniform.handle), assert(property.value))
		--print("texture ",stage,uniform.name,uniform.handle, property.value  )        		
	else
		local val = assert(property.value)

		local function need_unpack(val)
			if type(val) == "table" then
				local elemtype = type(val[1])
				if elemtype == "table" or elemtype == "userdata" or elemtype == "luserdata" then
					return true
				end
			end
			return false
		end
		
		if need_unpack(val) then
			-- print("uniform -- unpack",name,val )
			--bgfx.set_uniform(assert(uniform.handle), table.unpack(val))
		else
			-- print("uniform -- nounpack",name,val )
			--bgfx.set_uniform(assert(uniform.handle), val)
		end
	end
end

local function update_properties(shader, properties)
    if properties then
        -- check_uniform_is_match_with_shader(shader, properties)
        for n, p in pairs(properties) do
            update_property(n, p)
        end
    end
end

local function gen_shadow_uniforms( terrain )
	local properties = get_shadow_properties()
	update_properties(nil,properties)
end 

local function update( terrain )

	local ms = math3d_stack
	if init_ambient == nil  then 
		init_ambient = "true"
		--gen_lighting_uniforms( terrain ) 
		--gen_ambient_light_uniforms( terrain )
	end 

	-- 找到获得 view，proj 的直接方法，不需要这里二次转换
	local camera = world:first_entity("main_camera")
    local camera_view, camera_proj = math_util.view_proj_matrix( ms, camera )

	bgfx.set_view_rect( VIEWID_TERRAIN, 0, 0, ctx.width,ctx.height)
	bgfx.set_view_transform( VIEWID_TERRAIN,ms(camera_view,"m"),ms(camera_proj,"m") )	
	bgfx.touch( VIEWID_TERRAIN )
	
	-- terrain chibi 
	-- terrain_chibi:render( VIEW_TERRAIN, ctx.width,ctx.height)

	-- terrain pvp 	
	-- for further anything 
	-- terrain:update( view ,dir)                        				  
	terrain:render( VIEWID_TERRAIN, ctx.width,ctx.height,prim_type, gen_shadow_uniforms)   -- "POINT","LINES"  -- for debug 
end


local function init(fbw, fbh, entity )

	ctx.width = fbw
	ctx.height = fbh

	local program_create_mode = 1

	local terrain_comp = entity.terrain 
	local pos_comp = entity.position 
	local rot_comp = entity.rotation 
	local scl_comp = entity.scale 

	local terrain = terrainClass.new()       	-- new terrain instance pvp
	terrain_comp.terrain_obj = terrain 

	-- load terrain level 
    -- gemotry create mode 
	terrain:load( terrain_comp.level_name ,   --"assets/build/terrain/pvp1.lvl",
					{  -- 自定义顶点格式
						{ "POSITION", 3, "FLOAT" },
						{ "TEXCOORD0", 2, "FLOAT" },
						{ "TEXCOORD1", 2, "FLOAT" },
						{ "NORMAL", 3, "FLOAT" },
					}
				)

	-- material create mode 
	if program_create_mode == 1 then 
		-- load from mtl setting 
		terrain:load_material( terrain_comp.level_material) --"assets/build/assetfiles/terrain_shadow.mtl")
	else 
		-- or create manually
		terrain:load_program("terrain_shadow/vs_terrain_shadow.sc","terrain_shadow/fs_terrain_shadow.sc")
		terrain:create_uniform("u_mask","s_maskTexture","i1",1)
		terrain:create_uniform("u_base","s_baseTexture","i1",0)
		terrain:create_uniform("u_lightDirection","s_lightDirection","v4")
		terrain:create_uniform("u_lightIntensity","s_lightIntensity","v4")
		terrain:create_uniform("u_lightColor","s_lightColor","v4")
		terrain:create_uniform("u_showMode","s_showMode","i1")   -- 0 default,1 = normal

		terrain:set_uniform("u_lightDirection",{1,1,1,1} )
		terrain:set_uniform("u_lightIntensity",{2.316,0,0,0} )  
		terrain:set_uniform("u_lightColor",{1,1,1,0.625} )
		terrain:set_uniform("u_showMode",1)  
	end 

	-- combine into pvp scene 
	local t = math3d_stack( pos_comp.v,"T")
	local s = math3d_stack( scl_comp.v,"T")
	local r = math3d_stack( rot_comp.v,"T")
	--print("t ",t[1],t[2],t[3],t[4])
	terrain:set_transform { t = t, r = r, s = s }
	-- terrain:set_transform { t= {147,0.25,225,1},r= {0,0,0},s={1,1,1,1}}
	-- tested with c impl 
	-- terrain:set_transform { t= {0,0,0,1},r= {0,0,0},s={1,1,1,1}}

	-- chibi scene 
	-- terrain_chibi:load("assets/build/terrain/chibi16.lvl")  	  	    -- 默认顶点格式
	-- terrain_chibi:load_material("assets/build/terrain/terrain.mtl")  -- 文件加载材质
	-- terrain_chibi:create_uniform("u_showMode","s_showMode","i1")     -- 可以手工增加uniform，方便测试 
	-- terrain_chibi:set_uniform("u_showMode",0)   				     	-- 0 = default, 1 = display normal line
	-- terrain_chibi:set_transform { t= {0,150,0,1},r= {0,0,0},s={1,1,1,1}}
end

-- terrain component
--  传递地形关卡文件，材质文件，以及 iv,vb,mb
ecs.component "terrain" {
	path = {
		type = "userdata",
		default = "",
		save = function (v, arg)
			assert(type(v) == "string")
			-- local world = arg.world
			-- local e = assert(world[arg.eid])
			-- local comp = assert(e[arg.comp])
			-- assert(comp.assetinfo)
			return v
		end,

		load = function (v, arg)
			assert(type(v) == "string")
			local world = arg.world
			local e = assert(world[arg.eid])
			local comp = assert(e[arg.comp])

			if v ~= "" then
				assert(comp.assetinfo == nil)
				comp.assetinfo = asset.load(v)
			end
			return v
		end
	},

	level_name = " ",
	level_material = " ",
	terrain_obj = false, 
}


-- terrain entity

local function create_terrain_entity( world, name  )
	local eid = world:new_entity(
		"terrain",  
		"material", 
		"position","rotation","scale",
		"can_render",
		"name")
	local entity = assert( world[eid] )
	entity.name.n = name 
	return entity 
end 


local terrain_sys = ecs.system "terrain_system"
terrain_sys.singleton "math_stack"
terrain_sys.singleton "message_component"
terrain_sys.depend    "lighting_primitive_filter_system"
terrain_sys.depend 	  "entity_rendering"
terrain_sys.dependby  "end_frame"

-- ecs 需要增加 componet 从文件中创建加载的流程
-- update 访问 component ,mesh,terrain 可同流程不同结构
function terrain_sys:init()

	math3d_stack = self.math_stack  

	local fb = world.args.fb_size

	local tr_ent = create_terrain_entity( world,"pvp")
	tr_ent.terrain.level_name = "assets/build/terrain/pvp1.lvl"
	tr_ent.terrain.level_material = "assets/build/assetfiles/terrain_shadow.mtl"
	-- t= {147,0.25,225,1},r= {0,0,0},s={1,1,1,1}
	math3d_stack(tr_ent.position.v, {147,0.25,225,1}, "=")
	math3d_stack(tr_ent.rotation.v, {0, 0, 0,}, "=")
	math3d_stack(tr_ent.scale.v, {1, 1, 1}, "=")
	init(fb.w, fb.h, tr_ent )

	local chibi_ent = create_terrain_entity( world,"chibi")
	chibi_ent.terrain.level_name = "assets/build/terrain/chibi16.lvl"
	chibi_ent.terrain.level_material = "assets/build/assetfiles/terrain_shadow.mtl"
	math3d_stack(chibi_ent.scale.v, {1, 1, 1}, "=")
	math3d_stack(chibi_ent.rotation.v, {0, 0, 0,}, "=")
	math3d_stack(chibi_ent.position.v, {60, 10, 60}, "=")
	init(fb.w, fb.h, chibi_ent )
end

function terrain_sys:update()
	for _,eid in world:each("terrain") do              
        --if render_cu.is_entity_visible(world[eid]) then       -- vis culling 
		   local ter_ent = world[eid]
		   if ter_ent.terrain.terrain_obj then 
		     update( assert( ter_ent.terrain.terrain_obj) )
		   end 
        --end 
    end 
end

