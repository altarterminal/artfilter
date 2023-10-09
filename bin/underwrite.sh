#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -b<背景ファイル> [前景ファイル]
	Options : -o<オフセット> -t<透過文字> -w<待ち時間>

	背景に対して前景を上書きする。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-fオプションで前景のファイルを指定する。
	-oオプションで背景のオフセットを指定できる。デフォルトは"0,0"。
	-tオプションで前景中の透過領域を示す文字を指定できる。デフォルトは□。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	USAGE
  exit 1
}

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_r=''
opt_c=''
opt_b=''
opt_o='0,0'
opt_t='□'
opt_w='0'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -b*)                 opt_b=${arg#-b}      ;;
    -o*)                 opt_o=${arg#-o}      ;;
    -t*)                 opt_t=${arg#-t}      ;;
    -w*)                 opt_w=${arg#-w}      ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ]; then
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 11
      fi
      ;;
  esac

  i=$((i + 1))
done

# 標準入力または読み取り可能な通常ファイルであるか判定
if   [ "_$opr" = '_' ] || [ "_$opr" = '_-' ]; then     
  opr=''
elif [ ! -f "$opr"   ] || [ ! -r "$opr"    ]; then
  echo "${0##*/}: \"$opr\" cannot be opened" 1>&2
  exit 21
else
  :
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_r" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_r\" invalid number" 1>&2
  exit 31
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_c" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_c\" invalid number" 1>&2
  exit 41
fi

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_b" = '_' ] || [ "_$opt_b" = '_-' ]; then     
  echo "${0##*/}: forground content cannot be a file" 1>&2
  exit 51
elif [ ! -f "$opt_b"   ] || [ ! -r "$opt_b"    ]; then
  echo "${0##*/}: \"$opt_b\" cannot be opened" 1>&2
  exit 52
else
  :
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_o" | grep -Eq '^-?[0-9]+,-?[0-9]+$'; then
  echo "${0##*/}: \"$opt_o\" invalid number" 1>&2
  exit 61
fi

# 有効な文字列であるか判定
if ! printf '%s\n' "$opt_t" | grep -q '^.$'; then
  echo "${0##*/}: transparent character must be specified" 1>&2
  exit 71
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 81
fi

# パラメータを決定
forfile=$opr
height=$opt_r
width=$opt_c
backfile=$opt_b
offset=$opt_o
tchar=$opt_t
wtime=$opt_w

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  height   = '"${height}"';
  width    = '"${width}"';
  backfile = "'"${backfile}"'";
  offset   = "'"${offset}"'";
  tchar    = "'"${tchar}"'";
  wtime   = '"${wtime}"';

  # オフセットを分離  
  split(offset, oary, ",");
  ox = oary[1];
  oy = oary[2];

  # 背景を入力
  browcnt = 0;
  while (getline bline < backfile) {
    browcnt++;  
    n = split(bline, bary, "");
    for (i=1;i<=n;i++) { bbuf[browcnt,i] = bary[i]; }
  }

  # 背景領域のパラメータを設定
  bheight = browcnt;
  bwidth  = n;

  # パラメータを初期化
  rowidx = 1;

  # 水平方向の表示範囲を確認
  sidx = (ox < 1) ? 1 : (ox+1);
  eidx = (width < (ox+bwidth)) ? width : (ox+bwidth);

  # もし待ち時間があるならば「待機状態」に遷移
  if   (wtime > 0) { state = "s_wait"; wcnt = wtime; }
  else             { state = "s_run";                }
}

######################################################################
# 待機状態
######################################################################

state == "s_wait" {
  # フレームをそのまま出力
  print;
  for (i = 2; i <= height; i++) {
    if   (getline > 0) { print; }
    else               { exit;  }
  }

  # 待ち時間をすべて消費したら「描画状態」に遷移
  wcnt--;
  if (wcnt == 0) { state = "s_run"; next; }
}

######################################################################
# 実行状態
#####################################################################

state == "s_run" {
  # 背景領域の中にあるときは上書き
  if ((oy < rowidx) && (rowidx <= oy+bheight)) {
    for (i = sidx; i <= eidx; i++) {
      if ($i == tchar) { $i = bbuf[rowidx-oy,i-ox]; }
    }
  }

  # 出力
  print;

  # 行インデックスを更新
  rowidx++; if (rowidx > height) { rowidx = 1; }
}
' ${forfile:+"$forfile"}
