/*!
 * perl-with-pcre.js  (最終版：qr{}, m//, s/// すべて拾える)
 */
(function (mod) {
    if (typeof exports === "object" && typeof module === "object")
      mod(
        require("codemirror"),
        require("codemirror/addon/mode/multiplex"),
        require("codemirror/mode/perl/perl"),
        require("codemirror/mode/pcre/pcre")
      );
    else if (typeof define === "function" && define.amd)
      define([
        "codemirror",
        "codemirror/addon/mode/multiplex",
        "codemirror/mode/perl/perl",
        "codemirror/mode/pcre/pcre"
      ], mod);
    else mod(CodeMirror);
  })(function (CodeMirror) {
    /* ---------- util ---------- */
    const PAIRS = { "(":")","[":"]","{":"}","<":">" };
    const esc   = ch => ch.replace(/[\\^$.*+?()[\]{}|]/g,"\\$&");
  
    /* ---------- open 用正規表現 ----------
       キャプチャ1 = 区切り文字
       キャプチャ2 = s/tr/y 用フラグ
    --------------------------------------- */
    const openRe = new RegExp(
      String.raw`^\s*(?:` +                     // 空白可
        String.raw`(\/)(?![\s*=])`   + `|` +    //   1) /…/
        String.raw`(?:m|qr)\s*([/([{<^'"!~])` + `|` + // 2) m, qr
        String.raw`(?:s|tr|y)\s*([/([{<^'"!~])` +   // 3) s, tr, y
      `)`
    );
  
    /* ---------- multiplex spec (単一) ---------- */
    CodeMirror.defineMode("perl-with-pcre", cfg => {
      const perl = CodeMirror.getMode(cfg, "text/x-perl");
      const pcre = CodeMirror.getMode(cfg, "pcre");   // ← オブジェクト
  
      return CodeMirror.multiplexingMode(perl, {
        open : openRe,
        mode : pcre,                    // ここは**オブジェクト**
        delimStyle : "pcre-delim",
        close : /(?:)/,                 // placeholder, will be replaced
        /* 動的 close 生成 */
        parseDelim(match) {
          /* match[1] || match[2] || match[3] が区切り */
          const delim = match[1] || match[2] || match[3];
          const need2 = !!match[3];     // s/tr/y 系？
          const end   = PAIRS[delim] || delim;
          return new RegExp("^" + esc(end));   // 検索部だけハイライト
        }
      });
    });
  
    CodeMirror.defineMIME("text/x-perl-with-pcre","perl-with-pcre");
  });
  