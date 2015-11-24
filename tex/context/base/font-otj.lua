if not modules then modules = { } end modules ['font-otj'] = {
    version   = 1.001,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This property based variant is not faster but looks nicer than the attribute one. We
-- need to use rawget (which is apbout 4 times slower than a direct access but we cannot
-- get/set that one for our purpose! This version does a bit more with discretionaries
-- (and Kai has tested it with his collection of weird fonts.)

-- There is some duplicate code here (especially in the the pre/post/replace branches) but
-- we go for speed. We could store a list of glyph and mark nodes when registering but it's
-- cleaner to have an identification pass here. Also, I need to keep tracing in mind so
-- being too clever here is dangerous.

-- The subtype test is not needed as there will be no (new) properties set, given that we
-- reset the properties.

if not nodes.properties then return end

local next, rawget = next, rawget
local utfchar = utf.char
local fastcopy = table.fastcopy

local trace_injections = false  trackers.register("fonts.injections", function(v) trace_injections = v end)

local report_injections = logs.reporter("fonts","injections")

local attributes, nodes, node = attributes, nodes, node

fonts                    = fonts
local fontdata           = fonts.hashes.identifiers

nodes.injections         = nodes.injections or { }
local injections         = nodes.injections

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern

local nuts               = nodes.nuts
local nodepool           = nuts.pool

local newkern            = nodepool.kern

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar

local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc

local traverse_id        = nuts.traverse_id
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local find_tail          = nuts.tail

local properties         = nodes.properties.data

function injections.installnewkern(nk)
    newkern = nk or newkern
end

local nofregisteredkerns    = 0
local nofregisteredpairs    = 0
local nofregisteredmarks    = 0
local nofregisteredcursives = 0
local keepregisteredcounts  = false

function injections.keepcounts()
    keepregisteredcounts = true
end

function injections.resetcounts()
    nofregisteredkerns    = 0
    nofregisteredpairs    = 0
    nofregisteredmarks    = 0
    nofregisteredcursives = 0
    keepregisteredcounts  = false
end

-- We need to make sure that a possible metatable will not kick in unexpectedly.

function injections.reset(n)
    local p = rawget(properties,n)
    if p and rawget(p,"injections") then
        p.injections = nil
    end
end

function injections.copy(target,source)
    local sp = rawget(properties,source)
    if sp then
        local tp = rawget(properties,target)
        local si = rawget(sp,"injections")
        if si then
            si = fastcopy(si)
            if tp then
                tp.injections = si
            else
                propertydata[target] = {
                    injections = si,
                }
            end
        else
            if tp then
                tp.injections = nil
            end
        end
    end
end

function injections.setligaindex(n,index)
    local p = rawget(properties,n)
    if p then
        local i = rawget(p,"injections")
        if i then
            i.ligaindex = index
        else
            p.injections = {
                ligaindex = index
            }
        end
    else
        properties[n] = {
            injections = {
                ligaindex = index
            }
        }
    end
end

function injections.getligaindex(n,default)
    local p = rawget(properties,n)
    if p then
        local i = rawget(p,"injections")
        if i then
            return i.ligaindex or default
        end
    end
    return default
end

function injections.setcursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext) -- hm: nuts or nodes
    local dx =  factor*(exit[1]-entry[1])
    local dy = -factor*(exit[2]-entry[2])
    local ws = tfmstart.width
    local wn = tfmnext.width
    nofregisteredcursives = nofregisteredcursives + 1
    if rlmode < 0 then
        dx = -(dx + wn)
    else
        dx = dx - ws
    end
    --
    local p = rawget(properties,start)
    if p then
        local i = rawget(p,"injections")
        if i then
            i.cursiveanchor = true
        else
            p.injections = {
                cursiveanchor = true,
            }
        end
    else
        properties[start] = {
            injections = {
                cursiveanchor = true,
            },
        }
    end
    local p = rawget(properties,nxt)
    if p then
        local i = rawget(p,"injections")
        if i then
            i.cursivex = dx
            i.cursivey = dy
        else
            p.injections = {
                cursivex = dx,
                cursivey = dy,
            }
        end
    else
        properties[nxt] = {
            injections = {
                cursivex = dx,
                cursivey = dy,
            },
        }
    end
    return dx, dy, nofregisteredcursives
end

function injections.setpair(current,factor,rlmode,r2lflag,spec,injection) -- r2lflag & tfmchr not used
    local x = factor*spec[1]
    local y = factor*spec[2]
    local w = factor*spec[3]
    local h = factor*spec[4]
    if x ~= 0 or w ~= 0 or y ~= 0 or h ~= 0 then -- okay?
        local yoffset   = y - h
        local leftkern  = x      -- both kerns are set in a pair kern compared
        local rightkern = w - x  -- to normal kerns where we set only leftkern
        if leftkern ~= 0 or rightkern ~= 0 or yoffset ~= 0 then
            nofregisteredpairs = nofregisteredpairs + 1
            if rlmode and rlmode < 0 then
                leftkern, rightkern = rightkern, leftkern
            end
            if not injection then
                injection = "injections"
            end
            local p = rawget(properties,current)
            if p then
                local i = rawget(p,injection)
                if i then
                    if leftkern ~= 0 then
                        i.leftkern  = (i.leftkern  or 0) + leftkern
                    end
                    if rightkern ~= 0 then
                        i.rightkern = (i.rightkern or 0) + rightkern
                    end
                    if yoffset ~= 0 then
                        i.yoffset = (i.yoffset or 0) + yoffset
                    end
                elseif leftkern ~= 0 or rightkern ~= 0 then
                    p[injection] = {
                        leftkern  = leftkern,
                        rightkern = rightkern,
                        yoffset   = yoffset,
                    }
                else
                    p[injection] = {
                        yoffset = yoffset,
                    }
                end
            elseif leftkern ~= 0 or rightkern ~= 0 then
                properties[current] = {
                    [injection] = {
                        leftkern  = leftkern,
                        rightkern = rightkern,
                        yoffset   = yoffset,
                    },
                }
            else
                properties[current] = {
                    [injection] = {
                        yoffset = yoffset,
                    },
                }
            end
            return x, y, w, h, nofregisteredpairs
         end
    end
    return x, y, w, h -- no bound
end

-- This needs checking for rl < 0 but it is unlikely that a r2l script uses kernclasses between
-- glyphs so we're probably safe (KE has a problematic font where marks interfere with rl < 0 in
-- the previous case)

