_vboxmanage_list()
{
    local arg=$1 res i

    test -n "$_vboxmanage_wait" && _vboxmanage_wait= || _vboxmanage_wait=" wait ... "
    echo -n "$_vboxmanage_wait" >&2

    if [[ $arg == snapshot ]]; then
        res=$( $CMD snapshot "$VMNAME" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/"\1"/p' )
    else
        res=$( $CMD list vms | sed -E 's/(.*").*/\1/' )
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

_vboxmanage_quote()
{
    local i
    if [[ $PREV == --snapshot || $HELP =~ "$PREV <snapshot-name>" ]]; then
        WORDS=$( $CMD snapshot "$VMNAME" list | sed -En 's/^\s*Name: (.*) \(UUID:.*/"\1"/p' )
    else
        WORDS=$( $CMD list vms | sed -E 's/(.*").*/\1/' )
    fi
    IFS=$'\n' COMPREPLY=($(compgen -W '$WORDS' -- \\\"$CUR))
}

_vboxmanage_option() 
{
    local arg=$1 i

    if [[ $CMD2 == @(snapshot|encryptvm|controlvm|debugvm|modifynvram|bandwidthctl|\
guestcontrol) ]]; then
        if [[ -n $CMD3 ]]; then
            HELP=$( <<< $HELP sed -En "/$CMD $CMD2 [^ ]+ $CMD3/p" )
        else
            HELP=""
        fi

    elif [[ $CMD2 == @(mediumio|cloudprofile) ]]; then
        if [[ -z $CMD3 ]]; then
            HELP=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' (.*) \w{3,}( .*|$)/\1/p' )
        else
            HELP=$( <<< $HELP sed -En 's/.* '"$CMD3"' (.*)/\1/p' )
        fi

    elif [[ $CMD2 == @(sharedfolder|dhcpserver|extpack|unattended|hostonlynet|\
updatecheck|usbfilter|guestproperty|metrics|natnetwork|hostonlyif|usbdevsource) ]]; then
        if [[ -n $CMD3 ]]; then
            HELP=$( <<< $HELP sed -En "/$CMD $CMD2 $CMD3/p" )
        else
            HELP=""
        fi

    elif [[ $CMD2 == cloud ]]; then
        if [[ -z $CMD3 ]]; then
            HELP=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' (.*) \w{3,} \w{3,}( .*|$)/\1/p' )
        elif [[ -n $CMD3 && -n $CMD4 ]]; then
            HELP=$( <<< $HELP sed -En "s/$CMD $CMD2.* $CMD3 $CMD4(.*)/\1/p" )
        else
            HELP=""
        fi

    elif [[ $CMD2 == internalcommands ]]; then
        if [[ -n $CMD3 ]]; then
            HELP=$( <<< $HELP sed -En '/^ *'"$CMD3"' /,/^$/H; ${g; s/\n/ /g; p}' )
        else
            HELP=""
        fi
    fi

    if [[ $arg != value ]]; then
        WORDS=$( <<< $HELP grep -Po -- '(?<![[:alnum:]])-[[:alnum:]-]+' )
        return
    fi

    if [[ $CMD2 == clonevm ]]; then
        case $PREV in
            --mode)
                WORDS="machine machinechildren all" ;;
            --groups)
                WORDS=$( $CMD list groups ) ;;
        esac

    elif [[ $CMD2 == modifyvm ]]; then
        case $PREV in
            --bridge-adapter[0-9])
                WORDS=$( $CMD list bridgedifs | sed -En 's/^Name:\s+//p' ) ;;
            --host-only-adapter[0-9])
                WORDS=$( $CMD list hostonlyifs | sed -En 's/^Name:\s+//p' ) ;;
            --intnet[0-9])
                WORDS=$( $CMD list intnets | sed -En 's/^Name:\s+//p' ) ;;
            --nat-network[0-9])
                WORDS=$( $CMD list natnets | sed -En 's/^Name:\s+//p' ) ;;
            --host-only-net[0-9])
                WORDS=$( $CMD list hostonlynets | sed -En 's/^Name:\s+//p' ) ;;
            --groups)
                WORDS=$( $CMD list groups ) ;;
            --default-frontend)
                WORDS=$( vboxmanage help startvm | sed -En '/^\s*--type=/{ s///; s/\|//g; p; Q }' )" default" ;;
            --cpu-profile)
                IFS=$'\n' COMPREPLY=($(compgen -P \" -S \" -W $'host\nIntel 8086\nIntel 80286\nIntel 80386' -- "$CUR")) ;;
        esac

    elif [[ $CMD2 == @(cloud|cloudprofile) ]]; then
        case $PREV in
            --provider)
                WORDS=$( $CMD list cloudproviders | sed -En 's/^Short Name:\s+//p' ) ;; 
            --profile)
                WORDS=$( $CMD list cloudprofiles | sed -En 's/^Name:\s+//p' ) ;; 
        esac
        if [[ $CMD2 == cloud && $CMD3 == list && $PREV == --state ]]; then
            case $CMD4 in
                instances) WORDS="running paused terminated" ;;
                images) WORDS="available disabled deleted" ;;
            esac
        fi

    elif [[ $CMD2 == dhcpserver ]]; then
        case $PREV in
            --interface)
                WORDS=$( $CMD list hostonlyifs | sed -En 's/^Name:\s+//p' ) ;;
            --network)
                WORDS=$( $CMD list dhcpservers | sed -En 's/^NetworkName:\s+//p' ) ;;
        esac

    elif [[ $CMD2 == storageattach && $PREV == --storagectl ]]; then
        WORDS=$( $CMD showvminfo "$VMNAME" --machinereadable | sed -En 's/storagecontrollername[0-9]=//p' )
        IFS=$'\n' COMPREPLY=($(compgen -W '$WORDS' -- \\\"$CUR ))
    fi
    
    if [[ -z $WORDS ]]; then
        local opt=${PREV/%[0-9]/N}
        WORDS=$( <<< $HELP sed -En 's/.*'"$opt"'[= ]\[?((\[?(([[:alnum:].:]+-?)*[[:alnum:].:]+)\]?[,|/])+\[?(([[:alnum:].:]+-?)*[[:alnum:].:]+)\]?)]?.*/\1/; tX; b; :X s/[^[:alnum:].:-]/ /g; p' )
    fi
}

_vboxmanage_words()
{
    local RE='[[:alnum:]][[:alnum:]-]'

    if [[ $CMD2 == list ]]; then
        WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"'|--\w+//g; s/\[|]|\|/ /g; p' )

    elif [[ $CMD2 == setproperty ]]; then
        if [[ -z $CMD3 ]]; then
            WORDS=$( $CMD help setproperty | sed -En '/^Description$/,/^Examples$/{ //d; /^[ ]{,3}\w+$/p }' )
        elif [[ $CMD3 == proxymode ]]; then
            WORDS="manual noproxy system"
        elif [[ $CMD3 == hwvirtexclusive ]]; then
            WORDS="on off"
        fi

    elif [[ $CMD2 == @(snapshot|encryptvm|controlvm|debugvm|modifynvram|\
bandwidthctl|guestcontrol) ]]; then
        if [[ -z $CMD3 ]]; then
            WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' [^ ]+ ('"$RE"*')( .*|$)/\1/p' )
        elif [[ $CMD2 == guestcontrol && $PREV == list ]]; then
            WORDS="all files processes sessions"
        elif [[ $CMD2 == controlvm ]]; then
            case $CMD3 in
                setlinkstate[0-9]|nictrace[0-9]|audioin|audioout|vrde|autostart-enabled[0-9])
                    WORDS="on off" ;;
                nic[0-9])
                    WORDS="null nat bridged intnet hostonly generic natnetwork" ;;
                nicpromisc[0-9])
                    WORDS="deny allow-vms allow-all" ;;
                natpf[0-9]) 
                    WORDS="rulename tcp udp host-IP hostport guest-IP guestport" ;;
                clipboard) 
                    if [[ $PREV == clipboard ]]; then
                        WORDS="mode filetransfers"
                    elif [[ $PREV == mode ]]; then
                        WORDS="disabled hosttoguest guesttohost bidirectional"
                    elif [[ $PREV == filetransfers ]]; then
                        WORDS="on off"
                    fi ;;
                draganddrop) 
                    WORDS="disabled hosttoguest guesttohost bidirectional" ;;
                recording)
                    WORDS="on off screens filename videores videorate videofps maxtime maxfilesize" ;;
                webcam)
                    WORDS="attach detach list" ;;
                vm-process-priority)
                    WORDS="default flat low normal high" ;;
                changeuartmode[0-9])
                    WORDS="disconnected serverpipe-name clientpipe-name
                    tcpserverport tcpclienthostname:port filefilename device-name" ;;
            esac
        fi

    elif [[ -z $CMD3 && $CMD2 == @(mediumio|cloudprofile) ]]; then
        WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' .* ('"$RE"'{2,})( .*|$)/\1/p' )

    elif [[ $CMD2 == @(sharedfolder|dhcpserver|extpack|unattended|\
hostonlynet|updatecheck|convertfromraw|usbfilter|guestproperty|metrics|natnetwork|\
hostonlyif|usbdevsource) ]]; then
        if [[ -z $CMD3 ]]; then
            WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' ('"$RE"'*)( .*|$)/\1/p' )
        elif [[ $CMD2 == metrics ]]; then
            WORDS="'*' host vmname metrics-list"
        elif [[ $CMD2 == hostonlyif && $PREV == @(ipconfig|remove) ]]; then
            WORDS=$( $CMD list hostonlyifs | sed -En 's/^Name:\s+//p' )
        fi

    elif [[ $CMD2 == cloud ]]; then
        if [[ -z $CMD3 ]]; then
            WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"'.* ('"$RE"'{2,}) '"$RE"'{2,}( .*|$)/\1/p' )
        elif [[ -z $CMD4 ]]; then
            WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"'.* '"$CMD3"' ('"$RE"'{2,})( .*|$)/\1/p' )
        fi

    elif [[ $CMD2 == @(showmediuminfo|createmedium|modifymedium|mediumproperty|\
closemedium) ]]; then
        if [[ $PREV == $CMD2 ]]; then
            WORDS="disk dvd floppy"
        elif [[ -z $CMD3 && $CMD2 == mediumproperty ]]; then
            WORDS=$( <<< $HELP sed -En 's/'"$CMD $CMD2"' [^ ]+ ('"$RE"'*)( .*|$)/\1/p' )
        fi

    elif [[ $CMD2 == clonemedium ]]; then
        [[ -n $CMD3 && -n $CMD4 && $PREV == $CMD4 ]] && WORDS="disk dvd floppy"

    elif [[ $CMD2 == getextradata ]]; then
        WORDS="keyword enumerate"
    fi
}

