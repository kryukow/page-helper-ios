import SwiftUI
import TranslationUIProvider
import UIKit

@main final class PageTranslationExtension: TranslationUIProviderExtension {
    var body: some TranslationUIProviderExtensionScene {
        TranslationUIProviderSelectedTextScene { context in
            TranslationSheet(context: context)
        }
    }
}

@MainActor struct TranslationSheet: View {
    @State var context: any TranslationUIProviderContext
    @State private var result = ""
    @State private var error = ""
    @State private var busy = false
    @State private var copied = false
    @State private var attempt = 0
    @State private var firstSeconds: Double?
    @State private var totalSeconds: Double?
    @State private var preparationSeconds = 0.0
    @State private var headersSeconds = 0.0
    @State private var usedModel = ""
    private var source: String { context.inputText.map { String($0.characters) } ?? "" }
    var body: some View {
        VStack(spacing: 14) {
            if busy && result.isEmpty {
                PaperAssemblyLoader().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !result.isEmpty { Text(result).textSelection(.enabled) }
                    if busy { ProgressView("Перевожу…").font(.caption) }
                    if !error.isEmpty { Text(error).foregroundStyle(.red); Button("Повторить") { attempt += 1 } }
                    if let first = firstSeconds, let total = totalSeconds, !busy, error.isEmpty {
                        DisclosureGroup("Время перевода") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Первые слова: \(seconds(first)) с")
                                Text("Полный перевод: \(seconds(total)) с")
                                Text("Подготовка: \(seconds(preparationSeconds)) с")
                                Text("До ответа сервера: \(seconds(headersSeconds)) с")
                                Text(usedModel)
                            }.font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            }
            HStack {
                Button(copied ? "Скопировано" : "Копировать", systemImage: "doc.on.doc") { UIPasteboard.general.string = result; copied = true }.disabled(result.isEmpty || busy)
                Spacer()
                if context.allowsReplacement {
                    Button("Заменить текст") { context.finish(translation: AttributedString(result)) }.disabled(result.isEmpty || busy)
                }
            }
        }.padding(20).tint(Color(red:0.18, green:0.68, blue:0.5))
        .task(id: source + "\u{0}" + String(attempt)) { await translate() }
    }
    private func translate() async {
        result = ""; error = ""; copied = false; busy = true
        firstSeconds = nil; totalSeconds = nil; preparationSeconds = 0; headersSeconds = 0; usedModel = ""
        let started = ProcessInfo.processInfo.systemUptime
        let text = source
        defer { if !Task.isCancelled { busy = false } }
        do {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.message("Нет текста для перевода.") }
            guard text.utf8.count <= 20000 else { throw Failure.message("Выдели текст короче — до 20 тысяч байт.") }
            guard let saved = try SessionStore.load() else { throw Failure.message("Открой Page Helper и войди через ChatGPT.") }
            let session = try await OpenAI.refresh(saved)
            let model = try SessionStore.defaults().string(forKey:"model") ?? ""
            guard !model.isEmpty else { throw Failure.message("Выбери модель в Page Helper.") }
            usedModel = model
            preparationSeconds = ProcessInfo.processInfo.systemUptime - started
            let translated = try await OpenAI.translateText(text, model: model, session: session) { partial in
                guard !Task.isCancelled, source == text else { return }
                if firstSeconds == nil { firstSeconds = ProcessInfo.processInfo.systemUptime - started }
                result = partial
            }
            try Task.checkCancellation()
            guard source == text else { return }
            result = translated.text
            firstSeconds = firstSeconds ?? preparationSeconds + translated.firstTextSeconds
            totalSeconds = ProcessInfo.processInfo.systemUptime - started
            headersSeconds = translated.headersSeconds
        } catch {
            if !Task.isCancelled {
                result = "" // An interrupted stream must not look like a complete translation.
                self.error = error.localizedDescription
            }
        }
    }
    private func seconds(_ value: Double) -> String { String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",") }
}

private struct PaperAssemblyLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    private let mint = Color(red: 0.40, green: 0.88, blue: 0.70)

    var body: some View {
        VStack(spacing: 22) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(started))
                let phase = reduceMotion ? 2.4 : elapsed.truncatingRemainder(dividingBy: 3.6)
                Canvas { graphics, size in
                    let origin = CGPoint(x: (size.width - 66) / 2, y: (size.height - 84) / 2)
                    for row in 0..<14 {
                        for column in 0..<11 {
                            // Leave a folded corner in the assembled sheet.
                            if row < 3 && column > 7 + row { continue }
                            let order = (row * 7 + column * 11) % 37
                            let delay = Double(order) * 0.030
                            let progress = min(1, max(0, (phase - delay) / 0.80))
                            let eased = 1 - pow(1 - progress, 3)
                            let angle = Double(row * 11 + column) * 2.39996
                            let distance = (1 - eased) * (24 + Double(order % 5) * 8)
                            let x = origin.x + CGFloat(column * 6) + CGFloat(cos(angle) * distance)
                            let y = origin.y + CGFloat(row * 6) + CGFloat(sin(angle) * distance)
                            let fade = phase > 2.9 ? max(0, (3.6 - phase) / 0.7) : 1
                            let rect = CGRect(x: x, y: y, width: 5.7, height: 5.7)
                            graphics.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(mint.opacity((0.15 + 0.85 * progress) * fade)))
                        }
                    }
                    let detailOpacity = min(1, max(0, (phase - 1.5) / 0.5)) * (phase > 2.9 ? max(0, (3.6 - phase) / 0.7) : 1)
                    for line in 0..<3 {
                        let width: CGFloat = line == 2 ? 26 : 42
                        let rect = CGRect(x: origin.x + 12, y: origin.y + 36 + CGFloat(line * 12), width: width, height: 3)
                        graphics.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color(red: 0.06, green: 0.30, blue: 0.24).opacity(detailOpacity)))
                    }
                }
            }.frame(width: 150, height: 140).accessibilityHidden(true)
            Text("Перевожу…").font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
