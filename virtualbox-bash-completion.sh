_vboxmanage_index()
{
    for ((i = 1; i < COMP_CWORD; )); do 
        [[ ${COMP_WORDS[i++]} == $1 ]] && break
    done
}
_vboxmanage_list()
{
    local title=$1 medium=$2 res
    test -n "$_vboxmanage_wait" && _vboxmanage_wait= || _vboxmanage_wait=" wait ... "
    echo -n "$_vboxmanage_wait" >&2

    if [[ $title == snapshot-name ]]; then
        _vboxmanage_index snapshot
        res=$( $CMD snapshot "${COMP_WORDS[i]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\1/p' )
    elif [[ $title == filename ]]; then
        case $medium in
            dvds|floppies) res=$( $CMD list $medium | sed -En '/^Location: */{ s///p }' ) ;;
            *) res=$( $CMD list hdds | sed -En '/^Type:\s+normal\s+\(base\)/{ n; s/Location: *//p }') ;;
        esac
    else  # vmname
        res=$( $CMD list vms | sed -E 's/.*"([^"]*)".*/\1/' )
    fi
    WORDS=$( echo "$res" | gawk '/[[:graph:]]/{ a[i++] = $0 } END { 
            if (isarray(a)) { 
                len = length(i)
                for (i in a)
                    printf "%0*d) %s\n", len, i+1, a[i]
                if (length(a) == 1) print " "
            }}')
    _vboxmanage_list=$WORDS
    IFS=$'\n' COMPREPLY=( $WORDS )
}

