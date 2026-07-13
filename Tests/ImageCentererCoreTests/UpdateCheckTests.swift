import Foundation
import ImageCentererCore
import Testing

struct UpdateCheckTests {
    @Test func versionParsesPlainAndTaggedStrings() {
        #expect(AppVersion("0.1.4")?.components == [0, 1, 4], "Plain version string should parse.")
        #expect(AppVersion("v0.1.4")?.components == [0, 1, 4], "Tag-style v prefix should be stripped.")
        #expect(AppVersion(" 1.2.3\n")?.components == [1, 2, 3], "Surrounding whitespace should be ignored.")
        #expect(AppVersion("7")?.components == [7], "Single-component version should parse.")
    }

    @Test func versionRejectsInvalidStrings() {
        #expect(AppVersion("") == nil, "Empty string should not parse.")
        #expect(AppVersion("v") == nil, "Bare prefix should not parse.")
        #expect(AppVersion("1.2.beta") == nil, "Non-numeric component should not parse.")
        #expect(AppVersion("1..2") == nil, "Empty component should not parse.")
        #expect(AppVersion("1.-2") == nil, "Negative component should not parse.")
    }

    @Test func versionComparisonIsNumericPerComponent() throws {
        let older = try #require(AppVersion("0.1.4"))
        let newer = try #require(AppVersion("0.1.10"))
        let major = try #require(AppVersion("1.0"))

        #expect(older < newer, "Components should compare numerically, not lexically.")
        #expect(newer < major, "Higher major version should win.")
        #expect(!(older < older), "A version should not be less than itself.")
    }

    @Test func versionComparisonTreatsMissingComponentsAsZero() throws {
        let short = try #require(AppVersion("1.0"))
        let long = try #require(AppVersion("1.0.0"))
        let patched = try #require(AppVersion("1.0.1"))

        #expect(short == long, "Trailing zero components should not matter.")
        #expect(short < patched, "Shorter version should compare against implied zeros.")
    }

    @Test func checkIsDueWithoutPreviousCheck() {
        #expect(UpdateCheckSchedule.isCheckDue(lastCheck: nil), "First launch should always check.")
    }

    @Test func checkIsNotDueWithinInterval() {
        let now = Date()
        let sixDaysAgo = now.addingTimeInterval(-6 * 24 * 60 * 60)
        #expect(!UpdateCheckSchedule.isCheckDue(lastCheck: sixDaysAgo, now: now), "A recent check should not repeat.")
    }

    @Test func checkIsDueAfterInterval() {
        let now = Date()
        let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)
        #expect(UpdateCheckSchedule.isCheckDue(lastCheck: eightDaysAgo, now: now), "A stale check should repeat.")
    }
}
