import Foundation
import Testing
@testable import PulseSignal

struct PulseHeartGeometryTests {
    private let mesh = PulseHeartMesh()

    @Test func defaultMeshIsFiniteIndexedAndCompact() {
        #expect(!mesh.vertices.isEmpty)
        #expect(mesh.vertices.count < 5_000)
        #expect(mesh.indices.count.isMultiple(of: 3))

        for vertex in mesh.vertices {
            #expect(vertex.position.x.isFinite)
            #expect(vertex.position.y.isFinite)
            #expect(vertex.position.z.isFinite)
            #expect(vertex.normal.x.isFinite)
            #expect(vertex.normal.y.isFinite)
            #expect(vertex.normal.z.isFinite)
            #expect(abs(length(vertex.normal) - 1) < 0.001)
        }
        #expect(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count })
    }

    @Test func trianglesAreNondegenerateAndNormalsFollowWinding() {
        for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.vertices[Int(mesh.indices[offset])]
            let b = mesh.vertices[Int(mesh.indices[offset + 1])]
            let c = mesh.vertices[Int(mesh.indices[offset + 2])]
            let faceNormal = cross(b.position - a.position, c.position - a.position)
            let areaTwice = length(faceNormal)
            #expect(areaTwice > 0.000_000_1)

            let averageNormal = a.normal + b.normal + c.normal
            #expect(dot(faceNormal, averageNormal) > 0)
        }
    }

    @Test func meshIsClosedTwoManifold() {
        struct Edge: Hashable {
            let low: UInt32
            let high: UInt32

            init(_ a: UInt32, _ b: UInt32) {
                low = min(a, b)
                high = max(a, b)
            }
        }

        var edgeUses: [Edge: Int] = [:]
        for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
            let triangle = Array(mesh.indices[offset..<(offset + 3)])
            for edgeIndex in 0..<3 {
                let edge = Edge(triangle[edgeIndex], triangle[(edgeIndex + 1) % 3])
                edgeUses[edge, default: 0] += 1
            }
        }

        #expect(edgeUses.values.allSatisfy { $0 == 2 })
    }

    @Test func silhouetteHasTwinLobesNotchAndTaperedTip() throws {
        let equator = mesh.vertices.filter { abs($0.position.z) < 0.000_001 }
        let topY = try #require(equator.map(\.position.y).max())
        let bottomY = try #require(equator.map(\.position.y).min())
        let topCenter = try #require(equator.min { lhs, rhs in
            abs(lhs.position.x) < abs(rhs.position.x)
        })
        let upperRight = try #require(equator
            .filter { $0.position.x > 0.25 }
            .max { lhs, rhs in lhs.position.y < rhs.position.y })
        let upperLeft = try #require(equator
            .filter { $0.position.x < -0.25 }
            .max { lhs, rhs in lhs.position.y < rhs.position.y })
        let bottom = try #require(equator.min { lhs, rhs in
            lhs.position.y < rhs.position.y
        })

        #expect(topY > 0.9)
        #expect(bottomY < -0.9)
        #expect(upperLeft.position.y > topCenter.position.y + 0.3)
        #expect(upperRight.position.y > topCenter.position.y + 0.3)
        #expect(abs(upperLeft.position.y - upperRight.position.y) < 0.03)
        #expect(abs(bottom.position.x) < 0.02)
    }

    @Test func meshHasSubstantialFrontToBackThickness() throws {
        let minimumZ = try #require(mesh.vertices.map(\.position.z).min())
        let maximumZ = try #require(mesh.vertices.map(\.position.z).max())
        #expect(maximumZ - minimumZ > 0.8)
        #expect(mesh.vertices.contains { $0.position.z > 0.4 })
        #expect(mesh.vertices.contains { $0.position.z < -0.4 })
    }

    @Test func beatIsPeriodicBoundedAndReturnsToRest() {
        #expect(PulseHeartBeat.deformation(phase: 0) == SIMD3(repeating: 1))
        #expect(PulseHeartBeat.deformation(phase: 1) == SIMD3(repeating: 1))
        #expect(PulseHeartBeat.deformation(phase: -1) == SIMD3(repeating: 1))

        var observedExpansion = false
        for step in 0...1_000 {
            let phase = Double(step) / 1_000
            let deformation = PulseHeartBeat.deformation(phase: phase)
            #expect(deformation.x >= 0.98 && deformation.x <= 1.10)
            #expect(deformation.y >= 0.98 && deformation.y <= 1.10)
            #expect(deformation.z >= 0.97 && deformation.z <= 1.14)
            #expect(deformation == PulseHeartBeat.deformation(phase: phase + 4))
            observedExpansion = observedExpansion || deformation.z > 1.1
        }
        #expect(observedExpansion)
        #expect(PulseHeartBeat.deformation(phase: .nan) == SIMD3(repeating: 1))
    }

    private func cross(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
    }

    private func dot(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    private func length(_ vector: SIMD3<Float>) -> Float {
        sqrt(dot(vector, vector))
    }
}
