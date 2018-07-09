local event = require 'new-debugger.event'
local response = require 'new-debugger.response'
local path = require 'new-debugger.path'

local CMD = {}

function CMD.eventStop(w, req)
    event.stopped(w, req.reason)
end

function CMD.stackTrace(w, req)
    for _, frame in ipairs(req.stackFrames) do
        frame.id = (w << 16) | frame.id
        if frame.source and frame.source.sourceReference then
            frame.source.sourceReference = (w << 32) | frame.source.sourceReference
        end
    end
    response.success(req, {
        stackFrames = req.stackFrames,
        totalFrames = req.totalFrames,
    })
end

function CMD.source(w, req)
    if not req.content then
        response.success(req, {
            content = 'Source not available',
            mimeType = 'text/x-lua',
        })
        return
    end
    response.success(req, {
        content = req.content,
        mimeType = 'text/x-lua',
    }) 
end

function CMD.scopes(w, req)
    for _, scope in ipairs(req.scopes) do
        scope.variablesReference = (w << 32) | scope.variablesReference
    end
    response.success(req, {
        scopes = req.scopes
    }) 
end

function CMD.variables(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    for _, var in ipairs(req.variables) do
        if var.variablesReference then
            var.variablesReference = (w << 32) | var.variablesReference
        end
    end
    response.success(req, {
        variables = req.variables
    })
end

return CMD
