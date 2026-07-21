local targetmarker = {}

local imgui = require('imgui');
local hide = require('util.hidestatus');
local helpers  = require('util.helpers');
local screenPosition  = require('util.screenPosition');

local d3d = require('d3d8');
local d3d8dev = d3d.get_device();
local _, viewport = d3d8dev:GetViewport();
local screenWidth = viewport.Width;
local screenHeight = viewport.Height;

local status = {
    targetMarker = {
        lockonIndex = nil,
        lockonStartTime = os.clock(),
        lockonChangeTime = nil,

        lockonStartPos = {nil, nil},
        lockonTargetPos = {nil, nil},
        lockonCurrentPos = {nil, nil},
    },
}

local function isMobByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x10) ~= 0)
end

local function isNpcByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x0002) == 0x0002)
end

local function GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():Get('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

local function getTargetData()
    local ret = nil;
    local st_index = GetStPartyIndex();
    local main_index = nil
    local tentity = nil
    if (st_index ~= nil ) then
        tentity = GetEntity(AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(st_index))
    else
        main_index = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
        tentity = GetEntity(main_index)
    end

    if (tentity ~= nil) then
        local dstPointer = nil
        local x1, y1, z1 = nil, nil, nil
        local xx, yy = nil, nil

        if (tentity.Type == 3) then
            local x, y, z= tentity.Movement.LocalPosition.X, tentity.Movement.LocalPosition.Y, tentity.Movement.LocalPosition.Z
            xx, yy = screenPosition.getScreenDoorPosition(x, y, z)
        else
            dstPointer = tentity.ActorPointer
            x1, y1, z1 = helpers.getBoneHalf(dstPointer, 2)
            xx, yy = screenPosition.getScreenPosition(x1, y1, z1)
        end

        ret = {
            Index = tentity.TargetIndex,
            ServerId = tentity.ServerId,
            Name = tentity.Name,
            HPP = tentity.HPPercent / 100,
            Dist = ('%.1f'):fmt(math.sqrt(tentity.Distance)),
            SpawnFlags = tentity.SpawnFlags,
            Status = tentity.Status,
            PosX = xx,
            PosY = yy,
        }
    end

    return ret
end

local function drawCircularProgressBar(posCenter, length, thickness, progress, color, startingAngle)
    local points = {}
    local draw = imgui.GetWindowDrawList()
    local color32 = imgui.GetColorU32(color)

    local cx = posCenter[1]
    local cy = posCenter[2]

    local start = startingAngle - 90
    local finish = start + progress * 3.6

    local count = 0

    for deg = start, finish, 1 do
        local rad = math.rad(deg)

        count = count + 1

        points[count] = points[count] or {0,0}

        points[count][1] = cx + math.cos(rad) * length * 0.9
        points[count][2] = cy + math.sin(rad) * length * 0.9
    end

    draw:AddPolyline(points, count, color32, false, thickness)
end

local function drawTargetMarker(posCenter, length, thickness, progress, color)
    local x, y = posCenter[1], posCenter[2]
    local startingAngle = (os.clock() - status.targetMarker.lockonStartTime) * 200 % 360

    -- keiryou style
    drawCircularProgressBar({x, y}, length, thickness + 2, progress + 1.5, {0, 0, 0, color[4]}, 0 + startingAngle - 2.5)
    drawCircularProgressBar({x, y}, length, thickness + 2, progress + 1.5, {0, 0, 0, color[4]}, 120 + startingAngle - 2.5)
    drawCircularProgressBar({x, y}, length, thickness + 2, progress + 1.5, {0, 0, 0, color[4]}, 240 + startingAngle - 2.5)

    drawCircularProgressBar({x, y}, length, thickness, progress, color, 0 + startingAngle)
    drawCircularProgressBar({x, y}, length, thickness, progress, color, 120 + startingAngle)
    drawCircularProgressBar({x, y}, length, thickness, progress, color, 240 + startingAngle)

    drawCircularProgressBar({x, y}, 16 * 0.3, 4, 100, {0, 0, 0, color[4]}, 0)
    drawCircularProgressBar({x, y}, 16 * 0.3, 2, 100, color, 0)
end

local function drawTargetInfo(entity, color)
    local x, y = entity.PosX, entity.PosY
    imgui.SetWindowFontScale(config.createTargetMarker.info_size + 0.2);

    -- Dist
    local text_dist = "" .. entity.Dist;
    local xx, yy = imgui.CalcTextSize(text_dist)
    imgui.GetWindowDrawList():AddText({x + 22 + 1, y - (yy / 2) + 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_dist)
    imgui.GetWindowDrawList():AddText({x + 22 - 1, y - (yy / 2) - 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_dist)
    imgui.GetWindowDrawList():AddText({x + 22 + 1, y - (yy / 2) - 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_dist)
    imgui.GetWindowDrawList():AddText({x + 22 - 1, y - (yy / 2) + 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_dist)
    imgui.GetWindowDrawList():AddText({x + 22, y - (yy / 2)}, imgui.GetColorU32(color), text_dist)

    -- Name
    local text_name = "" .. entity.Name;
    local xx, yy = imgui.CalcTextSize(text_name)
    imgui.GetWindowDrawList():AddText({x - 22 - xx + 1, y - (yy / 2) + 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_name)
    imgui.GetWindowDrawList():AddText({x - 22 - xx - 1, y - (yy / 2) - 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_name)
    imgui.GetWindowDrawList():AddText({x - 22 - xx + 1, y - (yy / 2) - 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_name)
    imgui.GetWindowDrawList():AddText({x - 22 - xx - 1, y - (yy / 2) + 1}, imgui.GetColorU32({0, 0, 0, color[4]}), text_name)
    imgui.GetWindowDrawList():AddText({x - 22 - xx, y - (yy / 2)}, imgui.GetColorU32(color), text_name)
end

local function createTargetMarker()
    local t = getTargetData();

    if (t ~= nil) then
        local x, y = t.PosX, t.PosY
        if (x ~= x or y ~= y) then
            return
        end
        imgui.SetNextWindowPos({0, 0}, 0, {0, 0});
        imgui.SetNextWindowSize({screenWidth, screenHeight})
        if (imgui.Begin('targetLine_'..t.Index, true, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoInputs))) then
            if (x ~= nil and y ~= nil) then
                if status.targetMarker.lockonStartTime == nil then
                    status.targetMarker.lockonStartTime = os.clock()
                end
                if status.targetMarker.lockonIndex == nil or (status.targetMarker.lockonIndex ~= t.Index) then
                    status.targetMarker.lockonIndex = t.Index
                    status.targetMarker.lockonChangeTime = os.clock()

                    if status.targetMarker.lockonCurrentPos[1] == nil or status.targetMarker.lockonCurrentPos[2] == nil then
                        status.targetMarker.lockonCurrentPos = {t.PosX, t.PosY}
                    end
                    status.targetMarker.lockonStartPos = status.targetMarker.lockonCurrentPos
                end
                status.targetMarker.lockonTargetPos = {t.PosX, t.PosY}

                local elapsed = os.clock() - status.targetMarker.lockonChangeTime
                local ap = math.min(elapsed / config.createTargetMarker.animation.movement_duration, 1.0)
                ap = 1 - (1 - ap) ^ 3
                status.targetMarker.lockonCurrentPos[1] = status.targetMarker.lockonStartPos[1] + (status.targetMarker.lockonTargetPos[1] - status.targetMarker.lockonStartPos[1]) * ap
                status.targetMarker.lockonCurrentPos[2] = status.targetMarker.lockonStartPos[2] + (status.targetMarker.lockonTargetPos[2] - status.targetMarker.lockonStartPos[2]) * ap

                local scale = 1.0

                local elapsed2 = os.clock() - status.targetMarker.lockonStartTime
                local duration2 = 0.5
                local ap2 = math.min(elapsed2 / duration2, 1.0)
                ap2 = 1 - (1 - ap2) ^ 3
                local startRadius = 16 * 6 * scale
                local endRadius = 16 * scale
                local currentRadius = startRadius + (endRadius - startRadius) * ap2
                local thickness = 3 * scale

                local color = config.createTargetMarker.color.pc
                if isNpcByEntity(t) then
                    color = config.createTargetMarker.color.npc
                elseif isMobByEntity(t) then
                    if t.Status == 1 then
                        color = config.createTargetMarker.color.mob_battle
                    else
                        color = config.createTargetMarker.color.mob_default
                    end
                end
                if config.createTargetMarker.info_enable then
                    drawTargetInfo(t, color)
                end
                drawTargetMarker(status.targetMarker.lockonCurrentPos, currentRadius, thickness, 20, color)
            end
        end
        imgui.End();
    else
        status.targetMarker.lockonIndex = nil
        status.targetMarker.lockonStartTime = nil
        status.targetMarker.lockonChangeTime = nil
        status.targetMarker.lockonCurrentPos = {nil, nil}
    end
end

ashita.events.register('d3d_present', 'targetmarker_present_cb', function()
    if hide.GetHidden() == false then
        if (config.createTargetMarker.enable) then
            createTargetMarker();
        end
    end
end);

return targetmarker
