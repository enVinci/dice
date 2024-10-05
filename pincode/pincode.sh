#!/bin/bash
set -e
set -o pipefail

Black='\033[0;30m'               # Black
Red='\033[0;31m'                 # Red
Green='\033[0;32m'               # Green
Yellow='\033[0;33m'              # Yellow
Blue='\033[0;34m'                # Blue
Purple='\033[0;35m'              # Purple
Cyan='\033[0;36m'                # Cyan
White='\033[0;37m'               # White
Gray='\033[90m'                  # Gray
BoldGray="\033[1;30m"            # Bold Gray
RedText='\033[38;5;196m'         # Text color (red)
LightPurpleText='\033[38;5;177m' # Text color (purple)
Orange='\033[38;5;214m'          # Text color (orange)
BG_BrightYellow='\033[48;5;226m' # Background color (bright yellow)
BG_LightGray='\033[48;5;250m'    # Background color (light gray)
BG_DarkGray='\033[48;5;236m'     # Background color (dark gray)
BG_Purple='\033[48;5;93m'        # Background color (purple)
BG_DarkPurple='\033[48;5;53m'    # Background color (dark purple)
BG_DarkPink='\033[48;5;125m'     # Background color (dark pink)
BG_DarkRed='\033[48;5;52m'       # Background color (dark red)
NC='\033[0m'                     # No Color

readonly script_name=$(basename "$0")

# Default values
PASSMGR_PATH=${PASSMGR_PATH:-"passmgr"}
ROLLS_SH_PATH=${ROLLS_SH_PATH:-"dicerolls"}
pincode_db=${pincode_db:-"$HOME/pincode.db"}
c=${c:-5}
w=${w:-2}
word_mode=${word_mode:-false}
output_format=${output_format:-"dec"}
pincode_name=${pincode_name:-''}

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
Usage: $script_name [-f <path>] [-n <string>] [-m <format>] [-c <number>] [-w]
  -f <path>    Provide the path to the password-protected pincode database (default: ${pincode_db})
  -n <string>  Provide a name for the pincode. The input is case insensitive (default: $(name_format_option $pincode_name))
  -m <format>  Select output format for PIN mode: dec | hex | entropy (default: $output_format)
  -c <number>  Set the count of characters (default: $c) or words (default: $w)
  -w           Select BIP-39 word mode (default: $(name_mode_option $word_mode))
Version: 1.0
EOF
    exit 1
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

# Parse command-line options
while getopts ":c:wm:f:n:w" opt; do
    case ${opt} in
    f)
        pincode_db="$OPTARG"
        ;;
    n)
        pincode_name="$OPTARG"
        if [[ -z "$pincode_name" ]]; then
            cerror "-n option requires a non-empty argument."
            usage
        fi
        ;;
    m)
        output_format="$OPTARG"
        format_option=true
        ;;
    c)
        c="$OPTARG"
        c_option=true
        ;;
    w)
        word_mode=true
        ;;
    \?)
        usage
        ;;
    :)
        cerror "Option -"$OPTARG" requires an argument."
        usage
        ;;
    esac
done

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
if [[ ! "$output_format" =~ ^(dec|hex|entropy)$ ]]; then
    cerror "-m option argument must be one of: dec | hex | entropy."
    usage
fi

# Check for collisions between -m and -w
if [[ "$word_mode" == true && "$format_option" == true ]]; then
    cerror "-m option cannot be used with -w option."
    usage
fi

# Set the count of words if not specified
[ -v c_option ] || [[ ! "$word_mode" == true ]] || c="$w"

# Validate that the argument is a number
if ! [[ "$c" =~ ^[0-9]+$ ]]; then
    cerror "-n option argument must be a number."
    usage
fi

# Convert pincode name for command execution
if [[ -n "${pincode_name}" ]]; then
    pincode_name="-n ${pincode_name}"
fi

# Execute the command
hex_entropy="$("$PASSMGR_PATH" -c -l 86 -f "${pincode_db}" ${pincode_name})"
mnemonic="$(echo -n "${hex_entropy}==" | base64 --decode | xxd -p -c 9999 | bx mnemonic-new)"

if [[ "$word_mode" == true ]]; then
    mnemonic_length=$(echo -n "$mnemonic" | wc -w)
    if [ $c -gt $mnemonic_length ]; then
        cwarn "The value of -c option ($c) exceeds the maximum word count ($mnemonic_length)!"
    fi
    # Cut words
    echo -n "$mnemonic" | cut -d' ' -f1-"$c"
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
    mnemonic="$(echo -n "$mnemonic" | "$ROLLS_SH_PATH" -w | sed -n "${line_number}p")"
    mnemonic_length=$(echo -n "$mnemonic" | wc -c)
    if [ $c -gt $mnemonic_length ]; then
        cwarn "The value of -c option ($c) exceeds the maximum '$output_format' digit count ($mnemonic_length)!"
    fi
    # Cut characters
    echo -n "$mnemonic" | cut -c 1-"$c"
fi
