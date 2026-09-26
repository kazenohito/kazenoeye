-- GNU Licensed by mousseng's XITools repository [https://github.com/mousseng/xitools]
require('common');
-- require('handlers.helpers');
local buffTable = require('util.bufftable');

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
    [232] = {duration = 75}, -- Bio III

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

    -- blue spell
    [524] = {duration = 60, buffId = 146}, -- 土竜巻
    [597] = {duration = 180, buffId = 13}, -- スプラウトスマック -- OK
    [603] = {duration = 60, buffId = 138}, -- 種まき
    [599] = {duration = 180, buffId = 3}, -- マヨイタケ

    [620] = {duration = 60, buffId = 137}, -- バトルダンス -- OK
    [638] = {duration = 90, buffId = 3}, -- 羽根吹雪
    [623] = {duration = 5, buffId = 10}, -- ヘッドバッド -- OK
    [584] = {duration = 60, buffId = 2}, -- シープソング -- OK
    [618] = {duration = 60, buffId = 11}, -- 炸裂弾 -- OK

    [536] = {duration = 60, buffId = 3}, -- ポイズンブレス
    [598] = {duration = 90, buffId = 2}, -- サペリフィック -- OK

    [582] = {duration = 120, buffId = 6}, -- カオティックアイ -- OK
    [572] = {duration = 30, buffId = 140}, -- サウンドブラスト -- OK
    [596] = {duration = 90, buffId = 2}, -- まつぼっくり爆弾 -- OK?
    [534] = {duration = 120, buffId = 12}, -- 神秘の光
    [539] = {duration = 60, buffId = 147}, -- テラータッチ

    [513] = {duration = 60, buffId = 3}, -- ベノムシェル
    [537] = {duration = 60, buffId = 138}, -- スティンキングガス -- OK
    [532] = {duration = 5, buffId = 10}, -- B.シュトラール -- OK
    [606] = {duration = 30, buffId = 136}, -- アーフルアイ
    [555] = {duration = 60, buffId = 12}, -- 磁鉄粉 -- OK
    [575] = {duration = 5, buffId = 28}, -- ジェタチュラ
    [531] = {duration = 30, buffId = 11}, -- アイスブレイク -- OK
    [561] = {duration = 180, buffId = 149}, -- フライトフルロア -- OK

    [535] = {duration = 60, buffId = 129}, -- コールドウェーブ -- OK
    [548] = {duration = 90, buffId = 13}, -- F.ホールド -- OK
    [563] = {duration = 60, buffId = 5}, -- ヘカトンウェーブ -- OK
    [565] = {duration = 90, buffIds = {6, 13}}, -- R.ブレス
    [634] = {duration = 30, buffIds = {5, 11}}, -- 贖罪の光 -- OK
    [652] = {duration = 60, buffId = 146}, -- スパイラルスピン

    [604] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}}, -- 臭い息
    [515] = {duration = 60, buffId = 136}, -- メイルシュトロム
    [650] = {duration = 120, buffId = 147}, -- シードスプレー
    [631] = {duration = 180, buffId = 171}, -- ハイドロショット
    [628] = {duration = 5, buffId = 10}, -- フライパン
    [576] = {duration = 80, buffId = 2}, -- ヤーン
    [610] = {duration = 60, buffId = 148}, -- 超低周波
    [621] = {duration = 120, buffId = 5}, -- サンドスプレー
    [608] = {duration = 60, buffId = 4}, -- フロストブレス
    [651] = {duration = 90, buffIds = {147, 149}}, -- コローシブウーズ
    [633] = {duration = 30, buffIds = {149, 167}}, -- 吶喊
    [640] = {duration = 5, buffId = 10}, -- テールスラップ
    [648] = {duration = 60, buffId = 11}, -- リガージテーション

    [588] = {duration = 60, buffId = 31}, -- ロウイン
    [611] = {duration = 180, buffId = 3}, -- ディセバーメント
    [654] = {duration = 180, buffId = 4}, -- サブゼロスマッシュ
    [616] = {duration = 5, buffId = 10}, -- テンポラルシフト
    [644] = {duration = 90, buffId = 4}, -- マインドブラスト
    [612] = {duration = 12, buffId = 156}, -- A.バースト
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

    -- Fomor
    [243] = {duration = 300, buffId = 149}, -- 破鎧陣
    [251] = {duration = 300, buffId = 149}, -- 破鎧陣
    [244] = {duration = 300, buffId = 133}, -- 舞空鎖
    [252] = {duration = 300, buffId = 133}, -- 舞空鎖
    [245] = {duration = 300, buffId = 146}, -- 偃月刃
    [253] = {duration = 300, buffId = 146}, -- 偃月刃
    [241] = {duration = 60, buffId = 11}, -- 剣山獄
    [249] = {duration = 60, buffId = 11}, -- 剣山獄
    [247] = {duration = 5, buffId = 10}, -- 跳弧斬
}

