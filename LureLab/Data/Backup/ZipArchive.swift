import Compression
import Foundation

/// Minimal ZIP (PKWARE APPNOTE) support for Lure Lab backups: STORE/DEFLATE, no ZIP64, no encryption.
enum CRC32 {
    private static let table: [UInt32] = (0...255).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for byte in buffer {
                crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func append16(_ value: UInt16) { Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) } }
    mutating func append32(_ value: UInt32) { Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) } }

    func read16(_ offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        let base = startIndex + offset
        return UInt16(self[base]) | (UInt16(self[base + 1]) << 8)
    }

    func read32(_ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        let base = startIndex + offset
        return UInt32(self[base]) | (UInt32(self[base + 1]) << 8) | (UInt32(self[base + 2]) << 16) | (UInt32(self[base + 3]) << 24)
    }
}

final class ZipWriter {
    private struct CentralEntry {
        let name: Data
        let method: UInt16
        let crc: UInt32
        let compressedSize: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private let handle: FileHandle
    private var offset: UInt64 = 0
    private var entries: [CentralEntry] = []
    private let dosTime: UInt16
    private let dosDate: UInt16

    init(url: URL, date: Date = Date()) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        let hour: Int = components.hour ?? 0
        let minute: Int = components.minute ?? 0
        let second: Int = components.second ?? 0
        let year: Int = max((components.year ?? 1980) - 1980, 0)
        let month: Int = components.month ?? 1
        let day: Int = components.day ?? 1
        let time: Int = (hour << 11) | (minute << 5) | (second / 2)
        let packedDate: Int = (year << 9) | (month << 5) | day
        dosTime = UInt16(truncatingIfNeeded: time)
        dosDate = UInt16(truncatingIfNeeded: packedDate)
    }

    func add(path: String, data: Data, compress: Bool) throws {
        guard let name = path.data(using: .utf8), data.count < Int(UInt32.max) else { throw BackupError.tooLarge }
        let crc = CRC32.checksum(data)
        var method: UInt16 = 0
        var payload = data
        if compress, let deflated = Self.deflate(data), deflated.count < data.count {
            method = 8
            payload = deflated
        }
        var header = Data()
        header.append32(0x0403_4B50)
        header.append16(20)
        header.append16(0x0800) // UTF-8 names
        header.append16(method)
        header.append16(dosTime)
        header.append16(dosDate)
        header.append32(crc)
        header.append32(UInt32(payload.count))
        header.append32(UInt32(data.count))
        header.append16(UInt16(name.count))
        header.append16(0)
        header.append(name)
        guard offset + UInt64(header.count + payload.count) < UInt64(UInt32.max) else { throw BackupError.tooLarge }
        entries.append(CentralEntry(name: name, method: method, crc: crc, compressedSize: UInt32(payload.count), size: UInt32(data.count), offset: UInt32(offset)))
        try write(header)
        try write(payload)
    }

    func finish() throws {
        let centralStart = offset
        for entry in entries {
            var record = Data()
            record.append32(0x0201_4B50)
            record.append16(0x031E) // made by: UNIX, 3.0
            record.append16(20)
            record.append16(0x0800)
            record.append16(entry.method)
            record.append16(dosTime)
            record.append16(dosDate)
            record.append32(entry.crc)
            record.append32(entry.compressedSize)
            record.append32(entry.size)
            record.append16(UInt16(entry.name.count))
            record.append16(0)
            record.append16(0)
            record.append16(0)
            record.append16(0)
            record.append32(UInt32(0o100644) << 16) // regular file
            record.append32(entry.offset)
            record.append(entry.name)
            try write(record)
        }
        var end = Data()
        end.append32(0x0605_4B50)
        end.append16(0)
        end.append16(0)
        end.append16(UInt16(entries.count))
        end.append16(UInt16(entries.count))
        end.append32(UInt32(offset - centralStart))
        end.append32(UInt32(centralStart))
        end.append16(0)
        try write(end)
        try handle.close()
    }

    private func write(_ data: Data) throws {
        try handle.write(contentsOf: data)
        offset += UInt64(data.count)
    }

    static func deflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + 1024
        var output = Data(count: capacity)
        let written = output.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Int in
                compression_encode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          input.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        output.count = written
        return output
    }
}

