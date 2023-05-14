#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -p<パラメータ> [コンテンツ]
	Options :

	<パラメータ>で指定した条件でフレーム内の領域を回転させる。
	回転量はフレームの進行に対して累積する。

	-rオプションでフレームの行数を指定する。
	-rオプションでフレームの列数を指定する。
	-pオプションで回転のパラメータを指定する。

	パラメータは以下の形式で指定する。
	  中心の座標を(x,y)、中心からの距離をrとする領域に対して、
	  角度t（度数法）だけ回転させるとき、"x,y,r,t" のように指定する。
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

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -p*)                 opt_p=${arg#-p}      ;;
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
  echo "${0##*/}: \"$opt_r\" invalid row number" 1>&2
  exit 31
fi

# 有効な数値であるか判定
if ! printf '%s\n' "$opt_c" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_c\" invalid col number" 1>&2
  exit 41
fi

# 有効なパラメータ指定か判定
if ! printf '%s\n' "$opt_p"                        |
     grep -Eq '^-?[0-9]+,-?[0-9]+,[0-9]+,-?[0-9]+$'; then
  echo "${0##*/}: \"$opr\" invalid parameter" 1>&2
  exit 51
fi
  
# パラメータを決定
content=$opr
height=$opt_r
width=$opt_c
param=$opt_p

######################################################################
# 本体処理
######################################################################

gawk -v FS='' -v OFS='' '
BEGIN {
  param  = "'"${param}"'";
  height = '"${height}"';
  width  = '"${width}"';

  # パラメータを分離
  split(param, pary, ",");
  x0 = pary[1];
  y0 = pary[2];
  r0 = pary[3];
  t0 = pary[4];

  # 領域判定のために利用する値（半径の２乗）
  r2 = r0 * r0;

  # 領域判定の暫定値（円を含む正方形）
  xmin = x0 - r0;
  xmax = x0 + r0;
  ymin = y0 - r0;
  ymax = y0 + r0;

  # 定数を定義
  pi = 3.141592;
  radPdeg = pi / 180.0;

  # パラメータを初期化
  t = 0;
}

{
  # 角度を更新
  t = (t + t0) % 360;

  # 三角関数の値を計算
  st = sin(t * radPdeg);
  ct = cos(t * radPdeg);

  # フレームを入力バッファに保存
  for (i = 1; i <= width; i++) { ibuf[1,i] = $i; }
  rcnt = 1;
  while (rcnt < height) {
    # 入力がなければ終了
    if (getline <= 0) { exit; }

    # 1行入力に成功したのでカウントアップ
    rcnt++;

    # 入力した行をバッファに保存
    for (i = 1; i <= width; i++) { ibuf[rcnt,i] = $i; }
  }

  # 出力バッファを作成
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) {
      obuf[i,j] = ibuf[i,j];
    }
  }

  # 対象領域の画素を回転
  for (j = ymin; j <= ymax; j++) {
    for (i = xmin; i <= xmax; i++) {
      # 原点中心の座標に平行移動
      x_o = i - x0;
      y_o = j - y0;

      # 対象領域内であるか判定
      if (x_0*x_0 + y_0*y_0 > r2) {
        # 対象領域外であるので何もしない
      }
      else {
        # 対象領域内であるので回転させる

        # 回転処理
        x_r = x_o * ct + y_o * st * (-1);
        y_r = x_o * st + y_o * ct;

        # もとの座標に平行移動
        x_s = x_r + x0;
        y_s = y_r + y0;

        # 四捨五入
        xidx = int(x_s + 0.5);
        yidx = int(y_s + 0.5);

        # もし元画像中の範囲外であるならば無効文字で埋める
        if (xidx < 1 || width < xidx || yidx < 1 || height < yidx) {
          obuf[j,i] = "□"
        }
        else {
          obuf[j,i] = ibuf[yidx,xidx];
        }
      }
    }
  }

  # 出力
  for (j = 1; j <= height; j++) {
    for (i = 1; i <= width; i++) { printf "%s", obuf[j,i]; }
    print "";
  }
}
' ${content:+"$content"}