local PET_ABILITY_DURATIONS = {
    -- mobs
    -- orc
    [608] = {duration = 600, buffId = 93, type = 11}, -- アームブロック
    [1060] = {duration = 600, buffId = 93, type = 11}, -- アームブロック
    [633] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [757] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [758] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [759] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [760] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [761] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [762] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [763] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [764] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [765] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [766] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1062] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1072] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1079] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1512] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1514] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [1516] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [2227] = {duration = 180, buffId = 68, type = 11}, -- 雄叫び
    [605] = {duration = 5, buffId = 10, type = 11}, -- エアリアルホイール
    [1057] = {duration = 5, buffId = 10, type = 11}, -- エアリアルホイール
    [607] = {duration = 60, buffId = 11, type = 11}, -- スラムダンク
    [1059] = {duration = 60, buffId = 11, type = 11}, -- スラムダンク
    [1511] = {duration = 60, buffId = 11, type = 11}, -- スラムダンク
    [609] = {duration = 180, buffId = 137, type = 11}, -- バトルダンス
    [1061] = {duration = 180, buffId = 137, type = 11}, -- バトルダンス
    -- orcish warmachine
    [638] = {duration = 30, buffId = 11, type = 11}, -- 炸裂弾
    -- quadav
    [613] = {duration = 5, buffId = 10, type = 11}, -- シェルバッシュ
    [1077] = {duration = 5, buffId = 10, type = 11}, -- シェルバッシュ
    [2225] = {duration = 5, buffId = 10, type = 11}, -- シェルバッシュ
    [300] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [612] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [1076] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [1584] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [2224] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [3354] = {duration = 5, buffId = 10, type = 11}, -- ヘッドバット
    [614] = {duration = 600, buffId = 93, type = 11}, -- シェルガード
    [1078] = {duration = 600, buffId = 93, type = 11}, -- シェルガード
    [2226] = {duration = 600, buffId = 93, type = 11}, -- シェルガード
    [1074] = {duration = 10, buffId = 12, type = 11}, -- グ・ダの怒り
    [1080] = {duration = 10, buffId = 12, type = 11}, -- グ・ダの怒り
    [2228] = {duration = 10, buffId = 12, type = 11}, -- グ・ダの怒り
    -- yagudo
    [617] = {duration = 45, buffId = 3, type = 11}, -- 羽根吹雪
    [1068] = {duration = 45, buffId = 3, type = 11}, -- 羽根吹雪
    [618] = {duration = 5, buffId = 10, type = 11}, -- 飛燕双脚
    [1069] = {duration = 5, buffId = 10, type = 11}, -- 飛燕双脚
    [1515] = {duration = 5, buffId = 10, type = 11}, -- 飛燕双脚
    [2381] = {duration = 5, buffId = 10, type = 11}, -- 飛燕双脚
    [620] = {duration = 5, buffId = 10, type = 11}, -- 草払い
    [1071] = {duration = 5, buffId = 10, type = 11}, -- 草払い
    [619] = {duration = 600, buffId = 93, type = 11}, -- 受け流し
    [1070] = {duration = 600, buffId = 93, type = 11}, -- 受け流し
    [1067] = {duration = 30, buffId = 15, type = 11}, -- 死の宣告
    [1073] = {duration = 30, buffId = 15, type = 11}, -- 死の宣告
    [2139] = {duration = 30, buffId = 15, type = 11}, -- 死の宣告
    [3817] = {duration = 30, buffId = 15, type = 11}, -- 死の宣告
    -- goblin
    [1081] = {duration = 5, buffId = 10, type = 11}, -- フライパン
    [1092] = {duration = 5, buffId = 10, type = 11}, -- フライパン
    [4125] = {duration = 5, buffId = 10, type = 11}, -- フライパン
    [1086] = {duration = 120, buffId = 4, type = 11}, -- パラライズシャワー
    [1087] = {duration = 120, buffId = 4, type = 11}, -- パラライズシャワー
    [1097] = {duration = 120, buffId = 4, type = 11}, -- パラライズシャワー
    [1098] = {duration = 120, buffId = 4, type = 11}, -- パラライズシャワー
    [2707] = {duration = 120, buffId = 4, type = 11}, -- パラライズシャワー
    [1082] = {duration = 120, buffId = 5, type = 11}, -- スモークスクリーン
    [1083] = {duration = 120, buffId = 5, type = 11}, -- スモークスクリーン
    [1093] = {duration = 120, buffId = 5, type = 11}, -- スモークスクリーン
    [1094] = {duration = 120, buffId = 5, type = 11}, -- スモークスクリーン
    [2706] = {duration = 120, buffId = 5, type = 11}, -- スモークスクリーン
    -- [XXXX] = {duration = 300, buffId = XXXX, type = 11}, -- 運命のダイス
    -- Antica
    [792] = {duration = 90, buffId = 5, type = 11}, -- 砂塵
    [3549] = {duration = 90, buffId = 5, type = 11}, -- 砂塵
    [796] = {duration = 120, buffId = 6, type = 11}, -- 妨害音波
    [793] = {duration = 120, buffId = 92, type = 11}, -- サンドヴェール
    [3550] = {duration = 120, buffId = 92, type = 11}, -- サンドヴェール
    [794] = {duration = 90, buffId = 93, type = 11}, -- サンドシールド
    [791] = {duration = 60, buffId = 12, type = 11}, -- 磁鉄粉
    [795] = {duration = 15, buffId = 7, type = 11}, -- 砂の呪縛
    [789] = {duration = 60, buffId = 3, type = 11}, -- スパイクボール
    -- Sahagin
    [771] = {duration = 120, buffId = 136, type = 11}, -- ハイドロボール
    [772] = {duration = 120, buffId = 136, type = 11}, -- ハイドロボール
    [773] = {duration = 120, buffId = 136, type = 11}, -- ハイドロボール
    [780] = {duration = 5, buffId = 10, type = 11}, -- スピニングフィン
    [781] = {duration = 5, buffId = 10, type = 11}, -- スピニングフィン
    [782] = {duration = 5, buffId = 10, type = 11}, -- スピニングフィン
    [774] = {duration = 180, buffId = 41, type = 11}, -- バブルアーマー
    [775] = {duration = 180, buffId = 41, type = 11}, -- バブルアーマー
    [776] = {duration = 180, buffId = 41, type = 11}, -- バブルアーマー
    -- Tonberry
    [786] = {duration = 30, buffId = 149, type = 11}, -- 胴斬り
    [787] = {duration = 30, buffId = 146, type = 11}, -- 袈裟斬り
    [784] = {duration = 15, buffId = 92, type = 11}, -- ため息
    [783] = {duration = 45, buffId = 9, type = 11}, -- 呪いの言葉
    [785] = {duration = 60, buffIds = {5, 11}, type = 11}, -- 贖罪の光
    -- Bugbear
    [361] = {duration = 5, buffId = 10, type = 11}, -- アースショック
    [359] = {duration = 60, buffId = 61, type = 11}, -- バイオニックブースト
    -- Mamool Ja
    [1734] = {duration = 60, buffIds = {90, 92}, type = 11}, -- ワームアップ
    [1924] = {duration = 60, buffIds = {90, 92}, type = 11}, -- ワームアップ
    [1800] = {duration = 120, buffIds = {3, 31, 13}, type = 11}, -- マイアズマ
    -- Lamia
    [1758] = {duration = 5, buffId = 10, type = 11}, -- テールスラップ
    [1771] = {duration = 5, buffId = 10, type = 11}, -- テールスラップ
    [1810] = {duration = 5, buffId = 10, type = 11}, -- テールスラップ
    [1759] = {duration = 30, buffId = 16, type = 11}, -- 恍惚のダンス
    -- [XXXX] = {duration = 300, buffId = XXXX, type = 11}, -- ドゥッケリペン
    -- Qiqirn
    [1725] = {duration = 60, buffId = 16, type = 11}, -- カイボッシュ
    [1727] = {duration = 150, buffId = 5, type = 11}, -- サンドスプレー
    [1728] = {duration = 10, buffId = 28, type = 11}, -- 猫だまし
    [1730] = {duration = 120, buffIds = {149, 167}, type = 11}, -- デッドアイ
    -- Troll
    [1743] = {duration = 45, buffId = 7, type = 11}, -- ロックスマッシュ
    [1896] = {duration = 45, buffId = 7, type = 11}, -- ロックスマッシュ
    [2076] = {duration = 45, buffId = 7, type = 11}, -- ロックスマッシュ
    [1744] = {duration = 300, buffId = 37, type = 11}, -- 金剛身
    [1897] = {duration = 300, buffId = 37, type = 11}, -- 金剛身
    [2077] = {duration = 300, buffId = 37, type = 11}, -- 金剛身
    [1745] = {duration = 30, buffIds = {149, 167}, type = 11}, -- 吶喊
    [1898] = {duration = 30, buffIds = {149, 167}, type = 11}, -- 吶喊
    [2078] = {duration = 30, buffIds = {149, 167}, type = 11}, -- 吶喊
    [1746] = {duration = 60, buffId = 45, type = 11}, -- クェークストンプ
    [1899] = {duration = 60, buffId = 45, type = 11}, -- クェークストンプ
    [2079] = {duration = 60, buffId = 45, type = 11}, -- クェークストンプ
    [2083] = {duration = 60, buffId = 11, type = 11}, -- ドロップハンマー
    -- [2084] = {duration = 300, buffId = 7, type = 11}, -- サイズモハンマー?
    [1749] = {duration = 180, buffId = 42, type = 11}, -- 力足
    [1900] = {duration = 180, buffId = 42, type = 11}, -- 力足
    [1802] = {duration = 60, buffId = 7, type = 11}, -- スレッジハンマー
    [1804] = {duration = 60, buffId = 16, type = 11}, -- ヘイメーカー
    [1806] = {duration = 300, buffId = 152, type = 11}, -- 大力足
    [1807] = {duration = 120, buffIds = {3, 4, 6, 13, 11, 12, 31}, type = 11}, -- プレアデスレイ
    -- Poroggo
    [1957] = {duration = 60, buffIds = {14, 127}, type = 11}, -- カエルの歌
    [2907] = {duration = 60, buffIds = {14, 127}, type = 11}, -- カエルの歌
    [1959] = {duration = 60, buffId = 6, type = 11}, -- 水風船爆弾
    [1960] = {duration = 300, buffIds = {190, 79}, type = 11}, -- カエルの応援
    [1962] = {duration = 60, buffIds = {14, 127}, type = 11}, -- カエルの大合唱
    [2908] = {duration = 60, buffIds = {14, 127}, type = 11}, -- カエルの大合唱
    -- Coeurl
    [653] = {duration = 60, buffId = 6, type = 11}, -- カオティックアイ
    [3898] = {duration = 60, buffId = 6, type = 11}, -- カオティックアイ
    [652] = {duration = 60, buffId = 4, type = 11}, -- ブラスター
    [2611] = {duration = 60, buffId = 4, type = 11}, -- ブラスター
    [3899] = {duration = 60, buffId = 4, type = 11}, -- ブラスター
    [480] = {duration = 60, buffId = 7, type = 11}, -- 石の吐息
    -- Dhalmel
    [280] = {duration = 180, buffId = 149, type = 11}, -- ソニックウェーブ
    [1561] = {duration = 180, buffId = 149, type = 11}, -- ソニックウェーブ
    [284] = {duration = 60, buffId = 6, type = 11}, -- 白眼視
    [1563] = {duration = 60, buffId = 6, type = 11}, -- 白眼視
    [285] = {duration = 210, buffId = 83, type = 11}, -- ホイッスル
    [1564] = {duration = 210, buffId = 83, type = 11}, -- ホイッスル
    [286] = {duration = 120, buffId = 56, type = 11}, -- バーサク
    [1565] = {duration = 120, buffId = 56, type = 11}, -- バーサク
    -- Rabbit
    [258] = {duration = 120, buffId = 5, type = 11}, -- 土煙
    [1568] = {duration = 120, buffId = 5, type = 11}, -- 土煙
    [661] = {duration = 120, buffId = 4, type = 11}, -- 雪煙
    [3902] = {duration = 120, buffId = 4, type = 11}, -- 雪煙
    -- Sheep
    [264] = {duration = 45, buffId = 2, type = 11}, -- シープソング
    [1634] = {duration = 45, buffId = 2, type = 11}, -- シープソング
    [3433] = {duration = 45, buffId = 2, type = 11}, -- シープソング
    [261] = {duration = 120, buffId = 56, type = 11}, -- レイジ
    [263] = {duration = 90, buffId = 13, type = 11}, -- シープクライ
    [1633] = {duration = 90, buffId = 13, type = 11}, -- シープクライ
    [1837] = {duration = 90, buffId = 4, type = 11}, -- 小咆哮
    -- Ram
    [265] = {duration = 120, buffId = 56, type = 11}, -- レイジ
    [268] = {duration = 120, buffId = 144, type = 11}, -- 大咆哮
    [267] = {duration = 45, buffId = 148, type = 11}, -- 地鳴り
    [269] = {duration = 120, buffId = 7, type = 11}, -- ペトロブレス
    -- Tiger
    [270] = {duration = 120, buffId = 4, type = 11}, -- 咆哮
    [1677] = {duration = 120, buffId = 4, type = 11}, -- 咆哮
    [2406] = {duration = 120, buffId = 4, type = 11}, -- 咆哮
    -- Behemoth
    [378] = {duration = 16, buffId = 10, type = 11}, -- サンダーボルト
    [629] = {duration = 16, buffId = 10, type = 11}, -- サンダーボルト
    [1686] = {duration = 16, buffId = 10, type = 11}, -- サンダーボルト
    [3526] = {duration = 16, buffId = 10, type = 11}, -- サンダーボルト
    [632] = {duration = 180, buffId = 34, type = 11}, -- フレイムアーマー
    [630] = {duration = 120, buffId = 5, type = 11}, -- ダストストーム
    -- Manticore
    [801] = {duration = 60, buffId = 144, type = 11}, -- リドル
    [1629] = {duration = 60, buffId = 144, type = 11}, -- リドル
    [801] = {duration = 60, buffId = 144, type = 11}, -- リドル
    [798] = {duration = 90, buffId = 11, type = 11}, -- テールスイング
    [3801] = {duration = 90, buffId = 11, type = 11}, -- テールスイング
    [799] = {duration = 90, buffId = 11, type = 11}, -- テールスマッシュ
    [3804] = {duration = 90, buffId = 11, type = 11}, -- テールスマッシュ
    [802] = {duration = 180, buffId = 5, type = 11}, -- 大砂塵
    [1630] = {duration = 180, buffId = 5, type = 11}, -- 大砂塵
    [3805] = {duration = 180, buffId = 5, type = 11}, -- 大砂塵
    [803] = {duration = 90, buffId = 130, type = 11}, -- 大旋風
    [1631] = {duration = 90, buffId = 130, type = 11}, -- 大旋風
    [3806] = {duration = 90, buffId = 130, type = 11}, -- 大旋風
    -- Opo-opo
    [294] = {duration = 60, buffId = 5, type = 11}, -- アイスクラッチ
    [291] = {duration = 60, buffId = 3, type = 11}, -- クローストーム
    [289] = {duration = 60, buffId = 4, type = 11}, -- 投石
    -- Buffalo
    [496] = {duration = 60, buffId = 92, type = 11}, -- ラビッドダンス
    [493] = {duration = 120, buffId = 4, type = 11}, -- ランパントナウ
    [497] = {duration = 60, buffId = 31, type = 11}, -- ロウイン
    -- Marid
    [1703] = {duration = 90, buffIds = {191, 429}, type = 11}, -- 牙門
    -- Cerberus
    [1790] = {duration = 60, buffId = 128, type = 11}, -- ゲーツオブハデス
    [3521] = {duration = 60, buffId = 128, type = 11}, -- ゲーツオブハデス
    [1789] = {duration = 180, buffIds = {37, 34}, type = 11}, -- マグマホプロン
    [3522] = {duration = 180, buffIds = {37, 34}, type = 11}, -- マグマホプロン
    [1788] = {duration = 120, buffId = 4, type = 11}, -- ユルレーション
    -- Beetle
    [343] = {duration = 300, buffId = 136, type = 11}, -- スポイル
    [339] = {duration = 180, buffId = 148, type = 11}, -- 高周波フィールド
    [341] = {duration = 180, buffId = 92, type = 11}, -- ライノガード
    -- Crawler
    [346] = {duration = 180, buffId = 93, type = 11}, -- コクーン
    [1583] = {duration = 180, buffId = 93, type = 11}, -- コクーン
    [345] = {duration = 60, buffId = 3, type = 11}, -- ポイズンブレス
    [466] = {duration = 300, buffId = 3, type = 11}, -- ポイズンブレス
    [643] = {duration = 180, buffId = 3, type = 11}, -- ポイズンブレス
    [1169] = {duration = 180, buffId = 3, type = 11}, -- ポイズンブレス
    [1179] = {duration = 180, buffId = 3, type = 11}, -- ポイズンブレス
    [1582] = {duration = 60, buffId = 3, type = 11}, -- ポイズンブレス
    [2229] = {duration = 300, buffId = 3, type = 11}, -- ポイズンブレス
    [344] = {duration = 180, buffId = 13, type = 11}, -- 粘糸
    [1581] = {duration = 180, buffId = 13, type = 11}, -- 粘糸
    -- Fly
    [1623] = {duration = 60, buffId = 3, type = 11}, -- 毒液
    [2231] = {duration = 60, buffId = 3, type = 11}, -- 毒液
    [3881] = {duration = 60, buffId = 3, type = 11}, -- 毒液
    -- Spider
    [812] = {duration = 90, buffId = 13, type = 11}, -- スパイダーウェブ
    [961] = {duration = 90, buffId = 13, type = 11}, -- スパイダーウェブ
    [3944] = {duration = 90, buffId = 13, type = 11}, -- スパイダーウェブ
    [811] = {duration = 60, buffId = 3, type = 11}, -- アシッドスプレー
    [960] = {duration = 60, buffId = 3, type = 11}, -- アシッドスプレー
    [3943] = {duration = 60, buffId = 3, type = 11}, -- アシッドスプレー
    -- Antlion
    [276] = {duration = 60, buffId = 1, type = 11}, -- サンドピット
    [1842] = {duration = 60, buffId = 1, type = 11}, -- サンドピット
    [275] = {duration = 180, buffId = 5, type = 11}, -- サンドブラスト
    [1841] = {duration = 180, buffId = 5, type = 11}, -- サンドブラスト
    [277] = {duration = 120, buffId = 3, type = 11}, -- ベノムスプレー
    [1843] = {duration = 120, buffId = 3, type = 11}, -- ベノムスプレー
    -- Diremite
    [364] = {duration = 120, buffId = 13, type = 11}, -- フィラメンテッドホールド
    [1456] = {duration = 120, buffId = 13, type = 11}, -- フィラメンテッドホールド
    [1691] = {duration = 120, buffId = 13, type = 11}, -- フィラメンテッドホールド
    -- [1361] = {duration = 300, buffIds = {13, 12}, type = 11}, -- 粘粘
    -- Wamoura
    -- [1952] = {duration = 180, buffId = 33, type = 11}, -- エラチックフラッター TODO:
    [1954] = {duration = 30, buffId = 134, type = 11}, -- 妖鱗粉
    -- Wamouracampa
    [1819] = {duration = 300, buffIds = {34, 94}, type = 11}, -- ヒートバリア
    [1817] = {duration = 30, buffId = 5, type = 11}, -- サーマルパルス
    [1816] = {duration = 60, buffId = 128, type = 11}, -- ヴィットリアリクスプレー
    [1815] = {duration = 120, buffId = 93, type = 11}, -- アンバースクトゥム
    -- Giant Bat
    [392] = {duration = 180, buffId = 148, type = 11}, -- 超音波
    [1662] = {duration = 180, buffId = 148, type = 11}, -- 超音波
    [1155] = {duration = 180, buffId = 149, type = 11}, -- サブソニクス
    [1664] = {duration = 180, buffId = 149, type = 11}, -- サブソニクス
    -- Triple Bats
    [393] = {duration = 180, buffId = 147, type = 11}, -- ソニックブーム
    [1666] = {duration = 180, buffId = 147, type = 11}, -- ソニックブーム
    [1157] = {duration = 120, buffId = 146, type = 11}, -- スリップストリーム
    [1668] = {duration = 120, buffId = 146, type = 11}, -- スリップストリーム
    -- Bird
    [1161] = {duration = 16, buffId = 10, type = 11}, -- ダムネーションダイブ
    [1445] = {duration = 16, buffId = 10, type = 11}, -- ダムネーションダイブ
    [1580] = {duration = 16, buffId = 10, type = 11}, -- ダムネーションダイブ
    -- Cockatrice
    [408] = {duration = 120, buffId = 6, type = 11}, -- サウンドバキューム
    [1601] = {duration = 120, buffId = 6, type = 11}, -- サウンドバキューム
    [410] = {duration = 180, buffId = 140, type = 11}, -- サウンドブラスト
    [1602] = {duration = 180, buffId = 140, type = 11}, -- サウンドブラスト
    [411] = {duration = 120, buffId = 7, type = 11}, -- 邪視
    [1603] = {duration = 120, buffId = 7, type = 11}, -- 邪視
    [407] = {duration = 60, buffId = 3, type = 11}, -- ポイズンピック
    [1600] = {duration = 60, buffId = 3, type = 11}, -- ポイズンピック
    -- Roc
    [401] = {duration = 5, buffId = 10, type = 11}, -- ドレッドダイヴ
    [924] = {duration = 5, buffId = 10, type = 11}, -- ドレッドダイヴ
    [1659] = {duration = 5, buffId = 10, type = 11}, -- ドレッドダイヴ
    [399] = {duration = 120, buffId = 5, type = 11}, -- ブラインヴォルテクス
    [922] = {duration = 120, buffId = 5, type = 11}, -- ブラインヴォルテクス
    [1657] = {duration = 120, buffId = 5, type = 11}, -- ブラインヴォルテクス
    [402] = {duration = 180, buffId = 92, type = 11}, -- フェザーバリア
    [925] = {duration = 180, buffId = 92, type = 11}, -- フェザーバリア
    [1660] = {duration = 180, buffId = 92, type = 11}, -- フェザーバリア
    -- Hippogryph
    [577] = {duration = 10, buffId = 28, type = 11}, -- ジェタチュラ
    [2828] = {duration = 10, buffId = 28, type = 11}, -- ジェタチュラ
    [3916] = {duration = 10, buffId = 28, type = 11}, -- ジェタチュラ
    [579] = {duration = 30, buffIds = {4, 6}, type = 11}, -- チョークブレス
    [1632] = {duration = 30, buffIds = {4, 6}, type = 11}, -- チョークブレス
    [3917] = {duration = 30, buffIds = {4, 6}, type = 11}, -- チョークブレス
    [580] = {duration = 180, buffId = 45, type = 11}, -- ファンタッド
    [3918] = {duration = 180, buffId = 45, type = 11}, -- ファンタッド
    -- Apkallu
    [1713] = {duration = 60, buffId = 2, type = 11}, -- ヤーン
    [2814] = {duration = 60, buffId = 2, type = 11}, -- ヤーン
    [1716] = {duration = 120, buffId = 4, type = 11}, -- クールダンス
    [2817] = {duration = 120, buffId = 4, type = 11}, -- クールダンス
    [1714] = {duration = 5, buffId = 10, type = 11}, -- ウィングスラップ
    [2815] = {duration = 5, buffId = 10, type = 11}, -- ウィングスラップ
    [3922] = {duration = 5, buffId = 10, type = 11}, -- ウィングスラップ
    -- Hecteyes
    [438] = {duration = 120, buffId = 4, type = 11}, -- 凶眼
    [439] = {duration = 25, buffId = 7, type = 11}, -- ペトロゲイズ
    -- Leech
    [415] = {duration = 120, buffId = 147, type = 11}, -- アシッドミスト
    [1872] = {duration = 120, buffId = 147, type = 11}, -- アシッドミスト
    [3907] = {duration = 120, buffId = 147, type = 11}, -- アシッドミスト
    [414] = {duration = 5, buffId = 10, type = 11}, -- 吸着
    [1871] = {duration = 5, buffId = 10, type = 11}, -- 吸着
    [3900] = {duration = 5, buffId = 10, type = 11}, -- 吸着
    [416] = {duration = 120, buffId = 5, type = 11}, -- サンドブレス
    [903] = {duration = 120, buffId = 5, type = 11}, -- サンドブレス
    [1873] = {duration = 120, buffId = 5, type = 11}, -- サンドブレス
    [423] = {duration = 120, buffId = 140, type = 11}, -- ブレインドレイン
    [1878] = {duration = 120, buffId = 140, type = 11}, -- ブレインドレイン
    [418] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    [461] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    [1556] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    [1674] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    [1875] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    [3548] = {duration = 300, buffId = 41, type = 11}, -- リジェネレーション
    -- Worm
    [427] = {duration = 180, buffId = 137, type = 11}, -- 震動
    [1888] = {duration = 180, buffId = 137, type = 11}, -- 震動
    [425] = {duration = 180, buffId = 147, type = 11}, -- 消化液弾
    [1886] = {duration = 180, buffId = 147, type = 11}, -- 消化液弾
    [426] = {duration = 180, buffId = 146, type = 11}, -- 土竜巻
    [1887] = {duration = 180, buffId = 146, type = 11}, -- 土竜巻
    [429] = {duration = 90, buffId = 6, type = 11}, -- サウンドバキューム
    [1890] = {duration = 90, buffId = 6, type = 11}, -- サウンドバキューム
    -- Flan
    [1821] = {duration = 120, buffIds = {190, 191}, type = 11}, -- ねたみ種
    [1822] = {duration = 120, buffId = 167, type = 11}, -- 罵詈雑言
    -- Lizard
    [366] = {duration = 5, buffId = 10, type = 11}, -- テイルブロー
    [369] = {duration = 30, buffId = 6, type = 11}, -- ブレインクラッシュ
    [371] = {duration = 60, buffId = 3, type = 11}, -- プレイグブレス
    [370] = {duration = 60, buffId = 7, type = 11}, -- 邪視
    [372] = {duration = 180, buffId = 148, type = 11}, -- 超低周波
    [373] = {duration = 60, buffId = 92, type = 11}, -- 体液分泌
    -- Raptor
    [380] = {duration = 5, buffId = 10, type = 11}, -- サイズテール
    [1688] = {duration = 5, buffId = 10, type = 11}, -- サイズテール
    [3909] = {duration = 5, buffId = 10, type = 11}, -- サイズテール
    [379] = {duration = 180, buffId = 13, type = 11}, -- 噛みつきラッシュ
    [1687] = {duration = 180, buffId = 13, type = 11}, -- 噛みつきラッシュ
    [3911] = {duration = 180, buffId = 13, type = 11}, -- 噛みつきラッシュ
    [376] = {duration = 180, buffId = 8, type = 11}, -- ファウルブレス
    [1684] = {duration = 180, buffId = 8, type = 11}, -- ファウルブレス
    [377] = {duration = 180, buffId = 4, type = 11}, -- フロストブレス
    [901] = {duration = 180, buffId = 4, type = 11}, -- フロストブレス
    [1685] = {duration = 180, buffId = 4, type = 11}, -- フロストブレス
    -- Adamantoise
    [807] = {duration = 180, buffId = 93, type = 11}, -- 甲羅強化
    [1050] = {duration = 180, buffId = 93, type = 11}, -- 甲羅強化
    [3920] = {duration = 180, buffId = 93, type = 11}, -- 甲羅強化
    [806] = {duration = 180, buffId = 149, type = 11}, -- トータスストンプ
    [1049] = {duration = 180, buffId = 149, type = 11}, -- トータスストンプ
    [3919] = {duration = 180, buffId = 149, type = 11}, -- トータスストンプ
    [805] = {duration = 180, buffId = 146, type = 11}, -- ヘッドバット
    [1048] = {duration = 180, buffId = 146, type = 11}, -- ヘッドバット
    -- Bugard
    [386] = {duration = 180, buffId = 136, type = 11}, -- アーフルアイ
    [1862] = {duration = 180, buffId = 136, type = 11}, -- アーフルアイ
    [384] = {duration = 180, buffId = 93, type = 11}, -- スクトゥム
    [1860] = {duration = 180, buffId = 93, type = 11}, -- スクトゥム
    [387] = {duration = 5, buffId = 10, type = 11}, -- ヘヴィベロー
    [1863] = {duration = 5, buffId = 10, type = 11}, -- ヘヴィベロー
    [385] = {duration = 60, buffId = 31, type = 11}, -- ボーンクランチ
    [1861] = {duration = 60, buffId = 31, type = 11}, -- ボーンクランチ
    -- Eft
    [515] = {duration = 180, buffId = 3, type = 11}, -- トクシックスピット
    [1455] = {duration = 180, buffId = 3, type = 11}, -- トクシックスピット
    [1594] = {duration = 180, buffId = 3, type = 11}, -- トクシックスピット
    [517] = {duration = 6, buffId = 10, type = 11}, -- ナビングノイズ
    [1596] = {duration = 6, buffId = 10, type = 11}, -- ナビングノイズ
    -- Wivre
    [2101] = {duration = 30, buffId = 147, type = 11}, -- デモラライジングロア
    [2102] = {duration = 180, buffIds = {33, 56}, type = 11}, -- ボイリングブラッド
    [2097] = {duration = 60, buffId = 93, type = 11}, -- グラニットスキン
    [2103] = {duration = 60, buffId = 93, type = 11}, -- グラニットスキン
    [2098] = {duration = 180, buffId = 149, type = 11}, -- ブレージングアンゴン
    -- Crab
    [442] = {duration = 180, buffId = 136, type = 11}, -- バブルシャワー
    [1589] = {duration = 180, buffId = 136, type = 11}, -- バブルシャワー
    [443] = {duration = 180, buffId = 41, type = 11}, -- バブルカーテン
    [1590] = {duration = 180, buffId = 41, type = 11}, -- バブルカーテン
    [3474] = {duration = 180, buffId = 41, type = 11}, -- バブルカーテン
    [445] = {duration = 60, buffId = 93, type = 11}, -- シザーガード
    [1592] = {duration = 60, buffId = 93, type = 11}, -- シザーガード
    [3483] = {duration = 60, buffId = 93, type = 11}, -- シザーガード
    [448] = {duration = 300, buffId = 37, type = 11}, -- メタルボディ
    [1593] = {duration = 300, buffId = 37, type = 11}, -- メタルボディ
    [3475] = {duration = 300, buffId = 37, type = 11}, -- メタルボディ
    -- Pugil
    [453] = {duration = 60, buffId = 93, type = 11}, -- ウォーターウォール
    [1868] = {duration = 60, buffId = 93, type = 11}, -- ウォーターウォール
    [3926] = {duration = 60, buffId = 93, type = 11}, -- ウォーターウォール
    [454] = {duration = 30, buffId = 92, type = 11}, -- ウォーターシールド
    [1869] = {duration = 30, buffId = 92, type = 11}, -- ウォーターシールド
    [450] = {duration = 180, buffId = 136, type = 11}, -- アクアボール
    [1865] = {duration = 180, buffId = 136, type = 11}, -- アクアボール
    [446] = {duration = 120, buffId = 13, type = 11}, -- 威嚇
    [449] = {duration = 120, buffId = 13, type = 11}, -- 威嚇
    [1864] = {duration = 120, buffId = 13, type = 11}, -- 威嚇
    [3924] = {duration = 120, buffId = 13, type = 11}, -- 威嚇
    -- Sea Monk
    [458] = {duration = 120, buffId = 5, type = 11}, -- インクジェット
    [1328] = {duration = 120, buffId = 5, type = 11}, -- インクジェット
    [1671] = {duration = 120, buffId = 5, type = 11}, -- インクジェット
    [463] = {duration = 120, buffId = 138, type = 11}, -- 旋風
    [1676] = {duration = 120, buffId = 138, type = 11}, -- 旋風
    [459] = {duration = 180, buffId = 92, type = 11}, -- 粘膜強化
    [1672] = {duration = 180, buffId = 92, type = 11}, -- 粘膜強化
    [3547] = {duration = 180, buffId = 92, type = 11}, -- 粘膜強化
    [462] = {duration = 180, buffId = 136, type = 11}, -- メイルシュトロム
    [1675] = {duration = 180, buffId = 136, type = 11}, -- メイルシュトロム
    -- Uragnite
    [508] = {duration = 90, buffIds = {3, 11}, type = 11}, -- サクトリアルテンタクル
    [1575] = {duration = 90, buffIds = {3, 11}, type = 11}, -- サクトリアルテンタクル
    [506] = {duration = 120, buffId = 4, type = 11}, -- パルジーニクシス
    [1573] = {duration = 120, buffId = 4, type = 11}, -- パルジーニクシス
    [504] = {duration = 90, buffId = 3, type = 11}, -- ガスシェル
    [1571] = {duration = 90, buffId = 3, type = 11}, -- ガスシェル
    [505] = {duration = 120, buffId = 3, type = 11}, -- ベノムシェル
    [1572] = {duration = 120, buffId = 3, type = 11}, -- ベノムシェル
    -- Orobon
    [1697] = {duration = 60, buffId = 13, type = 11}, -- 潮泡
    [1694] = {duration = 30, buffIds = {6, 31}, type = 11}, -- おくび
    [1695] = {duration = 120, buffId = 2, type = 11}, -- ヒプニックランプ
    -- Funguar
    [312] = {duration = 720, buffId = 8, type = 11}, -- オドリタケ
    [311] = {duration = 180, buffId = 4, type = 11}, -- シビレタケ
    [310] = {duration = 60, buffId = 3, type = 11}, -- マヨイタケ
    [2232] = {duration = 60, buffId = 3, type = 11}, -- マヨイタケ
    [309] = {duration = 180, buffId = 4, type = 11}, -- スポア
    [315] = {duration = 90, buffId = 5, type = 11}, -- ダークスポア
    [314] = {duration = 60, buffId = 6, type = 11}, -- サイレスガス
    -- Goobbue
    [586] = {duration = 180, buffId = 4, type = 11}, -- 虚ろな眼
    [3358] = {duration = 180, buffId = 4, type = 11}, -- 虚ろな眼
    [587] = {duration = 90, buffId = 6, type = 11}, -- 逆位相波
    [3357] = {duration = 90, buffId = 6, type = 11}, -- 逆位相波
    [583] = {duration = 60, buffId = 11, type = 11}, -- ビートダウン
    [581] = {duration = 5, buffId = 10, type = 11}, -- ブロー
    [1617] = {duration = 5, buffId = 10, type = 11}, -- ブロー
    [3355] = {duration = 5, buffId = 10, type = 11}, -- ブロー
    -- Mandragora
    [304] = {duration = 120, buffId = 42, type = 11}, -- 光合成
    [324] = {duration = 180, buffId = 42, type = 11}, -- 光合成
    [3352] = {duration = 180, buffId = 42, type = 11}, -- 光合成
    [306] = {duration = 180, buffId = 141, type = 11}, -- スクリーム
    [1588] = {duration = 180, buffId = 141, type = 11}, -- スクリーム
    [302] = {duration = 120, buffId = 138, type = 11}, -- 種まき
    [1586] = {duration = 120, buffId = 138, type = 11}, -- 種まき
    [3351] = {duration = 120, buffId = 138, type = 11}, -- 種まき
    [301] = {duration = 60, buffId = 2, type = 11}, -- 夢想花
    [305] = {duration = 60, buffId = 2, type = 11}, -- 夢想花
    [305] = {duration = 90, buffId = 3, type = 11}, -- リーフダガー
    [1585] = {duration = 90, buffId = 3, type = 11}, -- リーフダガー
    [3794] = {duration = 90, buffId = 3, type = 11}, -- リーフダガー
    -- Morbol
    [320] = {duration = 60, buffId = 2, type = 11}, -- 甘い息
    [728] = {duration = 60, buffId = 2, type = 11}, -- 甘い息
    [3799] = {duration = 60, buffId = 2, type = 11}, -- 甘い息
    [319] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}, type = 11}, -- 臭い息
    [727] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}, type = 11}, -- 臭い息
    [3523] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}, type = 11}, -- 臭い息
    [3531] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}, type = 11}, -- 臭い息
    [3798] = {duration = 60, buffIds = {4, 6, 3, 12, 11, 13, 5}, type = 11}, -- 臭い息
    [316] = {duration = 120, buffId = 4, type = 11}, -- くしざし
    [725] = {duration = 120, buffId = 4, type = 11}, -- くしざし
    -- Treant
    [299] = {duration = 60, buffId = 11, type = 11}, -- エンタングル
    [332] = {duration = 60, buffId = 11, type = 11}, -- エンタングル
    [930] = {duration = 60, buffId = 11, type = 11}, -- エンタングル
    [296] = {duration = 45, buffId = 5, type = 11}, -- ドリルブランチ
    [328] = {duration = 45, buffId = 5, type = 11}, -- ドリルブランチ
    [927] = {duration = 45, buffId = 5, type = 11}, -- ドリルブランチ
    [297] = {duration = 60, buffId = 2, type = 11}, -- まつぼっくり爆弾
    [329] = {duration = 60, buffId = 2, type = 11}, -- まつぼっくり爆弾
    [928] = {duration = 60, buffId = 2, type = 11}, -- まつぼっくり爆弾
    -- Sapling
    [686] = {duration = 30, buffId = 2, type = 11}, -- グーグーパウダー
    [687] = {duration = 90, buffId = 13, type = 11}, -- スプラウトスマック
    -- Flytrap
    [434] = {duration = 30, buffId = 2, type = 11}, -- サペリフィック
    [1615] = {duration = 30, buffId = 2, type = 11}, -- サペリフィック
    [436] = {duration = 180, buffId = 13, type = 11}, -- グロオーサケス
    [1613] = {duration = 180, buffId = 13, type = 11}, -- グロオーサケス
    [1614] = {duration = 180, buffId = 13, type = 11}, -- グロオーサケス
    [3443] = {duration = 180, buffId = 13, type = 11}, -- グロオーサケス
    [435] = {duration = 60, buffId = 4, type = 11}, -- パルジィパレン
    [1454] = {duration = 60, buffId = 4, type = 11}, -- パルジィパレン
    [1616] = {duration = 60, buffId = 4, type = 11}, -- パルジィパレン
    -- Ghost
    -- [474] = {duration = 300, buffId = 13, type = 11}, -- フィアタッチ?
    [475] = {duration = 90, buffId = 147, type = 11}, -- テラータッチ
    [477] = {duration = 300, buffId = 5, type = 11}, -- ダークスフィア
    [476] = {duration = 2280, buffId = 9, type = 11}, -- 呪う
    -- Hound
    [465] = {duration = 60, buffId = 4, type = 11}, -- ハウリング
    [467] = {duration = 360, buffId = 8, type = 11}, -- 腐敗ガス
    [469] = {duration = 30, buffId = 5, type = 11}, -- 闇の爪
    -- Skeleton
    [484] = {duration = 420, buffId = 5, type = 11}, -- ブラッククラウド
    [2764] = {duration = 420, buffId = 5, type = 11}, -- ブラッククラウド
    [479] = {duration = 120, buffId = 13, type = 11}, -- ホラークラウド
    [2763] = {duration = 120, buffId = 13, type = 11}, -- ホラークラウド
    -- Doomed
    [488] = {duration = 180, buffId = 136, type = 11}, -- アシッドブレス
    [492] = {duration = 120, buffId = 5, type = 11}, -- アビスブラスト
    [489] = {duration = 180, buffId = 138, type = 11}, -- スティンキングガス
    [486] = {duration = 5, buffId = 10, type = 11}, -- ホウィップタン
    [491] = {duration = 120, buffId = 140, type = 11}, -- 亡者達の呼び声
    -- Corse
    [532] = {duration = 180, buffId = 9, type = 11}, -- エンバウトメント
    [3626] = {duration = 180, buffId = 9, type = 11}, -- エンバウトメント
    [531] = {duration = 60, buffId = 6, type = 11}, -- サイレンスシール
    [3625] = {duration = 60, buffId = 6, type = 11}, -- サイレンスシール
    [530] = {duration = 300, buffId = 190, type = 11}, -- メメントモーリ
    [3624] = {duration = 300, buffId = 190, type = 11}, -- メメントモーリ
    [3765] = {duration = 300, buffId = 190, type = 11}, -- メメントモーリ
    -- Qutrub
    [1780] = {duration = 16, buffId = 10, type = 11}, -- 一刀両断
    [1782] = {duration = 90, buffId = 33, type = 11}, -- 鯨波
    [1783] = {duration = 120, buffId = 40, type = 11}, -- 大喝
    -- Bomb
    [510] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [526] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [593] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [598] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [697] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [1647] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [2217] = {duration = 180, buffId = 56, type = 11}, -- バーサク
    [512] = {duration = 180, buffId = 128, type = 11}, -- ヒートウェーブ
    [595] = {duration = 180, buffId = 128, type = 11}, -- ヒートウェーブ
    -- Doll
    [534] = {duration = 90, buffId = 2, type = 11}, -- カルトシュトラール
    [535] = {duration = 5, buffId = 10, type = 11}, -- ブリッツシュトラール
    [537] = {duration = 120, buffId = 56, type = 11}, -- ベルセルク
    [541] = {duration = 420, buffId = 13, type = 11}, -- 重力場
    -- Evil Weapon
    [514] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    [1642] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    [4035] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    [4036] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    [4037] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    [4038] = {duration = 5, buffId = 10, type = 11}, -- 怒りの旋風
    -- Magic Pot
    [523] = {duration = 120, buffId = 12, type = 11}, -- 神秘の光
    [524] = {duration = 300, buffId = 141, type = 11}, -- マインドドレイン
    [522] = {duration = 60, buffId = 152, type = 11}, -- スペクトルバリア
    -- Golem
    [677] = {duration = 20, buffId = 10, type = 11}, -- サンダーブレイク
    [1651] = {duration = 20, buffId = 10, type = 11}, -- サンダーブレイク
    [676] = {duration = 120, buffId = 11, type = 11}, -- アイスブレイク
    [1650] = {duration = 120, buffId = 11, type = 11}, -- アイスブレイク
    [674] = {duration = 300, buffId = 40, type = 11}, -- クリスタルシールド
    [1648] = {duration = 300, buffId = 40, type = 11}, -- クリスタルシールド
    -- Mimic
    [588] = {duration = 300, buffIds = {10, 3}, type = 11}, -- デストラップ
    [729] = {duration = 300, buffIds = {10, 3}, type = 11}, -- デストラップ
    [3766] = {duration = 300, buffIds = {10, 3}, type = 11}, -- デストラップ
    -- Cluster
    [570] = {duration = 120, buffId = 12, type = 11}, -- サークルオブフレイム
    [1852] = {duration = 120, buffId = 12, type = 11}, -- サークルオブフレイム
    [569] = {duration = 180, buffId = 33, type = 11}, -- リフュエリング
    [1851] = {duration = 180, buffId = 33, type = 11}, -- リフュエリング
    -- Snoll
    [528] = {duration = 180, buffId = 129, type = 11}, -- コールドウェーブ
    [600] = {duration = 180, buffId = 129, type = 11}, -- コールドウェーブ
    [1646] = {duration = 180, buffId = 129, type = 11}, -- コールドウェーブ
    -- Mammet
    [540] = {duration = 4, buffId = 10, type = 11}, -- トレモロストレッド
    [457] = {duration = 120, buffId = 12, type = 11}, -- グラビティホィール
    -- [441] = {duration = 60, buffId = 11, type = 11}, -- マイクロクェーク
    [471] = {duration = 30, buffId = 152, type = 11}, -- マインドウォール
    -- Omega
    [1235] = {duration = 30, buffId = 11, type = 11}, -- パイルピッチ
    [1533] = {duration = 30, buffId = 11, type = 11}, -- パイルピッチ
    [1237] = {duration = 15, buffIds = 11, type = 11}, -- ハイパーパルス
    [1529] = {duration = 15, buffIds = 11, type = 11}, -- ハイパーパルス
    [1535] = {duration = 15, buffIds = 11, type = 11}, -- ハイパーパルス
    [1239] = {duration = 60, buffIds = {152, 38}, type = 11}, -- ディスチャージャー
    [1537] = {duration = 60, buffIds = {152, 38}, type = 11}, -- ディスチャージャー
    [1240] = {duration = 180, buffId = 4, type = 11}, -- イオンエフラクス
    [1538] = {duration = 180, buffId = 4, type = 11}, -- イオンエフラクス
    [1241] = {duration = 30, buffId = 7, type = 11}, -- リアレーザー
    [1539] = {duration = 30, buffId = 7, type = 11}, -- リアレーザー
    [2914] = {duration = 30, buffId = 7, type = 11}, -- リアレーザー
    [1527] = {duration = 60, buffId = 149, type = 11}, -- レーザーシャワー
    [1528] = {duration = 120, buffIds = {156, 5, 6}, type = 11}, -- フラッドライト
    [1530] = {duration = 120, buffId = 4, type = 11}, -- スタンキャノン
    -- Ultima
    [1269] = {duration = 120, buffIds = {13, 194}, type = 11}, -- ケミカルボム
    [1521] = {duration = 45, buffId = 12, type = 11}, -- アーマーバスター
    [1524] = {duration = 10, buffId = 28, type = 11}, -- ディシペーション
    -- [1268] = {duration = 60, buffId = XXXX, type = 11}, -- ニュークリアウェースト
    [1267] = {duration = 120, buffId = 3, type = 11}, -- ハイドロキャノン
    [1262] = {duration = 120, buffId = 31, type = 11}, -- フレイムスルーアー
    [1263] = {duration = 120, buffId = 4, type = 11}, -- クライオジェット
    [1264] = {duration = 30, buffId = 29, type = 11}, -- ターボファン
    [1266] = {duration = 5, buffId = 10, type = 11}, -- HTディスチャージャー
    [1265] = {duration = 45, buffId = 7, type = 11}, -- スモークディスチャージャー
    -- Khimaira
    [2023] = {duration = 10, buffId = 10, type = 11}, -- サンダーストライク
    [2024] = {duration = 20, buffId = 149, type = 11}, -- トゥールビヨン
    [2025] = {duration = 10, buffId = 28, type = 11}, -- ドレッドストーム
    [2026] = {duration = 60, buffId = 7, type = 11}, -- 岩息
    [2027] = {duration = 60, buffIds = {31, 135}, type = 11}, -- プレイグスワイプ
    [2028] = {duration = 60, buffIds = {10, 4}, type = 11}, -- フルミネーション
    -- Ahriman
    [548] = {duration = 30, buffId = 5, type = 11}, -- ブラインドアイ
    [1136] = {duration = 30, buffId = 5, type = 11}, -- ブラインドアイ
    [550] = {duration = 45, buffId = 2, type = 11}, -- 催眠術
    [1138] = {duration = 45, buffId = 2, type = 11}, -- 催眠術
    [551] = {duration = 10, buffId = 145, type = 11}, -- マインドブレイク
    [1139] = {duration = 10, buffId = 145, type = 11}, -- マインドブレイク
    [552] = {duration = 60, buffId = 11, type = 11}, -- バインドウェーブ
    [1140] = {duration = 60, buffId = 11, type = 11}, -- バインドウェーブ
    [557] = {duration = 15, buffId = 7, type = 11}, -- レベル5石化
    [756] = {duration = 15, buffId = 7, type = 11}, -- レベル5石化
    [1144] = {duration = 15, buffId = 7, type = 11}, -- レベル5石化
    [553] = {duration = 60, buffId = 151, type = 11}, -- エアリーシールド
    [1141] = {duration = 60, buffId = 151, type = 11}, -- エアリーシールド
    [555] = {duration = 60, buffId = 152, type = 11}, -- マジックバリア
    [1143] = {duration = 60, buffId = 152, type = 11}, -- マジックバリア
    -- Demon
    [563] = {duration = 240, buffId = 13, type = 11}, -- デモニックハウル
    [1147] = {duration = 240, buffId = 13, type = 11}, -- デモニックハウル
    [560] = {duration = 120, buffId = 5, type = 11}, -- ヘカトンウェーブ
    [1146] = {duration = 120, buffId = 5, type = 11}, -- ヘカトンウェーブ
    [1152] = {duration = 120, buffId = 5, type = 11}, -- ヘカトンウェーブ
    [564] = {duration = 13, buffId = 10, type = 11}, -- コンデムネーション
    [1148] = {duration = 13, buffId = 10, type = 11}, -- コンデムネーション
    -- Taurus
    [502] = {duration = 45, buffId = 15, type = 11}, -- モータルレイ
    [589] = {duration = 45, buffId = 15, type = 11}, -- モータルレイ
    [1883] = {duration = 45, buffId = 15, type = 11}, -- モータルレイ
    [498] = {duration = 90, buffId = 137, type = 11}, -- トライクリップ
    [1879] = {duration = 90, buffId = 137, type = 11}, -- トライクリップ
    [500] = {duration = 30, buffId = 3, type = 11}, -- モウ
    [1881] = {duration = 30, buffId = 3, type = 11}, -- モウ
    [501] = {duration = 180, buffId = 149, type = 11}, -- フライトフルロア
    [1882] = {duration = 180, buffId = 149, type = 11}, -- フライトフルロア
    [503] = {duration = 180, buffId = 41, type = 11}, -- アンブレストアーマー
    [1884] = {duration = 180, buffId = 41, type = 11}, -- アンブレストアーマー
    -- Imp
    [1709] = {duration = 60, buffId = 16, type = 11}, -- アブレーシブタンタラ
    [1710] = {duration = 30, buffId = 6, type = 11}, -- デフェニングタンタラ
    -- Soulflayer
    [1964] = {duration = 180, buffIds = {190, 191}, type = 11}, -- イモータルマインド
    [1965] = {duration = 300, buffId = 152, type = 11}, -- イモータルシールド
    [1963] = {duration = 15, buffId = 4, type = 11}, -- マインドブラスト
    [1967] = {duration = 120, buffIds = {5, 135}, type = 11}, -- トリビュレーション
    [2069] = {duration = 120, buffIds = {5, 135}, type = 11}, -- トリビュレーション
    [1968] = {duration = 300, buffId = 9, type = 11}, -- イモータルアナテーマ
    -- Dragon
    [646] = {duration = 960, buffId = 4, type = 11}, -- ヘビーストンプ
    [1172] = {duration = 960, buffId = 4, type = 11}, -- ヘビーストンプ
    [1182] = {duration = 960, buffId = 4, type = 11}, -- ヘビーストンプ
    [647] = {duration = 420, buffId = 9, type = 11}, -- カオスブレード
    [1173] = {duration = 420, buffId = 9, type = 11}, -- カオスブレード
    [1183] = {duration = 420, buffId = 9, type = 11}, -- カオスブレード
    [648] = {duration = 420, buffId = 7, type = 11}, -- ペトロアイズ
    [1174] = {duration = 420, buffId = 7, type = 11}, -- ペトロアイズ
    [1184] = {duration = 420, buffId = 7, type = 11}, -- ペトロアイズ
    [650] = {duration = 30, buffId = 153, type = 11}, -- 棘の歌
    [1176] = {duration = 30, buffId = 153, type = 11}, -- 棘の歌
    [1186] = {duration = 30, buffId = 153, type = 11}, -- 棘の歌
    [651] = {duration = 30, buffId = 12, type = 11}, -- 鉛の歌
    [1177] = {duration = 30, buffId = 12, type = 11}, -- 鉛の歌
    [1187] = {duration = 30, buffId = 12, type = 11}, -- 鉛の歌
    -- Wyvern
    [815] = {duration = 15, buffId = 92, type = 11}, -- ウィンドウォール
    [818] = {duration = 60, buffId = 3, type = 11}, -- テールクラッシュ
    [817] = {duration = 60, buffId = 4, type = 11}, -- ドレッドシュリーク
    [821] = {duration = 120, buffIds = {6, 13}, type = 11}, -- レイディアントブレス
    -- Wyrm
    [957] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1045] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1285] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1295] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1305] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1315] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1412] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [1548] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [3246] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [3771] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [3777] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [3783] = {duration = 45, buffId = 28, type = 11}, -- アブソルートテラー
    [951] = {duration = 30, buffId = 5, type = 11}, -- ハリケーンウィング
    [956] = {duration = 30, buffId = 5, type = 11}, -- ハリケーンウィング
    [1039] = {duration = 30, buffId = 5, type = 11}, -- ハリケーンウィング
    [3439] = {duration = 30, buffId = 5, type = 11}, -- ハリケーンウィング
    [1279] = {duration = 120, buffId = 31, type = 11}, -- テバッドウィング
    [1284] = {duration = 120, buffId = 31, type = 11}, -- テバッドウィング
    [3785] = {duration = 120, buffId = 31, type = 11}, -- テバッドウィング
    [3787] = {duration = 120, buffId = 31, type = 11}, -- テバッドウィング
    [1289] = {duration = 120, buffId = 4, type = 11}, -- グレガーレウィング
    [1294] = {duration = 120, buffId = 4, type = 11}, -- グレガーレウィング
    [3779] = {duration = 120, buffId = 4, type = 11}, -- グレガーレウィング
    [3781] = {duration = 120, buffId = 4, type = 11}, -- グレガーレウィング
    [1299] = {duration = 30, buffId = 5, type = 11}, -- タイフーンウィング
    [1406] = {duration = 30, buffId = 5, type = 11}, -- タイフーンウィング
    [1304] = {duration = 120, buffId = 13, type = 11}, -- バイウィング
    [1411] = {duration = 120, buffId = 13, type = 11}, -- バイウィング
    -- [2702] = {duration = 120, buffId = 7, type = 11}, -- テラウィング
    [1309] = {duration = 60, buffId = 2, type = 11}, -- サイクロンウィング
    [1314] = {duration = 60, buffId = 2, type = 11}, -- サイクロンウィング
    [3773] = {duration = 60, buffId = 2, type = 11}, -- サイクロンウィング
    [3775] = {duration = 60, buffId = 2, type = 11}, -- サイクロンウィング
    -- Puk
    [1722] = {duration = 180, buffId = 36, type = 11}, -- ゼファーマント
    [1721] = {duration = 20, buffId = 156, type = 11}, -- 粉塵
    -- Hydra
    [1832] = {duration = 60, buffId = 12, type = 11}, -- バロフィールド
    [1831] = {duration = 45, buffId = 150, type = 11}, -- ポーラーブルワーク
    [1829] = {duration = 45, buffId = 152, type = 11}, -- パイリックブルワーク
    [1828] = {duration = 60, buffId = 31, type = 11}, -- パイリックブラスト
    [1830] = {duration = 60, buffId = 4, type = 11}, -- ポーラーブラスト
    [1836] = {duration = 420, buffIds = {3, 9}, type = 11}, -- ナーブガス
    -- Wanderer
    [390] = {duration = 180, buffId = 92, type = 11}, -- ミラージュ
    [391] = {duration = 30, buffId = 93, type = 11}, -- 記憶の固執
    -- Weeper
    [1218] = {duration = 60, buffIds = {3, 31}, type = 11}, -- 虚ろな接吻
    [1220] = {duration = 90, buffIds = {6, 5}, type = 11}, -- オーロラルドレープ
    [1219] = {duration = 180, buffId = 93, type = 11}, -- ヘキサゴンベルト
    -- Seether
    [1258] = {duration = 20, buffId = 134, type = 11}, -- ラメンテーション
    [1255] = {duration = 300, buffId = 36, type = 11}, -- オカルテーション
    -- Thinker
    [1244] = {duration = 120, buffId = 31, type = 11}, -- 陰鬱な気
    [1252] = {duration = 180, buffIds = {9, 5, 2}, type = 11}, -- シャドウスプレッド
    [1243] = {duration = 60, buffId = 13, type = 11}, -- ネガティヴワール
    [1272] = {duration = 60, buffId = 13, type = 11}, -- ネガティヴワール
    -- Gorger
    [750] = {duration = 90, buffId = 4, type = 11}, -- 陰鬱なガス
    [751] = {duration = 90, buffId = 4, type = 11}, -- 陰鬱なガス
    [752] = {duration = 180, buffId = 93, type = 11}, -- 虚ろなる障壁
    [753] = {duration = 180, buffId = 93, type = 11}, -- 虚ろなる障壁
    [754] = {duration = 180, buffId = 93, type = 11}, -- 虚ろなる障壁
    -- Craver
    [1231] = {duration = 180, buffId = 3, type = 11}, -- 虚ろなる霧
    [1276] = {duration = 180, buffId = 3, type = 11}, -- 虚ろなる霧
    [1229] = {duration = 90, buffId = 4, type = 11}, -- ブレインスパイク
    [1233] = {duration = 180, buffId = 92, type = 11}, -- マテリアルフェンド
    [1232] = {duration = 120, buffIds = {12, 13}, type = 11}, -- マルク
    -- Aern
    [1380] = {duration = 60, buffIds = {10, 93}, type = 11}, -- インパクトストリーム
    [1378] = {duration = 60, buffId = 13, type = 11}, -- ウィングスラスト
    [1379] = {duration = 120, buffId = 6, type = 11}, -- オーロラルウインド
    [1382] = {duration = 120, buffIds = {40, 41}, type = 11}, -- クリスタリンコクーン
    [1383] = {duration = 60, buffId = 4, type = 11}, -- グレイシャースプリッター
    [1384] = {duration = 180, buffId = 3, type = 11}, -- ディセバーメント
    [1385] = {duration = 60, buffId = 31, type = 11}, -- バイオティクブーメラン
    [1386] = {duration = 60, buffId = 7, type = 11}, -- メデューサジャベリン
    -- Euvhi
    [1452] = {duration = 60, buffId = 11, type = 11}, -- アクシアルブルーム
    [1449] = {duration = 60, buffId = 2, type = 11}, -- ストゥパースポア
    [1448] = {duration = 30, buffIds = {5, 6}, type = 11}, -- エッフロレセントフィーター
    [1450] = {duration = 120, buffId = 13, type = 11}, -- ヴィシドネクター
    -- Hpemde
    [1368] = {duration = 30, buffId = 42, type = 11}, -- ラピッドモルト
    [1369] = {duration = 120, buffId = 3, type = 11}, -- イカーストリーム
    [1365] = {duration = 60, buffId = 4, type = 11}, -- テールスラスト
    [1366] = {duration = 6, buffId = 10, type = 11}, -- テンポラルシフト
    -- Phuabo
    -- [1354] = {duration = 300, buffId = 3, type = 11}, -- ヴェイパースプレー
    [1353] = {duration = 75, buffId = 149, type = 11}, -- エリアルコリジョン
    [1355] = {duration = 120, buffId = 31, type = 11}, -- スパインラッシュ
    [1357] = {duration = 120, buffIds = {11, 12}, type = 11}, -- タイダルダイブ
    [1358] = {duration = 60, buffId = 38, type = 11}, -- プラズマチャージ
    [1356] = {duration = 120, buffId = 6, type = 11}, -- ボイスレスストーム
    -- Xzomit
    [1350] = {duration = 60, buffId = 5, type = 11}, -- インククラウド
    [1352] = {duration = 60, buffId = 191, type = 11}, -- セイリーンコート
    [1347] = {duration = 5, buffId = 10, type = 11}, -- デュアルストライク
    [1349] = {duration = 45, buffId = 12, type = 11}, -- マントルピアス
    [1351] = {duration = 60, buffId = 93, type = 11}, -- モラスカスミューテーション
    -- Yovra
    [1375] = {duration = 60, buffId = 133, type = 11}, -- アセニックフォグ
    [1373] = {duration = 6, buffId = 10, type = 11}, -- イオンシャワー
    [1370] = {duration = 180, buffId = 3, type = 11}, -- ヴィトリオリクバラージ
    [1372] = {duration = 120, buffId = 12, type = 11}, -- オシレーション
    [1371] = {duration = 90, buffId = 11, type = 11}, -- プライマルドリル
    [1377] = {duration = 5, buffId = 45, type = 11}, -- フロレセンス
    [1376] = {duration = 25, buffId = 14, type = 11}, -- ルミナスドレープ
    -- Ghrah
    [1441] = {duration = 15, buffId = 156, type = 11}, -- アクチニックバースト
    -- [1443] = {duration = 5, buffId = 10, type = 11}, -- ヘクシディスク
    -- Zdei
    [1463] = {duration = 120, buffIds = {93, 35}, type = 11}, -- 反応炉冷却
    [1465] = {duration = 60, buffId = 7, type = 11}, -- 光化学硬結
    [1466] = {duration = 5, buffId = 10, type = 11}, -- スタティックフィラメント
    [1467] = {duration = 180, buffId = 3, type = 11}, -- ディケードフィラメント
    [1468] = {duration = 60, buffId = 31, type = 11}, -- 反応炉過熱
    [1469] = {duration = 60, buffId = 6, type = 11}, -- 反応炉重荷

    -- jug pet
    [3841] = {duration = 120, buffId = 5, type = 11}, -- 土煙
    [3860] = {duration = 30, buffId = 2, type = 11}, -- シープソング
    [3858] = {duration = 120, buffId = 56, type = 11}, -- レイジ
    [3848] = {duration = 120, buffId = 4, type = 11}, -- 咆哮
    [3843] = {duration = 4, buffId = 10, type = 11}, -- ヘッドバット
    [3844] = {duration = 30, buffId = 2, type = 11}, -- 夢想花
    [3845] = {duration = 112, buffId = 138, type = 11}, -- 種まき
    [3846] = {duration = 18, buffId = 3, type = 11}, -- リーフダガー
    [3847] = {duration = 35, buffId = 141, type = 11}, -- スクリーム
    [660] = {duration = 60, buffId = 3, type = 11}, -- 毒液
    [3851] = {duration = 4, buffId = 10, type = 11}, -- テイルブロー
    [3855] = {duration = 120, buffId = 148, type = 11}, -- 超低周波
    [3854] = {duration = 30, buffId = 6, type = 11}, -- ブレインクラッシュ
    [3856] = {duration = 60, buffId = 92, type = 11}, -- 体液分泌
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

    -- automaton
    [2067] = {duration = 30, buffId = 148, type = 11}, -- ノックアウト
    [2299] = {duration = 4, buffId = 10, type = 11}, -- ボーンクラッシャー
    [2066] = {duration = 4, buffId = 10, type = 11}, -- デイズ

    [1944] = {duration = 6, buffId = 10, type = 11}, -- シールドバッシュ
    [1946] = {duration = 180, buffId = 37, type = 11}, -- Ｓ．アブソーバー
    [1947] = {duration = 12, buffId = 156, type = 11}, -- フラッシュバルブ
    [1948] = {duration = 30, buffId = 43, type = 11}, -- マナコンバーター
    [2132] = {duration = 300, buffId = 36, type = 11}, -- レプリケーター
    [2031] = {duration = 60, buffId = 34, type = 11}, -- Ｒ．シールド
    [2021] = {duration = 0, buffId = 0, type = 11}, -- イレーザー
};

