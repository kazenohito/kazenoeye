local setting = {}

local settings = require('settings');
local imgui = require('imgui');
local hide = require('util.hidestatus');

local default_settings = T{
    isJapanese = false,
    createTargetHudOnMobs = T{
        enable = true,
        pets_enable = true,
        only_mypet = false,
        hp_size = {40, 4},
        hp_font_size = 0.80,
        hp_font_size2 = 16.0,
        icon_size = 16,
        icon_spacing = 2,
        timer_enable = true,
        timer_size = 0.60,
        timer_size2 = 14.0,
        format_min = false,
        addEffectLullaby = 0,
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
    createTargetHudOnMobs_format_min = {
        en = 'Format Display In Minutes',
        jp = '分表示に変換',
    },
    addEffectLullaby = {
        en = 'Effect Level Of Lullaby',
        jp = 'ララバイの効果レベル',
    },
    addEffectLullabyHelp = {
        en = 'Extends the duration display of the Lullaby effect. (+1 for a 10% increase)',
        jp = 'ララバイの効果時間表示を延長します。(+1で10％)',
    },
}

config = settings.load(default_settings);
showConfig = { false };

local function drawSettingWindow()
    if (imgui.Begin("kazenoeye_config", showConfig, bit.bor(ImGuiWindowFlags_AlwaysAutoResize))) then
        local isJapanese = {config.isJapanese};
        if (imgui.Checkbox("Japanese language", isJapanese)) then
            config.isJapanese = isJapanese[1];
            settings.save();
        end
        local lang = config.isJapanese and 'jp' or 'en'

        if (imgui.BeginTabBar('settings')) then
            if (imgui.BeginTabItem("MobHUD", nil)) then
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
                local hpFontSize = {config.createTargetHudOnMobs.hp_font_size2}
                if (imgui.SliderFloat(config_lang_resource.hpFontSize[lang], hpFontSize, 8.0, 36.0, "%.1f")) then
                    config.createTargetHudOnMobs.hp_font_size2 = hpFontSize[1]
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
                local timerSize = {config.createTargetHudOnMobs.timer_size2}
                if (imgui.SliderFloat(config_lang_resource.timerSize[lang], timerSize, 8.0, 36.0, "%0.1f")) then
                    config.createTargetHudOnMobs.timer_size2 = timerSize[1]
                    settings.save();
                end
                local createTargetHudOnMobs_format_min = {config.createTargetHudOnMobs.format_min};
                if (imgui.Checkbox(config_lang_resource.createTargetHudOnMobs_format_min[lang], createTargetHudOnMobs_format_min)) then
                    config.createTargetHudOnMobs.format_min = createTargetHudOnMobs_format_min[1];
                    settings.save();
                end
                local addEffectLullaby = {config.createTargetHudOnMobs.addEffectLullaby}
                if (imgui.SliderInt(config_lang_resource.addEffectLullaby[lang], addEffectLullaby, 0, 2)) then
                    config.createTargetHudOnMobs.addEffectLullaby = addEffectLullaby[1]
                    settings.save();
                end
                imgui.ShowHelp(config_lang_resource.addEffectLullabyHelp[lang]);

                imgui.EndTabItem()
            end

        end
        imgui.EndTabBar();
    end
    imgui.End();
end

ashita.events.register('unload', 'setting_unload_cb', function ()
    settings.save();
end);

ashita.events.register('d3d_present', 'setting_present_cb', function ()
    if (showConfig[1] == true) and (not hide.GetHidden()) then
        drawSettingWindow();
    end
end)

settings.register('settings', 'settings_update', function (s)
    if s ~= nil then
        config = s
    end

    settings.save()
end)

return setting