_vboxmanage_number()
{
    CUR=$(( 10#$CUR ))
    COMPREPLY=$( echo "$_vboxmanage_list" | 
        gawk $CUR' == $1+0 {sub(/^[0-9]+) +/,""); print "\""$0"\""; exit}' )
}

_vboxmanage_double_quotes()
{
    if [[ $PREV == --snapshot ]] || 
       [[ $HELP =~ ${PREV}[$' \n']*\ +"<snapshot-name" ]]; then
        _vboxmanage_index snapshot
        WORDS=$( $CMD snapshot "${COMP_WORDS[i]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\\"\1\\"/p' )
    else
        WORDS=$( $CMD list vms | sed -E 's/^"([^"]*)".*/\\"\1\\"/' )
    fi
    IFS=$'\n' COMPREPLY=( $(compgen -W "$WORDS" -- \\\"$CUR) )
}

_vboxmanage_commands()
{
    WORDS=$( echo "$HELP" |
        tee >(gawk '/^[ ]{2}[a-z]+/{print $1}') >(\grep -Po '(?<=VBoxManage )\w+') > /dev/null )" internalcommands"
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}

_vboxmanage_options() 
{
    if [[ $1 == value ]]; then
        WORDS=$( sed -E -e ':Y s/<[^><]*>//g; tY; :Z s/\([^)(]*\)//g; tZ; s/'"VBoxManage $CMD2"'/\a/g' \
                     -e 's/.*'"${PREV%%+([0-9])}"'[0-9]*[= ]([^][]+).*/\1/; tX; d' \
                     -e ':X s/ --?[[:alnum:]]+|\a//g; s/[^[:alnum:]-]/\n/g' )
#        [[ -z $WORDS ]] && _vboxmanage_else_words
    else 
        local GREP="grep -Po -- '(?<![a-z])-[[:alnum:]-]+=?'"
        if [[ -z $CMD2 ]]; then
            WORDS=$( sed -En '/General Options:/,/Commands:/p' | eval "$GREP" )
        elif [[ $CMD2 == internalcommands && $PREV != internalcommands ]]; then
            _vboxmanage_index internalcommands
            WORDS=$( sed -En '/^ *'"${COMP_WORDS[i]}"'/,/^$/{ s/\b[0-9]+-([0-9]+|N)//ig; p}' | eval "$GREP" )
        else
            WORDS=$( sed -En 's/\b[0-9]+-([0-9]+|N)//ig; p' | eval "$GREP" )
        fi
    fi
}
_vboxmanage_get_options_cloud()
{
    local sub1 sub2 i
    for ((i = 2; i < COMP_CWORD; i++)); do 
        case ${COMP_WORDS[i]} in
            --provider|--profile) 
                [[ ${COMP_WORDS[i+1]} == "=" ]] && let i+=2 || let i++ ;;
            *) break ;;
        esac
    done
    if [[ $1 == profile ]]; then
        [[ i -lt $COMP_CWORD && $CUR != ${COMP_WORDS[i]} ]] && sub1=${COMP_WORDS[i]}
        if [[ -n $sub1 ]]; then
            HELP=$( echo "$HELP" | sed -En '/VBoxManage cloudprofile .*'"$sub1"'.*/,/^$/p' )
        else
            HELP=" --provider= --profile="
        fi
    else
        sub1=${COMP_WORDS[i++]}; 
        [[ i -lt $COMP_CWORD && $CUR != ${COMP_WORDS[i]} ]] && sub2=${COMP_WORDS[i]}
        if [[ -n $sub1 && -n $sub2 ]]; then
            HELP=$( echo "$HELP" | sed -En '/VBoxManage cloud .*'"$sub1 $sub2"'.*/,/^$/p' )
        else
            HELP=" --provider= --profile="
        fi
    fi
}
_vboxmanage_get_options_sub()
{
    local i subcommand
    _vboxmanage_index $CMD2

    if [[ $CMD2 == @(debugvm|guestcontrol|snapshot) ]]; then
        subcommand=${COMP_WORDS[i+1]}
    elif [[ $CMD2 == @(dhcpserver|extpack|guestproperty|hostonlyif|metrics|natnetwork|\
unattended|usbdevsource|usbfilter|sharedfolder) ]]; then
        subcommand=${COMP_WORDS[i]}
    fi
    if [[ -n $subcommand ]]; then
        if [[ $CMD2 == guestcontrol ]]; then
            HELP=$( echo "$HELP" | sed -En -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
                -e '/^[ ]*[[:alnum:]\|]*\b'$subcommand'\b/,/^$/p' )
            HELP+=" -v --verbose -q --quiet --username --domain --password --passwordfile"
        else 
            HELP=$( echo "$HELP" | sed -En '/VBoxManage '$CMD2'.*[ |]'$subcommand'\b.*/,/^$/p' )
        fi
    fi
}
_vboxmanage_subcommand()
{
    local i
    _vboxmanage_index "$CMD2"
    if [[ $CMD2 == @(debugvm|guestcontrol|snapshot|controlvm|bandwidthctl) ]]; then
        [[ $CUR != ${COMP_WORDS[i+1]} ]] && subcommand=${COMP_WORDS[i+1]%%+([0-9])}

    elif [[ $CMD2 == @(dhcpserver|extpack|guestproperty|hostonlyif|metrics|natnetwork|\
unattended|usbdevsource|setproperty|usbfilter|sharedfolder) ]]; then
        [[ $CUR != ${COMP_WORDS[i]} ]] && subcommand=${COMP_WORDS[i]%%+([0-9])}

    elif [[ $CMD2 == list ]]; then
        while [[ ${COMP_WORDS[i]} == -* ]]; do let i++; done
        [[ $CUR != ${COMP_WORDS[i]} ]] && subcommand=${COMP_WORDS[i]%%+([0-9])}

    elif [[ $CMD2 == mediumproperty ]]; then
        [[ ${COMP_WORDS[i]} == @(disk|dvd|floppy) ]] && let i++
        [[ $CUR != ${COMP_WORDS[i]} ]] && subcommand=${COMP_WORDS[i]%%+([0-9])}

    elif [[ $CMD2 == convertfromraw ]]; then
        [[ ${COMP_WORDS[i]} == stdin ]] && subcommand=${COMP_WORDS[i]}
    fi
    HELP2=$( echo "$HELP" | perl -pe 's/(VBoxManage '$CMD2'(\s+<[^>]*vmname[^>]*>)?)/" " x length($1)/e' )
    n=$( echo "$HELP" | awk 'BEGIN{ min=100 }
        match($0, /^ *[^ ]/) { if (RLENGTH > 10 && RLENGTH < min) min = RLENGTH } 
        END { print --min }' )
}
_vboxmanage_get_options() 
{
    if [[ $CMD2 == @(debugvm|dhcpserver|extpack|guestcontrol|guestproperty|hostonlyif|\
metrics|natnetwork|snapshot|unattended|usbdevsource|usbfilter|sharedfolder) ]]; then
        _vboxmanage_get_options_sub $CMD2

    elif [[ $CMD2 == cloud ]]; then
        _vboxmanage_get_options_cloud

    elif [[ $CMD2 == cloudprofile ]]; then
        _vboxmanage_get_options_cloud profile

    else
        local HELP2 n subcommand
        _vboxmanage_subcommand
        if [[ -n $subcommand && $CMD2 == @(controlvm|bandwidthctl) ]]; then
            HELP=$( echo "$HELP2" | sed -En -e '/^[ ]{'$n'}'$subcommand'\b/{ ' \
                -e ':Y s/'$subcommand'\b//; :X p; n; /^[ ]{'$n'}'$subcommand'\b/bY;' \
                -e '/^[ ]{'$n'}\w/Q; bX }' )
        fi
    fi

    if [[ $1 == value ]]; then
        _vboxmanage_options value <<< $(echo $HELP)
    else
        _vboxmanage_options <<< $HELP
    fi
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
    COMPREPLY=( ${COMPREPLY[@]/%--/} )
}
_vboxmanage_words()
{
    sed -E -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
           -e ':X s/\[[^][]*\]//g; tX; :Y s/<[^><]*>//g; tY; :Z s/\([^)(]*\)//g; tZ' \
           -e 's/'"VBoxManage $CMD2"'//g; s/[^[:alnum:]=-]/ /g' \
    | gawk '{ for (i=1; i<=NF; i++) { if ($i ~ /^[[:alpha:]][[:alnum:]-]+=?$/) print $i }}'
}
_vboxmanage_get_words()
{
    local HELP2 n subcommand
    _vboxmanage_subcommand
    if [[ -z $subcommand && $CMD2 == @($PREV|$PREV2|${COMP_WORDS[COMP_CWORD-3]}) ]]; then
        WORDS=$( echo "$HELP2" | sed -En -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
            -e 's/^[ ]{'$n'}\[?(\w[[:alnum:]\|-]+)\]?.*/\1/; tX; b' -e ':X s/\|/ /g; p' )
    else  # else_words
        WORDS=$( echo "$HELP2" | sed -En -e '/^[ ]{'$n'}'$subcommand'\b/{ ' \
            -e ':Y s/'$subcommand'\b//; :X p; n; /^[ ]{'$n'}'$subcommand'\b/bY;' \
            -e '/^[ ]{'$n'}\w/Q; bX }' | _vboxmanage_words )
    fi
}
_vboxmanage_else_words()
{
    if [[ $CMD2 == @(bandwidthctl|clonemedium|closemedium|controlvm|convertfromraw|\
createmedium|guestcontrol|hostonlyif|metrics|movevm|setproperty|modifymedium) ]]; then
        _vboxmanage_get_words

    elif [[ $CMD2 == @(dhcpserver|extpack|getextradata|debugvm|guestproperty|natnetwork|\
setextradata|snapshot|unattended|usbdevsource|usbfilter) ]]; then
        WORDS=$( echo "$HELP" | sed -En -e 's/VBoxManage '$CMD2'(\s+<[^>]*vmname[^>]*>)?\s+([[:alnum:]\|-]+).*/\2/; tX; b' -e ':X s/\|/ /g; p' )

    else # list mediumio mediumproperty sharedfolder
        WORDS=$( echo $HELP | _vboxmanage_words )
        [[ $CMD2 == @(mediumproperty|showmediuminfo) ]] && WORDS+=" disk dvd floppy"

    fi
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}
_vboxmanage() 
{
    trap 'set +o noglob' RETURN   
    set -o noglob
    local CMD=$1 CMD2 CUR=$2 PREV=$3 PREV2=${COMP_WORDS[COMP_CWORD-2]}
    [[ $PREV == "=" ]] && PREV=${COMP_WORDS[COMP_CWORD-2]}
    local IFS=$' \t\n' WORDS idx2
    for (( idx2 = 1; idx2 < COMP_CWORD; idx2++)) do
        case ${COMP_WORDS[idx2]} in 
            -q|--nologo|@*) ;;
            --settingspw|--settingspwfile) let idx2++ ;;
            *) break ;;
        esac
    done
    [[ ${COMP_WORDS[idx2]} != $CUR ]] && CMD2=${COMP_WORDS[idx2]}
    local HELP=$($CMD $CMD2 |& tail -n +3 | sed 's/\[  \+\(USB|NVMe|VirtIO]\)/\1/')

    if [[ $PREV == --settingspwfile ]]; then :

    elif [[ $CUR == +([0-9]) && -n $_vboxmanage_list ]]; then
        _vboxmanage_number

    elif [[ $CMD2 == internalcommands && $PREV == internalcommands ]]; then
        WORDS=$( echo "$HELP" | grep -Po '(?<=^  )([a-z]+)' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )

    elif [[ $CUR == -* ]]; then
        _vboxmanage_get_options
    
    elif [[ $PREV == --ostype ]]; then
        WORDS=$( $CMD list ostypes | sed -En 's/^ID:\s+//p' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
    
    elif [[ ${COMP_WORDS[COMP_CWORD]} == \"* ]]; then
        _vboxmanage_double_quotes

    elif [[ -z $CMD2 ]]; then
        _vboxmanage_commands

    elif [[ -z $CUR ]] && 
        [[ $HELP =~ ${PREV}[^$' \n']*\ +"<"[^\>]*"vmname"[^\>]*">" ]]; then
        _vboxmanage_list vmname

    elif [[ -z $CUR ]] && [[ $PREV == --snapshot || 
         $HELP =~ ${PREV}[^$' \n']*\ +"<snapshot-name" ]]; then
        _vboxmanage_list snapshot-name

    elif [[ -z $CUR ]] && [[ $PREV == @(--disk|--dvd|--floppy) || 
         $HELP =~ ${PREV}[^$' \n']*\ +"<uuid|filename>" ]]; then
         if [[ $PREV == @(dvd|--dvd) || $PREV2 == dvd ]]; then PREV=dvds
         elif [[ $PREV == @(floppy|--floppy) || $PREV2 == floppy ]]; then PREV=floppies
         else PREV=hdds; fi
        _vboxmanage_list filename $PREV
    
    elif [[ $PREV == -* ]]; then
        _vboxmanage_get_options value

    else
        [[ $CMD2 != internalcommands ]] && _vboxmanage_else_words
    fi

    [[ ${COMPREPLY: -1} == "=" ]] && compopt -o nospace
}

complete -o default -o bashdefault -F _vboxmanage vboxmanage VBoxManage