local JOB_ABILITY_DURATIONS = {
    -- Job abilities with debuffs
    [45] = {duration = 30, buffId = 448},  -- Mug - ???
    [46] = {duration = 6, buffId = 10},    -- Shield Bash - Stun
    [77] = {duration = 6, buffId = 10},    -- Weapon Bash - Stun

    [131] = {duration = 60, buffId = 2},    -- Light Shot

    [137] = {duration = {[18731] = 30, [18732] = 60, [18733] = 90, [187314] = 120}, buffId = 42},    -- Repair
}

local AVATAR_BLOODPACTS_DURATIONS = {
    -- avatar
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
}

local function GetCurrentEquip(slot)
    local equippedItem = AshitaCore:GetMemoryManager():GetInventory():GetEquippedItem(slot - 1);
    local index = bit.band(equippedItem.Index, 0x00FF);
    local eqEntry = {};
    if (index == 0) then
        eqEntry.Container = 0;
        eqEntry.Item = nil;
    else
        eqEntry.Container = bit.band(equippedItem.Index, 0xFF00) / 256;
        eqEntry.Item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(eqEntry.Container, index);
        if (eqEntry.Item.Id == 0) or (eqEntry.Item.Count == 0) then
            eqEntry.Item = nil;
        end
    end
    return eqEntry;
