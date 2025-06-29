//画像オーバーレイ表示
document.addEventListener("DOMContentLoaded", function() {
	const images = document.querySelectorAll('.post_image');
	const overlay = document.getElementById('overlay');
	const overlayImage = document.getElementById('overlay-image');
  
	images.forEach((image) => {
	  image.addEventListener('click', function() {
		overlayImage.src = this.src;
		overlayImage.onload = function() {
		  overlay.style.display = 'block';
		};
	  });
	});
  
	overlay.addEventListener('click', function(event) {
	  // クリックされた要素がoverlayImageでない場合、オーバーレイを閉じる
	  if (event.target !== overlayImage) {
		overlay.style.display = 'none';
	  }
	});
});
//メニュー切り替え
function toggleDropdown() {
    var content = document.getElementById("dropdown-content");
    if (content.style.display === "block") {
        content.style.display = "none";
    } else {
        content.style.display = "block";
    }
}
// メニュー以外をクリックしたときにメニューを閉じる
document.addEventListener('click', function(event) {
    var dropdown = document.getElementById("dropdown-content");
    var dropbtn = document.querySelector(".dropbtn");
    if (dropdown.style.display === "block" && !dropbtn.contains(event.target) && !dropdown.contains(event.target)) {
        dropdown.style.display = "none";
    }
});

//TL管理用
// ページ読み込み時に実行される関数
document.addEventListener('DOMContentLoaded', () => {
    updateTimelineTimes();  // タイムラインの時間表示を更新
});

// 時差を計算して「何秒前」「何分前」「何時間前」などを返す関数
function timeAgo(unix_timestamp) {
    const now = new Date(); // 現在の日時
    const postDate = new Date(unix_timestamp * 1000); // 投稿日時
    const diffInSeconds = Math.floor((now - postDate) / 1000); // 秒単位の差

    if (diffInSeconds < 60) {
        return `${diffInSeconds}秒`; // 1～59秒前
    } else if (diffInSeconds < 3600) {
        const minutes = Math.floor(diffInSeconds / 60);
        return `${minutes}分`; // 1～59分前
    } else if (diffInSeconds < 86400) {
        const hours = Math.floor(diffInSeconds / 3600);
        return `${hours}時間`; // 1～23時間前
    } else if (diffInSeconds < 2592000) { // 約30日
        const days = Math.floor(diffInSeconds / 86400);
        return `${days}日`; // 1～30日前
    } else {
        const months = Math.floor(diffInSeconds / 2592000);
        return `${months}ヶ月`; // 1か月以上前
    }
}

// タイムラインの各エントリの時間表示を更新する関数
function updateTimelineTimes() {
    // タイムラインエントリをすべて取得
    const entries = document.querySelectorAll('.timeline-entry');

    entries.forEach(entry => {
        const mtime = entry.getAttribute('data-mtime');  // mtimeを取得
        const timeElement = entry.querySelector('.tl_time');  // 時間表示の要素
        const timeAgoText = timeAgo(mtime);  // 経過時間を計算
        timeElement.textContent = timeAgoText;  // 時間表示を更新
    });
}

// 30秒ごとに時間表示を更新する
setInterval(updateTimelineTimes, 30000);

// 選択ファイル取り消し
const fileInput = document.getElementById('fileInput');
const clearBtn   = document.getElementById('clearBtn');

// ファイルが選択されるたびに呼ばれる
fileInput.addEventListener('change', () => {
    if (fileInput.value) {
    clearBtn.style.display = 'inline-block';
    } else {
    clearBtn.style.display = 'none';
    }
});

// 取り消しボタンをクリックしたとき
clearBtn.addEventListener('click', () => {
    // ファイル選択をクリア
    fileInput.value = '';
    // ボタンを隠す
    clearBtn.style.display = 'none';
});
