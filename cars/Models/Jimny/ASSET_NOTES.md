# 吉姆尼 JB74 车模记录

## 来源与范围

本车使用本机 `~/Downloads/3D_model/car/2023_suzuki_jimny_sierra_gltf/2023_suzuki_jimny_sierra_gltf/`
中的 `scene.gltf`、二进制数据和贴图作为车身基础，并非全部从零建模。

This work is based on **[2023 Suzuki Jimny Sierra](https://sketchfab.com/3d-models/2023-suzuki-jimny-sierra-8b7c4d136f6742e180faf654d874f14a)**
by **[tonielpro520](https://sketchfab.com/tonielpro520)**,
licensed under **[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)**.
原下载包的声明保存在 [SOURCE_LICENSE.txt](SOURCE_LICENSE.txt)。

本项目改动：黄黑双色材质、透明玻璃、表面细节贴图、米制尺寸校准、四轮活动层级、
旧固定底盘清理、内饰与轮胎减面、动态底盘重建和驾驶接入。保留源模型的车身曲面、
门窗、仪表、座椅、灯具、车标与备胎。配色参考 Kinetic Yellow / 黑色车顶。

这是 JB74 三门 Sierra 的游戏适配，保留了源资产的部分饰件与轮圈造型，
没有声称是某个市场、年款、配置的完整原厂 CAD 复刻。没有使用牧马人的 35 寸胎。

## 尺寸与活动层级

| 项目 | 数值 |
| --- | --- |
| 轴距 | 2.250 m |
| 前 / 后轮距 | 1.395 / 1.405 m |
| 轮胎名义规格 | 195/80 R15 |
| 外径 / 宽度 | 0.693 / 0.195 m |
| 物理半径 | 0.3465 m，逐轮与实际顶点外径校验 |
| 坐标 | Godot +Z 向前、+Y 向上、+X 车辆左侧 |
| 原点 | 前后轴中点，标称轮心高度 |
| 驾驶员视点 | 左舵，(0.35, 1.10, -0.04) |

`WheelFL/FR/RL/RR` 处理位置和转向，子节点 `RotorFL/FR/RL/RR` 绕 X 滚动。
备胎固定在车身。车桥、差速器、传动轴、半径臂、弹簧、减震器、轮毂与制动软管
由 `JimnyChassis.gd` 使用相同的四轮悬挂数据驱动。

底盘采用梯形车架、中部 X 形加强梁、独立分动箱、前后整体桥、每桥两根叉形半径臂
和一根横向定位杆；配有前盘后鼓制动、油箱托架、排气与后消声器。各零件的形状和位置
是参考结构的游戏近似，连杆随射线悬挂显示，并非多刚体机械运动学求解。

1100 kg、27 kN/m 弹簧、压缩 / 回弹阻尼 1750 / 2600 N·s/m、6.5 kN 驱动力和
64 kW 接地点功率均为本项目调校值。支持 R 高低速四驱、P 驻车、四种 V 视角、
鼠标观察以及所有三个场景。

## 材质与重建

保留原图集 UV，增加 `DetailUV` 与固定种子生成的细微法线 / 粗糙度贴图。
车漆、塑料、橡胶、织物、金属和玻璃分别处理；运行时修正透明材质时保留已有贴图。
外部钣金、保险杠保留源自定义逐面角法线，拆分材质块时显式传递，避免错误反光。

运行只需要仓库中的 GLB 和导入资源。Blender 与原下载包仅用于重建：

```sh
blender -b -t 4 --python tools/import_jimny.py -- --source /path/to/2023_suzuki_jimny_sierra_gltf
./run.sh --headless --editor --import --quit
./run.sh --headless --script tests/JimnyAssetChecks.gd
./run.sh --headless --script tests/ChassisChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/JimnyChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/CameraChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/ParkingChecks.gd
./run.sh --script tests/JimnyVisualReview.gd --resolution 1440x810
```

视觉检查输出 `/tmp/jimny-review-{front,side,rear,under,layout,articulation,cockpit,drive,garage}.png`。

## 资产快照

2026-11-04 导出：368,083 个三角面（按节点实例计）、17 张内嵌图片、
GLB 45,812,516 字节。此统计不包含运行时生成的底盘。

## 实车参考

- [铃木官方 Jimny 外观、内饰与底盘说明](https://www.globalsuzuki.com/automobile/lineup/jimny/index.html)
- [官方梯形车架与悬挂示意](https://www.globalsuzuki.com/automobile/lineup/jimny/img/pe_img03.jpg)
- [铃木官方尺寸、轮胎及制动规格](https://www.suzuki.com.au/vehicles/4x4/jimny/specifications/)

参考图片仅用于观察，没有作为游戏纹理打包。
