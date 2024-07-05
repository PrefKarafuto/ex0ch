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