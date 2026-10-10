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
    private var source: String { context.inputText.map { String($0.characters) } ?? "" }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Page Helper", systemImage: "doc.text") .font(.headline)
                Spacer()
                Button { context.finish(translation: nil) } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.accessibilityLabel("Закрыть")
            }
            HStack { Text("Определить язык"); Image(systemName: "arrow.right"); Text("Русский") }.font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(source).textSelection(.enabled).foregroundStyle(.secondary)
                    Divider()
                    if busy { ProgressView("Перевожу…") }
                    if !result.isEmpty { Text(result).textSelection(.enabled) }
                    if !error.isEmpty { Text(error).foregroundStyle(.red); Button("Повторить") { attempt += 1 } }
                }.frame(maxWidth: .infinity, alignment: .leading)
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
        let text = source
        defer { if !Task.isCancelled { busy = false } }
        do {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.message("Нет текста для перевода.") }
            guard text.utf8.count <= 20000 else { throw Failure.message("Выдели текст короче — до 20 тысяч байт.") }
            guard let saved = try SessionStore.load() else { throw Failure.message("Открой Page Helper и войди через ChatGPT.") }
            let session = try await OpenAI.refresh(saved)
            let model = try SessionStore.defaults().string(forKey:"model") ?? ""
            guard !model.isEmpty else { throw Failure.message("Выбери модель в Page Helper.") }
            let translated = try await OpenAI.translate([text], model:model, session:session, plainText:true)
            try Task.checkCancellation()
            guard source == text else { return }
            result = translated[0]
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
