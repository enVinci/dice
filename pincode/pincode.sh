#!/bin/bash
set -eu
set -o pipefail

readonly Black='\033[0;30m'               # Black
readonly Red='\033[0;31m'                 # Red
readonly Green='\033[0;32m'               # Green
readonly Yellow='\033[0;33m'              # Yellow
readonly Blue='\033[0;34m'                # Blue
readonly Purple='\033[0;35m'              # Purple
readonly Cyan='\033[0;36m'                # Cyan
readonly White='\033[0;37m'               # White
readonly WhiteText='\033[38;5;255m'       # Text color (white)
readonly Gray='\033[90m'                  # Gray
readonly BoldGray="\033[1;30m"            # Bold Gray
readonly RedText='\033[38;5;196m'         # Text color (red)
readonly LightPurpleText='\033[38;5;177m' # Text color (purple)
readonly OrangeText='\033[38;5;214m'      # Text color (orange)
readonly BG_BrightYellow='\033[48;5;226m' # Background color (bright yellow)
readonly BG_LightGray='\033[48;5;250m'    # Background color (light gray)
readonly BG_DarkGray='\033[48;5;236m'     # Background color (dark gray)
readonly BG_Purple='\033[48;5;93m'        # Background color (purple)
readonly BG_DarkPurple='\033[48;5;53m'    # Background color (dark purple)
readonly BG_DarkPink='\033[48;5;125m'     # Background color (dark pink)
readonly BG_DarkRed='\033[48;5;52m'       # Background color (dark red)
readonly NC='\033[0m'                     # No Color

readonly script_name=$(basename "$0")
# Create an associative array to map long options to short options
declare -A option_map=(
    ["--file"]="-f"
    ["--name"]="-n"
    ["--type"]="-t"
    ["--count"]="-c"
    ["--clipboard"]="-C"
    ["--word-mode"]="-w"
    ["--verbose"]="-v"
    ["--help"]="-h"
)
# Default values
PASSMGR_PATH=${PASSMGR_PATH:-"passmgr"}
PASSMGR_OPTIONS=(${PASSMGR_OPTIONS:-'-c'})
ROLLS_SH_PATH=${ROLLS_SH_PATH:-"dicerolls"}
pincode_db=${pincode_db:-"$HOME/pincode.db"}
c=${c:-5}
w=${w:-2}
clipboard_option=${clipboard_option:-false}
clipboard_selection=${clipboard_selection:-'primary'} # "primary", "secondary", "clipboard" or "buffer-cut"
word_mode=${word_mode:-false}
verbose_option=${verbose_option:-false}
output_format=${output_format:-"dec"}
pincode_name=${pincode_name:-''}
format_option=false

parameter_to_str() {
    [[ "${1}" == 'true' ]] && echo -e "${Green}on${NC}" || echo "off"
}

name_mode_option() {
    local value="$1"
    $value && echo "WORDS" || echo "PIN"
}

name_format_option() {
    local value="$1"
    [ -n "$value" ] && echo "$pincode_name" || echo "ask the user"
}

# Function to display usage information
usage() {
    cat <<EOF >&2
This script generates a PIN code using the BIP-85 password generator with a password-protected pincode database.
Usage: $script_name [-f <path>] [-n <string>] [-t <format>] [-c <number>] [-w]
  -f, --file <path>     Provide the path to the password-protected pincode database (default: "${pincode_db}")
  -n, --name <string>   Provide a name for the pincode. The input is case insensitive (default: $(name_format_option "${pincode_name}"))
  -t, --type <format>   Select output format for PIN mode: dec | hex | entropy (default: ${output_format})
  -c, --count <number>  Set the count of characters (default: ${c}) or words (default: ${w})
  -C, --clipboard       Copy $(name_mode_option "${word_mode}") to the clipboard and do not print it (default: $(parameter_to_str "${clipboard_option}"))
  -w, --word-mode       Select BIP-39 word mode (default: $(name_mode_option "${word_mode}"))
  -v, --verbose         Enable verbose mode (default: $(parameter_to_str "${verbose_option}"))
  -h, --help            Display this Help message
Version: 1.0
EOF
    exit 1
}

# Function to convert long options to short options
convert_options() {
    local args=("$@")
    local converted_args=()

    for arg in "${args[@]}"; do
        if [[ -n "${option_map[$arg]+exists}" ]]; then
            converted_args+=("${option_map[$arg]}")
        else
            converted_args+=("$arg")
        fi
    done

    echo "${converted_args[@]}"
}

# Function for colored echo
cerror() {
    echo -e "${BG_DarkRed}${RedText}${script_name} Error:${NC} ${Red}$1${NC}" >&2
}

cwarn() {
    echo -e "${BG_DarkRed}${Orange}${script_name} Warning:${NC} ${Yellow}$1${NC}" >&2
}

# Check for required commands
if ! command -v "$ROLLS_SH_PATH" &>/dev/null; then
    cerror "The ROLLS_SH_PATH is not set or does not point to a valid executable ($ROLLS_SH_PATH)."
    exit 2
fi

if ! command -v "$PASSMGR_PATH" &>/dev/null; then
    cerror "The PASSMGR_PATH is not set or does not point to a valid executable ($PASSMGR_PATH)."
    exit 3
fi

