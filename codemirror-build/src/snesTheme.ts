import { EditorView } from "@codemirror/view";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

// SNES Studio dark theme colors (matching SNESTheme.swift)
const colors = {
  bgMain: "#0D0F12",
  bgEditor: "#1A1D23",
  bgPanel: "#13161B",
  border: "#2A2E36",
  textPrimary: "#E8ECF1",
  textSecondary: "#8B92A0",
  textDisabled: "#4A5060",
  success: "#4AFF9B",
  warning: "#FFD04A",
  danger: "#FF4A6A",
  info: "#4A9EFF",
  purple: "#9B6DFF",
  orange: "#FF8A4A",
};

export const snesEditorTheme = EditorView.theme(
  {
    "&": {
      color: colors.textPrimary,
      backgroundColor: colors.bgEditor,
      fontSize: "13px",
      fontFamily: "'SF Mono', 'Menlo', 'Monaco', monospace",
    },
    ".cm-content": {
      caretColor: colors.info,
      lineHeight: "1.6",
    },
    ".cm-cursor, .cm-dropCursor": {
      borderLeftColor: colors.info,
      borderLeftWidth: "2px",
    },
    "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection":
      {
        backgroundColor: colors.info + "30",
      },
    ".cm-panels": {
      backgroundColor: colors.bgPanel,
      color: colors.textPrimary,
    },
    ".cm-panels.cm-panels-top": {
      borderBottom: `1px solid ${colors.border}`,
    },
    ".cm-searchMatch": {
      backgroundColor: colors.warning + "40",
      outline: `1px solid ${colors.warning}60`,
    },
    ".cm-searchMatch.cm-searchMatch-selected": {
      backgroundColor: colors.warning + "60",
    },
    ".cm-activeLine": {
      backgroundColor: colors.textPrimary + "08",
    },
    ".cm-selectionMatch": {
      backgroundColor: colors.info + "20",
    },
    ".cm-matchingBracket, .cm-nonmatchingBracket": {
      backgroundColor: colors.info + "30",
      outline: `1px solid ${colors.info}50`,
    },
    ".cm-gutters": {
      backgroundColor: colors.bgEditor,
      color: colors.textDisabled,
      border: "none",
      paddingRight: "8px",
    },
    ".cm-activeLineGutter": {
      backgroundColor: colors.textPrimary + "08",
      color: colors.textSecondary,
    },
    ".cm-foldPlaceholder": {
      backgroundColor: colors.bgPanel,
      color: colors.textDisabled,
      border: `1px solid ${colors.border}`,
    },
    ".cm-tooltip": {
      backgroundColor: colors.bgPanel,
      border: `1px solid ${colors.border}`,
      color: colors.textPrimary,
    },
    ".cm-tooltip .cm-tooltip-arrow:before": {
      borderTopColor: colors.border,
      borderBottomColor: colors.border,
    },
    ".cm-tooltip .cm-tooltip-arrow:after": {
      borderTopColor: colors.bgPanel,
      borderBottomColor: colors.bgPanel,
    },
    ".cm-tooltip-autocomplete": {
      "& > ul > li[aria-selected]": {
        backgroundColor: colors.info + "30",
      },
    },
  },
  { dark: true }
);

export const snesHighlightStyle = HighlightStyle.define([
  // Opcodes (LDA, STA, JSR...) → blue
  { tag: tags.operatorKeyword, color: colors.info, fontWeight: "bold" },
  // Directives (.segment, .proc...) → purple
  { tag: tags.keyword, color: colors.purple },
  // Labels (Main:, @loop:) → orange
  { tag: tags.labelName, color: colors.orange },
  // Numbers (#$FF, %1010) → yellow
  { tag: tags.number, color: colors.warning },
  // Strings → green
  { tag: tags.string, color: colors.success },
  // Comments (;) → grey
  { tag: tags.comment, color: colors.textDisabled, fontStyle: "italic" },
  // Variables / identifiers → primary text
  { tag: tags.variableName, color: colors.textPrimary },
  // Operators → secondary
  { tag: tags.operator, color: colors.textSecondary },
]);

export const snesTheme = [
  snesEditorTheme,
  syntaxHighlighting(snesHighlightStyle),
];
