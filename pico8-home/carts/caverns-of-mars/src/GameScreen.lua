-- =============================================
-- GameScreen – Caverns of Mars prototype, step 2
-- Scrolling cavern terrain, player + bullets,
-- wall collision detection.
-- =============================================

-- game states
local STATE_PLAYING  = 1
local STATE_DYING    = 2   -- ship destroyed; showing explosion animation
local STATE_CRASHED  = 3   -- game over (no lives left)
local STATE_ESCAPE   = 4   -- reactor hit; ticker intro playing
local STATE_ESCAPING = 5   -- active reverse scroll; player must reach level top
local STATE_ESCAPE_FLY_OFF = 6  -- terrain stopped; ship flies off top of screen

-- score awarded per target ttype; TTYPE_WAVE entries are keyed by wave_spr
local SCORE_BY_TTYPE = {
    [TTYPE_FUEL]   = SCORE_FUEL_TANK,
    [TTYPE_NODE]   = SCORE_RADAR,
    [TTYPE_ROCKET] = SCORE_ROCKET,
}
local SCORE_BY_WAVE_SPR = {
    [SPRITE_ROCKET]      = SCORE_WAVE_ROCKET,
    [SPRITE_FUEL_ROCKET] = SCORE_WAVE_FUEL,
}

GameScreen = {}

function GameScreen.new()
    local self = {}
    setmetatable(self, { __index = GameScreen })
    self:init()
    return self
end

-- Full initialisation – called by new() and on game-over restart.
-- Resets everything including terrain, score, and lives.
function GameScreen:init()
    self.isDone     = false
    self.isEscaped  = false
    self.isGameOver = false
    self.hum_snd    = -1
    self.state  = STATE_PLAYING
    self.lives  = PLAYER_LIVES
    self.score  = 0
    self.bullets    = {}
    self.targets    = {}   -- alive target objects placed by section rules
    self.explosions = {}   -- active target explosion animations
    self.frame      = 0    -- global frame counter for synced animations
    self.respawn_wy = 0    -- world-y of the last crossed checkpoint
    self.escapeTime = 0
    self.escape_tick = 0
    self:respawnPlayer()
    self:initTerrain()
end

-- Respawn the player in place – called after a death when lives remain.
function GameScreen:respawn()
    self.bullets    = {}
    self.explosions = {}
    if self.died_while_escaping then
        -- during escape: checkpoint row sits at the bottom of the screen
        local wy = max(0, self.respawn_wy - GAMEPLAY_H)
        self:resetTerrainAt(wy)
        self:prepareEscapeTargets()
        self.scroll_multiplier = self.levelDef.escape_speed
        self.escapeTime  = self.levelDef.escape_time
        self.escape_tick = 0
        self.state = STATE_ESCAPING
        self:respawnPlayer()
        self.player.y = GAMEPLAY_H - SHIP_HEIGHT
    else
        -- during descent: checkpoint row sits at the top of the screen
        self:resetTerrainAt(self.respawn_wy)
        self.state = STATE_PLAYING
        self:respawnPlayer()
    end
end

-- Reset just the player ship fields (shared by init and respawn).
function GameScreen:respawnPlayer()
    self.player = {
        x        = PLAYER_START_X,
        y        = PLAYER_START_Y,
        cooldown = 0,
    }
    self.fuel         = PLAYER_FUEL_MAX
    self.fuel_wy_last = self.terrain_base_wy or 0
end



-- =============================================
-- Tile-based terrain engine
-- =============================================
-- buildCavern() (Level.lua) produces a flat array of row arrays, each 16 sprite IDs.
-- The engine indexes into that array, wrapping at the end, and maintains a
-- rolling pixel-row buffer (TERRAIN_SLICES deep) for drawing and collision.
-- Each buffered entry: {sprites={s1..s16}, spr_phase=0..7}
--   spr_phase – pixel offset within the 8-px band (0=top of sprite, trigger draw).