_vboxmanage_set_cmds()
{
    local i
    for (( i = 1; i < COMP_CWORD; i++)); do
        [[ ${COMP_WORDS[i]} == @(-q|--nologo) ]] && continue
        [[ ${COMP_WORDS[i]} == "@" ]] && { let i++; continue ;}
        if [[ ${COMP_WORDS[i]} == @(--settingspw|--settingspwfile) ]]; then 
            [[ ${COMP_WORDS[i+1]} == "=" ]] && let i+=2 || let i++
            continue 
        fi
        break
    done
    if (( i < COMP_CWORD )); then
        CMD2=${COMP_WORDS[i]}
        VMNAME=${COMP_WORDS[i+1]#\"} VMNAME=${VMNAME%\"}
    fi
    [[ -z $CMD2 ]] && return
    case $CMD2 in
        sharedfolder|dhcpserver|extpack|unattended|hostonlynet|updatecheck|usbfilter|\
        setproperty|guestproperty|metrics|natnetwork|hostonlyif|usbdevsource|\
        convertfromraw|clonemedium|internalcommands)
            (( i + 1 < COMP_CWORD )) && CMD3=${COMP_WORDS[i+1]}
            if [[ $CMD2 == clonemedium ]] && (( i + 2 < COMP_CWORD )); then
                CMD4=${COMP_WORDS[i+2]}
            fi
            ;;
        snapshot|encryptvm|controlvm|debugvm|modifynvram|bandwidthctl|guestcontrol|\
        mediumproperty)
            (( i + 2 < COMP_CWORD )) && CMD3=${COMP_WORDS[i+2]}
            ;;
        mediumio|cloud|cloudprofile)
            for (( ++i ; i < COMP_CWORD; i++)); do
                if [[ ${COMP_WORDS[i]} == --* ]]; then 
                    [[ ${COMP_WORDS[i+1]} == "=" ]] && let i+=2 || let i++
                    continue 
                fi
                break
            done
            (( i < COMP_CWORD )) && CMD3=${COMP_WORDS[i]}
            if [[ $CMD2 == cloud ]] && (( i + 1 < COMP_CWORD )); then
                CMD4=${COMP_WORDS[i+1]}
            fi
    esac
}
_init_comp_wordbreaks()
{
    if [[ $PROMPT_COMMAND == *";COMP_WORDBREAKS="* ]]; then
        [[ $PROMPT_COMMAND =~ ^:\ ([^;]+)\; ]]
        [[ ${BASH_REMATCH[1]} != "${COMP_WORDS[0]}" ]] && eval "${PROMPT_COMMAND%%$'\n'*}"
    fi
    if [[ $PROMPT_COMMAND != *";COMP_WORDBREAKS="* ]]; then
        PROMPT_COMMAND=": ${COMP_WORDS[0]};COMP_WORDBREAKS=${COMP_WORDBREAKS@Q};\
        "$'PROMPT_COMMAND=${PROMPT_COMMAND#*$\'\\n\'}\n'$PROMPT_COMMAND
    fi
}
_vboxmanage() 
{
    # It is recommended that every completion function starts with _init_comp_wordbreaks,
    # whether or not they change the COMP_WORDBREAKS variable afterward.
    _init_comp_wordbreaks
    [[ $COMP_WORDBREAKS != *@* ]] && COMP_WORDBREAKS+="@"

    local CMD=VBoxManage CMD2 CMD3 CMD4 VMNAME
    local CUR=${COMP_WORDS[COMP_CWORD]}
    [[ ${COMP_LINE:COMP_POINT-1:1} = " " || $COMP_WORDBREAKS == *$CUR* ]] && CUR=""
    local PREV=${COMP_WORDS[COMP_CWORD-1]}
    [[ $PREV == "=" ]] && PREV=${COMP_WORDS[COMP_CWORD-2]}
    local IFS=$' \t\n' WORDS HELP
    _vboxmanage_set_cmds
    if [[ -n $CMD2 ]]; then
        if [[ $CMD2 == internalcommands ]]; then
            HELP=$( $CMD internalcommands )
        else
            HELP=$( $CMD $CMD2 | sed -Ez 's/ *\n {5,}/ /g; s/^([^\n]*\n){1}\n//; s/\n\n+/\n/g; s/ \| /\|/g; s/= /=/g' )
        fi
    fi

    if [[ $CUR == -* ]]; then
        if [[ -z $CMD2 ]]; then
            WORDS="-V --version --dump-build-type -q --nologo --settingspw= --settingspwfile="
        else
            _vboxmanage_option
        fi

    elif [[ $CUR == +([0-9]) && -n $_vboxmanage_list ]]; then
        CUR=$(( 10#$CUR ))
        COMPREPLY=$(<<< $_vboxmanage_list gawk $CUR' == $1+0 {sub(/^[0-9]+) +/,""); print $0; exit}')
        
    elif [[ ${COMP_WORDS[COMP_CWORD]} == "@" || $PREV == "@" ]]; then
        :

    elif [[ $PREV != @(--settingspw|--settingspwfile) && ( -z $CMD2 || $CMD2 == help ) ]]; then
        WORDS=$( $CMD | sed -En 's/^\s*VBoxManage (\w+).*/\1/p' )
        WORDS+=" internalcommands help"

    elif [[ $CMD2 = internalcommands && -z $CMD3 ]]; then
        WORDS=$( <<< $HELP grep -Po '(?<=^  )([a-z]+)' )

    elif [[ ${COMP_WORDS[COMP_CWORD]} == \"* && 
        $PREV != @(--storagectl|--cpu-profile) ]]; then
        _vboxmanage_quote

    elif [[ $PREV == @(--ostype|--os-type) ]]; then
        WORDS=$( $CMD list ostypes | sed -En 's/^ID:\s+//p' )

    elif [[ -z $CUR ]] && [[ $HELP =~ "$PREV <"[^\>]*(vmname|machines?)[^\>]*">" ]]; then
        _vboxmanage_list vmname

    elif [[ -z $CUR ]] && [[ $PREV == --snapshot || $HELP =~ "$PREV <snapshot-name>" ]]; then
        _vboxmanage_list snapshot
    
    elif [[ $PREV == -* && $CMD2 != @(metrics|list) ]]; then
        _vboxmanage_option value

    else
        [[ $CMD2 != internalcommands ]] && _vboxmanage_words
    fi

    [[ -z $COMPREPLY ]] && COMPREPLY=( $(compgen -W '$WORDS' -- $CUR) )
    [[ ${COMPREPLY: -1} == "=" ]] && compopt -o nospace
}
complete -o default -o bashdefault -F _vboxmanage vboxmanage VBoxManage
