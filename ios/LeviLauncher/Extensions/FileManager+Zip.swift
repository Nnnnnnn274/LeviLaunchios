import Foundation
import zlib

extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        guard sourceURL.pathExtension == "zip" || sourceURL.pathExtension == "mcworld"
                || sourceURL.pathExtension == "mcpack" || sourceURL.pathExtension == "mcaddon"
                || sourceURL.pathExtension == "levibackup" else {
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
    struct LocalFileHeader {
        let signature: UInt32
        let versionNeeded: UInt16
        let flags: UInt16
        let compressionMethod: UInt16
        let lastModTime: UInt16
        let lastModDate: UInt16
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let fileNameLength: UInt16
        let extraFieldLength: UInt16
        let fileName: String
    }

    static func extract(data: Data, to destinationURL: URL) throws {
        var offset = 0

        while offset < data.count - 4 {
            let signature = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
            }

            if signature == 0x04034b50 { // Local file header signature
                let header = try readLocalFileHeader(data: data, offset: offset)
                offset += 30 + Int(header.fileNameLength) + Int(header.extraFieldLength)

                let filePath = destinationURL.appendingPathComponent(header.fileName)

                if header.fileName.hasSuffix("/") {
                    try FileManager.default.createDirectory(at: filePath, withIntermediateDirectories: true)
                } else {
                    try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)

                    let rawData = data[offset..<offset + Int(header.compressedSize)]
                    let extracted: Data

                    if header.compressionMethod == 0 {
                        extracted = rawData
                    } else if header.compressionMethod == 8 {
                        extracted = try inflate(rawData, uncompressedSize: Int(header.uncompressedSize))
                    } else {
                        throw ZipError.extractionFailed("Unsupported compression: \(header.compressionMethod)")
                    }

                    try extracted.write(to: filePath, options: .atomic)
                }

                offset += Int(header.compressedSize)
            } else if signature == 0x02014b50 || signature == 0x06054b50 {
                break // Central directory or End of central directory
            } else {
                offset += 1
            }
        }
    }

    private static func readLocalFileHeader(data: Data, offset: Int) throws -> LocalFileHeader {
        var o = offset
        let signature = readUInt32(data: data, offset: o); o += 4
        let versionNeeded = readUInt16(data: data, offset: o); o += 2
        let flags = readUInt16(data: data, offset: o); o += 2
        let compressionMethod = readUInt16(data: data, offset: o); o += 2
        let lastModTime = readUInt16(data: data, offset: o); o += 2
        let lastModDate = readUInt16(data: data, offset: o); o += 2
        let crc32 = readUInt32(data: data, offset: o); o += 4
        let compressedSize = readUInt32(data: data, offset: o); o += 4
        let uncompressedSize = readUInt32(data: data, offset: o); o += 4
        let fileNameLength = readUInt16(data: data, offset: o); o += 2
        let extraFieldLength = readUInt16(data: data, offset: o); o += 2

        let fileName = String(data: data[o..<o + Int(fileNameLength)], encoding: .utf8)
            ?? String(data: data[o..<o + Int(fileNameLength)], encoding: .ascii)
            ?? "unknown"

        return LocalFileHeader(
            signature: signature, versionNeeded: versionNeeded, flags: flags,
            compressionMethod: compressionMethod, lastModTime: lastModTime,
            lastModDate: lastModDate, crc32: crc32, compressedSize: compressedSize,
            uncompressedSize: uncompressedSize, fileNameLength: fileNameLength,
            extraFieldLength: extraFieldLength, fileName: fileName
        )
    }

    private static func readUInt16(data: Data, offset: Int) -> UInt16 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    private static func readUInt32(data: Data, offset: Int) -> UInt32 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }

    private static func inflate(_ data: Data, uncompressedSize: Int) throws -> Data {
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
