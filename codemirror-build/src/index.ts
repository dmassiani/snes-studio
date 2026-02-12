import { EditorState } from "@codemirror/state";
import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search";
import { bracketMatching, foldGutter, foldKeymap } from "@codemirror/language";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { asm65816 } from "./asm65816";
import { snesTheme } from "./snesTheme";

let view: EditorView | null = null;

function createEditor(parent: HTMLElement, content: string = "") {
  if (view) {
    view.destroy();
  }

  const state = EditorState.create({
    doc: content,
    extensions: [
      lineNumbers(),
      highlightActiveLineGutter(),
      highlightActiveLine(),
      history(),
      bracketMatching(),
      closeBrackets(),
      highlightSelectionMatches(),
      foldGutter(),
      asm65816,
      ...snesTheme,
      keymap.of([
        ...closeBracketsKeymap,
        ...defaultKeymap,
        ...searchKeymap,
        ...historyKeymap,
        ...foldKeymap,
      ]),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          // Notify Swift
          (window as any).webkit?.messageHandlers?.contentChanged?.postMessage({
            content: update.state.doc.toString(),
          });
        }
        if (update.selectionSet) {
          const cursor = update.state.selection.main;
          const line = update.state.doc.lineAt(cursor.head);
          (window as any).webkit?.messageHandlers?.cursorMoved?.postMessage({
            line: line.number,
            column: cursor.head - line.from + 1,
          });
        }
      }),
    ],
  });

  view = new EditorView({ state, parent });
  return view;
}

// Bridge API exposed to Swift
const editorBridge = {
  init(content: string = "") {
    const container = document.getElementById("editor");
    if (container) {
      createEditor(container, content);
    }
  },

  setContent(content: string) {
    if (view) {
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: content },
      });
    }
  },

  getContent(): string {
    return view?.state.doc.toString() ?? "";
  },

  setCursorPosition(line: number, column: number) {
    if (view) {
      const lineInfo = view.state.doc.line(Math.min(line, view.state.doc.lines));
      const pos = lineInfo.from + Math.min(column - 1, lineInfo.length);
      view.dispatch({ selection: { anchor: pos } });
      view.focus();
    }
  },

  focus() {
    view?.focus();
  },
};

(window as any).editorBridge = editorBridge;

// Auto-init when DOM is ready
document.addEventListener("DOMContentLoaded", () => {
  editorBridge.init();
  // Signal ready to Swift
  (window as any).webkit?.messageHandlers?.editorReady?.postMessage({});
});
