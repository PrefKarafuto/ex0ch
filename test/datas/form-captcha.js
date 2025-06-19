// form-captcha.js

document.addEventListener('DOMContentLoaded', () => {
  const btn          = document.getElementById('form-btn');
  const defaultLabel = btn.value;

  // �������F�{�^�������{���[�h������
  btn.disabled = true;
  btn.value    = '�L���v�`���̃��[�h��';

  // �{�^������p�R�[���o�b�N
  function onLoad() {
    btn.disabled = true;
    btn.value    = '�L���v�`�����N���A���Ă�������';
  }
  function onSuccess(token) {
    btn.disabled = false;
    btn.value    = defaultLabel;
  }
  function onError() {
    btn.disabled = true;
    btn.value    = '�L���v�`�����N���A���Ă�������';
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
    // �E�B�W�F�b�g�`���Ƀ��[�h�����Ƃ݂Ȃ�
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
    // API.js �Ǎ���̓��[�h�����Ƃ݂Ȃ�
    onLoad();
  }
});
