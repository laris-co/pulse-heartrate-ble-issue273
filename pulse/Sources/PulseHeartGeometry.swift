import Foundation

/// A render-agnostic vertex for Pulse's heart sculpture.
public struct HeartVertex: Equatable, Sendable {
    public let position: SIMD3<Float>
    public let normal: SIMD3<Float>

    public init(position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.position = position
        self.normal = normal
    }
}

/// A closed, smooth, plump love-heart mesh with no rendering-framework dependency.
///
/// The familiar parametric heart curve forms the silhouette. Nested copies of that
/// curve are lofted toward front and back poles, producing real volume rather than
/// an extrusion. The two halves share their equator so the result is watertight.
public struct PulseHeartMesh: Sendable {
    public let vertices: [HeartVertex]
    public let indices: [UInt32]

    public init(
        angularSegments: Int = 120,
        radialSegments: Int = 18,
        depth: Float = 0.46
    ) {
        let angularSegments = max(24, angularSegments)
        let radialSegments = max(4, radialSegments)
        let depth = min(max(depth, 0.12), 0.8)

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(2 + angularSegments * (2 * radialSegments - 1))

        // The poles are deliberately a little above the silhouette's bounding-box
        // center: that leaves more visual weight in the lobes than in the point.
        let poleY: Float = 0.02
        let frontPole = positions.count
        positions.append(SIMD3(0, poleY, depth))
        let backPole = positions.count
        positions.append(SIMD3(0, poleY, -depth))

        var frontRings: [[Int]] = []
        var backRings: [[Int]] = []
        frontRings.reserveCapacity(radialSegments - 1)
        backRings.reserveCapacity(radialSegments - 1)

        for radialIndex in 1..<radialSegments {
            let radius = Float(radialIndex) / Float(radialSegments)
            let z = depth * Self.hemisphereHeight(at: radius)
            frontRings.append(Self.appendRing(
                radius: radius,
                z: z,
                angularSegments: angularSegments,
                positions: &positions
            ))
            backRings.append(Self.appendRing(
                radius: radius,
                z: -z,
                angularSegments: angularSegments,
                positions: &positions
            ))
        }

        // One shared equator makes every edge belong to exactly two triangles.
        let equator = Self.appendRing(
            radius: 1,
            z: 0,
            angularSegments: angularSegments,
            positions: &positions
        )

        var indices: [UInt32] = []
        indices.reserveCapacity(angularSegments * radialSegments * 12)

        Self.appendFan(
            pole: frontPole,
            ring: frontRings[0],
            facesForward: true,
            indices: &indices
        )
        Self.appendFan(
            pole: backPole,
            ring: backRings[0],
            facesForward: false,
            indices: &indices
        )

        for ringIndex in 0..<(frontRings.count - 1) {
            Self.appendStrip(
                inner: frontRings[ringIndex],
                outer: frontRings[ringIndex + 1],
                facesForward: true,
                indices: &indices
            )
            Self.appendStrip(
                inner: backRings[ringIndex],
                outer: backRings[ringIndex + 1],
                facesForward: false,
                indices: &indices
            )
        }

        Self.appendStrip(
            inner: frontRings[frontRings.count - 1],
            outer: equator,
            facesForward: true,
            indices: &indices
        )
        Self.appendStrip(
            inner: backRings[backRings.count - 1],
            outer: equator,
            facesForward: false,
            indices: &indices
        )

        let normals = Self.vertexNormals(positions: positions, indices: indices)
        vertices = zip(positions, normals).map(HeartVertex.init(position:normal:))
        self.indices = indices
    }

    private static func appendRing(
        radius: Float,
        z: Float,
        angularSegments: Int,
        positions: inout [SIMD3<Float>]
    ) -> [Int] {
        var ring: [Int] = []
        ring.reserveCapacity(angularSegments)
        for angularIndex in 0..<angularSegments {
            // Half-step sampling straddles, rather than lands directly on, the
            // two zero-derivative cusps. The tiny bridge across each side rounds
            // the notch and point and avoids needle-like triangles.
            let angle = 2 * Float.pi
                * (Float(angularIndex) + 0.5)
                / Float(angularSegments)
            let point = outline(at: angle)
            ring.append(positions.count)
            positions.append(SIMD3(point.x * radius, point.y * radius, z))
        }
        return ring
    }

