import SwiftUI
import UIKit
import QuartzCore

// System translation is hosted by another app. Drive animation from the visible
// UIKit view's display link, not the main application's SwiftUI scene phase.
struct TranslationVacuumView: UIViewRepresentable {
    func makeUIView(context: Context) -> TranslationVacuumCanvas { TranslationVacuumCanvas() }
    func updateUIView(_ uiView: TranslationVacuumCanvas, context: Context) {}
    static func dismantleUIView(_ uiView: TranslationVacuumCanvas, coordinator: ()) { uiView.stop() }
}

final class TranslationVacuumCanvas: UIView {
    private var link: CADisplayLink?
    private lazy var relay = VacuumDisplayRelay(owner: self)
    private var motionObserver: NSObjectProtocol?
    private var previousTime: CFTimeInterval?
    private var elapsed = 0.0
    private var floorTime = -Double.infinity
    private var floorImage: UIImage?
    private var floorSize = CGSize.zero
    private let mint = UIColor(red: 0.58, green: 0.94, blue: 0.79, alpha: 1)
    private let letters = Array("Aaßüéñλβγδεφאבגדابتث")

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false; isUserInteractionEnabled = false
        isAccessibilityElement = false
        contentMode = .redraw
        motionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.synchronize() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronize() }
    override func layoutSubviews() {
        super.layoutSubviews()
        if floorSize != bounds.size { floorImage = nil; floorTime = -Double.infinity }
        setNeedsDisplay()
    }
    private func synchronize() {
        stop()
        guard window != nil, !UIAccessibility.isReduceMotionEnabled else { setNeedsDisplay(); return }
        let timer = CADisplayLink(target: relay, selector: #selector(VacuumDisplayRelay.step(_:)))
        timer.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        timer.add(to: .main, forMode: .common)
        link = timer
    }
    func stop() { link?.invalidate(); link = nil; previousTime = nil }
    fileprivate func nextFrame(_ timer: CADisplayLink) {
        guard window != nil else { stop(); return }
        if let previousTime { elapsed += min(0.1, max(0, timer.timestamp - previousTime)) }
        previousTime = timer.timestamp
        setNeedsDisplay()
    }
    private func position(_ time: Double, size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(sin(time * 0.8)) * max(0, size.width / 2 - 38),
                y: size.height / 2 + CGFloat(sin(time * 0.57)) * max(0, size.height / 2 - 38) * 0.65)
    }
    private func updateFloor(size: CGSize, time: Double) {
        let format = UIGraphicsImageRendererFormat(); format.opaque = false
        format.scale = min(2, window?.screen.scale ?? 2)
        floorImage = UIGraphicsImageRenderer(size: size, format: format).image { image in
            let columns = max(3, Int(size.width / 45)), rows = max(3, Int(size.height / 55))
            let recent = (0..<24).map { position(max(0, time - Double($0) * 0.25), size: size) }
            for row in 0..<rows {
                for column in 0..<columns {
                    let index = row * columns + column
                    var point = CGPoint(x: (CGFloat(column) + 0.5) * size.width / CGFloat(columns),
                                        y: (CGFloat(row) + 0.5) * size.height / CGFloat(rows))
                    point.x += CGFloat((index * 7) % 15 - 7)
                    if !UIAccessibility.isReduceMotionEnabled,
                       recent.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 27 }) { continue }
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .medium),
                        .foregroundColor: mint.withAlphaComponent(0.23)
                    ]
                    (String(letters[index % letters.count]) as NSString).draw(at: point, withAttributes: attributes)
                }
            }
        }
        floorTime = time; floorSize = size
    }
    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0, let graphics = UIGraphicsGetCurrentContext() else { return }
        let time = UIAccessibility.isReduceMotionEnabled ? 0 : elapsed
        if floorImage == nil || floorSize != bounds.size || time - floorTime >= 0.125 { updateFloor(size: bounds.size, time: time) }
        floorImage?.draw(in: bounds)
        let robot = position(time, size: bounds.size)
        graphics.saveGState(); graphics.translateBy(x: robot.x, y: robot.y)
        graphics.setLineCap(.round); graphics.setStrokeColor(mint.withAlphaComponent(0.8).cgColor)
        graphics.setLineWidth(2)
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: side * 18, y: 18)
            for arm in 0..<3 {
                let angle = Double(arm) * .pi * 2 / 3 + time * 6 * side
                graphics.move(to: center)
                graphics.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle) * 7), y: center.y + CGFloat(sin(angle) * 7)))
            }
            graphics.strokePath()
        }
        graphics.setFillColor(UIColor(red: 0.12, green: 0.28, blue: 0.23, alpha: 1).cgColor)
        graphics.setStrokeColor(mint.cgColor); graphics.setLineWidth(1.5)
        graphics.addEllipse(in: CGRect(x: -25, y: -25, width: 50, height: 50)); graphics.drawPath(using: .fillStroke)
        graphics.setStrokeColor(mint.withAlphaComponent(0.25).cgColor); graphics.setLineWidth(1)
        graphics.strokeEllipse(in: CGRect(x: -20, y: -20, width: 40, height: 40))
        graphics.setFillColor(mint.cgColor); graphics.fillEllipse(in: CGRect(x: -7, y: -7, width: 14, height: 14))
        graphics.addPath(UIBezierPath(roundedRect: CGRect(x: -3, y: -18, width: 6, height: 2), cornerRadius: 1).cgPath); graphics.fillPath()
        graphics.fillEllipse(in: CGRect(x: -15, y: -14, width: 3, height: 3))
        graphics.restoreGState()
    }
    deinit { link?.invalidate(); if let motionObserver { NotificationCenter.default.removeObserver(motionObserver) } }
}

private final class VacuumDisplayRelay: NSObject {
    weak var owner: TranslationVacuumCanvas?
    init(owner: TranslationVacuumCanvas) { self.owner = owner }
    @objc func step(_ timer: CADisplayLink) { owner?.nextFrame(timer) }
}