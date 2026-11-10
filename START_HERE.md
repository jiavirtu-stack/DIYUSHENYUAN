# 团队从这里开始

当前可玩版本：纯战斗肉鸽原型，五波分批清场、战后强化、最终Boss。默认分支为 `codex/team-collaboration`。

```sh
git clone --branch codex/team-collaboration https://github.com/jiavirtu-stack/DIYUSHENYUAN.git
cd DIYUSHENYUAN
```

使用Godot 4.7.2导入根目录 `project.godot`，等待首次导入，再按F5。主菜单的“开始游戏”进入正式关卡；“规则实验室”用于测试可叠加光波规则；“卡牌练习”提供五技能测试。

操作：WASD移动，左键快刀，Shift/Space闪避，滚轮选卡，按住中键瞄准、松开施放，Tab查看本局构筑，Esc暂停。

第一波32只分四批，每批8只，清完才出下一批。后续各波40/48/56/64只，也按8只逐批推进；每波全清后选强化，第3/5波追加精英与遗物，最后自动Boss战。无探索或跑图交互前置。

开始协作前先读 `团队协作与Agent交接.md` 与 `docs/纯战斗模式_实现说明.md`。各人从默认分支开自己的 `codex/任务名` 分支，完成后PR审核；不要强推、覆盖别人改动或自行合并。

给对方Agent直接发送：

> 请先阅读 START_HERE.md 和 团队协作与Agent交接.md，检查 git status 和当前分支。基于 codex/team-collaboration 开个人 codex/任务名 分支。项目是Godot 4.7.2，正式入口 scenes/main_menu.tscn，战斗场景 scenes/chapter01/revoked_day.tscn。先理解现有批次计数、敌人AI和卡牌接口，再修改你负责的模块；保留现有改动，不提交 .godot 或本机路径。完成后说明体验步骤、实际验证和限制，并提交PR。

## 验证入口

首次克隆先用编辑器完成资源导入，之后可用Godot控制台可执行文件运行：

```sh
godot --headless --path . --script res://tests/clear_batch_smoke.gd
godot --headless --path . --script res://tests/combat_only_smoke.gd
godot --headless --path . --script res://tests/enemy_spacing_smoke.gd
godot --headless --path . --script res://tests/melee_hitstop_smoke.gd
godot --headless --path . --script res://tests/card_skills_smoke.gd
godot --headless --path . --script res://tests/magic_circle_smoke.gd
```

`rogue_run_smoke`、`chapter01_flow_smoke`与部分旧测试显式开启旧模式，仅用于旧接口回归，不代表当前游戏入口仍有探索。

原始视频、大型素材库、重复空项目、缓存和运行日志不上传；游戏可运行资源包含在 assets/。二十技能是设计方案，当前实际为五技能。尚未验证Windows导出与长时间性能，当前构筑不支持存档。
