if not modules then modules = { } end modules ['lpdf-fld'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The problem with widgets is that so far each version of acrobat
-- has some rendering problem. I tried to keep up with this but
-- it makes no sense to do so as one cannot rely on the viewer
-- not changing. Especially Btn fields are tricky as their appearences
-- need to be synchronized in the case of children but e.g. acrobat
-- 10 does not retain the state and forces a check symbol. If you
-- make a file in acrobat then it has MK entries that seem to overload
-- the already present appearance streams (they're probably only meant for
-- printing) as it looks like the viewer has some fallback on (auto
-- generated) MK behaviour built in. So ... hard to test. Unfortunately
-- not even the default appearance is generated. This will probably be
-- solved at some point.

local gmatch, lower, format = string.gmatch, string.lower, string.format
local lpegmatch = lpeg.match
local utfchar = utf.char
local bpfactor, todimen = number.dimenfactors.bp, string.todimen

local trace_fields = false  trackers.register("backends.fields", function(v) trace_fields = v end)

local report_fields = logs.reporter("backend","fields")

local backends, lpdf = backends, lpdf

local variables               = interfaces.variables
local context                 = context

local references              = structures.references
local settings_to_array       = utilities.parsers.settings_to_array

local pdfbackend              = backends.pdf

local nodeinjections          = pdfbackend.nodeinjections
local codeinjections          = pdfbackend.codeinjections
local registrations           = pdfbackend.registrations

local registeredsymbol        = codeinjections.registeredsymbol

local pdfstream               = lpdf.stream
local pdfdictionary           = lpdf.dictionary
local pdfarray                = lpdf.array
local pdfreference            = lpdf.reference
local pdfunicode              = lpdf.unicode
local pdfstring               = lpdf.string
local pdfconstant             = lpdf.constant
local pdftoeight              = lpdf.toeight
local pdfflushobject          = lpdf.flushobject
local pdfimmediateobject      = lpdf.immediateobject
local pdfshareobjectreference = lpdf.shareobjectreference
local pdfshareobject          = lpdf.shareobject
local pdfreserveobject        = lpdf.reserveobject
local pdfreserveannotation    = lpdf.reserveannotation
local pdfaction               = lpdf.action

local hpack_node              = node.hpack

local nodepool                = nodes.pool

local pdfannotation_node      = nodepool.pdfannotation

local submitoutputformat      = 0 --  0=unknown 1=HTML 2=FDF 3=XML   => not yet used, needs to be checked

local pdf_widget              = pdfconstant("Widget")
local pdf_tx                  = pdfconstant("Tx")
local pdf_ch                  = pdfconstant("Ch")
local pdf_btn                 = pdfconstant("Btn")
local pdf_yes                 = pdfconstant("Yes")
local pdf_off                 = pdfconstant("Off")
local pdf_p                   = pdfconstant("P") -- None Invert Outline Push
local pdf_n                   = pdfconstant("N") -- None Invert Outline Push
--
local pdf_no_rect             = pdfarray { 0, 0, 0, 0 }

local splitter = lpeg.splitat("=>")

local formats = {
    html = 1, fdf = 2, xml = 3,
}

function codeinjections.setformsmethod(name)
    submitoutputformat = formats[lower(name)] or formats.xml
end

local flag = {
    MultiLine       =     4096, --  13
    NoToggleToOff   =    16384, --  15
    Radio           =    32768, --  16
    PushButton      =    65536, --  17
    PopUp           =   131072, --  18
    Edit            =   262144, --  19
    RadiosInUnison  = 33554432, --  26
    DoNotSpellCheck =  4194304, --  23
    DoNotScroll     =  8388608, --  24
    ReadOnly        =        1, --   1
    Required        =        2, --   2
    NoExport        =        4, --   3
    Password        =     8192, --  14
    Sort            =   524288, --  20
    FileSelect      =  1048576, --  21
}

local plus = {
    Invisible       =        1, --   1
    Hidden          =        2, --   2
    Printable       =        4, --   3
    NoView          =       32, --   6
    ToggleNoView    =      256, --   9
    AutoView        =      256, -- 288 (6+9)
}

-- todo: check what is interfaced

flag.readonly    = flag.ReadOnly
flag.required    = flag.Required
flag.protected   = flag.Password
flag.sorted      = flag.Sort
flag.unavailable = flag.NoExport
flag.nocheck     = flag.DoNotSpellCheck
flag.fixed       = flag.DoNotScroll
flag.file        = flag.FileSelect

plus.hidden      = plus.Hidden
plus.printable   = plus.Printable
plus.auto        = plus.AutoView

-- some day .. lpeg with function or table

local function fieldflag(specification)
    local o, n = specification.option, 0
    if o and o ~= "" then
        for f in gmatch(o,"[^, ]+") do
            n = n + (flag[f] or 0)
        end
    end
    return n
end

local function fieldplus(specification)
    local o, n = specification.option, 0
    if o and o ~= "" then
        for p in gmatch(o,"[^, ]+") do
            n = n + (plus[p] or 0)
        end
    end
    return n
end

local function checked(what)
    local set, bug = references.identify("",what)
    if not bug and #set > 0 then
        local r, n = pdfaction(set)
        return pdfshareobjectreference(r)
    end
end

local function fieldactions(specification) -- share actions
    local d, a = { }, nil
    a = specification.mousedown
     or specification.clickin           if a and a ~= "" then d.D  = checked(a) end
    a = specification.mouseup
     or specification.clickout          if a and a ~= "" then d.U  = checked(a) end
    a = specification.regionin          if a and a ~= "" then d.E  = checked(a) end -- Enter
    a = specification.regionout         if a and a ~= "" then d.X  = checked(a) end -- eXit
    a = specification.afterkey          if a and a ~= "" then d.K  = checked(a) end
    a = specification.format            if a and a ~= "" then d.F  = checked(a) end
    a = specification.validate          if a and a ~= "" then d.V  = checked(a) end
    a = specification.calculate         if a and a ~= "" then d.C  = checked(a) end
    a = specification.focusin           if a and a ~= "" then d.Fo = checked(a) end
    a = specification.focusout          if a and a ~= "" then d.Bl = checked(a) end
    a = specification.openpage          if a and a ~= "" then d.PO = checked(a) end
    a = specification.closepage         if a and a ~= "" then d.PC = checked(a) end
 -- a = specification.visiblepage       if a and a ~= "" then d.PV = checked(a) end
 -- a = specification.invisiblepage     if a and a ~= "" then d.PI = checked(a) end
    return next(d) and pdfdictionary(d)
end

-- fonts and color

local pdfdocencodingvector, pdfdocencodingcapsule

-- The pdf doc encoding vector is needed in order to
-- trigger propper unicode. Interesting is that when
-- a glyph is not in the vector, it is still visible
-- as it is taken from some other font. Messy.

local function checkpdfdocencoding()
    report_fields("adding pdfdoc encoding vector")
    local encoding = dofile(resolvers.findfile("lpdf-enc.lua")) -- no checking, fatal if not present
    pdfdocencodingvector = pdfreference(pdfflushobject(encoding))
    local capsule = pdfdictionary {
        PDFDocEncoding = pdfdocencodingvector
    }
    pdfdocencodingcapsule = pdfreference(pdfflushobject(capsule))
    checkpdfdocencoding = function() end
end

local fontnames = {
    rm = {
        tf = "Times-Roman",
        bf = "Times-Bold",
        it = "Times-Italic",
        sl = "Times-Italic",
        bi = "Times-BoldItalic",
        bs = "Times-BoldItalic",
    },
    ss = {
        tf = "Helvetica",
        bf = "Helvetica-Bold",
        it = "Helvetica-Oblique",
        sl = "Helvetica-Oblique",
        bi = "Helvetica-BoldOblique",
        bs = "Helvetica-BoldOblique",
    },
    tt = {
        tf = "Courier",
        bf = "Courier-Bold",
        it = "Courier-Oblique",
        sl = "Courier-Oblique",
        bi = "Courier-BoldOblique",
        bs = "Courier-BoldOblique",
    },
    symbol = {
        dingbats = "ZapfDingbats",
    }
}

local usedfonts = { }

local function fieldsurrounding(specification)
    local fontsize        = specification.fontsize or "12pt"
    local fontstyle       = specification.fontstyle or "rm"
    local fontalternative = specification.fontalternative or "tf"
    local colorvalue      = specification.colorvalue
    local s = fontnames[fontstyle]
    if not s then
        fontstyle, s = "rm", fontnames.rm
    end
    local a = s[fontalternative]
    if not a then
        alternative, a = "tf", s.tf
    end
    local tag = fontstyle .. fontalternative
    fontsize = todimen(fontsize)
    fontsize = (fontsize and (bpfactor * fontsize)) or 12
    fontraise = 0.1 * fontsize -- todo: figure out what the natural one is and compensate for strutdp
    local fontcode  = format("%0.4f Tf %0.4f Ts",fontsize,fontraise)
    local colorcode = lpdf.color(3,colorvalue) -- we force an rgb color space
    if trace_fields then
        report_fields("fontcode : %s %s @ %s => %s => %s",fontstyle,fontalternative,fontsize,tag,fontcode)
        report_fields("colorcode: %s => %s",colorvalue,colorcode)
    end
    local stream = pdfstream {
        pdfconstant(tag),
        format("%s %s",fontcode,colorcode)
    }
    usedfonts[tag] = a -- the name
    -- move up with "x.y Ts"
    return tostring(stream)
end

local function registerfonts()
    if next(usedfonts) then
        checkpdfdocencoding()
        local d = pdfdictionary()
        local pdffonttype, pdffontsubtype = pdfconstant("Font"), pdfconstant("Type1")
        for tag, name in next, usedfonts do
            local f = pdfdictionary {
                Type     = pdffonttype,
                Subtype  = pdffontsubtype,
                Name     = pdfconstant(tag),
                BaseFont = pdfconstant(name),
                Encoding = pdfdocencodingvector,
            }
            d[tag] = pdfreference(pdfflushobject(f))
        end
        return d
    end
end

-- symbols

local function fieldappearances(specification)
    -- todo: caching
    local values = specification.values
    local default = specification.default -- todo
    if not values then
        -- error
        return
    end
    local v = settings_to_array(values)
    local n, r, d
    if #v == 1 then
        n, r, d = v[1], v[1], v[1]
    elseif #v == 2 then
        n, r, d = v[1], v[1], v[2]
    else
        n, r, d = v[1], v[2], v[3]
    end
    local appearance = pdfdictionary {
        N = registeredsymbol(n), R = registeredsymbol(r), D = registeredsymbol(d),
    }
    return pdfshareobjectreference(appearance)
end

local YesorOn = "Yes" -- somehow On is not always working out well any longer (why o why this change)

local function fieldstates(specification,forceyes,values,default)
    -- we don't use Opt here (too messy for radio buttons)
    local values, default = values or specification.values, default or specification.default
    if not values or values == "" then
        -- error
        return
    end
    local v = settings_to_array(values)
    local yes, off, yesn, yesr, yesd, offn, offr, offd
    if #v == 1 then
        yes, off = v[1], v[1]
    else
        yes, off = v[1], v[2]
    end
    local yesshown, yesvalue = lpegmatch(splitter,yes)
    if not (yesshown and yesvalue) then
        yesshown = yes, yes
    end
    yes = settings_to_array(yesshown)
    local offshown, offvalue = lpegmatch(splitter,off)
    if not (offshown and offvalue) then
        offshown = off, off
    end
    off = settings_to_array(offshown)
    if #yes == 1 then
        yesn, yesr, yesd = yes[1], yes[1], yes[1]
    elseif #yes == 2 then
        yesn, yesr, yesd = yes[1], yes[1], yes[2]
    else
        yesn, yesr, yesd = yes[1], yes[2], yes[3]
    end
    if #off == 1 then
        offn, offr, offd = off[1], off[1], off[1]
    elseif #off == 2 then
        offn, offr, offd = off[1], off[1], off[2]
    else
        offn, offr, offd = off[1], off[2], off[3]
    end
    if not yesvalue then
        yesvalue = yesn
    end
    if not offvalue then
        offvalue = offn
    end
    if forceyes == true then
        forceyes = forceyes and YesorOn -- spec likes Yes more but we've used On for ages now
    else
        -- false or string
    end
    if default == yesn then
        default = pdfconstant(forceyes or yesn)
    else
        default = pdf_off
    end
    local appearance = pdfdictionary { -- maybe also cache components
        N = pdfdictionary { [forceyes or yesn] = registeredsymbol(yesn), Off = registeredsymbol(offn) },
        R = pdfdictionary { [forceyes or yesr] = registeredsymbol(yesr), Off = registeredsymbol(offr) },
        D = pdfdictionary { [forceyes or yesd] = registeredsymbol(yesd), Off = registeredsymbol(offd) }
    }
    local appearanceref = pdfshareobjectreference(appearance)
    return appearanceref, default, yesvalue
end

local function fielddefault(field)
    local default = field.default
    if not default or default == "" then
        local values = settings_to_array(field.values)
        default = values[1]
    end
    if not default or default == "" then
        return pdf_off
    else
        return pdfconstant(default)
    end
end

local function fieldoptions(specification)
    local values = specification.values
    local default = specification.default
    if values then
        local v = settings_to_array(values)
        for i=1,#v do
            local vi = v[i]
            local shown, value = lpegmatch(splitter,vi)
            if shown and value then
                v[i] = pdfarray { pdfunicode(value), shown }
            else
                v[i] = pdfunicode(v[i])
            end
        end
        return pdfarray(v)
    end
end

local mapping = {
    -- acrobat compliant (messy, probably some pdfdoc encoding interference here)
    check   = "4", -- 0x34
    circle  = "l", -- 0x6C
    cross   = "8", -- 0x38
    diamond = "u", -- 0x75
    square  = "n", -- 0x6E
    star    = "H", -- 0x48
}

local function todingbat(n)
    if n and n ~= "" then
        return mapping[n] or ""
    end
end

local function fieldrendering(specification)
    local bvalue = tonumber(specification.backgroundcolorvalue)
    local fvalue = tonumber(specification.framecolorvalue)
    local svalue = specification.fontsymbol
    if bvalue or fvalue or svalue then
        return pdfdictionary {
            BG = bvalue and pdfarray { lpdf.colorvalues(3,bvalue) } or nil,
            BC = fvalue and pdfarray { lpdf.colorvalues(3,fvalue) } or nil,
            CA = svalue and pdfstring (svalue) or nil,
        }
    end
end

-- layers

local function fieldlayer(specification) -- we can move this in line
    local layer = specification.layer
    return (layer and lpdf.layerreference(layer)) or nil
end

-- defining

local fields, radios, clones, fieldsets, calculationset = { }, { }, { }, { }, nil

function codeinjections.definefieldset(tag,list)
    fieldsets[tag] = list
end

function codeinjections.getfieldset(tag)
    return fieldsets[tag]
end

local function fieldsetlist(tag)
    if tag then
        local ft = fieldsets[tag]
        if ft then
            local a = pdfarray()
            for name in gmatch(list,"[^, ]+") do
                local f = field[name]
                if f and f.pobj then
                    a[#a+1] = pdfreference(f.pobj)
                end
            end
            return a
        end
    end
end

function codeinjections.setfieldcalculationset(tag)
    calculationset = tag
end

local function predefinesymbols(specification)
    local values = specification.values
    if values then
        local symbols = settings_to_array(values)
        for i=1,#symbols do
            local symbol = symbols[i]
            local a, b = lpegmatch(splitter,symbol)
            codeinjections.presetsymbol(a or symbol)
        end
    end
end

function codeinjections.getdefaultfieldvalue(name)
    local f = fields[name]
    if f then
        local values  = f.values
        local default = f.default
        if not default or default == "" then
            local symbols = settings_to_array(values)
            local symbol = symbols[1]
            if symbol then
                local a, b = lpegmatch(splitter,symbol) -- splits at =>
                default = a or symbol
            end
        end
        return default
    end
end

function codeinjections.definefield(specification)
    local n = specification.name
    local f = fields[n]
    if not f then
        local fieldtype = specification.type
        if not fieldtype then
            if trace_fields then
                report_fields("invalid definition of '%s': unknown type",n)
            end
        elseif fieldtype == "radio" then
            local values = specification.values
            if values and values ~= "" then
                values = settings_to_array(values)
                for v=1,#values do
                    radios[values[v]] = { parent = n }
                end
                fields[n] = specification
                if trace_fields then
                    report_fields("defining '%s' as radio",n or "?")
                end
            elseif trace_fields then
                report_fields("invalid definition of radio '%s': missing values",n)
            end
        elseif fieldtype == "sub" then
            -- not in main field list !
            local radio = radios[n]
            if radio then
                -- merge specification
                for key, value in next, specification do
                    radio[key] = value
                end
                if trace_fields then
                    local p = radios[n] and radios[n].parent
                    report_fields("defining '%s' as sub of radio '%s'",n or "?",p or "?")
                end
            elseif trace_fields then
                report_fields("invalid definition of radio sub '%s': no parent",n)
            end
            predefinesymbols(specification)
        elseif fieldtype == "text" or fieldtype == "line" then
            fields[n] = specification
            if trace_fields then
                report_fields("defining '%s' as %s",n,fieldtype)
            end
            if specification.values ~= "" and specification.default == "" then
                specification.default, specification.values = specification.values, nil
            end
        else
            fields[n] = specification
            if trace_fields then
                report_fields("defining '%s' as %s",n,fieldtype)
            end
            predefinesymbols(specification)
        end
    elseif trace_fields then
        report_fields("invalid definition of '%s': already defined",n)
    end
end

function codeinjections.clonefield(specification) -- obsolete
    local p, c, v = specification.parent, specification.children, specification.alternative
    if not p or not c then
        if trace_fields then
            report_fields("invalid clone: children: '%s', parent '%s', alternative: '%s'",p or "?",c or "?", v or "?")
        end
        return
    end
    local x = fields[p]
    if not x then
        if trace_fields then
            report_fields("cloning: unknown parent '%s'",p)
        end
        return
    end
    for n in gmatch(c,"[^, ]+") do
        local f, r, c = fields[n], radios[n], clones[n]
        if f or r or c then
            if trace_fields then
                report_fields("already cloned: child: '%s', parent '%s', alternative: '%s'",p,n, v or "?")
            end
        else
            if trace_fields then
                report_fields("cloning: child: '%s', parent '%s', alternative: '%s'",p,n, v or "?")
            end
            clones[n] = specification
            predefinesymbols(specification)
        end
    end
end

function codeinjections.getfieldcategory(name)
    local f = fields[name] or radios[name] or clones[name]
    if f then
        local g = f.category
        if not g or g == "" then
            local v, p, t = f.alternative, f.parent, f.type
            if v == "clone" or v == "copy" then
                f = fields[p] or radios[p]
                g = f and f.category
            elseif t == "sub" then
                f = fields[p]
                g = f and f.category
            end
        end
        return g
    end
end

--

function codeinjections.validfieldcategory(name)
    return fields[name] or radios[name] or clones[name]
end

function codeinjections.validfieldset(name)
    return fieldsets[tag]
end

function codeinjections.validfield(name)
    return fields[name]
end

--

local alignments = {
    flushleft  = 0, right  = 0,
    center     = 1, middle = 1,
    flushright = 2, left   = 2,
}

local function fieldalignment(specification)
    return alignments[specification.align] or 0
end

local function enhance(specification,option)
    local so = specification.option
    if so and so ~= "" then
        specification.option = so .. "," .. option
    else
        specification.option = option
    end
    return specification
end

-- finish

local collected = pdfarray()

local function finishfields()
    for name, field in next, fields do
        local kids = field.kids
        if kids then
            pdfflushobject(field.kidsnum,kids)
        end
        local opt = field.opt
        if opt then
            pdfflushobject(field.optnum,opt)
        end
    end
    for name, field in next, radios do
        local kids = field.kids
        if kids then
            pdfflushobject(field.kidsnum,kids)
        end
        local opt = field.opt
        if opt then
            pdfflushobject(field.optnum,opt)
        end
    end
    if #collected > 0 then
        checkpdfdocencoding()
        usedfonts.tttf = fontnames.tt.tf
        local acroform = pdfdictionary {
            NeedAppearances = true,
            Fields = pdfreference(pdfflushobject(collected)),
            DR     = pdfdictionary {
                Font     = registerfonts(),
                Encoding = pdfdocencodingcapsule,
            },
            CO     = fieldsetlist(calculationset),
            DA     = "/tttf 12 Tf 0 g",
        }
        lpdf.addtocatalog("AcroForm",pdfreference(pdfflushobject(acroform)))
    end
end

lpdf.registerdocumentfinalizer(finishfields,"form fields")

local methods = { }

function nodeinjections.typesetfield(name,specification)
    local field = fields[name] or radios[name] or clones[name]
    if not field then
        report_fields( "unknown child '%s'",name)
        -- unknown field
        return
    end
    local alternative, parent = field.alternative, field.parent
    if alternative == "copy" or alternative == "clone" then -- only in clones
        field = fields[parent] or radios[parent]
    end
    local method = methods[field.type]
    if method then
        return method(name,specification,alternative)
    else
        report_fields( "unknown method '%s' for child '%s'",field.type,name)
    end
end

local function save_parent(field,specification,d,hasopt)
    local kidsnum = pdfreserveobject()
    d.Kids = pdfreference(kidsnum)
    field.kidsnum = kidsnum
    field.kids = pdfarray()
    if hasopt then
        local optnum = pdfreserveobject()
        d.Opt = pdfreference(optnum)
        field.optnum = optnum
        field.opt = pdfarray()
    end
    local pnum = pdfflushobject(d)
    field.pobj = pnum
    collected[#collected+1] = pdfreference(pnum)
end

local function save_kid(field,specification,d,optname)
    local kn = pdfreserveannotation()
    field.kids[#field.kids+1] = pdfreference(kn)
    if optname then
        field.opt[#field.opt+1] = optname
    end
    local width, height, depth = specification.width or 0, specification.height or 0, specification.depth
    local box = hpack_node(pdfannotation_node(width,height,depth,d(),kn))
    box.width, box.height, box.depth = width, height, depth -- redundant
    return box
end

local function makelineparent(field,specification)
    local text = pdfunicode(field.default)
    local length = tonumber(specification.length or 0) or 0
    local d = pdfdictionary {
        Subtype  = pdf_widget,
        T        = pdfunicode(specification.title),
        F        = fieldplus(specification),
        Ff       = fieldflag(specification),
        OC       = fieldlayer(specification),
        DA       = fieldsurrounding(specification),
        AA       = fieldactions(specification),
        FT       = pdf_tx,
        Q        = fieldalignment(specification),
        MaxLen   = length == 0 and 1000 or length,
        DV       = text,
        V        = text,
    }
    save_parent(field,specification,d)
end

local function makelinechild(name,specification)
    local field, parent = clones[name], nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent text '%s'",parent.name)
            end
            makelineparent(parent,specification)
        end
    else
        parent = fields[name]
        field = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent text '%s'",name)
            end
            makelineparent(parent,specification)
        end
    end
    if trace_fields then
        report_fields("using child text '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        DA      = fieldsurrounding(specification),
        AA      = fieldactions(specification),
        MK      = fieldrendering(specification),
        Q       = fieldalignment(specification),
    }
    return save_kid(parent,specification,d)
end

function methods.line(name,specification)
    return makelinechild(name,specification)
end

function methods.text(name,specification)
    return makelinechine(name,enhance(specification,"MultiLine"))
end

local function makechoiceparent(field,specification)
    local d = pdfdictionary {
        Subtype  = pdf_widget,
        T        = pdfunicode(specification.title),
        F        = fieldplus(specification),
        Ff       = fieldflag(specification),
        OC       = fieldlayer(specification),
        AA       = fieldactions(specification),
        FT       = pdf_ch,
        Opt      = fieldoptions(field), -- todo
    }
    save_parent(field,specification,d)
end

local function makechoicechild(name,specification)
    local field, parent = clones[name], nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent choice '%s'",parent.name)
            end
            makechoiceparent(parent,specification,extras)
        end
    else
        parent = fields[name]
        field = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent choice '%s'",name)
            end
            makechoiceparent(parent,specification,extras)
        end
    end
    if trace_fields then
        report_fields("using child choice '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
    }
    return save_kid(parent,specification,d) -- do opt here
end

function methods.choice(name,specification)
    return makechoicechild(name,specification)
end

function methods.popup(name,specification)
    return makechoicechild(name,enhance(specification,"PopUp"))
end

function methods.combo(name,specification)
    return makechoicechild(name,enhance(specification,"PopUp,Edit"))
end

local function makecheckparent(field,specification)
    local d = pdfdictionary {
        T  = pdfunicode(specification.title),
        F  = fieldplus(specification),
        Ff = fieldflag(specification),
        OC = fieldlayer(specification),
        AA = fieldactions(specification),
        FT = pdf_btn,
        V  = fielddefault(field),
    }
    save_parent(field,specification,d,true)
end

local function makecheckchild(name,specification)
    local field, parent = clones[name], nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent check '%s'",parent.name)
            end
            makecheckparent(parent,specification,extras)
        end
    else
        parent = fields[name]
        field = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent check '%s'",name)
            end
            makecheckparent(parent,specification,extras)
        end
    end
    if trace_fields then
        report_fields("using child check '%s'",name)
    end
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        H       = pdf_n,
    }
    local fontsymbol = specification.fontsymbol
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
        return save_kid(parent,specification,d)
    else
        local appearance, default, value = fieldstates(field,true)
        d.AS = default
        d.AP = appearance
        return save_kid(parent,specification,d,value)
    end
end

function methods.check(name,specification)
    return makecheckchild(name,specification)
end

local function makepushparent(field,specification) -- check if we can share with the previous
    local d = pdfdictionary {
        Subtype = pdf_widget,
        T       = pdfunicode(specification.title),
        F       = fieldplus(specification),
        Ff      = fieldflag(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        FT      = pdf_btn,
        AP      = fieldappearances(field),
        H       = pdf_p,
    }
    save_parent(field,specification,d)
end

local function makepushchild(name,specification)
    local field, parent = clones[name], nil
    if field then
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent push '%s'",parent.name)
            end
            makepushparent(parent,specification)
        end
    else
        parent = fields[name]
        field = parent
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent push '%s'",name)
            end
            makepushparent(parent,specification)
        end
    end
    if trace_fields then
        report_fields("using child push '%s'",name)
    end
    local fontsymbol = specification.fontsymbol
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(field.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        H       = pdf_p,
    }
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
    else
        d.AP = fieldappearances(field)
    end
    return save_kid(parent,specification,d)
end

function methods.push(name,specification)
    return makepushchild(name,enhance(specification,"PushButton"))
end

local function makeradioparent(field,specification)
    specification = enhance(specification,"Radio,RadiosInUnison")
    local d = pdfdictionary {
        T  = field.name,
        FT = pdf_btn,
        F  = fieldplus(specification),
        Ff = fieldflag(specification),
        H  = pdf_n,
        V  = fielddefault(field),
    }
    save_parent(field,specification,d,true)
end

local function makeradiochild(name,specification)
    local field, parent = clones[name], nil
    if field then
        field = radios[field.parent]
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("forcing parent radio '%s'",parent.name)
            end
            makeradioparent(parent,parent)
        end
        field = radios[name]
    else
        field = radios[name]
        parent = fields[field.parent]
        if not parent.pobj then
            if trace_fields then
                report_fields("using parent radio '%s'",name)
            end
            makeradioparent(parent,parent)
        end
    end
    if trace_fields then
        report_fields("using child radio '%s' with values '%s' and default '%s'",name,field.values or "?",field.default or "?")
    end
    local fontsymbol = specification.fontsymbol
    local d = pdfdictionary {
        Subtype = pdf_widget,
        Parent  = pdfreference(parent.pobj),
        F       = fieldplus(specification),
        OC      = fieldlayer(specification),
        AA      = fieldactions(specification),
        H       = pdf_n,
    }
    if fontsymbol and fontsymbol ~= "" then
        specification.fontsymbol = todingbat(fontsymbol)
        specification.fontstyle = "symbol"
        specification.fontalternative = "dingbats"
        d.DA = fieldsurrounding(specification)
        d.MK = fieldrendering(specification)
        return save_kid(parent,specification,d)
    else
        local appearance, default, value = fieldstates(field,true) -- false is also ok
        d.AS = default -- needed ?
        d.AP = appearance
        return save_kid(parent,specification,d,value)
    end
end

function methods.sub(name,specification)
    return makeradiochild(name,enhance(specification,"Radio,RadiosInUnison"))
end
