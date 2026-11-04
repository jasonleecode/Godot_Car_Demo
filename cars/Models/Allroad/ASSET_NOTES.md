# Audi A6 allroad — C8 游戏车模

## 制作方式

本车由 `tools/build_allroad.py` 和 `tools/allroad_body.py` 在 Blender 中从尺寸化曲面生成，没有复用第三方整车网格。
参考对象为 C8 A6 allroad（2019–2025）旅行车。外观采用深绿金属漆、石墨灰轮眉与下护板、
银色格栅饰条和行李架；补有独立透明玻璃、后排隐私玻璃、分段灯组、四环标识、门缝、
门把手、后视镜、雨刷、内饰座椅、仪表台、方向盘和双屏中控。

这是参考实车比例的程序化游戏模型，车身曲面、灯具、饰件与内饰仍有简化，
不是扫描车模或原厂 CAD 的精确复刻。官方照片仅用作观察参考，未打包为贴图。

## 尺寸与坐标

- 轴距：2.925 m；前后轮心 Z 为 ±1.4625 m。
- 按官方图纸定位前 / 后保险杠基准：Z = 2.3835 / -2.5675 m，即前悬 0.921 m、后悬 1.105 m。
- 牌照框、灯罩及护板允许在上述钣金基准外突出少量；资产检查对完整模型使用 40 mm 容差。
- 前 / 后轮距：1.645 / 1.611 m。
- 轮胎名义规格：235/55 R18；外径 0.7157 m、宽度 0.235 m。
- 物理半径：0.35785 m；资产检查逐轮测量实际顶点外径。
- 单位：米。Godot +Z 朝前、+Y 向上、+X 车辆左侧。
- 原点：轴距中点、标称轮心高度；驾驶员左舵视点 (0.39, 0.91, -0.28)。
- `WheelFL/FR/RL/RR` 处理悬挂位置与转向；`Rotor*` 子节点处理滚动。

车身侧板采用连续四边形曲面并留出真实轮拱开口；纵向截面使用三次 Hermite 插值，
门板具有肩部外鼓、下部内收和浅凹面。门板折线在绝对车身高度定义，避免随轮拱下边界一起变形。
发动机盖具有横向拱度、纵向下落及双侧压线，车顶同时沿纵横两个方向起拱。
窗柱通过带车窗开口的连续蒙皮衔接，前后包围与侧围采用连续环绕截面，中心线焊接后再赋予板厚。
灯罩和格栅先细分再投影到车身曲面，避免非共面多边形穿进车身、导致灯具被遮住。
车漆、轮胎、包覆内饰与护板使用固定随机种子生成的微法线和粗糙度贴图。

## 多角度外观复核（2026-11-04）

先前版本虽然轴距正确，但总轮廓和面板关系没有通过实车对照。驾驶测试通过不能代替造型验收。
本轮使用官方尺寸图的正前、正侧、正后投影，以及 A196846、A196848、A196849 三张官方实拍观察曲面。

| 观察方向 | 旧模型问题 | 本轮修正 |
| --- | --- | --- |
| 车头 | 前悬偏长、机盖前缘过高，格栅像竖直矩形框，包围转角有接缝 | 按尺寸图缩短前悬、增加机盖纵向下落；重做格栅比例、灯眉、凹入进气口和连续包围 |
| 侧面 | A 柱和 B 柱位置偏差、车顶过长、后窗太直立，轮眉过窄 | 校正窗柱及车窗轮廓；缩短车顶并增加后窗倾角；重做轮眉、下门板内收和裙边 |
| 车尾 | 后悬偏短、后窗边缘悬空、尾灯不包角，尾门层次缺失 | 延长后悬；后窗横向弧线与尾门贴合；增加包角灯组、牌照凹槽、尾门开口、反光片与下护板 |
| 镜像与斜视 | 开放饰件法线方向不一致，长灯框跨过曲面后穿插 | 显式统一饰件朝外方向；细分灯框与凹多边形后投影，避免扇形重叠；四环逐点贴合尾门 |

物理碰撞体同步缩短车头、延长车尾和调整车顶范围，轮心、轮胎尺寸和悬挂参数保持原有设定。
这仍是程序化游戏模型：手工取样曲线并非原厂控制面，内饰、轮毂和灯具光学结构仍有简化。

## 底盘和驾驶

`AllroadChassis.gd` 创建四个独立的五连杆悬挂角、四条 CV 半轴与防尘套、固定在副车架上的
前后差速器、纵向传动、空气弹簧外观、伸缩减震器、前后制动盘及卡钳、转向拉杆、
底部保护板、油箱和双路排气。车轮和连杆跟随同一套射线接地数据，差速器不随车轮跳动。

空气弹簧和连杆属于视觉模拟，受力继续使用游戏的弹簧 / 阻尼模型，未实现气压系统、
车身自动调平或完整的五连杆多刚体求解。动力数据和阻尼均为游戏调校值，不等于原厂测试数据。

- 车重 2000 kg，弹簧 50 kN/m，驱动力 11.5 kN，接地点功率 185 kW。
- 舒适模式：压缩 / 回弹阻尼 3300 / 4600 N·s/m，防倾耦合 4800。
- R 切换全地形模式：阻尼 2600 / 3900，防倾耦合 2800，降低车速上限。
- quattro 四驱始终启用，没有模拟低速分动箱；HUD 显示对应 quattro 模式。
- 支持三个场景、P 驻车、V 四种视角和鼠标环绕观察。

## 重建与验收

运行游戏不依赖 Blender。重建命令：

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_allroad.py
./run.sh --headless --editor --import --quit
./run.sh --headless --script tests/AllroadAssetChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/AllroadChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/CameraChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/ParkingChecks.gd
./run.sh --script tests/AllroadVisualReview.gd --resolution 1440x810
```

预览输出 `/tmp/allroad-review-{front,side,rear,front-ortho,side-ortho,rear-ortho,front-right,under,layout,articulation,cockpit,drive,garage}.png`。
外观脚本追加 `-- --baseline` 可在修改前保存七张外观基准图到 `/tmp/allroad-audit-before-*.png`。
基准图与修改后截图均生成后，可运行 `python3 tools/allroad_review_report.py`，输出带滑块的本地对照页 `/tmp/allroad-comparison.html`。
报告读取已有截图并内嵌，不修改截图像素；官方参考图仅在 `/tmp` 中存在时加入本地报告，不打包进游戏资产。
选车增加了横向滚动容器与焦点自动滚动，五辆车均保留卡片入口。

## 参考

- [奥迪官方 C8 allroad 尺寸图](https://media.audi.com/is/content/audi/global/assets/dimensions/a6/A6_allroad_2020_dimensions_1.pdf)
- [奥迪中国 A6 allroad 图库](https://www.audi.cn/zh/models/a/a6/a6_allroad_quattro.html)
- [C8 官方图库（until 2025）](https://www.audi.com/en/images/album/audi-a6-allroad-quattro-until-2025-1449)
- [官方前侧实拍 A196846](https://www.audi.com/en/images/detail/audi-a6-allroad-quattro-78931)
- [官方后侧实拍 A196848](https://www.audi.com/en/images/detail/audi-a6-allroad-quattro-78933)
- [官方高角度前侧实拍 A196849](https://www.audi.com/en/images/detail/audi-a6-allroad-quattro-78934)
- [官方悬挂技术说明（2019）](https://www.audi-technology-portal.de/en/chassis/suspension-control-systems/audi-a6-allroad-quattro-suspension?c=video%3A2067&type=video_md)
- [官方轮胎规格手册](https://api.audi.co.za/files/brochures/a6/a6_model_brochure.pdf)
