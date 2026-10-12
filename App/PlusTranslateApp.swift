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
    @State private var testBusy=false
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
                    Button { run { try await login.signIn(); try await reload() } } label: {
                        Text("Подключить ChatGPT").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain).foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.10))
                    .background(mint, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(busy)
                    Button("Отключить", role: .destructive) { run { try await logout() } }
                        .font(.subheadline).disabled(busy)
                    if busy { ProgressView().tint(mint).frame(maxWidth: .infinity) }
                }
                .padding(20).background(card, in: RoundedRectangle(cornerRadius: 24))

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
                .padding(20).background(card, in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("ПРОВЕРКА")
                    if testBusy {
                        VacuumTranslationView().frame(height: 110)
                    }
                    TextEditor(text: $testText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityLabel("Текст для проверки перевода")
                        .disabled(busy)
                    Button { run {
                        testBusy = true
                        result = ""
                        defer { testBusy = false }
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
                .padding(20).background(card, in: RoundedRectangle(cornerRadius: 24))

                Text("Page Helper · \(version)")
                    .font(.caption2).foregroundStyle(mint.opacity(0.45))
                    .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(red: 0.025, green: 0.055, blue: 0.045).ignoresSafeArea())
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
        guard let saved=try SessionStore.load() else{status="Вход не выполнен.";return}
        let s=try await OpenAI.refresh(saved);choices=try await OpenAI.models(s)
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
        try SessionStore.clear();choices=[];model="";result=""
        status=revokeFailed ? "Локальная сессия удалена. Удалённый отзыв не подтверждён; отключи приложение в настройках ChatGPT." : "Отключено."
    }
}

private struct VacuumTranslationView: View {
    @State private var started = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    private let letters = Array("Aa ß ü Ö é 文 字")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { geometry in
                let width = geometry.size.width
                let phase = timeline.date.timeIntervalSince(started).truncatingRemainder(dividingBy: 4.5) / 4.5
                let position = reduceMotion ? width * 0.5 : -35 + (width + 70) * phase
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(mint.opacity(0.035))
                    ForEach(letters.indices, id: \.self) { index in
                        let x = 22 + (width - 44) * CGFloat(index) / CGFloat(letters.count - 1)
                        Text(String(letters[index]))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(mint.opacity(0.6))
                            .opacity(reduceMotion || x > position + 18 ? 1 : 0)
                            .scaleEffect(reduceMotion || x > position + 18 ? 1 : 0.2)
                            .position(x: x, y: 40 + CGFloat(index % 3) * 8)
                    }
                    ZStack {
                        Circle().fill(Color(red: 0.10, green: 0.27, blue: 0.22))
                        Circle().stroke(mint.opacity(0.75), lineWidth: 2)
                        Circle().fill(mint.opacity(0.8)).frame(width: 12, height: 12)
                        Capsule().fill(mint).frame(width: 13, height: 3).offset(x: 13)
                        Circle().fill(mint.opacity(0.25)).frame(width: 7, height: 7).offset(x: -10, y: -11)
                    }
                    .frame(width: 42, height: 42)
                    .shadow(color: mint.opacity(0.15), radius: 8)
                    .position(x: position, y: 48)
                    Text("Перевожу…")
                        .font(.caption).foregroundStyle(mint.opacity(0.65))
                        .position(x: width / 2, y: 91)
                }
                .clipped()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Идёт перевод")
    }
}