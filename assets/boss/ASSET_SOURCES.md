# Boss 资产来源

`ritual_briar_atlas.png` 是本项目原创手绘式程序绘制精灵图集，由 `scripts/generate_boss_atlas.py` 使用 Pillow 绘制、渐层叠色与透明通道合成；未采样或引用参考视频中的怪物造型。图集为 4×3 格、每格 512×512 RGBA：第一行待机呼吸，第二行蓄力预警，第三行受击/消散。可运行 `python scripts/generate_boss_atlas.py` 重新生成。
