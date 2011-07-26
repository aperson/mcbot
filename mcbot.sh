#!/usr/bin/env bash
###################
# mcbot.sh
# version 0.6
# Initially released on 05/01/11
# Written by Zach McCullough
# released under the GNU GPLv3
# which should be included along
# with the copy of this script
###################

# Lets define some settings first:
# GNU Screen name to expect the server to be in:
screen_name="minecraft"
# Path to the server folder:
server_path="/dev/shm/minecraft_server"
# Path to the folder where mcbot stores things:
mcbot="$server_path/mcbot"
# Location of the help file:
help_file="$mcbot/help"
# Where to store the list of online players:
online_list="$mcbot/online_list"
# Location of the message of the day:
motd_file="$mcbot/motd"
# Location to keep track of user information.
# Every subfolder beyond this are usernames
user_dir="$mcbot/user_data"

# Create online list:
cat /dev/null > "$online_list"

main () {
# Script main function; takes a $line and decides what to do with it
# $4 is usually the username; everything else depends on the context

    send_cmd () {
    # The base function for sending commands to the server.
    # Anything passed to this function is sent to the server.
    # We send a blank newline to clear anything that might be in the
    # console already.  Thanks for the idea, Dagmar.
        screen -p 0 -S minecraft -X eval "stuff \015\"$*\"\015"
    }

    tell () {
    # Whispers to the user; first argument should be the username
        send_cmd "tell $*"
    }

    tell_file () {
    # reads a file line by line and sends it to the user; takes a username and
    # what file to read as arguments
        while read -r line; do
            tell "$1 $line"
        done < "$2"
    }

    tell_help () {
    # Tells user the help file.  Takes a user as an argument.
        tell_file "$1" "$help_file"
    }

    count_users () {
    # Counts the online users; this takes no argument
        local user_count="$(wc -l $online_list)"
        echo "${user_count% *}"
    }

    tell_motd () {
    # Message of the day; takes a username as an argument
        local count="$(count_users)"
        tell_file "$1" "$motd_file"
        if [[ "$count" -eq 1 ]]; then
            tell "$1" "You\047re the only one here, $1."
        else
            tell "$1" "There are $(echo $(($count-1))) other users online."
        fi
    }

    write_file () {
    # Writes data to a file.  First argument should be the full path to the
    # file; we will create the directory if it doesn't exist.  Second
    # argument is what to write to the file. We always overwrite the
    # WHOLE file.
        local base_dir="${1%/*}"
        if [[ ! -e "$base_dir" ]]; then
            mkdir -p "$base_dir"
        fi
        echo -e "$2" > "$1"
    }

    log_in () {
    # Records user to the online_list and records their login time for /seen
    # We also send the motd.  Takes a username as an argument.
        echo "$1" >> "$online_list"
        write_file "$user_dir/$1/last_seen" "$(date "+%A, %B %d at %R")"
        tell_motd "$1"
    }

    log_out () {
    # removes user from the online_list; takes a username as an argument
        sed -i -e '/'"$1"'/d' "$online_list"
    }

    list_users () {
    # provides the list command; takes a username as an argument
        if [[ "$(count_users)" -eq 1 ]]; then
            tell "$1 You\047re the only one here, $1."
        else
            local output="$(while read -r line; do echo -n "$i, ";done < $online_list)"
            tell "$1 Players online: $(count_users)"
            tell "$1" "${output%, }"
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
    # I don't use this on my server anymore, but if you want to enable /get,
    # just have the mcbot_get.sh file in the $mcbot folder.  All its settings
    # are in that file as well.  When I reimplement that, that is.
        if [[ -e "$mcbot/mcbot_get.sh" ]]; then
            source "$mcbot/mcbot_get.sh"
        fi
    }

    seen_user () {
    # Gives the last logged in time of a user.  Takes the requesting user and
    # the user in question as arguments.
    if [[ -z "$2" ]]; then
        tell "$1" "You must specify a user."
    elif [[ "$1" == "$2" ]]; then
        tell "$1" "That\047s you, silly!"
    elif [[ "$(grep $2 $online_list)" ]]; then
        tell "$1" "That user is online!"
    elif [[ -e "$user_dir/$2/last_seen" ]]; then
        tell "$1" "$2 was last logged in on:"
        tell "$1" "$(cat $user_dir/$2/last_seen)"
    else
        tell "$1" "No information on that user available."
    fi
    }

    die () {
    # Breaks out of the loop and does a little housekeeping
        rm -f "$olist"
        break
    }

    if [[ "$6" == "command:" ]]; then
        if [[ "$7" == "motd" ]]; then
            tell_motd "$4"
        elif [[ "$7" == "list" ]]; then
            list_users "$4"
        elif [[ "$7" == "seen" ]]; then
            seen_user "$4" "$8"
        elif [[ "$7" == "help" ]]; then
            tell_help "$4"
        elif [[ "$7" == "get" ]] && \
             [[ "$use_get" == "true" ]]; then
            get "$4" "$8" "$9"
        fi
    elif [[ "$6 $7 $8 $9 ${10}" == "logged in with entity id" ]]; then
        log_in "$4"
    elif [[ "$5 $6 $7" == "lost connection: disconnect" ]]; then
        log_out "$4"
    elif [[ "${line:27:30}" == "CONSOLE: Stopping the server.." ]]; then
        die
    fi

}

tail -Fn0 "$server_path/server.log" | \
while read line; do
    main $line

done