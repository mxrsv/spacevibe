import Foundation
import Testing
@testable import SpaceVibe

/// RD-R17 numbers, with the break-ui extremes of the reference mock (`src/x-data.js`: `extreme`, `one`, `huge`).
@Suite("Number wording")
struct NumberWordingTests {
    @Test("bytes: decimal units, three significant digits, KB whole, B below a kilobyte")
    func bytes() {
        #expect(NumberWording.bytes(Int64(0)) == "0 B")
        #expect(NumberWording.bytes(Int64(1)) == "1 B")
        #expect(NumberWording.bytes(Int64(999)) == "999 B")
        #expect(NumberWording.bytes(Int64(1000)) == "1 KB")
        #expect(NumberWording.bytes(Int64(1499)) == "1 KB")
        #expect(NumberWording.bytes(Int64(1500)) == "2 KB")
        #expect(NumberWording.bytes(Int64(999_499)) == "999 KB")
        #expect(NumberWording.bytes(Int64(1_000_000)) == "1.00 MB")
        #expect(NumberWording.bytes(Int64(12_480_000)) == "12.5 MB")
        #expect(NumberWording.bytes(Int64(1_020_000_000)) == "1.02 GB")
        #expect(NumberWording.bytes(Int64(345_600_000_000)) == "346 GB")
    }

    @Test("bytes: the unit and the decimals are chosen after rounding, so no 1000 KB and no 10.00 MB")
    func bytesAfterRounding() {
        #expect(NumberWording.bytes(Int64(999_600)) == "1.00 MB")
        #expect(NumberWording.bytes(Int64(999_999)) == "1.00 MB")
        #expect(NumberWording.bytes(Int64(999_600_000)) == "1.00 GB")
        #expect(NumberWording.bytes(Int64(999_600_000_000)) == "1.00 TB")
        #expect(NumberWording.bytes(Int64(9_996_000)) == "10.0 MB")
        #expect(NumberWording.bytes(Int64(99_960_000)) == "100 MB")
        #expect(NumberWording.bytes(999.6) == "1 KB")
    }

    @Test("bytes: TB above 1,000 GB and nothing larger, thousands separated")
    func bytesHuge() {
        #expect(NumberWording.bytes(Int64(2_430_000_000_000)) == "2.43 TB")
        #expect(NumberWording.bytes(Int64(1_360_000_000_000)) == "1.36 TB")
        #expect(NumberWording.bytes(Int64(1_500_000_000_000_000)) == "1,500 TB")
        #expect(NumberWording.bytes(Int64.max) == "9,223,372 TB")
    }

    @Test("bytes: the mock's extreme sizes (statsig 999 B, a 999,600 B cache, a 9.996e8 B skill)")
    func bytesMockExtremes() {
        #expect(NumberWording.bytes(Int64(999)) == "999 B")
        #expect(NumberWording.bytes(Int64(999_600)) == "1.00 MB")
        #expect(NumberWording.bytes(9.996e8) == "1.00 GB")
    }

    @Test("bytes: negative, NaN and infinite sizes read as a dash, never NaN")
    func bytesGuards() {
        #expect(NumberWording.bytes(Int64(-1)) == NumberWording.missing)
        #expect(NumberWording.bytes(Int64.min) == NumberWording.missing)
        #expect(NumberWording.bytes(Double.nan) == NumberWording.missing)
        #expect(NumberWording.bytes(Double.infinity) == NumberWording.missing)
        #expect(NumberWording.bytes(0.4) == "0 B")
    }

    @Test("money: dollar sign, two decimals, thousands separated, half rounds up")
    func money() {
        #expect(NumberWording.money(0) == "$0.00")
        #expect(NumberWording.money(0.0225) == "$0.02")
        #expect(NumberWording.money(0.125) == "$0.13")
        #expect(NumberWording.money(0.31) == "$0.31")
        #expect(NumberWording.money(12_480) == "$12,480.00")
        #expect(NumberWording.money(10_450.75) == "$10,450.75")
        #expect(NumberWording.money(1e9) == "$1,000,000,000.00")
        #expect(NumberWording.money(-1) == NumberWording.missing)
        #expect(NumberWording.money(.nan) == NumberWording.missing)
        #expect(NumberWording.money(.infinity) == NumberWording.missing)
    }

    @Test("count: thousands separators, en_US whatever the system locale")
    func count() {
        #expect(NumberWording.count(0) == "0")
        #expect(NumberWording.count(1) == "1")
        #expect(NumberWording.count(1204) == "1,204")
        #expect(NumberWording.count(4_830_112) == "4,830,112")
        #expect(NumberWording.count(Int.max) == "9,223,372,036,854,775,807")
        #expect(NumberWording.count(-3) == NumberWording.missing)
    }

    @Test("plural: one is singular, zero and many are plural, irregular plurals by argument")
    func plural() {
        #expect(NumberWording.plural(1, "skill") == "1 skill")
        #expect(NumberWording.plural(0, "skill") == "0 skills")
        #expect(NumberWording.plural(2, "skill") == "2 skills")
        #expect(NumberWording.plural(1204, "run") == "1,204 runs")
        #expect(NumberWording.plural(2, "match", "matches") == "2 matches")
        #expect(NumberWording.plural(1, "match", "matches") == "1 match")
        #expect(NumberWording.plural(-1, "skill") == NumberWording.missing)
    }

    @Test("compact count: full below 100,000, then K, M, B with the unit chosen after rounding")
    func compactCount() {
        #expect(NumberWording.compactCount(0) == "0")
        #expect(NumberWording.compactCount(1) == "1")
        #expect(NumberWording.compactCount(12_480) == "12,480")
        #expect(NumberWording.compactCount(99_999) == "99,999")
        #expect(NumberWording.compactCount(100_000) == "100K")
        #expect(NumberWording.compactCount(482_400) == "482K")
        #expect(NumberWording.compactCount(999_499) == "999K")
        #expect(NumberWording.compactCount(999_999) == "1.0M")
        #expect(NumberWording.compactCount(4_830_112) == "4.8M")
        #expect(NumberWording.compactCount(9_960_000) == "10M")
        #expect(NumberWording.compactCount(48_301_120) == "48M")
        #expect(NumberWording.compactCount(999_999_999) == "1.0B")
        #expect(NumberWording.compactCount(1_200_000_000) == "1.2B")
        #expect(NumberWording.compactCount(Int.max) == "9,223,372,037B")
        #expect(NumberWording.compactCount(-5) == NumberWording.missing)
    }

    @Test("milliseconds: ms under a second, then seconds with one decimal below 10")
    func milliseconds() {
        #expect(NumberWording.milliseconds(0) == "0 ms")
        #expect(NumberWording.milliseconds(38) == "38 ms")
        #expect(NumberWording.milliseconds(999) == "999 ms")
        #expect(NumberWording.milliseconds(1000) == "1.0 s")
        #expect(NumberWording.milliseconds(1234) == "1.2 s")
        #expect(NumberWording.milliseconds(9949) == "9.9 s")
        #expect(NumberWording.milliseconds(9960) == "10 s")
        #expect(NumberWording.milliseconds(18_342) == "18 s")
        #expect(NumberWording.milliseconds(3_600_000) == "3,600 s")
        #expect(NumberWording.milliseconds(Int.max).hasSuffix(" s"))
        #expect(NumberWording.milliseconds(-1) == NumberWording.missing)
    }
}
