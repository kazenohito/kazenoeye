local mobhud = {}

local imgui = require('imgui');
local screenPosition  = require('util.screenPosition');
local texture  = require('util.texture');
local debuffHandler = require('util.debuffhandler');
local hide = require('util.hidestatus');
local helpers  = require('util.helpers');

local entities = {}

local function loadIconImage(element, i)
    local path = addon.path:append('\\assets\\');
    texture.loadImage(element, path .. "\\icons\\" .. i .. ".png");
end

local function formatTimeMin(sec)
    local m = math.floor(sec / 60)
    local s = sec % 60

    if m > 0 then
        return string.format("%dm", m)
    else
        return string.format("%d", s)
    end
end

local function isRendererByEntity(entity)
    return (bit.band(entity.Render.Flags0, 0x200) == 0x200);
end
local function isMobByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x10) ~= 0)
end
local function isPetByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x100) ~= 0)
end
local function isMyPetByEntity(entity)
    local player = 	GetPlayerEntity();
    if (player ~= nil and player.PetTargetIndex ~= 0) then
        local pet = GetEntity(player.PetTargetIndex);
        if (pet ~= nil) then
            if pet.ServerId == entity.ServerId then
                return true
            else 
                return false
            end
        end
    end

    return false
end

local function GetIndexFromId(id)
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    
    --Shortcut for monsters/static npcs..
    if (bit.band(id, 0x1000000) ~= 0) then
        local index = bit.band(id, 0xFFF);
        if (index >= 0x900) then
            index = index - 0x100;
        end

        if (index < 0x900) and (entMgr:GetServerId(index) == id) then
            return index;
        end
    end

    for i = 1,0x8FF do
        if entMgr:GetServerId(i) == id then
            return i;
        end
    end

    return 0;
end

local function getRenderedEntities()
    entities = {};

    for i = 0,2312,1 do
        local entity = GetEntity(i);
        local resource = nil;
        if (entity ~= nil and isRendererByEntity(entity)) then
            table.insert(entities, T{
                index = i,
                entity = entity,
                mobdb = resource,
            });
        end
    end
end

