#!/usr/bin/env bash
###################
# mcbot.sh
# version 0.7
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
# World name/directory
world_dir="$server_path/world"
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
# The time to wait before teleporting
tp_wait="5"
# The file to stor the last user who logged out
last_user="$mcbot/last_user"

# Create online list:
cat /dev/null > "$online_list"

# Create the $creative_list if it doesn't exist
# Please make sure the case of the usernames in this file match their users if editing
# this file manually. Otherwise, just use the provided op command creative add
if [[ ! -e "$creative_list" ]]; then
    cat /dev/null > "$creative_list"
fi

if [[ ! -e "$last_user" ]]; then
    echo -e "last_username=\"\"\n" > "$last_user"
fi

if [[ -z "$mux_cmd." ]]; then
    echo "You need to choose between screen and tmux"
    exit 1
fi

main () {
# Script main function; takes a $line and decides what to do with it
# $4 is usually the username; everything else depends on the context

    format_secs () {
    # Converts seconds into the hh:mm:ss
        local time_secs="$1"
        local days="$((time_secs / 86400))"
        local time_secs="$((time_secs % 86400))"
        local hours="$((time_secs / 3600))"
        local time_secs="$((time_secs % 3600))"
        local minutes="$((time_secs / 60))"
        local seconds="$((time_secs % 60))"
        if [[ "$days" -eq 0 ]]; then
            unset days
            if [[ "$hours" -eq 0 ]]; then
                unset hours
                if [[ "$minutes" -eq 0 ]]; then
                    unset minutes
                fi
            fi
        fi
        for i in "$days" "$hours" "$minutes" "$seconds"; do
            if [[ -n "$i" ]]; then
                if [[ "${#i}" -eq 1 ]]; then
                    i="0$i"
                fi
                output="$output:$i"
            fi
        done
        if [[ "${#output}" -eq 3 ]]; then
            output="$output seconds"
        elif [[ "${#output}" -eq 6 ]]; then
            output="$output minutes"
        elif [[ "${#output}" -eq 9 ]]; then
            output="$output hours"
        else 
            output="$output days"
        fi
        echo "${output#:}"
    }

    auth_user () {
    # Checks if user is in file.
    # First argument is the file to auth against.  Second is the user.
    # The optional third argument is [add|del|list]
    # If only two args are given, the only return value is true.
    # If the third argurment is given and it is 'list' the first is considered the issuer
        if [[ -z "$3" ]]; then
            if [[ "$(grep -i $2 $1)" ]]; then
                echo "true"
            fi
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
        #if [[ "${#1} -gt 45" ]]; then
            #line="${*#$1}"
            #while true; do
                #send_cmd "tell" "$1 ${line:0:45}"
                #line="${line:45}"
                #if [[ "${#line}" -lt 45 ]]; then
                    #send_cmd "tell" "$1 $line"
                    #break
                #fi
            #done
        #else
            #send_cmd "tell" "$*"
        #fi
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
            source "$last_user"
            login_data "read" "$last_username"
            if [[ -n "$last_username" ]]; then
                local last_duration="$(format_secs $(($(date '+%s') - $last_logout)))"
                tell "$1" "You're the only one here, $1."
                if [[ -n "$last_username" ]]; then
                    if [[ "$1" == "$last_username" ]]; then
                        tell "$1" "You last visited $last_duration ago."
                    else
                        tell "$1" "$last_username was last here $last_duration ago."
                    fi
                fi
            else
                tell "$1" "You're the first person to ever visit!"
            fi
        else
            tell "$1" "There are $(echo $(($count-1))) other users online."
            login_data "read" "$1"
            if [[ -n "$last_logout" ]]; then
                local last_duration="$(format_secs $(($(date '+%s') - $last_logout)))"
                tell "$1" "You last visited $last_duration ago."
            fi
        login_data "unset"
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

    login_data () {
# Writes/reads/unsets user's login data
    # First argument action [read|write|unset].  Second arg is the username
    # If the second arg is write, we expect the last_login_formatted, last_login,
    # last_logout, and played_total values.
        local user_data="$user_dir/$2/login_data"
        if [[ "$1" == "read" ]]; then
            if [[ -e "$user_data" ]]; then
                source "$user_data"
            fi
        elif [[ "$1" == "write" ]]; then
            write_file "$user_data" "last_login_formatted=\"$3\"\nlast_login=\"$4\"\nlast_logout=\"$5\"\nplayed_total=\"$6\"\nstatus=\"$7\""
        elif [[ "$1" == "unset" ]]; then
            unset last_login_formatted
            unset last_login
            unset last_logout
            unset played_total
        fi
    }

    log_in () {
    # Records user to the online_list and records their login time for /seen
    # We also send the motd.  Takes a username as an argument.
        echo "$1" >> "$online_list"
        login_data "read" "$1"
        if [[ -z "$played_total" ]]; then
            played_total=0
        fi
        login_data "write" "$1" "$(date '+%A, %B %d at %R')" "$(date '+%s')" "$last_logout" "$played_total" "online"
        login_data "unset"
    }

    log_out () {
    # removes user from the online_list; takes a username as an argument
        local logout_time="$(date '+%s')"
        echo "$1 logged out"
        login_data "read" "$1"
        local played_total="$(($played_total + $(($logout_time - $last_login))))"
        login_data "write" "$1" "$last_login_formatted" "$last_login" "$logout_time" "$played_total" "offline"
        login_data "unset"
        write_file "$last_user" "last_username=\"$1\"\n"
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
            if [[ "$1" != "$2" ]]; then
                if [[ -n "$(auth_user $online_list $2)" ]]; then
                    tell "$1" "Teleporting to $2 in $tp_wait seconds."
                    tell "$2" "$1 will teleport to you in $tp_wait seconds."
                    sleep "$tp_wait"
                    send_cmd "tp $1 $2"
                else
                    tell "$1" "$2 is not online."
                    tell "$1" "Use /list to see online players."
                fi
            else
                tell "$1" "You cannot teleport to yourself."
            fi
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
        elif [[ "$(echo $user_dir/*/login_data | grep -i $2)" ]]; then
            source "$user_data/$(echo $user_dir/* | grep -io $2)/login_data"
            tell "$1" "$2 was last logged in on:"
            tell "$1" "$last_login_formatted for $(format_secs $(($last_login - $last_logout)))."
        else
            local users="$(for i in $user_dir/*;do echo -n ${i##*/}', '; done)"
            tell "$1" "I don't know who that is. I only know:"
            tell "$1" "${users%', '}"
        fi
    }

    set_creative () {
    # Allows player to turn creative mode on or off for themselves.
    # For normal users, we accept the username and [on|off].
    # If the second argument is [add|del|list],then the third argument is the target user and the
    # the first is the issuer.
        if [[ "$(auth_user $creative_list $1)" == "true" || "$(auth_user $server_path/ops.txt $1)" == "true" ]]; then
            case "$2" in
                "on")
                    send_cmd "gamemode $1 1"
                ;;
                "off")
                    send_cmd "gamemode $1 0"
                ;;
                "add")
                    auth_user "$creative_list" "$3" "add"
                ;;
                "del")
                    auth_user "$creative_list" "$3" "del"
                ;;
                "list")
                    auth_user "$creative_list" "$1" "list"
                ;;
                *)
                    tell "$1" "Invalid option for creative command."
                ;;
            esac
        else
            tell "$1" "You do not have access to that command."
        fi
    }

    played () {
    # Can tell the user stats about play time.  Expects a username. An optional second argument is 
    # 'all'.
        user_played () {
        # Tells the user how long they've been logged in for.  Expects a username.
            login_data "read" "$1"
            local played_time="$(($(date '+%s') - $last_login))"
            local total_time="$(($played_total + $played_time))"
            tell "$1" "You've been online for $(format_secs $played_time) and"
            tell "$1" "have logged a total of $(format_secs $total_time)."
            login_data "unset"
        }
        cumulative_played () {
        # Tells the user the total time played by the entire server.  Expects a username.
            local cumulative_time=0
            for i in "$user_dir"/*; do
                login_data "read" "${i##*/}"
                if [[ "$status" == "online" ]]; then
                    cumulative_time="$(($cumulative_time + $(($(date '+%s') - $last_login)) + $played_total))"
                else
                    cumulative_time="$(($cumulative_time + $played_total))"
                fi
                login_data "unset"
            done
            tell "$1" "There has been a grand total of :"
            tell "$1" "$(format_secs $cumulative_time) played on this server."
        }
        if [[ -z "$2" ]]; then
            user_played "$1"
        elif [[ "$2" == "all" ]]; then
            cumulative_played "$1"
        else
            tell "$1" "Invalid argument to the /played command."
        fi
    }

    world_size () {
    # Tells the user the current world. The available size is kinda specific to my server, as I
    # run it in a ram disk. People are free, of course, to modify this to their needs.
        local size="$(du -hs $world_dir)"
        local available="$(free -m | awk '/buffers\/cache/{print $4}')M"
        tell "$1" "The world is ${size%%$world_dir}/$available."
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
                tell_motd "$4"
            ;;
            "list")
                list_users "$4"
            ;;
            "seen")
                seen_user "$4" "$8"
            ;;
            "help")
                tell_help "$4"
            ;;
            "tp")
                tp_user "$4" "$8"
            ;;
            "get")
                 if [[ "$use_get" == "true" ]]; then
                    get "$4" "$8" "$9"
                fi
            ;;
            "day")
                #TODO: list of users instead
                if [[ "$use_day" == "true" ]]; then
                    send_cmd "time set 1"
                fi
            ;;
            "creative")
                if [[ "$use_creative" == "true" && "$8" == "on" || "$8" == "off" ]]; then
                    set_creative "$4" "$8" "$9"
                fi
            ;;
            "played")
                played "$4" "$8"
            ;;
            "worldsize")
                world_size "$4"
            ;;
        esac
    # Parse log for op user
    elif [[ "$5 $6 $7" == "issued server command:" ]]; then
        case "$8" in
            "help")
                tell_op_help "$4"
            ;;
            "seen")
                seen_user "$4" "$9"
            ;;
            "tp")
                tp_user "$4" "$9"
            ;;
            "day")
                send_cmd "time set 1"
            ;;
            "creative")
                set_creative "$4" "$9" "${10}"
            ;;
            "played")
                played "$4" "$9"
            ;;
            "worldsize")
                world_size "$4"
            ;;
        esac
    elif [[ "$6 $7 $8 $9 ${10}" == "logged in with entity id" ]]; then
        log_in "$4"
        tell_motd "$4"
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
