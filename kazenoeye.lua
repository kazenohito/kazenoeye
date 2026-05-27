addon.name      = 'kazenoeye';
addon.author    = 'kazenohito';
addon.version   = '1.2.8';
addon.desc      = 'Display information about Entity within visible range';
addon.link      = 'https://github.com/kazenohito/kazenoeye';

require('common');
local imgui = require('imgui');
local settings = require('settings');
local screenPosition  = require('screenPosition');
local texture  = require('texture');
local debuffHandler = require('debuffhandler');
local hide = require('hidestatus');

local default_settings = T{
    isJapanese = false,
    createTargetHudOnMobs = T{
        enable = true,
        pets_enable = true,
        only_mypet = false,
        hp_size = {40, 4},
        hp_font_size = 0.80,
        icon_size = 16,
        icon_spacing = 2,
        timer_enable = true,
        timer_size = 0.60,
    },
};
local config_lang_resource = T{
    createTargetHudOnMobs = {
        en = 'MobHUD',
        jp = 'MobHUD',
    },
    createTargetHudOnMobs_enable = {
        en = 'Enable MobHUD',
        jp = 'MobHUD 有効',
    },
    createTargetHudOnMobs_pets_enable = {
        en = 'Enable For Pets',
        jp = '味方ペット 有効',
    },
    createTargetHudOnMobs_only_mypet = {
        en = 'Only My Pet',
        jp = '自分のペットのみ',
    },
    hpSize = {
        en = 'HP Size',
        jp = 'HPサイズ',
    },
    hpFontSize = {
        en = 'HP FontSize',
        jp = 'HPフォントサイズ',
    },
    iconSize = {
        en = 'IconSize',
        jp = 'アイコンサイズ',
    },
    iconSpacing = {
        en = 'IconSpacing',
        jp = 'アイコン間隔',
    },
    createTargetHudOnMobs_timer_enable = {
        en = 'Show Timer',
        jp = 'タイマー表示 有効',
    },
    timerSize = {
        en = 'TimerSize',
        jp = 'タイマーサイズ',
    },
}

local config = settings.load(default_settings);
local showConfig = { false };

local helpers  = require('helpers');

local function isRendererByEntity(entity)
    return (bit.band(entity.Render.Flags0, 0x200) == 0x200);
end
local function isMobByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x10) ~= 0)
end
local function isPlayerByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x0001) == 0x0001)
end
local function isNpcByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x0002) == 0x0002)
end
local function isPetByEntity(entity)
    return (bit.band(entity.SpawnFlags, 0x100) ~= 0)
    -- return (entity.SpawnFlags ==258)
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
local function isPartyMemberByEntity(entity)
    return (entity.SpawnFlags ==13)
end

local function getRenderedEntities()
    local entities = {};

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

    return entities;
end

