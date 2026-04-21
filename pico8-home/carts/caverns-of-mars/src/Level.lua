

-- TODO generate this into user data at build time.  Be much more efficient
-- with space (should be able to describe each row in two ints), define level 
-- flow with a jump table like (reps, segStart, segLength)


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
-- rowDefs may be a single row (array of  6 numbers) or a rowDefs list.
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

function rocketWave(ctx)
    add(ctx.rocket_waves, #ctx.rows)
end



function generate_right_ledge(ctx, t1, t2, t3)
section(ctx, {
{  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,t1, 0, 2, 1 },
{  1, 0, 0, 0, 0, 0, 0, 0, 0,t2, 0, 2, 1, 1, 1, 1 },
{  1, 0, 0, 0, 0, 0,t3, 0, 2, 1, 1, 1, 1, 1, 1, 1 },
{  1, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
{  1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
{  1, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
})
end

function generate_left_ledge(ctx, t1, t2, t3)
section(ctx, {
{  1, 3,t1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
{  1, 1, 1, 1, 3,t2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
{  1, 1, 1, 1, 1, 1, 1, 3,t3, 0, 0, 0, 0, 0, 0, 1 },
{  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 0, 0, 0, 0, 1 },
{  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1 },
{  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 0, 0, 0, 0, 1 },
})
end

function genOpenTunnel(ctx, rowCount)
    for i=1,rowCount do
        add(ctx.rows, {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 })
    end
end

function genEssCurve(ctx)
section(ctx, {
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
    {  1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1 },
    {  1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1 },
    {  1, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1 },
    {  1, 1, 1, 5, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1 },
    {  1, 1, 5, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1 },
    {  1, 5, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1 },
})
end

function genBumpCurve(ctx)
section(ctx, {
    {  1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 3, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 1, 3, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 1, 5, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 5, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    {  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
})
end

NOVICE_LEVEL = {
    function(ctx) checkpoint(ctx) end,
    function(ctx) rep(ctx, 8,
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    ) end,
    {  3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
    function(ctx) genOpenTunnel(ctx, 12) end,
    function(ctx) generate_left_ledge(ctx,  6,  7,  8) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx,  8,  7,  7) end,
    function(ctx) checkpoint(ctx) end,
    function(ctx) genEssCurve(ctx) end,
    function(ctx) generate_left_ledge(ctx,  8,  6,  7) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx,  8,  8,  7) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_left_ledge(ctx,  8,  7,  8) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx,  8,  8,  8) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_left_ledge(ctx,  6,  6,  6) end,
    function(ctx) genOpenTunnel(ctx, 3) end,
    function(ctx) generate_right_ledge(ctx,  8,  8,  8) end,
    function(ctx) genBumpCurve(ctx) end,
    function(ctx) generate_right_ledge(ctx,  7,  8,  8) end,
    function(ctx) genOpenTunnel(ctx, 8) end,    
    function(ctx) checkpoint(ctx) end,    
    function(ctx) genOpenTunnel(ctx, 8) end,

    function(ctx) rocketWave(ctx) end,
    function(ctx) checkpoint(ctx) end,
    function(ctx) section(ctx, EASY_BASE_SECTION) end
}

-- Describes the pattern of targets that appear during a rocket wave.  Each
-- element in this array describes what appear on one row of the rocket wave:
-- if the targetDef value is 0, do nothing else
-- if the targetDef value is positive, add a rocket at: 8 + 8 * (targetDef value)
-- if the targetDef value is negative, add a fueld rocket at: 8 * (targetDef value)
ROCKET_WAVE = {
    1, -7, 12, 0, 7, 0, 8, 1, 9, 0, 14, 4, 0, -1, 13, 1, 6, -1,
    12, 0, 5, 0, 10, 0, 7, -13, 8, -1, 4, 13, 1, 0, 13, 1, 12, 
    0, 3, -3, 9, 0, 6, -10, 4,0, 8, 0, 10, 0, 2, 0, 10, 13, 
    -13, 13, 6, 0, 13, 0, 1, -4, 4, 0, 9, 1, 11, -5, 3, 0, 
    8, 0, 4, -13, 5, 0, 6, 0, 7, 1, 8, 0, 9, -12, 10, 0, 7, 0,
    2, -3, 13, -9, -7, 8, 8, 0, 11, 0, 3, -12, 5, 0, 12, -10
}

EASY_BASE_SECTION = {
        {  1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1 },    
    function(ctx) rep(ctx, 7, 
        { 11,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,11 }
    ) end,
        { 11,10,10,10, 0, 0, 0, 0, 0, 0, 0, 0,10,10,10,11 },    
    function(ctx) rep(ctx, 15, 
        { 11,11,11,10, 0, 0, 0, 0, 0, 0, 0, 0,10,11,11,11 }
    ) end,
        { 11,11,11,10,10,10,12, 0, 0,13,10,10,10,11,11,11 },
    function(ctx) checkpoint(ctx) end,        
    function(ctx) rep(ctx, 19,
        { 11,11,11,11,11,10,12, 0, 0,13,10,11,11,11,11,11 }
    ) end,
        { 11,11,11,11,11,10,12,46,47,13,10,11,11,11,11,11 },
        { 11,11,11,11,11,10,12,62,63,13,10,11,11,11,11,11 },
        { 11,11,11,11,11,10,10,10,10,10,10,11,11,11,11,11 },
    function(ctx) rep(ctx, 20,
        { 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11 }
    ) end

}

-- Builds the gameplay Level.  outputRows must be an array; after the function returns,
-- it will contain 16-element arrays for each row in the level.
function buildCavern(difficulty, cavern) 
    local level = {
        rows = {},
        checkpoints = {},
        rocket_waves = {},
        escape_time = 30,
    }

    section(level, NOVICE_LEVEL)

    return level
end
