if not modules then modules = { } end modules ['font-shp'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local concat = table.concat
local formatters = string.formatters

local otf          = fonts.handlers.otf
local afm          = fonts.handlers.afm

local hashes       = fonts.hashes
local identifiers  = hashes.identifiers

local version      = 0.007
local cache        = containers.define("fonts", "shapes", version, true)

local report       = logs.reporter("fonts","shapes")

-- shapes (can be come a separate file at some point)

local function packoutlines(data,makesequence)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            packoutlines(subfonts[i],makesequence)
        end
        return
    end
    local common = data.segments
    if common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    if makesequence then
        for index=1,#glyphs do
            local glyph = glyphs[index]
            local segments = glyph.segments
            if segments then
                local sequence    = { }
                local nofsequence = 0
                for i=1,#segments do
                    local segment    = segments[i]
                    local nofsegment = #segment
                    nofsequence = nofsequence + 1
                    sequence[nofsequence] = segment[nofsegment]
                    for i=1,nofsegment-1 do
                        nofsequence = nofsequence + 1
                        sequence[nofsequence] = segment[i]
                    end
                end
                glyph.sequence = sequence
                glyph.segments = nil
            end
        end
    else
        local hash    = { }
        local common  = { }
        local reverse = { }
        local last    = 0
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local h = concat(segments[i]," ")
                    hash[h] = (hash[h] or 0) + 1
                end
            end
        end
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local segment = segments[i]
                    local h = concat(segment," ")
                    if hash[h] > 1 then -- minimal one shared in order to hash
                        local idx = reverse[h]
                        if not idx then
                            last = last + 1
                            reverse[h] = last
                            common[last] = segment
                            idx = last
                        end
                        segments[i] = idx
                    end
                end
            end
        end
        if last > 0 then
            data.segments = common
        end
    end
end

local function unpackoutlines(data)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            unpackoutlines(subfonts[i])
        end
        return
    end
    local common = data.segments
    if not common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    for index=1,#glyphs do
        local segments = glyphs[index].segments
        if segments then
            for i=1,#segments do
                local c = common[segments[i]]
                if c then
                    segments[i] = c
                end
            end
        end
    end
    data.segments = nil
end

-- todo: loaders per format

local readers   = otf.readers
local cleanname = readers.helpers.cleanname

local function makehash(filename,sub,instance)
    local name = cleanname(file.basename(filename))
    if instance then
        return formatters["%s-%s-%s"](name,sub or 0,cleanname(instance))
    else
        return formatters["%s-%s"]   (name,sub or 0)
    end
end

local function loadoutlines(filename,sub,instance)
    local base = file.basename(filename)
    local name = file.removesuffix(base)
    local kind = file.suffix(filename)
    local attr = lfs.attributes(filename)
    local size = attr and attr.size or 0
    local time = attr and attr.modification or 0
    local sub  = tonumber(sub)

    -- fonts.formats

    if size > 0 and (kind == "otf" or kind == "ttf" or kind == "tcc") then
        local hash = makehash(filename,sub,instance)
        data = containers.read(cache,hash)
        if not data or data.time ~= time or data.size  ~= size then
            data = readers.loadshapes(filename,sub,instance)
            if data then
                data.size   = size
                data.format = data.format or (kind == "otf" and "opentype") or "truetype"
                data.time   = time
                packoutlines(data)
                containers.write(cache,hash,data)
                data = containers.read(cache,hash) -- frees old mem
            end
        end
        unpackoutlines(data)
    elseif size > 0 and (kind == "pfb") then
        local hash = containers.cleanname(base) -- including suffix
        data = containers.read(cache,hash)
        if not data or data.time ~= time or data.size  ~= size then
            data = afm.readers.loadshapes(filename)
            if data then
                data.size   = size
                data.format = "type1"
                data.time   = time
                packoutlines(data)
                containers.write(cache,hash,data)
                data = containers.read(cache,hash) -- frees old mem
            end
        end
        unpackoutlines(data)
    else
        data = {
            filename = filename,
            size     = 0,
            time     = time,
            format   = "unknown",
            units    = 1000,
            glyphs   = { }
        }
    end
    return data
end

local loadedshapes = { }

local function loadoutlinedata(fontdata)
    local properties = fontdata.properties
    local filename   = properties.filename
    local subindex   = fontdata.subindex
    local instance   = properties.instance
    local hash       = makehash(filename,subindex,instance)
    local loaded     = loadedshapes[hash]
    if not loaded then
        loaded = loadoutlines(filename,subindex,instance)
        loadedshapes[hash] = loaded
    end
    return loaded
end

hashes.shapes = table.setmetatableindex(function(t,k)
    return loadoutlinedata(identifiers[k])
end)

otf.loadoutlinedata = loadoutlinedata

-- experimental code, for me only ... unsupported

local f_c = string.formatters["%F %F %F %F %F %F c"]
local f_l = string.formatters["%F %F l"]
local f_m = string.formatters["%F %F m"]

local function addvariableshapes(tfmdata,key,value)
    if value then
        local shapes = otf.loadoutlinedata(tfmdata)
        if not shapes then
            return
        end
        local glyphs = shapes.glyphs
        if not glyphs then
            return
        end
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        local hfactor    = parameters.hfactor * (7200/7227)
        local factor     = hfactor / 65536
        local getactualtext = otf.getactualtext
        for unicode, char in next, characters do
            if not char.commands then
                local shape = glyphs[char.index]
                if shape then
                    local segments = shape.segments
                    if segments then
                        local t = { }
                        local n = #segments
                        local bt, et = getactualtext(char.tounicode or char.unicode or unicode)
                        for i=1,n do
                            local s = segments[i]
                            local m = #s
                            local w = s[m]
                            if w == "c" then
                                t[i] = f_c(s[1]*factor,s[2]*factor,s[3]*factor,s[4]*factor,s[5]*factor,s[6]*factor)
                            elseif w == "l" then
                                t[i] = f_l(s[1]*factor,s[2]*factor)
                            elseif w == "m" then
                                t[i] = f_m(s[1]*factor,s[2]*factor)
                            else
                                t[i] = ""
                            end
                        end
--                         local boundingbox = shape.boundingbox
--                         char.height =   boundingbox[4] * hfactor
--                         char.depth  = - boundingbox[2] * hfactor
--                         if shape.width then
--                             char.width = shape.width * hfactor
--                         end
                     -- -- not ok: color etc but a temp hack anyway
                     -- if false then
                     --     t[n+1] = "h f" -- B*
                     --     char.commands = {
                     --         { "special", "pdf:direct:" .. bt },
                     --         { "down", char.depth },
                     --         {
                     --             "image",  {
                     --                 stream = concat(t,"\n"),
                     --                 bbox   = shape.boundingbox,
                     --             }
                     --         },
                     --         { "special",  "pdf:direct" .. et },
                     --     }
                     -- else
                            t[0]   = bt
                            t[n+1] = "h f" -- B*
                            t[n+2] = et
                            char.commands = {
                                { "special",  "pdf:" .. concat(t,"\n",0,n+2) }
                            }
                     -- end
                    end
                end
            end
        end
    end
end

otf.features.register {
    name        = "variableshapes", -- enforced for now
    description = "variable shapes",
    manipulators = {
        base = addvariableshapes,
        node = addvariableshapes,
    }
}
