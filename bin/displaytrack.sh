#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -p<系列ファイル> [コンテンツファイル]
	Options : -w<待ち時間> -l -o<オフセット>

	経路上を動く図形を描画する。

	系列ファイルは以下の形式で記述する。
	  ・図形の一部を表す座標： <x座標> <y座標>
	  ・図形が動く経路を表す座標： <x座標> <y座標> <表示色>

	-rオプションでコンテンツのフレームの行数を指定する。
	-cオプションでコンテンツのフレームの列数を指定する。
	-pオプションで系列ファイルを指定する。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	-lオプションで描画のループの有無を指定できる。デフォルトはループしない。
	-oオプションで座標のオフセットを指定できる。デフォルトは"0,0"。
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
if ! printf '%s\n' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 61
fi

# 有効な数値の組であるか判定
if ! printf '%s\n' "$opt_o" | grep -Eq '^[0-9]+,[0-9]+$'; then
  echo "${0##*/}: \"$opt_o\" invalid pair of number" 1>&2
  exit 71
fi

# パラメータを決定
content=$opr
width=$opt_c
height=$opt_r
trackfile=$opt_p
waittime=$opt_w
isloop=$opt_l
offsets=$opt_o

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  width     = '"${width}"';
  height    = '"${height}"';
  trackfile = "'"${trackfile}"'";
  waittime  = '"${waittime}"';
  isloop    = "'"${isloop}"'";
  offsets   = "'"${offsets}"'";

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
  tn = 0; # 軌道の数
  cn = 0; # 部品の数
  while ((getline tline < trackfile) > 0) {
    # フィールドを分離
    fn = split(tline, tary, " ");

    # フィールド数を簡易チェック
    if (fn == 2) {
      # 軌道の情報（x座標 / y座標）
      tn++;

      tx[tn] = tary[1];
      ty[tn] = tary[2];
    }
    else if (fn == 3) {
      # 部品の情報（x座標 / y座標 / 色）
      cn++;

      xtmp = tary[1];
      ytmp = tary[2];
      ctmp = tary[3];

      # 座標を記録
      cx[cn] = (xtmp == "n") ? xtmp : (xtmp + xoffset);
      cy[cn] = (ytmp == "n") ? ytmp : (ytmp + yoffset);

      # 色アルファベットを全角に変換
      cc[cn] = h2z[ctmp];
    }
    else {
      # フィールド数が不正な場合はエラーを出力して終了
      msg = "'"${0##*/}"': invalid number of field (" tn+cn+1 ")";
      print msg > "/dev/stderr";
      exit 81;
    }
  }

  # 待ち時間があるならば「待機状態」に遷移
  if   (waittime > 0) { state = "s_wait"; wcnt = waittime; }
  else                { state = "s_run";  tidx = 1;        }
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
  if (wcnt == 0) { state = "s_run"; tidx = 1; next; }
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
  for (c = 1; c <= cn; c++) {
     # Ｎを指定する可能性はないはずだが念のため確認
     if (cc[c] != "Ｎ") {
       buf[cy[c]+ty[tidx], cx[c]+tx[tidx]] = cc[c];
     }
  }

  # フレームバッファ出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", buf[i, j]; }
    print "";
  }

  # 時刻インデックスを更新
  tidx++;
  if (tidx > tn) {
    # 表示を一巡したので次の状態を判定

    # 出力をもう一度最初から行う
    if (isloop == "yes") { state = "s_run"; tidx = 1; next; }

    # 図形の出力を終了して以降の入力はそのまま出力
    else                 { state = "s_fin";           next; }
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
