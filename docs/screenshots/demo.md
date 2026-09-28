# Trip Planner Notes

A small **Swift** command-line tool that turns a list of places into a day-by-day
plan. Data lives in `trips.json`; see [the format](#data-format) below.

## This week

- [x] Parse the input file
- [x] Group places by city
- [ ] Sort each day by opening hours
- [ ] Export to calendar

## Usage

```swift
struct Place: Codable {
    let name: String
    let city: String
    var hours: ClosedRange<Int>
}

let places = try JSONDecoder().decode([Place].self, from: data)
let days = Dictionary(grouping: places, by: \.city)
print("Planned \(days.count) days")
```

Run it with:

```bash
swift run planner trips.json --days 3
```

## Data format

| Field | Type | Required | Notes |
| :-- | :-- | :-: | :-- |
| `name` | String | Yes | Shown in the plan |
| `city` | String | Yes | Used for grouping |
| `hours` | Range | No | Defaults to 9–18 |

## Open questions

> Should museums closed on Monday move to the next day automatically?

- Keep the output ==plain text== for now.
- ~~Add a web UI~~ — not needed.

### Later

1. Walking time between places
2. Weather check
   - Only for outdoor places
