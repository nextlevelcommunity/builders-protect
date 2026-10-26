import Foundation

public enum Semver {
    public static func normalized(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("=") { text.removeFirst() }
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        return text
    }

    public static func isExact(_ value: String) -> Bool {
        let text = normalized(value)
        guard !text.isEmpty else { return false }
        let forbidden = CharacterSet(charactersIn: "^~<>=*| ,xX")
        if text.rangeOfCharacter(from: forbidden) != nil { return false }
        if text.hasPrefix("file:") || text.hasPrefix("git") || text.hasPrefix("http") {
            return false
        }
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = parts[0]
        let numbers = core.split(separator: ".")
        guard (1...4).contains(numbers.count) else { return false }
        return numbers.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    public static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = parse(lhs)
        let right = parse(rhs)

        let maxCount = max(left.core.count, right.core.count)
        for index in 0..<maxCount {
            let a = index < left.core.count ? left.core[index] : 0
            let b = index < right.core.count ? right.core[index] : 0
            if a != b { return a < b ? -1 : 1 }
        }

        if left.prerelease.isEmpty && right.prerelease.isEmpty { return 0 }
        if left.prerelease.isEmpty { return 1 }
        if right.prerelease.isEmpty { return -1 }

        let count = max(left.prerelease.count, right.prerelease.count)
        for index in 0..<count {
            guard index < left.prerelease.count else { return -1 }
            guard index < right.prerelease.count else { return 1 }
            let a = left.prerelease[index]
            let b = right.prerelease[index]
            let aNumber = Int(a)
            let bNumber = Int(b)
            if let aNumber, let bNumber {
                if aNumber != bNumber { return aNumber < bNumber ? -1 : 1 }
            } else if aNumber != nil {
                return -1
            } else if bNumber != nil {
                return 1
            } else if a != b {
                return a < b ? -1 : 1
            }
        }

        return 0
    }

    public static func lessThan(_ lhs: String, _ rhs: String) -> Bool {
        compare(lhs, rhs) < 0
    }

    public static func maxVersion(_ values: [String]) -> String? {
        values
            .filter { !$0.isEmpty }
            .max(by: lessThan)
    }

    private static func parse(_ value: String) -> (core: [Int], prerelease: [String]) {
        var text = normalized(value)
        if let plus = text.firstIndex(of: "+") {
            text = String(text[..<plus])
        }
        let pieces = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = pieces[0].split(separator: ".").map { segment in
            Int(segment) ?? 0
        }
        let prerelease = pieces.count > 1
            ? pieces[1].split(separator: ".").map(String.init)
            : []
        return (core, prerelease)
    }
}