local function createTargetHudOnMobs()
    local mobs = {};
    for index, entity in ipairs(entities) do
        local isMyPet = true
        if config.createTargetHudOnMobs.only_mypet then
            if isPetByEntity(entity.entity) and not isMyPetByEntity(entity.entity) then
                isMyPet = false
            end
        end
        if (
            (isMobByEntity(entity.entity) and (entity.entity.Status == 1 or entity.entity.Status == 3))
            or (config.createTargetHudOnMobs.pets_enable and isPetByEntity(entity.entity) and entity.entity.HPPercent <= 99 and isMyPet)
        ) then
            table.insert(mobs, entity);
        end
    end

    for index, entity in ipairs(mobs) do
        local dstPointer = entity.entity.ActorPointer;
        if (dstPointer ~= 0) then
            local x1, y1, z1 = helpers.getBone(dstPointer, 1);
            local xx, yy = screenPosition.getScreenPosition(x1, y1, z1);

            if (xx ~= nil and yy ~= nil and xx > 0 and yy > 0) then
                imgui.SetNextWindowBgAlpha(0.4);
                imgui.SetNextWindowPos({xx, yy}, 0, {0.5, 0.5});
                imgui.SetNextWindowSize({
                    32 + config.createTargetHudOnMobs.hp_size[1] + (config.createTargetHudOnMobs.hp_font_size2 * 2),
                    24 + config.createTargetHudOnMobs.hp_size[2]
                })
                if (imgui.Begin('TargetHud:' .. entity.index, true, bit.bor(
                    ImGuiWindowFlags_AlwaysAutoResize,
                    ImGuiWindowFlags_NoTitleBar,
                    ImGuiWindowFlags_NoBackground,
                    ImGuiWindowFlags_NoScrollbar,
                    ImGuiWindowFlags_NoInputs,
                    ImGuiWindowFlags_NoSavedSettings
                ))) then
                    imgui.PushFont(nil, config.createTargetHudOnMobs.hp_font_size2)

                    local x, y = imgui.GetCursorScreenPos();
                    local color = nil;

                    local gageRelativePos = {10, 4}
                    local gageBaseSize = {
                        x + config.createTargetHudOnMobs.hp_size[1],
                        y + config.createTargetHudOnMobs.hp_size[2]
                    };

                    color = imgui.GetColorU32({0, 0, 0, 1});
                    imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1] + x - 2, gageRelativePos[2] + y - 2}, {gageRelativePos[1] + gageBaseSize[1] + 2, gageRelativePos[2] + gageBaseSize[2] + 2}, color, 0.5);
                    color = imgui.GetColorU32({1, 1, 1, 1});
                    imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1] + x - 1, gageRelativePos[2] + y - 1}, {gageRelativePos[1] + gageBaseSize[1] + 1, gageRelativePos[2] + gageBaseSize[2] + 1}, color, 0.5);
                    color = imgui.GetColorU32({0, 0, 0, 1});
                    imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1] + x, gageRelativePos[2] + y}, {gageRelativePos[1] + gageBaseSize[1], gageRelativePos[2] + gageBaseSize[2]}, color, 0.5);
            
                    if (entity.entity.HPPercent > 0) then
                        if isMobByEntity(entity.entity) then
                            color = imgui.GetColorU32({0.8, 0.2, 0.2, 1});
                        else
                            color = imgui.GetColorU32({0.2, 0.8, 0.2, 1});
                        end
                        imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1] + x, gageRelativePos[2] + y}, {gageRelativePos[1] + x + (config.createTargetHudOnMobs.hp_size[1] * (entity.entity.HPPercent / 100)), gageRelativePos[2] + gageBaseSize[2]}, color, 0.5);
                    end

                    local hpText = '' .. entity.entity.HPPercent .. '%';
                    local hpTextWidth, hpTextHeight = imgui.CalcTextSize(hpText);
                    local fontPos = {
                        config.createTargetHudOnMobs.hp_size[1] + 2,
                        (config.createTargetHudOnMobs.hp_size[2] / 2) - (hpTextHeight / 2),
                    }

                    color = imgui.GetColorU32({0, 0, 0, 1});
                    imgui.GetWindowDrawList():AddText({gageRelativePos[1] + x + fontPos[1] + 1, gageRelativePos[2] + y + fontPos[2] + 1}, color, '' .. entity.entity.HPPercent .. '%')
                    imgui.GetWindowDrawList():AddText({gageRelativePos[1] + x + fontPos[1] - 1, gageRelativePos[2] + y + fontPos[2] - 1}, color, '' .. entity.entity.HPPercent .. '%')
                    color = imgui.GetColorU32({1, 1, 1, 1});
                    imgui.GetWindowDrawList():AddText({gageRelativePos[1] + x + fontPos[1], gageRelativePos[2] + y + fontPos[2]}, color, '' .. entity.entity.HPPercent .. '%')

                    imgui.PopFont();
                end
                imgui.End();

                imgui.SetNextWindowBgAlpha(0.4);
                imgui.SetNextWindowPos({xx, yy - 4 + (config.createTargetHudOnMobs.hp_size[2] / 2)}, 0, {0.5, 0});
                if (imgui.Begin('TargetHud_debuff:' .. entity.index, true, bit.bor(
                    ImGuiWindowFlags_AlwaysAutoResize,
                    ImGuiWindowFlags_NoTitleBar,
                    ImGuiWindowFlags_NoBackground,
                    ImGuiWindowFlags_NoScrollbar,
                    ImGuiWindowFlags_NoInputs,
                    ImGuiWindowFlags_NoSavedSettings
                ))) then
                    imgui.PushFont(nil, config.createTargetHudOnMobs.timer_size2)

                    local buffIds, buffTimes = debuffHandler.GetActiveDebuffs(entity.entity.ServerId);
                    if (buffIds ~= nil and #buffIds > 0) then
                        for i, v in ipairs(buffIds) do
                            local samerine = config.createTargetHudOnMobs.icon_spacing
                            local icon_x = config.createTargetHudOnMobs.icon_size
                            local icon_y = config.createTargetHudOnMobs.icon_size

                            local icon_pos_x, icon_pos_y = imgui.GetCursorScreenPos();

                            if buffTimes[i] < 5 and os.clock() % 0.1 >= 0.02 == false then
                                imgui.Dummy({icon_x, icon_y})
                            elseif buffTimes[i] < 10 and os.clock() % 0.5 >= 0.02 == false then
                                imgui.Dummy({icon_x, icon_y})
                            else
                                local iconName = "bufficon" .. v
                                if texture.getImage(iconName) == nil then
                                    loadIconImage(iconName, v)
                                end
                                texture.drawTexture(iconName, {icon_x, icon_y})
                            end

                            if config.createTargetHudOnMobs.timer_enable and v < 1000 then
                                local timeValue = buffTimes[i];
                                local text = '' .. timeValue;

                                if config.createTargetHudOnMobs.format_min then
                                    text = formatTimeMin(timeValue)
                                end

                                local textWidth, _ = imgui.CalcTextSize(text);

                                local text_x = icon_pos_x + ((icon_x - textWidth) * 0.5);
                                local text_y = icon_pos_y + icon_y + 2;

                                local color = imgui.GetColorU32({1, 1, 1, 1})
                                if timeValue < 10 then
                                    color = imgui.GetColorU32({1, 0.3, 0.3, 1})
                                elseif timeValue < 20 then
                                    color = imgui.GetColorU32({1, 1, 0, 1})
                                end

                                imgui.GetWindowDrawList():AddText({text_x + 1, text_y + 1}, imgui.GetColorU32({0, 0, 0, 1}), '' .. text)
                                imgui.GetWindowDrawList():AddText({text_x - 1, text_y - 1}, imgui.GetColorU32({0, 0, 0, 1}), '' .. text)
                                imgui.GetWindowDrawList():AddText({text_x + 1, text_y - 1}, imgui.GetColorU32({0, 0, 0, 1}), '' .. text)
                                imgui.GetWindowDrawList():AddText({text_x - 1, text_y + 1}, imgui.GetColorU32({0, 0, 0, 1}), '' .. text)
                                imgui.GetWindowDrawList():AddText({text_x, text_y}, color, '' .. text)
                            end

                            if i < #buffIds then
                                imgui.SameLine(0, samerine);
                            end
                        end
                    end

                    imgui.Dummy({1, 20});
                    imgui.PopFont();
                end
                imgui.End();
            end
        end
    end
end

local function ParseMessagePacket(e)
    local basic = {
        sender     = struct.unpack('i4', e, 0x04 + 1),
        target     = struct.unpack('i4', e, 0x08 + 1),
        param      = struct.unpack('i4', e, 0x0C + 1),
        value      = struct.unpack('i4', e, 0x10 + 1),
        sender_tgt = struct.unpack('i2', e, 0x14 + 1),
        target_tgt = struct.unpack('i2', e, 0x16 + 1),
        message    = struct.unpack('i2', e, 0x18 + 1),
    }
    return basic
end

local function ParseActionPacket(e)
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;
    local function UnpackBits(length)
        if ((bitOffset + length) >= maxLength) then
            maxLength = 0; --Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local actionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;
    actionPacket.UserId = UnpackBits(32);
    actionPacket.UserIndex = GetIndexFromId(actionPacket.UserId); --Many implementations of this exist, or you can comment it out if not needed.  It can be costly.
    local targetCount = UnpackBits(6);
    --Unknown 4 bits
    bitOffset = bitOffset + 4;
    actionPacket.Type = UnpackBits(4);
    -- Bandaid fix until we have more flexible packet parsing
    if actionPacket.Type == 8 or actionPacket.Type == 9 then
        actionPacket.Param = UnpackBits(16);
        actionPacket.SpellGroup = UnpackBits(16);
    else
        -- Not every action packet has the same data at the same offsets so we just skip this for now
        actionPacket.Param = UnpackBits(32);
    end

    actionPacket.Recast = UnpackBits(32);

    actionPacket.Targets = T{};
    if (targetCount > 0) then
        for i = 1,targetCount do
            local target = T{};
            target.Id = UnpackBits(32);
            local actionCount = UnpackBits(4);
            target.Actions = T{};
            if (actionCount == 0) then
                break;
            else
                for j = 1,actionCount do
                    local action = {};
                    action.Reaction = UnpackBits(5);
                    action.Animation = UnpackBits(12);
                    action.SpecialEffect = UnpackBits(7);
                    action.Knockback = UnpackBits(3);
                    action.Param = UnpackBits(17);
                    action.Message = UnpackBits(10);
                    action.Flags = UnpackBits(31);

                    local hasAdditionalEffect = (UnpackBits(1) == 1);
                    if hasAdditionalEffect then
                        local additionalEffect = {};
                        additionalEffect.Damage = UnpackBits(10);
                        additionalEffect.Param = UnpackBits(17);
                        additionalEffect.Message = UnpackBits(10);
                        action.AdditionalEffect = additionalEffect;
                    end

                    local hasSpikesEffect = (UnpackBits(1) == 1);
                    if hasSpikesEffect then
                        local spikesEffect = {};
                        spikesEffect.Damage = UnpackBits(10);
                        spikesEffect.Param = UnpackBits(14);
                        spikesEffect.Message = UnpackBits(10);
                        action.SpikesEffect = spikesEffect;
                    end

                    target.Actions:append(action);
                end
            end
            actionPacket.Targets:append(target);
        end
    end

    if  (maxLength ~= 0) and (#actionPacket.Targets > 0) then
        return actionPacket;
    end
end

local nextUpdate = os.clock()
local interval = 0.15
ashita.events.register('d3d_present', 'mobhud_present_cb', function()
    if (hide.GetHidden() == false) then
        if (os.clock() >= nextUpdate) then
            getRenderedEntities()
            nextUpdate = nextUpdate + interval
        end

        if (config.createTargetHudOnMobs.enable) then
            createTargetHudOnMobs();
        end
    end
end);

ashita.events.register('packet_in', 'mobhud_packet_in_cb', function (e)
	if (e.id == 0x0028) then
		local actionPacket = ParseActionPacket(e);
		
		if actionPacket then
			debuffHandler.HandleActionPacket(actionPacket);
		end
    elseif (e.id == 0x00B) then
        entities = {}
	elseif (e.id == 0x00A) then
		debuffHandler.HandleZonePacket(e);
	elseif (e.id == 0x0029) then
		local messagePacket = ParseMessagePacket(e.data);
		if (messagePacket) then
			debuffHandler.HandleMessagePacket(messagePacket);
		end
    elseif (e.id == 0x00E) then
        local entity = GetEntity(struct.unpack('H', e.data, 0x08 + 1))
        local status = nil
        if (bit.band(struct.unpack('B', e.data, 0x0A + 1), 0x04) == 0x04) then
            status = struct.unpack('B', e.data, 0x1F + 1)
        end
        if (entity ~= nil) then
            debuffHandler.HandleUpdateEntity(entity, status);
        end
	end
end);

return mobhud
