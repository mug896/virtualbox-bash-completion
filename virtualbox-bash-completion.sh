_vboxmanage_index()
{
    local -n i=$1
    for ((i = 1; i < COMP_CWORD; )); do 
        [[ ${COMP_WORDS[i++]} == $2 ]] && break
    done
}
_vboxmanage_list()
{
    local title=$1 medium=$2 res i
    test -n "$_vboxmanage_wait" && _vboxmanage_wait= || _vboxmanage_wait=" wait ... "
    echo -n "$_vboxmanage_wait" >&2

    if [[ $title == snapshot-name ]]; then
        _vboxmanage_index i snapshot
        res=$( $CMD snapshot "${COMP_WORDS[i]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\1/p' )
    elif [[ $title == filename ]]; then
        case $medium in
            dvds|floppies) res=$( $CMD list $medium | sed -En '/^Location: */{ s///p }' ) ;;
            *) res=$( $CMD list hdds | sed -En '/^Type:\s+normal\s+\(base\)/{ n; s/Location: *//p }') ;;
        esac
    else  # vmname
        res=$( $CMD list vms | sed -E 's/.*"([^"]*)".*/\1/' )
    fi
    WORDS=$( <<< $res gawk '/[[:graph:]]/{ a[i++] = $0 } END { 
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
    COMPREPLY=$( <<< $_vboxmanage_list \
        gawk $CUR' == $1+0 {sub(/^[0-9]+) +/,""); print "\""$0"\""; exit}' )
}

