#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -b<背景ファイル> [前景ファイル]
	Options : -o<オフセット> -c<透過部分のマーカー>

	背景に対して前景を上書きする。

	-rオプションでフレームの行数を指定する。
	-fオプションで前景のファイルを指定する。
	-oオプションで背景のオフセットを指定できる。デフォルトは"0,0"。
	-cオプションで前景中の透過領域を示す文字を指定できる。デフォルトは□。
	USAGE
  exit 1
}

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_r=''
opt_b=''
opt_o='0,0'
opt_c='□'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -b*)                 opt_b=${arg#-b}      ;;
    -o*)                 opt_o=${arg#-o}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
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

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_b" = '_' ] || [ "_$opt_b" = '_-' ]; then     
  echo "${0##*/}: forground content cannot be a file" 1>&2
  exit 41
elif [ ! -f "$opt_b"   ] || [ ! -r "$opt_b"    ]; then
  echo "${0##*/}: \"$opt_b\" cannot be opened" 1>&2
  exit 42
else
  :
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_o" | grep -Eq '^-?[0-9]+,-?[0-9]+$'; then
  echo "${0##*/}: \"$opt_o\" invalid number" 1>&2
  exit 51
fi

# 引数を評価
if printf '%s\n' "$opt_c" | grep -q '^$'; then
  echo "${0##*/}: transparent character must be specified" 1>&2
  exit 61
fi

# パラメータを決定
forfile=$opr
height=$opt_r
backfile=$opt_b
offset=$opt_o
tchar=$opt_c

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  height   = '"${height}"';
  backfile = "'"${backfile}"'";
  offset   = "'"${offset}"'";
  tchar    = "'"${tchar}"'";

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
  rowidx = 0;
}

{
  # 現在の上書き対象の行インデックスを計算
  rowidx = (rowidx < height) ? (rowidx+1) : 1;

  # 背景領域の中にあるときは上書き
  if ((oy < rowidx) && (rowidx <= oy+bheight)) {
    sidx = (ox < 1) ? 1 : (ox+1);
    eidx = ((ox+bwidth) < NF) ? (ox+bwidth) : NF;

    for (i = sidx; i <= eidx; i++) {
      if ($i == tchar) {
        $i = bbuf[rowidx-oy,i-ox];
      }
    }
  }

  # 出力
  print;
}
' ${forfile:+"$forfile"}
