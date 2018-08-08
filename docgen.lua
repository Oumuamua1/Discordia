local fs = require('fs')
local pathjoin = require('pathjoin')

local insert, sort, concat = table.insert, table.sort, table.concat
local pathJoin = pathjoin.pathJoin

local function scan(dir)
	for fileName, fileType in fs.scandirSync(dir) do
		local path = pathJoin(dir, fileName)
		if fileType == 'file' then
			coroutine.yield(path)
		else
			scan(path)
		end
	end
end

local function checkType(docstring, token)
	return docstring:find(token) == 1
end

local function match(s, pattern) -- only useful for one return value
	return assert(s:match(pattern), s)
end

local docs = {}

for f in coroutine.wrap(function() scan('./libs') end) do

	local d = assert(fs.readFileSync(f))

	local class = {
		methods = {},
		statics = {},
		properties = {},
		parents = {},
	}

	for s in d:gmatch('--%[=%[%s*(.-)%s*%]=%]') do

		if checkType(s, '@i?c') then

			class.name = match(s, '@i?c (%w+)')
			class.userInitialized = checkType(s, '@ic')
			for parent in s:gmatch('x (%w+)') do
				insert(class.parents, parent)
			end
			class.desc = match(s, '@d (.+)'):gsub('\r?\n', ' ')
			class.parameters = {}
			for optional, paramName, paramType in s:gmatch('@(o?)p (%w+)%s+([%w%p]+)') do
				insert(class.parameters, {paramName, paramType, optional == 'o'})
			end

		elseif checkType(s, '@s?m') then

			local method = {parameters = {}}
			method.name = match(s, '@s?m (%w+)')
			for optional, paramName, paramType in s:gmatch('@(o?)p (%w+)%s+([%w%p]+)') do
				insert(method.parameters, {paramName, paramType, optional == 'o'})
			end
			method.returnType = s:match('@r ([%w%p]+)')
			method.desc = match(s, '@d (.+)'):gsub('\r?\n', ' ')
			insert(checkType(s, '@sm') and class.statics or class.methods, method)

		elseif checkType(s, '@p') then

			local propertyName, propertyType, propertyDesc = s:match('@p (%w+)%s+([%w%p]+)%s+(.+)')
			assert(propertyName, s); assert(propertyType, s); assert(propertyDesc, s)
			propertyDesc = propertyDesc:gsub('\r?\n', ' ')
			insert(class.properties, {propertyName, propertyType, propertyDesc})

		end

	end

	if class.name then
		docs[class.name] = class
	end

end

local function link(str)
	return docs[str] and '[[' .. str .. ']]' or str
end

local function propertySorter(a, b)
	return a[1] < b[1]
end

local function methodSorter(a, b)
	return a.name < b.name
end

local function writeProperties(f, properties)
	sort(properties, propertySorter)
	f:write('| Name | Type | Description |\n')
	f:write('|-|-|-|\n')
	for _, v in ipairs(properties) do
		f:write('| ', v[1], ' | ', link(v[2]), ' | ', v[3], ' |\n')
	end
end

local function writeParameters(f, parameters)
	f:write('(')
	local optional
	if parameters[1] then
		for i, param in ipairs(parameters) do
			f:write(param[1])
			if i < #parameters then
				f:write(', ')
			end
			if param[3] then
				optional = true
			end
		end
		f:write(')\n')
		if optional then
			f:write('>| Name | Type | Optional |\n')
			f:write('>|-|-|:-:|\n')
			for _, param in ipairs(parameters) do
				local o = param[3] and '✔' or ''
				f:write('>| ', param[1], ' | ', param[2], ' | ', o, ' |\n')
			end
		else
			f:write('>| Parameter | Type |\n')
			f:write('>|-|-|\n')
			for _, param in ipairs(parameters) do
				f:write('>| ', param[1], ' | ', link(param[2]), '|\n')
			end
		end
	else
		f:write(')\n')
	end
end

local function writeMethods(f, methods)
	sort(methods, methodSorter)
	for _, method in ipairs(methods) do
		f:write('### ', method.name)
		writeParameters(f, method.parameters)
		f:write('>\n>', method.desc, '\n>\n')
		f:write('>Returns: ', link(method.returnType or 'nil'), '\n\n')
	end
end

if not fs.existsSync('docs') then
	fs.mkdirSync('docs')
end

for _, class in pairs(docs) do

	local f = io.open(pathJoin('docs', class.name .. '.md'), 'w')

	if next(class.parents) then
		f:write('#### *extends ', '[[', concat(class.parents, ']], [['), ']]*\n\n')
	end

	f:write(class.desc, '\n\n')

	if class.userInitialized then
		f:write('## Constructor\n\n')
		f:write('### ', class.name)
		writeParameters(f, class.parameters)
		f:write('\n')
	else
		f:write('*Instances of this class should not be constructed by users.*\n\n')
	end

	for _, parent in ipairs(class.parents) do
		if docs[parent] and next(docs[parent].properties) then
			f:write('## Properties Inherited From ', link(parent), '\n\n')
			writeProperties(f, docs[parent].properties)
		end
	end

	if next(class.properties) then
		f:write('## Properties\n\n')
		writeProperties(f, class.properties)
	end

	for _, parent in ipairs(class.parents) do
		if docs[parent] and next(docs[parent].statics) then
			f:write('## Static Methods Inherited From ', link(parent), '\n\n')
			writeMethods(f, docs[parent].statics)
		end
	end

	for _, parent in ipairs(class.parents) do
		if docs[parent] and next(docs[parent].methods) then
			f:write('## Methods Inherited From ', link(parent), '\n\n')
			writeMethods(f, docs[parent].methods)
		end
	end

	if next(class.statics) then
		f:write('## Static Methods\n\n')
		writeMethods(f, class.statics)
	end

	if next(class.methods) then
		f:write('## Methods\n\n')
		writeMethods(f, class.methods)
	end

	f:close()

end
