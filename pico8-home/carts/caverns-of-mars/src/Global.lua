-- =============================================
-- Global constants – all tunable gameplay values
-- =============================================

CART_ID = "caverns-of-mars"

-- ship sprite (16x8px)
--[[const]] SPRITE_FLAG        = 1 -- cavern number indicator (8x8)
--[[const]] SPRITE_PLAYER_SHIP = 3
--[[const]] SHIP_WIDTH         = 16   -- sprite width in pixels
--[[const]] SHIP_HEIGHT        = 8   -- sprite height in pixels
--[[const]] SHIP_SPR_W         = 2    -- cells wide passed to spr() (4×8 = 32 ≥ 26)
--[[const]] SHIP_SPR_H         = 1    -- cells tall passed to spr() (2×8 = 16 ≥ 13)


--[[const]] SPRITE_ROCKET       = 16 -- (8x8)
--[[const]] SPRITE_RADAR        = 17 -- (8x8)
--[[const]] SPRITE_FUEL_TANK    = 18 -- (16x8)
--[[const]] SPRITE_FUEL_ROCKET  = 20 -- (16x8)
--[[const]] SPRITE_FUEL_ROCKET2 = 22 -- (16x8)


--[[const]] SPRITE_BASE_BRICK = 32 -- (8x8)
--[[const]] SPRITE_BASE_LIGHT = 33 -- (8x8)
--[[const]] SPRITE_BASE_BRICK_LEFT = 34 -- (8x8)
--[[const]] SPRITE_BASE_BRICK_RIGHT = 35 -- (8x8)



--[[const]] SPRITE_EXPLOSION = { 128, 130, 132, 134, 136, 138, 140, 142 } -- (16x16)

--[[const]] SOUND_SHOOT_CHANNEL = 0
--[[const]] SOUND_SHOOT = 2
--[[const]] SOUND_EXPLOSION_CHANNEL = 1
--[[const]] SOUND_EXPLOSION = 3
--[[const]] SOUND_HUM_CHANNEL = 3
--[[const]] SOUND_HUM_FIRST = 16
--[[const]] SOUND_HUM_LAST = 20
--[[const]] SOUND_ALARM_CHANNEL = 3
--[[const]] SOUND_ALARM = 5


-- Probe offsets from ship top-left, chosen to match the visual silhouette.
-- Avoids the sloped/transparent top corners so those don't cause surprise hits.
local SHIP_PROBES = {
    {7, 0},   -- nose (center-top)
    {3, 3},   -- upper-left body edge
    {12, 3},  -- upper-right body edge
    {0, 4},   -- left wingtip
    {15, 4},  -- right wingtip
    {0, 7},   -- lower-left
    {15, 7},  -- lower-right
}


-- returns true if sprite id s is a square landscape tile (used for outline rendering)
function is_square_tile(s)
    return s==32 or s==33 or s==48 
end
--[[const]] TILE_OUTLINE_COLOR = BLUE

-- Draw a sprite with a 1px black outline by rendering it four times (offset ±1 in
-- each cardinal direction) with all colours remapped to BLACK, then once normally.
function spr_outlined(s, x, y, w, h)
    pal()
    for c = 0, 15 do pal(c, BLACK) end
    spr(s, x,   y-1, w, h)
    spr(s, x,   y+1, w, h)
    spr(s, x-1, y,   w, h)
    spr(s, x+1, y,   w, h)
    pal()
    spr(s, x, y, w, h)
end


function is_target_tile(s)
    return s>=16 and s <= 20
end

function is_reactor_tile(s)
    return s==46 or s==47 or s==62 or s==63
end

ESCAPE_TRIGGER_TEXT = "........enemy destroyed........bomb timer set........escape time "

--[[const]] ESCAPE_SCROLL_SPEED = 1   -- px/frame for reverse escape scroll (same as normal)


--[[const]] SPRITE_LIFE_REMAINING = 2 -- (8x8)


