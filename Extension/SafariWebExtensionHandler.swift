import SafariServices
import Foundation

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            finish(context, ["error": "Некорректный запрос."]); return
        }
        Task {
            do {
                let action = message["action"] as? String ?? ""
                if action == "status" {
                    let defaults = try SessionStore.defaults()
                    finish(context, ["connected": try SessionStore.load() != nil, "model": defaults.string(forKey: "model") ?? ""]); return
                }
                if ["streamStart", "streamPoll", "streamCancel"].contains(action) {
                    guard let id = message["id"] as? String, UUID(uuidString: id) != nil else { throw Failure.message("Некорректный запрос перевода.") }
                    let coordinator = SafariStreamCoordinator.shared
                    if action == "streamPoll" { finish(context, await coordinator.snapshot(id)); return }
                    if action == "streamCancel" { await coordinator.cancel(id); finish(context, ["cancelled": true]); return }
                    let segments = try validatedSegments(message)
                    try await coordinator.begin(id)
                    let worker = Task<[String], Error> {
                        guard let saved = try SessionStore.load() else { throw Failure.message("Открой Page Helper и войди через ChatGPT.") }
                        let session = try await OpenAI.refresh(saved), defaults = try SessionStore.defaults()
                        let model = defaults.string(forKey: "model") ?? ""
                        guard !model.isEmpty else { throw Failure.message("Выбери модель в Page Helper.") }
                        return try await OpenAI.translate(segments, model: model, session: session, plainText: true) { output in
                            try await coordinator.update(id, output: output)
                        }
                    }
                    await coordinator.attach(id, task: worker)
                    do {
                        let translations = try await worker.value
                        await coordinator.finish(id)
                        finish(context, ["translations": translations])
                    } catch {
                        await coordinator.finish(id)
                        throw error
                    }
                    return
                }
                guard action == "translate" else { throw Failure.message("Некорректный запрос перевода.") }
                let segments = try validatedSegments(message)
                guard let saved = try SessionStore.load() else { throw Failure.message("Открой Page Helper и войди через ChatGPT.") }
                let session = try await OpenAI.refresh(saved), defaults = try SessionStore.defaults()
                let model = defaults.string(forKey: "model") ?? ""
                guard !model.isEmpty else { throw Failure.message("Выбери модель в Page Helper.") }
                finish(context, ["translations": try await OpenAI.translate(segments, model: model, session: session)])
            } catch { finish(context, ["error": error.localizedDescription]) }
        }
    }
    private func validatedSegments(_ message: [String: Any]) throws -> [String] {
        guard let segments = message["segments"] as? [String], !segments.isEmpty, segments.count <= 30,
              segments.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 20_000 }),
              segments.reduce(0, { $0 + $1.utf8.count }) <= 100_000 else {
            throw Failure.message("Некорректный блок перевода.")
        }
        return segments
    }
    private func finish(_ context: NSExtensionContext, _ value: [String: Any]) {
        let response = NSExtensionItem(); response.userInfo = [SFExtensionMessageKey: value]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
