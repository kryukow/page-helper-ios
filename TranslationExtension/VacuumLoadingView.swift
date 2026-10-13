import SwiftUI
import UIKit
import QuartzCore

/// A UIKit display link is required for smooth animation in iOS system translation sheets.
struct TranslationVacuumView: UIViewRepresentable {
    func makeUIView(context: Context) -> TranslationMintFlowCanvas { TranslationMintFlowCanvas() }
    func updateUIView(_ uiView: TranslationMintFlowCanvas, context: Context) {}
    static func dismantleUIView(_ uiView: TranslationMintFlowCanvas, coordinator: ()) { uiView.stop() }
}

final class TranslationMintFlowCanvas: UIView {
    private var link: CADisplayLink?
    private lazy var relay = MintFlowDisplayRelay(owner: self)
    private var motionObserver: NSObjectProtocol?
    private var lastTimestamp: CFTimeInterval?
    private var elapsed = 0.0

    private let mint = UIColor(red: 0.58, green: 0.94, blue: 0.79, alpha: 1)
    private let pale = UIColor(red: 0.88, green: 1, blue: 0.96, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        contentMode = .redraw
        motionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.synchronize() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        synchronize()
    }
    private func synchronize() {
        stop()
        guard window != nil, !UIAccessibility.isReduceMotionEnabled else {
            setNeedsDisplay()
            return
        }
        let timer = CADisplayLink(target: relay, selector: #selector(MintFlowDisplayRelay.step(_:)))
        timer.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        timer.add(to: .main, forMode: .common)
        link = timer
    }
    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
    }
    fileprivate func nextFrame(_ timer: CADisplayLink) {
        guard window != nil else { stop(); return }
        if let lastTimestamp { elapsed += min(0.1, max(0, timer.timestamp - lastTimestamp)) }
        lastTimestamp = timer.timestamp
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0, let ctx = UIGraphicsGetCurrentContext() else { return }
        let t = UIAccessibility.isReduceMotionEnabled ? 0 : elapsed
        let scale = min(1.55, bounds.width / 170, bounds.height / 205)
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX - 100 * scale,
                        y: bounds.midY - 100 * scale + CGFloat(sin(t * 1.35) * 3.2) * scale)
        ctx.scaleBy(x: scale, y: scale)

        // Glass page with the same folded corner and two moving light ribbons as the app.
        let page = UIBezierPath()
        page.move(to: CGPoint(x: 64, y: 25))
        page.addLine(to: CGPoint(x: 120, y: 25))
        page.addLine(to: CGPoint(x: 144, y: 49))
        page.addLine(to: CGPoint(x: 144, y: 153))
        page.addQuadCurve(to: CGPoint(x: 132, y: 165), controlPoint: CGPoint(x: 144, y: 165))
        page.addLine(to: CGPoint(x: 64, y: 165))
        page.addQuadCurve(to: CGPoint(x: 52, y: 153), controlPoint: CGPoint(x: 52, y: 165))
        page.addLine(to: CGPoint(x: 52, y: 37))
        page.addQuadCurve(to: CGPoint(x: 64, y: 25), controlPoint: CGPoint(x: 52, y: 25))
        page.close()

        ctx.addPath(page.cgPath)
        ctx.setFillColor(UIColor(red: 0.10, green: 0.54, blue: 0.43, alpha: 0.23).cgColor)
        ctx.fillPath()
        ctx.addPath(page.cgPath)
        ctx.setStrokeColor(mint.withAlphaComponent(0.94).cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()

        let fold = UIBezierPath()
        fold.move(to: CGPoint(x: 120, y: 25))
        fold.addLine(to: CGPoint(x: 120, y: 38))
        fold.addQuadCurve(to: CGPoint(x: 131, y: 49), controlPoint: CGPoint(x: 120, y: 49))
        fold.addLine(to: CGPoint(x: 144, y: 49))
        fold.close()
        ctx.addPath(fold.cgPath)
        ctx.setFillColor(mint.withAlphaComponent(0.65).cgColor)
        ctx.drawPath(using: .fillStroke)

        ctx.saveGState()
        ctx.addPath(page.cgPath)
        ctx.clip()
        let lift = CGFloat(sin(t * 2.7) * 8)
        let shift = CGFloat(sin(t * 1.8 + 1.1) * 6)
        let upper = UIBezierPath()
        upper.move(to: CGPoint(x: 40, y: 115 + lift))
        upper.addCurve(to: CGPoint(x: 166, y: 87 - lift),
                       controlPoint1: CGPoint(x: 79, y: 36 + shift),
                       controlPoint2: CGPoint(x: 103, y: 161 - lift))
        ctx.addPath(upper.cgPath)
        ctx.setStrokeColor(mint.withAlphaComponent(0.16).cgColor)
        ctx.setLineWidth(19)
        ctx.setLineCap(.round)
        ctx.strokePath()

        ctx.addPath(upper.cgPath)
        ctx.setStrokeColor(mint.withAlphaComponent(0.96).cgColor)
        ctx.setLineWidth(6)
        ctx.strokePath()
        let lower = UIBezierPath()
        lower.move(to: CGPoint(x: 37, y: 136 - shift))
        lower.addCurve(to: CGPoint(x: 171, y: 111 + shift),
                       controlPoint1: CGPoint(x: 85, y: 56 + lift),
                       controlPoint2: CGPoint(x: 113, y: 177 - shift))
        ctx.addPath(lower.cgPath)
        ctx.setStrokeColor(pale.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.8)
        ctx.strokePath()
        ctx.restoreGState()

        ctx.setStrokeColor(mint.withAlphaComponent(0.30).cgColor)
        ctx.setLineWidth(1.8)
        ctx.move(to: CGPoint(x: 65, y: 62))
        ctx.addLine(to: CGPoint(x: 92, y: 62))
        ctx.move(to: CGPoint(x: 65, y: 146))
        ctx.addLine(to: CGPoint(x: 103, y: 146))
        ctx.strokePath()
        ctx.restoreGState()
    }
    deinit {
        link?.invalidate()
        if let motionObserver { NotificationCenter.default.removeObserver(motionObserver) }
    }
}

private final class MintFlowDisplayRelay: NSObject {
    weak var owner: TranslationMintFlowCanvas?
    init(owner: TranslationMintFlowCanvas) { self.owner = owner }
    @objc func step(_ timer: CADisplayLink) { owner?.nextFrame(timer) }
}
