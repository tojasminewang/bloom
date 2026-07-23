// JSONValue.swift — a lossless JSON tree. Unknown keys in synced data ride through here
// so the iOS app can never drop fields the web app (or a future version) wrote.
import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    indirect case array([JSONValue])
    indirect case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            // keep integers looking like integers, the way JS wrote them
            if n.truncatingRemainder(dividingBy: 1) == 0, abs(n) < 9_007_199_254_740_992 {
                try c.encode(Int64(n))
            } else {
                try c.encode(n)
            }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

// A CodingKey over arbitrary strings — used to sweep unknown keys into `extra`.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
    init(_ s: String) { self.stringValue = s }
}

extension KeyedDecodingContainer where K == AnyKey {
    /// Collect every key not in `known` as raw JSON.
    func extras(known: Set<String>) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for key in allKeys where !known.contains(key.stringValue) {
            if let v = try? decode(JSONValue.self, forKey: key) { out[key.stringValue] = v }
        }
        return out
    }
}

extension KeyedEncodingContainer where K == AnyKey {
    mutating func encodeExtras(_ extra: [String: JSONValue]) throws {
        for (k, v) in extra { try encode(v, forKey: AnyKey(k)) }
    }
}
