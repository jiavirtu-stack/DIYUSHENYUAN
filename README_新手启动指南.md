# 新手启动指南

## 用 Godot 打开

1. 打开 Godot 4.7.2（或兼容 Godot 4.x 的版本）。
2. 在项目管理器点“导入”，选中本文件夹里的 `project.godot`。
3. 打开项目后按 **F6** 运行当前打开的场景，按 **F5** 从标题页开始。
4. 如果 Godot 弹出资源导入提示，等导入完成再运行。

## 键位

| 操作 | 按键 |
|---|---|
| 移动 | WASD 或方向键 |
| 闪避 | Shift 或 Space |
| 三段普攻 | 鼠标左键或 J；后摇时再按可缓冲下一击 |
| 暂停/继续 | Esc |

建议先观察 Boss 前摇地面标记，再侧向闪避扇形；地刺会落在玩家先前站立的位置，移动即可避开。环形弹幕会朝玩家方向留出缺口。闪避有短暂无敌帧和冷却。

## 奖励与重开

击败 Boss 后选择一件遗物，再按“再战一局”：攻击力 +20%、闪避冷却缩短 20%、生命上限 +25 三选一。失败后可以直接重新挑战。重试会重新创建战斗场景和计时器。返回标题会清除所选遗物。

## 常用测试

在项目根目录运行：

```powershell
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script res://tests/stage2_smoke.gd
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script res://tests/stage3_melee_smoke.gd
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script res://tests/stage4_boss_smoke.gd
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script res://tests/stage5_skills_smoke.gd
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script res://tests/stage7_loop_smoke.gd
```

## 项目结构

```text
scenes/       主菜单、竞技场、玩家、Boss、木桩测试场景
scripts/      玩家控制、Boss 状态机与技能、HUD、反馈、原创资源生成脚本
resources/    三段攻击配置与音频总线
assets/       原创玩家/Boss精灵图、竞技场材质、程序合成音效
shaders/      地砖表面细节
tests/        分阶段可运行冒烟检查
docs/         视频观察、截图与分阶段验收记录
references/   本地参考材料目录（用户原始文件保持在工程根目录）
```

## 可调参数入口

- 三段攻击：`resources/attacks/light_1.tres` 至 `light_3.tres`。
- Boss 节奏、生命与前摇时长：Godot 打开 `scenes/boss.tscn`，检查器中选 Boss 节点。
- 单独测试技能：打开 `scenes/arena.tscn`，选 `BossAttackController`，将 `debug_force_skill` 设为 0（地刺）、1（扇形）或 2（环形）；设为 -1 恢复轮换。
- 玩家速度、闪避与生命：选 `scenes/player.tscn` 的 Player 节点。
- 音量：标题页“声音设置”，或资源 `resources/audio_bus_layout.tres`。

## 资产与已知限制

原创图集和声音的来源说明分别在 `assets/player/ASSET_SOURCES.md`、`assets/arena/ASSET_SOURCES.md`、`assets/boss/ASSET_SOURCES.md`、`assets/audio/ASSET_SOURCES.md`；总表见 `docs/ASSET_MANIFEST.md`。木桩与技能几何标记属于测试/特效用途。

本工程尚未完成 Windows 可执行包；当前机器没有 Godot 4.7.2 导出模板。尚未通过 1080p 长时间 60fps 实测、鼠标 GUI 全流程检查或两分钟录屏。完整阻断与处理方法见 `docs/stage8_QA.md`。
