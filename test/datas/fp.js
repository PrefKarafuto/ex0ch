/**
 * x86 系（Intel/AMD）かどうかを判定する関数
 *  - Float32Array における NaN の最上位バイトをチェックし、
 *    255 → x86 系（Intel/AMD）、127 → それ以外 の目安となる
 */
function isX86() {
    const f = new Float32Array(1);
    const u8 = new Uint8Array(f.buffer);
    // Infinity - Infinity → NaN を生成
    f[0] = Infinity;
    f[0] = f[0] - f[0];  // NaN
    // u8[3] が 255 の場合、x86 系（Intel/AMD）の浮動小数点実装とみなせる
    // それ以外（127 など）は、ARM や他のアーキテクチャの可能性が高い
    return u8[3] === 255;
  }
  
  /**
   * JavaScript エンジン差分判定用のバイトを返す関数
   *  - パターンA: 直接 0/0 → NaN の最上位バイト
   *  - パターンB: f[0]=0 → f[0]/f[0] → NaN の最上位バイト
   */
  function detectJSEngineNaN() {
    const f = new Float32Array(1);
    const u8 = new Uint8Array(f.buffer);
  
    // パターンA: 直接 0/0
    f[0] = 0 / 0;  // NaN
    const byteA = u8[3];
  
    // パターンB: まず f[0] = 0 してから f[0] / f[0]
    f[0] = 0;
    f[0] = f[0] / f[0];  // NaN
    const byteB = u8[3];
  
    return { byteA, byteB };
  }
  
  /**
   * 同一端末上でブラウザを変えても変わりにくい情報（Stable Features）を収集
   */
  function collectStableFeatures() {
    const screenInfo = {
      screenWidth: window.screen.width,
      screenHeight: window.screen.height,
      availWidth: window.screen.availWidth,
      availHeight: window.screen.availHeight,
      devicePixelRatio: window.devicePixelRatio || 1
    };
  
    // プラットフォーム情報取得（User-Agent Client Hints があれば優先）
    let platform = "unknown";
    if (navigator.userAgentData && typeof navigator.userAgentData.getHighEntropyValues === "function") {
      platform = navigator.userAgentData.platform || "unknown";
    } else if (navigator.platform) {
      platform = navigator.platform;
    }
  
    // CPU の論理コア数
    const hardwareConcurrency = navigator.hardwareConcurrency || 0;
    // 搭載 RAM の概算値 (GB)
    const deviceMemory = navigator.deviceMemory || 0;
  
    // x86 系かどうかの判定バイト
    const x86 = isX86();
  
    return {
      screenInfo,
      platform,
      hardwareConcurrency,
      deviceMemory,
      x86
    };
  }
  
  /**
   * ブラウザ実装や JS エンジンによって変わりやすい情報（Unstable Features）を収集
   */
  function collectUnstableFeatures() {
    const jsEngineNaN = detectJSEngineNaN();
    return {
      jsEngineNaN_byteA: jsEngineNaN.byteA,
      jsEngineNaN_byteB: jsEngineNaN.byteB
    };
  }
  
  /**
   * 上記の Stable / Unstable 情報をまとめて JSON 文字列化する
   */
  function generateFingerprintString() {
    const stable = collectStableFeatures();
    const unstable = collectUnstableFeatures();
    const payload = {
      stableFeatures: stable,
      unstableFeatures: unstable
    };
    return JSON.stringify(payload);
  }
  
  /**
   * ページ読み込み後に hidden input#fp に値をセットする
   */
  window.addEventListener("DOMContentLoaded", () => {
    const fp = generateFingerprintString();
    const hiddenInput = document.getElementById("fp");
    if (hiddenInput) {
      hiddenInput.value = fp;
    }
  });
  