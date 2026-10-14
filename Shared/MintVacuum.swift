import SwiftUI
import UIKit
import QuartzCore

// The visible UIKit view owns the clock in both the app and system extension.
struct MintCrystalView: UIViewRepresentable {
    var animated = true
    var ambient = false
    func makeUIView(context: Context) -> MintCrystalCanvas { MintCrystalCanvas() }
    func updateUIView(_ view: MintCrystalCanvas, context: Context) { view.configure(animated: animated, ambient: ambient) }
    static func dismantleUIView(_ view: MintCrystalCanvas, coordinator: ()) { view.stop() }
}

final class MintCrystalCanvas: UIView {
    private var link: CADisplayLink?
    private lazy var relay = CrystalDisplayRelay(owner: self)
    private var observer: NSObjectProtocol?
    private var previous: CFTimeInterval?
    private var elapsed = 0.0
    private var animated = true
    private var ambient = false
    private let mint = UIColor(red: 0.58, green: 0.94, blue: 0.79, alpha: 1)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false; isUserInteractionEnabled = false
        isAccessibilityElement = false; contentMode = .redraw
        observer = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.synchronize() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func configure(animated: Bool, ambient: Bool) {
        let changed = self.animated != animated || self.ambient != ambient
        self.animated = animated; self.ambient = ambient
        if changed { synchronize() }
    }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronize() }
    private func synchronize() {
        stop(); setNeedsDisplay()
        guard window != nil, animated, !UIAccessibility.isReduceMotionEnabled else { return }
        let timer = CADisplayLink(target: relay, selector: #selector(CrystalDisplayRelay.step(_:)))
        timer.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        timer.add(to: .main, forMode: .common); link = timer
    }
    func stop() { link?.invalidate(); link = nil; previous = nil }
    fileprivate func nextFrame(_ timer: CADisplayLink) {
        guard window != nil else { stop(); return }
        if let previous { elapsed += min(0.1, max(0, timer.timestamp - previous)) }
        previous = timer.timestamp; setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0, let c = UIGraphicsGetCurrentContext() else { return }
        let moving = animated && !UIAccessibility.isReduceMotionEnabled
        let time = moving ? elapsed : 1.8
        if ambient {
            let positions: [(CGFloat, CGFloat, CGFloat)] = [(0.16, 0.18, 135), (0.85, 0.48, 165), (0.25, 0.86, 120)]
            for (index, point) in positions.enumerated() {
                c.saveGState(); c.setAlpha(0.18)
                crystal(c, center: CGPoint(x: bounds.width * point.0, y: bounds.height * point.1), size: point.2, time: time * 0.6 + Double(index) * 2, letters: moving)
                c.restoreGState()
            }
        } else {
            crystal(c, center: CGPoint(x: bounds.midX, y: bounds.midY), size: min(200, min(bounds.width, bounds.height)), time: time, letters: moving)
        }
    }
    private func crystal(_ c: CGContext, center: CGPoint, size: CGFloat, time: Double, letters: Bool) {
        c.saveGState(); c.translateBy(x: center.x, y: center.y); c.scaleBy(x: size / 200, y: size / 200)
        let sway = 10 * sin(time * 0.8)
        let vertices = (0..<6).map { index -> (CGPoint, Double) in
            let angle = Double(index) * .pi / 3 + time * 0.4
            return (CGPoint(x: 53 * cos(angle), y: 20 * sin(angle) + sway), sin(angle))
        }
        let top = CGPoint(x: 0, y: -65 + sway / 2), bottom = CGPoint(x: 0, y: 65 + sway / 2)
        var faces: [(CGPoint, CGPoint, CGPoint, Double)] = []
        for index in 0..<6 {
            faces.append((top, vertices[index].0, vertices[(index + 1) % 6].0, vertices[index].1))
            faces.append((bottom, vertices[index].0, vertices[(index + 1) % 6].0, vertices[index].1 - 0.1))
        }
        for face in faces.sorted(by: { $0.3 < $1.3 }) {
            c.beginPath(); c.move(to: face.0); c.addLine(to: face.1); c.addLine(to: face.2); c.closePath()
            c.setFillColor(mint.withAlphaComponent(CGFloat(0.12 + (face.3 + 1) * 0.16)).cgColor)
            c.setStrokeColor(mint.withAlphaComponent(0.55).cgColor); c.setLineWidth(0.85); c.drawPath(using: .fillStroke)
        }
        if letters {
            let glyphs = ["é", "ß", "A", "λ", "ñ"]
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: mint.withAlphaComponent(0.38)]
            for index in 0..<5 {
                let angle = Double(index) * 2.4 + time * 0.3, text = glyphs[index] as NSString
                let extent = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: 76 * cos(angle) - extent.width / 2, y: 57 * sin(angle) - extent.height / 2), withAttributes: attributes)
            }
        }
        c.restoreGState()
    }
    deinit { link?.invalidate(); if let observer { NotificationCenter.default.removeObserver(observer) } }
}
private final class CrystalDisplayRelay: NSObject {
    weak var owner: MintCrystalCanvas?
    init(owner: MintCrystalCanvas) { self.owner = owner }
    @objc func step(_ timer: CADisplayLink) { owner?.nextFrame(timer) }
}

struct AmbientCrystalBackground: View {
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.055, blue: 0.045)
            MintCrystalView(animated: scenePhase == .active, ambient: true)
        }
    }
}
