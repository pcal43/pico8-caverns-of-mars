-- =============================================
-- Global constants – all tunable gameplay values
-- =============================================



--[[const]] CART_ID            = "caverns-of-mars"
--[[const]] FPS                = 60

--[[const]] INVULNERABILITY    = true

-- ship sprite (16x8px)
--[[const]] SHIP_WIDTH         = 16   -- sprite width in pixels
--[[const]] SHIP_HEIGHT        = 8   -- sprite height in pixels
--[[const]] SHIP_SPR_W         = 2    -- cells wide passed to spr() (4×8 = 32 ≥ 26)
--[[const]] SHIP_SPR_H         = 1    -- cells tall passed to spr() (2×8 = 16 ≥ 13)


--[[const]] SPRITE_FUEL_ROCKET  = 20 -- (16x8)
--[[const]] SPRITE_FUEL_ROCKET2 = 22 -- (16x8)


--[[const]] SPRITE_PLAYER_SHIP    = 26
--[[const]] SPRITE_SHIP_EXPLOSION = 28  -- 16x8 explosion sprite drawn during death pause
--[[const]] SPRITE_LIFE_REMAINING = 30 -- (8x8)
--[[const]] SPRITE_FLAG           = 31 -- cavern number indicator (8x8)



--[[const]] SPRITE_WALL                 = 1
--[[const]] SPRITE_CORNER_LOWER_RIGHT   = 2
--[[const]] SPRITE_CORNER_LOWER_LEFT    = 3
--[[const]] SPRITE_CORNER_UPPER_RIGHT   = 4
--[[const]] SPRITE_CORNER_UPPER_LEFT    = 5
--[[const]] SPRITE_ROCKET               = 6
--[[const]] SPRITE_RADAR                = 7
--[[const]] SPRITE_FUEL_TANK            = 8
--[[const]] SPRITE_BASE_BRICK           = 10
--[[const]] SPRITE_BASE_LIGHT           = 11
--[[const]] SPRITE_BASE_BRICK_LEFT      = 12
--[[const]] SPRITE_BASE_BRICK_RIGHT     = 13

SPRITE_EXPLOSION = { 128, 130, 132, 134, 136, 138, 140, 142 } -- (16x16)

--[[const]] SOUND_SHOOT_CHANNEL = 0
--[[const]] SOUND_SHOOT = 2
--[[const]] SOUND_EXPLOSION_CHANNEL = 1
--[[const]] SOUND_EXPLOSION = 3
--[[const]] SOUND_HUM_CHANNEL = 3
--[[const]] SOUND_HUM_FIRST = 16
--[[const]] SOUND_HUM_LAST = 20
--[[const]] SOUND_ALARM_CHANNEL = 3
--[[const]] SOUND_ALARM = 5

--[[const]] TILE_OUTLINE_COLOR = BLUE


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
    return s==32 or s==33 or s==SPRITE_WALL 
end

function is_target_tile(s)
    return s == SPRITE_ROCKET or s == SPRITE_RADAR or s == SPRITE_FUEL_TANK
end

function is_reactor_tile(s)
    return s==46 or s==47 or s==62 or s==63
end

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




--[[const]] SCORE_FUEL_TANK    = 150
--[[const]] SCORE_FUEL_ROCKET  = 150
--[[const]] SCORE_ROCKET       = 150
--[[const]] SCORE_RADAR        = 200
--[[const]] SCORE_WAVE_ROCKET  = 100   -- SPRITE_ROCKET in a missile wave
--[[const]] SCORE_WAVE_FUEL    = 150   -- SPRITE_FUEL_ROCKET in a missile wave
--[[const]] SCORE_PER_ROW      = 10    -- points awarded per 8px row descended

--[[const]] NUM_CAVERNS        = 5     -- total number of caverns; after the last, return to title

-- player lives
--[[const]] PLAYER_LIVES       = 5     -- starting lives
--[[const]] PLAYER_FUEL_MAX    = 99    -- maximum fuel
--[[const]] FUEL_DESCENT_RATE  = 8     -- world pixels of descent per 1 unit of fuel consumed
--[[const]] FUEL_PICKUP_AMT    = 10    -- fuel restored when a fuel tank or fuel rocket is destroyed

-- ship destruction

--[[const]] DEATH_PAUSE_FRAMES   = 1 * FPS  -- frames to show explosion before respawn/game-over (~5s at 60fps)

-- player starting position (top-left of sprite, horizontally centred)
--[[const]] PLAYER_START_X     = (128 - SHIP_WIDTH) \ 2
--[[const]] PLAYER_START_Y     = 10

--[[const]] DESCENT_SPEED_FACTOR = 1
--[[const]] ESCAPE_SPEED_FACTOR  = 1.5

-- dpad movement speed (pixels per frame)
--[[const]] PLAYER_SPEED_X     = 60 / FPS -- pixels-per-frame
--[[const]] PLAYER_SPEED_Y     = 30 / FPS     -- pixels-per-frame
--[[const]] BULLET_SPEED       = 120 / FPS    -- pixels-per-frame

-- bullet spawn offsets from ship top-left corner
-- left  gun → ship's left  pixel edge
-- right gun → ship's right pixel edge
-- both  spawn at the bottom row of the sprite (the gun nozzles)
--[[const]] BULLET_LEFT_X      = 0
--[[const]] BULLET_RIGHT_X     = SHIP_WIDTH  - 1
--[[const]] BULLET_SPAWN_Y     = SHIP_HEIGHT - 1



-- scrolling cavern terrain
--[[const]] SCROLL_SPEED             = 30 / FPS       -- cavern scroll speed in pixels-per-frame
--[[const]] ROCKET_WAVE_SCROLL_SPEED = 90 / FPS  -- rocket wave scroll speed (3× normal)
--[[const]] ROCKET_WAVE_SPACING      = 12        -- virtual pixels between successive rocket spawns

--[[const]] TERRAIN_SLICES     = 145   -- slices buffered (must be > 128)
--[[const]] WALL_EDGE_COLOR    = BLUE         -- one-pixel highlight on tunnel edges

--[[const]] TTYPE_FUEL         = 1       -- SPRITE_FUEL_TANK  (16×8)
--[[const]] TTYPE_NODE         = 2       -- SPRITE_RADAR      (8×8)
--[[const]] TTYPE_ROCKET       = 3       -- SPRITE_ROCKET     (8×8)
-- spr() draw offsets: centre the sprite on the target x,y position
--[[const]] TARGET_SPR_OX_SM   = 4       -- half-width of 8×8 sprites
--[[const]] TARGET_SPR_OX_LG   = 8       -- half-width of 16×8 sprite (FUEL_TANK)
--[[const]] TARGET_SPR_OY      = 7       -- spr() Y draw offset: bottom-aligns sprite to step surface

-- missile wave sections
--[[const]] TTYPE_WAVE           = 4     -- wave target; uses tgt.wave_spr / tgt.wave_spr_w directly

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


--[[const]] TICKER_SPEED = 60 / FPS

--[[const]] ROW_HEIGHT = 8 -- height of each cavern row, in pixels




-- mutable global state

-- Player movement and scrolling are faster during escape than 
-- during descent.  Track if globally so transition screens can
-- also reflect it.
speedFactor = DESCENT_SPEED_FACTOR
score  = 0
highScore = 0   -- loaded from cartdata in _init(); 0 until then
difficulty  = 1  -- difficulty level
currentCavern = 1  -- which cavern the player is about to enter
