local vfs = {} ; vfs.__index = vfs

-- dir object example :
-- f vfs.txt 90a5c279259fd4e105c4eb8378e9a21694e1e3c4 1533871795

local function read_history(self)
	local history = {}
	local f = io.open(self.path .. "root", "rb")
	if f then
		for hash in f:lines() do
			history[#history+1] = hash:match "[%da-f]+"
		end
		f:close()
	end
	return history
end

local function update_history(self, new)
	local history = read_history(self)
	for i, h in ipairs(history) do
		if h == new then
			table.remove(history, i)
			table.insert(history, 1, h)
			return history
		end
	end
	table.insert(history, 1, new)
	history[11] = nil
	return history
end

local function root_hash(self)
	local f = io.open(self.path .. "root", "rb")
	if f then
		local hash = f:read "l"
		f:close()
		return (hash:match "[%da-f]+")
	end
end

function vfs.new(repopath)
	local repo = {
		path = repopath:gsub("[/\\]?$","/") .. ".repo/",
		cache = {},--setmetatable( {} , { __mode = "kv" } ),
		compile = {},
		root = nil,
	}
	repo.root = root_hash(repo)
	return setmetatable(repo, vfs)
end

local function dir_object(self, hash)
	local realname = self.path .. hash:sub(1,2) .. "/" .. hash
	local df = io.open(realname, "rb")
	if df then
		local dir = {}
		for line in df:lines() do
			local type, hash, name = line:match "([fd]) ([%da-f]+) (.*)"
			if type then
				dir[name] = {
					dir = type == 'd',
					hash = hash,
				}
			end
		end
		df:close()
		local c = self.compile[hash]
		if c then
			local sub = {}
			for h, fullpath in pairs(c) do
				local path, name = fullpath:match "([^/]*)/?(.*)"
				if name == "" then
					dir[path] = {
						dir = true,
						hash = h,
					}
				else
					sub[h] = {path=path, name=name}
				end
			end
			self.compile[hash] = nil
			for h, inf in pairs(sub) do
				local d = assert(dir[inf.path])
				local c = self.compile[d.hash]
				if not c then
					c = {}
					self.compile[hash] = c
				end
				c[h] = inf.name
			end
		end
		return dir
	end
end

local function fetch_file(self, hash, fullpath, parent)
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return false, hash
		end
		self.cache[hash] = dir
	end

	local path, name = fullpath:match "([^/]*)/?(.*)"
	local subpath = dir[path]
	if subpath then
		if name == "" then
			return true, subpath.hash
		elseif subpath.dir then
			return fetch_file(self, subpath.hash, name, parent.."/"..path)
		end
	elseif path:match "%?" then
		return false, (parent.."/"..path):sub(2)
	end
	-- invalid repo, root change
end

function vfs:list(path)
	local hash
	if path == "" then
		hash = self.root
	else
		if not self.root then
			return false
		end
		local ok, h = fetch_file(self, self.root, path, "")
		if not ok then
			return false, h
		end
		hash = h
	end
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			return false, hash
		end
		self.cache[hash] = dir
	end
	return dir
end

local function fetch_hash(self, hash, fullpath, addhash)
	local dir = self.cache[hash]
	if not dir then
		dir = dir_object(self, hash)
		if not dir then
			local c = self.compile[hash]
			if not c then
				c = {}
				self.compile[hash] = c
			end
			c[addhash] = fullpath
			return true
		end
		self.cache[hash] = dir
	end
	local path, name = fullpath:match "([^/]*)/?(.*)"
	local subpath = dir[path]
	if name == "" then
		if subpath then
			return
		end
		dir[path] = {
			dir = true,
			hash = addhash
		}
		return true
	elseif subpath and subpath.dir then
		return fetch_hash(self, subpath.hash, name, addhash)
	end
end

function vfs:compilehash(path, hash)
	if not self.root then
		return false
	end
	return fetch_hash(self, self.root, path, hash)
end

function vfs:changeroot(hash)
	local history = update_history(self, hash)
	local f = assert(io.open(self.path .. "root", "wb"))
	f:write(table.concat(history, "\n"))
	f:close()
	self.root = hash
end

function vfs:realpath(path)
	if not self.root then
		return
	end
	local ok, hash = fetch_file(self, self.root, path, "")
	if not ok then
		return nil, hash
	end

	local f_n = self.path .. hash:sub(1,2) .. "/" .. hash
	return f_n, hash
end

function vfs:hashpath(hash)
	return self.path .. hash:sub(1,2) .. "/" .. hash
end

return vfs