    /// Classic `16 sin³(t)` heart, centered and normalized to approximately [-1, 1].
    private static func outline(at angle: Float) -> SIMD2<Float> {
        let sine = sin(angle)
        let classicX = sine * sine * sine
        // A 2% linear blend rounds the mathematical curve's zero-width cusps.
        // Visually it remains the classic sin³ silhouette, but lighting remains
        // stable at both the cleft and the pointed base.
        let x = 0.98 * classicX + 0.02 * sine
        let rawY = 13 * cos(angle)
            - 5 * cos(2 * angle)
            - 2 * cos(3 * angle)
            - cos(4 * angle)

        // Raw y bounds are about -17...11.92. Centering that interval retains
        // the recognizable deep notch and pointed base without stretching either.
        return SIMD2(x, (rawY + 2.54) / 14.46)
    }

    private static func hemisphereHeight(at radius: Float) -> Float {
        // The exponent slightly broadens the crown relative to a sphere, producing
        // a soft toy-like volume while still meeting the equator cleanly.
        pow(max(0, 1 - radius * radius), 0.58)
    }

    private static func appendFan(
        pole: Int,
        ring: [Int],
        facesForward: Bool,
        indices: inout [UInt32]
    ) {
        for index in ring.indices {
            let next = ring.index(afterWrapping: index)
            appendTriangle(
                pole,
                facesForward ? ring[next] : ring[index],
                facesForward ? ring[index] : ring[next],
                to: &indices
            )
        }
    }

    private static func appendStrip(
        inner: [Int],
        outer: [Int],
        facesForward: Bool,
        indices: inout [UInt32]
    ) {
        for index in inner.indices {
            let next = inner.index(afterWrapping: index)
            if facesForward {
                appendTriangle(inner[index], outer[next], outer[index], to: &indices)
                appendTriangle(inner[index], inner[next], outer[next], to: &indices)
            } else {
                appendTriangle(inner[index], outer[index], outer[next], to: &indices)
                appendTriangle(inner[index], outer[next], inner[next], to: &indices)
            }
        }
    }

    private static func appendTriangle(
        _ a: Int,
        _ b: Int,
        _ c: Int,
        to indices: inout [UInt32]
    ) {
        indices.append(UInt32(a))
        indices.append(UInt32(b))
        indices.append(UInt32(c))
    }

    private static func vertexNormals(
        positions: [SIMD3<Float>],
        indices: [UInt32]
    ) -> [SIMD3<Float>] {
        var accumulated = Array(repeating: SIMD3<Float>.zero, count: positions.count)
        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[triangle])
            let b = Int(indices[triangle + 1])
            let c = Int(indices[triangle + 2])
            let faceNormal = cross(positions[b] - positions[a], positions[c] - positions[a])
            accumulated[a] += faceNormal
            accumulated[b] += faceNormal
            accumulated[c] += faceNormal
        }

        return accumulated.enumerated().map { index, normal in
            let length = sqrt(dot(normal, normal))
            if length > 0.000_001, length.isFinite {
                return normal / length
            }

            // Defensive fallback for pathologically low/custom resolution. Default
            // meshes never take this branch, but callers still receive finite data.
            let position = positions[index]
            let fallback = SIMD3(position.x, position.y - 0.02, position.z)
            let fallbackLength = sqrt(dot(fallback, fallback))
            return fallbackLength > 0.000_001
                ? fallback / fallbackLength
                : SIMD3(0, 0, position.z >= 0 ? 1 : -1)
        }
    }

    private static func cross(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
    }

    private static func dot(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }
}

/// Render-independent beat deformation driven by a normalized clock phase.
public enum PulseHeartBeat {
    /// Returns nonuniform XYZ scale. Integer phases are exactly the rest pose.
    public static func deformation(phase: Double) -> SIMD3<Float> {
        guard phase.isFinite else { return SIMD3(repeating: 1) }
        let normalizedPhase = phase - floor(phase)
        let contraction = pulseWindow(normalizedPhase, start: 0.04, duration: 0.11)
        let primary = pulseWindow(normalizedPhase, start: 0.13, duration: 0.20)
        let secondary = pulseWindow(normalizedPhase, start: 0.38, duration: 0.14)
        let amount = -0.018 * contraction + 0.095 * primary + 0.032 * secondary

        // Depth moves a little farther than the silhouette so the beat reads as
        // an organic squeeze-and-release rather than a flat uniform zoom.
        return SIMD3(
            Float(1 + amount),
            Float(1 + amount * 0.92),
            Float(1 + amount * 1.35)
        )
    }

    private static func pulseWindow(
        _ phase: Double,
        start: Double,
        duration: Double
    ) -> Double {
        guard phase >= start, phase <= start + duration else { return 0 }
        let progress = (phase - start) / duration
        let sine = sin(.pi * progress)
        return sine * sine
    }
}

private extension Collection {
    func index(afterWrapping index: Index) -> Index {
        let next = self.index(after: index)
        return next == endIndex ? startIndex : next
    }
}
