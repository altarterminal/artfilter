#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -c<列数> -r<行数> [テキストファイル]
	Options : -u<シフト列数>

	入力テキストを徐々に左にシフトして表示する（リングバッファライク）。

	-uオプションで一度にシフトする列数を指定できる。デフォルトは1。
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
opt_u='1'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;    
    -c*)                 opt_c=${arg#-c}      ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -u*)                 opt_u=${arg#-u}      ;;    
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

# 引数を評価
if   [ "_$opr" = '_' ] || [ "_$opr" = '_-' ]; then     
  opr=''
elif [ ! -f "$opr"   ] || [ ! -r "$opr"    ]; then
  echo "${0##*/}: \"$opr\" cannot be opened" 1>&2
  exit 21
else
  :
fi

# 引数を評価
if ! printf '%s\n' "$opt_r" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_r\" invalid number" 1>&2
  exit 31
fi
if ! printf '%s\n' "$opt_c" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_c\" invalid number" 1>&2
  exit 41
fi
if ! printf '%s\n' "$opt_u" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_u\" invalid number" 1>&2
  exit 51
fi

# パラメータを決定
content=$opr
width=$opt_c
height=$opt_r
unit=$opt_u

######################################################################
# 本体処理
######################################################################

gawk '
BEGIN {
  # パラメータを設定
  width  = '"${width}"';
  height = '"${height}"';
  unit   = '"${unit}"';

  # 現在の先頭がオリジナル文字列の何番目の文字であるか
  lidx = 1;

  # 現在の行インデックス
  ridx  = 1;
}

{
  if (lidx == 1)         {
    # オリジナルの文字列をそのまま表示

    curstr = $0
  } else                   {
    # シフトを行う

    curstr = substr($0, lidx, width - lidx + 1) \
             substr($0, 1,            lidx - 1);
  }

  print curstr;
  
  if (ridx >= height) {
    # フレームを終了したのでシフト数を更新

    # シフト数を更新
    lidx = lidx + unit
    if (lidx > width) { lidx = lidx - width; }

    # 行インデックスをリセット
    ridx = 1;
  } else               {
    # まだフレームの途中なのでシフト数を維持

    ridx++;
  }
}
' ${content:+"$content"}