_vboxmanage_double_quotes()
{
    local i
    if [[ $PREV == --snapshot ]] || 
       [[ $HELP =~ ${PREV}[$' \n']*\ +"<snapshot-name" ]]; then
        _vboxmanage_index i snapshot
        WORDS=$( $CMD snapshot "${COMP_WORDS[i]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\1/p' )
    else
        WORDS=$( $CMD list vms | sed -E 's/^"([^"]*)".*/\1/' )
    fi
    IFS=$'\n' COMPREPLY=( $(compgen -P \" -S \" -W "$WORDS" -- "$CUR") )
}
_vboxmanage_options() 
{
    local i
    if [[ $1 == value ]]; then
        WORDS=$( sed -E -e ':Y s/<[^><]*>//g; tY; :Z s/\([^)(]*\)//g; tZ;' \
                     -e 's/.*'"${PREV%%+([0-9])}"'[0-9]*[= ]([^][]+]|\w[[:alnum:]|_-]*).*/\1/; tX; d' \
                     -e ':X s/[^[:alnum:]_-]/\n/g; s/^ *-.*//Mg' )
    else 
        local GREP="grep -Po -- '(?<![a-z])-[[:alnum:]-]+=?'"
        if [[ -z $CMD2 ]]; then
            WORDS=$( sed -En '/General Options:/,/Commands:/p' | eval "$GREP" )
        elif [[ $CMD2 == internalcommands && $PREV != internalcommands ]]; then
            _vboxmanage_index i internalcommands
            WORDS=$( sed -En '/^ *'"${COMP_WORDS[i]}"'/,/^$/{ s/\b[0-9]+-([0-9]+|N)//ig; p}' | eval "$GREP" )
        elif [[ $CMD2 == mediumio ]]; then
            if [[ -z $SCMD ]]; then
                WORDS="--disk= --dvd= --floppy= --password-file="
            else
                case $SCMD in
                    formatfat) WORDS=" --quick" ;;
                    cat) WORDS=" --hex --offset= --size= --output=" ;;
                    stream) WORDS=" --format= --variant= --output=" ;;
                esac
            fi
        else
            WORDS=$( sed -En 's/\b[0-9]+-([0-9]+|N)//ig; p' | eval "$GREP" )
        fi
    fi
}
_vboxmanage_get_options_cloud()
{
    if [[ $1 == profile ]]; then
        if [[ -n $SCMD ]]; then
            HELP=$( <<< $HELP sed -En '/VBoxManage cloudprofile .*'"$SCMD"'.*/,/^$/p' |
                    sed -E 's/--provider=|--profile=//g' )
        else
            HELP=" --provider= --profile="
        fi
    else
        if [[ -n $SCMD && -n $SCMD2 ]]; then
            HELP=$( <<< $HELP sed -En '/VBoxManage cloud .*'"$SCMD $SCMD2"'.*/,/^$/p' |
                    sed -E 's/--provider=|--profile=//g' )
        else
            HELP=" --provider= --profile="
        fi
    fi
}
_vboxmanage_get_options_sub()
{
    if [[ $CMD2 == guestcontrol ]]; then
        if [[ -n $SCMD ]]; then
            HELP=$( <<< $HELP sed -En -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
                -e '/^[ ]*[[:alnum:]\|]*\b'$SCMD'\b/,/^$/p' )
        else
            HELP=""
        fi
        local set="list closeprocess closesession updatega updateguestadditions updateadditions watch"
        if [[ $SCMD == @(${set//+([$' \n'])/|}) ]]; then
            HELP+=" -v --verbose -q --quiet"
        else
            HELP+=" -v --verbose -q --quiet --username --domain --password --passwordfile"
        fi
    elif [[ -n $SCMD ]]; then
        HELP=$( <<< $HELP sed -En '/VBoxManage '$CMD2'.*[ |]'$SCMD'\b.*/,/^$/p' )
    fi
}
_vboxmanage_subcommand()
{
    local i=$(( idx2 + 1 ))
    local set="dhcpserver extpack guestproperty hostonlyif metrics natnetwork unattended
            usbdevsource setproperty usbfilter sharedfolder"

    if [[ $CMD2 == @(debugvm|snapshot|controlvm|bandwidthctl) ]]; then
        if (( i + 1 < COMP_CWORD )); then 
            [[ $CMD2 == controlvm ]] && SCMD=${COMP_WORDS[i+1]%%+([0-9])} || SCMD=${COMP_WORDS[i+1]}
        fi

    elif [[ $CMD2 == @(${set//+([$' \n'])/|}) ]]; then
        (( i < COMP_CWORD )) && SCMD=${COMP_WORDS[i]}

    elif [[ $CMD2 == guestcontrol ]]; then let i++
        while [[ $i -lt $COMP_CWORD && ${COMP_WORDS[i]} == -* ]]; do 
            [[ ${COMP_WORDS[i]} == @(-v|--verbose|-q|--quiet) ]] && let i++ || {
                [[ ${COMP_WORDS[i+1]} == "=" ]] && let i+=3 || let i+=2
            }
        done
        (( i < COMP_CWORD )) && SCMD=${COMP_WORDS[i]}

    elif [[ $CMD2 == @(cloud|cloudprofile) ]]; then idc=2
        while [[ $idc -lt $COMP_CWORD && ${COMP_WORDS[idc]} == -* ]]; do 
            [[ ${COMP_WORDS[idc]} == @(--provider|--profile) ]] && {
                [[ ${COMP_WORDS[idc+1]} == "=" ]] && let idc+=3 || let idc+=2
            }
        done
        (( idc < COMP_CWORD )) && SCMD=${COMP_WORDS[idc]}
        [[ $CMD2 == cloud ]] && (( idc + 1 < COMP_CWORD )) && SCMD2=${COMP_WORDS[idc + 1]}

    elif [[ $CMD2 == @(list|mediumio) ]]; then
        while [[ $i -lt $COMP_CWORD && ${COMP_WORDS[i]} == -* ]]; do 
            [[ ${COMP_WORDS[i+1]} == "=" ]] && let i+=3 || let i++
        done
        (( i < COMP_CWORD )) && SCMD=${COMP_WORDS[i]}

    elif [[ $CMD2 == mediumproperty ]]; then
        [[ ${COMP_WORDS[i]} == @(disk|dvd|floppy) ]] && let i++
        (( i < COMP_CWORD )) && SCMD=${COMP_WORDS[i]}

    elif [[ $CMD2 == convertfromraw ]]; then
        [[ ${COMP_WORDS[i]} == stdin ]] && SCMD=${COMP_WORDS[i]}
    fi
}
_vboxmanage_HELP2()
{
    HELP2=$( <<< $HELP perl -pe 's/(VBoxManage '$CMD2'(\s+<[^>]*vmname[^>]*>)?)/" " x length($1)/e' )
    n=$( <<< $HELP awk 'BEGIN{ min=100 }
        match($0, /^ *[^ ]/) { if (RLENGTH > 10 && RLENGTH < min) min = RLENGTH } 
        END { print --min }' )
}
_vboxmanage_get_options() 
{
    local arg=$1
    local set="debugvm dhcpserver extpack guestcontrol guestproperty hostonlyif
        metrics natnetwork snapshot unattended usbdevsource usbfilter sharedfolder"

    if [[ $CMD2 == @(${set//+([$' \n'])/|}) ]]; then
        _vboxmanage_get_options_sub

    elif [[ $CMD2 == cloud ]]; then
        _vboxmanage_get_options_cloud

    elif [[ $CMD2 == cloudprofile ]]; then
        _vboxmanage_get_options_cloud profile

    else
        local HELP2 n
        _vboxmanage_HELP2
        if [[ -n $SCMD && $CMD2 == @(controlvm|bandwidthctl) ]]; then
            HELP=$( <<< $HELP2 sed -En -e '/^[ ]{'$n'}'$SCMD'\b/{ ' \
                -e ':Y s/'$SCMD'\b//; :X p; n; /^[ ]{'$n'}'$SCMD'\b/bY;' \
                -e '/^[ ]{'$n'}\w/Q; bX }' )
        fi
    fi

    if [[ $arg == value ]]; then
        _vboxmanage_options value <<< $(set -f; echo $HELP)
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
    local HELP2 n
    _vboxmanage_HELP2
    if [[ -z $SCMD && $CMD2 == @($PREV|$PREV2|${COMP_WORDS[COMP_CWORD-3]}) ]]; then
        WORDS=$( <<< $HELP2 sed -En -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
            -e 'tR :R s/^[ ]{'$n'}\[?(\w[[:alnum:]\|-]+)\]?.*/\1/; tX; b' -e ':X s/\|/ /g; p' )
    else  # else_words
        WORDS=$( <<< $HELP2 sed -En -e '/^[ ]{'$n'}'$SCMD'\b/{ ' \
            -e ':Y s/'$SCMD'\b//; :X p; n; /^[ ]{'$n'}'$SCMD'\b/bY;' \
            -e '/^[ ]{'$n'}\w/Q; bX }' | ( set -f; echo $(cat) ) | _vboxmanage_words )
    fi
}
_vboxmanage_else_words()
{
    local noneed="storagectl storageattach startvm showvminfo registervm movevm 
        modifyvm import export encryptmedium discardstate createvm clonevm 
        checkmediumpwd adoptstate"
    [[ $CMD2 == @(${noneed//+([$' \n'])/|}) ]] && return

    local ifscmdset="usbfilter usbdevsource unattended snapshot sharedfolder natnetwork 
        metrics mediumio list hostonlyif guestproperty guestcontrol extpack dhcpserver
        debugvm convertfromraw cloudprofile bandwidthctl mediumproperty"
    [[ -n $SCMD && $CMD2 == @(${ifscmdset//+([$' \n'])/|}) ]] && return

    [[ $CMD2 == cloud && -n $SCMD && -n $SCMD2 ]] && return

    [[ $CMD2 == @(showmediuminfo|modifymedium|createmedium|closemedium|clonemedium) &&
        ${COMP_WORDS[idx2 + 1]} == @(disk|dvd|floppy) ]] && return

    local set1="bandwidthctl clonemedium closemedium controlvm convertfromraw
        createmedium guestcontrol hostonlyif metrics setproperty modifymedium"

    local set2="dhcpserver extpack getextradata debugvm guestproperty natnetwork
        setextradata snapshot unattended usbdevsource usbfilter"

    if [[ $CMD2 == @(${set1//+([$' \n'])/|}) ]]; then
        _vboxmanage_get_words

    elif [[ $CMD2 == @(${set2//+([$' \n'])/|}) ]]; then
        WORDS=$( <<< $HELP \
            sed -En -e 's/VBoxManage '$CMD2'(\s+<[^>]*vmname[^>]*>)?\s+([[:alnum:]\|-]+).*/\2/; tX; b' \
                    -e ':X s/\|/ /g; p' )

    else # list mediumio mediumproperty sharedfolder
        WORDS=$( set -f; echo $HELP | _vboxmanage_words )
        if [[ $CMD2 == showmediuminfo ]]; then  WORDS=" disk dvd floppy"
        elif [[ $CMD2 == mediumproperty ]]; then 
            [[ ${COMP_WORDS[idx2 + 1]} != @(disk|dvd|floppy) ]] && WORDS=" disk dvd floppy"
        fi
    fi
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}
_vboxmanage() 
{
    local CMD=$1 CMD2 SCMD SCMD2
    local CUR=${COMP_WORDS[COMP_CWORD]}
    [[ ${COMP_LINE:COMP_POINT-1:1} = " " || $COMP_WORDBREAKS == *$CUR* ]] && CUR=""
    local PREV=${COMP_WORDS[COMP_CWORD-1]} PREV2=${COMP_WORDS[COMP_CWORD-2]}
    [[ $PREV == "=" ]] && PREV=${COMP_WORDS[COMP_CWORD-2]}
    local IFS=$' \t\n' WORDS idx2=1 idc
    while [[ $idx2 -lt $COMP_CWORD && ${COMP_WORDS[idx2]} == -* ]]; do 
        [[ ${COMP_WORDS[idx2]} == @(-q|--nologo|@*) ]] && let idx2++ || {
            [[ ${COMP_WORDS[idx2 + 1]} == "=" ]] && let idx2+=3 || let idx2+=2
        }
    done
    (( idx2 < COMP_CWORD )) && CMD2=${COMP_WORDS[idx2]}
    [[ -n $CMD2 ]] && _vboxmanage_subcommand
    local HELP=$($CMD $CMD2 |& tail -n +3 | sed 's/\[  \+\(USB|NVMe|VirtIO]\)/\1/')

    if [[ $PREV == --settingspwfile ]]; then
        :
    elif [[ $CUR == +([0-9]) && -n $_vboxmanage_list ]]; then
        _vboxmanage_number

    elif [[ $CMD2 == internalcommands && $PREV == internalcommands ]]; then
        WORDS=$( <<< $HELP grep -Po '(?<=^  )([a-z]+)' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )

    elif [[ $CUR == -* ]]; then
        _vboxmanage_get_options
    
    elif [[ $PREV == --ostype ]]; then
        WORDS=$( $CMD list ostypes | sed -En 's/^ID:\s+//p' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
    
    elif [[ ${COMP_WORDS[COMP_CWORD]} == \"* ]]; then
        _vboxmanage_double_quotes

    elif [[ -z $CMD2 ]]; then
        WORDS=$( <<< $HELP tee >(gawk '/^[ ]{2}[a-z]+/{print $1}') \
            >(\grep -Po '(?<=VBoxManage )\w+') > /dev/null )" internalcommands"
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )

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
    
    elif [[ $PREV == -* && $CMD2 != list && ! ($CMD2 == guestcontrol && -z $SCMD) ]]; then
        _vboxmanage_get_options value

    else
        [[ $CMD2 != internalcommands ]] && _vboxmanage_else_words
    fi

    [[ ${COMPREPLY: -1} == "=" ]] && compopt -o nospace
}

complete -o default -o bashdefault -F _vboxmanage vboxmanage VBoxManage