end

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
            local selfIdx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);

            -- debug:
            -- if (action.Type ~= 1) then
            --     print("=================================")
            --     print(ent.Name)
            --     print("action.Type : " .. action.Type)
            --     print("spell : " .. spell)
            --     print("message : " .. message)
            --     print("target.Id : " .. target.Id)
            --     print("=================================")
            -- end

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
            -- Handle monsters abilities
            elseif action.Type == 11 and PET_ABILITY_DURATIONS[spell] then
                if not (message == 185 or message == 186 or message == 242 or message == 243 or message == 264 or message == 277) then
                    return
                end

                local abiData = PET_ABILITY_DURATIONS[spell];
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
                    elseif abiData.buffIds ~= nil then
                        for _, buffId in ipairs(abiData.buffIds) do
                            debuffs[target.Id][buffId] = now + abiData.duration;
                        end
                    end
                end
            -- Handle weapon skills (Type 3 with damage message)
            elseif action.Type == 3 and (message == 185 or message == 277) then
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
            -- Handle blue spells
            elseif action.Type == 4 and (spell >= 515 and spell <= 753) and SPELL_DURATIONS[spell] then
                if not (spellDamageMes[message] or message == 236) then
                    return
                end

                local spellData = SPELL_DURATIONS[spell];
                if spellData.buffId ~= nil then
                    for index, value in pairs(debuffs[target.Id]) do
                        if index == spellData.buffId then
                            return
                        end
                    end

                    if spellData.duration ~= nil then
                        debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                    else
                        debuffs[target.Id][spellData.buffId] = now + 180;
                    end
                elseif spellData.buffIds ~= nil then
                    for _, buffId in ipairs(spellData.buffIds) do
                        debuffs[target.Id][buffId] = now + spellData.duration;
                    end
                end
            -- Handle dia/bio/helix spells (Type 4 with damage message)
            elseif action.Type == 4 and spellDamageMes[message] then
                local spellData = SPELL_DURATIONS[spell];
                if spellData then
                    local expiry = now + spellData.duration;
                    if spell == 23 or spell == 24 or spell == 25 or spell == 33 then
                        -- Dia spells
                        if
                            (debuffs[target.Id][134] == nil or debuffs[target.Id][134] < now)
                            and (debuffs[target.Id][135] == nil or debuffs[target.Id][135] < now)
                        then
                            debuffs[target.Id][134] = expiry;
                        end
                    elseif spell == 230 or spell == 231 or spell == 232 then
                        -- Bio spells
                        if
                            (debuffs[target.Id][134] == nil or debuffs[target.Id][134] < now)
                            and (debuffs[target.Id][135] == nil or debuffs[target.Id][135] < now)
                        then
                            debuffs[target.Id][135] = expiry;
                        end
                    elseif (spell >= 278 and spell <= 285) or (spell >= 885 and spell <= 892) then
                        -- Helix spells only (don't match weaponskill IDs that share numbers with damage spells)
                        debuffs[target.Id][spellData.buffId] = expiry;
                    end
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
            -- Handle job abilities
            elseif action.Type == 6 and JOB_ABILITY_DURATIONS[spell] then
                local spellData = JOB_ABILITY_DURATIONS[spell];
                if spellData and spell == 137 and message == 102 then
                    -- repair
                    if action.UserIndex == selfIdx then
                        local slotAmmo = GetCurrentEquip(4)
                        if slotAmmo.Item ~= nil then
                            debuffs[target.Id][spellData.buffId] = now + spellData.duration[slotAmmo.Item.Id];
                        else
                            debuffs[target.Id][spellData.buffId] = now + 120;
                        end
                    else
                        debuffs[target.Id][spellData.buffId] = now + 120;
                    end
                elseif spellData and message == 127 then
                    debuffs[target.Id][spellData.buffId] = now + spellData.duration;
                end
            -- Handle avatar blood pacts
            elseif action.Type == 13 and AVATAR_BLOODPACTS_DURATIONS[spell] then
                if not (message == 320 or message == 317 or message == 144) then
                    return
                end

                local abiData = AVATAR_BLOODPACTS_DURATIONS[spell];
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
            -- Handle regular status effect spells
            elseif statusOnMes[message] then
                local buffId = ability.Param or (action.Type == 4 and buffTable.GetBuffIdBySpellId(spell) or nil);
                if (buffId == nil) then
                    return
                end

                local spellData = SPELL_DURATIONS[spell];
                if action.Type == 13 then
                    spellData = AVATAR_BLOODPACTS_DURATIONS[spell];
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
                    if debuffs[ent.ServerId][buffId] == nil or debuffs[ent.ServerId][buffId] < now then
                        debuffs[ent.ServerId][buffId] = now + spellData.duration;
                    end
                else
                    if debuffs[ent.ServerId][buffId] == nil or debuffs[ent.ServerId][buffId] < now then
                        -- Default duration for unknown spikes effects
                        debuffs[ent.ServerId][buffId] = now + 300;
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
        if (expiryTime ~= 0 and expiryTime >= currentTime) then
            count = count + 1;
            reusableDebuffIds[count] = buffId;
            reusableDebuffTimes[count] = expiryTime - currentTime;
        elseif (expiryTime ~= 0 and (expiryTime - currentTime) >= -3) then
            count = count + 1;
            reusableDebuffIds[count] = buffId;
            reusableDebuffTimes[count] = 0;
        end
    end

    -- Return nil if no active debuffs (same behavior as before)
    if count == 0 then
        return nil;
    end

    return reusableDebuffIds, reusableDebuffTimes;
end

return debuffHandler;