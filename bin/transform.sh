#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -a<変身後ファイル> [変身前ファイル]
	Options : -m -w<待ち時間> -n<ピクセル数>

	変身前ファイルが徐々に変身後に移り変わる。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-aオプションで変身後のファイルを指定する。
	-mオプションで変身するピクセルの順序をランダムにできる。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	-nオプションでフレームごとに移行するピクセルの数を指定できる。デフォルトは1。
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
opt_m='no'
opt_w='0'
opt_n='1'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -a*)                 opt_a=${arg#-a}      ;;
    -m)                  opt_m='yes'          ;;
    -w*)                 opt_w=${arg#-w}      ;;
    -n*)                 opt_n=${arg#-n}      ;;
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
if ! printf '%s\n' "$opt_c" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_c\" invalid number" 1>&2
  exit 41
fi

# 有効な数値であるか判定
if [ ! -f "$opt_a" ] || [ ! -r "$opt_a" ]; then
  echo "${0##*/}: \"$opt_a\" cannot be opened" 1>&2
  exit 51
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 61
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_n" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_n\" invalid number" 1>&2
  exit 71
fi

# パラメータを決定
bfile=$opr
height=$opt_r
width=$opt_c
afile=$opt_a
isrand=$opt_m
wtime=$opt_w
nstep=$opt_n

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  height  = '"${height}"';
  width   = '"${width}"';
  afile   = "'"${afile}"'";
  isrand  = "'"${isrand}"'";
  wtime   = '"${wtime}"';
  nstep   = '"${nstep}"';

  # 変身後を入力
  arowcnt = 0;
  while (getline aline < afile) {
    arowcnt++;  
    n = split(aline, aary, "");
    for (i=1;i<=n;i++) { abuf[arowcnt,i] = aary[i]; }
  }

  # 変身後のパラメータを設定
  aheight = arowcnt;
  awidth  = n;

  # 座標列を生成
  ccnt = 0;
  for (j = 1; j <= height; j++) {
    for (i = 1; i <= width; i++) {
      ccnt++
      cseq[ccnt] = j "," i;
    }
  }

  # 座標列長さを決定
  cn = ccnt;

  # 座標列をランダムソート
  if (isrand == "yes") {
    srand();
    for (i = cn; i > 1; i--) {
      ia = i;
      ib = int(rand() * 4294967295) % i;
  
      tmp = cseq[ia];
      cseq[ia] = cseq[ib];
      cseq[ib] = tmp;
    }
  }

  # 座標を分解して保存しておく
  for (i = 1; i <= cn; i++) {
    split(cseq[i], cary, ",");
    cx[i] = cary[1];
    cy[i] = cary[2];
  }  

  # もし待ち時間があるなら「待機状態」に遷移
  if   (wtime > 0) { state = "s_wait"; wcnt = wtime; }
  else             { state = "s_run";  cidx = 1;     }
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
  if (wcnt == 0) { state = "s_run"; cidx = 1; next; }
}

######################################################################
# 実行状態
######################################################################

state == "s_run" {
  # フレームを入力
  for(j=1;j<=width;j++){buf[1,j]=$j;}
  for (i = 2; i <= height; i++) {
    if   (getline > 0) { for(j=1;j<=width;j++){buf[i,j]=$j;} }
    else               { exit;                               }
  }

  # 座標列の先頭から現在の末尾インデックスまでを上書き
  for (i = 1; i <= cidx; i++) { buf[cx[i],cy[i]]=abuf[cx[i],cy[i]]; }

  # 出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", buf[i, j]; }
    print "";
  }

  # 末尾インデックスを更新
  if      (cidx >= cn          ) { state = "s_fin"; ridx = 1; next; }
  else if (cidx >= (cn - nstep)) { cidx = cn;                       }
  else                           { cidx = cidx + nstep;             }
}

######################################################################
# 終了状態
######################################################################

state == "s_fin" {
  # 変身後の画像を出力
  for (j = 1; j <= width; j++) { printf "%s", abuf[rdix,j]; }
  print "";

  ridx++;
  ridx = (ridx > height) ? 1 : ridx;
}
' ${bfile:+"$bfile"}
