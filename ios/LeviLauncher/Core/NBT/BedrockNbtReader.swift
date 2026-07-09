import Foundation

struct BedrockNbtReader {
    static func read(from data: Data) throws -> NbtTag? {
        var offset = 0
        return try readTag(from: data, offset: &offset)
    }

    static func read(from url: URL) throws -> NbtTag? {
        let data = try Data(contentsOf: url)
        return try read(from: data)
    }

    private static func readTag(from data: Data, offset: inout Int) throws -> NbtTag? {
        guard offset < data.count else { return nil }

        let typeByte = data[offset]; offset += 1
        guard let type = NbtTag.TagType(rawValue: typeByte) else {
            throw NbtError.unknownTagType(typeByte)
        }

        if type == .end { return NbtTag(type: .end, name: "", value: nil) }

        let nameLen = Int(try readInt16(from: data, offset: &offset))
        guard offset + nameLen <= data.count else { throw NbtError.truncated }
        let name = String(data: data[offset..<offset + nameLen], encoding: .utf8) ?? ""
        offset += nameLen

        let value = try readValue(type: type, from: data, offset: &offset)
        return NbtTag(type: type, name: name, value: value)
    }

    private static func readValue(type: NbtTag.TagType, from data: Data, offset: inout Int) throws -> Any {
        switch type {
        case .byte:
            guard offset < data.count else { throw NbtError.truncated }
            let val = data[offset]; offset += 1
            return val

        case .short:
            return try readInt16(from: data, offset: &offset)

        case .int:
            return try readInt32(from: data, offset: &offset)

        case .long:
            return try readInt64(from: data, offset: &offset)

        case .float:
            guard offset + 4 <= data.count else { throw NbtError.truncated }
            let val = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: UInt32.self)
            }
            offset += 4
            return Float(bitPattern: val)

        case .double:
            guard offset + 8 <= data.count else { throw NbtError.truncated }
            let val = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: UInt64.self)
            }
            offset += 8
            return Double(bitPattern: val)

        case .byteArray:
            let len = Int(try readInt32(from: data, offset: &offset))
            guard offset + len <= data.count else { throw NbtError.truncated }
            let val = data[offset..<offset + len]
            offset += len
            return val

        case .string:
            let len = Int(try readInt16(from: data, offset: &offset))
            guard offset + len <= data.count else { throw NbtError.truncated }
            let str = String(data: data[offset..<offset + len], encoding: .utf8) ?? ""
            offset += len
            return str

        case .list:
            guard offset < data.count else { throw NbtError.truncated }
            let listType = NbtTag.TagType(rawValue: data[offset]) ?? .end
            offset += 1
            let listLen = Int(try readInt32(from: data, offset: &offset))
            var items: [NbtTag] = []
            for _ in 0..<listLen {
                let itemValue = try readValue(type: listType, from: data, offset: &offset)
                items.append(NbtTag(type: listType, name: "", value: itemValue))
            }
            return items

        case .compound:
            var dict: [String: NbtTag] = [:]
            while offset < data.count {
                let nextByte = data[offset]
                if nextByte == 0 { offset += 1; break } // TAG_End
                if let child = try readTag(from: data, offset: &offset) {
                    dict[child.name] = child
                }
            }
            return dict

        case .intArray:
            let len = Int(try readInt32(from: data, offset: &offset))
            guard offset + len * 4 <= data.count else { throw NbtError.truncated }
            var arr: [Int32] = []
            for _ in 0..<len {
                arr.append(try readInt32(from: data, offset: &offset))
            }
            return arr

        case .longArray:
            let len = Int(try readInt32(from: data, offset: &offset))
            guard offset + len * 8 <= data.count else { throw NbtError.truncated }
            var arr: [Int64] = []
            for _ in 0..<len {
                arr.append(try readInt64(from: data, offset: &offset))
            }
            return arr

        case .end:
            return nil
        }
    }

    private static func readInt16(from data: Data, offset: inout Int) throws -> Int16 {
        guard offset + 2 <= data.count else { throw NbtError.truncated }
        let val = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).bigEndian
        }
        offset += 2
        return Int16(bitPattern: val)
    }

    private static func readInt32(from data: Data, offset: inout Int) throws -> Int32 {
        guard offset + 4 <= data.count else { throw NbtError.truncated }
        let val = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
        offset += 4
        return Int32(bitPattern: val)
    }

    private static func readInt64(from data: Data, offset: inout Int) throws -> Int64 {
        guard offset + 8 <= data.count else { throw NbtError.truncated }
        let val = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt64.self).bigEndian
        }
        offset += 8
        return Int64(bitPattern: val)
    }
}

