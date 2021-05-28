#!/usr/bin/env bash

print_error()   { echo -e "\e[1m\e[91m[EE] $1\e[0m" ;};
print_warning() { echo -e "\e[1m\e[93m[WW] $1\e[0m" ;};
print_notice()  { echo -e "\e[1m[!!] $1\e[0m" ;};
print_ok()      { echo -e "\e[1m\e[92m[OK] $1\e[0m" ;};
print_pending() { echo -e "\e[1m\e[94m[..] $1\e[0m" ;};

main() {
	check_remote_uinput_access

}

check_local_input_group(){
    if ! id -nG $(id -u)|grep -qw input  ; then 
        echo
        print_warning "local user is not in the input group,"
        print_warning "but /dev/input/* access is required to forward input devices."
        ask_continue_or_exit
    fi
}

check_remote_uinput_access(){
	test -w /dev/uinput || E="noaccess"
	test -r /dev/uinput || E="noaccess"
	
    if [ "$E" = "noaccess" ] ; then
        echo
        print_warning "Remote user is missing R/W access to /dev/uinput"
        print_warning "which is needed to forward input devices."
    else
        print_ok "R/W access to /dev/uinput confirmed"
    fi
}

create_input_files() {
    check_local_input_group
    tmpfile=/tmp/$$devices$$.txt
    sleep 0.1
    timeout=10 #seconds to probe for input devices
    cd /dev/input/

    #Ask user to generate input to auto select input devices to forward
    echo Please, generate input on devices you want to forward, keyboard is mandatory!
    rm $tmpfile &>/dev/null
    for d in event* ; do 
        sh -c "timeout 10 grep . $d -m 1 -c -H |cut -d ":" -f 1 |tee -a $tmpfile &" 
    done 
    echo Waiting 10 seconds for user input...
    sleep $timeout
    list=""
    #Make a list of device names
    rm $EVDFILE &>/dev/null
    for evdevice in $(<$tmpfile) ; do 
        name=$(name_from_event $evdevice|tr " " ".")
        list="$list $name $evdevice off "
        echo $(name_from_event $evdevice)  >> $EVDFILE
    done
    #ask user to select the keyboard device
    echo
    echo "Press a key on the keyboard which will be forwarded."
    KBDDEV=$(inotifywait event* -q | cut -d " " -f 1)
    echo "Got $(name_from_event $KBDDEV)"
    name_from_event $KBDDEV > $KBDFILE

    # create_hk_file
    # uses netevent to generate a file containing the key codes
    # to switch fullscreen and forward devices
        cd /dev/input
        rm $HKFILE &>/dev/null
        sleep 1
        echo ; echo Press the key to forward/unforward input devices
        GRAB_HOTKEY=$(netevent show $KBDDEV 3 -g | grep KEY |cut -d ":" -f 2) ; echo got:$GRAB_HOTKEY
        sleep 0.5
        echo ; echo Press the key to switch fullscreen state
        FULLSCREENSWITCH_HOTKEY=$(netevent show $KBDDEV 3 -g | grep KEY |cut -d ":" -f 2) ; echo got:$FULLSCREENSWITCH_HOTKEY
        echo $GRAB_HOTKEY $FULLSCREENSWITCH_HOTKEY > $HKFILE

        read GRAB_HOTKEY FULLSCREENSWITCH_HOTKEY <<< $(<$HKFILE)
        echo
        echo GRAB_HOTKEY=$GRAB_HOTKEY
        echo FULLSCREENSWITCH_HOTKEY=$FULLSCREENSWITCH_HOTKEY

    rm $tmpfile
}

main "$@"; exit