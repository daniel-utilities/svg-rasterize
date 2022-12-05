#!/usr/bin/env bash
# USAGE:
#   svg-to-png.sh {source} [destination] [-w width] [-h height] [-pad true|false] [-background color]

function return_error(){
    if [[ "$1" == "" ]]; then local MSG="unspecified"
    else                      local MSG="$1"
    fi
    "${__ERROR:?$MSG ($0)}"
}

function fast_argparse() {
    local -n _args=$1
    local -a pos=($2)
    local -a flg=($3)
    shift 3
    local flag poscnt=0
    while [[ "$#" -gt 0 ]]; do
        flag="${1##*-}"
        if [[ "$1" == -* ]]; then   # it's a flag argument
            if has_value flg "$flag" && [[ "$#" -ge 2 ]]; then   # it's a recognized flag
                _args["$flag"]="$2"
                shift 2
            else
                return_error "Invalid argument: $1 $2"
            fi
        else                        # it's a positional argument
            if [[ $poscnt -lt "${#pos[@]}" ]]; then   # it's a recognized positional arg
                _args["${pos[poscnt]}"]="$1"
                ((poscnt=poscnt+1))
                shift 1
            else
                return_error "Provided too many positional arguments"
            fi
        fi
    done
}

function has_value() {
    local -n ___arr=$1
    local elem="$2" list_elem
    for list_elem in "${___arr[@]}"; do
        if [[ "$elem" == "$list_elem" ]]; then return 0; fi
    done
    return 1
}

function is_integer_gt_0() {
    local regex='^[1-9][0-9]*$'
    [[ "$1" =~ $regex ]];
}

function get_basename() {
    local -n __outstr=$1
    local __instr="$2"
    local suffix="$3"
    __instr="${__instr#"${__instr%%[![:space:]]*}"}" # trim leading and trailing whitespace
    __instr="${__instr%"${__instr##*[![:space:]]}"}"
    __instr="${__instr%"${__instr##*[!/]}"}"         # trim trailing slash(s)
    __instr="${__instr##*/}"                         # trim path
    __instr="${__instr%"$suffix"}"                   # trim suffix

    __outstr="$__instr"
}

function single_svg_to_png() {
    local svg="$1"
    local png="$2"
    local density="$3"
    local extents="$4"
    local background="$5"

    magick "$svg" -density "$density" -delete 0 -background $background -gravity center "$svg" $extents -strip "$png"
    #convert -background transparent -density $density $extents -strip "$svg" "$png"
}

#############################################################################

if ! command -v magick > /dev/null; then return_error "This script requires command 'magick' from package 'imagemagick' (version 7+)."
fi

#############################################################################
trap exit SIGINT SIGTERM

declare -A args=()
fast_argparse args "src dst" "w h pad background" "$@"
if [[ "${args[src]}" == "" ]]; then      return_error "No source specified in position 1."
elif [[ -f "${args[src]}" ]]; then       src="${args[src]}"
elif [[ -d "${args[src]}" ]]; then       src="${args[src]}/*"
else                                     return_error "Invalid source: ${args[src]}"
fi
if [[ "${args[dst]}" == "" ]]; then      dst="./*"
else
  if [[ "${args[dst]}" == *.png ]]; then dst="${args[dst]}"
  else                                   mkdir -p "${args[dst]}" && dst="${args[dst]}/*" || return_error "Could not create destination path: ${args[dst]}"
  fi
fi
if [[ "${args[pad]}" == "true" ]]; then  padded=true
else                                     padded=false
fi
if [[ "${args[w]}" == "" ]]; then        width=256
elif is_integer_gt_0 "${args[w]}"; then  width="${args[w]}"
else                                     return_error "Invalid width: ${args[w]}"
fi
if [[ "${args[h]}" == "" ]]; then        height=$width
elif is_integer_gt_0 "${args[h]}"; then  height="${args[h]}"
else                                     return_error "Invalid height: ${args[h]}"
fi
if [[ "${args[background]}" == "" ]]; then background="transparent"
else                                     background="${args[background]}"
fi

[[ $width -ge $height ]] && density="%[fx:(($width*96)/w)]" || density="%[fx:(($height*96)/h)]"
[[ $padded == true ]] && extents="-extent ${width}x${height}" || extents=""

echo "Converting .svg files in path: $src"
for srcfile in $src; do
    get_basename basesrcfile "$srcfile"
    if [[ "$basesrcfile" == *.svg ]]; then
        dstfile="${dst/\*/"${basesrcfile%.svg}.png"}"   # get basename without .svg, substitue any * in the dst with basename.png
        echo "$basesrcfile --> $dstfile"
        single_svg_to_png "$srcfile" "$dstfile" "$density" "$extents" "$background"
    fi
done
