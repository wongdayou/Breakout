Powerup = Class{}

function Powerup:init(type, x, y)
    self.width = 16
    self.height = 16
    self.x = x
    self.y = y
    self.dy = 50
    self.type = type
    self.inPlay = true
end


--function to activate Powerup
function Powerup:activate()
    self.inPlay = false
    return true
end

--function to check if Powerup collides with brick
function Powerup:collides(target)
    if self.inPlay then
        if self.x > target.x + target.width or target.x > self.x + self.width then
            return false
        end

        if self.y > target.y + target.height or target.y > self.y + self.height then
            return false
        end

        return true
    else
        return false
    end

end


function Powerup:update(dt)
    --let powerup float down
    self.y = self.y + self.dy * dt

end

function Powerup:render()
    if self.inPlay then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], 
                                self.x,
                                self.y)
    end
end