/// Reads and validates a ZIP before any of its content is used.
struct ZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let crc: UInt32
        let compressedSize: Int
        let size: Int
        let localHeaderOffset: Int
    }

    let data: Data
    let entries: [String: Entry]

    init(url: URL, maxEntries: Int, maxTotalSize: Int) throws {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { throw BackupError.unreadableArchive }
        try self.init(data: data, maxEntries: maxEntries, maxTotalSize: maxTotalSize)
    }

    init(data: Data, maxEntries: Int, maxTotalSize: Int) throws {
        self.data = data
        guard data.count >= 22, data.count <= maxTotalSize + 50 * 1024 * 1024 else {
            throw data.count < 22 ? BackupError.unreadableArchive : BackupError.tooLarge
        }
        // Locate the end-of-central-directory record.
        var eocd = -1
        let lowest = max(0, data.count - 22 - 65_535)
        var position = data.count - 22
        while position >= lowest {
            if data.read32(position) == 0x0605_4B50 { eocd = position; break }
            position -= 1
        }
        guard eocd >= 0,
              let totalEntries = data.read16(eocd + 10),
              let centralSize = data.read32(eocd + 12),
              let centralOffset = data.read32(eocd + 16)
        else { throw BackupError.unreadableArchive }
        guard totalEntries != 0xFFFF, centralOffset != 0xFFFF_FFFF else { throw BackupError.unreadableArchive }
        guard Int(totalEntries) <= maxEntries else { throw BackupError.tooManyPhotos }
        guard Int(centralOffset) + Int(centralSize) <= eocd else { throw BackupError.unreadableArchive }

        var result: [String: Entry] = [:]
        var cursor = Int(centralOffset)
        var totalSize = 0
        for _ in 0..<Int(totalEntries) {
            guard data.read32(cursor) == 0x0201_4B50,
                  let madeBy = data.read16(cursor + 4),
                  let flags = data.read16(cursor + 8),
                  let method = data.read16(cursor + 10),
                  let crc = data.read32(cursor + 16),
                  let compressedSize = data.read32(cursor + 20),
                  let size = data.read32(cursor + 24),
                  let nameLength = data.read16(cursor + 28),
                  let extraLength = data.read16(cursor + 30),
                  let commentLength = data.read16(cursor + 32),
                  let externalAttributes = data.read32(cursor + 38),
                  let localOffset = data.read32(cursor + 42)
            else { throw BackupError.unreadableArchive }
            let nameStart = cursor + 46
            guard nameStart + Int(nameLength) <= data.count else { throw BackupError.unreadableArchive }
            let nameData = data.subdata(in: (data.startIndex + nameStart)..<(data.startIndex + nameStart + Int(nameLength)))
            guard let name = String(data: nameData, encoding: .utf8), !name.isEmpty else { throw BackupError.unsafeEntry }
            cursor = nameStart + Int(nameLength) + Int(extraLength) + Int(commentLength)

            guard flags & 0x0001 == 0 else { throw BackupError.unreadableArchive } // encrypted
            guard compressedSize != 0xFFFF_FFFF, size != 0xFFFF_FFFF, localOffset != 0xFFFF_FFFF else { throw BackupError.unreadableArchive }
            try Self.checkSafePath(name)
            let hostSystem = madeBy >> 8
            let mode = externalAttributes >> 16
            if hostSystem == 3, (mode & 0o170000) == 0o120000 { throw BackupError.unsafeEntry } // symlink
            if name.hasSuffix("/") { continue } // directory entry
            guard method == 0 || method == 8 else { throw BackupError.unreadableArchive }
            guard result[name] == nil else { throw BackupError.duplicateEntry }
            totalSize += Int(size)
            guard totalSize <= maxTotalSize else { throw BackupError.tooLarge }
            result[name] = Entry(name: name, method: method, crc: crc, compressedSize: Int(compressedSize), size: Int(size), localHeaderOffset: Int(localOffset))
        }
        entries = result
    }

    static func checkSafePath(_ name: String) throws {
        guard !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0"), !name.contains(":") else { throw BackupError.unsafeEntry }
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        for (index, component) in components.enumerated() {
            if component == ".." || component == "." { throw BackupError.unsafeEntry }
            if component.isEmpty && index != components.count - 1 { throw BackupError.unsafeEntry }
        }
    }

    /// Extracts one entry, enforcing the size limit and CRC.
    func extract(_ entry: Entry, maxSize: Int) throws -> Data {
        guard entry.size <= maxSize else { throw BackupError.tooLarge }
        let local = entry.localHeaderOffset
        guard data.read32(local) == 0x0403_4B50,
              let nameLength = data.read16(local + 26),
              let extraLength = data.read16(local + 28)
        else { throw BackupError.unreadableArchive }
        let start = local + 30 + Int(nameLength) + Int(extraLength)
        guard start >= 0, start + entry.compressedSize <= data.count else { throw BackupError.unreadableArchive }
        let payload = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + entry.compressedSize))
        let output: Data
        if entry.method == 0 {
            guard payload.count == entry.size else { throw BackupError.unreadableArchive }
            output = payload
        } else {
            output = try Self.inflate(payload, expectedSize: entry.size)
        }
        guard CRC32.checksum(output) == entry.crc else { throw BackupError.unreadableArchive }
        return output
    }

    static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Int in
                guard let source = input.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                                                 source, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { throw BackupError.unreadableArchive }
        return output
    }
}
