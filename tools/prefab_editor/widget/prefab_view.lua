local ecs = ...
local world = ecs.world
local w = world.w

local datalist  = require "datalist"
local fs        = require "filesystem"
local imgui     = require "imgui"

local uiproperty= ecs.require "widget.uiproperty"
local gizmo     = ecs.require "gizmo.gizmo"
local hierarchy = ecs.require "hierarchy_edit"
local uiutils   = ecs.require "widget.utils"

local component_desc = datalist.parse(fs.open(fs.path "/pkg/tools.prefab_editor/common/component_desc.txt"):read "a")
local component_names = {}
for k in pairs(component_desc) do
    component_names[#component_names+1] = k
end
table.sort(component_names)

local function sort_pairs(t)
    local s = {}
    for k in pairs(t) do
        s[#s+1] = k
    end

    table.sort(s)

    local n = 1
    return function ()
        local k = s[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end




local prefab_view = {}

local uimapper = {
    string = function (name, desc, value)
        
    end,
    array = function (name, desc, value)
    end,
    int = function (name, desc, value)
    end,
}

local function build_ui(compname, compdesc, compvalue)
    local d = compdesc[compname]
    if d.type == "string" then
        imgui.widget.LabelText(compname)
        imgui.widget.Selectable(compname)
    elseif d == "array" then
        --imgui.widget
    elseif d == "int" then
    elseif d == "float" then
    elseif d == "table" then
        if imgui.widget.TreeNode(compname, imgui.flags.TreeNode{"DefaultOpen"}) then
        for k, v in sort_pairs(compvalue) do
                build_ui(k, d[k], v)
            end
        end
        imgui.widget.TreePop()
        build_ui()
    end
end

function prefab_view:show()
    local eid = gizmo.target_eid

    if eid == nil then
        return
    end
    local t = hierarchy:get_template(gizmo.target_eid)
    if t == nil then
        return
    end

    for _ in uiutils.imgui_windows("Prefab", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if imgui.widget.CollapsingHeader("Prefab Data", imgui.flags.TreeNode{"DefaultOpen"}) then
            for _, n in ipairs(component_names) do
                local v = t[n]
                if v then

                else
                    -- if imgui.widget.TreeNode(n, imgui.flags.TreeNode{"DefaultOpen"}) then
                    --     imgui.widget.TreePop()
                    -- end
                end

                -- local tv = t[n]
                -- if tv then
                --     local d = component_desc[n]
                --     components[n] = uimapper[d.type](n, d, tv)
                -- end
            end
        end

        
    end
end

-- function prefab_view:show()
-- end

return prefab_view