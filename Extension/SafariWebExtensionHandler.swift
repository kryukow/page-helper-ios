import SafariServices
import Foundation

final class SafariWebExtensionHandler:NSObject,NSExtensionRequestHandling {
    func beginRequest(with context:NSExtensionContext){
        guard let item=context.inputItems.first as? NSExtensionItem,let message=item.userInfo?[SFExtensionMessageKey] as? [String:Any] else{finish(context,["error":"Некорректный запрос."]);return}
        Task{
            do{
                if message["action"] as? String=="status"{
                    finish(context,["connected":try SessionStore.load() != nil]);return
                }
                guard message["action"] as? String=="translate",let segments=message["segments"] as? [String],segments.count<=30 else{throw Failure.message("Некорректный запрос перевода.")}
                guard let saved=try SessionStore.load() else{throw Failure.message("Открой Plus Translate и войди через ChatGPT.")}
                let session=try await OpenAI.refresh(saved),d=try SessionStore.defaults()
                let model=d.string(forKey:"model") ?? ""
                guard !model.isEmpty else{throw Failure.message("Выбери модель в Plus Translate.")}
                let translated=try await OpenAI.translate(segments,model:model,session:session)
                finish(context,["translations":translated])
            }catch{finish(context,["error":error.localizedDescription])}
        }
    }
    private func finish(_ context:NSExtensionContext,_ value:[String:Any]){
        let response=NSExtensionItem();response.userInfo=[SFExtensionMessageKey:value]
        context.completeRequest(returningItems:[response],completionHandler:nil)
    }
}
