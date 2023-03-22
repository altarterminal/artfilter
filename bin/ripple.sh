#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -r<行数> -c<列数> -p<中心> [コンテンツ]
	Options : -f<フレーム数> -l -s<速度> -m<最大半径> -w<待ち時間> -a<文字>

	コンテンツに波紋を上書きする。

	-rオプションでフレームの行数を指定する。
	-cオプションでフレームの列数を指定する。
	-pオプションで波紋の中心の座標を指定する。
	-fオプションで何フレームで波紋を変化させるか指定できる。デフォルトは1。
	-lオプションで描画のループの有無を指定できる。デフォルトはループしない。
	-sオプションで波紋の広がる速度を指定できる。デフォルトは1。
	-mオプションで波紋の最大サイズ（半径）を指定できる。デフォルトは10。
	-wオプションで開始までの待ち時間を指定できる。デフォルトは0。
	-aオプションで波紋を構成する文字を指定できる。デフォルトは"■"。
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
opt_f='1'
opt_l='no'
opt_s='1'
opt_m='10'
opt_w='0'
opt_a='■'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;    
    -r*)                 opt_r=${arg#-r}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -p*)                 opt_p=${arg#-p}      ;;
    -f*)                 opt_f=${arg#-f}      ;;
    -l)                  opt_l='yes'          ;;
    -s*)                 opt_s=${arg#-s}      ;;
    -m*)                 opt_m=${arg#-m}      ;;
    -w*)                 opt_w=${arg#-w}      ;;
    -a*)                 opt_a=${arg#-a}      ;;
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

# 有効な数値の組であるか判定
if ! printf '%s' "$opt_p" | grep -Eq '^-?[0-9]+,-?[0-9]+$'; then
  echo "${0##*/}: \"$opt_p\" invalid number pair" 1>&2
  exit 51
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_f" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_f\" invalid number" 1>&2
  exit 61
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_s" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_s\" invalid number" 1>&2
  exit 71
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_m" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_m\" invalid number" 1>&2
  exit 81
fi

# 有効な数値であるか判定
if ! printf '%s' "$opt_w" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: \"$opt_w\" invalid number" 1>&2
  exit 91
fi

# 有効な一文字であるか判定
if ! printf '%s' "$opt_a" | grep -q '^.$'; then
  echo "${0##*/}: \"$opt_a\" invalid character" 1>&2
  exit 101
fi

# パラメータを決定
content=$opr
height=$opt_r
width=$opt_c
center=$opt_p
frame=$opt_f
isloop=$opt_l
speed=$opt_s
rmax=$opt_m
waittime=$opt_w
char=$opt_a

######################################################################
# 本体処理
######################################################################

# コンテンツを入力
cat ${content:+"$content"}                                           |

gawk -v FS='' -v OFS='' '
######################################################################
# 初期化
######################################################################

BEGIN{
  # パラメータを設定
  height   = '"${height}"';
  width    = '"${width}"';
  center   = "'"${center}"'";
  frame    = '"${frame}"';
  isloop   = "'"${isloop}"'";
  speed    = '"${speed}"';
  rmax     = '"${rmax}"';
  waittime = '"${waittime}"';
  char     = "'"${char}"'";

  # 変化後文字列を分離
  split(center, cary, ",");
  x0 = cary[1];
  y0 = cary[2];

  xc[0];
  yc[0];
  nc;

  xcf[0];
  ycf[0];
  ncf;
  
  # 初期の波紋（半径1）を作成
  rc = 0;

  xall[1,1] = x0;
  yall[1,1] = y0;
  nall[1]   = 1;  
  rn        = 1;

  # 最大の半径に到達するまで波紋を作成
  rc = rc + speed;
  while (rc <= rmax) {
    # 波紋の数を更新
    rn++;

    # 波紋を作成
    nc = calccircle(x0,y0,rc,xc,yc);

    # フレーム外の座標をフィルタ
    ncf = filterframepoint(xc,yc,nc,height,width,xcf,ycf);

    # 座標を記録
    for (i=1;i<=ncf;i++){ xall[rn,i]=xcf[i]; yall[rn,i]=ycf[i]; }
    nall[rn] = ncf;

    # 半径を更新
    rc = rc + speed;  
  }

  # パラメータを初期化
  ridx = 1; # 現在の波紋が何番目のものか
  fcnt = 0; # 更新してから何フレームが経過したか

  # もし待ち時間があるならば「待機状態に遷移」
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

  # フレームに波紋を上書き
  for (i = 1; i <= nall[ridx]; i++) {      
    buf[yall[ridx,i], xall[ridx,i]] = char;
  }

  # フレームを出力
  for (i = 1; i <= height; i++) {
    for (j = 1; j <= width; j++) { printf "%s", buf[i, j]; }
    print "";
  }

  # 経過フレームを更新
  fcnt++;

  # 経過フレームが基準に達したら文字を更新
  if (fcnt >= frame) {
    # 経過フレームをリセット
    fcnt = 0;

    # 次の半径の波紋に切り替え
    ridx++;

    # すべての文字で置換し終えたら終了
    if (ridx > rn) {
      # 文字インデックスをリセット
      ridx = 1;

      # 置換をもう一度最初から行う
      if   (isloop == "yes") { state = "s_run"; }

      # 置換を終了して以降の入力はそのまま出力
      else                   { state = "s_fin"; }
   }
  }
}

state == "s_fin" {
  # 入力をパススルー
  print;
}

######################################################################
# 関数定義
######################################################################

# 指定のフレーム内に存在する座標のみを保存
function filterframepoint(xin,yin,nin,h,w,xout,yout,   nout,i) {
   nout = 0;

   for (i = 1; i <= nin; i++) {
     if (1<=xin[i] && xin[i]<=w && 1<=yin[i] && yin[i]<=h) {
       nout++;
       xout[nout] = xin[i];
       yout[nout] = yin[i];
     }
   }

   return nout;
}

# 指定した円周を構成する座標を計算
function calccircle(x0,y0,r0,x,y,                               \
                    x1,x2,x3,x4,x5,x6,x7,x8,                    \
                    y1,y2,y3,y4,y5,y6,y7,y8,                    \
                    xb,yb,d,cx,cy,i,n,ridx,tidx,lidx,bidx,eidx) {
  # 起点の４点
  xb[1] =  r0; yb[1] =   0;
  xb[2] =   0; yb[2] =  r0;
  xb[3] = -r0; yb[3] =   0;
  xb[4] =   0; yb[4] = -r0;

  # 第２領域（x>0,y>0,x<y）をベースとする初期化
  d  = 3 - 2*r0;
  cx = 0;
  cy = r0;
  n  = 0;

  # 第２領域（x>0,y>0,x<y）をベースとして座標を計算
  while (cx <= cy) {
    n++;
    if   (d < 0) { d = d +  6 + 4*cx;              cx++; }
    else         { d = d + 10 + 4*cx - 4*cy; cy--; cx++; }

    x1[n] =  cy; y1[n] =  cx;
    x2[n] =  cx; y2[n] =  cy;
    x3[n] = -cx; y3[n] =  cy;
    x4[n] = -cy; y4[n] =  cx;
    x5[n] = -cy; y5[n] = -cx;
    x6[n] = -cx; y6[n] = -cy;
    x7[n] =  cx; y7[n] = -cy;
    x8[n] =  cy; y8[n] = -cx;
  }

  # 範囲外の座標を削除（境界の周辺でオーバーランした座標を削除）
  for (i = 1; i <= n; i++) {
    # 第２領域（x>0,y>0,x<y）をベースに探索
    if (x2[i] > y2[i]) { n = i - 1; break; }
  }

  # 起点に対してオフセットを加算
  for (i = 1; i <= 4; i++) {
    xb[i] = xb[i] + x0; yb[i] = yb[i] + y0;
  }

  # 近似点に対してオフセットを加算
  for (i = 1; i <= n; i++) {
    x1[i] = x1[i] + x0; y1[i] = y1[i] + y0;
    x2[i] = x2[i] + x0; y2[i] = y2[i] + y0;
    x3[i] = x3[i] + x0; y3[i] = y3[i] + y0;
    x4[i] = x4[i] + x0; y4[i] = y4[i] + y0;
    x5[i] = x5[i] + x0; y5[i] = y5[i] + y0;
    x6[i] = x6[i] + x0; y6[i] = y6[i] + y0;
    x7[i] = x7[i] + x0; y7[i] = y7[i] + y0;
    x8[i] = x8[i] + x0; y8[i] = y8[i] + y0;
  }

  # 起点のインデックスを計算
  ridx = 0*n+1;
  tidx = 2*n+2;
  lidx = 4*n+3;
  bidx = 6*n+4;
  eidx = 8*n+5; # 存在しないが便宜上計算

  # 起点の座標を保存
  x[ridx] = xb[1];  y[ridx] = yb[1];
  x[tidx] = xb[2];  y[tidx] = yb[2];
  x[lidx] = xb[3];  y[lidx] = yb[3];
  x[bidx] = xb[4];  y[bidx] = yb[4];

  # 近似点の座標を保存（時計回りの順序を守る）
  for (i = 1; i <= n; i++) {
    x[ridx + i] = x1[i];  y[ridx + i] = y1[i];
    x[tidx - i] = x2[i];  y[tidx - i] = y2[i];
    x[tidx + i] = x3[i];  y[tidx + i] = y3[i];
    x[lidx - i] = x4[i];  y[lidx - i] = y4[i];
    x[lidx + i] = x5[i];  y[lidx + i] = y5[i];
    x[bidx - i] = x6[i];  y[bidx - i] = y6[i];
    x[bidx + i] = x7[i];  y[bidx + i] = y7[i];
    x[eidx - i] = x8[i];  y[eidx - i] = y8[i];
  }

  return 8 * n + 4;
}
'
