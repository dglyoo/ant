local datalist = require "datalist"
local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"

local CURPATH = {}
local function push_currentpath(path)
	CURPATH[#CURPATH+1] = path:match "^(.-)[^/|]*$"
end
local function pop_currentpath()
	CURPATH[#CURPATH] = nil
end
local function absolute_path(path)
	local base = CURPATH[#CURPATH]
	if path:sub(1,1) == "/" or not base then
		return path
	end
	return base .. (path:match "^%./(.+)$" or path)
end

local SEARCH = {}

local function prebuilt(ext, path, ...)
    local fullpath = absolute_path(path)
    push_currentpath(fullpath)
    local f = assert(lfs.open(cr.compile(fullpath), "rb"))
    local data = f:read "a"
    f:close()
    assert(SEARCH[ext])(assert(datalist.parse(data)), ...)
    pop_currentpath()
end

local function prebuilt_material(v, fx_setting)
    if type(v) == "string" then
        prebuilt("material", v, fx_setting)
    else
        SEARCH.material(v, fx_setting)
    end
end

local function prebuilt_fx(v, setting)
    if type(v) == "string" then
        prebuilt("fx", v, setting)
    else
        SEARCH.fx(v, setting)
    end
end

local function array_has(t, name)
    for i = 1, #t do
        if t[i] == name then
            return true
        end
    end
end

local function prebuilt_entity(v)
    local e = v.data
    if e.material then
        local fx_setting
        if array_has(v.policy, "ant.animation|skinning") then
            fx_setting = {skinning = "GPU"}
        end
        prebuilt_material(e.material, fx_setting)
    end
end

function SEARCH.prefab(data)
    for _, v in ipairs(data) do
        if v.prefab then
            prebuilt("prefab", v.prefab)
        else
            prebuilt_entity(v)
        end
    end
end

function SEARCH.material(data, fx_setting)
    prebuilt_fx(data.fx, fx_setting)
    if data.properties then
        for _, v in pairs(data.properties) do
            if v.texture then
                cr.compile(absolute_path(v.texture))
            end
        end
    end
end

function SEARCH.fx(data, setting)
    for k, v in pairs(data.shader) do
        data.shader[k] = absolute_path(v)
    end
    cr.compile_fx(data, setting)
end

local tasks = {}

local function load(...)
    tasks[#tasks+1] = {...}
end

local function build(identity)
    cr.set_identity(identity)
    for _, task in ipairs(tasks) do
        prebuilt(table.unpack(task))
    end
end

return {
    load = load,
    build = build,
}
