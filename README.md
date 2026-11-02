<div align="center">

# sextant

A small geospatial maths library for Swift: distance, bearing, destination points, geohashes and point-in-polygon. Foundation is the only dependency.

![License](https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge)  ![Language](https://img.shields.io/badge/SWIFT-F05138?style=for-the-badge&logo=swift&logoColor=white)  ![Tests](https://img.shields.io/badge/TESTS-18-brightgreen?style=for-the-badge)

Refer to [LICENSE](LICENSE) for the legal bits.

</div>

## What's in it

- Great-circle distance between two coordinates using the haversine formula, in metres.
- Initial bearing from one coordinate to another, in degrees clockwise from north.
- Destination point from a start, a bearing and a distance, with longitude normalised across the antimeridian.
- Geohash encoding (1 to 12 characters), decoding to cell bounds, and the eight neighbouring cells.
- Point-in-polygon for simple polygons, concave ones included, with points on an edge counting as inside.

```swift
import Sextant

let sydney = Coordinate(latitude: -33.8688, longitude: 151.2093)
let melbourne = Coordinate(latitude: -37.8136, longitude: 144.9631)

let metres = sydney.distance(to: melbourne)
let heading = sydney.initialBearing(to: melbourne)
let halfway = sydney.destination(bearing: heading, distance: metres / 2)

let hash = Geohash.encode(sydney, precision: 7)
let around = Geohash.neighbours(of: hash)

let park = Polygon([
    Coordinate(latitude: 0, longitude: 0),
    Coordinate(latitude: 0, longitude: 1),
    Coordinate(latitude: 1, longitude: 1),
    Coordinate(latitude: 1, longitude: 0)
])
park.contains(Coordinate(latitude: 0.5, longitude: 0.5))
```

## 🏗️ Architecture

```
 Sources/Sextant
  ├─ Coordinate.swift
  │    ├─ Coordinate        latitude, longitude
  │    │    ├─ distance(to:)         haversine
  │    │    ├─ initialBearing(to:)   atan2, 0..<360
  │    │    └─ destination(bearing:distance:)
  │    ├─ Earth.meanRadius  6,371,008.8 m
  │    ├─ normaliseLongitude(_:)
  │    └─ Polygon           ray casting + on-segment check
  └─ Geohash.swift
       ├─ Geohash           encode / decode / neighbour / neighbours
       ├─ GeohashBounds     min and max lat/lon, center, spans
       └─ Direction         eight compass steps
```

- Everything is a plain value type with `Sendable` conformance. Angles are in degrees and distances in metres at the API, and radians stay internal.
- `Geohash.encode` interleaves longitude and latitude bisections, five bits at a time, into the base-32 alphabet. `decode` returns a `GeohashBounds` rather than a single point, and returns `nil` for an empty string or a character outside the alphabet.
- Neighbours are found by stepping one cell span from the cell centre and re-encoding, which gets longitude wrap-around for free. A step past a pole returns `nil`, so `neighbours(of:)` leaves that direction out.
- `Polygon` drops a repeated closing vertex, then counts ray crossings in plain latitude and longitude. Fewer than three vertices never contains anything.

## 🚀 Quick start

```
swift test
```

For the example above, Sydney to Melbourne comes out as:

```
distance  713428.47 m
bearing   230.28 degrees
geohash   r3gx2f7   (the cell to the north is r3gx2fe)
```

## 🧪 Testing

18 XCTest cases, all passing (Swift 6.0):

- Distance, bearing and destination (7): known city pairs within a tolerance, symmetry and zero distance to self, a quarter of the equator, compass bearings, a destination round trip, due east on the equator, and wrap across the antimeridian.
- Geohash (7): known encodings (`ezs42` and an 11 character hash), decoded bounds contain the original point, a known centre, bad input rejected, neighbours, `neighbour` being reversible, and wrap at the antimeridian with `nil` at the poles.
- Polygon (4): inside and outside, boundary counts as inside, a concave polygon, and a closed ring plus degenerate input.

## ⚠️ Honest limits

- The Earth is a sphere, so distances can be off by roughly 0.5 per cent against an ellipsoidal model such as Vincenty or Karney.
- Point-in-polygon works in plain latitude and longitude. It doesn't handle polygons that cross the antimeridian or enclose a pole.

## Licence

MIT.

