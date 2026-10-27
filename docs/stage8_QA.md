# 阶段 8 QA / 打包状态

日期：2026-10-27；Godot 4.7.2.stable；Compatibility；机器 GPU NVIDIA GeForce RTX 5060 Laptop GPU。

## 阶段验证

- Godot 项目 headless 导入：通过，退出码 0。
- 主菜单主场景与竞技场 headless 启动：通过，退出码 0。
- 分阶段冒烟脚本复跑：Stage 2 移动/边界/闪避；Stage 3 命中/击退/连击；Stage 4 阶段转换/死亡；Stage 5 地刺/扇形/环形；Stage 7 胜利奖励/失败/强化，全部通过。
- 资源缺失扫描：项目场景和资源中的 `res://` 路径均检查；Godot 导入过程中无缺失资源错误。
- `python scripts/check_resources.py`：`RES_PATH_SCAN_OK: checked 97 text files`。
- 收尾复跑阶段 2/3/4/5/7 五个冒烟脚本：全部 PASS。
- 资产清单与帧图资源说明：`docs/ASSET_MANIFEST.md`。
- 人工核对截图：`docs/stage1_arena_overview.png`、阶段 2 前后景截图、`docs/stage3_melee_test.png`、`docs/stage4_boss_arena.png`、`docs/stage5_skill_telegraph.png`、`docs/stage7_hud.png`。
- Boss 动作精修 GPU 截图：`docs/boss_final_idle.png`、`docs/boss_motion_telegraph.png`、`docs/boss_motion_attack.png`；在攻击帧看到了树根举起并向地面冲击的专用姿势。动作来源和逐帧映射见 `docs/boss_motion_analysis.md`。

## 性能与限制

- 使用 1280×720 GPU Movie Maker 截帧，设备识别为 RTX 5060 Laptop GPU；50 帧、10fps 的动作录制测得 GPU 平均渲染时间 0.82ms、CPU 平均 1.25ms。固定低帧率 Movie Maker 录制与 1280×720 场景结果不能代表正常实时表现；目标 1080p 稳定 60fps **未验证**。
- 未完成两分钟战斗录屏，也未执行 GUI 鼠标/键盘完整手动验收、内存泄漏长测。
- 自动检查尚未覆盖每一种 Boss 技能多轮随机时序或奖励后的闪避冷却实战；目前 RNG 种子策略未实现，Boss 采取稳定轮换。
- 部分效果使用 Mesh 构成预警与尖刺；它们是战斗特效，不替代玩家、Boss、竞技场最终美术。

## Windows 导出阻断

本机检查 `%APPDATA%\Godot\export_templates\4.7.2.stable` 不存在，缺少对应导出模板，所以本次没有生成或声称生成 Windows EXE。解决：在 Godot 编辑器打开“编辑 > 管理导出模板”，为 4.7.2.stable 点“下载并安装”；然后“项目 > 导出”新增 Windows Desktop 预设，导出到 `build/`。导出前需再实际执行并运行生成的 EXE。

## 结论

项目能在 Godot 中打开并从 F5 进入标题页、开始战斗；核心战斗与最小胜败/奖励循环已有 headless 覆盖。由于 Windows 打包、长时性能和完整手动 QA 未通过，这仍是开发中 MVP，不满足文档的最终“精致 MVP”质量闸门。
