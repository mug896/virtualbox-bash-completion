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

[![Imgur](http://i.imgur.com/BidMGg7.png?2)](https://www.youtube.com/watch?v=YfjOxnAaiys)

## Installation

Copy contents of virtualbox-bash-completion.sh to ~/.bash_completion  
open new terminal and try completion

#### or

**cp** virtualbox-bash-completion.sh  /etc/bash_completion.d

## Usage

**vmname, snapname** completion start with <kbd>"</kbd> character  

You can see virtualbox command usage  
> vboxmanage command [enter]
