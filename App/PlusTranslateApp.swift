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
    @State private var status="Открой настройки и подключи ChatGPT."
    @State private var choices:[ModelChoice]=[]
    @State private var model=""
    @State private var testText="Das Gerät wird mit einem USB-C-Kabel geliefert. Preis: 33,95 €."
    @State private var result=""
    @State private var browser:BrowserLink?
    var body:some View{
        NavigationStack{Form{
            Section("ChatGPT Plus"){
                Text(status)
                Button("Continue with ChatGPT"){run{try await login.signIn();try await reload()}}.disabled(busy)
                Button("Отключить",role:.destructive){run{try await logout()}}.disabled(busy)
                if busy{ProgressView()}
            }
            Section("Модель"){
                Picker("Переводчик",selection:$model){ForEach(choices){Text($0.name).tag($0.id)}}
                    .onChange(of:model){value in do{try SessionStore.defaults().set(value,forKey:"model")}catch{status=error.localizedDescription}}
            }
            Section("Проверка"){
                TextEditor(text:$testText).frame(minHeight:80)
                Button("Перевести на русский"){run{guard let saved=try SessionStore.load() else{throw Failure.message("Войди через ChatGPT.")};let s=try await OpenAI.refresh(saved);guard !model.isEmpty else{throw Failure.message("Выбери модель.")};result=try await OpenAI.translate([testText],model:model,session:s)[0]}}.disabled(busy)
                if !result.isEmpty{Text(result).textSelection(.enabled)}
            }
            Section("Safari"){
                Text("Настройки iPhone → Приложения → Safari → Расширения → Page Helper. Включи расширение и разреши доступ к нужным сайтам.")
                Text("В Safari открой меню расширений → Page Helper → Перевести страницу. По умолчанию оригинал заменяется; кнопка «Оригинал» возвращает исходный текст.")
            }
            Section("Данные"){
                Text("Запросы идут напрямую в OpenAI через твою подписку. Токены хранятся в защищённой связке ключей телефона. Текст страницы передаётся только после нажатия «Перевести» и не записывается в файл.")
                Text("Прототип: вход, подпись и работа расширения на iPhone ещё требуют проверки.")
            }
        }.navigationTitle("Page Helper").task{do{try await reload()}catch{status=error.localizedDescription}}
        .onChange(of:login.browserURL){url in if let url{browser=BrowserLink(url:url)}else{browser=nil}}
        .sheet(item:$browser){link in BrowserView(url:link.url).ignoresSafeArea()}
        }
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
