import Foundation

struct CaptureLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let capturedAt: Date
}

private enum HarnessFailure: Error {
    case assertion(String)
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else { throw HarnessFailure.assertion(message) }
}

@main
private struct MacOSImportRollbackHarness {
    static func main() throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "zenche-macos-import-rollback-\(UUID().uuidString)",
                isDirectory: true
            )
        let sources = root.appendingPathComponent("sources", isDirectory: true)
        let library = root.appendingPathComponent("library", isDirectory: true)
        try fileManager.createDirectory(
            at: sources,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: root) }

        let defaultsName = "zenche.rollback.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            throw HarnessFailure.assertion("isolated defaults unavailable")
        }
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let workflow = CaptureWorkflow(
            rootDirectory: library,
            defaults: defaults
        )
        try workflow.begin(CaptureSessionConfiguration(
            name: "Rollback Harness",
            namingTemplate: "{session}_{counter}",
            creator: "ZENCHE",
            rights: "test",
            rating: 0,
            dualBackupEnabled: true
        ))

        let captureToken = try workflow.beginNonImportOperation()
        workflow.endNonImportOperation(UUID())
        do {
            _ = try workflow.beginImportBatch()
            throw HarnessFailure.assertion("wrong token released capture lease")
        } catch CaptureWorkflow.ImportError.importInProgress {
            // Exact-token ownership kept the capture lease active.
        }
        workflow.endNonImportOperation(captureToken)

        let jpeg = sources.appendingPathComponent("PAIR.JPG")
        let raw = sources.appendingPathComponent("PAIR.NEF")
        let bytes = Data((0..<(256 * 1024)).map { UInt8($0 % 251) })
        try bytes.write(to: jpeg)
        try bytes.write(to: raw)

        let first = try workflow.importFile(
            from: jpeg,
            cameraName: "Harness",
            reservedBaseName: "PAIR"
        )
        guard let backupDirectory = workflow.backupDirectory,
              let sessionRoot = workflow.sessionRoot else {
            throw HarnessFailure.assertion("session directories unavailable")
        }
        let primarySidecar = first
            .deletingPathExtension()
            .appendingPathExtension("xmp")
        let backup = backupDirectory.appendingPathComponent(first.lastPathComponent)
        let backupSidecar = backup
            .deletingPathExtension()
            .appendingPathExtension("xmp")
        let primaryBefore = try Data(contentsOf: primarySidecar)
        let backupBefore = try Data(contentsOf: backupSidecar)

        let manifest = sessionRoot.appendingPathComponent("checksums.sha256")
        try fileManager.removeItem(at: manifest)
        try fileManager.createDirectory(
            at: manifest,
            withIntermediateDirectories: false
        )
        do {
            _ = try workflow.importFile(
                from: raw,
                cameraName: "Harness",
                reservedBaseName: "PAIR"
            )
            throw HarnessFailure.assertion("manifest-directory fault succeeded")
        } catch HarnessFailure.assertion(let message) {
            throw HarnessFailure.assertion(message)
        } catch {
            // Expected: manifest read is fail-closed and triggers rollback.
        }

        let primaryAfter = try Data(contentsOf: primarySidecar)
        let backupAfter = try Data(contentsOf: backupSidecar)
        try require(
            primaryAfter == primaryBefore,
            "primary XMP was not restored"
        )
        try require(
            backupAfter == backupBefore,
            "backup XMP was not restored"
        )
        try require(
            !fileManager.fileExists(
                atPath: workflow.primaryDirectory
                    .appendingPathComponent("PAIR.nef").path
            ),
            "failed primary remained"
        )
        try require(
            !fileManager.fileExists(
                atPath: backupDirectory.appendingPathComponent("PAIR.nef").path
            ),
            "failed backup remained"
        )
        print("macOS import rollback behavior: PASS")
    }
}
