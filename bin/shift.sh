#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} -c<col num> -r<row num> <text file>
	Options : -u<unit to shift> -i

	shift the input text to the left gradually (like a ring buffer).

	-u: Specify the unit to shift once (default: 1).
	-i: Enable the shift to right.
	USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_c=''
opt_r=''
opt_u='1'
opt_i='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -c*)                 opt_c="${arg#-c}"    ;;
    -r*)                 opt_r="${arg#-r}"    ;;
    -u*)                 opt_u="${arg#-u}"    ;;
    -i)                  opt_i='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if   [ "${opr}" = '' ] || [ "${opr}" = '-' ]; then
  opr='-'
elif [ ! -f "${opr}" ] || [ ! -r "${opr}"  ]; then
  echo "ERROR:${0##*/}: invalid file specified <${opr}>" 1>&2
  exit 1
else
  :
fi

if ! printf '%s\n' "${opt_r}" | grep -Eq '^[0-9]+$'; then
  echo "ERROR:${0##*/}: invalid number specified <${opt_r}>" 1>&2
  exit 1
fi
if ! printf '%s\n' "${opt_c}" | grep -Eq '^[0-9]+$'; then
  echo "ERROR:${0##*/}: invalid number specified <${opt_c}>" 1>&2
  exit 1
fi
if ! printf '%s\n' "${opt_u}" | grep -Eq '^[0-9]+$'; then
  echo "ERROR:${0##*/}: invalid number specified <${opt_u}>" 1>&2
  exit 1
fi

readonly TEXT_FILE="${opr}"
readonly WIDTH="${opt_c}"
readonly HEIGHT="${opt_r}"
readonly UNIT="${opt_u}"
readonly IS_INVERSE="${opt_i}"

#####################################################################
# main routine
#####################################################################

cat "${TEXT_FILE}"                                                  |

gawk '
BEGIN {
  width  = '"${WIDTH}"';
  height = '"${HEIGHT}"';
  unit   = '"${UNIT}"';

  is_inverse = "'"${IS_INVERSE}"'"

  # The index of the currently head character
  lead_idx = 1;

  # The index to represent current row to pay attention to
  row_idx  = 1;
}

{
  if (lead_idx == 1) {
    # Output the original text

    curstr = $0
  } else             {
    # Apply the shift

    curstr = substr($0, lead_idx, width - lead_idx + 1) \
             substr($0, 1,                lead_idx - 1);
  }

  print curstr;
  
  if (row_idx >= height) {
    if (is_inverse == "no") {
      lead_idx = lead_idx + unit
      if (lead_idx > width) { lead_idx = lead_idx - width; }
    } else                   {
      lead_idx = lead_idx - unit
      if (lead_idx < 1    ) { lead_idx = lead_idx + width; }
    }

    row_idx = 1;
  } else                 {
    row_idx++;
  }
}
'
