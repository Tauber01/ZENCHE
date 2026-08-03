import Foundation

struct CameraStorageVolume: Identifiable, Hashable {
    let id: UInt32
    let name: String
    let capacityBytes: UInt64
    let freeBytes: UInt64
    let freeImages: UInt32
    let isReadOnly: Bool
}

struct CameraStorageItem: Identifiable, Hashable {
    let handle: UInt32
    let storageID: UInt32
    let format: UInt16
    let filename: String
    let sizeBytes: UInt64
    let width: UInt32
    let height: UInt32
    let capturedAt: String
    let isProtected: Bool

    var id: UInt32 { handle }

    var isVideo: Bool {
        let suffix = URL(fileURLWithPath: filename)
            .pathExtension
            .lowercased()
        return ["mov", "mp4", "avi", "m4v", "mts", "m2ts"].contains(suffix)
    }
}

struct CameraStorageSnapshot: Hashable {
    let volumes: [CameraStorageVolume]
    let items: [CameraStorageItem]

    static let empty = CameraStorageSnapshot(volumes: [], items: [])

    var capacityBytes: UInt64 {
        volumes.reduce(0) { partial, volume in
            partial.addingReportingOverflow(volume.capacityBytes).overflow
                ? UInt64.max
                : partial + volume.capacityBytes
        }
    }

    var freeBytes: UInt64 {
        volumes.reduce(0) { partial, volume in
            partial.addingReportingOverflow(volume.freeBytes).overflow
                ? UInt64.max
                : partial + volume.freeBytes
        }
    }
}

enum CameraStorageParser {
    static func storageIDs(_ data: Data) -> [UInt32] {
        guard data.count >= 4 else { return [] }
        let requested = Int(min(readUInt32(data, at: 0), UInt32(Int.max)))
        let count = min(requested, (data.count - 4) / 4)
        return (0..<count).map { readUInt32(data, at: 4 + $0 * 4) }
    }

    static func storageInfo(
        id: UInt32,
        data: Data
    ) -> CameraStorageVolume {
        guard data.count >= 26 else {
            return CameraStorageVolume(
                id: id,
                name: storageLabel(id),
                capacityBytes: 0,
                freeBytes: 0,
                freeImages: 0,
                isReadOnly: false
            )
        }
        let description = ptpString(data, at: 26)
        let label = ptpString(data, at: description.nextOffset)
        let name = !label.value.isEmpty
            ? label.value
            : !description.value.isEmpty
                ? description.value
                : storageLabel(id)
        return CameraStorageVolume(
            id: id,
            name: name,
            capacityBytes: readUInt64(data, at: 6),
            freeBytes: readUInt64(data, at: 14),
            freeImages: readUInt32(data, at: 22),
            isReadOnly: readUInt16(data, at: 4) != 0
        )
    }

    static func objectInfo(
        handle: UInt32,
        data: Data
    ) -> CameraStorageItem? {
        guard data.count >= 52, readUInt16(data, at: 42) == 0 else {
            return nil
        }
        let filename = ptpString(data, at: 52)
        guard !filename.value.isEmpty else { return nil }
        let capturedAt = ptpString(data, at: filename.nextOffset)
        return CameraStorageItem(
            handle: handle,
            storageID: readUInt32(data, at: 0),
            format: readUInt16(data, at: 4),
            filename: filename.value,
            sizeBytes: UInt64(readUInt32(data, at: 8)),
            width: readUInt32(data, at: 26),
            height: readUInt32(data, at: 30),
            capturedAt: displayDate(capturedAt.value),
            isProtected: readUInt16(data, at: 6) != 0
        )
    }

    static func isAssociation(_ data: Data) -> Bool {
        data.count >= 52 && readUInt16(data, at: 42) != 0
    }

    private static func ptpString(
        _ data: Data,
        at offset: Int
    ) -> (value: String, nextOffset: Int) {
        guard offset >= 0, offset < data.count else {
            return ("", data.count)
        }
        let count = Int(byte(data, at: offset))
        guard count > 0 else { return ("", offset + 1) }
        var values: [UInt16] = []
        values.reserveCapacity(max(0, count - 1))
        for index in 0..<max(0, count - 1) {
            let characterOffset = offset + 1 + index * 2
            guard characterOffset + 1 < data.count else { break }
            values.append(readUInt16(data, at: characterOffset))
        }
        return (
            String(decoding: values, as: UTF16.self),
            min(data.count, offset + 1 + count * 2)
        )
    }

    private static func displayDate(_ value: String) -> String {
        guard value.count >= 8 else { return "—" }
        let characters = Array(value)
        var result = String(characters[0..<4]) + "-"
            + String(characters[4..<6]) + "-"
            + String(characters[6..<8])
        if characters.count >= 15, characters[8] == "T" {
            result += " " + String(characters[9..<11])
                + ":" + String(characters[11..<13])
                + ":" + String(characters[13..<15])
        }
        return result
    }

    private static func storageLabel(_ id: UInt32) -> String {
        String(format: "存储卡 %08X", id)
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8 {
        guard offset >= 0, offset < data.count else { return 0 }
        return data[data.startIndex.advanced(by: offset)]
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(byte(data, at: offset))
            | (UInt16(byte(data, at: offset + 1)) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(byte(data, at: offset))
            | (UInt32(byte(data, at: offset + 1)) << 8)
            | (UInt32(byte(data, at: offset + 2)) << 16)
            | (UInt32(byte(data, at: offset + 3)) << 24)
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        UInt64(readUInt32(data, at: offset))
            | (UInt64(readUInt32(data, at: offset + 4)) << 32)
    }
}
