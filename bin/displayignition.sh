#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -p<系列ファイル> [コンテンツファイル]
	Options : -w<待ち時間> -l -o<オフセット> -s<ステップ>

	図形を徐々に（1ピクセルずつ）描画する。

	系列ファイルは以下の形式で記述する。
	  ・表示色を指定しない座標（白で表示する）： <x座標> <y座標>
	  ・表示色を指定する座標： <x座標> <y座標> <表示色>

	-rオプションでコンテンツのフレームの行数を指定する。
	-cオプションでコンテンツのフレームの列数を指定する。
	-pオプションで系列ファイルを指定する。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	-lオプションで描画のループの有無を指定できる。デフォルトはループしない。
	-oオプションで座標のオフセットを指定できる。デフォルトは"0,0"。
	-sオプションで1フレームあたりの表示ピクセルの増分を指定できる。デフォルトは1。
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
opt_p=''
opt_w='0'
opt_l='no'
opt_o='0,0'
opt_s='1'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -p*)                 opt_p=${arg#-p}      ;;
    -w*)                 opt_w=${arg#-w}      ;;
    -l)                  opt_l='yes'          ;;
    -o*)                 opt_o=${arg#-o}      ;;
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
if ! printf '%s' "$opt_r" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_r\" invalid number" 1>&2
  exit 31
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_c" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_c\" invalid number" 1>&2
  exit 41
fi

# 標準入力または読み取り可能な通常ファイルであるか判定
if   [ "_$opt_p" = '_' ] || [ "_$opt_p" = '_-' ]; then     
  echo "${0##*/}: coord file must be specified" 1>&2
  exit 51
elif [ ! -f "$opt_p"   ] || [ ! -r "$opt_p"    ]; then
  echo "${0##*/}: \"$opt_p\" cannot be opened" 1>&2
  exit 52
else
  :
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 61
fi

# 有効な数値の組であるか判定
if ! printf '%s' "$opt_o" | grep -Eq '^[0-9]+,[0-9]+$'; then
  echo "${0##*/}: \"$opt_o\" invalid pair of number" 1>&2
  exit 71
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 81
fi

# パラメータを決定
content=$opr
width=$opt_c
height=$opt_r
pfile=$opt_p
waittime=$opt_w
isloop=$opt_l
offsets=$opt_o
step=$opt_s

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  width     = '"${width}"';
  height    = '"${height}"';
  pfile     = "'"${pfile}"'";
  waittime  = '"${waittime}"';
  isloop    = "'"${isloop}"'";
  offsets   = "'"${offsets}"'";
  step      = '"${step}"';

  # オフセット値を取得
  split(offsets, oary, ",");
  xoffset = oary[1];
  yoffset = oary[2];

  # 半角→全角変換を準備
  h2z["A"] = "Ａ"; h2z["B"] = "Ｂ"; h2z["C"] = "Ｃ"; h2z["D"] = "Ｄ";
  h2z["E"] = "Ｅ"; h2z["F"] = "Ｆ"; h2z["G"] = "Ｇ"; h2z["H"] = "Ｈ";
  h2z["I"] = "Ｉ"; h2z["J"] = "Ｊ"; h2z["K"] = "Ｋ"; h2z["L"] = "Ｌ";
  h2z["M"] = "Ｍ"; h2z["N"] = "Ｎ"; h2z["O"] = "Ｏ"; h2z["P"] = "Ｐ";
  h2z["Q"] = "Ｑ"; h2z["R"] = "Ｒ"; h2z["S"] = "Ｓ"; h2z["T"] = "Ｔ";
  h2z["U"] = "Ｕ"; h2z["V"] = "Ｖ"; h2z["W"] = "Ｗ"; h2z["X"] = "Ｘ";
  h2z["Y"] = "Ｙ"; h2z["Z"] = "Ｚ";

  # 系列データをすべて読み出し
  pn = 0; # 座標の数

  while ((getline pline < pfile) > 0) {
    # フィールドを分離
    fn = split(pline, pary, " ");

    # フィールド数を簡易チェック
    if (fn == 2) {
      # 座標情報のみの場合

      pn++;

      xtmp = pary[1];
      ytmp = pary[2];

      # 座標を記録
      px[pn] = (xtmp == "n") ? xtmp : (xtmp + xoffset);
      py[pn] = (ytmp == "n") ? ytmp : (ytmp + yoffset);
      # 色アルファベットを全角に変換して記録
      pc[pn] = h2z["W"];
    }
    else if (fn == 3) {
      # 座標情報と色情報の場合

      pn++;

      xtmp = pary[1];
      ytmp = pary[2];
      ctmp = pary[3];

      # 座標を記録
      px[pn] = (xtmp == "n") ? xtmp : (xtmp + xoffset);
      py[pn] = (ytmp == "n") ? ytmp : (ytmp + yoffset);
      # 色アルファベットを全角に変換して記録
      pc[pn] = h2z[ctmp];
    }
    else {
      # フィールド数が不正な場合はエラーを出力して終了
      msg = "'"${0##*/}"': invalid number of field (" pn+1 ")";
      print msg > "/dev/stderr";
      exit 91;
    }
  }

  pidx = 1; # 現在の末尾の座標のインデックス

  # 待ち時間があるならば「待機状態」に遷移
  if   (waittime > 0) { state = "s_wait"; wcnt = waittime; }
  else                { state = "s_run";                   }
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
######################################################################

state == "s_run" {
  # フレームを入力
  for(j=1;j<=width;j++){buf[1,j]=$j;}
  for (i = 2; i <= height; i++) {
    if   (getline > 0) { for(j=1;j<=width;j++){buf[i,j]=$j;} }
    else               { exit;                               }
  }

  # 図形を上書き
  for (i = 1; i <= pidx; i++) {
     if (pc[i] != "Ｎ") {
       buf[py[i], px[i]] = pc[i];
     }
  }

  # フレームバッファ出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", buf[i, j]; }
    print "";
  }

  # 座標インデックスを更新
  pidx = pidx + step;
  if (pidx < pn) {
    # 表示の途中なので何もしない
  }
  else if (pidx <  (pn + step)) {
    # ちょうど末尾まで表示できるように調整
    pidx = pn;
  }
  else if (pidx == (pn + step)) {
    # 表示を一巡したので次の状態を判定

    # 座標インデックスを初期化
    pidx = 1;

    # 出力をもう一度最初から行う
    if (isloop == "yes") { state = "s_run"; next; }

    # 図形の出力を終了して以降の入力はそのまま出力
    else                 { state = "s_fin"; next; }
  }
}

######################################################################
# 終了状態
######################################################################

state == "s_fin" {
  # 入力をパススルー
  print;
}
' ${content:+"$content"}
