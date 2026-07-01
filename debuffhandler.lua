-- GNU Licensed by mousseng's XITools repository [https://github.com/mousseng/xitools]
require('common');
-- require('handlers.helpers');
local buffTable = require('bufftable');

local debuffHandler =
T{
    -- All enemies we have seen take a debuff
    enemies = T{};
};

-- Reusable tables for GetActiveDebuffs to avoid per-frame allocations
-- These are cleared and reused each call instead of creating new tables
local reusableDebuffIds = {};
local reusableDebuffTimes = {};

-- Message type hash tables for O(1) lookup (converted from T{} arrays)
local statusOnMes = {[101]=true, [127]=true, [160]=true, [164]=true, [166]=true, [186]=true, [194]=true, [203]=true, [205]=true, [230]=true, [236]=true, [266]=true, [267]=true, [268]=true, [269]=true, [237]=true, [271]=true, [272]=true, [277]=true, [278]=true, [279]=true, [280]=true, [319]=true, [320]=true, [375]=true, [412]=true, [645]=true, [754]=true, [755]=true, [804]=true};
local statusOffMes = {[64]=true, [159]=true, [168]=true, [204]=true, [206]=true, [321]=true, [322]=true, [341]=true, [342]=true, [343]=true, [344]=true, [350]=true, [378]=true, [531]=true, [647]=true, [805]=true, [806]=true};
local deathMes = {[6]=true, [20]=true, [97]=true, [113]=true, [406]=true, [605]=true, [646]=true};
local spellDamageMes = {[2]=true, [252]=true, [264]=true, [265]=true};
local additionalEffectJobAbilities = {[22]=true, [45]=true, [46]=true, [77]=true}; --energy drain, mug, shield bash, weapon bash
local additionalEffectMes = {[160]=true, [164]=true};
local spikesEffectMes = {[374]=true};