function injections.setkern(current,factor,rlmode,x,injection)
    local dx = factor * x
    if dx ~= 0 then
        nofregisteredkerns = nofregisteredkerns + 1
        local p = rawget(properties,current)
        if not injection then
            injection = "injections"
        end
        if p then
            local i = rawget(p,injection)
            if i then
                i.leftkern = dx + (i.leftkern or 0)
            else
                p[injection] = {
                    leftkern = dx,
                }
            end
        else
            properties[current] = {
                [injection] = {
                    leftkern = dx,
                },
            }
        end
        return dx, nofregisteredkerns
    else
        return 0, 0
    end
end

function injections.setmark(start,base,factor,rlmode,ba,ma,tfmbase,mkmk) -- ba=baseanchor, ma=markanchor
    local dx, dy = factor*(ba[1]-ma[1]), factor*(ba[2]-ma[2])
    nofregisteredmarks = nofregisteredmarks + 1
 -- markanchors[nofregisteredmarks] = base
    if rlmode >= 0 then
        dx = tfmbase.width - dx -- see later commented ox
    end
    local p = rawget(properties,start)
    -- hm, dejavu serif does a sloppy mark2mark before mark2base
    if p then
        local i = rawget(p,"injections")
        if i then
            if i.markmark then
                -- out of order mkmk: yes or no or option
            else
                i.markx        = dx
                i.marky        = dy
                i.markdir      = rlmode or 0
                i.markbase     = nofregisteredmarks
                i.markbasenode = base
                i.markmark     = mkmk
            end
        else
            p.injections = {
                markx        = dx,
                marky        = dy,
                markdir      = rlmode or 0,
                markbase     = nofregisteredmarks,
                markbasenode = base,
                markmark     = mkmk,
            }
        end
    else
        properties[start] = {
            injections = {
                markx        = dx,
                marky        = dy,
                markdir      = rlmode or 0,
                markbase     = nofregisteredmarks,
                markbasenode = base,
                markmark     = mkmk,
            },
        }
    end
    return dx, dy, nofregisteredmarks
