if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, match, rep = string.format, string.find, string.match, string.rep
local tonumber = tonumber
local S, lpegmatch, lpegtsplitat = lpeg.S, lpeg.match, lpeg.tsplitat

commands       = commands or { }
local commands = commands

local context  = context
local csprint  = context.sprint

local prtcatcodes = tex.prtcatcodes

function commands.writestatus(...) logs.status(...) end -- overloaded later

local ctx_firstoftwoarguments  = context.firstoftwoarguments  -- context.constructcsonly("firstoftwoarguments" )
local ctx_secondoftwoarguments = context.secondoftwoarguments -- context.constructcsonly("secondoftwoarguments")
local ctx_firstofoneargument   = context.firstofoneargument   -- context.constructcsonly("firstofoneargument"  )
local ctx_gobbleoneargument    = context.gobbleoneargument    -- context.constructcsonly("gobbleoneargument"   )

-- contextsprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
-- contextsprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
-- contextsprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
-- contextsprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments

function commands.doifelse(b)
    if b then
        ctx_firstoftwoarguments()
-- csprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
    else
        ctx_secondoftwoarguments()
-- csprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments
    end
end

function commands.doifelsesomething(b)
    if b and b ~= "" then
        ctx_firstoftwoarguments()
-- csprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
    else
        ctx_secondoftwoarguments()
-- csprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments
    end
end

function commands.doif(b)
    if b then
        ctx_firstofoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    else
        ctx_gobbleoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    end
end

function commands.doifsomething(b)
    if b and b ~= "" then
        ctx_firstofoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    else
        ctx_gobbleoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    end
end

function commands.doifnot(b)
    if b then
        ctx_gobbleoneargument()
-- csprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    else
        ctx_firstofoneargument()
-- csprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    end
end

function commands.doifnotthing(b)
    if b and b ~= "" then
        ctx_gobbleoneargument()
-- csprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    else
        ctx_firstofoneargument()
-- csprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    end
end

commands.testcase = commands.doifelse -- obsolete

function commands.boolcase(b)
    context(b and 1 or 0)
end

function commands.doifelsespaces(str)
    if find(str,"^ +$") then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

local s = lpegtsplitat(",")
local h = { }

function commands.doifcommonelse(a,b) -- often the same test
    local ha = h[a]
    local hb = h[b]
    if not ha then
        ha = lpegmatch(s,a)
        h[a] = ha
    end
    if not hb then
        hb = lpegmatch(s,b)
        h[b] = hb
    end
    local na = #ha
    local nb = #hb
    for i=1,na do
        for j=1,nb do
            if ha[i] == hb[j] then
                ctx_firstoftwoarguments()
                return
            end
        end
    end
    ctx_secondoftwoarguments()
end

function commands.doifinsetelse(a,b)
    local hb = h[b]
    if not hb then hb = lpegmatch(s,b) h[b] = hb end
    for i=1,#hb do
        if a == hb[i] then
            ctx_firstoftwoarguments()
            return
        end
    end
    ctx_secondoftwoarguments()
end

local pattern = lpeg.patterns.validdimen

function commands.doifdimenstringelse(str)
    if lpegmatch(pattern,str) then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

function commands.firstinset(str)
    local first = match(str,"^([^,]+),")
    context(first or str)
end

function commands.ntimes(str,n)
    context(rep(str,n or 1))
end

function commands.execute(str)
    os.execute(str) -- wrapped in sandbox
end

-- function commands.write(n,str)
--     if n == 18 then
--         os.execute(str)
--     elseif n == 16 then
--         -- immediate
--         logs.report(str)
--     else
--         -- at the tex end we can still drop the write / also delayed vs immediate
--         context.writeviatex(n,str)
--     end
-- end
