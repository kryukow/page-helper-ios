import SwiftUI

struct AmbientVacuumFloor: View {
    var floorColor = Color(red: 0.025, green: 0.055, blue: 0.045)
    var robotOpacity = 0.45
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()
    @State private var pausedAt: Date?
    @State private var visible = false
    @State private var seed = Double.random(in: 1...100_000)
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    // Decorative foreign letters; deliberately excludes Cyrillic and Han characters.
    private let glyphs = Array("ABCDEFGHJKLMNPQRSTUVXYZabcdefghjkmnpqrstuvxyz0123456789ßüöéàñçαβγδεζηθλμπσφψωאבגדהוזחטיךלמנסעפצקרשתابتثجحخدذرزسشصضطظعغفقكلمنهوي")

    private var paused: Bool { reduceMotion || scenePhase != .active || !visible }
    var body: some View {
        // Independent layers: text work cannot invalidate the 60 Hz robot view.
        ZStack {
            floorColor
            TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: paused)) { timeline in
                Canvas { context, size in
                    drawFloor(context: &context, size: size, date: timeline.date)
                }
            }
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { timeline in
                Canvas { context, size in
                    drawVacuum(context: context, size: size, date: timeline.date)
                }
            }
        }
        .onAppear { visible = true; resume() }
        .onDisappear { pause(); visible = false }
        .onChange(of: scenePhase) { phase in
            if phase == .active { resume() } else { pause() }
        }
    }
    private func drawFloor(context: inout GraphicsContext, size: CGSize, date: Date) {

                let elapsed = reduceMotion ? 0 : max(0, (pausedAt ?? date).timeIntervalSince(started))
                let robot = location(elapsed, size: size)
                // Recent swept floor: letters disappear along the actual route, then gently return.
                let history = (0..<40).map { location(max(0, elapsed - Double($0) * 0.25), size: size) }
                let columns = max(4, Int(size.width / 42))
                let rows = max(6, Int(size.height / 50))
                for row in 0..<rows {
                    for column in 0..<columns {
                        let index = row * columns + column
                        let x = (CGFloat(column) + 0.5) * size.width / CGFloat(columns)
                        let y = (CGFloat(row) + 0.5) * size.height / CGFloat(rows)
                        var point = CGPoint(x: x + CGFloat(noise(index + 300) - 0.5) * 18,
                                            y: y + CGFloat(noise(index + 600) - 0.5) * 20)
                        let distance = hypot(point.x - robot.x, point.y - robot.y)
                        var opacity = 0.07 + noise(index + 900) * 0.09
                        if !reduceMotion {
                            if let swept = history.firstIndex(where: { hypot(point.x - $0.x, point.y - $0.y) < 25 }) {
                                opacity *= min(1, max(0, (Double(swept) * 0.25 - 6) / 4))
                            } else if distance < 52 {
                                let pull = pow(1 - Double(distance) / 52, 2)
                                point.x += (robot.x - point.x) * CGFloat(pull)
                                point.y += (robot.y - point.y) * CGFloat(pull)
                                opacity *= 1 - pull
                            }
                        }
                        let glyph = glyphs[Int(noise(index + 1200) * Double(glyphs.count)) % glyphs.count]
                        context.draw(Text(String(glyph))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(mint.opacity(opacity)), at: point)
                    }
                }
    }
    private func drawVacuum(context: GraphicsContext, size: CGSize, date: Date) {
        let elapsed = reduceMotion ? 0 : max(0, (pausedAt ?? date).timeIntervalSince(started))
        let robot = location(elapsed, size: size)
        let ahead = location(elapsed + 0.05, size: size)
        let angle = atan2(ahead.y - robot.y, ahead.x - robot.x)
                var vacuum = context
                vacuum.translateBy(x: robot.x, y: robot.y)
                vacuum.rotate(by: .radians(Double(angle)))
                vacuum.opacity = robotOpacity
                let shell = Path(ellipseIn: CGRect(x: -23, y: -23, width: 46, height: 46))
                vacuum.fill(shell, with: .color(Color(red: 0.12, green: 0.28, blue: 0.23)))
                vacuum.stroke(shell, with: .color(mint.opacity(0.7)), lineWidth: 1.5)
                vacuum.stroke(Path(ellipseIn: CGRect(x: -18, y: -18, width: 36, height: 36)),
                              with: .color(mint.opacity(0.15)), lineWidth: 1)
                vacuum.fill(Path(ellipseIn: CGRect(x: -7, y: -7, width: 14, height: 14)),
                            with: .color(mint.opacity(0.55)))
                vacuum.fill(Path(roundedRect: CGRect(x: 14, y: -6, width: 3, height: 12), cornerRadius: 1.5),
                            with: .color(mint.opacity(0.75)))
                vacuum.fill(Path(ellipseIn: CGRect(x: -14, y: -13, width: 4, height: 4)),
                            with: .color(mint.opacity(0.4)))
                var brush = Path()
                for arm in 0..<3 {
                    let turn = Double(arm) * .pi * 2 / 3 + elapsed * 2
                    brush.move(to: CGPoint(x: 15, y: 19))
                    brush.addLine(to: CGPoint(x: 15 + cos(turn) * 8, y: 19 + sin(turn) * 8))
                }
                vacuum.stroke(brush, with: .color(mint.opacity(0.5)), lineWidth: 1)
    }
    private func pause() { if pausedAt == nil { pausedAt = Date() } }
    private func resume() {
        if let pause = pausedAt { started = started.addingTimeInterval(Date().timeIntervalSince(pause)); pausedAt = nil }
    }
    private func noise(_ index: Int) -> Double {
        let value = sin(Double(index) * 127.1 + seed * 0.013) * 43758.5453
        return value - floor(value)
    }
    private func waypoint(_ index: Int, size: CGSize) -> CGPoint {
        CGPoint(x: 30 + CGFloat(noise(index * 2 + 10)) * max(0, size.width - 60),
                y: 50 + CGFloat(noise(index * 2 + 11)) * max(0, size.height - 100))
    }
    private func location(_ time: Double, size: CGSize) -> CGPoint {
        let segment = time / 7
        let index = Int(floor(segment))
        let t = CGFloat(segment - floor(segment))
        let a = waypoint(index - 1, size: size)
        let b = waypoint(index, size: size)
        let c = waypoint(index + 1, size: size)
        let d = waypoint(index + 2, size: size)
        func coordinate(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            let t2 = t * t, t3 = t2 * t
            return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        }
        return CGPoint(x: min(max(26, coordinate(a.x, b.x, c.x, d.x)), max(26, size.width - 26)),
                       y: min(max(36, coordinate(a.y, b.y, c.y, d.y)), max(36, size.height - 36)))
    }
}