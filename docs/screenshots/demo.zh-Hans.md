# 旅行计划工具笔记

一个用 **Swift** 写的命令行小工具，把想去的地方排成每天的行程。数据放在 `trips.json` 里，格式见[下文](#数据格式)。

## 本周

- [x] 读取输入文件
- [x] 按城市分组
- [ ] 每天按开放时间排序
- [ ] 导出到日历

## 用法

```swift
struct Place: Codable {
    let name: String
    let city: String
    var hours: ClosedRange<Int>
}

let places = try JSONDecoder().decode([Place].self, from: data)
let days = Dictionary(grouping: places, by: \.city)
print("共安排 \(days.count) 天")
```

运行：

```bash
swift run planner trips.json --days 3
```

## 数据格式

| 字段 | 类型 | 必填 | 说明 |
| :-- | :-- | :-: | :-- |
| `name` | String | 是 | 显示在行程里 |
| `city` | String | 是 | 用于分组 |
| `hours` | Range | 否 | 默认 9–18 点 |

## 待定

> 周一闭馆的博物馆，要不要自动挪到第二天？

- 输出先保持==纯文本==。
- ~~做一个网页界面~~，不需要。

### 以后再说

1. 景点之间的步行时间
2. 查天气
   - 只查户外景点
