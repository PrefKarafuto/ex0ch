/*!
 * cm.js
 */
(function (mod) {
    if (typeof exports === "object" && typeof module === "object")
      mod(
        require("codemirror"),
        require("codemirror/addon/mode/multiplex"),
        require("codemirror/mode/perl/perl"),
        require("codemirror/mode/pcre/pcre"),
        require("codemirror/addon/fold/foldcode"),
        require("codemirror/addon/fold/foldgutter"),
        require("codemirror/addon/fold/brace-fold"),
        require("codemirror/addon/fold/xml-fold"),
        require("codemirror/addon/fold/comment-fold"),
        require("codemirror/addon/edit/closebrackets"),
        require("codemirror/addon/edit/matchbrackets"),
        require("codemirror/addon/scroll/scrollpastend"),
        require("codemirror/addon/search/match-highlighter"),
        require("codemirror/addon/selection/active-line"),
        require("codemirror/addon/display/placeholder")
      );
    else if (typeof define === "function" && define.amd)
      define([
        "codemirror",
        "codemirror/addon/mode/multiplex",
        "codemirror/mode/perl/perl",
        "codemirror/mode/pcre/pcre",
        "codemirror/addon/fold/foldcode",
        "codemirror/addon/fold/foldgutter",
        "codemirror/addon/fold/brace-fold",
        "codemirror/addon/fold/xml-fold",
        "codemirror/addon/fold/comment-fold",
        "codemirror/addon/edit/closebrackets",
        "codemirror/addon/edit/matchbrackets",
        "codemirror/addon/scroll/scrollpastend",
        "codemirror/addon/search/match-highlighter",
        "codemirror/addon/selection/active-line",
        "codemirror/addon/display/placeholder"
      ], mod);
    else
      // ブラウザ直接読み込み時は CodeMirror が global
      mod(CodeMirror);
  })(function (CodeMirror) {
    /* ---------- util ---------- */
    const PAIRS = { "(":")","[":"]","{":"}","<":">" };
    const esc   = ch => ch.replace(/[\\^$.*+?()[\]{}|]/g,"\\$&");
  
    /* ---------- open 用正規表現 ---------- */
    const openRe = new RegExp(
      String.raw`^\s*(?:` +                     
        String.raw`(\/)(?![\s*=])`   + `|` +    
        String.raw`(?:m|qr)\s*([/([{<^'"!~])` + `|` + 
        String.raw`(?:s|tr|y)\s*([/([{<^'"!~])` +   
      `)`
    );
  
    /* ---------- multiplex spec ---------- */
    CodeMirror.defineMode("perl-with-pcre", cfg => {
      const perl = CodeMirror.getMode(cfg, "text/x-perl");
      const pcre = CodeMirror.getMode(cfg, "pcre");
      return CodeMirror.multiplexingMode(perl, {
        open         : openRe,
        mode         : pcre,
        delimStyle   : "pcre-delim",
        close        : /(?:)/, // placeholder
        parseDelim(match) {
          const delim = match[1]||match[2]||match[3];
          const end   = PAIRS[delim]||delim;
          return new RegExp("^"+esc(end));
        }
      });
    });
    CodeMirror.defineMIME("text/x-perl-with-pcre","perl-with-pcre");
  
    /* ---------- エディタ共通オプション定義 ---------- */
    const fullwidthSpaceOverlay = {
      token: stream => {
        if (stream.match("　")) return "fullwidth-space";
        stream.next();
        return null;
      }
    };
  
    function getBaseOptions() {
      return {
        lineNumbers: true,
        foldGutter: true,
        gutters: ["CodeMirror-linenumbers","CodeMirror-foldgutter"],
        styleActiveLine: true,
        indentUnit: 4,
        indentWithTabs: false,
        lineWrapping: true,
        theme: window.CM_THEME || "default",
        matchBrackets: true,
        autoCloseBrackets: true,
        showTrailingSpace: true,
        highlightSelectionMatches: true,
        scrollbarStyle: "simple",
        scrollPastEnd: true
      };
    }
  
    /* ---------- DOMContentLoaded で各エディタを初期化 ---------- */
    document.addEventListener("DOMContentLoaded", () => {
      // Perl エディタ
      const perlTA = document.getElementById("perl-editor");
      if (perlTA) {
        const opts = Object.assign(
          {},
          getBaseOptions(),
          { mode: "perl-with-pcre" },
          { foldOptions: {
              rangeFinder: (cm, start) => {
                return CodeMirror.fold.brace(cm, start)
                    || CodeMirror.fold.indent(cm, start)
                    || CodeMirror.fold.xml(cm, start)
                    || CodeMirror.fold.comment(cm, start);
              }
            }
          }
        );
        const perlEd = CodeMirror.fromTextArea(perlTA, opts);
        const resizePerl = () => {
          perlEd.setSize("100%", window.innerHeight*0.85 - 200);
          perlEd.refresh();
        };
        resizePerl();
        perlEd.addOverlay(fullwidthSpaceOverlay, {opaque:true});
        window.addEventListener("resize", resizePerl);
      }
  
      // HTML エディタ
      const htmlTA = document.getElementById("html-editor");
      if (htmlTA) {
        const opts = Object.assign(
          {},
          getBaseOptions(),
          {
            mode: "htmlmixed",
            autoCloseTags: true,
            matchTags: { bothTags: true }
          }
        );
        const htmlEd = CodeMirror.fromTextArea(htmlTA, opts);
        htmlEd.setSize("100%", 250);
        htmlEd.addOverlay(fullwidthSpaceOverlay, {opaque:true});
        htmlEd.refresh();
      }
    });
  });
  