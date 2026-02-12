import WebKit
import Combine

final class CodeEditorCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let state: AppState
    let fileID: String
    private var filePath: URL?
    private var isLoaded = false
    private weak var webViewRef: WKWebView?
    private var cursorSubscription: AnyCancellable?
    private var codeFileSubscription: AnyCancellable?

    init(state: AppState, fileID: String) {
        self.state = state
        self.fileID = fileID
        super.init()

        cursorSubscription = NotificationCenter.default.publisher(for: .setCursorPosition)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self,
                      let info = notif.userInfo,
                      let line = info["line"] as? Int,
                      let col = info["column"] as? Int,
                      let webView = self.webViewRef,
                      self.fileID == self.state.activeSubTabID[.logique] else { return }
                webView.evaluateJavaScript("window.editorBridge.setCursorPosition(\(line), \(col))")
            }

        codeFileSubscription = NotificationCenter.default.publisher(for: .codeFileDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self,
                      let webView = self.webViewRef,
                      self.isLoaded else { return }
                let changedFile = notif.userInfo?["file"] as? String
                if changedFile == nil || changedFile == self.fileID {
                    self.loadFileContent(webView: webView)
                }
            }
    }

    // MARK: - Load file content

    func loadFileIfNeeded(webView: WKWebView) {
        webViewRef = webView
        guard let path = state.fileURL(for: fileID) else { return }
        filePath = path
        guard isLoaded else { return } // Wait until editor is ready

        loadFileContent(webView: webView)
    }

    private func loadFileContent(webView: WKWebView) {
        guard let path = filePath else { return }
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return }
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        webView.evaluateJavaScript("window.editorBridge.setContent(`\(escaped)`)")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "editorReady":
            isLoaded = true
            if let webView = message.webView {
                loadFileContent(webView: webView)
            }

        case "contentChanged":
            guard let dict = message.body as? [String: Any],
                  let content = dict["content"] as? String else { return }
            // Auto-save to disk
            if let path = filePath {
                try? content.write(to: path, atomically: true, encoding: .utf8)
            }

        case "cursorMoved":
            if let dict = message.body as? [String: Any],
               let line = dict["line"] as? Int,
               let col = dict["column"] as? Int {
                state.cursorLine = line
                state.cursorColumn = col
            }

        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Editor JS loaded, will receive editorReady message
    }
}
