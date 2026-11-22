import SwiftUI
import Testing
@testable import SpaceVibe

/// RB-R9: the glance widget's token seam (spec `docs/specs/2026-11-20-spacevibe-redesign.md`, RD34, RD-R3; FE-P9). With the
/// switch off the widget draws exactly the shipped tokens; with it on, the design system's surface and text roles, while the
/// state colours stay its own (GW20, GW22). And a click that falls back to SpaceVibe goes into the frame's route (GW6, LC-R7).
@MainActor
@Suite("Glance tokens and frame route")
struct GlanceTokensTests {
    /// A controller over throwaway preferences; it is never started.
    private func controller(_ surface: LaunchMode.Surface) -> GlanceController {
        GlanceController(preferences: GlancePreferences(defaults: UserDefaults(suiteName: "dev.spacevibe.tests.glance-tokens")!),
                         countdown: LimitsCountdownPreferences(defaults: nil), makeCore: { UnservedCore() }, surface: surface)
    }

    @Test("the shipped set is the v5 tokens the widget drew before the seam, value for value")
    func v5Unchanged() {
        let v5 = GlanceTokens.forSurface(.v5)
        #expect(v5.surface == .v5)
        #expect(v5.ground == Palette.bgPop)
        #expect(v5.edge == Palette.hair2)
        #expect(v5.hoverFill == Palette.sel)
        #expect(v5.wellFill == Palette.hover)
        #expect(v5.markInk == Palette.fg)
        #expect(v5.ringTrack == Palette.fg4)
        #expect(v5.hintInk == Palette.fg3)
        #expect(v5.slotFill == Palette.sel)
        #expect(v5.slotTargetFill == Palette.trackHi)
        #expect(v5.slotTargetEdge == Palette.fg)
        #expect(v5.slotEdge == Palette.fg.opacity(Metrics.Glance.slotEdgeOpacity))
        #expect(v5.ink(.primary) == TextTone.primary.color)
        #expect(v5.ink(.secondary) == TextTone.secondary.color)
        #expect(v5.ink(.tertiary) == TextTone.tertiary.color)
        // The roles the parts drew with before the seam: same font and line box.
        let pairs: [(GlanceTokens.TextRole, SpaceVibeType)] = [(.label, .metaLabel), (.note, .meta), (.small, .small), (.smallLabel, .smallLabel)]
        for (role, old) in pairs {
            #expect(role.v5.size == old.size)
            #expect(role.v5.weight == old.weight)
            #expect(role.v5.lineBox == old.lineBox)
            #expect(role.v5.tracking == old.tracking)
        }
    }

    @Test("the redesign's set takes the design system's surface and text roles")
    func redesign() {
        let set = GlanceTokens.forSurface(.redesign)
        #expect(set.surface == .redesign)
        #expect(set.ground == ColorRole.groupSurface)
        #expect(set.edge == ColorRole.hairline)
        #expect(set.ink(.primary) == ColorRole.ink)
        #expect(set.ink(.secondary) == ColorRole.ink2)
        #expect(set.ink(.tertiary) == ColorRole.ink3)
        #expect(GlanceTokens.TextRole.allCases.allSatisfy { $0.typeRole.face == .text })
    }

    @Test("the state colours stay the widget's own in both sets (GW20, GW22)")
    func stateColoursKept() {
        for set in [GlanceTokens.v5, .redesign] {
            #expect(set.ink(.warn) == TextTone.warn.color)
            #expect(set.ink(.danger) == TextTone.danger.color)
        }
    }

    @Test("the controller draws the shipped set unless told the redesign's surface; tests and shipped builds have no switch")
    func controllerSurface() {
        #expect(LaunchMode.surface(environment: [:]) == .v5)
        #expect(controller(.v5).tokens.surface == .v5)
        #expect(controller(.redesign).tokens.surface == .redesign)
    }

    @Test("with the frame there, the pill opens Limits on its Window and a session click opens Activity on it; without, v5 handles it")
    func routeIntoFrame() {
        let controller = controller(.redesign)
        #expect(!controller.routeIntoFrame(.limits(windowID: "claude:five_hour")))

        let router = FrameRouter(FrameRoute(page: .skills, selection: "skill:x"))
        controller.frame = router
        #expect(controller.routeIntoFrame(.limits(windowID: "claude:five_hour")))
        #expect(router.route == FrameRoute(page: .limits, selection: "claude:five_hour"))
        #expect(controller.routeIntoFrame(.activity(itemID: "codex:s1")))
        #expect(router.route == FrameRoute(page: .activity, selection: "codex:s1"))
    }

    @Test("the countdown window's id is the Limits row id the frame selects (LC-R7)")
    func countdownIDMatchesRow() throws {
        let now = LimitsFrameShotData.now
        let counting = GlanceCountdown.counting(LimitsFrameShotData.normal.limits, now: now, weeklyLead: .standard)
        let window = try #require(counting.first)
        let cards = LimitsFrameShotData.Scenario.normal.cards
        #expect(cards.rowIDs.contains(window.id))
    }

    @Test("every strip the controller lays out or measures draws with the controller's tokens, so a slot outline matches the widget")
    func measuredStripUsesTokens() throws {
        let source = try String(contentsOf: StyleBoundaryTests.appSources.appendingPathComponent("Glance/GlanceController.swift"),
                                encoding: .utf8)
        // The strip views set as a host's root view (`stripHost`, `measureStrip`): each passes `tokens:` in the same statement.
        let statements = source.components(separatedBy: ".rootView = GlanceStripView(").dropFirst()
        #expect(statements.count == 2)
        for statement in statements {
            let call = statement.prefix { $0 != "}" }
            #expect(call.contains("tokens: tokens"), "\(call)")
        }
    }
}

