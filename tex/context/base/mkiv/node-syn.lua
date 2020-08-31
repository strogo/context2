if not modules then modules = { } end modules ['node-syn'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Because we have these fields in some node that are used by synctex, and because
-- some users seem to like that feature, I decided to implement a variant that might
-- work out better for ConTeXt. This is experimental code. I don't use it myself so
-- it will take a while to mature. There will be some helpers that one can use in
-- more complex situations like included xml files. Currently (somewhere else) we
-- take care of valid files, that is: we prohibit access to files in the tree
-- because we don't want users to mess up styles.
--
-- It is unclear how the output gets interpreted but by reverse engineering (and
-- stripping) the file generated by generic synctex, I got there eventually. For
-- instance, we only need to be able to go back to a place where text is entered,
-- but still we need all that redundant box wrapping. Anyway, I was able to get a
-- minimal output and cross my fingers that the parser used in editors is not
-- changed in fundamental ways.
--
-- I only tested SumatraPDF with SciTE, for which one needs to configure in the
-- viewer:
--
--   InverseSearchCmdLine = c:\data\system\scite\wscite\scite.exe "%f" "-goto:%l" $
--
-- In fact, a way more powerful implementation would have been not to add a library
-- to a viewer, but letthe viewer call an external program:
--
--   InverseSearchCmdLine = mtxrun.exe --script synctex --edit --name="%f" --line="%l" $
--
-- which would (re)launch the editor in the right spot. That way we can really
-- tune well to the macro package used and also avoid the fuzzy heuristics of
-- the library.
--
-- Unfortunately syntex always removes the files at the end and not at the start
-- (this happens in synctexterminate) so we need to work around that by using an
-- intermediate file. This is no big deal in context (which has a runner) but
-- definitely not nice.
--
-- The visualizer code is only needed for testing so we don't use fancy colors or
-- provide more detail. After all we're only interested in rendered source text
-- anyway. We try to play safe which sometimes means that we'd better no go
-- somewhere than go someplace wrong.
--
-- A previous version had a mode for exporting boxes and such but I removed that
-- as it made no sense. Also, collecting output in a table was not faster than
-- directly piping to the file, probably because the amount is not that large. We
-- keep some left-overs commented.
--
-- A significate reduction in file size can be realized when reusing the same
-- values. Actually that triggered the current approach in ConTeXt. In the latest
-- synctex parser vertical positions can be repeated by an "=" sign but for some
-- reason only for that field. It's probably trivial to do that for all of "w h d v
-- h" but it currently not the case so I'll delay that till all are supported. (We
-- could benefit a lot from such a repetition scheme but not much from a "v" alone
-- which -alas- indicates that synctex is still mostly a latex targeted story.)
--
-- It's kind of hard to fight the parser because it really wants to go to some file
-- but maybe some day I can figure it out. Some untagged text (in the pdf) somehow
-- gets seen as part of the last box. Anonymous content is simply not part of the
-- concept. Using a dummy name doesn't help either as the editor gets a signal to
-- open that dummy. Even an empty filename doesn't work.
--
-- We output really simple and compact code, like:
--
-- SyncTeX Version:1
-- Input:1:e:/tmp/oeps.tex
-- Input:2:c:/data/develop/context/sources/klein.tex
-- Output:pdf
-- Magnification:1000
-- Unit:1
-- X Offset:0
-- Y Offset:0
-- Content:
-- !160
-- {1
-- h0,0:0,0,0,0,0
-- v0,0:0,55380990:39158276,55380990,0
-- h2,1:4661756,9176901:27969941,655360,327680
-- h2,2:4661756,10125967:26048041,655360,327680
-- h2,3:30962888,10125967:1668809,655360,327680
-- h2,3:4661756,11075033:23142527,655360,327680
-- h2,4:28046650,11075033:4585047,655360,327680
-- h2,4:4661756,12024099:22913954,655360,327680
-- h2,5:27908377,12024099:4723320,655360,327680
-- h2,5:4661756,12973165:22918783,655360,327680
-- h2,6:27884864,12973165:4746833,655360,327680
-- h2,6:4661756,13922231:18320732,655360,327680
-- ]
-- !533
-- }1
-- Input:3:c:/data/develop/context/sources/ward.tex
-- !57
-- {2
-- h0,0:0,0,0,0,0
-- v0,0:0,55380990:39158276,55380990,0
-- h3,1:4661756,9176901:18813145,655360,327680
-- h3,2:23713999,9176901:8917698,655360,327680
-- h3,2:4661756,10125967:10512978,655360,327680
-- h3,3:15457206,10125967:17174491,655360,327680
-- h3,3:4661756,11075033:3571223,655360,327680
-- h3,4:8459505,11075033:19885281,655360,327680
-- h3,5:28571312,11075033:4060385,655360,327680
-- h3,5:4661756,12024099:15344870,655360,327680
-- ]
-- !441
-- }2
-- !8
-- Postamble:
-- Count:22
-- !23
-- Post scriptum:
--
-- But for some reason, when the pdf file has some extra content (like page numbers)
-- the main document is consulted. Bah. It would be nice to have a mode for *only*
-- looking at marked areas. It somehow works not but maybe depends on the parser.
--
-- Supporting reuseable objects makes not much sense as these are often graphics or
-- ornamental. They can not have hyperlinks etc (at least not without some hackery
-- which I'm not willing to do) so basically they are sort of useless for text.

local type, rawset = type, rawset
local concat = table.concat
local formatters = string.formatters
local replacesuffix, suffixonly, nameonly = file.replacesuffix, file.suffix, file.nameonly
local openfile, renamefile, removefile = io.open, os.rename, os.remove

local report_system = logs.reporter("system")

local tex                = tex
local texget             = tex.get

local nuts               = nodes.nuts

local getid              = nuts.getid
local getlist            = nuts.getlist
local setlist            = nuts.setlist
local getnext            = nuts.getnext
local getwhd             = nuts.getwhd
local getwidth           = nuts.getwidth
local getsubtype         = nuts.getsubtype

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local penalty_code       = nodecodes.penalty
local kern_code          = nodecodes.kern
----- rule_code          = nodecodes.rule
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local dir_code           = nodecodes.dir
local fontkern_code      = kerncodes.fontkern

local cancel_code        = nodes.dircodes.cancel

local insert_before      = nuts.insert_before
local insert_after       = nuts.insert_after

local nodepool           = nuts.pool
local new_latelua        = nodepool.latelua
local new_rule           = nodepool.rule
local new_kern           = nodepool.kern

local getdimensions      = nuts.dimensions
local getrangedimensions = nuts.rangedimensions

local getsynctexfields   = nuts.getsynctexfields or nuts.get_synctex_fields
local forcesynctextag    = tex.forcesynctextag   or tex.force_synctex_tag
local forcesynctexline   = tex.forcesynctexline  or tex.force_synctex_line
local getsynctexline     = tex.getsynctexline    or tex.get_synctex_line
local setsynctexmode     = tex.setsynctexmode    or tex.set_synctex_mode

local foundintree        = resolvers.foundintree

local eol                = "\010"

----- f_glue             = formatters["g%i,%i:%i,%i\010"]
----- f_glyph            = formatters["x%i,%i:%i,%i\010"]
----- f_kern             = formatters["k%i,%i:%i,%i:%i\010"]
----- f_rule             = formatters["r%i,%i:%i,%i:%i,%i,%i\010"]
----- f_form             = formatters["f%i,%i,%i\010"]
local z_hlist            = "[0,0:0,0:0,0,0\010"
local z_vlist            = "(0,0:0,0:0,0,0\010"
----- z_xform            = "<0,0:0,0,0\010" -- or so
local s_hlist            = "]\010"
local s_vlist            = ")\010"
----- s_xform            = ">\010"
local f_hlist_1          = formatters["h%i,%i:%i,%i:%i,%i,%i\010"]
local f_hlist_2          = formatters["h%i,%i:%i,%s:%i,%i,%i\010"]
local f_vlist_1          = formatters["v%i,%i:%i,%i:%i,%i,%i\010"]
local f_vlist_2          = formatters["v%i,%i:%i,%s:%i,%i,%i\010"]

local synctex            = luatex.synctex or { }
luatex.synctex           = synctex

local getpos ; getpos = function() getpos = job.positions.getpos return getpos() end

-- status stuff

local enabled = false
local paused  = 0
local used    = false
local never   = false

-- get rid of overhead in mkiv

if tex.set_synctex_no_files then
    tex.set_synctex_no_files(1)
end

-- the file name stuff

local noftags            = 0
local stnums             = { }
local nofblocked         = 0
local blockedfilenames   = { }
local blockedsuffixes    = {
    mkii = true,
    mkiv = true,
    mkvi = true,
    mkxl = true,
    mklx = true,
    mkix = true,
    mkxi = true,
 -- lfg  = true,
}

local sttags = table.setmetatableindex(function(t,name)
    if blockedsuffixes[suffixonly(name)] then
        -- Just so that I don't get the ones on my development tree.
        nofblocked = nofblocked + 1
        return 0
    elseif blockedfilenames[nameonly(name)] then
        -- So we can block specific files.
        nofblocked = nofblocked + 1
        return 0
    elseif foundintree(name) then
        -- One shouldn't edit styles etc this way.
        nofblocked = nofblocked + 1
        return 0
    else
        noftags = noftags + 1
        t[name] = noftags
        stnums[noftags] = name
        return noftags
    end
end)

function synctex.blockfilename(name)
    blockedfilenames[nameonly(name)] = name
end

function synctex.setfilename(name,line)
    if paused == 0 and name then
        forcesynctextag(sttags[name])
        if line then
            forcesynctexline(line)
        end
    end
end

function synctex.resetfilename()
    if paused == 0 then
        forcesynctextag(0)
        forcesynctexline(0)
    end
end

do

    local nesting = 0
    local ignored = false

    function synctex.pushline()
        nesting = nesting + 1
        if nesting == 1 then
            local l = getsynctexline()
            ignored = l and l > 0
            if not ignored then
                forcesynctexline(texget("inputlineno"))
            end
        end
    end

    function synctex.popline()
        if nesting == 1 then
            if not ignored then
                forcesynctexline()
                ignored = false
            end
        end
        nesting = nesting - 1
    end

end

-- the node stuff

local filehandle = nil
local nofsheets  = 0
local nofobjects = 0
local last       = 0
local filesdone  = 0
local tmpfile    = false
local logfile    = false

local function writeanchor()
    local size = filehandle:seek("end")
    filehandle:write("!",size-last,eol)
    last = size
end

local function writefiles()
    local total = #stnums
    if filesdone < total then
        for i=filesdone+1,total do
            filehandle:write("Input:",i,":",stnums[i],eol)
        end
        filesdone = total
    end
end

local function makenames()
    logfile = replacesuffix(tex.jobname,"synctex")
    tmpfile = replacesuffix(logfile,"syncctx")
end

local function flushpreamble()
    makenames()
    filehandle = openfile(tmpfile,"wb")
    if filehandle then
        filehandle:write("SyncTeX Version:1",eol)
        writefiles()
        filehandle:write("Output:pdf",eol)
        filehandle:write("Magnification:1000",eol)
        filehandle:write("Unit:1",eol)
        filehandle:write("X Offset:0",eol)
        filehandle:write("Y Offset:0",eol)
        filehandle:write("Content:",eol)
        flushpreamble = function()
            writefiles()
            return filehandle
        end
    else
        enabled = false
    end
    return filehandle
end

function synctex.wrapup()
    if tmpfile then
        renamefile(tmpfile,logfile)
        tmpfile = nil
    end
end

local function flushpostamble()
    if not filehandle then
        return
    end
    writeanchor()
    filehandle:write("Postamble:",eol)
    filehandle:write("Count:",nofobjects,eol)
    writeanchor()
    filehandle:write("Post scriptum:",eol)
    filehandle:close()
    enabled = false
end

local getpagedimensions  getpagedimensions = function()
    getpagedimensions = backends.codeinjections.getpagedimensions
    return getpagedimensions()
end

-- local function doaction(action,t,l,w,h,d)
--     local pagewidth, pageheight = getpagedimensions()
--     local x, y = getpos()
--     filehandle:write(action(t,l,x,pageheight-y,w,h,d))
--     nofobjects = nofobjects + 1
-- end
--
-- local function noaction(action)
--     filehandle:write(action)
--     nofobjects = nofobjects + 1
-- end
--
-- local function b_vlist(head,current,t,l,w,h,d)
--     return insert_before(head,current,new_latelua(function() doaction(f_vlist,t,l,w,h,d) end))
-- end
--
-- local function b_hlist(head,current,t,l,w,h,d)
--     return insert_before(head,current,new_latelua(function() doaction(f_hlist,t,l,w,h,d) end))
-- end
--
-- local function e_vlist(head,current)
--     return insert_after(head,current,new_latelua(noaction(s_vlist)))
-- end
--
-- local function e_hlist(head,current)
--     return insert_after(head,current,new_latelua(noaction(s_hlist)))
-- end
--
-- local function x_vlist(head,current,t,l,w,h,d)
--     return insert_before(head,current,new_latelua(function() doaction(f_vlist_1,t,l,w,h,d) end))
-- end
--
-- local function x_hlist(head,current,t,l,w,h,d)
--     return insert_before(head,current,new_latelua(function() doaction(f_hlist_1,t,l,w,h,d) end))
-- end
--
-- generic
--
-- local function doaction(t,l,w,h,d)
--     local pagewidth, pageheight = getpagedimensions()
--     local x, y = getpos()
--     filehandle:write(f_hlist_1(t,l,x,pageheight-y,w,h,d))
--     nofobjects = nofobjects + 1
-- end

local x_hlist  do

    local function doaction_1(t,l,w,h,d)
        local pagewidth, pageheight = getpagedimensions()
        local x, y = getpos()
        filehandle:write(f_hlist_1(t,l,x,pageheight-y,w,h,d))
        nofobjects = nofobjects + 1
    end

    -- local lastx, lasty, lastw, lasth, lastd
    --
    -- local function doaction_2(t,l,w,h,d)
    --     local pagewidth, pageheight = getpagedimensions()
    --     local x, y = getpos()
    --     y = pageheight-y
    --     filehandle:write(f_hlist_2(t,l,
    --         x == lastx and "=" or x,
    --         y == lasty and "=" or y,
    --         w == lastw and "=" or w,
    --         h == lasth and "=" or h,
    --         d == lastd and "=" or d
    --     ))
    --     lastx, lasty, lastw, lasth, lastd = x, y, w, h, d
    --     nofobjects = nofobjects + 1
    -- end
    --
    -- but ... only y is supported:

    local lasty = false

    local function doaction_2(t,l,w,h,d)
        local pagewidth, pageheight = getpagedimensions()
        local x, y = getpos()
        y = pageheight - y
        filehandle:write(f_hlist_2(t,l,x,y == lasty and "=" or y,w,h,d))
        lasty = y
        nofobjects = nofobjects + 1
    end

    local doaction = doaction_1

    x_hlist = function(head,current,t,l,w,h,d)
        if filehandle then
            return insert_before(head,current,new_latelua(function() doaction(t,l,w,h,d) end))
        else
            return head
        end
    end

    directives.register("system.synctex.compression", function(v)
        doaction = tonumber(v) == 2 and doaction_2 or doaction_1
    end)

end

-- color is already handled so no colors

local collect     = nil
local fulltrace   = false
local trace       = false
local height      = 10 * 65536
local depth       =  5 * 65536
local traceheight =      32768
local tracedepth  =      32768

trackers.register("system.synctex.visualize", function(v)
    trace     = v
    fulltrace = v == "real"
end)

local function inject(head,first,last,tag,line)
    local w, h, d = getdimensions(first,getnext(last))
    if h < height then
        h = height
    end
    if d < depth then
        d = depth
    end
    if trace then
        head = insert_before(head,first,new_rule(w,fulltrace and h or traceheight,fulltrace and d or tracedepth))
        head = insert_before(head,first,new_kern(-w))
    end
    head = x_hlist(head,first,tag,line,w,h,d)
    return head
end

local function collect_min(head)
    local current = head
    while current do
        local id = getid(current)
        if id == glyph_code then
            local first = current
            local last  = current
            local tag   = 0
            local line  = 0
            while true do
                if id == glyph_code then
                    local tc, lc = getsynctexfields(current)
                    if tc and tc > 0 then
                        tag  = tc
                        line = lc
                    end
                    last = current
                elseif id == disc_code or (id == kern_code and getsubtype(current) == fontkern_code) then
                    last = current
                else
                    if tag > 0 then
                        head = inject(head,first,last,tag,line)
                    end
                    break
                end
                current = getnext(current)
                if current then
                    id = getid(current)
                else
                    if tag > 0 then
                        head = inject(head,first,last,tag,line)
                    end
                    return head
                end
            end
        end
        -- pick up (as id can have changed)
        if id == hlist_code or id == vlist_code then
            local list = getlist(current)
            if list then
                local l = collect(list)
                if l ~= list then
                    setlist(current,l)
                end
            end
        end
        current = getnext(current)
    end
    return head
end

local function inject(parent,head,first,last,tag,line)
    local w, h, d = getrangedimensions(parent,first,getnext(last))
    if h < height then
        h = height
    end
    if d < depth then
        d = depth
    end
    if trace then
        head = insert_before(head,first,new_rule(w,fulltrace and h or traceheight,fulltrace and d or tracedepth))
        head = insert_before(head,first,new_kern(-w))
    end
    head = x_hlist(head,first,tag,line,w,h,d)
    return head
end

local function collect_max(head,parent)
    local current = head
    while current do
        local id = getid(current)
        if id == glyph_code then
            local first = current
            local last  = current
            local tag   = 0
            local line  = 0
            while true do
                if id == glyph_code then
                    local tc, lc = getsynctexfields(current)
                    if tc and tc > 0 then
                        if tag > 0 and (tag ~= tc or line ~= lc) then
                            head  = inject(parent,head,first,last,tag,line)
                            first = current
                        end
                        tag  = tc
                        line = lc
                        last = current
                    else
                        if tag > 0 then
                            head = inject(parent,head,first,last,tag,line)
                            tag  = 0
                        end
                        first = nil
                        last  = nil
                    end
                elseif id == disc_code then
                    if not first then
                        first = current
                    end
                    last = current
                elseif id == kern_code and getsubtype(current) == fontkern_code then
                    if first then
                        last = current
                    end
                elseif id == glue_code then
                    if tag > 0 then
                        local tc, lc = getsynctexfields(current)
                        if tc and tc > 0 then
                            if tag ~= tc or line ~= lc then
                                head = inject(parent,head,first,last,tag,line)
                                tag  = 0
                                break
                            end
                        else
                            head = inject(parent,head,first,last,tag,line)
                            tag  = 0
                            break
                        end
                    else
                        tag = 0
                        break
                    end
                    id = nil -- so no test later on
                elseif id == penalty_code then
                    -- go on (and be nice for math)
                else
                    if tag > 0 then
                        head = inject(parent,head,first,last,tag,line)
                        tag  = 0
                    end
                    break
                end
                current = getnext(current)
                if current then
                    id = getid(current)

-- while id == dir_code do
--     current = getnext(current)
--     if current then
--         id = getid(current)
--     else
--         if tag > 0 then
--             head = inject(parent,head,first,last,tag,line)
--         end
--         return head
--     end
-- end

                else
                    if tag > 0 then
                        head = inject(parent,head,first,last,tag,line)
                    end
                    return head
                end
            end
        end
        -- pick up (as id can have changed)
        if id == hlist_code or id == vlist_code then
            local list = getlist(current)
            if list then
                local l = collect(list,current)
                if l and l ~= list then
                    setlist(current,l)
                end
            end
        end
        current = getnext(current)
    end
    return head
end

collect = collect_max

function synctex.collect(head,where)
    if enabled and where ~= "object" then
        return collect(head,head)
    else
        return head
    end
end

-- also no solution for bad first file resolving in sumatra

function synctex.start()
    if enabled then
        nofsheets = nofsheets + 1 -- could be realpageno
        if flushpreamble() then
            writeanchor()
            filehandle:write("{",nofsheets,eol)
            -- this seems to work:
            local pagewidth, pageheight = getpagedimensions()
            filehandle:write(z_hlist)
            filehandle:write(f_vlist_1(0,0,0,pageheight,pagewidth,pageheight,0))
        end
    end
end

function synctex.stop()
    if enabled then
     -- filehandle:write(s_vlist,s_hlist)
        filehandle:write(s_hlist)
        writeanchor()
        filehandle:write("}",nofsheets,eol)
        nofobjects = nofobjects + 2
    end
end

local enablers  = { }
local disablers = { }

function synctex.registerenabler(f)
    enablers[#enablers+1] = f
end

function synctex.registerdisabler(f)
    disablers[#disablers+1] = f
end

function synctex.enable()
    if not never and not enabled then
        enabled = true
        setsynctexmode(3) -- we want details
        if not used then
            nodes.tasks.enableaction("shipouts","luatex.synctex.collect")
            report_system("synctex functionality is enabled, expect 5-10 pct runtime overhead!")
            used = true
        end
        for i=1,#enablers do
            enablers[i](true)
        end
    end
end

function synctex.disable()
    if enabled then
        setsynctexmode(0)
        report_system("synctex functionality is disabled!")
        enabled = false
        for i=1,#disablers do
            disablers[i](false)
        end
    end
end

function synctex.finish()
    if enabled then
        flushpostamble()
    else
        makenames()
        removefile(logfile)
        removefile(tmpfile)
    end
end

local filename = nil

function synctex.pause()
    paused = paused + 1
    if enabled and paused == 1 then
        setsynctexmode(0)
    end
end

function synctex.resume()
    if enabled and paused == 1 then
        setsynctexmode(3)
    end
    paused = paused - 1
end

-- not the best place

luatex.registerstopactions(synctex.finish)

statistics.register("synctex tracing",function()
    if used then
        return string.format("%i referenced files, %i files ignored, %i objects flushed, logfile: %s",
            noftags,nofblocked,nofobjects,logfile)
    end
end)

local implement = interfaces.implement
local variables = interfaces.variables

function synctex.setup(t)
    if t.state == variables.never then
        synctex.disable() -- just in case
        never = true
        return
    end
    if t.method == variables.max then
        collect = collect_max
    else
        collect = collect_min
    end
    if t.state == variables.start then
        synctex.enable()
    else
        synctex.disable()
    end
end

implement {
    name      = "synctexblockfilename",
    arguments = "string",
    actions   = synctex.blockfilename,
}

implement {
    name      = "synctexsetfilename",
    arguments = "string",
    actions   = synctex.setfilename,
}

implement {
    name      = "synctexresetfilename",
    actions   = synctex.resetfilename,
}

implement {
    name      = "setupsynctex",
    actions   = synctex.setup,
    arguments = {
        {
            { "state" },
            { "method" },
        },
    },
}

implement {
    name    = "synctexpause",
    actions = synctex.pause,
}

implement {
    name    = "synctexresume",
    actions = synctex.resume,
}

interfaces.implement {
    name    = "synctexpushline",
    actions = synctex.pushline,
}
interfaces.implement {
    name    = "synctexpopline",
    actions = synctex.popline,
}

implement {
    name    = "synctexdisable",
    actions = synctex.disable,
}
