local function LOG(...)
	print(...)
end

local fw = require "filewatch"
local repo_new = require "repo".new
local protocol = require "protocol"
local network = require "network"
local lfs = require "filesystem.local"
local debugger = require "debugger"

local watch = {}
local repos = {}
local filelisten
local config

local function vfsjoin(dir, file)
    if file:sub(1, 1) == '/' or dir == '' then
        return file
    end
    return dir:gsub("(.-)/?$", "%1") .. '/' .. file
end

local function split(path)
	local r = {}
	path:string():gsub("[^/\\]+", function(s)
		r[#r+1] = s
	end)
	return r
end

local function watch_add_path(path, repo, url)
	local tree = watch
	for _, e in ipairs(split(lfs.absolute(path))) do
		if not tree[e] then
			tree[e] = {}
		end
		tree = tree[e]
	end
	if not tree[".id"] then
		tree[".id"] = assert(fw.add(path:string()))
	end
	tree[#tree+1] = {
		repo = repo,
		url = url,
	}
end

local function watch_add(repo, repopath)
	watch_add_path(repopath, repo, '')
	for k, v in pairs(repo._mountpoint) do
		watch_add_path(v, repo, k)
	end
end

local function do_prebuilt(repopath, identity)
	local sp = require "subprocess"
	sp.spawn {
        config.lua,
		repopath / "prebuilt.lua",
		identity,
        hideWindow = true,
    } :wait()
end

local function repo_add(identity, reponame)
	local repopath = lfs.path(reponame)
	LOG ("Open repo : ", repopath)
	do_prebuilt(repopath, identity)
	if repos[reponame] then
		local repo = repos[reponame]
		assert(repo._identity == identity)
		if lfs.is_regular_file(repopath / ".repo" / "root") then
			repo:index()
		else
			repo:rebuild()
		end
		return repo
	end
	local repo = repo_new(repopath)
	if not repo then
		return
	end
	LOG ("Rebuild repo")
	repo._identity = identity
	if lfs.is_regular_file(repopath / ".repo" / "root") then
		repo:index()
	else
		repo:rebuild()
	end
	watch_add(repo, repopath)
	repos[reponame] = repo
	return repo
end

local _origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(_origin + os.clock())
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

local function logger_finish(root)
	local logfile = root / '.log' / 'runtime.log'
	if lfs.exists(logfile) then
		lfs.rename(logfile, root / '.log' / 'runtime' / ('%s.log'):format(os_date('%Y_%m_%d_%H_%M_%S_{ms}')))
	end
end

local function logger_init(root)
	lfs.create_directories(root / '.log' / 'runtime')
	logger_finish(root)
end

local function response(obj, ...)
	network.send(obj, protocol.packmessage({...}))
end

local debug = {}
local message = {}

function message:ROOT(identity, reponame)
	LOG("ROOT", identity, reponame)
	local reponame = assert(reponame or config.default_repo,  "Need repo name")
	local repo = repo_add(identity, reponame)
	if repo == nil then
		response(self, "ROOT", "")
		return
	end
	self._repo = repo
	logger_init(self._repo._root)
	response(self, "ROOT", repo:root())
end

function message:GET(hash)
	local repo = self._repo
	local filename = repo:hash(hash)
	if filename == nil then
		response(self, "MISSING", hash)
		return
	end
	local f = io.open(filename:string(), "rb")
	if not f then
		response(self, "MISSING", hash)
		return
	end
	local sz = f:seek "end"
	f:seek("set", 0)
	if sz < 0x10000 then
		response(self, "BLOB", hash, f:read "a")
	else
		response(self, "FILE", hash, tostring(sz))
		local offset = 0
		while true do
			local data = f:read(0x8000)
			response(self, "SLICE", hash, tostring(offset), data)
			offset = offset + #data
			if offset >= sz then
				break
			end
		end
	end
	f:close()
end

function message:DBG(data)
	if data == "" then
		local fd = network.listen('127.0.0.1', 4278)
		LOG("LISTEN DEBUG", '127.0.0.1', 4278)
		debug[fd] = { server = self }
		return
	end
	for _, v in pairs(debug) do
		if v.server == self then
			if v.client then
				network.send(v.client, debugger.convertSend(self._repo, data))
			end
			break
		end
	end
end

function message:LOG(data)
	local logfile = self._repo._root / '.log' / 'runtime.log'
	local fp = assert(lfs.open(logfile, 'a'))
	fp:write(data)
	fp:write('\n')
	fp:close()
end

local output = {}
local function dispatch_obj(obj)
	local reading_queue = obj._read
	while true do
		local msg = protocol.readmessage(reading_queue, output)
		if msg == nil then
			break
		end
		--LOG("REQ :", obj._peer, msg[1])
		local f = message[msg[1]]
		if f then
			f(obj, table.unpack(msg, 2))
		end
	end
end

local function is_fileserver(obj)
	return filelisten == obj._ref
end

local function fileserver_update(obj)
	dispatch_obj(obj)
	if obj._status == "CONNECTING" then
		--LOG("New", obj._peer, obj._ref)
	elseif obj._status == "CLOSED" then
		logger_finish(obj._repo._root)
		for fd, v in pairs(debug) do
			if v.server == obj then
				if v.client then
					network.close(v.client)
				end
				network.close(fd)
				debug[fd] = nil
				break
			end
		end
	end
end

local function is_dbgserver(obj)
	return debug[obj._ref] ~= nil
end

local function dbgserver_update(obj)
	local dbg = debug[obj._ref]
	local data = table.concat(obj._read)
	obj._read = {}
	if data ~= "" then
		local self = dbg.server._repo
		local msg = debugger.convertRecv(self, data)
		while msg do
			response(dbg.server, "DBG", msg)
			msg = debugger.convertRecv(self, "")
		end
	end
	if obj._status == "CONNECTING" then
		obj._status = "CONNECTED"
		LOG("New DBG", obj._peer, obj._ref)
		if dbg.client then
			network.close(obj)
		else
			dbg.client = obj
		end
	elseif obj._status == "CLOSED" then
		if dbg.client == obj then
			dbg.client = nil
		end
		response(dbg.server, "DBG", "") --close DBG
	end
end

local function filewatch()
	while true do
		local type, path = fw.select()
		if not type then
			break
		end
		if type == 'error' then
			print(path)
			goto continue
		end
		local tree = watch
		local elems = split(lfs.absolute(lfs.path(path)))
		for i, e in ipairs(elems) do
			tree = tree[e]
			if not tree then
				break
			end
			if tree[".id"] then
				local rel_path = table.concat(elems, "/", i+1, #elems)
				if rel_path ~= '' and rel_path:sub(1, 1) ~= '.' then
					for _, v in ipairs(tree) do
						local newpath = vfsjoin(v.url, rel_path)
						print('[FileWatch]', type, newpath)
						v.repo:touch(newpath)
					end
				end
			end
		end
		::continue::
	end
end

local function init(v)
	config = v
end

local function listen(...)
	filelisten = network.listen(...)
	LOG ("Listen :", ...)
end

local function mainloop()
	local objs = {}
	while true do
		if network.dispatch(objs, 0.1) then
			for k,obj in ipairs(objs) do
				objs[k] = nil
				if is_fileserver(obj) then
					fileserver_update(obj)
				elseif is_dbgserver(obj) then
					dbgserver_update(obj)
				end
			end
		end
		filewatch()
	end
end

return {
	init = init,
	listen = listen,
	mainloop = mainloop,
}
