local info = {
    version   = 1.002,
    comment   = "file handler for textadept for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer   = require("scite-context-lexer")
local context = lexer.context

local char, format, gsub = string.char, string.format, string.gsub

-- What is _CHARSET doing ... I don't want any messing with conversion at all. Scite is
-- more clever with e.g. pdf. How can I show non ascii as escapes.

io.encodings = {
    "UTF-8",
    "ASCII",
    "UTF-16",
}

-- We need this for for instance pdf files (faster too):

local sevenbitascii   = { }
for i=127,255 do
    sevenbitascii[char(i)] = format("0x%02X",i)
end

local function setsevenbitascii(buffer)
    -- we cannot directly assign sevenbitascii to buffer
    local representation = buffer.representation
    for k, v in next, sevenbitascii do
        representation[k] = v
    end
end

-- Here we rebind keys. For this we need to load the alternative runner framework. I will
-- probably change the menu.

local oldrunner = textadept.run
local runner    = require("textadept-context-runner")

-- local function userunner(runner)
--     --
--     keys [OSX and 'mr' or                  'cr'  ] = runner.process or runner.run
--     keys [OSX and 'mR' or (GUI and 'cR' or 'cmr')] = runner.check   or runner.compile
--     keys [OSX and 'mB' or (GUI and 'cB' or 'cmb')] = runner.preview or runner.build
--     keys [OSX and 'mX' or (GUI and 'cX' or 'cmx')] = runner.quit    or runner.stop
--     --
--     textadept.menu.menubar [_L['_Tools']] [_L['_Run']]     [2] = runner.process or runner.run
--     textadept.menu.menubar [_L['_Tools']] [_L['_Compile']] [2] = runner.check   or runner.compile
--     textadept.menu.menubar [_L['_Tools']] [_L['Buil_d']]   [2] = runner.preview or runner.build
--     textadept.menu.menubar [_L['_Tools']] [_L['S_top']]    [2] = runner.quit    or runner.stop
--     --
-- end

-- I played a while with supporting both systems alongsize but getting the menus
-- synchronized is a real pain and semi-random. So, I decided to just drop the
-- old. And I don't want to implement a full variant now. Anyway, after that
-- conclusion I decided to replace not only the tools menu.

local SEPARATOR = { "" }
local newmenu   = { }

do

    newmenu.file = {

        title = '_File',

        { '_New',          buffer.new },
        { '_Open',         io.open_file },
        { 'Open _Recent',  io.open_recent_file },
        { 'Re_load',       io.reload_file },
        { '_Save',         io.save_file },
        { 'Save _As',      io.save_file_as },
        { 'Save All',      io.save_all_files },

        SEPARATOR,

        { '_Close',        io.close_buffer },
        { 'Close All',     io.close_all_buffers },

     -- SEPARATOR,

     -- { 'Loa_d Session', textadept.session.load },
     -- { 'Sav_e Session', textadept.session.save },

        SEPARATOR,

        { _L['_Quit'],     quit },

    }

end

do

    newmenu.edit = {

        title = '_Edit',

        SEPARATOR,

        { '_Undo',                 buffer.undo },
        { '_Redo',                 buffer.redo },

        SEPARATOR,

        { 'Cu_t',                  buffer.cut },
        { '_Copy',                 buffer.copy },
        { '_Paste',                buffer.paste },
        { '_Delete',               buffer.clear },
        { 'Select _All',           buffer.select_all },

        SEPARATOR,

        { 'Duplicate _Line',       buffer.line_duplicate },

        SEPARATOR,

        { 'Toggle _Block Comment', textadept.editing.block_comment },
        { '_Upper Case Selection', buffer.upper_case },
        { '_Lower Case Selection', buffer.lower_case },

    }

end

do

    local function find_in_file()
        ui.find.in_files = false
        ui.find.focus()
    end

    local function find_in_files()
        ui.find.in_files = true
        ui.find.focus()
    end

    local function find_next_in_files()
        ui.find.goto_file_found(false,true)
    end

    local function find_previous_in_files()
        ui.find.goto_file_found(false,false)
    end

    newmenu.search = {

        title = '_Search',

        SEPARATOR,

        { '_Find',                     find_in_file },
        { 'Find _Next',                ui.find.find_next },
        { 'Find _Previous',            ui.find.find_prev },
        { '_Replace',                  ui.find.replace },
        { 'Replace _All',              ui.find.replace_all },
        { 'Find _Incremental',         ui.find.find_incremental },

        SEPARATOR,

        { 'Find in Fi_les',            find_in_files },
        { 'Goto Nex_t File Found',     find_next_in_files },
        { 'Goto Previou_s File Found', find_previous_in_files },

        SEPARATOR,

        { '_Jump to',                  textadept.editing.goto_line }

    }

end

do

    io.quick_open_max = 5000

    local function isdir(path)
        return path and path ~= "" and lfs.attributes(path,'mode') == 'directory'
    end

    local function resolveroot(path)
        local path = runner.resultof("mtxrun --resolve-path TEXMFCONTEXT")
        if path then
            return string.match(path,"(.-)%s$")
        end
    end

    local function opencurrentdirectory()
        local path = buffer.filename
        if path and path ~= "" then
            path = string.match(path,"^(.+)[/\\]")
            if isdir(path) then
                io.quick_open(path)
            end
        end
    end

    local function openuserdirectory()
        local path = resolveroot("TEXMFPROJECT")
        if isdir(path) then
            io.quick_open(path .. "/tex/context/user")
        end
    end

    local function openbasedirectory()
        local path = resolveroot("TEXMFCONTEXT")
        if isdir(path) then
            io.quick_open(path .. "/tex/context/base/mkiv")
        end
    end

    local started = false

    local function startservice()
        if WIN32 then
            os.execute([[cmd /c start /min "Context Documentation" mtxrun --script server --auto]])
        else
            os.execute([[mtxrun --script server --start > ~/context-wwwserver.log &]])
        end
        started = true
    end

    local function showcommand()
     -- if not started then
     --     startservice()
     -- end
        local start = buffer.selection_n_start[0]
        local stop  = buffer.selection_n_end[0]
        if start == stop then
            buffer:set_target_range(buffer:word_start_position(start,true),buffer:word_end_position(stop,true))
        else
            buffer:set_target_range(start,stop)
        end
        local word = buffer.target_text
        os.execute(format([[mtxrun --gethelp --url="http://localhost:8088/mtx-server-ctx-help.lua?command=%s"]],word or ""))
    end

    newmenu.tools = {

        title = '_Tools',

        SEPARATOR,

        { 'Check Source',            runner.install("check") },
        { 'Process Source',          runner.install("process") },
        { 'Preview Result',          runner.install("preview") },
        { 'Show Log File',           runner.install("logfile") },
        { 'Quit',                    runner.quit },

        SEPARATOR,

        { 'Open Current Directory',  opencurrentdirectory },
        { 'Open User Directory',     openuserdirectory },
        { 'Open Base Directory',     openbasedirectory },

        SEPARATOR,

        { 'Purge Files',             runner.install("purge") },
        { 'Clear Cache',             runner.install("clear") },
        { 'Generate File Database',  runner.install("generate") },
        { 'Generate Font Database',  runner.install("fonts") },

        SEPARATOR,

        { 'Typeset Listing',         runner.install("listing") },
        { 'Process and Arrange',     runner.install("arrange") },

        SEPARATOR,

        { 'Start Document Service',  startservice },
        { 'Goto Document Service',   showcommand },

        SEPARATOR,

        { 'Show Unicodes',           runner.install("unicodes") },

    }

end

do

    local function use_tabs()
        buffer.use_tabs = not buffer.use_tabs
        events.emit(events.UPDATE_UI) -- for updating statusbar
    end

    local function set_eol_mode_crlf()
        set_eol_mode(buffer.EOL_CRLF)
    end

    local function set_eol_mode_lf()
        set_eol_mode(buffer.EOL_LF)
    end

    local function show_eol()
        buffer.view_eol = not buffer.view_eol
    end

    local function wrap_mode()
        buffer.wrap_mode = buffer.wrap_mode == 0 and buffer.WRAP_WHITESPACE or 0
    end

    function show_white_space()
        buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
    end

    local function update_lexing()
        buffer:colourise(0,-1)
    end

    function set_endoding_utf8()
        set_encoding('UTF-8')
    end

    function set_encoding_ascii()
        set_encoding('ASCII')
    end

    function set_endoding_utf16le()
        set_encoding('UTF-16LE')
    end

    function set_endoding_utf16Be()
        set_encoding('UTF-16BE')
    end

    function goto_previous_buffer()
        view:goto_buffer(-1)
    end

    function goto_next_buffer()
        view:goto_buffer(1)
    end

    newmenu.buffer = {

        title = '_Buffer',

        SEPARATOR,

        { '_Previous Buffer',  goto_previous_buffer },
        { '_Next Buffer',      goto_next_buffer },
        { '_Switch to Buffer', ui.switch_buffer },

        SEPARATOR,

        { '_Toggle Use Tabs', use_tabs },
        {
            title = 'EOL Mode',

            { '_CRLF', set_eol_mode_crlf },
            { '_LF',   set_eol_mode_lf },
        },
        {
            title = 'Encoding',

            { '_ASCII',     set_encoding_ascii },
            { '_UTF-8',     set_encoding_utf8 },
            { 'UTF-16-_BE', set_encoding_utf16le },
            { 'UTF-16-_LE', set_encoding_utf16be },
        },

        SEPARATOR,

        { 'Toggle View _EOL',     show_eol },
        { 'Toggle _Wrap Mode',    wrap_mode  },
        { 'Toggle View _Spacing', show_whitespace },

        SEPARATOR,

        { 'Select _Lexer',                textadept.file_types.select_lexer },
        { 'Refresh _Syntax Highlighting', update_lexing }

    }

end

do

    local function toggle_current_fold()
        buffer:toggle_fold(buffer:line_from_position(buffer.current_pos))
    end

    local function toggle_show_guides()
        local off = buffer.indentation_guides == 0
        buffer.indentation_guides = off and buffer.IV_LOOKBOTH or 0
    end

    local function toggle_virtual_space()
        local off = buffer.virtual_space_options == 0
        buffer.virtual_space_options = off and buffer.VS_USERACCESSIBLE or 0
    end

    local function reset_zoom()
        buffer.zoom = 0
    end

    newmenu.view = {

        title = '_View',

        SEPARATOR,

        { 'Toggle Current _Fold' ,      toggle_current_fold },

        SEPARATOR,

        { 'Toggle Show In_dent Guides', toggle_show_guides },
        { 'Toggle _Virtual Space',      toggle_virtual_space },

        SEPARATOR,

        { 'Zoom _In',                   buffer.zoom_in },
        { 'Zoom _Out',                  buffer.zoom_out },
        { '_Reset Zoom',                reset_zoom },

    }

end

do

    -- It's a pity that we can't have a proper monospaced font here so we try to make the best of it:

    local template = "\n\trelease info: %s\t\n\n\tcopyright: %s\t\n\n\tvariant: ConTeXt related editing\t\n\n\tadapted by: Hans Hagen\t"

    function show_about()
        ui.dialogs.msgbox {
            title            = "about",
            informative_text = format(template,(gsub(_RELEASE,"%s+"," ")),(gsub(_COPYRIGHT,"%s+"," ")))
        }
    end

    local function open_url(url) -- adapted from non public open_page
        local cmd = (WIN32 and 'start ""') or (OSX and 'open') or 'xdg-open'
        spawn(format('%s "%s"', cmd, url))
    end


    newmenu.help = {

        title = '_Help',

        SEPARATOR,

        { 'ConTeXt garden wiki', function() open_url("http://www.contextgarden.net") end },

     -- SEPARATOR,

        { '_About', show_about }

    }

end
do

    local function replace(oldmenu,newmenu)
        local n = #newmenu
        local o = #oldmenu
        for i=1,n do
            oldmenu[i] = newmenu[i]
        end
        for i=o,n+1,-1 do
            oldmenu[i] = nil
        end
    end

    replace(textadept.menu.menubar [_L['_File']],   newmenu.file)
    replace(textadept.menu.menubar [_L['_Edit']],   newmenu.edit)
    replace(textadept.menu.menubar [_L['_Search']], newmenu.search)
    replace(textadept.menu.menubar [_L['_Tools']],  newmenu.tools)
    replace(textadept.menu.menubar [_L['_Buffer']], newmenu.buffer)
    replace(textadept.menu.menubar [_L['_View']],   newmenu.view)
    replace(textadept.menu.menubar [_L['_Help']],   newmenu.help)

end

-- We have a different way to set up files and runners. Less distributed and morein the way we
-- do things in context.

local dummyrunner    = function() end
local extensions     = textadept.file_types.extensions
local specifications = runner.specifications
local setters        = { }
local defaults       = {
    check   = dummyrunner,
    process = dummyrunner,
    preview = dummyrunner,
}

setmetatable(specifications, { __index = defaults })

function context.install(specification)
    local suffixes = specification.suffixes
    if suffixes then
        local lexer    = specification.lexer
        local setter   = specification.setter
        local encoding = specification.encoding
        for i=1,#suffixes do
            local suffix = suffixes[i]
            if lexer and extensions then
                extensions[suffix] = lexer
            end
            specifications[suffix] = specification
            if lexer then
                setters[lexer] = function()
                    if encoding == "7-BIT-ASCII" then
                        setsevenbitascii(buffer)
                    end
                    if setter then
                        setter(lexer)
                    end
                end
            end
        end
    end
end

-- Too much interference so I might drop all the old stuff eventually.

local function synchronize(lexer)
    if lexer then
        local setter = lexer and setters[lexer]
        if setter then
            local action = context.synchronize
            if action then
                action()
            end
         -- userunner()
            setter(lexer)
        else
         -- useoldrunner()
        end
    end
end

events.connect(events.FILE_OPENED,function(filename)
    synchronize(buffer.get_lexer(buffer))
end)

events.connect(events.LEXER_LOADED,function(lexer)
    synchronize(lexer)
end)

-- obsolete

-- events.connect(events.BUFFER_AFTER_SWITCH,function()
--     synchronize(buffer.get_lexer(buffer))
-- end)

-- events.connect(events.VIEW_AFTER_SWITCH,function()
--     synchronize(buffer.get_lexer(buffer))
-- end)

-- events.connect(events.BUFFER_NEW,function()
--     synchronize(buffer.get_lexer(buffer))
-- end)

-- events.connect(events.VIEW_NEW,function()
--     synchronize(buffer.get_lexer(buffer))
-- end)

-- events.connect(events.RESET_AFTER,function()
--     synchronize(buffer.get_lexer(buffer))
-- end)

-- local oldtools  = { }
-- local usingold  = false
-- local toolsmenu = textadept.menu.menubar [_L['_Tools']]
--
-- for i=1,#toolsmenu do
--     oldtools[i] = toolsmenu[i]
-- end
--
-- local function replace(tools)
--     local n = #toolsmenu
--     local m = #tools
--     for i=1,m do
--         toolsmenu[i] = tools[i]
--     end
--     for i=n,m+1,-1 do
--         toolsmenu[i] = nil
--     end
-- end
--
-- local function useoldrunner()
--     if not usingold then
--         keys [OSX and 'mr' or                  'cr'  ] = oldrunner.run
--         keys [OSX and 'mR' or (GUI and 'cR' or 'cmr')] = oldrunner.compile
--         keys [OSX and 'mB' or (GUI and 'cB' or 'cmb')] = oldrunner.build
--         keys [OSX and 'mX' or (GUI and 'cX' or 'cmx')] = oldrunner.stop
--         --
--         replace(oldtools)
--         --
--         usingold = true
--     end
-- end
--
-- local function userunner()
--     if usingold then
--         keys [OSX and 'mr' or                  'cr'  ] = runner.process
--         keys [OSX and 'mR' or (GUI and 'cR' or 'cmr')] = runner.check
--         keys [OSX and 'mB' or (GUI and 'cB' or 'cmb')] = runner.preview
--         keys [OSX and 'mX' or (GUI and 'cX' or 'cmx')] = runner.quit
--         --
--         replace(newtools)
--         --
--         usingold = false
--     end
-- end
--
-- userunner()
