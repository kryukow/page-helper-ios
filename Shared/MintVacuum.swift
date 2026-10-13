import SwiftUI

/// Page Helper's shared mint identity: a folded glass page with animated light streams.
struct MintFlowMark: View {
    var size: CGFloat = 58
    var active: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var epoch = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                 paused: reduceMotion || !active || scenePhase != .active)) { timeline in
            Canvas { context, canvasSize in
                let time = reduceMotion || !active ? 0 : timeline.date.timeIntervalSince(epoch)
                Self.paint(context: context, size: canvasSize, time: time, working: active)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The same geometry is used by the app header and its ambient background.
    static func paint(context source: GraphicsContext, size: CGSize, time: Double, working: Bool = true) {
        guard size.width > 0, size.height > 0 else { return }
        var ctx = source
        let s = min(size.width, size.height) / 200
        ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 200 * s) / 2)
        ctx.scaleBy(x: s, y: s)

        let bob = CGFloat(sin(time * 1.35) * 3.2)
        ctx.translateBy(x: 0, y: bob)

        let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
        let bright = Color(red: 0.80, green: 1.0, blue: 0.92)

        // Subtle aura, not a solid cartoon character.
        let glow = Path(ellipseIn: CGRect(x: 43, y: 25, width: 114, height: 148))
        ctx.fill(glow, with: .radialGradient(Gradient(colors: [mint.opacity(0.20), mint.opacity(0)]),
                                             center: CGPoint(x: 100, y: 99), startRadius: 8, endRadius: 75))

        var page = Path()
        page.move(to: CGPoint(x: 64, y: 25))
        page.addLine(to: CGPoint(x: 120, y: 25))
        page.addLine(to: CGPoint(x: 144, y: 49))
        page.addLine(to: CGPoint(x: 144, y: 153))
        page.addQuadCurve(to: CGPoint(x: 132, y: 165), control: CGPoint(x: 144, y: 165))
        page.addLine(to: CGPoint(x: 64, y: 165))
        page.addQuadCurve(to: CGPoint(x: 52, y: 153), control: CGPoint(x: 52, y: 165))
        page.addLine(to: CGPoint(x: 52, y: 37))
        page.addQuadCurve(to: CGPoint(x: 64, y: 25), control: CGPoint(x: 52, y: 25))
        page.closeSubpath()

        ctx.fill(page, with: .linearGradient(
            Gradient(colors: [mint.opacity(0.30), Color(red: 0.06, green: 0.38, blue: 0.29).opacity(0.24), mint.opacity(0.40)]),
            startPoint: CGPoint(x: 52, y: 25), endPoint: CGPoint(x: 150, y: 164)))
        ctx.stroke(page, with: .color(mint.opacity(0.94)), lineWidth: 2)

        // The cut-out corner is the recognizable Page Helper silhouette.
        var fold = Path()
        fold.move(to: CGPoint(x: 120, y: 25))
        fold.addLine(to: CGPoint(x: 120, y: 38))
        fold.addQuadCurve(to: CGPoint(x: 131, y: 49), control: CGPoint(x: 120, y: 49))
        fold.addLine(to: CGPoint(x: 144, y: 49))
        fold.closeSubpath()
        ctx.fill(fold, with: .linearGradient(
            Gradient(colors: [bright.opacity(0.88), mint.opacity(0.30)]),
            startPoint: CGPoint(x: 120, y: 25), endPoint: CGPoint(x: 144, y: 49)))
        ctx.stroke(fold, with: .color(bright.opacity(0.85)), lineWidth: 1.5)

        // Two independent living mint ribbons, clipped to the glass page.
        var ribbons = ctx
        ribbons.clip(to: page)
        let phase = working ? time : 0
        let lift = CGFloat(sin(phase * 2.7) * 8)
        let shift = CGFloat(sin(phase * 1.8 + 1.1) * 6)
        var upper = Path()
        upper.move(to: CGPoint(x: 40, y: 115 + lift))
        upper.addCurve(to: CGPoint(x: 166, y: 87 - lift),
                       control1: CGPoint(x: 79, y: 36 + shift),
                       control2: CGPoint(x: 103, y: 161 - lift))
        ribbons.stroke(upper, with: .color(mint.opacity(0.16)), style: StrokeStyle(lineWidth: 19, lineCap: .round))
        ribbons.stroke(upper, with: .linearGradient(
            Gradient(colors: [.clear, mint, bright, Color(red: 0.11, green: 0.80, blue: 0.62).opacity(0.15)]),
            startPoint: CGPoint(x: 42 + CGFloat(sin(phase) * 14), y: 90),
            endPoint: CGPoint(x: 154, y: 120)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        var lower = Path()
        lower.move(to: CGPoint(x: 37, y: 136 - shift))
        lower.addCurve(to: CGPoint(x: 171, y: 111 + shift),
                       control1: CGPoint(x: 85, y: 56 + lift),
                       control2: CGPoint(x: 113, y: 177 - shift))
        ribbons.stroke(lower, with: .color(bright.opacity(0.60)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        var etched = Path()
        etched.move(to: CGPoint(x: 65, y: 62))
        etched.addLine(to: CGPoint(x: 92, y: 62))
        etched.move(to: CGPoint(x: 65, y: 146))
        etched.addLine(to: CGPoint(x: 103, y: 146))
        ctx.stroke(etched, with: .color(mint.opacity(0.30)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }
}

/// Quiet mint background; the previous vacuum robot has been replaced with Mint Flow.
struct AmbientVacuumFloor: View {
    var floorColor = Color(red: 0.025, green: 0.055, blue: 0.045)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var epoch = Date()
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    private let glyphs = Array("ABCDEFGHJKLMNPQRSTUVXYZabcdefghjkmnpqrstuvxyz0123456789ßüöéàñçαβγδεζηθλμπσφψωאבגדהוזחטיךלמנסעפצקרשתابتثجحخدذرزسشصضطظعغفقكلمنهوي")

    var body: some View {
        ZStack {
            floorColor
            Canvas { context, size in
                let cols = max(4, Int(size.width / 44))
                let rows = max(6, Int(size.height / 52))
                for y in 0..<rows {
                    for x in 0..<cols {
                        let i = y * cols + x
                        let px = (CGFloat(x) + 0.5) * size.width / CGFloat(cols)
                        let py = (CGFloat(y) + 0.5) * size.height / CGFloat(rows)
                        context.draw(
                            Text(String(glyphs[(i * 17 + 11) % glyphs.count]))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(mint.opacity(0.065)),
                            at: CGPoint(x: px, y: py))
                    }
                }
            }
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                     paused: reduceMotion || scenePhase != .active)) { timeline in
                Canvas { context, size in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(epoch)
                    let x = size.width * 0.5 + CGFloat(sin(t * 0.35)) * max(0, size.width * 0.5 - 60)
                    let y = size.height * 0.5 + CGFloat(sin(t * 0.29 + 0.8)) * max(0, size.height * 0.5 - 70)
                    var mark = context
                    mark.opacity = 0.65
                    mark.translateBy(x: x - 55, y: y - 55)
                    MintFlowMark.paint(context: mark, size: CGSize(width: 110, height: 110), time: t)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
