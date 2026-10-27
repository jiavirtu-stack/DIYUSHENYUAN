# 阶段 2 验收记录：原创角色与移动

日期：2026-10-27（Asia/Shanghai）

## 修改文件

- `assets/player/pilgrim_walk_atlas.png`、`pilgrim_idle_strip.png`、`pilgrim_action_atlas.png`：生成的透明角色图集。
- `assets/player/ASSET_SOURCES.md`：角色资产来源、分辨率、切图及提示记录。
- `scenes/player.tscn`、`scripts/player.gd`：Sprite3D 动画、朝向、加减速、碰撞体、受击/死亡接口、闪避无敌帧与冷却。
- `scenes/arena.tscn`：竞技场加入主角实例。
- `scripts/arena.gd`：相机以 28% 权重柔性跟随，保持舞台构图；提供平台轮廓边界限制。
- `scenes/showcase_player_foreground.tscn`、`showcase_player_background.tscn` 与 `scripts/player_depth_showcase.gd`：仅用于前景/后景对照截图的 QA 场景。
- `tests/stage2_smoke.gd`：可重复冒烟检查。
- `docs/stage2_player_foreground.png`、`stage2_player_background.png`：1280×720 实际 GPU 渲染截图。
- `README.md`、`CHANGELOG.md`：阶段状态与键位说明。

## 实际验证

Godot 4.7.2：

```powershell
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --editor --quit
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --quit-after 5
& 'E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\2026游戏课' --script 'res://tests/stage2_smoke.gd'
```

导入、主菜单启动和冒烟检查退出码均为 0。冒烟检查确认持续移动会改变角色坐标、越界坐标会被拉回平台范围、闪避入口会启动无敌计时与冷却。另用 GPU 对前景/后景 QA 场景各实际渲染两帧；截图可见角色脚底落点与场景纵深关系成立。未做 60fps 长时间采样。

Headless 模式中，`Input.action_press("dodge")` 的一次性输入未稳定触发 `is_action_just_pressed`，所以无敌帧检查直接调用玩家控制器的闪避入口；方向移动使用了持续输入模拟。运行时键位映射已在 `project.godot` 配置，但尚未通过可见 GUI 手动按键验收。

## 当前限制

- 主角攻击动画只发出 `attack_requested` 信号；伤害判定与连击在阶段 3 实现。
- 闪避已有无敌帧和冷却计时，但当前还没有 HUD 冷却指示。
- 玩家渲染和平台排序已用前后位置截图检查；Boss 特效和最终动画 polish 留到后续阶段。
