# 启动界面

用户提供《低语深渊》启动界面作为美术来源。`title_clean.png` 使用内置 image_gen 仅移除左下角已绘制的三项菜单、菱形与选中光晕，其余标题和构图保留。未覆盖原始素材。

菜单由 Godot 的真实按钮还原，中文字体优先调用系统 SimHei / Microsoft YaHei 并禁用抗锯齿，不打包系统字体。文字以 16px 栅格渲染至透明 SubViewport，经最近邻放大三倍，加入加粗与厚黑描边以模仿参考像素字。其他系统可能使用不同的中文回退字体。漂浮碎屑和选中项周围 220 枚持续散开、回流、淡入淡出的方块由 `scripts/title_dust.gd` 绘制。

完整清理提示词：

Precise edit of supplied game title screen. Preserve exact full composition, central Chinese title 低语深渊 and Whispering Abyss lettering, falling masked character, architecture, dark blue abyss, pixel texture and all atmospheric artwork. Remove ONLY the lower-left three menu texts 开始游戏 设置 退出游戏, the white diamond and local bright noisy selection halo behind 开始游戏. Reconstruct matching dark abyss background in that small lower-left area. Do not add any text, UI, characters or effects. Keep original landscape aspect ratio and framing.
