if SERVER then AddCSLuaFile("shared.lua") end

ENT.Type = "anim"
ENT.Base = "base_anim"

moduletype = {}
moduletype.lifesupport = 0
moduletype.shields = 1
moduletype.systempower = 2

ENT._grid = nil

function ENT:GetModuleType()
    return self:GetNWInt("type", 0)
end

function ENT:IsInSlot()
    return self:GetNWInt("room", -1) > -1
end

function ENT:GetRoom()
    if not self:IsInSlot() then return nil end
    local ship = ships.GetByName(self:GetNWString("ship"))
    return ship:GetRoomByIndex(self:GetNWInt("room"))
end

if SERVER then
    function ENT:SetModuleType(type)
        self:SetNWInt("type", type)
    end

    function ENT:Initialize()
        self:SetModel("models/props_c17/consolebox01a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:AddGameFlag(FVPHYSICS_PLAYER_HELD)
            phys:ClearGameFlag(FVPHYSICS_HEAVY_OBJECT)
            phys:ClearGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
            phys:SetMass(1)
            phys:Wake()
        end

        self:_RandomizeGrid()
        self:_UpdateGrid()
    end

    function ENT:Use()
        if self:IsInSlot() then
            local phys = self:GetPhysicsObject()

            self:SetPos(self:GetPos() + Vector(0, 0, 12))

            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()
                phys:SetVelocity(Vector(0, 0, 128))
            end

            self:SetNWString("ship", "")
            self:SetNWInt("room", -1)
        end
    end

    function ENT:_RandomizeGrid()
        if not self._grid then self._grid = {} end
        for i = 1, 4 do
            if not self._grid[i] then self._grid[i] = {} end
            for j = 1, 4 do
                if math.random() > 0.5 then
                    self._grid[i][j] = 1
                else
                    self._grid[i][j] = 0
                end
            end
        end
    end

    function ENT:_UpdateGrid()
        self:SetNWTable("grid", self._grid)
    end

    function ENT:InsertIntoSlot(room, slot)
        self:SetNWString("ship", room:GetShipName())
        self:SetNWInt("room", room:GetIndex())

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        self:SetPos(slot - Vector(0, 0, 4))
        self:SetAngles(Angle(0, 0, 0))
    end

    function ENT:Think()
        if not self:IsInSlot() then
            local min, max = self:GetCollisionBounds()
            min = min + self:GetPos() - Vector(0, 0, 8)
            max = max + self:GetPos()
            local near = ents.FindInBox(min, max)
            for _, v in pairs(near) do
                if v:GetClass() == "info_ff_moduleslot"
                    and v:GetModuleType() == self:GetModuleType() then
                    self:InsertIntoSlot(v:GetRoom(), v:GetPos())
                end
            end
        end
    end
elseif CLIENT then
    local typeMaterials = {
        Material("systems/lifesupport.png", "smooth"),
        Material("systems/shields.png", "smooth"),
        Material("power.png", "smooth")
    }

    function ENT:IsGridLoaded()
        local grid = self:GetGrid()
        return grid and #grid == 4
    end

    function ENT:GetGrid()
        if not self._grid then
            self._grid = self:GetNWTable("grid")
        end

        return self._grid
    end

    function ENT:Draw()
        self:DrawModel()

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        
        draw.NoTexture()
        
        cam.Start3D2D(self:GetPos() + ang:Up() * 11, ang, 0.5)
            surface.SetDrawColor(Color(0, 0, 0, 255))
            surface.DrawRect(-24, -24, 48, 48)

            if self:IsGridLoaded() then
                local grid = self:GetGrid()
                for i = 1, 4 do
                    local x = (i - 2.5) * 10
                    for j = 1, 4 do
                        local y = (j - 2.5) * 10
                        local val = grid[i][j]
                        if val == 0 then
                            surface.SetDrawColor(Color(51, 172, 45, 255))
                            surface.DrawRect(x - 4, y - 4, 8, 8)
                        elseif val == 1 then
                            surface.SetDrawColor(Color(45, 51, 172, 255))
                            surface.DrawRect(x - 4, y - 4, 8, 8)
                        end
                    end
                end
            end

            surface.SetDrawColor(Color(255, 255, 255, 16))
            surface.SetMaterial(typeMaterials[self:GetModuleType() + 1])
            surface.DrawTexturedRect(-20, -20, 40, 40)
        cam.End3D2D()
    end
end