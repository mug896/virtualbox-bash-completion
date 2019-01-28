_vboxmanage_else_words()
{
    subCommandRaw=$( echo $subCommandRaw | cut -d ' ' -f3- \
        | sed -r 's/\([^)]+\)|<[^>]+>|\[more options]//g' )

    case $COM2 in
        debugvm | guestcontrol)
            WORDS=$( echo $subCommandRaw \
                | tr '|' ' ' \
                | grep -Po '(?<= |^)\w[\w\-]+\w(?= |$)' \
                | sort -u )
            ;;
        *)
            WORDS=$( echo $subCommandRaw \
                | sed -r 's/(--|=)[[:alnum:]_-]+|\b(on|off|no|yes|[0-9]{2})\b//g' \
                | tr -cs '[:alnum:]_-' ' ' \
                | awk '{ for (i=1; i<=NF; i++) if (length($i) != 1 && index($i,"-") != 1) print $i }' \
                | sort -u )
    esac

    COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
}

_vboxmanage_snapname()
{
    WORDS=$( vboxmanage snapshot "${COMP_WORDS[2]:1:-1}" list | nl -n ln -w2 -s' ' )
    [ $(expr index + "$WORDS" $'\n') -eq 0 ] && WORDS=${WORDS/#/$'-\n'}
    IFS=$'\n'
    COMPREPLY=( $WORDS )
}

_vboxmanage_vmname()
{
    WORDS=$( vboxmanage list vms | nl -n ln -w2 -s' ' )
    [ $(expr index + "$WORDS" $'\n') -eq 0 ] && WORDS=${WORDS/#/$'-\n'}
    IFS=$'\n'
    COMPREPLY=( $WORDS )
}

_vboxmanage_double_quotes()
{
    if [[ $COMP_CWORD -eq 4 \
        && ( $PREV = --snapshot || $subCommandRaw =~ ${PREV}[^\ ]*" <uuid|snapname>" ) ]]
    then
        WORDS=$( vboxmanage snapshot "${COMP_WORDS[2]:1:-1}" list \
            | sed -r 's/.*Name: (.*) \(UUID.*/\\"\1\\"/' )
    else
        WORDS=$( vboxmanage list vms | sed -r 's/"(.*)".*/\\"\1\\"/' )
    fi
    IFS=$'\n'
    COMPREPLY=( $(compgen -W "$WORDS" -- \\\""$CUR") )
}

_vboxmanage_ostype()
{
    WORDS=$( vboxmanage list ostypes | sed -rn 's/^ID: *//p' | sort -u )
    COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
}

_vboxmanage_subcommands()
{

    WORDS=$( vboxmanage | sed '1,/Commands:/d;/Medium content access:/,$d' \
        | cut -d ' ' -f3 | sort -u )
    WORDS+=" mediumio extpack debugvm unattended internalcommands"
    COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
}

_vboxmanage_options() 
{
    if [ $COMP_CWORD -eq 1 ]; then
        WORDS=$( vboxmanage | sed -rn '/General Options:/,/Commands:/ s/.*(--\w+).*/\1/p; /Commands:/Q' )
        COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
    else
        WORDS=$( echo $subCommandRaw | grep -Po -- "--[\w-]+" | sort -u )
        COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
    fi
}

_vboxmanage() 
{
    local CUR=${COMP_WORDS[COMP_CWORD]}
    local PREV=${COMP_WORDS[COMP_CWORD-1]}
    local COM1=VBoxManage
    local COM2=${COMP_WORDS[1]}
    local WORDS subCommandRaw subCommand
    local IFS=$' \t\n'
    # prevent globbing in option strings like '[option1] [--option2]'
    set -o noglob

    if [ "$COMP_CWORD" -ge 2 ]; then
        if [[ "$COM2" =~ ^- ]]; then
            return
        else
            case $COM2 in
           
                internalcommands)

                if [ "$COMP_CWORD" -eq 2 ]; then
                    WORDS=$( vboxmanage internalcommands |& grep -Po '(?<=^  )([^ ]+)' )
                    COMPREPLY=( $(compgen -W "$WORDS" -- "$CUR") )
                    return
                fi
                ;;

                *)

                subCommandRaw=$( $COM1 $COM2 | tail -n +3 | tr -s ' ' \
                    | sed -r '2,${s/'"$COM1 $COM2"'//}' )
            esac
            
        fi
    fi

    if [[ $CUR =~ ^- ]]; then
        _vboxmanage_options

    elif [ $COMP_CWORD -eq 1 ]; then
        _vboxmanage_subcommands

    elif [[ $PREV = --ostype ]]; then
        _vboxmanage_ostype

    elif [[ $CUR =~ ^\" ]]; then
        _vboxmanage_double_quotes

    elif [[ $subCommandRaw =~ ${PREV}[^\ ]*" <uuid|vmname>" ]]; then
        _vboxmanage_vmname

    elif [[ $COMP_CWORD -eq 4 &&
            ( $PREV = --snapshot ||
              $subCommandRaw =~ ${PREV}[^\ ]*" <uuid|snapname>" ) ]]; then
        _vboxmanage_snapname

    else
        _vboxmanage_else_words
    fi
    
    set +o noglob
}

complete -F _vboxmanage vboxmanage VBoxManage
