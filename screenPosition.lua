local d3d8dev        = require('d3d8').get_device();
local ffi            = require('ffi');
local C              = ffi.C;

local helpers        = require('helpers');
local rotateVector16 = helpers.rotateVector16;
local normalize      = helpers.normalize;
local matrixMultiply = helpers.matrixMultiply;
local vec4Transform  = helpers.vec4Transform;
local worldToScreen  = helpers.worldToScreen;
local width          = helpers.width;
local height         = helpers.height;

local Bezier3D_2     = require('Bezier3D_2');

local screenPosition = {};

--debug
screenPosition.getScreenPosition = function(x1, y1, z1)
    local x2, z2, y2 = x1, z1, y1

    local _, world = d3d8dev:GetTransform(C.D3DTS_WORLD);
    local _, view = d3d8dev:GetTransform(C.D3DTS_VIEW);
    local _, projection = d3d8dev:GetTransform(C.D3DTS_PROJECTION)

    -- local _, ptr = vertexBuffer:Lock(0, 0, 0);
    -- local vdata = ffi.cast('struct VertFormatFFFFUFF*', ptr);

    local zoom = (2.8 - projection._11) * 0.47619047619;

    local P1x, P1y, P1z = (x1 + x2) / 2, (z1 + z2) / 2 - 2, (y1 + y2) / 2;

    P1y = P1y - 2 * zoom;

    local midpoint = vec4Transform(ffi.new('D3DXVECTOR4', { P1x, P1y, P1z, 1 }), view);
    local p1Distance = math.sqrt(midpoint.x ^ 2 + midpoint.y ^ 2 + midpoint.z ^ 2)

    P1y = P1y + math.max(6 - p1Distance, 0) / 2

    local P0x, P0y, P0z = x1, z1, y1;
    local P2x, P2y, P2z = x2, z2, y2;

    local P1 = rotateVector16(
        normalize({ P2x - P0x, P2y - P0y, P2z - P0z }),
        { P1x - P0x, P1y - P0y, P1z - P0z },
        false
    );
    P1x, P1y, P1z = P1[1] + P0x, P1[2] + P0y, P1[3] + P0z;

    local bcurve = Bezier3D_2:new({
        { P0x, P0y, P0z },
        { P1x, P1y, P1z },
        { P2x, P2y, P2z }
    });

    local viewProj = matrixMultiply(view, projection);

    local wx0, wy0, wz0 = worldToScreen(P0x, P0y, P0z, view, projection, world);
    local wx2, wy2, wz2 = worldToScreen(P2x, P2y, P2z, view, projection, world);

    if (
            (wz0 > 1 and wz2 > 1) or
            (wz0 < 0 and wz2 < 0) or
            ((wx0 > width or wx0 < 0) and (wx2 > width or wx2 < 0)) or
            ((wy0 > height or wy0 < 0) and (wy2 > height or wy2 < 0))
        ) then
        return;
    end

    local p1, p2, p3;

    local tMin = 0;
    local tMax = 1;
    if (wx0 > width or wx0 < 0 or wy0 > height or wy0 < 0 or wz0 > 1 or wz0 < 0) then
        -- local zeros = bcurve:solveZeros(viewProj);
        local _, tZero = bcurve:solveZeros(viewProj);

        if (not tZero) then return; end

        tMin = tZero;
        p1, p2, p3 = table.unpack(bcurve:subdivide(tZero)[2]);
    elseif (wx2 > width or wx2 < 0 or wy2 > height or wy2 < 0 or wz2 > 1 or wz2 < 0) then
        -- local zeros = bcurve:solveZeros(viewProj);
        local tZero = bcurve:solveZeros(viewProj);
        if (not tZero) then return; end

        tMax = tZero;
        p1, p2, p3 = table.unpack(bcurve:subdivide(tZero)[1]);
    else
        p1 = { P0x, P0y, P0z };
        p2 = { P1x, P1y, P1z };
        p3 = { P2x, P2y, P2z };
    end

    -- Project new control points to screen
    P0x, P0y, P0z = worldToScreen(p1[1], p1[2], p1[3], view, projection, world);
    P1x, P1y, P1z = worldToScreen(p2[1], p2[2], p2[3], view, projection, world);
    P2x, P2y, P2z = worldToScreen(p3[1], p3[2], p3[3], view, projection, world);

    -- Create new bezier curve with new control points
    bcurve = Bezier3D_2:new({
        { P0x, P0y, P0z },
        { P1x, P1y, P1z },
        { P2x, P2y, P2z }
    });

    return P0x,P0y
end

return screenPosition;
