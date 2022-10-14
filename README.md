## Virtualbox Bash Completion

```sh
bash$ hostnamectl
Operating System: Ubuntu 22.04.1 LTS
          Kernel: Linux 5.15.0-43-generic
    Architecture: x86-64

bash$ vboxmanage --version 
7.0.0r153978

bash$ vboxmanage [tab]
adoptstate        createvm          help              modifyvm          startvm
bandwidthctl      debugvm           hostonlyif        movevm            storageattach
checkmediumpwd    dhcpserver        hostonlynet       natnetwork        storagectl
clonemedium       discardstate      import            registervm        unattended
clonevm           encryptmedium     internalcommands  setextradata      unregistervm
closemedium       encryptvm         list              setproperty       updatecheck
cloud             export            mediumio          sharedfolder      usbdevsource
cloudprofile      extpack           mediumproperty    showmediuminfo    usbfilter
controlvm         getextradata      metrics           showvminfo        
convertfromraw    guestcontrol      modifymedium      signova           
createmedium      guestproperty     modifynvram       snapshot
```

## Installation

Copy contents of virtualbox-bash-completion.sh to ~/.bash_completion  
open new terminal and try auto completion !

## Usage

**vmname, snapshot-name** completion can start with <kbd>"</kbd> character.

```sh
bash$ vboxmanage showvminfo "[tab]
"Plan 9"        "Window-10"     "node-2"        
"Ubuntu-20.10"  "node-1"        "node-3" 

bash$ vboxmanage showvminfo "Ub[tab]

bash$ vboxmanage showvminfo "Ubuntu-20.10"
```

```sh
bash$ vboxmanage showvminfo [tab]
1) "node-1"        3) "node-3"        5) "Ubuntu-20.10"  
2) "node-2"        4) "Plan 9"        6) "Window-10"

bash$ vboxmanage showvminfo 5[tab]

bash$ vboxmanage showvminfo "Ubuntu-20.10"
```

Names that end with capital `N` should replace with `[0-9]` number for completion works.

```sh
bash$ vboxmanage controlvm "node-1" nic[tab]
nicN           nicpromiscN    nicpropertyN   nictraceN      nictracefileN  

bash$ vboxmanage controlvm "node-1" nic2 [tab] 
bridged     generic     hostonly    intnet      nat         natnetwork  null

bash$ vboxmanage modifyvm "node-1" --nic[tab]
--nic-bandwidth-groupN  --nic-propertyN         --nic-typeN
--nic-boot-prioN        --nic-speedN            --nicN
. . .
bash$ vboxmanage modifyvm "node-1" --nic2 [tab]             # --nic2=[tab] also works.
bridged      generic      hostonlynet  nat          none         
cloud        hostonly     intnet       natnetwork   null
```

You can see virtualbox command usage with
> vboxmanage command   
> vboxmanage help command (detail version)