local function createTargetHudOnMobs(entities)
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
        local x1, y1, z1 = helpers.getBone(dstPointer, 1);
        local xx, yy = screenPosition.getScreenPosition(x1, y1, z1);

        if (xx ~= nil and yy ~= nil and xx > 0 and yy > 0) then
            imgui.SetNextWindowBgAlpha(0.4);
            imgui.SetNextWindowPos({xx, yy}, 0, {0.5,0.5});
            imgui.SetNextWindowSize({32+config.createTargetHudOnMobs.hp_size[1]+(config.createTargetHudOnMobs.hp_font_size*40), 24+config.createTargetHudOnMobs.hp_size[2]})
            if (imgui.Begin('TargetHud:' .. entity.index, true, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings))) then
                imgui.SetWindowFontScale(config.createTargetHudOnMobs.hp_font_size);

                local x, y = imgui.GetCursorScreenPos();
                local color = nil;

                local gageRelativePos = {10, 4}
                local gageBaseSize = {x+config.createTargetHudOnMobs.hp_size[1],y+config.createTargetHudOnMobs.hp_size[2]};
                color = imgui.GetColorU32({0,0,0,1});
                imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1]+x-2,gageRelativePos[2]+y-2},{gageRelativePos[1]+gageBaseSize[1]+2,gageRelativePos[2]+gageBaseSize[2]+2},color,0.5);
                color = imgui.GetColorU32({1,1,1,1});
                imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1]+x-1,gageRelativePos[2]+y-1},{gageRelativePos[1]+gageBaseSize[1]+1,gageRelativePos[2]+gageBaseSize[2]+1},color,0.5);
                color = imgui.GetColorU32({0,0,0,1});
                imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1]+x,gageRelativePos[2]+y},{gageRelativePos[1]+gageBaseSize[1],gageRelativePos[2]+gageBaseSize[2]},color,0.5);
        
                if (entity.entity.HPPercent > 0) then
                    if isMobByEntity(entity.entity) then
                        color = imgui.GetColorU32({0.8, 0.2, 0.2, 1});
                    else
                        color = imgui.GetColorU32({0.2, 0.8, 0.2, 1});
                    end
                    imgui.GetWindowDrawList():AddRectFilled({gageRelativePos[1]+x,gageRelativePos[2]+y},{gageRelativePos[1]+x + (config.createTargetHudOnMobs.hp_size[1] * (entity.entity.HPPercent /100)),gageRelativePos[2]+gageBaseSize[2]},color,0.5);
                end

                local fontPos = {
                    config.createTargetHudOnMobs.hp_size[1] + 2,
                    (config.createTargetHudOnMobs.hp_size[2] / 2) + 1 - (config.createTargetHudOnMobs.hp_font_size * 11),
                }

                color = imgui.GetColorU32({0,0,0,1});
                imgui.GetWindowDrawList():AddText({gageRelativePos[1]+x+fontPos[1]+1,gageRelativePos[2]+y+fontPos[2]+1},color,''..entity.entity.HPPercent..'%')
                imgui.GetWindowDrawList():AddText({gageRelativePos[1]+x+fontPos[1]-1,gageRelativePos[2]+y+fontPos[2]-1},color,''..entity.entity.HPPercent..'%')
                color = imgui.GetColorU32({1,1,1,1});
                imgui.GetWindowDrawList():AddText({gageRelativePos[1]+x+fontPos[1],gageRelativePos[2]+y+fontPos[2]},color,''..entity.entity.HPPercent..'%')
            end
            imgui.End();


            imgui.SetNextWindowBgAlpha(0.4);
            imgui.SetNextWindowPos({xx, yy-4+(config.createTargetHudOnMobs.hp_size[2]/2)}, 0, {0.5,0});
            if (imgui.Begin('TargetHud_debuff:' .. entity.index, true, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings))) then
                imgui.SetWindowFontScale(config.createTargetHudOnMobs.timer_size);
                local buffIds, buffTimes = debuffHandler.GetActiveDebuffs(entity.entity.ServerId);
                if (buffIds ~= nil and #buffIds > 0) then
                    local bufffff = {}
                    for i = 1,#buffIds do
                        if (buffIds[i] == -1) then
                            break;
                        end
                        table.insert(bufffff, buffIds[i])
                    end
                    for i, v in pairs(buffIds) do
                        local samerine = config.createTargetHudOnMobs.icon_spacing
                        local icon_x = config.createTargetHudOnMobs.icon_size
                        local icon_y = config.createTargetHudOnMobs.icon_size

                        if buffTimes[i] < 5 and os.clock() % 0.1 >= 0.02 == false then
                            imgui.Dummy({icon_x,icon_y})
                        elseif buffTimes[i] < 10 and os.clock() % 0.5 >= 0.02 == false then
                            imgui.Dummy({icon_x,icon_y})
                        else
                            texture.drawTexture("bufficon"..v, {icon_x,icon_y})
                        end

                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 20)
                        if config.createTargetHudOnMobs.timer_enable then

                            local x, y = imgui.GetCursorScreenPos();
                            y = y - 20
                            x = x + ((i - 1) * config.createTargetHudOnMobs.icon_size + (i-1)*samerine)

                            local text = buffTimes[i]
                            local windowWidth = config.createTargetHudOnMobs.icon_size
                            local textWidth, _ = imgui.CalcTextSize(''..text)
                            local popopops_x = x + (windowWidth - textWidth) * 0.5

                            local color = imgui.GetColorU32({1,1,1,1})
                            if text < 10 then
                                color = imgui.GetColorU32({1,0,0,1})
                            elseif text < 20 then
                                color = imgui.GetColorU32({1,1,0,1})
                            end
                            imgui.GetWindowDrawList():AddText({popopops_x + 0, y - 6}, imgui.GetColorU32({0,0,0,1}), ''..text)
                            imgui.GetWindowDrawList():AddText({popopops_x + 2, y - 4}, imgui.GetColorU32({0,0,0,1}), ''..text)
                            imgui.GetWindowDrawList():AddText({popopops_x + 1, y - 5}, color, ''..text)
                        end

                        imgui.SameLine(0,samerine)
                    end
                end
            end
            imgui.End();
        end
    end

end

function ParseMessagePacket(e)
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

function ParseActionPacket(e)
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
function GetIndexFromId(id)
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

--[[
* Registers a callback for the settings to monitor for character switches.
--]]
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        config = s;
    end

    settings.save();
end);

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function ()
    -- debug
	local path = addon.path:append('\\assets\\');

    -- buff Icons
    for i = 0, 639 do
        local namae = "bufficon" .. i
        texture.loadImage(namae, path .. "\\icons\\" .. i .. ".png");
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

