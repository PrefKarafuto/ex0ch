//�摜�I�[�o�[���C�\��
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
	  // �N���b�N���ꂽ�v�f��overlayImage�łȂ��ꍇ�A�I�[�o�[���C�����
	  if (event.target !== overlayImage) {
		overlay.style.display = 'none';
	  }
	});
});
//���j���[�؂�ւ�
function toggleDropdown() {
    var content = document.getElementById("dropdown-content");
    if (content.style.display === "block") {
        content.style.display = "none";
    } else {
        content.style.display = "block";
    }
}
// ���j���[�ȊO���N���b�N�����Ƃ��Ƀ��j���[�����
document.addEventListener('click', function(event) {
    var dropdown = document.getElementById("dropdown-content");
    var dropbtn = document.querySelector(".dropbtn");
    if (dropdown.style.display === "block" && !dropbtn.contains(event.target) && !dropdown.contains(event.target)) {
        dropdown.style.display = "none";
    }
});

//TL�Ǘ��p
// �y�[�W�ǂݍ��ݎ��Ɏ��s�����֐�
document.addEventListener('DOMContentLoaded', () => {
    updateTimelineTimes();  // �^�C�����C���̎��ԕ\�����X�V
});

// �������v�Z���āu���b�O�v�u�����O�v�u�����ԑO�v�Ȃǂ�Ԃ��֐�
function timeAgo(unix_timestamp) {
    const now = new Date(); // ���݂̓���
    const postDate = new Date(unix_timestamp * 1000); // ���e����
    const diffInSeconds = Math.floor((now - postDate) / 1000); // �b�P�ʂ̍�

    if (diffInSeconds < 60) {
        return `${diffInSeconds}�b`; // 1�`59�b�O
    } else if (diffInSeconds < 3600) {
        const minutes = Math.floor(diffInSeconds / 60);
        return `${minutes}��`; // 1�`59���O
    } else if (diffInSeconds < 86400) {
        const hours = Math.floor(diffInSeconds / 3600);
        return `${hours}����`; // 1�`23���ԑO
    } else if (diffInSeconds < 2592000) { // ��30��
        const days = Math.floor(diffInSeconds / 86400);
        return `${days}��`; // 1�`30���O
    } else {
        const months = Math.floor(diffInSeconds / 2592000);
        return `${months}����`; // 1�����ȏ�O
    }
}

// �^�C�����C���̊e�G���g���̎��ԕ\�����X�V����֐�
function updateTimelineTimes() {
    // �^�C�����C���G���g�������ׂĎ擾
    const entries = document.querySelectorAll('.timeline-entry');

    entries.forEach(entry => {
        const mtime = entry.getAttribute('data-mtime');  // mtime���擾
        const timeElement = entry.querySelector('.tl_time');  // ���ԕ\���̗v�f
        const timeAgoText = timeAgo(mtime);  // �o�ߎ��Ԃ��v�Z
        timeElement.textContent = timeAgoText;  // ���ԕ\�����X�V
    });
}

// 30�b���ƂɎ��ԕ\�����X�V����
setInterval(updateTimelineTimes, 30000);

// �I���t�@�C��������
const fileInput = document.getElementById('fileInput');
const clearBtn   = document.getElementById('clearBtn');

// �t�@�C�����I������邽�тɌĂ΂��
fileInput.addEventListener('change', () => {
    if (fileInput.value) {
    clearBtn.style.display = 'inline-block';
    } else {
    clearBtn.style.display = 'none';
    }
});

// �������{�^�����N���b�N�����Ƃ�
clearBtn.addEventListener('click', () => {
    // �t�@�C���I�����N���A
    fileInput.value = '';
    // �{�^�����B��
    clearBtn.style.display = 'none';
});
