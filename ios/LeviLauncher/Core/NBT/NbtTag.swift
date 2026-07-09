import Foundation

final class NbtTag {
    enum TagType: UInt8 {
        case end = 0
        case byte = 1
        case short = 2
        case int = 3
        case long = 4
        case float = 5
        case double = 6
        case byteArray = 7
        case string = 8
        case list = 9
        case compound = 10
        case intArray = 11
        case longArray = 12
    }

    let type: TagType
    var name: String
    var value: Any?

    init(type: TagType, name: String, value: Any? = nil) {
        self.type = type
        self.name = name
        self.value = value
    }

    var byteValue: UInt8 {
        (value as? NSNumber)?.uint8Value ?? 0
    }

    var shortValue: Int16 {
        (value as? NSNumber)?.int16Value ?? 0
    }

    var intValue: Int32 {
        (value as? NSNumber)?.int32Value ?? 0
    }

    var longValue: Int64 {
        (value as? NSNumber)?.int64Value ?? 0
    }

    var floatValue: Float {
        (value as? NSNumber)?.floatValue ?? 0
    }

    var doubleValue: Double {
        (value as? NSNumber)?.doubleValue ?? 0
    }

    var stringValue: String {
        value as? String ?? ""
    }

    var byteArrayValue: Data {
        value as? Data ?? Data()
    }

    var intArrayValue: [Int32] {
        value as? [Int32] ?? []
    }

    var longArrayValue: [Int64] {
        value as? [Int64] ?? []
    }

    var compoundValue: [String: NbtTag] {
        value as? [String: NbtTag] ?? [:]
    }

    var listValue: [NbtTag] {
        value as? [NbtTag] ?? []
    }

    func tag(_ key: String) -> NbtTag? {
        guard type == .compound else { return nil }
        return compoundValue[key]
    }

    func putTag(_ key: String, _ tag: NbtTag) {
        guard type == .compound else { return }
        if var dict = value as? [String: NbtTag] {
            dict[key] = tag
            value = dict
        }
    }

    var isNumeric: Bool {
        type.rawValue >= TagType.byte.rawValue && type.rawValue <= TagType.double.rawValue
    }

    var isEditable: Bool {
        type != .end && type != .byteArray && type != .intArray && type != .longArray
    }

    static func typeName(_ type: TagType) -> String {
        switch type {
        case .end: return "End"
        case .byte: return "Byte"
        case .short: return "Short"
        case .int: return "Int"
        case .long: return "Long"
        case .float: return "Float"
        case .double: return "Double"
        case .byteArray: return "ByteArray"
        case .string: return "String"
        case .list: return "List"
        case .compound: return "Compound"
        case .intArray: return "IntArray"
        case .longArray: return "LongArray"
        }
    }
}

extension NbtTag: CustomStringConvertible {
    var description: String {
        "NbtTag{type=\(Self.typeName(type)), name='\(name)', value=\(formattedValue)}"
    }

    private var formattedValue: String {
        switch type {
        case .compound: return "{\(compoundValue.count) entries}"
        case .list: return "[\(listValue.count) items]"
        case .byteArray: return "byte[\(byteArrayValue.count)]"
        case .intArray: return "int[\(intArrayValue.count)]"
        case .longArray: return "long[\(longArrayValue.count)]"
        default: return value.map { "\($0)" } ?? "null"
        }
    }
}
