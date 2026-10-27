# 阶段 7 验收记录

日期：2026-10-27；Godot 4.7.2.stable。

## 已实现

- 战斗 HUD：玩家生命、闪避冷却、Boss 生命/阶段/状态和操作提示；羊皮纸色线框与暗色面板采用脚本主题。
- 暂停弹层支持继续、重新挑战、返回标题。
- Boss 死亡触发胜利遗物三选一；失败显示失败面板并可重试。
- 三项奖励在下一次场景实例化时生效：攻击力 +20%、闪避冷却 -20%、生命上限 +25。
- 标题页增加声音设置（Master/SFX/Ambience/Music/UI）和退出入口。
- `reload_current_scene()` 重建角色、Boss、技能控制器与所有计时状态；奖励数据由 `RunState` 跨场景保留。

## 验证

- Godot editor headless 导入和竞技场 headless 启动：退出码 0。
- `--headless --script res://tests/stage7_loop_smoke.gd`：通过；验证胜利暂停、奖励选择、攻击奖励跨局生效、失败界面和生命奖励。
- 1280×720 GPU 截图 `docs/stage7_hud.png` 已人工检查，HUD 没有遮挡战斗中心，中文标签正常显示。
- UI 交互尚未用真实鼠标逐项手动点击；截图短采样不能证明稳定 60fps。
