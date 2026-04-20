-- =============================================
-- Level.lua – Authored level section list
-- =============================================
-- LEVEL_SECTIONS is an ordered list of section descriptor tables.
-- The terrain generator walks the list in sequence, calling each
-- section's generator function, then looping back to index 1.
--
-- Descriptor format:
--   { generator = <fn>, ...params... }
--
-- Built-in generators and their params:
--   gen_default_shaft  – section.height (optional integer; omit for random)
--   gen_left_ledge     – section.pads   = {ttype1, ttype2, ttype3}
--   gen_right_ledge    – section.pads   = {ttype1, ttype2, ttype3}
--   gen_missile_wave   – section.wave   = { int, ... }
--       Positive int → SPRITE_ROCKET at x=int.  Negative int → SPRITE_FUEL_ROCKET at x=abs(int).
--       Each entry spawns one obstacle spaced MISSILE_WAVE_SPACING world rows apart.
--
-- section.pads lists one TTYPE_* constant per pad (LEDGE_PAD_COUNT entries),
-- from the topmost pad (first encountered while scrolling up) downward.
--
-- To add a new section type:
--   1. Write a function gen_mysection(section, gen, targets) in GameScreen.lua.
--   2. Add a descriptor here: { generator = gen_mysection, ...your params... }




-- Appends rows to outputRows to describe the game level.  A row is an array of 16 
-- integers decribing an 8px-high section of the level.  The rows are added in
-- descrnding order from the perspective of the player as they descend into the
-- cavern - the first row will appear at the bottom of the screen first and scroll up;
-- the last will be last.
--
-- The input rowDefs is an array that is processed from first to last to
-- in order to output the rows.  Each rowDef element in rowDefs is processed as follows:
-- * if rowDef is an array, it is simply appended to outputRows
-- * if rowDef is a function, it is called with outputRows as a parameter; the function
--   is then responsible to append addtional rows to outputRows as appropriate
--   


function section(ctx, rowDefs) 
    for _, rowDef in ipairs(rowDefs) do
        if type(rowDef) == "function" then
            rowDef(ctx)
        else
            add(ctx.rows, rowDef)
        end
    end
end

-- Repeatedly appends rowDefs a given number of times.
-- rowDefs may be a single row (array of 16 numbers) or a rowDefs list.
function rep(ctx, count, rowDefs) 
    local is_fn = type(rowDefs) == "function"
    local is_single_row = not is_fn and type(rowDefs[1]) == "number"
    for i=1,count do
        if is_fn then
            rowDefs(ctx)
        elseif is_single_row then
            add(ctx.rows, rowDefs)
        else
            section(ctx, rowDefs)
        end
    end
end

