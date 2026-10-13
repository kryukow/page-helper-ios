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
            ZStack {
                if busy {
                    TranslationVacuumView()
                        .opacity(result.isEmpty ? 0.85 : 0.22)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !result.isEmpty { Text(result).textSelection(.enabled) }
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
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
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

