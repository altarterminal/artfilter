#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -a<別シーンファイル>
	          -p<形状ファイル> -d<軌跡ファイル> [シーンファイル]
	Options : -w<待ち時間> -s<スキップ>

	あるシーンの領域内に別シーンを上書きする。
	２つのシーンの幅と高さは一致する必要がある。
	形状ファイルに指定した座標の画素が別シーンファイルとなる。
	形状ファイルで指定した座標郡は軌跡ファイル中の軌跡を移動する。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-aオプションで別シーンファイルを指定する。
	-pオプションで別シーン領域を構成する座標を含むファイルを指定する。
	-dオプションで別シーン領域の軌跡を含むファイルを指定する。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	-sオプションでイテレーションごとのスキップ数を指定できる。デフォルトは1。
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
opt_p=''
opt_d=''
opt_w='0'
opt_s='1'

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
    -w*)                 opt_w=${arg#-w}      ;;
    -s*)                 opt_s=${arg#-s}      ;;
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

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_p" = '_' ] || [ "_$opt_p" = '_-' ]; then     
  echo "${0##*/}: parameter content must be a file" 1>&2
  exit 61
elif [ ! -f "$opt_p"   ] || [ ! -r "$opt_p"    ]; then
  echo "${0##*/}: \"$opt_p\" cannot be opened" 1>&2
  exit 62
else
  :
fi

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opt_d" = '_' ] || [ "_$opt_d" = '_-' ]; then     
  echo "${0##*/}: trajectory content must be a file" 1>&2
  exit 71
elif [ ! -f "$opt_d"   ] || [ ! -r "$opt_d"    ]; then
  echo "${0##*/}: \"$opt_d\" cannot be opened" 1>&2
  exit 72
else
  :
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 81
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_s" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_s\" invalid number" 1>&2
  exit 82
fi

# パラメータを決定
ofile=$opr
height=$opt_r
width=$opt_c
afile=$opt_a
pfile=$opt_p
tfile=$opt_d
wtime=$opt_w
skip=$opt_s

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  # パラメータ設定
  height  = '"${height}"';
  width   = '"${width}"';
  afile   = "'"${afile}"'";
  pfile   = "'"${pfile}"'";
  tfile   = "'"${tfile}"'";
  wtime   = '"${wtime}"';
  skip    = '"${skip}"';

  ####################################################################
  # 別シーンを入力
  ####################################################################

  # 別シーンの入力を準備
  rowcnt = 0;

  # 別シーンを入力
  while (getline line < afile) {
    rowcnt++;
    linewidth = split(line, ary, "");

    if (linewidth != width) {
      # 入力サイズ（幅）が異なる場合はエラー終了
      msg = "'"${0##*/}"': invalid input frame size (" width ")";
      print msg > "/dev/stderr";
      exit 81;
    }

    # 一行を記録
    for (i=1;i<=width;i++) { abuf[rowcnt,i] = ary[i]; }
  }

  if (rowcnt != height) {
    # 入力サイズ（高さ）が異なる場合はエラー終了
    msg = "'"${0##*/}"': invalid input frame size (" height ")";
    print msg > "/dev/stderr";
    exit 82;
  }

  ####################################################################
  # 部品座標を入力
  ####################################################################

  # 部品座標の入力を準備
  cmpcnt = 0;

  # 部品座標を入力
  while (getline line < pfile) {
    cmpcnt++;
    n = split(line, ary, " ");

    if (n != 2) {
      # 二次元座標以外のデータが入力された場合はエラー終了
      msg = "'"${0##*/}"': invalid input data (" cmpcnt ")";
      print msg > "/dev/stderr";
      exit 91;
    }

    cx[cmpcnt] = ary[1];
    cy[cmpcnt] = ary[2];
  }

  # 部品座標数を決定
  ncmp = cmpcnt;

  ####################################################################
  # 軌跡座標を入力
  ####################################################################

  # 軌跡座標の入力を準備
  trkcnt = 0;

  # 軌跡座標を入力
  while (getline line < tfile) {
    trkcnt++;
    n = split(line, ary, " ");

    if (n != 2) {
      # 二次元座標以外のデータが入力された場合はエラー終了
      msg = "'"${0##*/}"': invalid input data (" trkcnt ")";
      print msg > "/dev/stderr";
      exit 101;
    }

    tx[trkcnt] = ary[1];
    ty[trkcnt] = ary[2];
  }

  # 軌跡座標数を決定
  ntrk = trkcnt;

  # 待ち時間があるならば「待機状態」に遷移
  if   (wtime > 0) { state = "s_wait"; waitcnt = 0; }
  else             { state = "s_run";  trkidx  = 1; }
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
  waitcnt++;
  if (waitcnt >= wtime) { state = "s_run"; trkidx = 1; next; }
}

######################################################################
# 実行状態
######################################################################

state == "s_run" {
  # フレームを入力
  for(j=1;j<=width;j++){obuf[1,j]=$j;}
  for (i = 2; i <= height; i++) {
    if   (getline > 0) { for(j=1;j<=width;j++){obuf[i,j]=$j;} }
    else               { exit;                                }
  }

  # 図形を上書き
  for (cmpidx = 1; cmpidx <= ncmp; cmpidx++) {
    cxcur = cx[cmpidx] + tx[trkidx];
    cycur = cy[cmpidx] + ty[trkidx];

    if (1 <= cxcur && cxcur <= width  &&
        1 <= cycur && cycur <= height  ) {
      obuf[cycur,cxcur] = abuf[cycur,cxcur];
    }
  }

  # フレームバッファを出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", obuf[i,j]; }
    print "";
  }

  # 軌跡インデックスを更新
  trkidx = trkidx + skip;
  if (trkidx > ntrk) {
    # すべての軌跡を追跡した

    # 終了状態に遷移
    state = "s_fin"; next;
  }
}

######################################################################
# 終了状態
######################################################################

state == "s_fin" {
  # 入力をパススルー
  print;
}
' ${ofile:+"$ofile"}
