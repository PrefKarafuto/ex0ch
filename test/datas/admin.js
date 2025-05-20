var postflag = false;

//----------------------------------------------------------------------------------------
//	submit����
//----------------------------------------------------------------------------------------
function DoSubmit(modName, mode, subMode)
{
	// �t�����ݒ�
	document.ADMIN.MODULE.value		= modName;				// ���W���[����
	document.ADMIN.MODE.value		= mode;					// ���C�����[�h
	document.ADMIN.MODE_SUB.value	= subMode;				// �T�u���[�h
	
	postflag = true;
	
	// POST���M
	document.ADMIN.submit();
}

//----------------------------------------------------------------------------------------
//	�I�v�V�����ݒ�
//----------------------------------------------------------------------------------------
function SetOption(key, val)
{
	document.ADMIN.elements[key].value = val;
}

function Submitted()
{
	return postflag;
}

function toggleAll(key)
{
	var elems = document.ADMIN.elements[key];
	if (elems.length == undefined) {
		elems.checked = !elems.checked;
	} else {
		var isall = true;
		for (var i = 0; i < elems.length; i++) {
			isall = isall && elems[i].checked;
		}
		for (var i = 0; i < elems.length; i++) {
			elems[i].checked = !isall;
		}
	}
}

//Lines count
document.addEventListener('DOMContentLoaded', function(){
	const ta   = document.getElementById('dslText');
	const nums = document.getElementById('dslLines');
	function update(){
	  const n = ta.value.split('\n').length || 1;
	  nums.innerHTML = Array.from({length:n},(_,i)=>i+1).join('<br>');
	}
	ta.addEventListener('scroll', ()=> nums.scrollTop = ta.scrollTop);
	ta.addEventListener('input',  update);
	update();
  });