#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -s<変化文字列> [コンテンツ]
	Options : -f<フレーム数> -c<対象文字> -l

	コンテンツの<対象文字>を<変化文字列>で変化させて出力する。

	-rオプションでフレームの行数を指定する。
	-sオプションで変化文字列を指定する。
	-fオプションで何フレームで文字を変化させるか指定できる。デフォルトは1。
	-cオプションで変化対象の文字を指定できる。デフォルトは"■"。
	-lオプションで描画のループの有無を指定できる。デフォルトはループしない。
	USAGE
  exit 1
}

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_r=''
opt_s=''
opt_f='1'
opt_c='■'
opt_l='no'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;    
    -r*)                 opt_r=${arg#-r}      ;;
    -s*)                 opt_s=${arg#-s}      ;;
    -f*)                 opt_f=${arg#-f}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -l)                  opt_l='yes'          ;;
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

# 1文字以上であるか判定
if ! printf '%s' "$opt_s" | grep -Eq '^.+$'; then
  echo "${0##*/}: \"$opt_s\" invalid string" 1>&2
  exit 41
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_f" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_f\" invalid number" 1>&2
  exit 51
fi

# 1文字であるか判定
if ! printf '%s' "$opt_c" | grep -Eq '^.$'; then
  echo "${0##*/}: \"$opt_c\" invalid character" 1>&2
  exit 61
fi

# パラメータを決定
content=$opr
height=$opt_r
set=$opt_s
frame=$opt_f
char=$opt_c
isloop=$opt_l

######################################################################
# 本体処理
######################################################################

# コンテンツを入力
cat ${content:+"$content"}                                           |

gawk '
BEGIN{
  # パラメータを設定
  height = '"${height}"';
  set    = "'"${set}"'";
  frame  = '"${frame}"';
  char   = "'"${char}"'";
  isloop = "'"${isloop}"'";

  # 変化後文字列を分離
  nchar = split(set, cset, "");

  # パラメータを初期化
  cidx = 1; # 現在のフレームで変化後文字列の何番目の文字で置換するか
  rcnt = 0; # 現在の入力行がフレームの何行目か
  fcnt = 0; # 更新してから何フレームが経過したか

  # 初期状態を設定
  state = "s_run";
}

state == "s_run" {
  # 行数を更新
  rcnt++;

  # 対象文字を置換  
  gsub(char, cset[cidx], $0);

  # 置換後の文字列を出力
  print;

  # フレーム行数に到達したら更新処理を実行
  if (rcnt >= height) {
    # 行カウントをリセット
    rcnt = 0;

    # 経過フレームを更新
    fcnt++;

    # 経過フレームが基準に達したら文字を更新
    if (fcnt >= frame) {
      # 経過フレームをリセット
      fcnt = 0;

      # 文字インデックスを更新
      cidx++;
      
      # すべての文字で置換し終えたら終了
      if (cidx > nchar) {
        # 文字インデックスをリセット
        cidx = 1;

        # 置換をもう一度最初から行う
        if   (isloop == "yes") { state = "s_run"; }

        # 置換を終了して以降の入力はそのまま出力
        else                   { state = "s_fin"; }
      }
    }
  }
}

state == "s_fin" {
  # 入力をパススルー
  print;
}
'