struct BedrockNbtWriter {
    static func write(_ tag: NbtTag) throws -> Data {
        var data = Data()
        try writeTag(tag, to: &data)
        return data
    }

    private static func writeTag(_ tag: NbtTag, to data: inout Data) throws {
        data.append(tag.type.rawValue)
        if tag.type == .end { return }

        let nameData = tag.name.data(using: .utf8) ?? Data()
        var nameLen = UInt16(nameData.count).bigEndian
        withUnsafeBytes(of: &nameLen) { data.append($0) }
        data.append(nameData)

        try writeValue(tag.type, tag.value, to: &data)
    }

    private static func writeValue(_ type: NbtTag.TagType, _ value: Any?, to data: inout Data) throws {
        guard let value = value else { return }

        switch type {
        case .byte:
            var v = (value as? NSNumber)?.uint8Value ?? 0
            data.append(&v, count: 1)

        case .short:
            var v = ((value as? NSNumber)?.int16Value ?? 0).bigEndian
            withUnsafeBytes(of: &v) { data.append($0) }

        case .int:
            var v = ((value as? NSNumber)?.int32Value ?? 0).bigEndian
            withUnsafeBytes(of: &v) { data.append($0) }

        case .long:
            var v = ((value as? NSNumber)?.int64Value ?? 0).bigEndian
            withUnsafeBytes(of: &v) { data.append($0) }

        case .float:
            let float = (value as? NSNumber)?.floatValue ?? 0
            var v = float.bitPattern.bigEndian
            withUnsafeBytes(of: &v) { data.append($0) }

        case .double:
            let double = (value as? NSNumber)?.doubleValue ?? 0
            var v = double.bitPattern.bigEndian
            withUnsafeBytes(of: &v) { data.append($0) }

        case .byteArray:
            let bytes = value as? Data ?? Data()
            var len = Int32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { data.append($0) }
            data.append(bytes)

        case .string:
            let str = value as? String ?? ""
            let strData = str.data(using: .utf8) ?? Data()
            var len = UInt16(strData.count).bigEndian
            withUnsafeBytes(of: &len) { data.append($0) }
            data.append(strData)

        case .list:
            let items = value as? [NbtTag] ?? []
            let itemType: NbtTag.TagType = items.first?.type ?? .end
            data.append(itemType.rawValue)
            var len = Int32(items.count).bigEndian
            withUnsafeBytes(of: &len) { data.append($0) }
            for item in items {
                try writeValue(item.type, item.value, to: &data)
            }

        case .compound:
            let dict = value as? [String: NbtTag] ?? [:]
            for (_, child) in dict.sorted(by: { $0.key < $1.key }) {
                try writeTag(child, to: &data)
            }
            data.append(NbtTag.TagType.end.rawValue)

        case .intArray:
            let arr = value as? [Int32] ?? []
            var len = Int32(arr.count).bigEndian
            withUnsafeBytes(of: &len) { data.append($0) }
            for val in arr {
                var v = val.bigEndian
                withUnsafeBytes(of: &v) { data.append($0) }
            }

        case .longArray:
            let arr = value as? [Int64] ?? []
            var len = Int32(arr.count).bigEndian
            withUnsafeBytes(of: &len) { data.append($0) }
            for val in arr {
                var v = val.bigEndian
                withUnsafeBytes(of: &v) { data.append($0) }
            }

        case .end:
            break
        }
    }
}

enum NbtError: LocalizedError {
    case unknownTagType(UInt8)
    case truncated

    var errorDescription: String? {
        switch self {
        case .unknownTagType(let t): return "Unknown NBT tag type: \(t)"
        case .truncated: return "Truncated NBT data"
        }
    }
}