end

local function dir(n)
    return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or "unset"
end

local function showchar(n,nested)
    local char = getchar(n)
    report_injections("%wfont %s, char %U, glyph %c",nested and 2 or 0,getfont(n),char,char)
end

local function show(n,what,nested,symbol)
    if n then
        local p = rawget(properties,n)
        if p then
            local i = rawget(p,what)
            if i then
                local leftkern  = i.leftkern  or 0
                local rightkern = i.rightkern or 0
                local yoffset   = i.yoffset   or 0
                local markx     = i.markx     or 0
                local marky     = i.marky     or 0
                local markdir   = i.markdir   or 0
                local markbase  = i.markbase  or 0 -- will be markbasenode
                local cursivex  = i.cursivex  or 0
                local cursivey  = i.cursivey  or 0
                local ligaindex = i.ligaindex or 0
                local margin    = nested and 4 or 2
                --
                if rightkern ~= 0 or yoffset ~= 0 then
                    report_injections("%w%s pair: lx %p, rx %p, dy %p",margin,symbol,leftkern,rightkern,yoffset)
                elseif leftkern ~= 0 then
                    report_injections("%w%s kern: dx %p",margin,symbol,leftkern)
                end
                if markx ~= 0 or marky ~= 0 or markbase ~= 0 then
                    report_injections("%w%s mark: dx %p, dy %p, dir %s, base %s",margin,symbol,markx,marky,markdir,markbase ~= 0 and "yes" or "no")
                end
                if cursivex ~= 0 or cursivey ~= 0 then
                    report_injections("%w%s curs: dx %p, dy %p",margin,symbol,cursivex,cursivey)
                end
                if ligaindex ~= 0 then
                    report_injections("%w%s liga: index %i",margin,symbol,ligaindex)
                end
            end
        end
    end
end

local function showsub(n,what,where)
    report_injections("begin subrun: %s",where)
    for n in traverse_id(glyph_code,n) do
        showchar(n,where)
        show(n,what,where," ")
    end
    report_injections("end subrun")
end

local function trace(head,where)
    report_injections("begin run %s: %s kerns, %s pairs, %s marks and %s cursives registered",
        where or "",nofregisteredkerns,nofregisteredpairs,nofregisteredmarks,nofregisteredcursives)
    local n = head
    while n do
        local id = getid(n)
        if id == glyph_code then
            showchar(n)
            show(n,"injections",false," ")
            show(n,"preinjections",false,"<")
            show(n,"postinjections",false,">")
            show(n,"replaceinjections",false,"=")
            show(n,"emptyinjections",false,"*")
        elseif id == disc_code then
            local pre, post, replace = getdisc(n)
            if pre then
                showsub(pre,"preinjections","pre")
            end
            if post then
                showsub(post,"postinjections","post")
            end
            if replace then
                showsub(replace,"replaceinjections","replace")
            end
            show(n,"emptyinjections",false,"*")
        end
        n = getnext(n)
    end
    report_injections("end run")
end

local function show_result(head)
    local current  = head
    local skipping = false
    while current do
        local id = getid(current)
        if id == glyph_code then
            report_injections("char: %C, width %p, xoffset %p, yoffset %p",
                getchar(current),getfield(current,"width"),getfield(current,"xoffset"),getfield(current,"yoffset"))
            skipping = false
        elseif id == kern_code then
            report_injections("kern: %p",getfield(current,"kern"))
            skipping = false
        elseif not skipping then
            report_injections()
            skipping = true
        end
        current = getnext(current)
    end
end

-- G  +D-pre        G
--     D-post+
--    +D-replace+
--
-- G  +D-pre       +D-pre
--     D-post      +D-post
--    +D-replace   +D-replace

