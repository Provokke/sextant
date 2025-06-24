import XCTest
@testable import Sextant

final class DistanceTests: XCTestCase {
    private let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
    private let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
    private let sydney = Coordinate(latitude: -33.8688, longitude: 151.2093)
    private let melbourne = Coordinate(latitude: -37.8136, longitude: 144.9631)

    func testHaversineKnownDistances() {
        XCTAssertEqual(london.distance(to: paris), 343_500, accuracy: 1_500)
        XCTAssertEqual(sydney.distance(to: melbourne), 713_400, accuracy: 3_000)
    }

    func testDistanceIsSymmetricAndZeroToSelf() {
        XCTAssertEqual(london.distance(to: paris), paris.distance(to: london), accuracy: 1e-6)
        XCTAssertEqual(london.distance(to: london), 0, accuracy: 1e-9)
    }

    func testQuarterOfTheEquator() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 0, longitude: 90)
        XCTAssertEqual(a.distance(to: b), Earth.meanRadius * .pi / 2, accuracy: 1e-3)
    }

    func testBearings() {
        let origin = Coordinate(latitude: 0, longitude: 0)
        XCTAssertEqual(origin.initialBearing(to: Coordinate(latitude: 10, longitude: 0)), 0, accuracy: 1e-9)
        XCTAssertEqual(origin.initialBearing(to: Coordinate(latitude: 0, longitude: 10)), 90, accuracy: 1e-9)
        XCTAssertEqual(origin.initialBearing(to: Coordinate(latitude: -10, longitude: 0)), 180, accuracy: 1e-9)
        XCTAssertEqual(origin.initialBearing(to: Coordinate(latitude: 0, longitude: -10)), 270, accuracy: 1e-9)
    }

    func testDestinationRoundTrip() {
        let bearing = london.initialBearing(to: paris)
        let distance = london.distance(to: paris)
        let arrived = london.destination(bearing: bearing, distance: distance)
        XCTAssertEqual(arrived.latitude, paris.latitude, accuracy: 1e-6)
        XCTAssertEqual(arrived.longitude, paris.longitude, accuracy: 1e-6)
    }

    func testDestinationDueEastOnEquator() {
        let origin = Coordinate(latitude: 0, longitude: 0)
        let moved = origin.destination(bearing: 90, distance: Earth.meanRadius * .pi / 180)
        XCTAssertEqual(moved.latitude, 0, accuracy: 1e-9)
        XCTAssertEqual(moved.longitude, 1, accuracy: 1e-9)
    }

    func testDestinationWrapsAcrossAntimeridian() {
        let start = Coordinate(latitude: 0, longitude: 179.5)
        let moved = start.destination(bearing: 90, distance: Earth.meanRadius * .pi / 180)
        XCTAssertEqual(moved.longitude, -179.5, accuracy: 1e-9)
    }
}

final class GeohashTests: XCTestCase {
    func testKnownEncodings() {
        XCTAssertEqual(Geohash.encode(Coordinate(latitude: 42.6, longitude: -5.6), precision: 5), "ezs42")
        XCTAssertEqual(Geohash.encode(Coordinate(latitude: 57.64911, longitude: 10.40744), precision: 11), "u4pruydqqvj")
    }

    func testDecodeContainsOriginalPoint() throws {
        let point = Coordinate(latitude: -33.8688, longitude: 151.2093)
        let hash = Geohash.encode(point, precision: 8)
        let bounds = try XCTUnwrap(Geohash.decode(hash))
        XCTAssertTrue(point.latitude >= bounds.minLatitude && point.latitude <= bounds.maxLatitude)
        XCTAssertTrue(point.longitude >= bounds.minLongitude && point.longitude <= bounds.maxLongitude)
        XCTAssertEqual(bounds.center.latitude, point.latitude, accuracy: 1e-3)
    }

