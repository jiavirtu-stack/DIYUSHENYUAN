# 烛渊：仪式残响

Godot 4 原创暗黑童话风 2.5D Boss 战 MVP。当前完成阶段 0、阶段 1 竞技场与阶段 2 主角移动。

## 启动

安装 Godot 4.x 后，在 Godot 项目管理器导入本目录的 `project.godot`，然后按 F6 运行主菜单或 F5 运行项目。

## 已完成

- Godot 工程配置，逻辑分辨率 1920×1080，窗口允许伸缩。
- 主菜单入口与阶段 1 竞技场场景。
- WASD/方向键移动、Shift/Space 闪避、鼠标左键/J 攻击、Esc 暂停的输入映射基线。
- 目录结构及 Git 忽略规则。
- 从参考视频均匀抽取 16 帧并生成联系表，分析报告见 `docs/视觉与机制拆解.md`。
- 阶段 1 已建立带原创生成石砖纹理、法阵贴花、破损边缘、仪式门、锁链、烛光与正交相机的竞技场。
- 阶段 2 已加入原创角色待机、四方向行走、攻击/闪避/受击/死亡动画、基础移动与闪避。

## 视频参考

- 帧索引拼图：`docs/reference_frames/contact_sheet.jpg`
- 单帧：`docs/reference_frames/`
- 观察/推测分离的中文报告：`docs/视觉与机制拆解.md`
- 竞技场全景运行截图：`docs/stage1_arena_overview.png`
- 阶段 1 验收记录：`docs/stage1_QA.md`
- 阶段 2 前景截图：`docs/stage2_player_foreground.png`
- 阶段 2 后景截图：`docs/stage2_player_background.png`
- 阶段 2 验收记录：`docs/stage2_QA.md`

## 暂未完成

- 未检查参考视频音轨；所有原作素材都仅作本地视觉分析，不进入游戏资产。
- 近战判定、Boss、技能、战斗特效与 HUD 尚未开发。

## 操作基线

- 菜单：鼠标点击“进入仪式场”。
- 移动：WASD/方向键；闪避：Shift/Space；攻击动画：鼠标左键/J；暂停：Esc。
- 攻击目前只有动画和信号，没有伤害判定；闪避冷却还没有 HUD 指示。

## 资产来源

当前没有第三方游戏资产。竞技场贴图为本项目原创 AI 生成；资产来源与提示词见 `assets/arena/ASSET_SOURCES.md`。参考视频仅作为本地视觉分析参考；不会复制或再分发原作素材。
