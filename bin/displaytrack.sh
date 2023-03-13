#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -c<列数> -r<行数> -p<系列ファイル> [コンテンツファイル]
	Options : -w<待ち時間> -l -o<オフセット>

	コンテンツ上に座標系列で指定された図形を描画する

	-cオプションでコンテンツの列数を指定する。
	-rオプションでコンテンツのフレームの行数を指定する。
	-pオプションで線分が通過する座標（整数）が記載されたファイルを指定する。
	-wオプションで開始までの待ち時間を指定する。デフォルトは0。
	-lオプションでループを指定する。デフォルトはループしない。
	-oオプションでオフセットを指定する。オフセットは-o"1,1"のように指定する。デフォルトは"0,0"。
	USAGE
  exit 1
}

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_c=''
opt_r=''
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
    -c*)                 opt_c=${arg#-c}      ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -p*)                 opt_p=${arg#-p}      ;;
    -w*)                 opt_w=${arg#-w}      ;;
    -l)                  opt_l='yes'          ;;
    -o*)                 opt_o=${arg#-o}      ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ] ; then
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

# コンテンツを入力
cat ${content:+"$content"}                                           |

awk -v FS='' -v OFS='' '
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

  # 座標をすべて読み込む
  tn = 0; # 軌道の数
  cn = 0; # 部品の数
  while ((getline tline < trackfile) > 0) {
    fn = split(tline, tary, " ");

    # フィールド数を簡易チェック
    if (fn == 2) {
      # 軌道の情報（x座標 / y座標）
      tn = tn + 1;

      tx[tn] = tary[1];
      ty[tn] = tary[2];
    }
    else if (fn == 3) {
      # 部品の情報（x座標 / y座標 / 色）
      cn = cn + 1;

      cx[cn] = tary[1];
      cy[cn] = tary[2];
      cc[cn] = tary[3];

      # 有効座標にはオフセットを加算
      cx[cn] = (cx[cn] == "n") ? cx[cn] : (cx[cn] + xoffset);
      cy[cn] = (cy[cn] == "n") ? cy[cn] : (cy[cn] + yoffset);
      # 半角文字を全角に変換
      cc[cn] = h2z[cc[cn]];
    }
    else {
      # フィールド数が不正な場合はメッセージ出力して終了
      if (prevsn != sn) {
        msg = "'"${0##*/}"': invalid number of field (" tn + cn + 1 ")";
        print msg >> "/dev/stderr";
        exit 81;
      }
    }
  }

  # 待ち時間があるならば「待機状態」に遷移
  if (waittime > 0) {
    state = "s_wait"; wcnt = waittime; 
  } else {
    state = "s_run";  tcnt = 0;
  }
}

######################################################################
# 待機状態
######################################################################

state == "s_wait" {
  # 1フレーム分の行をそのまま出力
  print;
  for (i = 2; i <= height; i++) {
    if   (getline > 0) { print; }
    else               { exit;  }
  }

  # 待ち時間をすべて消費したら「描画状態」に遷移
  wcnt--;
  if (wcnt == 0) { state = "s_run"; tcnt = 0; next; }
}

######################################################################
# 実行状態
######################################################################

state == "s_run" {
  # 1フレーム分のバッファを入力
  for (j = 1; j <= width; j++) { buf[1, j] = $j; }
  for (i = 2; i <= height; i++) {
    if (getline line > 0) {
      split(line, ary, "");
      for (j = 1; j <= width; j++) { buf[i, j] = ary[j]; }
    }
    else {
      exit;
    }
  }

  # 図形を上書き
  for (c = 1; c <= cn; c++) {
     # 「Ｎ」を指定する可能性はないはずであるが念のため
     if (cc[c] != "Ｎ") {
       buf[cy[c]+ty[tcnt+1], cx[c]+tx[tcnt+1]] = cc[c];
     }
  }

  # フレームバッファ出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", buf[i, j]; }
    print "";
  }

  # 時刻インデックスを更新
  tcnt++;
  if (tcnt >= tn) {
    # 表示を一巡したので次の状態を判定

    if (isloop == "yes") {
      # ループ指定があればもう一度最初から
      if (waittime > 0) { state = "s_wait"; wcnt = waittime; next; }
      else              { state = "s_run";  tcnt = 0;        next; }
    }
    else {
      # ループ指定がなければ「終了状態」に遷移
                        { state = "s_fin";                   next; }
    }
  }
}

######################################################################
# 終了状態
######################################################################

state == "s_fin" {
  # 入力をパススルー
  print;
}
'
