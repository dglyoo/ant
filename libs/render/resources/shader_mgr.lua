local require = import and import(...) or require
local log = log and log(...) or print

local bgfx = require "bgfx"
local baselib = require "bgfx.baselib"
local rhwi = require "render.hardware_interface"
local toolset = require "editor.toolset"
local path = require "filesystem.path"
local assetmgr = require "asset"
local fs = require "filesystem"
local fu = require "filesystem.util"

-- init
local function get_shader_rendertype_path()
    local caps = rhwi.get_caps()
    local paths = {
        NOOP       = "dx9",
        DIRECT3D9  = "dx9",
        DIRECT3D11 = "dx11",
        DIRECT3D12 = "dx11",
        GNM        = "pssl",
        METAL      = "metal",
        OPENGL     = "glsl",
        OPENGLES   = "essl",
        VULKAN     = "spirv",
    }

    return assert(paths[caps.rendererType])
end

local function get_compile_renderer_name()
    local caps = rhwi.get_caps()
    local rendertype = caps.rendererType
    local platform = baselib.platform_name

    if  rendertype == "DIRECT3D9" then
        return "d3d9"
    end

    if  rendertype == "DIRECT3D11" or
        rendertype == "DIRECT3D12" then
        return "d3d11"
    end

    return platform
end


local alluniforms = {}

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local function compile_shader(filename, outfile)
    local config = toolset.load_config()

    if next(config) == nil then
        return false, "load_config file failed, 'bin/iup.exe tools/config.lua' need to run first"
	end
	
	local cwd = fs.currentdir()
	config.includes = {config.shaderinc, path.join(cwd, "assets/shaders/src")}
    config.dest = outfile
    return toolset.compile(filename, config, get_compile_renderer_name())
end

local function check_compile_shader(name)
    local rt_path = get_shader_rendertype_path()
    local shader_subpath = path.join("shaders", rt_path, name)
    shader_subpath = path.remove_ext(shader_subpath) .. ".bin"

    local ext = path.ext(name)
    if ext and ext:lower() == "sc" then
        local srcdir = path.join("shaders/src", name)
        local srcpath = assetmgr.find_valid_asset_path(srcdir)
        if srcpath then
            local assetdir = assetmgr.assetdir()
			local outfile = path.join(assetdir, shader_subpath)
			
			if not fs.exist(outfile) or fu.file_is_newer(srcpath, outfile) then
				path.create_dirs(path.parent(outfile))            
				local success, msg = compile_shader(srcpath, outfile)
				if not success then
					print(string.format("try compile from file %s, but failed, error message : \n%s", srcpath, msg))
					return nil
				end
			end 

            return outfile
        end
    end

    return assetmgr.find_valid_asset_path(shader_subpath)
end

local function load_shader(name)
    local filename = check_compile_shader(name)
    if filename then
        local f = assert(io.open(filename, "rb"))
        local data = f:read "a"
        f:close()
        local h = bgfx.create_shader(data)
        bgfx.set_name(h, filename)
        return h
    end
    return nil
end

local function load_shader_uniforms(name)
    local h = load_shader(name)
    print("load uniform ",name )
    assert(h)
    local uniforms = bgfx.get_shader_uniforms(h)
    return h, uniforms
end

local function uniform_info(uniforms, handles)
    for _, h in ipairs(handles) do
        local name, type, num = bgfx.get_uniform_info(h)
        if uniforms[name] == nil then
            uniforms[name] = { handle = h, name = name, type = type, num = num }
        end
    end
end

local function programLoadEx(vs,fs, uniform)
    local vsid, u1 = load_shader_uniforms(vs)
    local fsid, u2
    if fs then
        fsid, u2 = load_shader_uniforms(fs)
    end
    uniform_info(uniform, u1)
    if u2 then
        uniform_info(uniform, u2)
    end
    return bgfx.create_program(vsid, fsid, true), uniform
end

function shader_mgr.programLoad(vs,fs, uniform)
    if uniform then
        local prog = programLoadEx(vs,fs, uniform)
        if prog then
            print("------- load shader  ",vs,fs,unifrom)
            for k, v in pairs(uniform) do
                local old_u = alluniforms[k]
                if old_u and old_u.type ~= v.type and old_u.num ~= v.num then
                    log(string.format([[previous has been defined uniform, 
                                    nameis : %s, type=%s, num=%d, replace as : type=%s, num=%d]],
                                    old_u.name, old_u.type, old_u.num, v.type, v.num))
                end

                alluniforms[k] = v
            end
        end
        return prog
    else
        local vsid = load_shader(vs)
        local fsid = fs and load_shader(fs)  
        print(" load vs -------",vs,vsid)      
        print(" load fs -------",fs,fsid)
        return bgfx.create_program(vsid, fsid, true)
    end
end

function shader_mgr.computeLoad(cs)
    local csid = load_shader(cs)
    return bgfx.create_program(csid, true)
end

function shader_mgr.get_uniform(name)
    return alluniforms[name]
end

-- function shader_mgr.add_uniform(name, type, num)
-- 	local uh = alluniforms[name]
-- 	if uh == nil then
-- 		num = num or 1
-- 		uh = bgfx.create_uniform(name, type, num)
-- 		alluniforms[name] = { handle = uh, name = name, type = type, num = num }
-- 	end
-- 	return uh
-- end

return shader_mgr