#!/usr/bin/env bash
###################
# mcbot.sh
# version 0.4
# Initially released on 05/01/11
# Written by Zach McCullough
# released under the GNU GPLv3
# which should be included along
# with the copy of this script
###################

source mcbot.properties

touch "$olist"

main () {
# Script main function; takes a $line and decides what to do with it
# $4 is usually the username; everything else depends on the context

    scmd () {
    # The base function for sending commands to the server
    # anything passed to this function is sent to the server
        bash -c "screen -p 0 -S minecraft -X eval 'stuff \"$*\"\015'"
    }

    tell () {
    # Whispers to the user; first argument should be the username
        scmd "tell $*"
    }

    rfile () {
    # reads a file line by line and sends it to the user; takes a username and
    # what file to read as arguments
        while read -r line; do
            tell "$1 $line"
        done < "$2"
    }

    ucount () {
    # Counts the online users; this takes no argument
        wc -l $olist | cut -d" " -f1
    }

    motd () {
    # Message of the day; takes a username as an argument
        count="$(ucount)"
        rfile "$1" "$motd"
        if [[ "$count" -eq 1 ]]; then
            tell "$1 You\047re the only one here, $1"
        else
            tell "$1 There are $(echo $(($count-1))) other users online."
        fi
    }

    hlp () {
    # Tells user the command help; takes a username as an argument
        rfile "$1" "$hfile"
    }

    login () {
    # records username to the online_list and sends the player the motd
    # takes the username as an argument
        echo "$1" >> "$olist"
        motd "$1"
    
    }

    logout () {
    # removes user from the online_list; takes a username as an argument
        sed -i -e '/'"$1"'/d' "$olist"
    }

    lusers () {
    # provides the list command; takes a username as an argument
        if [[ "$(ucount)" -eq 1 ]]; then
            tell "$1 You\047re the only one here, $1"
        else
            tell "$1 Players online: $(ucount)"
            tell "$1 $(xargs -a $olist printf '%s, ' | sed '$s/..$//')"
        fi
    }

    tp () {
    # Teleports the first player to the second
        if [[ -z "$2" ]]; then
            tell "$1 You must specify a user to teleport to."
        else
            scmd "tp $1 $2"
        fi
    }

    get () {
    # Gives user either netherrack or glowtone; takes username, item, [amount]
        wfile () {
        # writes data to file; accepts five mandatory arguments:
        # file to write, date, nrused, gsused, and ssused
            echo -e "udate=$2\nnrused=$3\ngsused=$4\nssused=$5" > "$1"
        }
        dimport () {
        # Imports user data, creates file if it doesn't exist; takes username
            udata="$udir/$1/used_items"
            mydate="$(date +%Y%m%d)"

            if [[ -e "$udata" ]]; then
                source "$udata"
                if [[ "$udate" != "$mydate" ]]; then
                    wfile "$udata" "$mydate" 0 0 0
                    source "$udata"
                fi

            else
                mkdir -p "$udir/$1"
                wfile "$udata" "$mydate" 0 0 0
                source "$udata"
            fi

        }

        amount="$3"

        if [[ -z "$amount" ]];then
            amount=1
        fi

        dimport "$1"
        if [[ -z "$2" ]]; then
            tell "$1 You must specify an item."
            tell "$1 You have:"
            tell "$1 $(($nrlimit - $nrused)) netherrack, $(($sslimit - $ssused)) soulsand, and $(($gslimit - $gsused)) glowstone"
            tell "$1 left today."

        elif [[ "$2" = "netherrack" ]] && \
           [[ "$amount" -le "$nrlimit" ]] && \
           [[ "$(($nrused + $amount))" -le "$nrlimit" ]]; then
            scmd "give $1 87 $amount"
            nrused="$(($nrused + $amount))"

        elif [[ "$2" = "soulsand" ]] && \
             [[ "$amount" -le "$sslimit" ]] && \
             [[ "$(($ssused + $amount))" -le "$sslimit" ]]; then
            scmd "give $1 88 $amount"
            ssused="$(($ssused + $amount))"

        elif [[ "$2" = "glowstone" ]] && \
             [[ "$amount" -le "$gslimit" ]] && \
             [[ "$(($gsused + $amount))" -le "$gslimit" ]]; then
            scmd "give $1 89 $amount"
            gsused="$(($gsused + $amount))"

        else
            tell "$1 Sorry, you can\047t have that\041"
        fi

        wfile "$udata" "$udate" "$nrused" "$gsused" "$ssused"

    }

    die () {
    # Breaks out of the loop and does a little housekeeping
        break
        rm -f "$olist"
    }

    weather() {
    # Tells user the weather; takes a username and a zipcode as an argument.
    # Credit goes to: http://www.commandlinefu.com/commands/view/3831/show-current-weather-for-any-us-city-or-zipcode
    # This requires lynx to be installed
        if [[ -n "$2" ]]; then
            output="$(lynx -dump "http://mobile.weather.gov/port_zh.php?inputstring=$2" | \
            sed 's/^ *//;/ror has occ/q;2h;/__/!{x;s/\n.*//;x;H;d};x;s/\n/ -- /;q';)"
            tell "$1" "The weather outside is: $(echo ${output#*--})"
        else
            tell "$1" "You must specify a zipcode"
        fi
    }

    if [[ "$*" = *"logged in with entity"* ]]; then
        login "$4"

    elif [[ "$*" = *"lost connection: disconnect"* ]]; then
        logout "$4"

    elif [[ "$*" = *"command: motd"* ]]; then
        motd "$4"

    elif [[ "$*" = *"command: list"* ]]; then
        lusers "$4"

    elif [[ "$*" = *"command: tp"* ]]; then
        tp "$4" "$8"

    elif [[ "$*" = *"command: get"* ]] && \
         [[ "useget" = "true" ]]; then
        get "$4" "$8" "$9"

    elif [[ "$*" = *"command: weather"* ]]; then
        weather "$4" "$8"

    elif [[ "$*" = *"command: help"* ]]; then
        hlp "$4"

    elif [[ "$4" = "CONSOLE:"  ]] && \
         [[ "$*" = *"Stopping the server.."* ]]; then
        die

    fi
}

tail -Fn0 "$spath/server.log" | \
while read line; do
    main $line

done