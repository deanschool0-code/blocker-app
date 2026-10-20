import XCTest
@testable import BlockerCore

final class DomainInputTests: XCTestCase {
    func ok(_ raw: String) -> String? { try? DomainInput.normalise(raw).get() }

    func testStripsSchemePathPortAndWWW() {
        XCTAssertEqual(ok("https://www.Example.com/videos?x=1#top"), "example.com")
        XCTAssertEqual(ok("  example.com:8080/path "), "example.com")
        XCTAssertEqual(ok("user:pw@sub.example.co.uk"), "sub.example.co.uk")
        XCTAssertEqual(ok("www.www.example.org."), "example.org")
    }

    func testPunycode() {
        XCTAssertEqual(ok("bücher.de"), "xn--bcher-kva.de")
        XCTAssertEqual(Punycode.encode("münchen"), "mnchen-3ya")
        XCTAssertEqual(Punycode.encode("例え"), "r8jz45g")
    }

    func testRejects() {
        XCTAssertEqual(DomainInput.normalise(""), .failure(.empty))
        XCTAssertEqual(DomainInput.normalise("localhost"), .failure(.notADomain))
        XCTAssertEqual(DomainInput.normalise("192.168.0.1"), .failure(.notADomain))
        XCTAssertEqual(DomainInput.normalise("bad_name.com"), .failure(.notADomain))
        XCTAssertEqual(DomainInput.normalise("-bad.com"), .failure(.notADomain))
        XCTAssertEqual(DomainInput.normalise("https://www.apple.com"), .failure(.protectedSite))
    }

    func testKeywords() {
        XCTAssertEqual(try? KeywordInput.normalise(" NSFW ").get(), "nsfw")
        XCTAssertEqual(KeywordInput.normalise("ab"), .failure(.tooShort))
        XCTAssertEqual(KeywordInput.normalise("a b c"), .failure(.badCharacters))
    }
}

final class RuleTests: XCTestCase {
    func testDomainFilterEscapesDots() {
        XCTAssertEqual(RuleBuilder.domainFilter("example.co.uk"), "^[^:]+://+([^:/]+\\.)?example\\.co\\.uk[/:]")
    }

    func testExtraRulesOrderAllowLast() throws {
        var d = AppData()
        d.rules = [BlockRuleItem(kind: .allow, value: "ok.com"),
                   BlockRuleItem(kind: .domain, value: "bad.com"),
                   BlockRuleItem(kind: .keyword, value: "nsfw")]
        d.prefs.blockImageSearch = true
        let rules = RuleBuilder.extraRulesB(data: d)
        XCTAssertEqual(rules.first?.action.type, "block")
        XCTAssertEqual(rules.last?.action.type, "ignore-previous-rules")
        XCTAssertEqual(rules.count, 1 + 1 + RuleBuilder.imageSearchRules.count + 1)
        XCTAssertEqual(rules[1].trigger.resourceType, ["document"])
        let json = String(decoding: try RuleBuilder.encode(rules), as: UTF8.self)
        XCTAssertTrue(json.contains("\"url-filter\""))
        XCTAssertTrue(json.contains("\"resource-type\":[\"document\"]"))
        XCTAssertEqual(RuleBuilder.extraRulesA(data: d).count, 1)
    }

    func testDeletedRulesIgnored() {
        var d = AppData()
        var r = BlockRuleItem(kind: .domain, value: "bad.com"); r.deleted = true
        d.rules = [r]
        XCTAssertTrue(RuleBuilder.extraRulesB(data: d).isEmpty)
    }

    func testMergeFiles() {
        func m(_ a: String, _ b: String) -> String {
            String(decoding: RuleFiles.merge(base: Data(a.utf8), extra: Data(b.utf8)), as: UTF8.self)
        }
        XCTAssertEqual(m("[1,2]", "[3]"), "[1,2,3]")
        XCTAssertEqual(m("[1,2]\n", " [] "), "[1,2]")
        XCTAssertEqual(m("[]", "[3]"), "[3]")
        XCTAssertEqual(m("", ""), "[]")
    }
}

