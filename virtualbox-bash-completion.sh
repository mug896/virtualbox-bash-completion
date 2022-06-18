_vboxmanage_vmname()
{
    local res

    test -n "$_vboxmanage_wait" && _vboxmanage_wait= || _vboxmanage_wait=" wait ... "
    echo -n "$_vboxmanage_wait" >&2

    if [ "$1" = "snapshot-name" ]; then
        res=$( $COM1 snapshot "${COMP_WORDS[2]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\1/p' )
    else  # vmname
        res=$( $COM1 list vms | sed 's/{[^}]\+}//' )
    fi
    WORDS=$( echo "$res" | gawk '{a[i++]=$0} END{ 
            if (isarray(a)) { 
                if (length(a) == 1) print " "
                len=length(i)
                for (i in a) printf "%0*d) %s\n", len, i+1, a[i]
            }}')

    _vboxmanage_vmname=$1$'\n'$WORDS

    IFS=$'\n'
    COMPREPLY=( $WORDS )
}

_vboxmanage_number()
{
    local title=${_vboxmanage_vmname%%$'\n'*}
    local value=${_vboxmanage_vmname#*$'\n'}
    
    CUR=$(( 10#$CUR ))
    if [ "$title" = vmname ]; then
        COMPREPLY=$( echo "$value" \
            | gawk $CUR' == $1+0 {print $2; exit}' FPAT='[^ ]+|"[^"]+"' )
    else  # snapshot-name
        COMPREPLY=$( echo "$value" \
            | gawk $CUR' == $1+0 {sub(/^[0-9]+) +/,""); print "\""$0"\""; exit}' )
    fi
}

_vboxmanage_double_quotes()
{
    if [ "$PREV" = --snapshot ] || 
       [[ $subComRaw =~ ${PREV}[^\ $'\n']*\ +"<snapshot-name" ]]
    then
        WORDS=$( $COM1 snapshot "${COMP_WORDS[2]:1:-1}" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/\\"\1\\"/p' )
    else
        WORDS=$( $COM1 list vms | sed -E 's/^"([^"]*)".*/\\"\1\\"/' )
    fi
    IFS=$'\n'
    COMPREPLY=( $(compgen -W "$WORDS" -- \\\"$CUR) )
}

_vboxmanage_subcommands()
{
    WORDS=$( echo "$subComRaw" \
        | tee >(gawk '/^[ ]{2}[a-z]+/{print $1}') >(\grep -Po '(?<=VBoxManage )\w+') > /dev/null \
        | { cat; echo internalcommands ;} )
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}

_vboxmanage_options() 
{
    if [ "$1" = value ]; then
        WORDS=$( echo $subComRaw \
            | sed -E -e ':Y s/<[^><]*>//g; tY; :Z s/\([^)(]*\)//g; tZ; s/'"$COM1 $COM2"'/\a/g' \
                     -e 's/.*'"${PREV%%+([0-9])}"'[0-9]* ([^][]+).*/\1/; tX; d' \
                     -e ':X / --?[[:alnum:]]+|\a/d; s/[^[:alnum:]-]/\n/g' )
        [ -z "$WORDS" ] && _vboxmanage_else_words
    else 
        local GREP="grep -Po -- '(?<![a-z])-[[:alnum:]-]+=?'"
        if [ "$COMP_CWORD" = 1 ]; then
            WORDS=$( echo "$subComRaw" \
                | sed -En '/General Options:/,/Commands:/p' | eval "$GREP" )
        elif [[ $COM2 = internalcommands && $COMP_CWORD -ge 3 ]]; then
            WORDS=$( echo "$subComRaw" \
                | sed -En '/^ *'"${COMP_WORDS[2]}"'/,/^$/{ s/\b[0-9]+-([0-9]+|N)//g; p}' | eval "$GREP" )
        else
            WORDS=$( echo "$subComRaw" | sed -En 's/\b[0-9]+-([0-9]+|N)//g; p' | eval "$GREP" )
        fi
    fi
    
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}

_vboxmanage_else_words()
{
    WORDS=$( echo $subComRaw \
            | sed -E -e 's/([[:alnum:]]+)\[([[:alnum:]]+)]/\1\2/g;' \
                     -e ':X s/\[[^][]*\]//g; tX; :Y s/<[^><]*>//g; tY; :Z s/\([^)(]*\)//g; tZ' \
                     -e 's/'"$COM1 $COM2"'//g; s/[^[:alnum:]=-]/ /g' \
            | gawk '{ for (i=1; i<=NF; i++) { if ($i ~ /^[[:alpha:]][[:alnum:]-]+=?$/) print $i }}' )
    COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
}

_vboxmanage_main() 
{
    local CUR=${COMP_WORDS[COMP_CWORD]}
    local PREV=${COMP_WORDS[COMP_CWORD-1]}
    local COM1=VBoxManage
    local COM2=${COMP_WORDS[1]}
    local WORDS subComRaw
    local IFS=$' \t\n'

    [ "$COMP_CWORD" = 1 ] && COM2=""
    subComRaw=$( $COM1 $COM2 |& tail -n +3 | sed 's/\[  \+\(USB|NVMe|VirtIO]\)/\1/' )

    if [[ $CUR =~ ^[0-9]+$ && -n $_vboxmanage_vmname ]]; then
        _vboxmanage_number

    elif [[ $COM2 = internalcommands && $COMP_CWORD -eq 2 ]]; then
        WORDS=$( echo "$subComRaw" | grep -Po '(?<=^  )([a-z]+)' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )

    elif [[ $CUR =~ ^- ]]; then
        _vboxmanage_options
    
    elif [ "$PREV" = --ostype ]; then
        WORDS=$( $COM1 list ostypes | sed -En 's/^ID:\s+//p' )
        COMPREPLY=( $(compgen -W "$WORDS" -- $CUR) )
    
    elif [[ $CUR =~ ^\" ]]; then
        _vboxmanage_double_quotes

    elif [ "$COMP_CWORD" = 1 ]; then
        _vboxmanage_subcommands

    elif [[ $subComRaw =~ ${PREV}[^\ $'\n']*\ +"<"[^\>]*"vmname"[^\>]*">" ]]; then

        _vboxmanage_vmname vmname

    elif [ "$PREV" = --snapshot ] || 
         [[ $subComRaw =~ ${PREV}[^\ $'\n']*\ +"<snapshot-name" ]]; then

        _vboxmanage_vmname snapshot-name
    
    elif [[ $PREV =~ ^- ]]; then
        _vboxmanage_options value
    else
        [ "$COM2" != internalcommands ] && _vboxmanage_else_words
    fi
}

_vboxmanage() {
    set -o noglob

    _vboxmanage_main

    [ "${COMPREPLY: -1}" = "=" ] && compopt -o nospace
    set +o noglob
}

complete -F _vboxmanage vboxmanage VBoxManage