ashita.events.register('d3d_present', 'present_cb', function()
    if hide.GetHidden() == false then
        local entities = getRenderedEntities();

        if (config.createTargetHudOnMobs.enable) then
            createTargetHudOnMobs(entities);
        end

        if (showConfig[1] == true) then
            drawConfigWindow();
        end
    end
end);

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'packet_in_cb', function (e)
	if (e.id == 0x0028) then
		local actionPacket = ParseActionPacket(e);
		
		if actionPacket then
			debuffHandler.HandleActionPacket(actionPacket);
		end
	elseif (e.id == 0x00E) then
	elseif (e.id == 0x00A) then
		debuffHandler.HandleZonePacket(e);
		-- bLoggedIn = true;
	elseif (e.id == 0x0029) then
		local messagePacket = ParseMessagePacket(e.data);
		if (messagePacket) then
			debuffHandler.HandleMessagePacket(messagePacket);
		end
	elseif (e.id == 0x00B) then
		-- bLoggedIn = false;
	elseif (e.id == 0x076) then
		-- statusHandler.ReadPartyBuffsFromPacket(e);
	end
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/kazenoeye')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    if table.contains({'/kazenoeye'}, args[1]) then
		-- Toggle the config menu
		showConfig[1] = not showConfig[1];
		return;
	end
end);

function drawConfigWindow()
    if (imgui.Begin("kazenoeye_config", showConfig, bit.bor(ImGuiWindowFlags_AlwaysAutoResize))) then
        local isJapanese = {config.isJapanese};
        if (imgui.Checkbox("Japanese language", isJapanese)) then
            config.isJapanese = isJapanese[1];
            settings.save();
        end
        local lang = config.isJapanese and 'jp' or 'en'

        imgui.Separator();

        imgui.Text(config_lang_resource.createTargetHudOnMobs[lang]);

        local createTargetHudOnMobs_enable = {config.createTargetHudOnMobs.enable};
        if (imgui.Checkbox(config_lang_resource.createTargetHudOnMobs_enable[lang], createTargetHudOnMobs_enable)) then
            config.createTargetHudOnMobs.enable = createTargetHudOnMobs_enable[1];
            settings.save();
        end
        local createTargetHudOnMobs_pets_enable = {config.createTargetHudOnMobs.pets_enable};
        if (imgui.Checkbox(config_lang_resource.createTargetHudOnMobs_pets_enable[lang], createTargetHudOnMobs_pets_enable)) then
            config.createTargetHudOnMobs.pets_enable = createTargetHudOnMobs_pets_enable[1];
            settings.save();
        end

        imgui.SameLine(0,0)
        local createTargetHudOnMobs_only_pet = {config.createTargetHudOnMobs.only_mypet};
        if (imgui.Checkbox(config_lang_resource.createTargetHudOnMobs_only_mypet[lang], createTargetHudOnMobs_only_pet)) then
            config.createTargetHudOnMobs.only_mypet = createTargetHudOnMobs_only_pet[1];
            settings.save();
        end

        local hpSize = {config.createTargetHudOnMobs.hp_size[1], config.createTargetHudOnMobs.hp_size[2]};
        if (imgui.SliderInt2(config_lang_resource.hpSize[lang], hpSize, 1, 80)) then
            config.createTargetHudOnMobs.hp_size = hpSize;
            settings.save();
        end
        local hpFontSize = {config.createTargetHudOnMobs.hp_font_size}
        if (imgui.SliderFloat(config_lang_resource.hpFontSize[lang], hpFontSize, 0.10, 1.50)) then
            config.createTargetHudOnMobs.hp_font_size = hpFontSize[1]
            settings.save();
        end

        local iconSize = {config.createTargetHudOnMobs.icon_size}
        if (imgui.SliderInt(config_lang_resource.iconSize[lang], iconSize, 8, 24)) then
            config.createTargetHudOnMobs.icon_size = iconSize[1]
            settings.save();
        end
        local iconSpacing = {config.createTargetHudOnMobs.icon_spacing}
        if (imgui.SliderInt(config_lang_resource.iconSpacing[lang], iconSpacing, 0, 24)) then
            config.createTargetHudOnMobs.icon_spacing = iconSpacing[1]
            settings.save();
        end

        local createTargetHudOnMobs_timer_enable = {config.createTargetHudOnMobs.timer_enable};
        if (imgui.Checkbox(config_lang_resource.createTargetHudOnMobs_timer_enable[lang], createTargetHudOnMobs_timer_enable)) then
            config.createTargetHudOnMobs.timer_enable = createTargetHudOnMobs_timer_enable[1];
            settings.save();
        end
        local timerSize = {config.createTargetHudOnMobs.timer_size}
        if (imgui.SliderFloat(config_lang_resource.timerSize[lang], timerSize, 0.10, 1.00)) then
            config.createTargetHudOnMobs.timer_size = timerSize[1]
            settings.save();
        end
    end
    imgui.End();
end