function GameScreen:initTerrain()
    self.scroll_frac     = 0
    self.terrain_base_wy = 0
    self.terrain         = {}
    self.levelDef = buildCavern(DIFFICULTY, CURRENT_CAVERN)
    self.level_rows      = self.levelDef.rows
    self:extractTargets()
    -- save pristine target list so resetTerrainAt can restore targets
    self.target_defs = {}
    for _, t in ipairs(self.targets) do
        add(self.target_defs, {spr=t.spr, spr_w=t.spr_w, ttype=t.ttype, x=t.x, world_y=t.world_y})
    end
    -- stop scrolling when the last authored row reaches screen-y 0
    self.scroll_stop_wy  = (#self.level_rows - 1) * 8
    -- copy authored checkpoints (row index → world-y pixel)
    self.checkpoints = {}
    for _, ri in ipairs(self.levelDef.checkpoints) do
        add(self.checkpoints, ri * 8)
    end
    self.next_cp_idx = 1
    -- copy authored speed changes (row index → world-y pixel)
    self.speed_changes = {}
    for _, sc in ipairs(self.levelDef.speed_changes) do
        add(self.speed_changes, { wy = sc.row_idx * 8, mult = sc.mult })
    end
    self.next_speed_idx   = 1
    self.scroll_multiplier = 1
    self.gen = {
        row_idx = 1,   -- index into level_rows (wraps)
        row_py  = 0,   -- pixel y within current authored row (0..7)
        next_wy = 0,   -- world-y of the next pixel row to generate
    }
    for _ = 1, TERRAIN_SLICES do
        add(self.terrain, self:nextRowFromGen())
    end
end

-- Restart the terrain engine from world-y wy (must be a checkpoint boundary).
-- Rebuilds level_rows and targets from scratch; preserves checkpoints and scroll_stop_wy.
function GameScreen:resetTerrainAt(wy)
    self.scroll_frac     = 0
    self.terrain_base_wy = wy
    -- terrain (level_rows, scroll_stop_wy) is immutable — no rebuild needed
    -- targets must be reset so destroyed ones reappear on respawn
    self.targets = {}
    for _, def in ipairs(self.target_defs) do
        add(self.targets, {spr=def.spr, spr_w=def.spr_w, ttype=def.ttype, x=def.x, world_y=def.world_y, alive=true})
    end
    -- reset next_cp_idx and advance past checkpoints already behind wy
    self.next_cp_idx = 1
    while self.next_cp_idx <= #self.checkpoints and
          self.checkpoints[self.next_cp_idx] <= wy do
        self.next_cp_idx += 1
    end
    -- reset speed multiplier and advance past speed changes already behind wy
    self.scroll_multiplier = 1
    self.next_speed_idx    = 1
    while self.next_speed_idx <= #self.speed_changes and
          self.speed_changes[self.next_speed_idx].wy <= wy do
        self.scroll_multiplier = self.speed_changes[self.next_speed_idx].mult
        self.next_speed_idx   += 1
    end
    local row_idx = flr(wy / 8) + 1
    self.gen = {
        row_idx = row_idx,
        row_py  = 0,
        next_wy = wy,
    }
    self.terrain = {}
    for _ = 1, TERRAIN_SLICES do
        add(self.terrain, self:nextRowFromGen())
    end
end

-- Pull one pixel row from level_rows. Each authored row occupies 8 pixel ticks.
function GameScreen:nextRowFromGen()
    local g  = self.gen
    g.next_wy += 1
    if g.row_idx > #self.level_rows then
        return {sprites=nil, spr_phase=0}
    end
    local row       = self.level_rows[g.row_idx]
    local spr_phase = g.row_py
    g.row_py += 1
    if g.row_py >= 8 then
        g.row_py  = 0
        g.row_idx += 1
    end
    return {sprites=row, spr_phase=spr_phase}
end

-- Scroll terrain backwards (level played in reverse: terrain moves DOWN).
-- Each pixel tick: drop the last (bottom) buffer row, prepend a new row
-- from level_rows at the top, decrement terrain_base_wy.
function GameScreen:scrollTerrainReverse()
    if self.terrain_base_wy <= 0 then return end
    self.scroll_frac += ESCAPE_SCROLL_SPEED * self.scroll_multiplier
    while self.scroll_frac >= 1 do
        self.scroll_frac     -= 1
        self.terrain_base_wy -= 1
        -- skip over rows excluded from the escape sequence
        local row_idx = flr(self.terrain_base_wy / 8) + 1
        for _, range in ipairs(self.levelDef.escape_skip_ranges) do
            if row_idx >= range.from and row_idx <= range.to then
                self.terrain_base_wy = (range.from - 1) * 8
                row_idx = range.from - 1
                break
            end
        end
        if self.terrain_base_wy % 8 == 0 then
            self.score += SCORE_PER_ROW
        end
        local phase   = self.terrain_base_wy % 8
        local sprites = (row_idx >= 1 and row_idx <= #self.level_rows)
                        and self.level_rows[row_idx] or nil
        deli(self.terrain, #self.terrain)
        add(self.terrain, {sprites=sprites, spr_phase=phase}, 1)
        if self.terrain_base_wy <= 0 then
            self.scroll_frac = 0
            break
        end
    end
end

-- Advance scroll_frac by SCROLL_SPEED.
-- Stops once the last authored row has reached screen-y 0.
function GameScreen:scrollTerrain()
    if self.terrain_base_wy >= self.scroll_stop_wy then return end
    self.scroll_frac += SCROLL_SPEED * self.scroll_multiplier
    while self.scroll_frac >= 1 do
        self.scroll_frac     -= 1
        self.terrain_base_wy += 1
        if self.terrain_base_wy % 8 == 0 then
            self.score += SCORE_PER_ROW
        end
        -- advance the respawn checkpoint when the player's world-y crosses it
        while self.next_cp_idx <= #self.checkpoints and
              self.terrain_base_wy + self.player.y >= self.checkpoints[self.next_cp_idx] do
            self.respawn_wy  = self.checkpoints[self.next_cp_idx]
            self.next_cp_idx += 1
        end
        -- apply speed changes when the row scrolls into view at the bottom
        while self.next_speed_idx <= #self.speed_changes and
              self.terrain_base_wy + GAMEPLAY_H >= self.speed_changes[self.next_speed_idx].wy do
            self.scroll_multiplier = self.speed_changes[self.next_speed_idx].mult
            self.next_speed_idx   += 1
        end
        deli(self.terrain, 1)
        add(self.terrain, self:nextRowFromGen())
        if self.terrain_base_wy >= self.scroll_stop_wy then
            self.scroll_frac = 0
            break
        end
    end
end

-- Return the terrain row for screen-y sy.
function GameScreen:rowAt(sy)
    local idx = -flr(-sy - self.scroll_frac - 1)
    if idx >= 1 and idx <= #self.terrain then
        return self.terrain[idx]
    end
    return nil
end

-- Return true if pixel column cx (0-7 within an 8px tile) is solid for sprite sid.
-- Full tiles are always solid; half-bricks only cover their respective 4px.
local function sid_hits_px(sid, cx)
    if not sid or sid == 0 then return false end
    if sid == SPRITE_BASE_BRICK_LEFT  then return cx < 4 end
    if sid == SPRITE_BASE_BRICK_RIGHT then return cx >= 4 end
    return true
end

-- Return true if pixel x falls on a solid tile in row r.
local function tile_solid(r, px)
    if not r or not r.sprites then return false end
    local sid = r.sprites[flr(px / 8) + 1]
    return sid_hits_px(sid, px % 8)
end

-- =============================================
-- Player movement (dpad) and shooting (X)
-- =============================================

-- btn() is checked every frame for held input → smooth continuous motion.
-- mid() clamps so the ship never exits the 128×128 screen.
function GameScreen:movePlayer()
    local p = self.player
    if btn(BUTTON_LEFT)  then p.x -= PLAYER_SPEED_X end
    if btn(BUTTON_RIGHT) then p.x += PLAYER_SPEED_X end
    if btn(BUTTON_UP)    then p.y -= PLAYER_SPEED_Y end
    if btn(BUTTON_DOWN)  then p.y += PLAYER_SPEED_Y end
    p.x = mid(0, p.x, 128 - SHIP_WIDTH)
    p.y = mid(0, p.y, GAMEPLAY_H - SHIP_HEIGHT)
end

-- Two bullets spawn simultaneously from the bottom-left and bottom-right
-- edges of the ship sprite. Player cannot fire again until both bullets expire.
function GameScreen:handleShooting()
    local p = self.player
    if btn(BUTTON_X) and #self.bullets == 0 then
        local by = p.y + BULLET_SPAWN_Y
        add(self.bullets, {x = p.x + BULLET_LEFT_X,  y = by})
        add(self.bullets, {x = p.x + BULLET_RIGHT_X, y = by})
        sfx(SOUND_SHOOT, SOUND_SHOOT_CHANNEL)
    end
end

-- =============================================
-- Bullet update

-- Spawn a target explosion at the given world position.
local function spawn_explosion(explosions, x, world_y)
    add(explosions, { x=x, world_y=world_y })
    sfx(SOUND_EXPLOSION, SOUND_EXPLOSION_CHANNEL)
end
-- =============================================
-- Bullets travel downward. Destroyed on hitting a solid tile.
function GameScreen:updateBullets()
    local live = {}
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    for b in all(self.bullets) do
        b.y += BULLET_SPEED
        if b.y < GAMEPLAY_H and not tile_solid(self:rowAt(b.y), b.x) then
            local hit = false
            for tgt in all(self.targets) do
                if tgt.alive then
                    local tsy = flr((tgt.world_y - bwy) - sf)
                    local hw  = tgt.spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                    if b.x >= tgt.x - hw and b.x <= tgt.x + hw - 1
                    and b.y >= tsy - TARGET_SPR_OY and b.y <= tsy then
                        tgt.alive  = false
                        self.score += SCORE_BY_TTYPE[tgt.ttype] or 0
                        if tgt.ttype == TTYPE_FUEL then
                            self.fuel = mid(0, self.fuel + 25, PLAYER_FUEL_MAX)
                        end
                        spawn_explosion(self.explosions, tgt.x, tgt.world_y)
                        hit = true
                        break
                    end
                end
            end
            if not hit then add(live, b) end
        end
    end
    self.bullets = live
end

-- Scan level_rows for target-tile sprites, register them in self.targets,
-- and zero them out so they don't render as solid terrain.
function GameScreen:extractTargets()
    for i = 1, #self.level_rows do
        local row = self.level_rows[i]
        for j = 1, 16 do
            local s = row[j]
            if s and is_target_tile(s) and s != 19 and s != 21 then
                local ttype, spr_w
                if     s == 16 then ttype = TTYPE_ROCKET ; spr_w = 1
                elseif s == 17 then ttype = TTYPE_NODE   ; spr_w = 1
                elseif s == 18 or s == 20 then ttype = TTYPE_FUEL ; spr_w = 2
                end
                if ttype then
                    local hw = spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                    local x_off = spr_w == 1 and 4 or 0
                    add(self.targets, {
                        spr     = s,
                        spr_w   = spr_w,
                        ttype   = ttype,
                        x       = (j-1)*8 + hw + x_off,
                        world_y = (i-1)*8 + 7,
                        alive   = true,
                    })
                    local clean = {}
                    for k = 1, 16 do clean[k] = row[k] end
                    clean[j] = 0
                    if spr_w == 2 and j < 16 and (row[j+1] == s+1) then
                        clean[j+1] = 0
                    end
                    self.level_rows[i] = clean
                    row = clean
                end
            end
        end
    end
end

function GameScreen:updateEngineHum()
    local num_sounds = SOUND_HUM_LAST - SOUND_HUM_FIRST + 1
    if self.state == STATE_PLAYING
    or self.state == STATE_ESCAPE
    or self.state == STATE_ESCAPING
    or self.state == STATE_ESCAPE_FLY_OFF then
        -- divide GAMEPLAY_H into equal bands; clamp ship y to [0, GAMEPLAY_H-1]
        local band = flr(mid(0, self.player.y, GAMEPLAY_H - 1) / GAMEPLAY_H * num_sounds)
        local snd  = SOUND_HUM_FIRST + band
        if snd != self.hum_snd then
            self.hum_snd = snd
            sfx(snd, SOUND_HUM_CHANNEL, 0, -1)  -- loop until replaced
        end
    else
        if self.hum_snd != -1 then
            self.hum_snd = -1
            sfx(-1, SOUND_HUM_CHANNEL)  -- stop hum
        end
    end
end


function GameScreen:checkPlayerCollision()
    local p = self.player
    for _, probe in ipairs(SHIP_PROBES) do
        local sx = p.x + probe[1]
        local sy = p.y + probe[2]
        local r  = self:rowAt(sy)
        if r and r.sprites then
            local sid = r.sprites[flr(sx / 8) + 1]
            if sid_hits_px(sid, sx % 8) then
                if is_reactor_tile(sid) and self.state == STATE_PLAYING then
                    self:triggerEscape()
                elseif not is_reactor_tile(sid) then
                    self:shipDestroyed()
                end
                return
            end
        end
    end
end

-- Check whether the player's padded bounding box overlaps any alive target sprite.
-- Wide targets (TTYPE_FUEL, 16-px-wide wave sprites) use TARGET_SPR_OX_LG; all others
-- use TARGET_SPR_OX_SM.  Vertically, every target sprite is bottom-aligned to its row
-- via TARGET_SPR_OY so the sprite occupies rows [tsy-TARGET_SPR_OY .. tsy].
function GameScreen:checkTargetCollision()
    local p   = self.player
    local sx1 = p.x + PLAYER_COLL_PAD
    local sx2 = p.x + SHIP_WIDTH  - 1 - PLAYER_COLL_PAD
    local sy1 = p.y + PLAYER_COLL_PAD
    local sy2 = p.y + SHIP_HEIGHT - 1 - PLAYER_COLL_PAD
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    for tgt in all(self.targets) do
        if tgt.alive then
            local hw  = ((tgt.ttype == TTYPE_FUEL)
                         or (tgt.ttype == TTYPE_WAVE and tgt.wave_spr_w == 2))
                        and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
            local tsy = flr((tgt.world_y - bwy) - sf)
            if sx1 <= tgt.x + hw - 1
            and sx2 >= tgt.x - hw
            and sy1 <= tsy
            and sy2 >= tsy - TARGET_SPR_OY then
                self:shipDestroyed()
                return
            end
        end
    end
end

-- Consume fuel based on descent distance (world pixels scrolled since last check).
-- Every FUEL_DESCENT_RATE pixels burns 1 unit. Fuel is clamped to [0, PLAYER_FUEL_MAX].
-- Reaching zero destroys the ship via the normal lives/respawn flow.
function GameScreen:updateFuel()
    local traveled = abs(self.terrain_base_wy - self.fuel_wy_last)
    local burn = flr(traveled / FUEL_DESCENT_RATE)
    if burn > 0 then
        -- advance fuel_wy_last in direction of travel
        if self.terrain_base_wy >= self.fuel_wy_last then
            self.fuel_wy_last += burn * FUEL_DESCENT_RATE
        else
            self.fuel_wy_last -= burn * FUEL_DESCENT_RATE
        end
        self.fuel = mid(0, self.fuel - burn, PLAYER_FUEL_MAX)
        if self.fuel == 0 then
            -- treat fuel exhaustion as a crash: reuse lives/respawn logic
            self:shipDestroyed()
        end
    end
end

-- =============================================
-- Update
-- =============================================

-- Called whenever the ship is destroyed (wall, fuel, etc.).
-- Decrements lives, records death position, and enters the dying animation state.
-- Actual respawn or game-over is deferred until the animation timer expires.
function GameScreen:shipDestroyed()
    sfx(SOUND_EXPLOSION, SOUND_EXPLOSION_CHANNEL)
    self.lives -= 1
    self.death_x            = self.player.x
    self.death_y            = self.player.y
    self.death_timer        = DEATH_PAUSE_FRAMES
    self.died_while_escaping = (self.state == STATE_ESCAPING)
    self.state              = STATE_DYING
end

-- Reactor collision: freeze scrolling and input, begin escape sequence.
function GameScreen:triggerEscape()
    self.state = STATE_ESCAPE
    self.scroll_multiplier = self.levelDef.escape_speed
    self.ticker_msgs = {
        "enemy destroyed",
        "bomb timer set",
        "escape time "..self.levelDef.escape_time,
    }
    self.ticker_idx   = 1
    self.ticker_x     = 128
    self.ticker_hold  = 0
    sfx(SOUND_ALARM, SOUND_ALARM_CHANNEL, 0, -1)
end

-- Prepare targets for escape mode:
-- TTYPE_NODE (radar) targets are all restored alive; all other types are removed.
function GameScreen:prepareEscapeTargets()
    local kept = {}
    for tgt in all(self.targets) do
        if tgt.ttype == TTYPE_NODE then
            tgt.alive = true
            add(kept, tgt)
        end
    end
    self.targets = kept
end

function GameScreen:update()    
    if self.state == STATE_PLAYING then
        self:movePlayer()
        self:handleShooting()
        self:updateBullets()
        self:updateExplosions()
        self:scrollTerrain()
        self:checkPlayerCollision()
        self:checkTargetCollision()
        self:updateFuel()
        self.frame += 1
    elseif self.state == STATE_DYING then
        -- count down the death pause; then respawn or end the game
        self.death_timer -= 1
        if self.death_timer <= 0 then
            if self.lives > 0 then
                self:respawn()
            else
                self.isGameOver = true
                self.state  = STATE_CRASHED
                self.isDone = true
            end
        end
    elseif self.state == STATE_ESCAPE then
        -- scrolling frozen, player input ignored
        self:updateExplosions()
        -- multi-message ticker: each message scrolls to centre, holds, then advances
        local msg  = self.ticker_msgs[self.ticker_idx]
        local centre_x = (128 - #msg * 8) \ 2
        if self.ticker_x > centre_x then
            self.ticker_x = max(centre_x, self.ticker_x - 2)
        else
            self.ticker_hold += 1
            if self.ticker_hold >= 40 then
                self.ticker_idx  += 1
                self.ticker_x    = 128
                self.ticker_hold = 0
                if self.ticker_idx > #self.ticker_msgs then
                    -- all messages shown: start escaping
                    sfx(-1, SOUND_ALARM_CHANNEL)
                    self:prepareEscapeTargets()
                    self.escapeTime = self.levelDef.escape_time
                    self.escape_tick = 0
                    self.state = STATE_ESCAPING
                end
            end
        end
        self.frame += 1
    elseif self.state == STATE_ESCAPING then
        -- reverse scroll: terrain moves down, player must reach level top
        self.escape_tick += 1
        if self.escape_tick >= 30 then
            self.escape_tick = 0
            self.escapeTime = max(0, self.escapeTime - 1)
        end
        self:movePlayer()
        self:updateBullets()
        self:updateExplosions()
        self:scrollTerrainReverse()
        self:checkPlayerCollision()
        if self.terrain_base_wy <= 0 then
            self.state = STATE_ESCAPE_FLY_OFF
        end
        self.frame += 1
    elseif self.state == STATE_ESCAPE_FLY_OFF then
        -- terrain is frozen; ship flies straight up until fully off screen
        self.player.y -= PLAYER_SPEED_Y
        if self.player.y + SHIP_HEIGHT <= 0 then
            self.isEscaped = true
            self.isDone    = true
        end
        self.frame += 1
    end
    self:updateEngineHum()
end
-- =============================================

function GameScreen:draw()
    cls(BLACK)
    self:drawTerrain()
    self:drawTileOutlines()
    self:drawTargets()
    self:drawExplosions()
    self:drawBullets()
    self:drawShip()
    self:drawStatusBar()
end

-- Advance explosion animations and remove any that have scrolled off the top.
function GameScreen:updateExplosions()
    local bwy  = self.terrain_base_wy
    local sf   = self.scroll_frac
    local live = {}
    for e in all(self.explosions) do
        local sy = flr((e.world_y - bwy) - sf)
        if sy > -16 then
            add(live, e)
        end
    end
    self.explosions = live
end

-- Draw active explosions: 16x16, centered horizontally, bottom-aligned to target.
-- All explosions share the same animation frame (global self.frame % 15 ping-pong).
function GameScreen:drawExplosions()
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    local pos = self.frame % 15
    local fi  = pos < 8 and pos + 1 or 15 - pos + 1
    local s   = SPRITE_EXPLOSION[fi]
    for e in all(self.explosions) do
        local sy = flr((e.world_y - bwy) - sf)
        spr(s, e.x - 8, sy - 15, 2, 2)
    end
end

function GameScreen:drawTargets()
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    clip(0, 0, 128, GAMEPLAY_H)
    local flash = flr(time()*8)
    if self.state == STATE_ESCAPE or self.state == STATE_ESCAPING then
        local phase = flash % 4
        if     phase == 0 then pal(YELLOW, BROWN)
        elseif phase == 1 then pal(YELLOW, ORANGE)
        elseif phase == 3 then pal(YELLOW, ORANGE) end
    elseif flash % 2 == 0 then
        pal(YELLOW, WHITE)
    end
    for tgt in all(self.targets) do
        if tgt.alive then
            local tsy = flr((tgt.world_y - bwy) - sf)
            if tsy >= 0 and tsy - TARGET_SPR_OY < GAMEPLAY_H then
                local ox = tgt.spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                local draw_spr = tgt.spr
                if tgt.spr == SPRITE_FUEL_ROCKET and flr(self.frame / 5) % 2 == 1 then
                    draw_spr = SPRITE_FUEL_ROCKET2
                end
                spr(draw_spr, tgt.x - ox, tsy - TARGET_SPR_OY, tgt.spr_w, 1)
            end
        end
    end
    pal()
    clip()
end

-- Draw 1px blue outlines on the edges of SQUARE_TILES that face an empty tile.
-- Iterates over sprite bands (spr_phase==0 entries); for each empty tile checks
-- its 4 orthogonal neighbours. Lines extend 1px beyond the tile boundary each
-- end so that corners meet cleanly.
-- Draw 1px outlines on SQUARE_TILES edges that face empty (sprite-0) space.
-- Iterates spr_phase==0 band-top entries. For each solid SQUARE_TILE checks
-- all 4 neighbours; draws into the empty neighbour's pixel (not the solid tile).
function GameScreen:drawTileOutlines()
    local t  = self.terrain
    local sf = self.scroll_frac
    for i = 1, #t do
        local r = t[i]
        if (r.spr_phase == 0 or i == 1) and r.sprites then
            local sy = flr((i - 1) - sf) - r.spr_phase  -- band top y
            if sy >= GAMEPLAY_H then break end
            -- sprites of the row above (spr_phase 7 of prev band) and below
                local asp = (i > 1)     and t[i-1].sprites or nil
                local bsp = (i+8 <= #t) and t[i+8].sprites or nil
                for j = 0, 15 do
                    local s = r.sprites[j+1]
                    if s and s != 0 and is_square_tile(s) then
                        local x = j * 8
                        -- right face → rightmost pixel column of solid tile
                        local rn = (j < 15) and (r.sprites[j+2] or 0) or -1
                        if rn == 0 then
                            line(x+7, sy, x+7, sy+7, TILE_OUTLINE_COLOR)
                        end
                        -- left face → leftmost pixel column of solid tile
                        local ln = (j > 0) and (r.sprites[j] or 0) or -1
                        if ln == 0 then
                            line(x, sy, x, sy+7, TILE_OUTLINE_COLOR)
                        end
                        -- top face → top pixel row of solid tile
                        local an = asp and (asp[j+1] or 0) or -1
                        if an == 0 then
                            line(x, sy, x+7, sy, TILE_OUTLINE_COLOR)
                        end
                        -- bottom face → bottom pixel row of solid tile
                        local bn = bsp and (bsp[j+1] or 0) or -1
                        if bn == 0 then
                            line(x, sy+7, x+7, sy+7, TILE_OUTLINE_COLOR)
                        end
                    end
                end
        end
    end
end

-- Draw the tile grid. Each 8×8 sprite is drawn once at the top of its pixel band
-- (spr_phase==0). Empty (sprite 0) tiles are skipped.
function GameScreen:drawTerrain()
    local t  = self.terrain
    local sf = self.scroll_frac
    -- flash: normal = yellow↔white; escape = brown/orange/yellow/orange 4-way cycle
    local flash = flr(time()*8)
    if self.state == STATE_ESCAPE or self.state == STATE_ESCAPING then
        local phase = flash % 4
        if     phase == 0 then pal(YELLOW, BROWN)
        elseif phase == 1 then pal(YELLOW, ORANGE)
        elseif phase == 3 then pal(YELLOW, ORANGE) end
    elseif flash % 2 == 0 then
        pal(YELLOW, WHITE)
    end
    for i = 1, #t do
        local sy = flr((i - 1) - sf)
        if sy >= GAMEPLAY_H then break end
        local r = t[i]
        -- draw_y: top-left y of this sprite band
        local draw_y = sy - r.spr_phase
        -- draw when the band top enters the buffer (spr_phase==0), or when i==1
        -- and the band started above the buffer top (spr_phase!=0, partially cut off)
        if (r.spr_phase == 0 or i == 1) and draw_y >= -7 and r.sprites then
            for j = 0, 15 do
                local sid = r.sprites[j + 1]
                if sid and sid != 0 then
                    spr(sid, j * 8, draw_y)
                end
            end
        end
    end
    pal()
end

function GameScreen:drawShip()
    local p = self.player
    if self.state == STATE_DYING then
        -- draw explosion sprite at death position with random flips each frame
        spr(SPRITE_SHIP_EXPLOSION, self.death_x, self.death_y,
            SHIP_SPR_W, SHIP_SPR_H, rnd(1) > 0.5, rnd(1) > 0.5)
    else
        spr(SPRITE_PLAYER_SHIP, p.x, p.y, SHIP_SPR_W, SHIP_SPR_H)
    end
end

function GameScreen:drawBullets()
    for b in all(self.bullets) do
        pset(b.x, b.y, YELLOW)
    end
end

-- Draw status bar.  Always called last so it sits in the foreground.
-- Layout (all values from Global.lua):
--   Left  – one SPRITE_LIFE_REMAINING icon per remaining life, horizontally spaced
--   Centre – score on the first text line, fuel on the second
function GameScreen:drawStatusBar()
    -- solid white background spanning the full width of the reserved strip
    rectfill(0, GAMEPLAY_H, 127, 127, STATUS_BAR_COLOR)

    -- lives: icons left-aligned on the bottom row
    for i = 1, self.lives -1 do
        spr(SPRITE_LIFE_REMAINING,
            1 + (i - 1) * STATUS_LIFE_GAP,
            STATUS_LIFE_SPR_Y)
    end

    if self.state == STATE_ESCAPE then
        -- ticker: show current message, hide fuel, keep score
        local score_str = "SCORE:" .. self.score
        print(score_str, (128 - #score_str * 4) \ 2, STATUS_SCORE_Y, BLACK)
        if self.ticker_msgs then
            local msg = self.ticker_msgs[self.ticker_idx]
            if msg then
                print("\^w"..msg, self.ticker_x, STATUS_FUEL_Y, BLACK)
            end
        end
    elseif self.state == STATE_ESCAPING or self.state == STATE_ESCAPE_FLY_OFF then
        -- keep "escape time N" centred and live during the escape
        local score_str = "SCORE:" .. self.score
        print(score_str, (128 - #score_str * 4) \ 2, STATUS_SCORE_Y, BLACK)
        local cdown = "escape time "..self.escapeTime
        print("\^w"..cdown, (128 - #cdown * 8) \ 2, STATUS_FUEL_Y, BLACK)
    else
        -- fuel centred on top row; score centred on bottom row
        local score_str = "SCORE:" .. self.score
        local fuel_str  = "FUEL:"  .. self.fuel
        print(score_str, (128 - #score_str * 4) \ 2, STATUS_SCORE_Y, BLACK)
        print(fuel_str,  (128 - #fuel_str  * 4) \ 2, STATUS_FUEL_Y,  BLACK)
    end
    -- cavern number: flag icons right-aligned on bottom row
    for i = 1, CURRENT_CAVERN - 1 do
        spr(SPRITE_FLAG, 127 - i * 8, STATUS_LIFE_SPR_Y)
    end
end

function GameScreen:drawCrashedOverlay()    rectfill(28, 54, 99, 72, BLACK)
    print("crashed!", 37, 57, RED)
    print("press x to retry", 30, 64, LIGHT_GRAY)
end

