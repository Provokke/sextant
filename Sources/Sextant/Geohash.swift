import Foundation

public enum Direction: CaseIterable, Sendable {
    case north, northEast, east, southEast, south, southWest, west, northWest

    var step: (lat: Int, lon: Int) {
        switch self {
        case .north: return (1, 0)
        case .northEast: return (1, 1)
        case .east: return (0, 1)
        case .southEast: return (-1, 1)
        case .south: return (-1, 0)
        case .southWest: return (-1, -1)
        case .west: return (0, -1)
        case .northWest: return (1, -1)
        }
    }
}

public struct GeohashBounds: Equatable, Sendable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public var center: Coordinate {
        Coordinate(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }

    public var latitudeSpan: Double { maxLatitude - minLatitude }
    public var longitudeSpan: Double { maxLongitude - minLongitude }
}

public enum Geohash {
    private static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let lookup: [Character: Int] = {
        var table: [Character: Int] = [:]
        for (index, character) in alphabet.enumerated() {
            table[character] = index
        }
        return table
    }()

    public static func encode(_ coordinate: Coordinate, precision: Int = 9) -> String {
        precondition(precision >= 1 && precision <= 12, "precision must be between 1 and 12")
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        let longitude = min(max(normaliseLongitude(coordinate.longitude), -180), 180)
        let latitude = min(max(coordinate.latitude, -90), 90)
        var result = ""
        var bit = 0
        var value = 0
        var useLongitude = true
        while result.count < precision {
            if useLongitude {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    value = value * 2 + 1
                    lonRange.0 = mid
                } else {
                    value *= 2
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    value = value * 2 + 1
                    latRange.0 = mid
                } else {
                    value *= 2
                    latRange.1 = mid
                }
            }
            useLongitude.toggle()
            bit += 1
            if bit == 5 {
                result.append(alphabet[value])
                bit = 0
                value = 0
            }
        }
        return result
    }

    public static func decode(_ hash: String) -> GeohashBounds? {
        guard !hash.isEmpty else { return nil }
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var useLongitude = true
        for character in hash.lowercased() {
            guard let value = lookup[character] else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let set = (value >> shift) & 1 == 1
                if useLongitude {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if set { lonRange.0 = mid } else { lonRange.1 = mid }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if set { latRange.0 = mid } else { latRange.1 = mid }
                }
                useLongitude.toggle()
            }
        }
        return GeohashBounds(
            minLatitude: latRange.0,
            maxLatitude: latRange.1,
            minLongitude: lonRange.0,
            maxLongitude: lonRange.1
        )
    }

    public static func neighbour(of hash: String, _ direction: Direction) -> String? {
        guard let bounds = decode(hash) else { return nil }
        let step = direction.step
        let latitude = bounds.center.latitude + Double(step.lat) * bounds.latitudeSpan
        guard latitude > -90, latitude < 90 else { return nil }
        let longitude = bounds.center.longitude + Double(step.lon) * bounds.longitudeSpan
        return encode(Coordinate(latitude: latitude, longitude: longitude), precision: hash.count)
    }

    public static func neighbours(of hash: String) -> [Direction: String] {
        var result: [Direction: String] = [:]
        for direction in Direction.allCases {
            if let value = neighbour(of: hash, direction) {
                result[direction] = value
            }
        }
        return result
    }
}
