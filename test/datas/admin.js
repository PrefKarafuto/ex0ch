var postflag = false;

//----------------------------------------------------------------------------------------
//	submit処理
//----------------------------------------------------------------------------------------
function DoSubmit(modName, mode, subMode)
{
	// 付加情報設定
	document.ADMIN.MODULE.value		= modName;				// モジュール名
	document.ADMIN.MODE.value		= mode;					// メインモード
	document.ADMIN.MODE_SUB.value	= subMode;				// サブモード
	
	postflag = true;
	
	// POST送信
	document.ADMIN.submit();
}

//----------------------------------------------------------------------------------------
//	オプション設定
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
