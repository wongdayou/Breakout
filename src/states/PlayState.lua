--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
local powerupCount = 0


function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.ballnum = params.ballnum
    self.level = params.level
    self.recoverPoints = 5000
    self.powerups = {}
    self.lockedbrick = params.lockedbrick

    -- give ball random starting velocity
    for b, balls in pairs(self.ball) do
        balls.dx = math.random(-200, 200)
        balls.dy = math.random(-50, -60)
    end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    
    for b, balls in pairs(self.ball) do
        balls:update(dt)
    end

    for b, balls in pairs(self.ball) do
        if balls:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            balls.y = self.paddle.y - 8
            balls.dy = -balls.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if balls.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                balls.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - balls.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif balls.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                balls.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - balls.x))
            end

            gSounds['paddle-hit']:play()
        end

    end
    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        for b, balls in pairs(self.ball) do
        -- only check collision if we're in play
            if brick.inPlay and balls:collides(brick) then

                --run the below functions only if the brick is not locked
                if not brick.locked then
            -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- if we have enough points, recover a point of health
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        self.paddle.size = math.min(4, self.paddle.size + 1)
                        self.paddle.width = math.min(128, self.paddle.width + 32)

                        -- multiply recover points by 2
                        self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    if (math.random(1,10) == 10) then
                        table.insert(self.powerups, Powerup(9, brick.middle, brick.y + brick.height))
                    end

                    if ((math.random(1, 5) == 3) and lockedbrick) then
                        table.insert(self.powerups, Powerup(10, brick.middle, brick.y + brick.height))
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            highScores = self.highScores,
                            ball = self.ball,
                            recoverPoints = self.recoverPoints
                        })
                    end
                
                else
                    gSounds['wall-hit']:play()
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if balls.x + 2 < brick.x and balls.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    balls.dx = -balls.dx
                    balls.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif balls.x + 6 > brick.x + brick.width and balls.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    balls.dx = -balls.dx
                    balls.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif balls.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    balls.dy = -balls.dy
                    balls.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    balls.dy = -balls.dy
                    balls.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(balls.dy) < 150 then
                    balls.dy = balls.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end

            

        end

    end



    -- if ball goes below bounds, revert to serve state and decrease health
    for b, ball in pairs(self.ball) do
        if ball.y > VIRTUAL_HEIGHT then
            table.remove(self.ball, b)
            self.ballnum = self.ballnum - 1
        end 

        if (self.ballnum <= 0) then
            self.health = self.health - 1
            gSounds['hurt']:play()

            self.paddle.size = math.max(2, self.paddle.size - 1)
            self.paddle.width = math.max(64, self.paddle.width - 32)

            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints,
                    ballnum = 1,
                    powerupPoints = self.powerupPoints
                })
            end
        end

    end 


    for i, powerup in pairs(self.powerups) do
        if powerup:collides(self.paddle) then
            
            
            if (powerup.type == 9) then
                newBall = Ball(self.ball[1].x, self.ball[1].y, -self.ball[1].dx, self.ball[1].dy, math.random(7))
                table.insert(self.ball, newBall)
                self.ballnum = self.ballnum + 1
                
            elseif (powerup.type == 10) then
                self.bricks["lockedbrick"].locked = false 
                lockedbrick = false
            end

            table.remove(self.powerups, i)
        end

        if (powerup.y > VIRTUAL_HEIGHT) then
            table.remove(self.powerups, i)
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    for k, powerup in pairs(self.powerups) do
        powerup:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for b, balls in pairs(self.ball) do
        balls:render()
    end

    for p, powerup in pairs(self.powerups) do
        powerup:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end