import SwiftUI
import SafariServices

struct BrowserView: UIViewControllerRepresentable {
    let url:URL
    func makeUIViewController(context:Context)->SFSafariViewController{SFSafariViewController(url:url)}
    func updateUIViewController(_ controller:SFSafariViewController,context:Context){}
}
struct BrowserLink:Identifiable {let id=UUID();let url:URL}

@main struct PlusTranslateApp:App {
    var body:some Scene{WindowGroup{SettingsView()}}
}
struct SettingsView:View {
    @StateObject private var login=Login()
    @State private var busy=false
    @State private var connected=false
    @State private var status="Открой настройки и подключи ChatGPT."
    @State private var choices:[ModelChoice]=[]
    @State private var model=""
    @State private var testText="Das Gerät wird mit einem USB-C-Kabel geliefert. Preis: 33,95 €."
    @State private var result=""
    @State private var browser:BrowserLink?
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    private let card = Color(red: 0.07, green: 0.13, blue: 0.11)
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(mint)
                        .frame(width: 58, height: 58)
                        .background(mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    Text("Page Helper")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(mint)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("ПОДКЛЮЧЕНИЕ")
                    Text(status).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if !connected {
                    Button { run { try await login.signIn(); try await reload() } } label: {
                        Text("Подключить ChatGPT").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain).foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.10))
                    .background(mint, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(busy)
                    }
                    if connected {
                    Button("Отключить", role: .destructive) { run { try await logout() } }
                        .font(.subheadline).disabled(busy)
                    }
                    if busy { ProgressView().tint(mint).frame(maxWidth: .infinity) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).background(card.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("МОДЕЛЬ")
                    Picker("Переводчик", selection: $model) {
                        ForEach(choices) { Text($0.name).tag($0.id) }
                    }
                    .tint(mint).disabled(busy || choices.isEmpty)
                    .onChange(of: model) { value in
                        do { try SessionStore.defaults().set(value, forKey: "model") }
                        catch { status = error.localizedDescription }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).background(card.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("ПРОВЕРКА")
                    TextEditor(text: $testText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityLabel("Текст для проверки перевода")
                        .disabled(busy)
                    Button { run {
                        result = ""
                        guard let saved = try SessionStore.load() else { throw Failure.message("Войди через ChatGPT.") }
                        let s = try await OpenAI.refresh(saved)
                        guard !model.isEmpty else { throw Failure.message("Выбери модель.") }
                        result = try await OpenAI.translate([testText], model: model, session: s)[0]
                    } } label: {
                        Text("Перевести на русский").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain).foregroundStyle(mint)
                    .background(mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .disabled(busy)
                    if !result.isEmpty {
                        Divider().overlay(mint.opacity(0.15))
                        Text(result).foregroundStyle(.white.opacity(0.9)).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).background(card.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))

                Text("Page Helper · \(version)")
                    .font(.caption2).foregroundStyle(mint.opacity(0.45))
                    .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
        }
        .background {
            AmbientVacuumFloor()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .tint(mint)
        .preferredColorScheme(.dark)
        .task { do { try await reload() } catch { status = error.localizedDescription } }
        .onChange(of: login.browserURL) { url in
            if let url { browser = BrowserLink(url: url) } else { browser = nil }
        }
        .sheet(item: $browser) { link in BrowserView(url: link.url).ignoresSafeArea() }
    }
    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(mint.opacity(0.65))
    }
    private func run(_ task:@escaping() async throws->Void){busy=true;Task{do{try await task()}catch{status=error.localizedDescription};busy=false}}
    private func reload() async throws {
        guard let saved=try SessionStore.load() else{connected=false;status="Вход не выполнен.";return}
        let s=try await OpenAI.refresh(saved);connected=true;choices=try await OpenAI.models(s)
        guard !choices.isEmpty else{throw Failure.message("Нет доступных моделей.")}
        let wanted=try SessionStore.defaults().string(forKey:"model") ?? "gpt-6-luna"
        model=choices.first(where:{$0.id==wanted})?.id ?? choices[0].id
        status="Подключено: "+s.email
    }
    private func logout() async throws {
        let s=try SessionStore.load();var revokeFailed=false
        if let s,let token=s.refreshToken{do{
            let d=try await OpenAI.json("https://auth.openai.com/.well-known/openid-configuration")
            guard let endpoint=d["revocation_endpoint"] as? String else{throw Failure.message("Нет адреса отзыва.")}
            _=try await OpenAI.json(endpoint,method:"POST",body:OpenAI.form(["token":token,"token_type_hint":"refresh_token","client_id":s.client]),contentType:"application/x-www-form-urlencoded")
        }catch{revokeFailed=true}}
        try SessionStore.clear();connected=false;choices=[];model="";result=""
        status=revokeFailed ? "Локальная сессия удалена. Удалённый отзыв не подтверждён; отключи приложение в настройках ChatGPT." : "Отключено."
    }
}

private struct AmbientVacuumFloor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()
    @State private var pausedAt: Date?
    @State private var visible = false
    @State private var seed = Double.random(in: 1...100_000)
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    // Decorative foreign letters; deliberately excludes Cyrillic and Han characters.
    private let glyphs = Array("ABCDEFGHJKLMNPQRSTUVXYZabcdefghjkmnpqrstuvxyz0123456789ßüöéàñçαβγδεζηθλμπσφψωאבגדהוזחטיךלמנסעפצקרשתابتثجحخدذرزسشصضطظعغفقكلمنهوي")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: reduceMotion || scenePhase != .active || !visible)) { timeline in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(Color(red: 0.025, green: 0.055, blue: 0.045)))
                let elapsed = reduceMotion ? 0 : max(0, (pausedAt ?? timeline.date).timeIntervalSince(started))
                let robot = location(elapsed, size: size)
                let ahead = location(elapsed + 0.15, size: size)
                let angle = atan2(ahead.y - robot.y, ahead.x - robot.x)
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
                var vacuum = context
                vacuum.translateBy(x: robot.x, y: robot.y)
                vacuum.rotate(by: .radians(Double(angle)))
                vacuum.opacity = 0.45
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
        }
        .onAppear { visible = true; resume() }
        .onDisappear { pause(); visible = false }
        .onChange(of: scenePhase) { phase in
            if phase == .active { resume() } else { pause() }
        }
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