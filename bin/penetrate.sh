#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -a<別シーンファイル> [シーンファイル]
	Options : -p<パラメータ> -d<増減>

	あるシーンの領域内に別シーンを上書きする。
	２つのシーンの幅と高さは一致する必要がある。

	パラメータは以下の形式で指定する。
	  左上座標を(x,y)、幅をw、高さをhとする矩形 -> "x,y,w,h"

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-aオプションでアナザーシーンファイルを指定する。
	-pオプションで領域のパラメータを指定できる。デフォルトは"1,1,1,1"
	-dオプションで増減を指定できる。デフォルトは"1,1"。
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
opt_p='1,1,1,1'
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
    -p*)                 opt_p=${arg#-p}      ;;
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
  exit 41
fi

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_a" = '_' ] || [ "_$opt_a" = '_-' ]; then     
  echo "${0##*/}: forground content cannot be a file" 1>&2
  exit 51
elif [ ! -f "$opt_a"   ] || [ ! -r "$opt_a"    ]; then
  echo "${0##*/}: \"$opt_a\" cannot be opened" 1>&2
  exit 52
else
  :
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_p"                    |
   grep -Eq '^-?[0-9]+,-?[0-9]+,[0-9]+,[0-9]+$'; then
  echo "${0##*/}: \"$opt_p\" invalid parameter" 1>&2
  exit 61
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_d"                        |
   grep -Eq '^-?[0-9](\.[0-9])?,-?[0-9](\.[0-9])?$'; then
  echo "${0##*/}: \"$opt_d\" invalid number" 1>&2
  exit 71
fi

# パラメータを決定
onefile=$opr
height=$opt_r
width=$opt_c
anofile=$opt_a
param=$opt_p
delta=$opt_d

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  # パラメータ設定
  height  = '"${height}"';
  width   = '"${width}"';
  param   = "'"${param}"'";
  anofile = "'"${anofile}"'";
  delta   = "'"${delta}"'";

  # 領域パラメータを分離
  split(param, pary, ",");
  rx = pary[1];
  ry = pary[2];
  rw = pary[3];
  rh = pary[4];

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

  # 現在の領域の範囲を設定
  xcmin = rx;
  xcmax = rx + rw - 1;
  ycmin = ry;
  ycmax = ry + rh - 1;

  # 整数座標を取得
  xcmini = intcoord(xcmin);
  xcmaxi = intcoord(xcmax);
  ycmini = intcoord(ycmin);
  ycmaxi = intcoord(ycmax);

  # 有効座標を取得
  xcminv = validcoord(xcmini, width);
  xcmaxv = validcoord(xcmaxi, width);
  ycminv = validcoord(ycmini, height);
  ycmaxv = validcoord(ycmaxi, height);

  # フィルタ実行状態に遷移
  state = "s_run";
}

state == "s_run" {
  # 現在の領域の位置を判断
  if (xcmini > width  || xcmaxi < 1 ||
      ycmini > height || ycmaxi < 1 ){
    # 領域が完全にフレーム外なので上書きしない
  }
  else {
    # 一部または全部の領域がフレーム内にあるので上書きする

    if (ycminv <= rowidx && rowidx <= ycmaxv) {
      for (i = xcminv; i <= xcmaxv; i++) {
        $i = anobuf[rowidx,i];
      }
    }
  }

  # 出力
  print;

  # 行インデックスを更新
  rowidx++;
  if (rowidx > height) {
    # フレームが終了

    # 行インデックスをリセット
    rowidx = 1;

    # 現在の領域の範囲を更新
    xcmin += dx;
    xcmax += dx;
    ycmin += dy;
    ycmax += dy;

    # 整数座標を更新
    xcmini = intcoord(xcmin);
    xcmaxi = intcoord(xcmax);
    ycmini = intcoord(ycmin);
    ycmaxi = intcoord(ycmax);

    # 有効座標を更新
    xcminv = validcoord(xcmini, width);
    xcmaxv = validcoord(xcmaxi, width);
    ycminv = validcoord(ycmini, height);
    ycmaxv = validcoord(ycmaxi, height);

    # 更新後に領域がフレーム外に出たら終了
    if (dx > 0 && dy > 0 && (xcmini > width || ycmini > height) ||
        dx > 0 && dy < 0 && (xcmini > width || ycmaxi < 1     ) ||
        dx < 0 && dy > 0 && (xcmaxi < 1     || ycmini > height) ||
        dx < 0 && dy < 0 && (xcmaxi < 1     || ycmaxi < 1     ) ){

      # フィルタ終了状態に遷移
      state = "s_fin";

      # 現入力に関する処理を終了
      next;
    }
  }
}

# 有効座標に修正（フレーム範囲内の座標に修正）
function validcoord(ival,max) {
  return (ival < 1) ? 1 : (ival > max) ? max : ival;
}

# 整数座標（四捨五入）に修正
function intcoord(val) {
  return int(val + 0.5);
}

state == "s_fin" {
  # 入力をパススルー
  print;
}
' ${onefile:+"$onefile"}
