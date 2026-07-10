import Foundation
import zlib

extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "zip" || fileExtension == "mcworld"
                || fileExtension == "mcpack" || fileExtension == "mcaddon"
                || fileExtension == "levibackup" || fileExtension == "levipack" else {
            throw ZipError.unsupportedFormat
        }

        try createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try unzipBasic(at: sourceURL, to: destinationURL)
    }

    private func unzipBasic(at sourceURL: URL, to destinationURL: URL) throws {
        guard let data = try? Data(contentsOf: sourceURL) else {
            throw ZipError.invalidArchive
        }
        try ZipReader.extract(data: data, to: destinationURL)
    }
}

enum ZipError: LocalizedError {
    case unsupportedFormat
    case invalidArchive
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported archive format"
        case .invalidArchive: return "Invalid archive"
        case .extractionFailed(let msg): return "Extraction failed: \(msg)"
        }
    }
}

// Minimal ZIP extraction using zlib
struct ZipReader {
    private static let maxEntrySize = 512 * 1024 * 1024
    private static let maxArchiveSize = 1024 * 1024 * 1024

    static func extract(data: Data, to destinationURL: URL) throws {
        guard let endOffset = findEndOfCentralDirectory(in: data) else {
            throw ZipError.invalidArchive
        }
        let entryCount = Int(try readUInt16(data: data, offset: endOffset + 10))
        var centralOffset = Int(try readUInt32(data: data, offset: endOffset + 16))
        var totalSize = 0

        for _ in 0..<entryCount {
            guard try readUInt32(data: data, offset: centralOffset) == 0x02014b50 else {
                throw ZipError.invalidArchive
            }
            let flags = try readUInt16(data: data, offset: centralOffset + 8)
            guard flags & 0x0001 == 0 else {
                throw ZipError.extractionFailed("Encrypted ZIP entries are unsupported")
            }
            let method = try readUInt16(data: data, offset: centralOffset + 10)
            let expectedCRC = try readUInt32(data: data, offset: centralOffset + 16)
            let compressedSize = Int(try readUInt32(data: data, offset: centralOffset + 20))
            let uncompressedSize = Int(try readUInt32(data: data, offset: centralOffset + 24))
            let nameLength = Int(try readUInt16(data: data, offset: centralOffset + 28))
            let extraLength = Int(try readUInt16(data: data, offset: centralOffset + 30))
            let commentLength = Int(try readUInt16(data: data, offset: centralOffset + 32))
            let localOffset = Int(try readUInt32(data: data, offset: centralOffset + 42))
            let nameStart = centralOffset + 46
            let nameData = try slice(data, nameStart..<(nameStart + nameLength))
            guard let fileName = String(data: nameData, encoding: .utf8), !fileName.isEmpty else {
                throw ZipError.invalidArchive
            }
            centralOffset = nameStart + nameLength + extraLength + commentLength

            guard uncompressedSize <= maxEntrySize,
                  totalSize <= maxArchiveSize - uncompressedSize else {
                throw ZipError.extractionFailed("Archive is too large")
            }
            totalSize += uncompressedSize

            let outputURL = try safeOutputURL(fileName, under: destinationURL)
            if fileName.hasSuffix("/") {
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                continue
            }

            guard try readUInt32(data: data, offset: localOffset) == 0x04034b50 else {
                throw ZipError.invalidArchive
            }
            let localNameLength = Int(try readUInt16(data: data, offset: localOffset + 26))
            let localExtraLength = Int(try readUInt16(data: data, offset: localOffset + 28))
            let payloadStart = localOffset + 30 + localNameLength + localExtraLength
            let compressed = try slice(data, payloadStart..<(payloadStart + compressedSize))
            let extracted: Data
            switch method {
            case 0:
                extracted = compressed
            case 8:
                extracted = try inflate(compressed, uncompressedSize: uncompressedSize)
            default:
                throw ZipError.extractionFailed("Unsupported compression: \(method)")
            }
            guard extracted.count == uncompressedSize,
                  checksum(extracted) == expectedCRC else {
                throw ZipError.extractionFailed("Corrupt ZIP entry: \(fileName)")
            }
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try extracted.write(to: outputURL, options: .atomic)
        }
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let lowerBound = max(0, data.count - 65_557)
        for offset in stride(from: data.count - 22, through: lowerBound, by: -1) {
            guard (try? readUInt32(data: data, offset: offset)) == 0x06054b50,
                  let commentLength = try? readUInt16(data: data, offset: offset + 20),
                  offset + 22 + Int(commentLength) == data.count else { continue }
            return offset
        }
        return nil
    }

    private static func readUInt16(data: Data, offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw ZipError.invalidArchive }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(data: Data, offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw ZipError.invalidArchive }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func slice(_ data: Data, _ range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= data.count else {
            throw ZipError.invalidArchive
        }
        return Data(data[range])
    }

    private static func safeOutputURL(_ name: String, under destination: URL) throws -> URL {
        let normalizedName = name.replacingOccurrences(of: "\\", with: "/")
        guard !normalizedName.hasPrefix("/"),
              !normalizedName.split(separator: "/").contains("..") else {
            throw ZipError.extractionFailed("Unsafe archive path")
        }
        let root = destination.standardizedFileURL.path
        let output = destination.appendingPathComponent(normalizedName).standardizedFileURL
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard output.path == root || output.path.hasPrefix(prefix) else {
            throw ZipError.extractionFailed("Unsafe archive path")
        }
        return output
    }

    private static func checksum(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { bytes in
            guard let base = bytes.bindMemory(to: Bytef.self).baseAddress else { return 0 }
            return UInt32(zlib.crc32(0, base, uInt(data.count)))
        }
    }

    private static func inflate(_ data: Data, uncompressedSize: Int) throws -> Data {
        if uncompressedSize == 0 { return Data() }
        var result = Data(count: uncompressedSize)
        var stream = z_stream()

        return try data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
            guard let srcBase = srcPtr.baseAddress else { throw ZipError.extractionFailed("no data") }
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: srcBase.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = uInt(data.count)

            return try result.withUnsafeMutableBytes { (dstPtr: UnsafeMutableRawBufferPointer) -> Data in
                guard let dstBase = dstPtr.baseAddress else { throw ZipError.extractionFailed("no buffer") }
                stream.next_out = dstBase.assumingMemoryBound(to: UInt8.self)
                stream.avail_out = uInt(uncompressedSize)

                let initResult = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard initResult == Z_OK else {
                    throw ZipError.extractionFailed("deflate init failed: \(initResult)")
                }

                let inflateResult = zlib.inflate(&stream, Z_FINISH)
                inflateEnd(&stream)

                guard inflateResult == Z_STREAM_END || inflateResult == Z_OK else {
                    throw ZipError.extractionFailed("inflate failed: \(inflateResult)")
                }

                return Data(dstPtr.prefix(Int(stream.total_out)))
            }
        }
    }
}