--[[const]] SCORE_FUEL_TANK    = 150
--[[const]] SCORE_FUEL_ROCKET  = 150
--[[const]] SCORE_ROCKET       = 150
--[[const]] SCORE_RADAR        = 200
--[[const]] SCORE_WAVE_ROCKET  = 100   -- SPRITE_ROCKET in a missile wave
--[[const]] SCORE_WAVE_FUEL    = 150   -- SPRITE_FUEL_ROCKET in a missile wave
--[[const]] SCORE_PER_ROW      = 10    -- points awarded per 8px row descended

HIGH_SCORE = 0   -- loaded from cartdata in _init(); 0 until then
DIFFICULTY  = 1  -- difficulty level
CURRENT_CAVERN = 1  -- which cavern the player is about to enter
--[[const]] NUM_CAVERNS = 5  -- total number of caverns; after the last, return to title

-- player lives
--[[const]] PLAYER_LIVES       = 5     -- starting lives
--[[const]] PLAYER_FUEL_MAX    = 99    -- maximum fuel
--[[const]] FUEL_DESCENT_RATE  = 8     -- world pixels of descent per 1 unit of fuel consumed
--[[const]] FUEL_PICKUP_AMT    = 10    -- fuel restored when a fuel tank or fuel rocket is destroyed

-- ship destruction
--[[const]] SPRITE_SHIP_EXPLOSION = 5  -- 16x8 explosion sprite drawn during death pause
--[[const]] DEATH_PAUSE_FRAMES = 30   -- frames to show explosion before respawn/game-over (~5s at 60fps)

-- player starting position (top-left of sprite, horizontally centred)
--[[const]] PLAYER_START_X     = (128 - SHIP_WIDTH) \ 2
--[[const]] PLAYER_START_Y     = 10

-- dpad movement speed (pixels per frame)
--[[const]] PLAYER_SPEED_X     = 2
--[[const]] PLAYER_SPEED_Y     = 1

-- bullets: speed (pixels/frame downward) and fire-rate cooldown (frames)
--[[const]] BULLET_SPEED       = 4
--[[const]] FIRE_COOLDOWN      = 15

-- bullet spawn offsets from ship top-left corner
-- left  gun → ship's left  pixel edge
-- right gun → ship's right pixel edge
-- both  spawn at the bottom row of the sprite (the gun nozzles)
--[[const]] BULLET_LEFT_X      = 0
--[[const]] BULLET_RIGHT_X     = SHIP_WIDTH  - 1
--[[const]] BULLET_SPAWN_Y     = SHIP_HEIGHT - 1

-- scrolling cavern terrain
--[[const]] SCROLL_SPEED       = 1     -- world pixels scrolled upward per frame
--[[const]] TERRAIN_SLICES     = 145   -- slices buffered (must be > 128)
--[[const]] WALL_COLOR         = DARK_PURPLE  -- rock fill colour
--[[const]] WALL_EDGE_COLOR    = BLUE          -- one-pixel highlight on tunnel edges

-- shaft-and-ledge terrain generator
-- Default shaft: both walls are straight vertical lines WALL_INSET px from each screen edge.
-- Ledges alternate left/right. Each ledge has LEDGE_PAD_COUNT horizontal pads separated
-- by rough diagonal ramps, then a sheer face and a single underhang row.
-- Targets are always placed at the midpoint of each pad.
--[[const]] WALL_INSET         = 8     -- default inset of each wall from the screen edge (px)
--[[const]] SHAFT_H_MIN        = 20    -- min rows of straight shaft between ledge sections
--[[const]] SHAFT_H_MAX        = 70    -- max rows of straight shaft between ledge sections
--[[const]] SHAFT_DEFAULT_RATE = 128   -- default wall movement rate (px/row); ≥ screen width = instant arrival
-- ledge geometry (tuning these shapes the look of each ledge)
--[[const]] LEDGE_DIAG_H       = 8     -- rows per diagonal ramp section
--[[const]] LEDGE_DIAG_STEP    = 8     -- pixels the wall moves during the diagonal (gentle slope)
--[[const]] LEDGE_PAD_W        = 18    -- pixels of abrupt horizontal jump INTO each pad (the visible step lip)
--[[const]] LEDGE_PAD_H        = 0     -- rows of vertical face below each step lip
-- per step: the wall advances LEDGE_DIAG_STEP during the ramp + LEDGE_PAD_W at the step lip
-- total displacement = PAD_COUNT*(DIAG_STEP+PAD_W) + DIAG_STEP = 3*20+4 = 64px with defaults
-- minimum corridor after face = (128-2*WALL_INSET) - 64 = 32px = CORR_MIN_W (safe)
--[[const]] LEDGE_PAD_COUNT    = 3     -- pads per ledge (= 3 target shelves per side)
--[[const]] LEDGE_FACE_H       = 16    -- rows for the sheer vertical face after last pad
-- diagonal roughness (flat pads and default shaft are always perfectly straight)
--[[const]] LEDGE_JAGGY_AMT    = 2     -- ±pixel roughness applied only to ramp phases
--[[const]] CORR_MIN_W         = 24    -- minimum open corridor width (safety clamp)

