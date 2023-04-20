#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -a<アナザーシーンファイル> [ワンシーンファイル]
	Options : -s<起点> -d<増減>

	あるシーンの領域内に別シーンを上書きする。
  ２つのシーンの幅と高さは一致する必要がある。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-aオプションでアナザーシーンファイルを指定する。
	-sオプションで起点座標を指定する。デフォルトは"1,1"。
	-dオプションで増減を指定する。デフォルトは"1,1"。
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
opt_a=''
opt_s='1,1'
opt_d='1,1'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -a*)                 opt_a=${arg#-a}      ;;
    -s*)                 opt_s=${arg#-s}      ;;
    -d*)                 opt_d=${arg#-d}      ;;
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
  exit 31
fi

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_a" = '_' ] || [ "_$opt_a" = '_-' ]; then     
  echo "${0##*/}: forground content cannot be a file" 1>&2
  exit 41
elif [ ! -f "$opt_a"   ] || [ ! -r "$opt_a"    ]; then
  echo "${0##*/}: \"$opt_a\" cannot be opened" 1>&2
  exit 42
else
  :
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_s" | grep -Eq '^-?[0-9]+,-?[0-9]+$'; then
  echo "${0##*/}: \"$opt_s\" invalid number" 1>&2
  exit 51
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_d"                       |
  grep -Eq '^-?[0-9](\.[0-9])?,-?[0-9](\.[0-9])?$'; then
  echo "${0##*/}: \"$opt_d\" invalid number" 1>&2
  exit 51
fi

# パラメータを決定
onefile=$opr
height=$opt_r
width=$opt_c
anofile=$opt_a
sp=$opt_s
delta=$opt_d

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  # パラメータ設定
  height  = '"${height}"';
  width   = '"${width}"';
  anofile = "'"${anofile}"'";
  sp      = "'"${sp}"'";
  delta   = "'"${delta}"'";

  # 増減を分離
  split(sp, sary, ",");
  sx = sary[1];
  sy = sary[2];

  # 増減を分離
  split(delta, dary, ",");
  dx = dary[1];
  dy = dary[2];

  # 別シーンを入力
  rowidx = 0;
  while (getline line < anofile) {
    rowidx++;  
    split(line, ary, "");
    for (i=1;i<=width;i++) { anobuf[rowidx,i] = ary[i]; }
  }

  # パラメータを初期化
  rowidx = 1;

  # 基準座標を初期化
  cacx = sx;
  cacy = sy;
  cx   = int(cacx);
  cy   = int(cacy);
}

{
  if (rowidx == cy) {
    $cx = "★";
  }

  # 出力
  print;

  # 行インデックスを更新
  rowidx++;
  if (rowidx > height) {
    # 行インデックスをリセット
    rowidx = 1;

    # 基準座標を更新
    cacx = cacx + dx;
    cacy = cacy + dy;
    cx = int(cacx);
    cy = int(cacy);
  }
}
' ${onefile:+"$onefile"}
