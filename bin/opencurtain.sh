#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -f<前景ファイル> [背景ファイル]
	Options : -o<オフセット> -c<透過部分のマーカー> -i

	背景に対して前景を上書きする。
	表示される前景の領域は徐々に減少し、最終的に背景が完全に表示されるようにする。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-fオプションで前景のファイルを指定する。
	-oオプションで前景のオフセットを指定できる。デフォルトは"0,0"。
	-tオプションで前景中の透過領域を示す文字を指定できる。デフォルトは□。
	-iオプションで開く方向を逆にする。デフォルトは中央から両側へ開く。
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
opt_i='yes'

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
    -i)                  opt_i='no'           ;;
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

# 引数を評価
if printf '%s\n' "$opt_t" | grep -q '^$'; then
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
isnormal=$opt_i

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  # パラメータを入力
  height   = '"${height}"';
  width    = '"${width}"';
  forfile  = "'"${forfile}"'";
  offset   = "'"${offset}"'";
  tchar    = "'"${tchar}"'";
  isnormal = "'"${isnormal}"'";

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

  # 現在の行インデックスを初期化
  rowidx = 1;

  # 幅が奇数or偶数のマーク
  iseven = (fwidth%2==0) ? "yes" : "no";

  # 左側部分の左端と右端のインデックスを初期化
  lsidx = ox+1;
  leidx = (iseven=="yes") ? (fwidth/2 + ox  ) : (fwidth/2+1 + ox);

  # 右側部分の左端と右端のインデックスを初期化
  rsidx = (iseven=="yes") ? (fwidth/2 + ox+1) : (fwidth/2+1 + ox);
  reidx = ox+fwidth;

  if (lsidx < 1 || width < reidx) {
    # 前景の一部または全部が領域外にある場合はエラー終了
    msg = "'"${0##*/}"': invalid foreground location";
    print msg > "/dev/stderr";
    exit 81;
  }

  # 初期状態を設定
  state = "state_run";
}

state == "state_run" {
  if ((oy < rowidx) && (rowidx <= oy+fheight)) {
    # 前景領域の中にあるときは上書き

    # 左側部分の上書き
    for (i = lsidx; i <= leidx; i++) {
      if (fbuf[rowidx-oy,i-ox] != tchar) {$i = fbuf[rowidx-oy,i-ox];}
    }

    # 右側部分の上書き
    for (i = rsidx; i <= reidx; i++) {
      if (fbuf[rowidx-oy,i-ox] != tchar) {$i = fbuf[rowidx-oy,i-ox];}
    }
  }

  # 出力
  print;

  # 行インデックス更新
  rowidx++;
  if (rowidx > height) {
    # 1フレームを終了したのでパラメータを更新

    # 行インデックスを先頭に戻す
    rowidx = 1;

    # 処理が終了したら終了状態に遷移（左側部分で判定）
    if (lsidx == leidx) { state = "state_fin"; }
    # 処理が継続なら端点のインデックスを更新
    else                {
      if   (isnormal == "yes") { leidx--; rsidx++; }
      else                     { lsidx++; reidx--; }
    }
  }

  # 出力を行ったので次の行へ進む
  next;
}

state == "state_fin" {
  # 入力をパススルー
  print;
}
' ${backfile:+"$backfile"}