-- player collision
--[[const]] PLAYER_COLL_PAD    = 0     -- shrink player hitbox by this many px per side

-- section-based target placement
-- Three targets are always placed at the mid-row of every horizontal pad in a ledge.
-- Left-ledge pads: targets cluster near the left (ledge) wall.
-- Right-ledge pads: targets cluster near the right (ledge) wall.
-- TARGET_WALL_MARGIN keeps targets clear of wall edges.
--[[const]] TARGET_COUNT       = 1       -- one target per pad, centred on the step surface
--[[const]] TARGET_SPACING     = 20      -- pixels between target sprite centres
--[[const]] TARGET_HIT_R       = 5       -- bullet collision radius (pixels)
--[[const]] TARGET_WALL_MARGIN = 10      -- min px from ledge wall to outermost target
-- target type ids (mapped to sprites below)
--[[const]] TTYPE_FUEL         = 1       -- SPRITE_FUEL_TANK  (16×8)
--[[const]] TTYPE_NODE         = 2       -- SPRITE_RADAR      (8×8)
--[[const]] TTYPE_ROCKET       = 3       -- SPRITE_ROCKET     (8×8)
-- spr() draw offsets: centre the sprite on the target x,y position
--[[const]] TARGET_SPR_OX_SM   = 4       -- half-width of 8×8 sprites
--[[const]] TARGET_SPR_OX_LG   = 8       -- half-width of 16×8 sprite (FUEL_TANK)
--[[const]] TARGET_SPR_OY      = 7       -- spr() Y draw offset: bottom-aligns sprite to step surface

-- missile wave sections
--[[const]] MISSILE_WAVE_SPACING = 9     -- world rows between consecutive wave entries
--[[const]] TTYPE_WAVE           = 4     -- wave target; uses tgt.wave_spr / tgt.wave_spr_w directly
--[[const]] WAVE_DRAW_LEAD       = 8     -- rows below screen where wave sprites begin rendering (scroll-in effect)
--[[const]] WAVE_MISSILE_SPEED   = SCROLL_SPEED  -- extra world-rows/frame wave missiles travel toward the player
                                                  -- (screen speed = SCROLL_SPEED + WAVE_MISSILE_SPEED = 2×)

-- status bar (bottom of screen)
-- The bottom STATUS_BAR_H pixels are reserved; all gameplay drawing is clipped above GAMEPLAY_H.
--[[const]] STATUS_BAR_H        = 16    -- pixel height of the status bar
--[[const]] GAMEPLAY_H          = 128 - STATUS_BAR_H  -- exclusive bottom boundary for gameplay content
--[[const]] STATUS_BAR_COLOR    = WHITE  -- solid background fill
-- lives icons (centred on bottom row of bar)
--[[const]] STATUS_LIFE_SPR_Y   = 120   -- y of life icons
--[[const]] STATUS_LIFE_GAP     = 9     -- pixels between icon origins (8px sprite + 1px gap)
-- score / fuel text
--[[const]] STATUS_FUEL_Y       = GAMEPLAY_H + 2  -- y of fuel line (top row)
--[[const]] STATUS_SCORE_Y      = GAMEPLAY_H + 9  -- y of score line (bottom row, left-aligned)
