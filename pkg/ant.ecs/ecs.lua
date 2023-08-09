local pm = require "packagemanager"

local function sourceinfo()
	local info = debug.getinfo(3, "Sl")
	return string.format("%s(%d)", info.source, info.currentline)
end

local function keys(tbl)
	local k = {}
	for _, v in ipairs(tbl) do
		k[v] = true
	end
	return k
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local OBJECT = {"system","policy","interface","component"}

return function (w, package)
    local ecs = { world = w, method = w._set_methods }
    local declaration = w._decl
    local import = w._importor
    local function register(what)
        local class_set = {}
        ecs[what] = function(name)
            local fullname = name
            if what ~= "action" and what ~= "component" then
                fullname = package .. "|" .. name
            end
            local r = class_set[fullname]
            if r == nil then
                log.debug("Register", #what<8 and what.."  " or what, fullname)
                r = {}
                class_set[fullname] = r
                local decl = declaration[what][fullname]
                if not decl then
                    error(("%s `%s` has no declaration."):format(what, fullname))
                end
                if not decl.method then
                    error(("%s `%s` has no method."):format(what, fullname))
                end
                decl.source = {}
                decl.defined = sourceinfo()
                local callback = keys(decl.method)
                local object = import[what](package, fullname)
                setmetatable(r, {
                    __pairs = function ()
                        return pairs(object)
                    end,
                    __index = object,
                    __newindex = function(_, key, func)
                        if type(func) ~= "function" then
                            error(decl.defined..":Method should be a function")
                        end
                        if callback[key] == nil then
                            error(decl.defined..":Invalid callback function " .. key)
                        end
                        if decl.source[key] ~= nil then
                            error(decl.defined..":Method " .. key .. " has already defined at " .. decl.source[key])
                        end
                        decl.source[key] = sourceinfo()
                        object[key] = func
                    end,
                })
            end
            return r
        end
    end
    register "system"
    register "interface"
    register "component"
    function ecs.require(fullname)
        local pkg, file = splitname(fullname)
        if not pkg then
            pkg = package
            file = fullname
        end
        return pm.loadenv(pkg)
            .require_ecs(w, w._ecs[pkg], file)
    end
    ecs.import = {}
    for _, objname in ipairs(OBJECT) do
        ecs.import[objname] = function (name)
            return w:_import(objname, package, name)
        end
    end
    function ecs.create_entity(v)
        return w:_create_entity(package, nil, v)
    end
    function ecs.release_cache(v)
        return w:_release_cache(v)
    end
    function ecs.create_instance(v, parent)
        return w:_create_instance(nil, parent, v)
    end
    function ecs.group(id)
        return w:_create_group(id)
    end
    function ecs.group_flush(tag)
        return w:_group_flush(tag)
    end
    function ecs.clibs(name)
        return w:clibs(name)
    end
    w._ecs[package] = ecs
    return ecs
end