# Convert long options to short options
converted_args=($(convert_options "$@"))
# Set the positional parameters to the contents of the converted_args array
set -- "${converted_args[@]}"

# Parse command-line options
while getopts ":c:Cwt:f:n:wvh" opt; do
    case ${opt} in
    f)
        pincode_db="$OPTARG"
        ;;
    n)
        pincode_name="$OPTARG"
        if [[ -z "$pincode_name" ]]; then
            cerror "Option: -n, --name requires a non-empty argument."
            usage
        fi
        ;;
    t)
        output_format="$OPTARG"
        format_option=true
        ;;
    c)
        c="$OPTARG"
        c_option=true
        ;;
    C)
        clipboard_option=true
        ;;
    w)
        word_mode=true
        ;;
    v)
        verbose_option=true
        ;;
    h)
        usage
        ;;
    \?)
        cerror "Invalid option: -$OPTARG"
        usage
        ;;
    :)
        cerror "Option: -"$OPTARG" requires an argument."
        usage
        ;;
    esac
done

command -v sed >/dev/null 2>&1 || cwarn "Dependency Check: sed command not found!"
command -v xxd >/dev/null 2>&1 || cwarn "Dependency Check: xxd command not found!"
command -v base64 >/dev/null 2>&1 || cwarn "Dependency Check: base64 command not found!"
command -v bx >/dev/null 2>&1 || cwarn "Dependency Check: bx command not found!"
command -v wc >/dev/null 2>&1 || cwarn "Dependency Check: wc command not found!"
command -v cut >/dev/null 2>&1 || cwarn "Dependency Check: cut command not found!"
command -v xclip >/dev/null 2>&1 || cwarn "Dependency Check: xclip command not found!"
command -v "${PASSMGR_PATH}" >/dev/null 2>&1 || cwarn "Dependency Check: ${PASSMGR_PATH} command not found!"

# Check for any remaining arguments
shift $((OPTIND - 1))
if [[ $# -gt 0 ]]; then
    cerror "Unrecognized arguments: $*"
    usage
fi

# Check if the file exists
if [[ ! -r "${pincode_db}" ]]; then
    cwarn "The pincode database '$pincode_db' does not exist or is not readable."
fi

# Validate that the argument is one of the allowed formats
if [[ ! "${output_format}" =~ ^(dec|hex|entropy)$ ]]; then
    cerror "Option: -t, --type argument must be one of: dec | hex | entropy."
    usage
fi

# Check for collisions between -t and -w
if [[ "${word_mode}" == true && "${format_option}" == true ]]; then
    cerror "Option: -t, --type cannot be used with -w, --word-mode option."
    usage
fi

# Set the count of words if not specified
[ -v c_option ] || [[ ! "${word_mode}" == true ]] || c="$w"
# Validate that the argument is a number
if ! [[ "$c" =~ ^[0-9]+$ ]]; then
    cerror "option: -n, --name argument must be a number."
    usage
fi

[ "${verbose_option}" = "true" ] && PASSMGR_OPTIONS+=' -v'

# Convert pincode name for command execution
if [[ -n "${pincode_name}" ]]; then
    pincode_name="-n ${pincode_name}"
fi

# Check if '-c' is in the option array for executable
[[ ! " ${PASSMGR_OPTIONS[@]} " =~ [[:space:]]-c[[:space:]] ]] && cwarn "The option of no coping to clipboard for the '$PASSMGR_PATH' is not set!"

# Execute the command
hex_entropy="$("$PASSMGR_PATH" ${PASSMGR_OPTIONS[@]} -l 86 -f "${pincode_db}" ${pincode_name} | tail -n 1)"
[ ${#hex_entropy} -ne 86 ] && cerror "Entropy capture length assert (${#hex_entropy})!" && exit 111
mnemonic="$(echo -n "${hex_entropy}==" | base64 --decode | xxd -p -c 9999 | bx mnemonic-new)"

if [[ "$word_mode" == true ]]; then
    mnemonic_length=$(echo -n "${mnemonic}" | wc -w)
    if [ $c -gt ${mnemonic_length} ]; then
        cwarn "The value of -c, --count option ($c) exceeds the maximum word count (${mnemonic_length})!"
    fi
    # Cut words
    code="$(echo -n "${mnemonic}" | cut -d' ' -f1-"$c")"
else
    # Process output and extract words
    case "$output_format" in
    dec)
        line_number=1
        ;;
    hex)
        line_number=2
        ;;
    entropy)
        line_number=3
        ;;
    *)
        cerror "Invalid format. Use dec, hex, or entropy."
        exit 1
        ;;
    esac
    # Converts words
    mnemonic="$(echo -n "${mnemonic}" | "$ROLLS_SH_PATH" -w | sed -n "${line_number}p")"
    mnemonic_length=$(echo -n "${mnemonic}" | wc -c)
    if [ $c -gt ${mnemonic_length} ]; then
        cwarn "The value of -c, --count option ($c) exceeds the maximum '$output_format' digit count (${mnemonic_length})!"
    fi
    # Cut characters
    code="$(echo -n "${mnemonic}" | cut -c 1-"$c")"
fi

if ${clipboard_option}; then
    echo -n "${code}" | xclip -se "$clipboard_selection" >/dev/null
else
    echo "${code}"
fi