    func testDecodeKnownCentre() throws {
        let bounds = try XCTUnwrap(Geohash.decode("ezs42"))
        XCTAssertEqual(bounds.center.latitude, 42.605, accuracy: 1e-3)
        XCTAssertEqual(bounds.center.longitude, -5.603, accuracy: 1e-3)
    }

    func testDecodeRejectsBadInput() {
        XCTAssertNil(Geohash.decode(""))
        XCTAssertNil(Geohash.decode("abc!"))
        XCTAssertNil(Geohash.decode("ailo"))
    }

    func testNeighbours() {
        let all = Geohash.neighbours(of: "ezs42")
        XCTAssertEqual(all.count, 8)
        XCTAssertEqual(all[.east], "ezs43")
        XCTAssertEqual(Set(all.values).count, 8)
        XCTAssertFalse(all.values.contains("ezs42"))
        for (direction, hash) in all {
            XCTAssertEqual(hash.count, 5)
            XCTAssertNotNil(Geohash.decode(hash), "\(direction)")
        }
    }

    func testNeighbourIsReversible() {
        let hash = "u4pru"
        let north = Geohash.neighbour(of: hash, .north)
        XCTAssertEqual(north.flatMap { Geohash.neighbour(of: $0, .south) }, hash)
        let west = Geohash.neighbour(of: hash, .west)
        XCTAssertEqual(west.flatMap { Geohash.neighbour(of: $0, .east) }, hash)
    }

    func testNeighbourWrapsAtAntimeridianAndStopsAtPoles() {
        let east = Geohash.encode(Coordinate(latitude: 10, longitude: 179.99), precision: 4)
        let wrapped = Geohash.neighbour(of: east, .east)
        let bounds = Geohash.decode(wrapped ?? "")
        XCTAssertNotNil(bounds)
        XCTAssertLessThan(bounds?.center.longitude ?? 0, -170)
        let polar = Geohash.encode(Coordinate(latitude: 89.99, longitude: 0), precision: 4)
        XCTAssertNil(Geohash.neighbour(of: polar, .north))
        XCTAssertEqual(Geohash.neighbours(of: polar).count, 5)
    }
}

final class PolygonTests: XCTestCase {
    private let square = Polygon([
        Coordinate(latitude: 0, longitude: 0),
        Coordinate(latitude: 0, longitude: 10),
        Coordinate(latitude: 10, longitude: 10),
        Coordinate(latitude: 10, longitude: 0)
    ])

    func testInsideAndOutside() {
        XCTAssertTrue(square.contains(Coordinate(latitude: 5, longitude: 5)))
        XCTAssertFalse(square.contains(Coordinate(latitude: 15, longitude: 5)))
        XCTAssertFalse(square.contains(Coordinate(latitude: 5, longitude: -1)))
    }

    func testBoundaryCountsAsInside() {
        XCTAssertTrue(square.contains(Coordinate(latitude: 0, longitude: 5)))
        XCTAssertTrue(square.contains(Coordinate(latitude: 10, longitude: 10)))
    }

    func testConcavePolygon() {
        let ell = Polygon([
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 10),
            Coordinate(latitude: 4, longitude: 10),
            Coordinate(latitude: 4, longitude: 4),
            Coordinate(latitude: 10, longitude: 4),
            Coordinate(latitude: 10, longitude: 0)
        ])
        XCTAssertTrue(ell.contains(Coordinate(latitude: 2, longitude: 8)))
        XCTAssertTrue(ell.contains(Coordinate(latitude: 8, longitude: 2)))
        XCTAssertFalse(ell.contains(Coordinate(latitude: 8, longitude: 8)))
    }

    func testClosedRingAndDegenerateInput() {
        let closed = Polygon(square.vertices + [square.vertices[0]])
        XCTAssertEqual(closed.vertices.count, 4)
        XCTAssertTrue(closed.contains(Coordinate(latitude: 5, longitude: 5)))
        XCTAssertFalse(Polygon([Coordinate(latitude: 0, longitude: 0)]).contains(Coordinate(latitude: 0, longitude: 0)))
    }
}

