-- dofile "libs/init.lua"

-- local fu = require "filesystem.util"

-- local meshfile = "mem://test.mesh"
-- fu.write_to_file(meshfile, [[
-- 	mesh_path = "meshes/PVPScene/BH-Scene-campsite-Door"
-- ]])

-- local assetmgr = require "asset"
-- assetmgr.


local assimp = require "assimplua"

assimp.ConvertFBX("../../assets/build/meshes/PVPScene/BH-Scene-campsite-Door.FBX", "./BH-Scene-campsite-Door.antmesh", {
	layout = "p3|n|T|b|t20|c30",
	flags = {
		gen_normal = false,
		tangentspace = true,
	
		invert_normal = false,
		flip_uv = true,
		ib_32 = false,	-- if index num is lower than 65535
	},
	animation = {
		load_skeleton = true,
		ani_list = "all" -- or {"walk", "stand"}
	},
})

local antmeshloader = require "../../libs/modelloader/antmeshloader"

antmeshloader("./BH-Scene-campsite-Door.antmesh")