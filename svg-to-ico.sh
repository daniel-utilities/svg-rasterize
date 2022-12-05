#!/usr/bin/env bash
# USAGE:
#   svg-to-ico.sh {source} [destination] [-src2 second_svg_path [-thresh size]] [-background color]

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

function get_dirname() {
    local -n __outstr=$1
    local __instr="$2"
    __instr="${__instr#"${__instr%%[![:space:]]*}"}" # trim leading and trailing whitespace
    __instr="${__instr%"${__instr##*[![:space:]]}"}"
    __instr="${__instr%"${__instr##*[!/]}"}"         # trim trailing slash(s)
    __instr="${__instr%/*}"                          # trim basename
    __instr="${__instr%"${__instr##*[!/]}"}"         # trim trailing slash(s) (again, for some weird edge cases)

    __outstr="$__instr"
}


function single_svg_to_ico () {
    local svg1="$1"
    local svg2="$2"
    local ico="$3"
    local thresh="$4"
    local background="$5"

    if [[ ! -f "$svg2" ]]; then
        echo "Error: $svg2 does not exist. Reverting to $svg1."
        svg2="$svg1"
    fi


    # Setup pngpath
    get_basename name "$ico" ".ico"
    get_dirname dstdir "$ico"
    local pngpath="$dstdir/$name"
    mkdir -p "$pngpath"
    
    # Export full-color (32-bit) pngs first, then make 8 and 4 bit pngs for specific sizes (windows requirement)
    local size svg density extents
    for size in 16 24 32 48 64 96 128 256; do
        [[ $size -lt $thresh ]] && svg="$svg2" || svg="$svg1"
        density="%[fx:(($size*96)/h)]"
        extents="-extent ${size}x${size}"
        echo "  Exporting $name/$size.png..."
        magick "$svg" -density "$density" -delete 0 -background $background -gravity center "$svg" $extents -strip "$pngpath/$size.png"
        #convert -background transparent -density $size -extent ${size}x${size} -gravity center -strip "$svg" "$pngpath/$size.png"
    done
    for size in 16 24 32 48; do
        echo "  Exporting $name/$size-8.png..."
        convert -colors 256 +dither "$pngpath/$size.png" png8:"$pngpath/$size-8.png"
        echo "  Exporting $name/$size-4.png..."
        convert -colors 16 +dither "$pngpath/$size-8.png" "$pngpath/$size-4.png"
    done

    echo "  Creating $ico..."
    icotool -c -o "$ico" "$pngpath/16.png" "$pngpath/24.png" "$pngpath/32.png" "$pngpath/48.png" "$pngpath/16-8.png" "$pngpath/24-8.png" "$pngpath/32-8.png" "$pngpath/48-8.png" "$pngpath/16-4.png" "$pngpath/24-4.png" "$pngpath/32-4.png" "$pngpath/48-4.png" "$pngpath/64.png" "$pngpath/96.png" -r "$pngpath/128.png" -r "$pngpath/256.png"
    #convert -density 512 -background transparent "$svg" -define icon:auto-resize -colors 256 "$ico"

    echo "  Cleaning up..."
    cp "$pngpath/256.png" "$dstdir/$name.png"
    rm -rf "$pngpath"
}

#############################################################################

if ! command -v magick > /dev/null; then return_error "This script requires command 'magick' from package 'imagemagick' (version 7+)."
fi
if ! command -v convert > /dev/null; then return_error "This script requires command 'convert' from package 'imagemagick' (version 7+)."
fi
if ! command -v icotool > /dev/null; then return_error "This script requires command 'icotool' from package 'icoutils'."
fi

#############################################################################
trap exit SIGINT SIGTERM

declare -A args=()
fast_argparse args "src1 dst" "src2 thresh background" "$@"
if [[ "${args[src1]}" == "" ]]; then     return_error "No source specified in position 1."
elif [[ -f "${args[src1]}" ]]; then      src1="${args[src1]}"
elif [[ -d "${args[src1]}" ]]; then      src1="${args[src1]}/*"
else                                     return_error "Invalid source: ${args[src1]}"
fi
if [[ "${args[dst]}" == "" ]]; then      dst="./*"
else
  if [[ "${args[dst]}" == *.svg ]]; then dst="${args[dst]}"
  else                                   mkdir -p "${args[dst]}" && dst="${args[dst]}/*" || return_error "Could not create destination path: ${args[dst]}"
  fi
fi
if [[ "${args[src2]}" == "" ]]; then     src2="$src1"
elif [[ -f "${args[src2]}" ]]; then      src2="${args[src2]}"
elif [[ -d "${args[src2]}" ]]; then      src2="${args[src2]}/*"
else                                     return_error "Invalid source: ${args[src2]}"
fi
if [[ "${args[thresh]}" == "" ]]; then   thresh=64
elif is_integer_gt_0 "${args[thresh]}"; then thresh="${args[thresh]}"
else                                     return_error "Invalid size: ${args[thresh]}"
fi
if [[ "${args[background]}" == "" ]]; then background="transparent"
else                                     background="${args[background]}"
fi

echo "Converting .svg files in path:"
echo "  $src1"
if [[ "${args[thresh]}" != "" ]]; then
    echo "For sizes lower than $thresh, using alternative .svg path:"
    echo "  $src2"
fi
echo ""

for src1file in $src1; do
    get_basename basesrcfile "$src1file"
    if [[ "$basesrcfile" == *.svg ]]; then
        src2file="${src2/\*/"$basesrcfile"}"
        dstfile="${dst/\*/"${basesrcfile%.svg}.ico"}"   # get basename without .svg, substitue any * in the dst with basename.ico
        echo "$basesrcfile --> $dstfile"
        single_svg_to_ico "$src1file" "$src2file" "$dstfile" "$thresh" "$background"
        # echo "src1:         $src1"
        # echo "src2:         $src2"
        # echo "basesrcfile:  $basesrcfile"
        # echo "src1file:     $src1file"
        # echo "src2file:     $src2file"
    fi
done