final class StreakTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Santiago")!; return c
    }()
    func date(_ s: String) -> Date {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: s)!
    }

    func testDaysUseLocalCalendarDays() {
        let m = StreakMath(calendar: cal)
        XCTAssertEqual(m.days(from: date("2026-10-01T23:50:00"), to: date("2026-10-02T00:10:00")), 1)
        XCTAssertEqual(m.days(from: date("2026-10-01T08:00:00"), to: date("2026-10-01T22:00:00")), 0)
        // Chile's DST change (first Sunday of September 2026) must not add or lose a day.
        XCTAssertEqual(m.days(from: date("2026-09-05T12:00:00"), to: date("2026-09-07T12:00:00")), 2)
    }

    func testResetKeepsBest() {
        let m = StreakMath(calendar: cal)
        let s = StreakInfo(start: date("2026-09-01T10:00:00"), now: date("2026-09-01T10:00:00"))
        let r = m.reset(s, at: date("2026-09-11T10:00:00"), now: date("2026-09-11T10:00:00"))
        XCTAssertEqual(r.bestDays, 10)
        XCTAssertEqual(m.currentDays(r, now: date("2026-09-13T10:00:00")), 2)
        XCTAssertEqual(m.bestDays(r, now: date("2026-09-13T10:00:00")), 10)
    }

    func testDayStates() {
        let m = StreakMath(calendar: cal)
        let s = StreakInfo(start: date("2026-10-03T10:00:00"))
        let resets = [ResetItem(at: date("2026-10-05T21:00:00"))]
        let now = date("2026-10-07T12:00:00")
        XCTAssertEqual(m.state(of: date("2026-10-02T12:00:00"), streak: s, resets: resets, now: now), .beforeStart)
        XCTAssertEqual(m.state(of: date("2026-10-04T12:00:00"), streak: s, resets: resets, now: now), .clean)
        XCTAssertEqual(m.state(of: date("2026-10-05T12:00:00"), streak: s, resets: resets, now: now), .reset)
        XCTAssertEqual(m.state(of: date("2026-10-07T08:00:00"), streak: s, resets: resets, now: now), .today)
        XCTAssertEqual(m.state(of: date("2026-10-08T08:00:00"), streak: s, resets: resets, now: now), .future)
    }

    func testMonthGridIsWholeWeeks() {
        let grid = StreakMath(calendar: cal).monthGrid(for: date("2026-10-15T12:00:00"))
        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(grid.compactMap { $0 }.count, 31)
    }
}

final class SyncTests: XCTestCase {
    func testRuleMergeNewestWinsAndTombstonesTravel() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var a = BlockRuleItem(kind: .domain, value: "bad.com", now: t0)
        var b = a; b.deleted = true; b.updatedAt = t0.addingTimeInterval(10)
        let merged = SyncMerge.rules(local: [a], remote: [b])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].deleted)
        // Idempotent.
        XCTAssertEqual(SyncMerge.rules(local: merged, remote: [b]), merged)
        a.updatedAt = t0.addingTimeInterval(20); a.deleted = false
        XCTAssertFalse(SyncMerge.rules(local: merged, remote: [a])[0].deleted)
    }

    func testSameSiteAddedOnBothDevicesKeptOnce() {
        let x = BlockRuleItem(kind: .domain, value: "bad.com", now: Date(timeIntervalSince1970: 1))
        let y = BlockRuleItem(kind: .domain, value: "bad.com", now: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(SyncMerge.rules(local: [x], remote: [y]).filter { !$0.deleted }.count, 1)
    }

    func testStreakMergeAndReconcile() {
        let early = Date(timeIntervalSince1970: 0)
        var local = StreakInfo(start: early.addingTimeInterval(86_400), now: early)
        local.bestDays = 5
        var remote = StreakInfo(start: early, now: early.addingTimeInterval(100))
        remote.bestDays = 3
        let m = SyncMerge.streak(local: local, remote: remote)!
        XCTAssertEqual(m.journeyStart, early)
        XCTAssertEqual(m.bestDays, 5)
        let reset = ResetItem(at: early.addingTimeInterval(10 * 86_400))
        XCTAssertEqual(SyncMerge.reconcile(streak: m, resets: [reset])?.currentStart, reset.at)
    }

    func testEmptyRemoteNeverWipesLocal() {
        var d = AppData()
        d.rules = [BlockRuleItem(kind: .domain, value: "bad.com")]
        d.streak = StreakInfo(start: .now)
        let out = SyncMerge.apply(remote: RemotePayload(), to: d)
        XCTAssertEqual(out.rules, d.rules)
        XCTAssertEqual(out.streak, d.streak)
    }

    func testRoundTripCoding() throws {
        var d = AppData()
        d.rules = [BlockRuleItem(kind: .keyword, value: "nsfw")]
        let data = try SyncCoding.encoder.encode(d.rules)
        let back = try SyncCoding.decoder.decode([BlockRuleItem].self, from: data)
        XCTAssertEqual(back.map(\.value), ["nsfw"])
    }
}
