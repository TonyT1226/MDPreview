# Markit 图标图层

给 Icon Composer 用的分层素材。画布都是 1024×1024，图形铺满整个画布，没有圆角和留白（圆角由系统裁切）。
图层里没有阴影、高光和模糊，这些由 Icon Composer 的玻璃材质加。

## 文件

| 文件 | 内容 | 用途 |
| :-- | :-- | :-- |
| `1-background.svg` | 白到浅蓝的竖向渐变 | 背景。也可以不导入，直接在 Icon Composer 里设背景色 |
| `2-stroke.svg` | 黄色笔迹，自带黄到橙的渐变 | 下层图形 |
| `2-stroke-flat.svg` | 同一个笔迹，纯色 | 想在 Icon Composer 里自己设渐变时用这个 |
| `3-m.svg` | 字母 M，纯色，已转成轮廓 | 上层图形，设成玻璃 |
| `2-stroke.png`、`3-m.png` | 上面两层的透明 PNG | SVG 导入有问题时的备用 |
| `preview-flat.png` | 三层叠在一起的平面效果 | 对照位置 |
| `reference-sketch.png` | 定稿的草图（带模拟的玻璃效果） | 对照最终想要的感觉 |

## 颜色

| 位置 | 颜色 |
| :-- | :-- |
| 背景 | 上 `#FFFFFF`，下 `#DDE7F6` |
| 笔迹 | 左下 `#FFE45C`，右上 `#FFAE1F`；纯色用 `#FFC53D` |
| M | `#5894F5` |

## 在 Icon Composer 里组合

1. 打开 Icon Composer（Xcode › Open Developer Tool › Icon Composer），新建图标。
2. 把 `2-stroke.svg` 和 `3-m.svg` 拖进去。两个文件画布相同，位置会自动对齐，不要移动或缩放。
3. 图层顺序：M 在上，笔迹在下。两层分别放在两个组（Group）里，这样可以单独设材质。
4. 背景：选中画布背景，填充设成渐变，颜色用上表的两个值，方向从上到下。
5. M 所在的组：打开 Liquid Glass，Mode 选 Individual。调 Translucency，让笔迹从 M 后面透出一点，以 M 仍然清楚为准。Specular（高光）打开，Shadow 选 Neutral 或 Chromatic。
6. 笔迹所在的组：可以关掉 Liquid Glass，或者保留但把 Translucency 调到 0，让它是一块实色。
7. 在右上角切换 Default、Dark、Mono 三种外观，各看一遍。深色下背景会变暗，需要的话给深色外观单独设背景色（比如 `#1C2433` 到 `#0E131C`）。
8. 存成 `AppIcon.icon`，放到 `Sources/App/` 下。之后告诉 Claude，由它接进工程并替换旧图标。
