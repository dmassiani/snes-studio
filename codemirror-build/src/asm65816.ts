import { StreamLanguage, StringStream } from "@codemirror/language";

// 65816/ca65 opcodes
const OPCODES = new Set([
  "adc", "and", "asl", "bcc", "bcs", "beq", "bit", "bmi", "bne", "bpl",
  "bra", "brk", "brl", "bvc", "bvs", "clc", "cld", "cli", "clv", "cmp",
  "cop", "cpx", "cpy", "db", "dec", "dex", "dey", "eor", "inc", "inx",
  "iny", "jml", "jmp", "jsl", "jsr", "lda", "ldx", "ldy", "lsr", "mvn",
  "mvp", "nop", "ora", "pea", "pei", "per", "pha", "phb", "phd", "phk",
  "php", "phx", "phy", "pla", "plb", "pld", "plp", "plx", "ply", "rep",
  "rol", "ror", "rti", "rtl", "rts", "sbc", "sec", "sed", "sei", "sep",
  "sta", "stp", "stx", "sty", "stz", "tax", "tay", "tcd", "tcs", "tdc",
  "trb", "tsb", "tsc", "tsx", "txa", "txs", "txy", "tya", "tyx", "wai",
  "wdm", "xba", "xce",
]);

// ca65 directives
const DIRECTIVES = new Set([
  ".a16", ".a8", ".addr", ".align", ".asciiz", ".assert", ".autoimport",
  ".bank", ".bankbytes", ".bss", ".byte", ".case", ".charmap", ".code",
  ".condes", ".constructor", ".data", ".dbyt", ".debuginfo", ".define",
  ".delmac", ".destructor", ".dword", ".else", ".elseif", ".end",
  ".endenum", ".endif", ".endmac", ".endmacro", ".endproc", ".endrepeat",
  ".endscope", ".endstruct", ".endunion", ".enum", ".error", ".exitmac",
  ".exitmacro", ".export", ".exportzp", ".faraddr", ".feature",
  ".fileopt", ".forceimport", ".global", ".globalzp", ".i16", ".i8",
  ".if", ".ifblank", ".ifdef", ".ifnblank", ".ifndef", ".ifnref",
  ".ifref", ".import", ".importzp", ".include", ".incbin", ".interruptor",
  ".linecont", ".list", ".listbytes", ".literal", ".local", ".localchar",
  ".macpack", ".mac", ".macro", ".org", ".out", ".p02", ".p816",
  ".pagelen", ".pagelength", ".paramcount", ".pc02", ".popseg", ".proc",
  ".pushseg", ".reloc", ".repeat", ".res", ".rodata", ".scope",
  ".segment", ".set", ".setcpu", ".smart", ".struct", ".tag", ".undef",
  ".union", ".warning", ".word", ".zeropage",
]);

function tokenize(stream: StringStream, state: any): string | null {
  // Skip whitespace
  if (stream.eatSpace()) return null;

  // Comments
  if (stream.eat(";")) {
    stream.skipToEnd();
    return "comment";
  }

  // Strings
  if (stream.eat('"')) {
    while (!stream.eol()) {
      if (stream.eat("\\")) { stream.next(); continue; }
      if (stream.eat('"')) break;
      stream.next();
    }
    return "string";
  }

  // Labels — word followed by colon, or starting with @
  if (stream.sol()) {
    const m = stream.match(/^[@.]?[a-zA-Z_]\w*:/);
    if (m) return "labelName";
  }

  // Local labels @xxx (not at start)
  if (stream.eat("@")) {
    stream.eatWhile(/\w/);
    return "labelName";
  }

  // Numbers: hex $FF, binary %1010, decimal
  if (stream.eat("#")) {
    // Immediate prefix
    if (stream.eat("$")) {
      stream.eatWhile(/[0-9a-fA-F]/);
      return "number";
    }
    if (stream.eat("%")) {
      stream.eatWhile(/[01]/);
      return "number";
    }
    stream.eatWhile(/\d/);
    return "number";
  }

  if (stream.eat("$")) {
    stream.eatWhile(/[0-9a-fA-F]/);
    return "number";
  }

  if (stream.eat("%")) {
    stream.eatWhile(/[01]/);
    return "number";
  }

  // Directives
  if (stream.eat(".")) {
    stream.eatWhile(/\w/);
    const word = "." + stream.current().substring(1);
    if (DIRECTIVES.has(word.toLowerCase())) return "keyword";
    return "variableName";
  }

  // Words (opcodes, labels, etc.)
  if (stream.match(/[a-zA-Z_]\w*/)) {
    const word = stream.current();
    if (OPCODES.has(word.toLowerCase())) return "operatorKeyword";
    return "variableName";
  }

  // Digits
  if (stream.match(/\d+/)) return "number";

  // Operators
  if (stream.match(/[+\-*\/&|^~<>=!,()]/)) return "operator";

  stream.next();
  return null;
}

export const asm65816 = StreamLanguage.define({
  token: tokenize,
  languageData: {
    commentTokens: { line: ";" },
  },
});