local function inject_kerns_only(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"kerns")
    end
    local current   = head
    local prev      = nil
    local next      = nil
    local prevdisc  = nil
    local prevglyph = nil
    local pre       = nil -- saves a lookup
    local post      = nil -- saves a lookup
    local replace   = nil -- saves a lookup
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                    local i = rawget(p,"injections")
                    if i then
                        -- left|glyph|right
                        local leftkern = i.leftkern
                        if leftkern and leftkern ~= 0 then
                            insert_node_before(head,current,newkern(leftkern))
                        end
                    end
                    if prevdisc then
                        local done = false
                        if post then
                            local i = rawget(p,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local posttail = find_tail(post)
                                    insert_node_after(post,posttail,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                        if replace then
                            local i = rawget(p,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local replacetail = find_tail(replace)
                                    insert_node_after(replace,replacetail,newkern(leftkern))
                                    done = true
                                end
                            end
                        else
-- local i = rawget(p,"emptyinjections")
-- if i then
-- inspect(i)
--     local leftkern = i.leftkern
--     if leftkern and leftkern ~= 0 then
--         replace = newkern(leftkern)
--         done = true
--     end
-- end
                        end
                        if done then
                            setdisc(prevdisc,pre,post,replace)
                        end
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace = getdisc(current)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_id(glyph_code,pre) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"preinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    pre  = insert_node_before(pre,n,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_id(glyph_code,post) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    post = insert_node_before(post,n,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_id(glyph_code,replace) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    replace = insert_node_before(replace,n,newkern(leftkern))
                                    done    = true
                                end
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post,replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts = false
    else
        nofregisteredkerns   = 0
    end
    return tonode(head), true
end

local function inject_pairs_only(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"pairs")
    end
    local current   = head
    local prev      = nil
    local next      = nil
    local prevdisc  = nil
    local prevglyph = nil
    local pre       = nil -- saves a lookup
    local post      = nil -- saves a lookup
    local replace   = nil -- saves a lookup
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                    local i = rawget(p,"injections")
                    if i then
                        -- left|glyph|right
                        local yoffset = i.yoffset
                        if yoffset and yoffset ~= 0 then
                            setfield(current,"yoffset",yoffset)
                        end
                        local leftkern = i.leftkern
                        if leftkern and leftkern ~= 0 then
                            insert_node_before(head,current,newkern(leftkern))
                        end
                        local rightkern = i.rightkern
                        if rightkern and rightkern ~= 0 then
                            insert_node_after(head,current,newkern(rightkern))
                        end
                    else
                        local i = rawget(p,"emptyinjections")
                        if i then
                            -- glyph|disc|glyph (special case)
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                if next and getid(next) == disc_code then
                                    local replace = getfield(next,"replace")
                                    if replace then
                                        -- error, we expect an empty one
                                    else
                                        setfield(next,"replace",newkern(rightkern)) -- maybe also leftkern
                                    end
                                end
                            end
                        end
                    end
                    if prevdisc and p then
                        local done = false
                        if post then
                            local i = rawget(p,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local posttail = find_tail(post)
                                    insert_node_after(post,posttail,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                        if replace then
                            local i = rawget(p,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local replacetail = find_tail(replace)
                                    insert_node_after(replace,replacetail,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                        if done then
                            setdisc(prevdisc,pre,post,replace)
                        end
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace = getdisc(current)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_id(glyph_code,pre) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"preinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    pre  = insert_node_before(pre,n,newkern(leftkern))
                                    done = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(pre,n,newkern(rightkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_id(glyph_code,post) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"postinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    post = insert_node_before(post,n,newkern(leftkern))
                                    done = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(post,n,newkern(rightkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_id(glyph_code,replace) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    replace = insert_node_before(replace,n,newkern(leftkern))
                                    done    = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(replace,n,newkern(rightkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if prevglyph then
                if pre then
                    local p = rawget(properties,prevglyph)
                    if p then
                        local i = rawget(p,"preinjections")
                        if i then
                            -- glyph|pre glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                pre  = insert_node_before(pre,pre,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
                if replace then
                    local p = rawget(properties,prevglyph)
                    if p then
                        local i = rawget(p,"replaceinjections")
                        if i then
                            -- glyph|replace glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                replace = insert_node_before(replace,replace,newkern(rightkern))
                                done    = true
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post,replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts = false
    else
        nofregisteredkerns   = 0
    end
    return tonode(head), true
end

local function inject_everything(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"everything")
    end
    local hascursives = nofregisteredcursives > 0
    local hasmarks    = nofregisteredmarks    > 0
    --
    local current   = head
    local prev      = nil
    local next      = nil
    local prevdisc  = nil
    local prevglyph = nil
    local pre       = nil -- saves a lookup
    local post      = nil -- saves a lookup
    local replace   = nil -- saves a lookup
    --
    local cursiveanchor = nil
    local lastanchor    = nil
    local minc          = 0
    local maxc          = 0
    local last          = 0
    local glyphs        = { }
    --
    local function processmark(p,n,pn) -- p = basenode
        local px = getfield(p,"xoffset")
        local ox = 0
        local rightkern = nil
        local pp = rawget(properties,p)
        if pp then
            pp = rawget(pp,"injections")
            if pp then
                rightkern = pp.rightkern
            end
        end
        if rightkern then -- x and w ~= 0
            if pn.markdir < 0 then
                -- kern(w-x) glyph(p) kern(x) mark(n)
                ox = px - pn.markx - rightkern
             -- report_injections("r2l case 1: %p",ox)
            else
                -- kern(x) glyph(p) kern(w-x) mark(n)
             -- ox = px - getfield(p,"width") + pn.markx - pp.leftkern
                --
                -- According to Kai we don't need to handle leftkern here but I'm
                -- pretty sure I've run into a case where it was needed so maybe
                -- some day we need something more clever here.
                --
                if false then
                    -- a mark with kerning
                    local leftkern = pp.leftkern
                    if leftkern then
                        ox = px - pn.markx - leftkern
                    else
                        ox = px - pn.markx
                    end
                else
                    ox = px - pn.markx
                end
            end
        else
            -- we need to deal with fonts that have marks with width
         -- if pn.markdir < 0 then
         --     ox = px - pn.markx
         --  -- report_injections("r2l case 3: %p",ox)
         -- else
         --  -- ox = px - getfield(p,"width") + pn.markx
                ox = px - pn.markx
             -- report_injections("l2r case 3: %p",ox)
         -- end
            local wn = getfield(n,"width") -- in arial marks have widths
            if wn ~= 0 then
                -- bad: we should center
             -- insert_node_before(head,n,newkern(-wn/2))
             -- insert_node_after(head,n,newkern(-wn/2))
                pn.leftkern  = -wn/2
                pn.rightkern = -wn/2
             -- wx[n] = { 0, -wn/2, 0, -wn }
            end
            -- so far
        end
        setfield(n,"xoffset",ox)
        --
        local py = getfield(p,"yoffset")
     -- local oy = 0
     -- if marks[p] then
     --     oy = py + pn.marky
     -- else
     --     oy = getfield(n,"yoffset") + py + pn.marky
     -- end
        local oy = getfield(n,"yoffset") + py + pn.marky
        setfield(n,"yoffset",oy)
    end
    --
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                    local i = rawget(p,"injections")
                    if i then
                        -- cursives
                        if hascursives then
                            local cursivex = p.cursivex
                            if cursivex then
                                if cursiveanchor then
                                    if cursivex ~= 0 then
                                        p.leftkern = (p.leftkern or 0) + cursivex
                                    end
                                    if lastanchor then
                                        if maxc == 0 then
                                            minc = 1
                                            maxc = 1
                                            glyphs[1] = lastanchor
                                        else
                                            maxc = maxc + 1
                                            glyphs[maxc] = lastanchor
                                        end
                                        properties[cursiveanchor].cursivedy = p.cursivey
                                    end
                                    last = n
                                else
                                    maxc = 0
                                end
                            elseif maxc > 0 then
                                local ny = getfield(n,"yoffset")
                                for i=maxc,minc,-1 do
                                    local ti = glyphs[i]
                                    ny = ny + properties[ti].cursivedy
                                    setfield(ti,"yoffset",ny) -- why not add ?
                                end
                                maxc = 0
                            end
                            if p.cursiveanchor then
                                cursiveanchor = current -- no need for both now
                                lastanchor    = current
                            else
                                cursiveanchor = nil
                                lastanchor    = nil
                                if maxc > 0 then
                                    local ny = getfield(n,"yoffset")
                                    for i=maxc,minc,-1 do
                                        local ti = glyphs[i]
                                        ny = ny + properties[ti].cursivedy
                                        setfield(ti,"yoffset",ny) -- why not add ?
                                    end
                                    maxc = 0
                                end
                            end
                        end
                        -- marks
                        if hasmarks then
                            local pm = i.markbasenode
                            if pm then
                                processmark(pm,current,i)
                            end
                        end
                        -- left|glyph|right
                        local yoffset = i.yoffset
                        if yoffset and yoffset ~= 0 then
                            setfield(current,"yoffset",yoffset)
                        end
                        local leftkern = i.leftkern
                        if leftkern and leftkern ~= 0 then
                            insert_node_before(head,current,newkern(leftkern))
                        end
                        local rightkern = i.rightkern
                        if rightkern and rightkern ~= 0 then
                            insert_node_after(head,current,newkern(rightkern))
                        end
                    else
                        local i = rawget(p,"emptyinjections")
                        if i then
                            -- glyph|disc|glyph (special case)
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                if next and getid(next) == disc_code then
                                    local replace = getfield(next,"replace")
                                    if replace then
                                        -- error, we expect an empty one
                                    else
                                        setfield(next,"replace",newkern(rightkern)) -- maybe also leftkern
                                    end
                                end
                            end
                        end
                    end
                    if prevdisc then
                        if p then
                            local done = false
                            if post then
                                local i = rawget(p,"postinjections")
                                if i then
                                    local leftkern = i.leftkern
                                    if leftkern and leftkern ~= 0 then
                                        local posttail = find_tail(post)
                                        insert_node_after(post,posttail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            end
                            if replace then
                                local i = rawget(p,"replaceinjections")
                                if i then
                                    local leftkern = i.leftkern
                                    if leftkern and leftkern ~= 0 then
                                        local replacetail = find_tail(replace)
                                        insert_node_after(replace,replacetail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            end
                            if done then
                                setdisc(prevdisc,pre,post,replace)
                            end
                        end
                    end
                else
                    -- cursive
                    if hascursives and maxc > 0 then
                        local ny = getfield(current,"yoffset")
                        for i=maxc,minc,-1 do
                            local ti = glyphs[i]
                            ny = ny + properties[ti].cursivedy
                            setfield(ti,"yoffset",getfield(ti,"yoffset") + ny) -- ?
                        end
                        maxc = 0
                        cursiveanchor = nil
                        lastanchor = nil
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace = getdisc(current)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_id(glyph_code,pre) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"preinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    pre  = insert_node_before(pre,n,newkern(leftkern))
                                    done = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(pre,n,newkern(rightkern))
                                    done = true
                                end
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_id(glyph_code,post) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"postinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    post = insert_node_before(post,n,newkern(leftkern))
                                    done = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(post,n,newkern(rightkern))
                                    done = true
                                end
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_id(glyph_code,replace) do
                    if getsubtype(n) < 256 then
                        local p = rawget(properties,n)
                        if p then
                            local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                            if i then
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    replace = insert_node_before(replace,n,newkern(leftkern))
                                    done    = true
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(replace,n,newkern(rightkern))
                                    done = true
                                end
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if prevglyph then
                if pre then
                    local p = rawget(properties,prevglyph)
                    if p then
                        local i = rawget(p,"preinjections")
                        if i then
                            -- glyph|pre glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                pre  = insert_node_before(pre,pre,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
                if replace then
                    local p = rawget(properties,prevglyph)
                    if p then
                        local i = rawget(p,"replaceinjections")
                        if i then
                            -- glyph|replace glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                replace = insert_node_before(replace,replace,newkern(rightkern))
                                done    = true
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post.replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    -- cursive
    if hascursives then
        if last and maxc > 0 then
            local ny = getfield(last,"yoffset")
            for i=maxc,minc,-1 do
                local ti = glyphs[i]
                ny = ny + properties[ti].cursivedy
                setfield(ti,"yoffset",ny) -- why not add ?
            end
        end
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts  = false
    else
        nofregisteredkerns    = 0
        nofregisteredpairs    = 0
        nofregisteredmarks    = 0
        nofregisteredcursives = 0
    end
    return tonode(head), true
end

function injections.handler(head,where)
    if nofregisteredmarks > 0 or nofregisteredcursives > 0 then
        return inject_everything(head,where)
    elseif nofregisteredpairs > 0 then
        return inject_pairs_only(head,where)
    elseif nofregisteredkerns > 0 then
        return inject_kerns_only(head,where)
    else
        return head, false
    end
end