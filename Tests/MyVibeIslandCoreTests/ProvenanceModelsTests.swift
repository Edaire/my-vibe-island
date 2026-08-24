import XCTest
@testable import MyVibeIslandCore

final class ProvenanceModelsTests: XCTestCase {
    func testProvenanceModelsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ProvenanceModelsMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/provenance-models-matrix")
        )

        let binarySnapshots = [
            BinaryProvenanceSnapshot(
                integrityStatus: "trusted",
                executableLoadStatus: "loaded",
                externalHelperStatus: "managed",
                bundleIDMatchesOfficial: true,
                helperBinaryPresent: true,
                signingTeamMatchesOfficial: true,
                hardenedRuntimeEnabled: true,
                codeUniqueHash: "redacted-hash"
            ),
            BinaryProvenanceSnapshot(
                integrityStatus: "mismatch",
                executableLoadStatus: "loaded",
                externalHelperStatus: "stale",
                bundleIDMatchesOfficial: false,
                helperBinaryPresent: true,
                signingTeamMatchesOfficial: false,
                hardenedRuntimeEnabled: true,
                codeUniqueHash: "redacted-stale-hash"
            )
        ]
        let clientPayloads = [
            ClientProvenancePayload(
                appVersion: "1.0.0",
                platform: "macOS",
                bundleId: "com.example.fixture",
                binary: "my-vibe-island"
            ),
            ClientProvenancePayload(
                appVersion: "1.0.1",
                platform: "macOS",
                bundleId: "com.example.fixture.beta",
                binary: "my-vibe-island-beta"
            )
        ]
        let assessments = [
            ProvenanceAssessment(
                status: .trustedManaged,
                binarySnapshot: binarySnapshots[0],
                clientPayload: clientPayloads[0],
                redactionLevel: .redacted,
                reason: "managed helper matched expected signature"
            ),
            ProvenanceAssessment(
                status: .staleHelper,
                binarySnapshot: binarySnapshots[1],
                clientPayload: clientPayloads[1],
                redactionLevel: .localOnly,
                reason: "managed helper version is behind app version"
            ),
            ProvenanceAssessment(
                status: .unknown,
                redactionLevel: .redacted,
                reason: "no provenance payload supplied"
            )
        ]

        XCTAssertEqual(binarySnapshots, expected.binarySnapshots)
        XCTAssertEqual(clientPayloads, expected.clientPayloads)
        XCTAssertEqual(assessments, expected.assessments)
        XCTAssertEqual(ProvenanceAssessmentStatus.allFixtureCases, expected.statuses)
    }

    func testBinaryProvenanceSnapshotDecodesObservedProviderFields() throws {
        let json = """
        {
          "integrityStatus": "trusted",
          "executableLoadStatus": "loaded",
          "externalHelperStatus": "managed",
          "bundleIDMatchesOfficial": true,
          "helperBinaryPresent": true,
          "signingTeamMatchesOfficial": true,
          "hardenedRuntimeEnabled": true,
          "codeUniqueHash": "redacted-hash"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BinaryProvenanceSnapshot.self, from: json)

        XCTAssertEqual(decoded.integrityStatus, "trusted")
        XCTAssertEqual(decoded.executableLoadStatus, "loaded")
        XCTAssertEqual(decoded.externalHelperStatus, "managed")
        XCTAssertEqual(decoded.bundleIDMatchesOfficial, true)
        XCTAssertEqual(decoded.helperBinaryPresent, true)
        XCTAssertEqual(decoded.signingTeamMatchesOfficial, true)
        XCTAssertEqual(decoded.hardenedRuntimeEnabled, true)
        XCTAssertEqual(decoded.codeUniqueHash, "redacted-hash")
    }

    func testClientProvenancePayloadDecodesObservedProviderFields() throws {
        let json = """
        {
          "appVersion": "1.0.0",
          "platform": "macOS",
          "bundleId": "com.example.fixture",
          "binary": "my-vibe-island"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ClientProvenancePayload.self, from: json)

        XCTAssertEqual(decoded.appVersion, "1.0.0")
        XCTAssertEqual(decoded.platform, "macOS")
        XCTAssertEqual(decoded.bundleId, "com.example.fixture")
        XCTAssertEqual(decoded.binary, "my-vibe-island")
    }

    func testProvenanceAssessmentRoundTripsThroughJSON() throws {
        let assessment = ProvenanceAssessment(
            status: .trustedManaged,
            binarySnapshot: BinaryProvenanceSnapshot(
                integrityStatus: "trusted",
                executableLoadStatus: "loaded",
                externalHelperStatus: "managed",
                bundleIDMatchesOfficial: true,
                helperBinaryPresent: true,
                signingTeamMatchesOfficial: true,
                hardenedRuntimeEnabled: true,
                codeUniqueHash: "redacted-hash"
            ),
            clientPayload: ClientProvenancePayload(
                appVersion: "1.0.0",
                platform: "macOS",
                bundleId: "com.example.fixture",
                binary: "my-vibe-island"
            ),
            redactionLevel: .redacted,
            reason: "fixture"
        )

        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(ProvenanceAssessment.self, from: data)

        XCTAssertEqual(decoded, assessment)
    }

    private struct ProvenanceModelsMatrixFixture: Codable, Equatable {
        let binarySnapshots: [BinaryProvenanceSnapshot]
        let clientPayloads: [ClientProvenancePayload]
        let assessments: [ProvenanceAssessment]
        let statuses: [ProvenanceAssessmentStatus]
    }
}

private extension ProvenanceAssessmentStatus {
    static let allFixtureCases: [ProvenanceAssessmentStatus] = [
        .trustedManaged,
        .trustedUnmanaged,
        .staleHelper,
        .pathMismatch,
        .hashMismatch,
        .bundleMismatch,
        .missingMarker,
        .unknown
    ]
}
