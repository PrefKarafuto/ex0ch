// form-captcha.js

document.addEventListener('DOMContentLoaded', () => {
  const btn          = document.getElementById('form-btn');
  const defaultLabel = btn.value;

  // 初期化：ボタン無効＋ロード中文言
  btn.disabled = true;
  btn.value    = 'キャプチャのロード中';

  // ボタン制御用コールバック
  function onLoad() {
    btn.disabled = true;
    btn.value    = 'キャプチャをクリアしてください';
  }
  function onSuccess(token) {
    btn.disabled = false;
    btn.value    = defaultLabel;
  }
  function onError() {
    btn.disabled = true;
    btn.value    = 'キャプチャをクリアしてください';
  }

  // Turnstile explicit render
  if (window.turnstile) {
    document.querySelectorAll('.cf-turnstile').forEach(el => {
      turnstile.render(el, {
        sitekey:        el.dataset.sitekey,
        'load-callback': onLoad,
        callback:        onSuccess,
        'error-callback': onError
      });
    });
  }

  // reCAPTCHA explicit render
  if (window.grecaptcha) {
    document.querySelectorAll('.g-recaptcha').forEach((el, i) => {
      if (!el.id) el.id = `js-recaptcha-${i}`;
      grecaptcha.render(el.id, {
        sitekey:          el.dataset.sitekey,
        callback:         onSuccess,
        'expired-callback': onError
      });
    });
    // ウィジェット描画後にロード完了とみなす
    grecaptcha.ready(onLoad);
  }

  // hCaptcha explicit render
  if (window.hcaptcha) {
    document.querySelectorAll('.h-captcha').forEach((el, i) => {
      if (!el.id) el.id = `js-hcaptcha-${i}`;
      hcaptcha.render(el.id, {
        sitekey:           el.dataset.sitekey,
        callback:          onSuccess,
        'expired-callback': onError,
        'error-callback':   onError
      });
    });
    // API.js 読込後はロード完了とみなす
    onLoad();
  }
});
