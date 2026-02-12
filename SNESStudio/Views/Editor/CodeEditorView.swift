import SwiftUI
import WebKit

struct CodeEditorView: NSViewRepresentable {
    let state: AppState
    let fileID: String

    func makeCoordinator() -> CodeEditorCoordinator {
        CodeEditorCoordinator(state: state, fileID: fileID)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "editorReady")
        contentController.add(context.coordinator, name: "contentChanged")
        contentController.add(context.coordinator, name: "cursorMoved")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        // Load local HTML
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("CodeMirror"),
           let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "CodeMirror")
        {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceURL)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.loadFileIfNeeded(webView: webView)
    }
}
