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
# GNU Screen/tmux session name to expect the server to be in:
session_name="minecraft"
# Uncomment one of the two, depending on if you're using screen or tmux
mux_cmd=screen
#mux_cmd=tmux
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
# Let users start a new day
## TODO: use a list of allowed users
### I added the base for doing that
use_day="false"
# Let users turn creative on/off
use_creative="true"
# The file to store allowed creative users
creative_list="$mcbot/creative.txt"

# Create online list:
cat /dev/null > "$online_list"

# Create the $creative_list if it doesn't exist
# Please make sure the case of the usernames in this file match their users if editing
# this file manually. Otherwise, just use the provided op command creative add
if [[ ! -e "$creative_list" ]]; then
    cat /dev/null > "$creative_list"
fi

if [[ -z "$mux_cmd." ]]; then
    echo "You need to choose between screen and tmux"
    exit 1
fi

main () {
# Script main function; takes a $line and decides what to do with it
# $4 is usually the username; everything else depends on the context

    auth_user () {
    # Checks if user is in file. This is case sensitive. Don't be lazy.
    # First argument is the file to auth against.  Second is the user.
    # The optional third and fourth arguments are [add|del|list] and the issuer..
    # If only two args are given, the only return value is true.
    # If the third argurment is given and it is 'list' the first is considered the issuer
        if [[ -z "$3" ]]; then
            while read -r line; do
                if [[ "$line" == "$2" ]]; then
                    echo "true"
                    break
                fi
            done < "$1"
        else
            case "$3" in
                "add")
                    if [[ "$(auth_user $1 $2)" != "true" ]]; then
                        echo "$2" >> "$1"
                    fi
                    ;;
                "del")
                    if [[ "$(auth_user $1 $2)" == "true" ]]; then
                        sed -i -e '/'"$2"'/d' "$1"
                    fi
                    ;;
                "list")
                    local output="$(while read -r line; do echo -n $line', ';done < $1)"
                    tell "$2" "${output%', '}"
                    ;;
            esac
        fi
    }

    send_cmd () {
    # The base function for sending commands to the server.
    # Anything passed to this function is sent to the server.
    # We send a blank newline to clear anything that might be in the
    # console already.  Thanks for the idea, Dagmar.
        echo "sending \"$*\""
        case $mux_cmd in
            "tmux")
                tmux send-keys -t $session_name:0 "$*" C-m
                ;;
            "screen")
                screen -p 0 -S $session_name -X eval "stuff \015\"$*\"\015"
                ;;
            *)
                echo "mux_cmd invalid"
                exit 1
        esac
    }

    tell () {
    # Whispers to the user; first argument should be the username
    # Note: we have 47 chars to work with per line before the server starts
    # splitting the lines up.  We should do that ourselves eventually. We have
    # 20 lines of scrollback as well.
        send_cmd "tell" "$*"
    }

    tell_file () {
    # reads a file line by line and sends it to the user; takes a username and
    # what file to read as arguments
        while read -r line; do
            tell "$1" "$line"
        done < "$2"
    }

    tell_help () {
    # Tells user the help file.  Takes a user as an argument.
        tell_file "$1" "$help_file"
    }

    tell_op_help () {
    # Appends OP help comments.  Takes a user as an argument.
        tell "$1" "Additionally, you have /seen"
        tell "$1" "and /tp user works"
        tell "$1" "and /day"
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
            tell "$1" "You're the only one here, $1."
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
        write_file "$user_dir/$1/last_seen" "$(date '+%A, %B %d at %R')"
        tell_motd "$1"
    }

    log_out () {
    # removes user from the online_list; takes a username as an argument
        echo "$1 logged out"
        sed -i -e '/'"$1"'/d' "$online_list"
    }

    list_users () {
    # provides the list command; takes a username as an argument
        if [[ "$(count_users)" -eq 1 ]]; then
            tell "$1 You're the only one here, $1."
        else
            local output="$(while read -r line; do echo -n $line', ';done < $online_list)"
            tell "$1" "Players online: $(count_users)"
            tell "$1" "${output%', '}"
        fi
    }


    tp_user () {
    # Teleports the first player to the second
        if [[ -z "$2" ]]; then
            tell "$1 You must specify a user to teleport to."
        else
            send_cmd "tp $1 $2"
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
            tell "$1" "That's you, silly!"
        elif [[ "$(grep -i $2 $online_list)" ]]; then
            tell "$1" "That user is online!"
        elif [[ -e "$user_dir/$(ls $user_dir/ | grep -i $2)/last_seen" ]]; then
            tell "$1" "$2 was last logged in on:"
            tell "$1" "$(cat $user_dir/$(ls $user_dir/ | grep -i $2)/last_seen)"
        else
            tell "$1" "No information on that user available. Try one of $(ls -x $user_dir)"
        fi
    }

    set_creative () {
    # Allows player to turn creative mode on or off for themselves.
    # For normal users, we accept the username and [on|off].
    # If the second argument is [add|del|list],then the third argument is the target user and the
    # the first is the issuer.
        case "$2" in
            "on")
                if [[ "$(auth_user $creative_list $1)" == "true" || "$(auth_user $server_path/ops.txt $1)" == "true" ]]; then
                    send_cmd "gamemode $1 1"
                fi
                ;;
            "off")
                send_cmd "gamemode $1 0"
                ;;
            "add")
                echo $3
                auth_user "$creative_list" "$3" "add"
                ;;
            "del")
                auth_user "$creative_list" "$3" "del"
                ;;
            "list")
                auth_user "$creative_list" "$1" "list" "$1"
                ;;
            *)
                tell "$1" "Invalid option for creative command."
                ;;
        esac
    }


    mail () {
    # Simple mail system.  Each user has nine mail slots.  We'll name the
    # messages with their timestamp and store those in an array.  Each 'slot'
    # will just reference that message's array index+1.  Message 1 is newest
    # and 9 is oldest.  Each message will have three variables, sender, recipient,
    # and the message body.  Takes a username, action to perform
    # (read/send/unread), and anything after is treated as something to
    # be passed to the supporting function.
        local mail_dir="$user_dir/$1/mail"
        mail_count () {
        # Takes a username as an argument and returns the number of unread
        # and and total number of messages.
            if [[ ! -x "$mail_dir" ]]; then
                tell "$1" "No mail."
            else
                local messages="$(find $mail_dir type -f)"
                if [[ "${#messages}" -eq 0 ]]; then
                    tell "$1" "No mail."
                else
                    local unread_count=0
                    for mail in "$messages"; do
                        source "$mail_dir/$mail"
                            if [[ "$unread" == "true" ]]; then
                                (( ++unread_count ))
                            fi
                    done
                    tell "$1" "You have $unread_count unread out of ${#messages} message(s)."
                fi
            fi
        }

        mail_read () {
        # We still need to figure out how to store the mail for this to work.
        # probably takes a user as an argument, the second argument will
        # probably be some pointer to the desired message to read.
            sleep 0
        }

        mail_delete () {
        # Provision to delete a message.  As usuall, we'll take a user as the
        # first argument, and then some reference to the message as the second.
            sleep 0
        }

        mail_send () {
        # Send's mail to user. Takes the from, to, and body of the message
        # as the arguments.
            sleep 0
        }
    }

    die () {
    # Breaks out of the loop and does a little housekeeping
        rm -f "$online_list"
        break
    }

    # Parse log expecting non-op user
    if [[ "$6" == "command:" ]]; then
        case "$7" in
            "motd")
                tell_motd "$4" ;;
            "list")
                list_users "$4" ;;
            "seen")
                seen_user "$4" "$8" ;;
            "help")
                tell_help "$4" ;;
            "tp")
                tp_user "$4" "$8" ;;
            "get")
                 if [[ "$use_get" == "true" ]]; then
                    get "$4" "$8" "$9"
                fi;;
            "day")
                #TODO: list of users instead
                if [[ "$use_day" == "true" ]]; then
                    send_cmd "time set 1"
                fi;;
            "creative")
                if [[ "$use_creative" == "true" && "$8" != "add" && "$8" != "del" && "$8" != "list" ]]; then
                    set_creative "$4" "$8"
                fi;;
        esac
    # Parse log for op user
    elif [[ "$5 $6 $7" == "issued server command:" ]]; then
        case "$8" in
            "help")
                tell_op_help "$4" ;;
            "seen")
                seen_user "$4" "$9" ;;
            "tp")
                tp_user "$4" "$9" ;;
            "day")
                send_cmd "time set 1" ;;
            "creative")
                set_creative "$4" "$9" "${10}" ;;
        esac
    elif [[ "$6 $7 $8 $9 ${10}" == "logged in with entity id" ]]; then
        log_in "$4"
    elif [[ "$5 $6" == "lost connection:" ]]; then
        log_out "$4"
    elif [[ "${line:27:30}" == "CONSOLE: Stopping the server.." ]]; then
        die
    fi
}

tail -Fn0 "$server_path/server.log" | \
while read line; do
    main $line
done
