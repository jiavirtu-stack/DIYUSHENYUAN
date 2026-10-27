# 资产清单

| 类别 | 文件 | 格式/尺寸 | 用途与来源 |
|---|---|---|---|
| 竞技场地面 | `assets/arena/arena_stone_tile_gen.png` | PNG，可平铺 | 本项目原创 AI 生成石砖材质；来源说明在 arena manifest |
| 法阵 | `assets/arena/arena_ritual_decal_gen.png` | PNG，透明 | 原创 AI 生成透明地面贴花 |
| 主角行走 | `assets/player/pilgrim_walk_atlas.png` | PNG RGBA，4×4 帧 | 四方向行走；帧按 AtlasTexture 切分 |
| 主角待机 | `assets/player/pilgrim_idle_strip.png` | PNG RGBA，4 帧 | 四方向待机 |
| 主角动作 | `assets/player/pilgrim_action_atlas.png` | PNG RGBA，4×4 帧 | 攻击、闪避、受击、死亡 |
| Boss 待机/预警/受击 | `assets/boss/ritual_briar_atlas_v2.png` | PNG RGBA，1448×1086、4×3 帧 | 原创沼泽根系兽：呼吸待机、抬蔓蓄力、受击回缩/伏倒 |
| Boss 技能动作 | `assets/boss/ritual_briar_actions.png` | PNG RGBA，1774×887、4×2 帧 | 第一行横扫，第二行下砸/冲击；三种技能绑定到专用动作序列 |
| 战斗音效 | `assets/audio/swing.wav`、`hit_light.wav`、`hit_heavy.wav` | WAV，44.1 kHz，16-bit mono | 标准库程序合成原创音效 |
| 技能特效 | 运行时 Mesh/GPUParticles | 实时生成 | 地面预警、地刺、冲击/弹幕、挥击弧线和命中火花；不作为角色或场景美术替代 |

Godot 导入默认使用 PNG 纹理过滤；角色 Sprite3D 使用 AtlasTexture 按单格裁切。完整来源和生成说明：`assets/arena/ASSET_SOURCES.md`、`assets/player/ASSET_SOURCES.md`、`assets/boss/ASSET_SOURCES.md`、`assets/audio/ASSET_SOURCES.md`。
