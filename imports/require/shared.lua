local loaded = {}

package = {
    loaded = setmetatable({}, {
        __index = loaded,
        __newindex = noop,
        __metatable = false,
    }),
    path = './?.lua;'
}

local _require = require

---Loads the given module inside the current resource, returning any values returned by the file or `true` when `nil`.
---@param modname string
---@return unknown?
function lib.require(modname)
    if type(modname) ~= 'string' then return end

    local module = loaded[modname]

    if not module then
        if module == false then
            error(("^1circular-dependency occurred when loading module '%s'^0"):format(modname), 2)
        end

        local success, result = pcall(_require, modname)

        if success then
            loaded[modname] = result
            return result
        end

        local idx, resourceSrc = 1

        while true do
            local di = debug.getinfo(idx, 'S')

            if not di or di.short_src:find('^@' .. cache.resource) then
                resourceSrc = cache.resource
                break
            elseif di.short_src:find('^citizen') then
                resourceSrc = idx == 2 and cache.resource or debug.getinfo(idx - 1, 'S').short_src:gsub('^@(.-)/.+', '%1')
                break
            end

            idx += 1
        end

        local modpath = modname:gsub('%.', '/')

        for path in package.path:gmatch('[^;]+') do
            local scriptPath = path:gsub('?', modpath):gsub('%.+%/+', '')
            local resourceFile = LoadResourceFile(resourceSrc, scriptPath)

            if resourceSrc ~= cache.resource then
                modname = ('@%s.%s'):format(resourceSrc, modname)
            end

            if resourceFile then
                loaded[modname] = false
                scriptPath = ('@@%s/%s'):format(resourceSrc, scriptPath)

                local chunk, err = load(resourceFile, scriptPath)

                if err or not chunk then
                    loaded[modname] = nil
                    return error(err or ("unable to load module '%s'"):format(modname), 3)
                end

                module = chunk(modname) or true
                loaded[modname] = module

                return module
            end
        end

        return error(result, 2)
    end

    return module
end

return lib.require