-- Spell duration lookup table for O(1) performance
-- Maps spell IDs to duration (in seconds) and optionally buff ID overrides
local SPELL_DURATIONS = {
    -- Dia/Bio spells
    [23] = {duration = 60},   -- Dia
    [33] = {duration = 60},   -- Diaga
    [230] = {duration = 60},  -- Bio
    [24] = {duration = 120},  -- Dia II
    [231] = {duration = 120}, -- Bio II
    [25] = {duration = 150},  -- Dia III
    [232] = {duration = 150}, -- Bio III

    -- Helix spells (278-285 and 885-892)
    [278] = {duration = 90, buffId = 186}, [279] = {duration = 90, buffId = 186},
    [280] = {duration = 90, buffId = 186}, [281] = {duration = 90, buffId = 186},
    [282] = {duration = 90, buffId = 186}, [283] = {duration = 90, buffId = 186},
    [284] = {duration = 90, buffId = 186}, [285] = {duration = 90, buffId = 186},
    [885] = {duration = 90, buffId = 186}, [886] = {duration = 90, buffId = 186},
    [887] = {duration = 90, buffId = 186}, [888] = {duration = 90, buffId = 186},
    [889] = {duration = 90, buffId = 186}, [890] = {duration = 90, buffId = 186},
    [891] = {duration = 90, buffId = 186}, [892] = {duration = 90, buffId = 186},

    -- Regular debuff spells
    [58] = {duration = 120},  -- Paralyze
    [80] = {duration = 120},  -- Paralyze II
    [56] = {duration = 180},  -- Slow
    [79] = {duration = 180},  -- Slow II
    [216] = {duration = 120}, -- Gravity
    [254] = {duration = 180}, -- Blind
    [276] = {duration = 180}, -- Blind II
    [59] = {duration = 120},  -- Silence
    [359] = {duration = 120}, -- Silencega
    [253] = {duration = 60},  -- Sleep
    [273] = {duration = 60},  -- Sleepga
    [363] = {duration = 60},  -- Sleepga II
    [259] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}}, -- Sleep II
    [274] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}}, -- Sleepga II
    [364] = {duration = 90, buffId = 19, clearsBuffs = {2, 193}}, -- Sleepga III
    [258] = {duration = 60},  -- Bind
    [362] = {duration = 60},  -- Bindga
    [252] = {duration = 5},   -- Stun
    [220] = {duration = 90},  -- Poison
    [221] = {duration = 120}, -- Poison II

    --buff spells
    [100] = {duration = 180, buffId = 94, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enfire
    [101] = {duration = 180, buffId = 95, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enblizzard
    [102] = {duration = 180, buffId = 96, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enaero
    [103] = {duration = 180, buffId = 97, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enstone
    [104] = {duration = 180, buffId = 98, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enthunder
    [105] = {duration = 180, buffId = 99, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enwater
    [310] = {duration = 300, buffId = 274, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Enlight
    [311] = {duration = 300, buffId = 275, clearsBuffs = {94, 95, 96, 97, 98, 99, 310, 311}}, -- Endark

    -- Ninjutsu debuffs
    [341] = {duration = 180}, -- Kurayami: Ichi
    [344] = {duration = 180}, -- Hojo: Ichi
    [347] = {duration = 180}, -- Dokumori: Ichi
    [342] = {duration = 300}, -- Kurayami: Ni
    [345] = {duration = 300}, -- Hojo: Ni
    [348] = {duration = 300}, -- Dokumori: Ni
    [338] = {duration = 900, buffId = 445}, -- Utsusemi: Ichi
    [339] = {duration = 900, buffId = 446}, -- Utsusemi: Ni

    -- Elemental debuffs (Burn, Frost, Choke, Rasp, Shock, Drown)
    [235] = {duration = 120}, [236] = {duration = 120},
    [237] = {duration = 120}, [238] = {duration = 120},
    [239] = {duration = 120}, [240] = {duration = 120},

    -- Threnodies (454-461)
    [454] = {duration = 78}, [455] = {duration = 78},
    [456] = {duration = 78}, [457] = {duration = 78},
    [458] = {duration = 78}, [459] = {duration = 78},
    [460] = {duration = 78}, [461] = {duration = 78},

    -- Elegies
    [422] = {duration = 216}, -- Carnage Elegy
    [421] = {duration = 216}, -- Battlefield Elegy

    -- Bard songs
    [376] = {duration = 30}, -- Foe Lullaby
    [463] = {duration = 30}, -- Horde Lullaby
    [321] = {duration = 60}, -- Bully

    -- 2-Hour abilities
    [688] = {duration = 45}, -- Mighty Strikes
    [690] = {duration = 45}, -- Hundred Fists
    [691] = {duration = 60}, -- Manafont
    [692] = {duration = 60}, -- Chainspell
    [693] = {duration = 30}, -- Perfect Dodge
    [694] = {duration = 30}, -- Invincible
    [695] = {duration = 30}, -- Blood Weapon

    -- Additional effect debuffs
    [2] = {duration = 25, additionalEffect = true},   -- Sleep Bolt
    [149] = {duration = 60, additionalEffect = true}, -- Defense Down/Acid Bolt
    [12] = {duration = 30, additionalEffect = true},  -- Gravity/Mandau
    [6] = {duration = 60, additionalEffect = true}, -- Silence/Kabura Arrows
    [10] = {duration = 5, additionalEffect = true}, -- Stun
    [3] = {duration = 30, additionalEffect = true}, -- Poison/Venom Bolt

    -- spikes effect debuffs
    [9] = {duration = 180, spikesEffect = true},   -- Iqgira set

    -- Special cases
    [1908] = {duration = 60, buffId = 2, type = 13}, -- Nightmare (pet ability)
};

local WEAPON_SKILL_DURATIONS = {
    -- Weapon skills with debuffs
    [181] = {duration = 180, buffId = 149}, -- Shell Crusher - Defense Down
    [83] = {duration = 180, buffId = 149},  -- Armor Break - Defense Down
    [87] = {duration = 180, buffIds = {149, 147}}, -- Full Break - Defense Down & Attack Down
    [155] = {duration = 180, buffId = 149}, -- Tachi: Ageha - Defense Down
    [187] = {duration = 180, buffId = 149}, -- Garland of Bliss - Defense Down
    [89] = {duration = 180, buffId = 149},  -- Metatron Torment - Defense Down
    [85] = {duration = 180, buffId = 147},  -- Weapon Break - Attack Down
    [185] = {duration = 180, buffId = 147}, -- Gate of Tartarus - Attack Down
    [107] = {duration = 180, buffId = 147}, -- Infernal Scythe - Attack Down
    [16] = {duration = 90, buffId = 3},     -- Wasp Sting - Poison
    [17] = {duration = 90, buffId = 3},     -- Viper Bite - Poison
    [18] = {duration = 30, buffId = 11},    -- Shadowstitch - Bind
    [35] = {duration = 5, buffId = 10},     -- Flat Blade - Stun
    [115] = {duration = 5, buffId = 10},    -- Leg Sweep - Stun
    [2] = {duration = 5, buffId = 10},      -- Shoulder Tackle - Stun
    [65] = {duration = 5, buffId = 10},     -- Smash Axe - Stun
    [162] = {duration = 5, buffId = 10},    -- Brainshaker - Stun
    [145] = {duration = 5, buffId = 10},    -- Tachi: Hobaku - Stun
    [80] = {duration = 180, buffId = 148},  -- Shield Break - Evasion Down
    [73] = {duration = 120, buffId = 146},  -- Onslaught - Accuracy Down
    [170] = {duration = 120, buffId = 148},  -- Randgrith - Evasion Down
    [22] = {duration = 210, buffId = 13},   -- Energy Drain - Slow
}

local PET_ABILITY_DURATIONS = {
    [513] = {duration = 90, buffId = 3, type = 13}, -- ポイズンネイル
    [560] = {duration = 60, buffId = 13, type = 13}, -- ロックスロー
    [562] = {duration = 60, buffId = 11, type = 13}, -- ロックバスター
    [563] = {duration = 120, buffId = 13, type = 13}, -- メガリススロー
    [566] = {duration = 60, buffId = 11, type = 13}, -- マウンテンバスター
    [578] = {duration = 60, buffId = 12, type = 13}, -- テールウィップ
    [624] = {duration = 12, buffId = 10, type = 13}, -- ショックストライク
    [627] = {duration = 60, buffId = 4, type = 13}, -- サンダースパーク
    [630] = {duration = 12, buffId = 10, type = 13}, -- カオスストライク
    [528] = {duration = 60, buffId = 5, type = 13}, -- ムーンリットチャージ
    [529] = {duration = 60, buffId = 4, type = 13}, -- クレセントファング
    [530] = {duration = 180, buffIds = {146, 148}, type = 13}, -- ルナークライ
    [611] = {duration = 90, buffId = 2, type = 13}, -- スリプガ

    [3841] = {duration = 120, buffId = 5, type = 11}, -- 土煙
    [3860] = {duration = 45, buffId = 2, type = 11}, -- シープソング
    [3848] = {duration = 120, buffId = 4, type = 11}, -- 咆哮
    [3844] = {duration = 30, buffId = 2, type = 11}, -- 夢想花
    [3845] = {duration = 112, buffId = 138, type = 11}, -- 種まき
    [3846] = {duration = 18, buffId = 3, type = 11}, -- リーフダガー
    [3847] = {duration = 35, buffId = 141, type = 11}, -- スクリーム
    [660] = {duration = 60, buffId = 3, type = 11}, -- 毒液
    [3851] = {duration = 5, buffId = 10, type = 11}, -- テイルブロー
    [3855] = {duration = 120, buffId = 148, type = 11}, -- 超低周波
    [3854] = {duration = 30, buffId = 6, type = 11}, -- ブレインクラッシュ
    [3876] = {duration = 120, buffId = 148, type = 11}, -- 高周波フィールド
    [3878] = {duration = 180, buffId = 92, type = 11}, -- ライノガード
    [3879] = {duration = 35, buffId = 136, type = 11}, -- スポイル
    [3861] = {duration = 100, buffId = 136, type = 11}, -- バブルシャワー
    [3862] = {duration = 180, buffId = 41, type = 11}, -- バブルカーテン
    [3864] = {duration = 60, buffId = 93, type = 11}, -- シザーガード
    [3865] = {duration = 300, buffId = 37, type = 11}, -- メタルボディ
    [3886] = {duration = 30, buffId = 2, type = 11}, -- サペリフィック
    [3887] = {duration = 180, buffId = 13, type = 11}, -- グロオーサケス
    [3888] = {duration = 60, buffId = 4, type = 11}, -- パルジィパレン
    [3890] = {duration = 5, buffId = 10, type = 11}, -- ナビングノイズ
    [3893] = {duration = 30, buffId = 3, type = 11}, -- トクシックスピット
    [3882] = {duration = 180, buffId = 5, type = 11}, -- サンドブラスト
    [3883] = {duration = 60, buffId = 11, type = 11}, -- サンドピット
    [3884] = {duration = 120, buffId = 3, type = 11}, -- ベノムスプレー
    [3896] = {duration = 120, buffId = 13, type = 11}, -- フィラメンテッドホールド
    [3869] = {duration = 180, buffId = 4, type = 11}, -- スポア
    [3870] = {duration = 60, buffId = 3, type = 11}, -- マヨイタケ
    [3871] = {duration = 180, buffId = 4, type = 11}, -- シビレタケ
    [3872] = {duration = nil, buffId = 8, type = 11}, -- オドリタケ MEMO:使用不能？
    [3873] = {duration = 50, buffId = 6, type = 11}, -- サイレスガス
    [3874] = {duration = 90, buffId = 5, type = 11}, -- ダークスポア
};

local JOB_ABILITY_DURATIONS = {
    -- Job abilities with debuffs
    [45] = {duration = 30, buffId = 448},  -- Mug - ???
    [46] = {duration = 6, buffId = 10},    -- Shield Bash - Stun
    [77] = {duration = 6, buffId = 10},    -- Weapon Bash - Stun
}

local function ApplyMessage(debuffs, action)

    if (action == nil) then
        return;
    end

    local now = os.time()

    for _, target in pairs(action.Targets) do
        for _, ability in pairs(target.Actions) do

            -- Set up our state
            local spell = action.Param
            local message = ability.Message
            local additionalEffect
            local spikesEffect
            local ent = GetEntity(action.UserIndex)

            if (ability.AdditionalEffect ~= nil and ability.AdditionalEffect.Message ~= nil) then
                additionalEffect = ability.AdditionalEffect.Message
            end
            if (ability.SpikesEffect ~= nil and ability.SpikesEffect.Message ~= nil) then
                spikesEffect = ability.SpikesEffect.Message

                if (ent ~= nil and debuffs[ent.ServerId] == nil) then
                    debuffs[ent.ServerId] = T{};
                end
            end

            if (debuffs[target.Id] == nil) then
                debuffs[target.Id] = T{};
            end

            -- Handle pet abilities (Type 13)
            if action.Type == 13 and spell == 1908 then
                -- Nightmare
                debuffs[target.Id][2] = now + 60
            -- Handle weapon skills (Type 3 with damage message)
            elseif action.Type == 3 and message == 185 then
                local spellData = WEAPON_SKILL_DURATIONS[spell];
                if spellData then
                    if spellData.buffId then
                        debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                    end
                    if spellData.buffIds then
                        for _, buffId in ipairs(spellData.buffIds) do
                            debuffs[target.Id][buffId] = now + spellData.duration;
                        end
                    end
                end
            -- Handle dia/bio/helix spells (Type 4 with damage message)
            elseif action.Type == 4 and spellDamageMes[message] then
                local spellData = SPELL_DURATIONS[spell];
                if spellData then
                    local expiry = now + spellData.duration;
                    if spell == 23 or spell == 24 or spell == 25 or spell == 33 then
                        -- Dia spells - set dia, clear bio
                        debuffs[target.Id][134] = expiry;
                        debuffs[target.Id][135] = nil;
                    elseif spell == 230 or spell == 231 or spell == 232 then
                        -- Bio spells - set bio, clear dia
                        debuffs[target.Id][134] = nil;
                        debuffs[target.Id][135] = expiry;
                    elseif (spell >= 278 and spell <= 285) or (spell >= 885 and spell <= 892) then
                        -- Helix spells only (don't match weaponskill IDs that share numbers with damage spells)
                        debuffs[target.Id][spellData.buffId] = expiry;
                    end
                end
            -- Handle regular status effect spells
            elseif statusOnMes[message] then
                local buffId = ability.Param or (action.Type == 4 and buffTable.GetBuffIdBySpellId(spell) or nil);
                if (buffId == nil) then
                    return
                end

                local spellData = SPELL_DURATIONS[spell];
                if action.Type == 13 then
                    spellData = PET_ABILITY_DURATIONS[spell];
                end

                if spellData then
                    -- Handle special clear buffs (Sleep II clears Sleep I)
                    if spellData.clearsBuffs then
                        for _, clearBuffId in ipairs(spellData.clearsBuffs) do
                            debuffs[target.Id][clearBuffId] = nil;
                        end
                    end

                    local duration = spellData.duration
                    if config.createTargetHudOnMobs.addEffectLullaby >= 1 and (spell == 376 or spell == 463) then
                        local additional = (config.createTargetHudOnMobs.addEffectLullaby * 0.1) + 1
                        duration = spellData.duration * additional
                    end

                    -- Apply the debuff
                    local finalBuffId = spellData.buffId or buffId;
                    debuffs[target.Id][finalBuffId] = now + duration;
                else
                    -- Unknown status effect - default to 5 minutes
                    debuffs[target.Id][buffId] = now + 300;
                end
            -- Handle dispel effects
            elseif statusOffMes[message] then
                if (ability.Param == nil) then
                    return
                else
                    debuffs[target.Id][ability.Param] = nil
                end
            -- Handle job abilities with additional effects
            elseif action.Type == 3 and additionalEffectJobAbilities[spell] then
                local spellData = JOB_ABILITY_DURATIONS[spell];
                if spellData and spellData.buffId and (message == 185 or spell ~= 22) then
                    -- Only apply if not already present or expired
                    if (debuffs[target.Id][spellData.buffId] == nil or debuffs[target.Id][spellData.buffId] < now) then
                        debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                    end
                end
            -- Handle additional effects (weapon procs, etc.)
            elseif additionalEffect ~= nil and additionalEffectMes[additionalEffect] then
                local buffId = ability.AdditionalEffect.Param;
                if (buffId == nil) then
                    return
                end

                local spellData = SPELL_DURATIONS[buffId];
                if spellData and spellData.additionalEffect then
                    debuffs[target.Id][buffId] = now + spellData.duration;
                else
                    -- Default duration for unknown additional effects
                    debuffs[target.Id][buffId] = now + 30;
                end
            -- Handle spike effects
            elseif spikesEffect ~= nil and spikesEffectMes[spikesEffect] then
                local buffId = ability.SpikesEffect.Param;
                if (buffId == nil) then
                    return
                end

                local spellData = SPELL_DURATIONS[buffId];
                if spellData and spellData.spikesEffect then
                    if debuffs[ent.ServerId][buffId] == null or debuffs[ent.ServerId][buffId] < now then
                        debuffs[ent.ServerId][buffId] = now + spellData.duration;
                    end
                else
                    if debuffs[ent.ServerId][buffId] == null or debuffs[ent.ServerId][buffId] < now then
                        -- Default duration for unknown spikes effects
                        debuffs[ent.ServerId][buffId] = now + 300;
                    end
                end
            -- Handle monsters abilities
            elseif action.Type == 11 and (message == 185 or message == 242) then
                -- local tpName = AshitaCore:GetResourceManager():GetString('monsters.abilities', action.Param - 256, 1);
                -- if tpName ~= nil then
                --     print(action.Param .. ':' .. tpName)
                -- end

                local abiData = PET_ABILITY_DURATIONS[action.Param];
                if abiData ~= nil then
                    if abiData.buffId ~= nil then
                        if message == 185 then
                            for index, value in pairs(debuffs[target.Id]) do
                                if index == abiData.buffId then
                                    return
                                end
                            end
                        end

                        if abiData.duration ~= nil then
                            debuffs[target.Id][abiData.buffId] = now + abiData.duration;
                        else
                            debuffs[target.Id][abiData.buffId] = now + 180;
                        end
                    end
                end
            -- Handle avatar blood pacts
            elseif action.Type == 13 and (message == 317 or message == 144) then
                local tmpAbiParam = action.Param

                -- local tpName = AshitaCore:GetResourceManager():GetString('monsters.abilities', tmpAbiParam - 256, 1);
                -- if tpName ~= nil then
                --     print(tmpAbiParam..':'..tpName)
                -- end

                local abiData = PET_ABILITY_DURATIONS[tmpAbiParam];
                if abiData ~= nil then
                    if abiData.buffId ~= nil then
                        for index, value in pairs(debuffs[target.Id]) do
                            if index == abiData.buffId then
                                return
                            end
                        end

                        if abiData.duration ~= nil then
                            debuffs[target.Id][abiData.buffId] = now + abiData.duration;
                        else
                            debuffs[target.Id][abiData.buffId] = now + 180;
                        end
                    elseif abiData.buffIds ~= nil then
                        for _, buffId in ipairs(abiData.buffIds) do
                            debuffs[target.Id][buffId] = now + abiData.duration;
                        end
                    end
                end
            end
        end
    end
end

local function ClearMessage(debuffs, basic)
    -- if we're tracking a mob that dies, reset its status
    if deathMes[basic.message] and debuffs[basic.target] then
        debuffs[basic.target] = nil
    elseif (basic.message == 321) then --Custom Chi Blast dispel message
        if (debuffs[basic.target] == nil or basic.value == nil) then
            return
        end

        debuffs[basic.target][basic.value] = nil
    elseif statusOffMes[basic.message] then
        if debuffs[basic.target] == nil then
            return
        end

        -- Clear the buffid that just wore off
        if (basic.param ~= nil) then
            if (basic.param == 2) then --Sleep/Lullaby Handling
                debuffs[basic.target][2] = nil
                debuffs[basic.target][193] = nil
                debuffs[basic.target][19] = nil
            else
                debuffs[basic.target][basic.param] = nil
            end
        end
    end
end

debuffHandler.HandleActionPacket = function(e)
    ApplyMessage(debuffHandler.enemies, e);
end

debuffHandler.HandleZonePacket = function(e)
    debuffHandler.enemies = {};
end

debuffHandler.HandleMessagePacket = function(e)
    ClearMessage(debuffHandler.enemies, e)
end

debuffHandler.GetActiveDebuffs = function(serverId)

    if (debuffHandler.enemies[serverId] == nil) then
        return nil
    end

    -- Clear and reuse tables instead of allocating new ones every frame
    -- This significantly reduces garbage collection pressure
    local count = 0;
    for i = 1, #reusableDebuffIds do
        reusableDebuffIds[i] = nil;
        reusableDebuffTimes[i] = nil;
    end

    -- Cache os.time() once instead of calling it repeatedly in the loop
    local currentTime = os.time();

    for buffId, expiryTime in pairs(debuffHandler.enemies[serverId]) do
        if (expiryTime ~= 0 and expiryTime > currentTime) then
            count = count + 1;
            reusableDebuffIds[count] = buffId;
            reusableDebuffTimes[count] = expiryTime - currentTime;
        end
    end

    -- Return nil if no active debuffs (same behavior as before)
    if count == 0 then
        return nil;
    end

    return reusableDebuffIds, reusableDebuffTimes;
end

return debuffHandler;