-- Notes the current row as the point the player should respawn at
-- once they've crossed it.  Checkpoints are not displayed to the player.
function checkpoint(ctx)
    add(ctx.checkpoints, #ctx.rows)
end

-- Notes the current row as the point at which the terrain scrolling speed changes
-- from the default speed by the given factor.
function speed(ctx, speedMultiplier)
    add(ctx.speed_changes, { row_idx = #ctx.rows, mult = speedMultiplier })
end

-- Sets whether rows being added should appear during the escape sequence.  By
-- default, all rows appear during escape.  If escape(false) is called, then
-- subsequent rows will be skipped during the escape sequence.  If escape(true)
-- is called again, subsequent rows should again be included in the escape sequence
function escape(ctx, escapeEnabled)
    if not escapeEnabled and ctx.escape_enabled then
        -- transitioning to skip: record the start of the skipped range
        ctx._escape_skip_start = #ctx.rows + 1
    elseif escapeEnabled and not ctx.escape_enabled then
        -- transitioning back to include: close the range
        if ctx._escape_skip_start then
            add(ctx.escape_skip_ranges, { from = ctx._escape_skip_start, to = #ctx.rows })
            ctx._escape_skip_start = nil
        end
    end
    ctx.escape_enabled = escapeEnabled
end


-- appends to output rows by iterating through targetDefs and generating
-- a row for each targetDef as follows:
-- the first and last sprite in the generated row is 48
-- if the targetDef value is 0, do nothing else
-- if the targetDef value is positive, add a rocket at: 8 + 8 * (targetDef value)
-- if the targetDef value is negative, add a fueld rocket at: 8 * (targetDef value)
function generateRocketWave(ctx, targetDefs)
    for _, v in ipairs(targetDefs) do
        local row = {48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48}
        if v > 0 then
            -- pixel x = 8 + 8*v  →  column j = v+2 (1-based)
            local j = v + 2
            if j >= 2 and j <= 15 then
                row[j] = SPRITE_ROCKET
            end
        elseif v < 0 then
            -- pixel x = 8*abs(v)  →  column j = abs(v)+1 (1-based)
            local j = -v + 1
            if j >= 2 and j <= 14 then
                row[j]   = SPRITE_FUEL_ROCKET
                row[j+1] = 21  -- right half of fuel rocket sprite (20+1)
            end
        end
        add(ctx.rows, row)
    end
end




function generate_right_ledge(ctx, t1, t2, t3)
section(ctx, {
{ 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,t1, 0,49,48 },
{ 48, 0, 0, 0, 0, 0, 0, 0, 0,t2, 0,49,48,48,48,48 },
{ 48, 0, 0, 0, 0, 0,t3, 0,49,48,48,48,48,48,48,48 },
{ 48, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48,48,48 },
{ 48, 0, 0, 0, 0,48,48,48,48,48,48,48,48,48,48,48 },
{ 48, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48,48,48 },
})
end

function generate_left_ledge(ctx, t1, t2, t3)
section(ctx, {
{ 48,50,t1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 },
{ 48,48,48,48,50,t2, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 },
{ 48,48,48,48,48,48,48,50,t3, 0, 0, 0, 0, 0, 0,48 },
{ 48,48,48,48,48,48,48,48,48,48,50, 0, 0, 0, 0,48 },
{ 48,48,48,48,48,48,48,48,48,48,48, 0, 0, 0, 0,48 },
{ 48,48,48,48,48,48,48,48,48,48,52, 0, 0, 0, 0,48 },
})
end

function genOpenTunnel(ctx, rowCount)
    for i=1,rowCount do
        add(ctx.rows, { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 })
    end
end

function genEssCurve(ctx)
section(ctx, {
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48,48 },
    { 48,50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,49,48,48 },
    { 48,48,50, 0, 0, 0, 0, 0, 0, 0, 0, 0,49,48,48,48 },
    { 48,48,48,50, 0, 0, 0, 0, 0, 0, 0,49,48,48,48,48 },
    { 48,48,48,52, 0, 0, 0, 0, 0, 0,49,48,48,48,48,48 },
    { 48,48,52, 0, 0, 0, 0, 0, 0,49,48,48,48,48,48,48 },
    { 48,52, 0, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0,51,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0,51,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,51,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,51,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,51,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,51,48 },
})
end

function genBumpCurve(ctx)
section(ctx, {
    { 48, 0, 0, 0, 0, 0,48,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,48,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,48,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,48,48,48,48,48,48,48,48,48,48 },            
    { 48, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48,48 },     
    { 48,50, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48 }, 
    { 48,48,50, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48 }, 
    { 48,48,52, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48 }, 
    { 48,52, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,49,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0,51,48,48,48,48,48,48,48,48,48 },
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 },    
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 },    
    { 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,48 },
})
end

NOVICE_LEVEL = {
    function(ctx) checkpoint(ctx) end,
    function(ctx) rep(ctx, 8,
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    ) end,
    { 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,49 },
    function(ctx) genOpenTunnel(ctx, 12) end,
    function(ctx) generate_left_ledge(ctx, 16, 17, 18) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx, 18, 17, 17) end,
    function(ctx) checkpoint(ctx) end,
    function(ctx) genEssCurve(ctx) end,
    function(ctx) generate_left_ledge(ctx, 18, 16, 17) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx, 18, 18, 17) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_left_ledge(ctx, 18, 17, 18) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx, 18, 18, 18) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_left_ledge(ctx, 16, 16, 16) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx, 18, 18, 18) end,
    function(ctx) genBumpCurve(ctx) end,
    function(ctx) generate_right_ledge(ctx, 17, 18, 18) end,
    function(ctx) checkpoint(ctx) end,
    function(ctx) genOpenTunnel(ctx, 16) end,
    function(ctx) speed(ctx, 2.5) end,
    function(ctx) escape(ctx, false) end,
    function(ctx) rep(ctx, 2, 
        function(ctx) generateRocketWave(ctx, {
            1, -7, 12, 0, 7, 0, 8, 1, 9, 0, 14, 4, 0, -1, 13, 1, 6, -1, 12, 0,
            5, 0, 10, 0, 7, -13, 8, -1, 4, 13, 1, 0, 13, 1, 12, 0, 
            3, -3, 9, 0, 6, -10, 4,0, 8, 0, 10, 0, 2, 0, 10, 13, -13, 13,
            6, 0, 13, 0, 1, -4, 4, 0, 9, 1, 11, -5, 3, 0, 8, 0, 
            4, -13, 5, 0, 6, 0, 7, 1, 8, 0, 9, -12, 10, 0, 7, 0,
            2, -3, 13, -9, -7, 8, 8, 0, 11, 0, 3, -12, 5, 0,
            12, -10
        }) end
    ) end,
    function(ctx) genOpenTunnel(ctx, 16) end,
    function(ctx) speed(ctx, 1) end,
    function(ctx) escape(ctx, true) end,
    function(ctx) genOpenTunnel(ctx, 3) end,

    function(ctx) checkpoint(ctx) end,

    function(ctx) section(ctx, EASY_BASE_SECTION) end
}

EASY_BASE_SECTION = {
        { 48,50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,49,48 },    
    function(ctx) rep(ctx, 7, 
        { 33,32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,32,33 }
    ) end,
        { 33,32,32,32, 0, 0, 0, 0, 0, 0, 0, 0,32,32,32,33 },    
    function(ctx) rep(ctx, 15, 
        { 33,33,33,32, 0, 0, 0, 0, 0, 0, 0, 0,32,33,33,33 }
    ) end,
        { 33,33,33,32,32,32,34, 0, 0,35,32,32,32,33,33,33 },
    function(ctx) checkpoint(ctx) end,        
    function(ctx) rep(ctx, 19,
        { 33,33,33,33,33,32,34, 0, 0,35,32,33,33,33,33,33 }
    ) end,
        { 33,33,33,33,33,32,34,46,47,35,32,33,33,33,33,33 },
        { 33,33,33,33,33,32,34,62,63,35,32,33,33,33,33,33 },
        { 33,33,33,33,33,32,32,32,32,32,32,33,33,33,33,33 },
    function(ctx) rep(ctx, 20,
        { 33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33 }
    ) end

}


-- Builds the gameplay Level.  outputRows must be an array; after the function returns,
-- it will contain 16-element arrays for each row in the level.
function buildCavern(difficulty, cavern) 
    local level = {
        rows = {},
        checkpoints = {},
        speed_changes = {},
        escape_skip_ranges = {},
        escape_enabled = true,
        escape_time = 30,
        escape_speed = 2
    }

    section(level, NOVICE_LEVEL)

    -- close any open skip range left unclosed at end of level
    if level._escape_skip_start then
        add(level.escape_skip_ranges, { from = level._escape_skip_start, to = #level.rows })
    end
    return level
end
