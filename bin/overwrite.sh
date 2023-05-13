#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -f<前景ファイル> [背景ファイル]
	Options : -o<オフセット> -t<透過文字>

	背景に対して前景を上書きする。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-fオプションで前景のファイルを指定する。
	-oオプションで前景のオフセットを指定できる。デフォルトは"0,0"。
	-tオプションで前景中の透過領域を示す文字を指定できる。デフォルトは□。
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
opt_f=''
opt_o='0,0'
opt_t='□'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -f*)                 opt_f=${arg#-f}      ;;
    -o*)                 opt_o=${arg#-o}      ;;
    -t*)                 opt_t=${arg#-t}      ;;
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
if   [ "_$opt_f" = '_' ] || [ "_$opt_f" = '_-' ]; then     
  echo "${0##*/}: forground content cannot be a file" 1>&2
  exit 51
elif [ ! -f "$opt_f"   ] || [ ! -r "$opt_f"    ]; then
  echo "${0##*/}: \"$opt_f\" cannot be opened" 1>&2
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

# パラメータを決定
backfile=$opr
height=$opt_r
width=$opt_c
forfile=$opt_f
offset=$opt_o
tchar=$opt_t

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  height  = '"${height}"';
  width   = '"${width}"';
  forfile = "'"${forfile}"'";
  offset  = "'"${offset}"'";
  tchar   = "'"${tchar}"'";

  # オフセットを分離
  split(offset, oary, ",");
  ox = oary[1];
  oy = oary[2];

  # 前景を入力
  frowcnt = 0;
  while (getline fline < forfile) {
    frowcnt++;  
    n = split(fline, fary, "");
    for (i=1;i<=n;i++) { fbuf[frowcnt,i] = fary[i]; }
  }

  # 前景領域のパラメータを設定
  fheight = frowcnt;
  fwidth  = n;

  # パラメータを初期化
  rowidx = 1;

  # 水平方向の表示範囲を確認
  sidx = (ox < 1) ? 1 : (ox+1);
  eidx = (width < (ox+fwidth)) ? width : (ox+fwidth);
}

{
  # 前景領域の中にあるときは上書き
  if ((oy < rowidx) && (rowidx <= oy+fheight)) {
    for (i = sidx; i <= eidx; i++) {
      yidx = rowidx - oy;
      xidx = i - ox;

      if (fbuf[yidx,xidx] != tchar) { $i = fbuf[yidx,xidx]; }
    }
  }

  # 出力
  print;

  # 行インデックスを更新
  rowidx++; if (rowidx > height) { rowidx = 1; }
}
' ${backfile:+"$backfile"}
