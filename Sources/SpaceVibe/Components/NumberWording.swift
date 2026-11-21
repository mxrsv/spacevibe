import Foundation

/// Numbers as the new frame shows them (RD-R17): bytes, money, counts, plurals and durations. Pure. The rules are the reference
/// mock's (`src/a-core.js`: `fB`, `money`, `n0`, `pl`, `nC`, `msTxt`), with one change everywhere: the unit is chosen after rounding,
/// so no figure reads `1000 KB`, `1000K` or `10.0 s`. Digits and separators are en_US like the rest of the app's English wording
/// (`LoadoutFormat`), whatever the system locale. A value outside its domain (negative, NaN, infinite) reads as `missing`, never
/// as `NaN` or a made-up zero.
enum NumberWording {
    /// What a figure the app cannot honestly show reads as (the mock's `dayTxt` uses the same dash).
    static let missing = "—"

    private static let locale = Locale(identifier: "en_US")

    // MARK: Bytes

    /// Decimal units, as Finder and the mock count them (1 KB = 1,000 bytes). The largest unit is TB, so a huge size reads
    /// `1,500 TB`, never PB.
    private static let byteUnits: [(name: String, size: Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("KB", 1e3)]

    /// `0 B`, `999 B`, `1 KB`, `999 KB`, `1.00 MB`, `12.5 MB`, `1.02 GB`, `2.43 TB`. Two decimals under 10, one under 100, none
    /// above, counted on the rounded figure; KB never has decimals. 999,600 bytes is `1.00 MB`, not `1000 KB`.
    static func bytes(_ count: Int64) -> String { bytes(Double(count)) }

    /// The same for a size that is not a whole byte count (an estimate, a share of a total).
    static func bytes(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return missing }
        for (index, unit) in byteUnits.enumerated() where value >= unit.size {
            let scaled = value / unit.size
            var digits = unit.name == "KB" ? 0 : fractionDigits(scaled)
            var shown = rounded(scaled, digits)
            // 9.996 MB rounds to 10.00: show it as 10.0 MB, like any other figure from 10.
            if fractionDigits(shown) < digits {
                digits = fractionDigits(shown)
                shown = rounded(scaled, digits)
            }
            if shown >= 1000, index > 0 { return "\(fixed(1, digits: 2)) \(byteUnits[index - 1].name)" }
            return "\(fixed(shown, digits: digits)) \(unit.name)"
        }
        let whole = value.rounded(.toNearestOrAwayFromZero)
        return whole >= 1000 ? "1 KB" : "\(Int(whole)) B"
    }

    /// Two decimals under 10, one under 100, none from 100: three significant digits at most.
    private static func fractionDigits(_ value: Double) -> Int { value >= 100 ? 0 : value >= 10 ? 1 : 2 }

    // MARK: Money

    /// `$0.00`, `$1.50`, `$12,480.00`: two decimals, thousands separated, the dollar sign in front, as the mock writes an
    /// estimate. The caller adds its own words (`est.`); a cost is never negative, so a negative one reads as `missing`.
    static func money(_ usd: Double) -> String {
        guard usd.isFinite, usd >= 0 else { return missing }
        return "$" + fixed(rounded(usd, 2), digits: 2)
    }

    // MARK: Counts

    /// `0`, `1,204`, `4,830,112`: the full count with thousands separators.
    static func count(_ n: Int) -> String {
        guard n >= 0 else { return missing }
        return n.formatted(.number.locale(locale))
    }

    /// `1 skill`, `2 skills`, `1,204 runs`; `many` for an irregular plural (`plural(2, "match", "matches")`).
    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        guard n >= 0 else { return missing }
        return "\(count(n)) \(n == 1 ? one : many ?? one + "s")"
    }

    /// For narrow cells: the full count below 100,000, then `482K`, `4.8M`, `48M`, `1.2B`. One decimal below 10 of a unit,
    /// none above; 999,999 is `1.0M`, not `1000K`.
    static func compactCount(_ n: Int) -> String {
        guard n >= 0 else { return missing }
        if n < 100_000 { return count(n) }
        let value = Double(n)
        if value < 1e6 {
            let thousands = rounded(value / 1e3, 0)
            if thousands < 1000 { return "\(Int(thousands))K" }
        }
        let units: [(name: String, size: Double)] = [("M", 1e6), ("B", 1e9)]
        for (index, unit) in units.enumerated() {
            let scaled = value / unit.size
            let isLast = index == units.count - 1
            if !isLast, scaled >= 1000 { continue }
            let tenth = rounded(scaled, 1)
            if tenth < 10 { return "\(fixed(tenth, digits: 1))\(unit.name)" }
            let whole = rounded(scaled, 0)
            if whole >= 1000, !isLast { return "\(fixed(1, digits: 1))\(units[index + 1].name)" }
            return "\(fixed(whole, digits: 0))\(unit.name)"
        }
        return count(n)
    }

    // MARK: Durations

    /// `0 ms`, `214 ms`, `1.2 s`, `18 s`, `3,600 s`: milliseconds under a second, then seconds with one decimal below 10.
    /// 999 ms stays `999 ms`; 9,960 ms is `10 s`, not `10.0 s`.
    static func milliseconds(_ ms: Int) -> String {
        guard ms >= 0 else { return missing }
        if ms < 1000 { return "\(count(ms)) ms" }
        let seconds = Double(ms) / 1000
        let tenth = rounded(seconds, 1)
        if tenth < 10 { return "\(fixed(tenth, digits: 1)) s" }
        return "\(fixed(rounded(seconds, 0), digits: 0)) s"
    }

    // MARK: Digits

    /// Half away from zero, as the mock's `toFixed` reads to a person (0.125 → 0.13), not the formatter's half-even default.
    private static func rounded(_ value: Double, _ digits: Int) -> Double {
        let scale = pow(10, Double(digits))
        return (value * scale).rounded(.toNearestOrAwayFromZero) / scale
    }

    private static func fixed(_ value: Double, digits: Int) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(digits)).rounded(rule: .toNearestOrAwayFromZero))
    }
}
