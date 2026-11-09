# 启动界面

## 下坠视差分层

- `abyss_loop.png`：基于启动画面，经内置 image_gen 移除人物与标题，补成无封底的深渊长井背景。
- `falling_hero.png`：内置 image_gen 提取的人物透明 PNG，保留坠落姿势、红围巾和铃铛。
- 标题使用原 `title_clean.png` 的标题区域，通过运行时 AtlasTexture 与透明遮罩单独显示，避免重绘字体。
- `scripts/title_fall.gd`：远景与墙体分别按 0.010 / 0.027 周期每秒向上滚动，近处碎屑以 32–105 逻辑像素/秒上升；人物漂移约 7 像素，摆动约 1.6 度，标题与交互菜单固定。
- `shaders/title_scroll.gdshader`：循环采样与末端过渡混合；`shaders/title_logo.gdshader`：标题透明遮罩。
- 生成提示词见 `falling_prompts.json`。原始静态图保留，运行时改为独立图层组合。
- `shaders/falling_hero_motion.gdshader` 在人物透明层上做局部 UV 变形：围巾末端气流波动、双手与双脚错相摆动、铃铛绕悬挂点延迟摇摆。不是完整逐帧或骨骼动画；保留原始人物 PNG，幅度由 `title_fall.gd` 的 `character_motion` 控制。
- `tests/title_character_motion.gd` 对比两个时刻的实际渲染，检查围巾、手、脚与铃铛四个区域均存在变化。

用户提供《低语深渊》启动界面作为美术来源。`title_clean.png` 使用内置 image_gen 仅移除左下角已绘制的三项菜单、菱形与选中光晕，其余标题和构图保留。未覆盖原始素材。

菜单由 Godot 的真实按钮还原，中文字体优先调用系统 SimHei / Microsoft YaHei 并禁用抗锯齿，不打包系统字体。文字以 16px 栅格渲染至透明 SubViewport，经最近邻放大三倍，加入加粗与厚黑描边以模仿参考像素字。其他系统可能使用不同的中文回退字体。漂浮碎屑和选中项周围 220 枚持续散开、回流、淡入淡出的方块由 `scripts/title_dust.gd` 绘制。

完整清理提示词：

Precise edit of supplied game title screen. Preserve exact full composition, central Chinese title 低语深渊 and Whispering Abyss lettering, falling masked character, architecture, dark blue abyss, pixel texture and all atmospheric artwork. Remove ONLY the lower-left three menu texts 开始游戏 设置 退出游戏, the white diamond and local bright noisy selection halo behind 开始游戏. Reconstruct matching dark abyss background in that small lower-left area. Do not add any text, UI, characters or effects. Keep original landscape aspect ratio and framing.
