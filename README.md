## Virtualbox Bash Completion

```sh
bash$ hostnamectl
Operating System: Ubuntu 22.04.1 LTS
          Kernel: Linux 5.15.0-43-generic
    Architecture: x86-64

bash$ vboxmanage --version 
6.1.36r152435

bash$ vboxmanage [tab]
vboxmanage 
adoptstate        createmedium      guestproperty     movevm            storageattach
bandwidthctl      createvm          hostonlyif        natnetwork        storagectl
checkmediumpwd    debugvm           import            registervm        unattended
clonemedium       dhcpserver        internalcommands  setextradata      unregistervm
clonevm           discardstate      list              setproperty       usbdevsource
closemedium       encryptmedium     mediumio          sharedfolder      usbfilter
cloud             export            mediumproperty    showmediuminfo    
cloudprofile      extpack           metrics           showvminfo        
controlvm         getextradata      modifymedium      snapshot          
convertfromraw    guestcontrol      modifyvm          startvm  
```

## Installation

Copy contents of virtualbox-bash-completion.sh to ~/.bash_completion  
open new terminal and try completion !

## Usage

**vmname, snapname** completion can start with <kbd>"</kbd> character  

```sh
bash$ vboxmanage showvminfo "[tab]
"Plan 9"        "Window-10"     "node-2"        
"Ubuntu-20.10"  "node-1"        "node-3" 

bash$ vboxmanage showvminfo "Ub[tab]

bash$ vboxmanage showvminfo "Ubuntu-20.10"
```

```sh
bash$ vboxmanage showvminfo [tab]
1) node-1        3) node-3        5) Ubuntu-20.10  
2) node-2        4) Plan 9        6) Window-10     

bash$ vboxmanage showvminfo 5[tab]

bash$ vboxmanage showvminfo "Ubuntu-20.10"
```

You can see virtualbox command usage with
> vboxmanage command [enter]


