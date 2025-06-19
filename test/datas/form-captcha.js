// form-captcha.js

document.addEventListener('DOMContentLoaded', () => {
  const btn          = document.getElementById('form-btn');
  const defaultLabel = btn.value;

  // 初期化
  btn.disabled = true;
  btn.value    = 'キャプチャのロード中';

  // 共通コールバック
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

  // Turnstile を explicit render で初期化
  document.querySelectorAll('.cf-turnstile').forEach((el, i) => {
    // explicit モードでレンダー
    if (window.turnstile) {
      turnstile.render(el, {
        sitekey: el.dataset.sitekey,
        'load-callback': onLoad,
        callback: onSuccess,
        'error-callback': onError,
      });
    }
  });

  // reCAPTCHA v2 を explicit render で初期化
  // （HTML API だけの場合は data-* を使う必要がありますが、
  // ここでは JS render を使う例）
  document.querySelectorAll('.g-recaptcha').forEach((el, i) => {
    if (window.grecaptcha) {
      // 要素に id がなければ自動で付与
      if (!el.id) el.id = `js-recaptcha-${i}`;
      grecaptcha.render(el.id, {
        sitekey: el.dataset.sitekey,
        callback: onSuccess,
        'expired-callback': onError,
      });
      // grecaptcha.ready が呼ばれたらロード完了とみなす
      grecaptcha.ready(onLoad);
    }
  });

  // hCaptcha を explicit render で初期化
  document.querySelectorAll('.h-captcha').forEach((el, i) => {
    if (window.hcaptcha) {
      // 要素に id がなければ自動で付与
      if (!el.id) el.id = `js-hcaptcha-${i}`;
      hcaptcha.render(el.id, {
        sitekey: el.dataset.sitekey,
        callback: onSuccess,
        'error-callback': onError,
      });
      // API.js 読み込み後はロード完了とみなす
      onLoad();
    }
  });
});

  