# 烛渊：仪式残响｜团队协作与 Agent 交接

> 本文供新加入的开发者及其编码 Agent 使用。项目唯一工作副本应来自团队 Git 仓库；不要从聊天附件或个人临时目录另建分叉版本。

## 项目概况

- 引擎：Godot 4.x（当前项目使用 Godot 4.7.2）。
- 类型：暗黑童话风 2.5D 动作 Roguelite 原型。
- 当前主流程：主菜单 → 第一关《被撤销的一天》→ 办公室调查/残影战 → 雨后街道 → 出租屋账单 → 盖章者 Boss 战。
- 新关卡入口：`res://scenes/chapter01/revoked_day.tscn`；实现与体验说明：`docs/第一关_被撤销的一天_实现说明.md`。旧小兵/Boss MVP 场景可单独运行。
- 主场景：`res://scenes/main_menu.tscn`。
- 项目配置：`project.godot`；全局运行状态：`scripts/run_state.gd`。
- 详细背景：先读 `README.md`、`README_新手启动指南.md`、`docs/` 下策划/资产/QA 文档。

## 给 Agent 的可直接使用指令

将下面内容交给你的编码 Agent，并同时开放本 Git 仓库：

```text
你将协作 Godot 项目《烛渊：仪式残响》。先阅读仓库根目录的“团队协作与Agent交接.md”、docs/第一关_被撤销的一天_实现说明.md，以及与你任务相关的 docs/ 文档。项目运行主场景是 res://scenes/main_menu.tscn，当前第一关入口为 res://scenes/chapter01/revoked_day.tscn；Godot 版本为 4.7.2。当前第一关是可玩流程原型，几何美术与战斗平衡仍需迭代。

开始前先检查 git status 和当前分支。不要覆盖或丢弃其他人的未提交改动；不要自行重置、rebase 公共分支或强推。每项工作使用独立 feature/... 或 fix/... 分支。先定位现有实现并复用项目结构，再做最小完整改动；如改动输入、场景流程、资源路径或玩家/Boss接口，检查其调用方。

未获任务明确要求时，不要删除或改写策划文档、资产来源说明、QA记录，不要引入未经许可的第三方/参考视频素材，不要提交 .godot/、导出包、临时截图或密钥。Godot UID 文件若由编辑器生成且对应资源应纳入仓库，可一并提交。

完成后说明：修改了什么、涉及哪些文件、如何在 Godot 中体验、已做的验证及尚存限制。不要声称运行过未实际执行的测试。除非用户任务要求，不要额外添加/运行测试。提交改动并创建 PR；不要直接推送到受保护主分支或自行合并 PR。
```

## 首次加入项目

1. 仓库管理员在 GitHub/GitLab 建立私有仓库，并邀请成员；把仓库地址发给团队。
2. 成员安装 Git、Git LFS（仅当团队选择 LFS 管理大文件时）和 Godot 4.7.2。
3. 克隆项目：

   ```bash
   git clone <团队仓库地址>
   cd <仓库目录>
   ```

4. 在 Godot Project Manager 中导入该目录的 `project.godot`，等待资源扫描完成，再按 F5 运行主场景。
5. 每次开始任务前同步主分支并开个人分支：

   ```bash
   git switch main
   git pull --ff-only
   git switch -c feature/简短任务名
   ```

   如果远端默认分支叫 `master`，将上面的 `main` 换成 `master`。

## 日常协作流程

1. 一个分支聚焦一个可审查任务；先在 Issue 或团队任务板写清目标与验收条件。
2. 不要让两个人同时编辑同一个 `.tscn` 或同一段核心脚本。Godot 场景和资源以文本为主，但冲突仍需人工检查。
3. 提交前查看 `git status`、`git diff`，确认没有缓存、个人文件、错误素材或无关改动。
4. 提交信息用简短动词描述，例如 `Add corridor transition triggers`。
5. 推送个人分支并开 Pull Request；让另一位成员检查后再合并。
6. 合并后删除已完成分支。遇到冲突时先与文件负责人协调，不要用“接受全部覆盖”解决。

## Godot 与版本控制约定

- `.godot/` 是本机导入缓存，已由 `.gitignore` 排除，不提交。
- `*.import`、`.uid` 和项目自身 `assets/`、`scenes/`、`scripts/`、`resources/` 通常应提交，以保证资源引用一致。
- 导出设置或导出包只在团队明确需要时纳入；不要提交机器私有路径、访问令牌或密钥。
- 提交前从干净拉取的项目确认 `project.godot` 能导入。涉及画面、战斗与流程的改动，PR 描述应给出人工体验步骤或截图。
- 当前 `.gitignore` 已忽略 Godot 缓存，但不会自动忽略所有大型媒体；新增大型资产前先按下方规则处理。

## 大文件与参考素材

- 游戏运行所需且已获许可的美术、音频资产应放入项目 `assets/` 并纳入版本控制。
- 大型二进制（例如源视频、长音频、原始 PSD/Blender 文件）不要未经讨论直接提交普通 Git。优先放团队云盘并在文档写资源链接；确需版本化时统一配置 Git LFS 和配额。
- 参考视频仅用于本地研究，不作为游戏内容分发。请勿将其推入仓库或转发；需要共享分析时共享文字结论或团队有权分发的截图。
- 每项外部素材需记录来源、许可、作者/生成方式和用途，更新对应 `ASSET_SOURCES.md` 或资产清单。

## 当前仓库交接状态

- 当前工作分支：`codex/team-collaboration`。
- 该分支承载近期关卡与协作文档相关改动；提交/推送前请先逐项审阅 `git status` 与 `git diff`。
- 私有仓库：`https://github.com/jiavirtu-stack/DIYUSHENYUAN`；本机已配置 origin。新成员获得仓库权限后克隆：

  ```bash
  git clone --branch codex/team-collaboration https://github.com/jiavirtu-stack/DIYUSHENYUAN.git
  ```

- 仓库管理员应确认默认分支名称、访问权限、PR 审核规则，以及是否启用 LFS。

## 新成员任务交接模板

```text
任务：
目标场景/脚本：
验收方式：
不要改动：
参考资料：
完成后请提供：改动摘要、文件清单、体验步骤、验证结果、PR 链接。
```
