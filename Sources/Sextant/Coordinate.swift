import Foundation

public struct Coordinate: Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum Earth {
    public static let meanRadius: Double = 6_371_008.8
}

private func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
private func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

public func normaliseLongitude(_ longitude: Double) -> Double {
    var value = longitude.truncatingRemainder(dividingBy: 360)
    if value > 180 { value -= 360 }
    if value <= -180 { value += 360 }
    return value
}

extension Coordinate {
    public func distance(to other: Coordinate, radius: Double = Earth.meanRadius) -> Double {
        let phi1 = radians(latitude)
        let phi2 = radians(other.latitude)
        let deltaPhi = radians(other.latitude - latitude)
        let deltaLambda = radians(other.longitude - longitude)
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return 2 * radius * atan2(sqrt(a), sqrt(1 - a))
    }

    public func initialBearing(to other: Coordinate) -> Double {
        let phi1 = radians(latitude)
        let phi2 = radians(other.latitude)
        let deltaLambda = radians(other.longitude - longitude)
        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let bearing = degrees(atan2(y, x))
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    public func destination(bearing: Double, distance: Double, radius: Double = Earth.meanRadius) -> Coordinate {
        let angular = distance / radius
        let theta = radians(bearing)
        let phi1 = radians(latitude)
        let lambda1 = radians(longitude)
        let sinPhi2 = sin(phi1) * cos(angular) + cos(phi1) * sin(angular) * cos(theta)
        let phi2 = asin(max(-1, min(1, sinPhi2)))
        let lambda2 = lambda1 + atan2(
            sin(theta) * sin(angular) * cos(phi1),
            cos(angular) - sin(phi1) * sinPhi2
        )
        return Coordinate(latitude: degrees(phi2), longitude: normaliseLongitude(degrees(lambda2)))
    }
}

public struct Polygon: Sendable {
    public let vertices: [Coordinate]

    public init(_ vertices: [Coordinate]) {
        var points = vertices
        if points.count > 1, points.first == points.last {
            points.removeLast()
        }
        self.vertices = points
    }

    public func contains(_ point: Coordinate) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var previous = vertices[vertices.count - 1]
        for current in vertices {
            if Polygon.isOnSegment(point, previous, current) { return true }
            let crosses = (current.latitude > point.latitude) != (previous.latitude > point.latitude)
            if crosses {
                let slope = (previous.longitude - current.longitude) / (previous.latitude - current.latitude)
                let crossingLongitude = current.longitude + (point.latitude - current.latitude) * slope
                if point.longitude < crossingLongitude {
                    inside.toggle()
                }
            }
            previous = current
        }
        return inside
    }

    private static func isOnSegment(_ p: Coordinate, _ a: Coordinate, _ b: Coordinate) -> Bool {
        let cross = (p.longitude - a.longitude) * (b.latitude - a.latitude)
            - (p.latitude - a.latitude) * (b.longitude - a.longitude)
        guard abs(cross) < 1e-12 else { return false }
        return p.latitude >= min(a.latitude, b.latitude) && p.latitude <= max(a.latitude, b.latitude)
            && p.longitude >= min(a.longitude, b.longitude) && p.longitude <= max(a.longitude, b.longitude)
    }
}

