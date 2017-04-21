_tkctl() {
   local cur prev
   COMPREPLY=()

   COMMANDS="list-versions get-active repository switch-version install delete build pack"
   APPS="apache2 bind php5 postfix dovecot mariadb sqlgrey kerberos subversion modsecurity clamav zabbix openssl"

   cur=${COMP_WORDS[COMP_CWORD]}
   prev=${COMP_WORDS[COMP_CWORD-1]}
   local firstparam="${COMP_WORDS[1]}"
   if [ "$firstparam" == "" ]; then
     case "$cur" in
       *)
         COMPREPLY=( $(compgen -W '-r' -- $cur) )
         ;;
     esac
     return 0
   fi
   case "$prev" in
        "-r")
          COMPREPLY=( $(compgen -W '$COMMANDS' -- $cur) );
          return 0;
          ;;
        "-a")
          COMPREPLY=( $(compgen -W '$APPS' -- $cur) );
          return 0;
          ;;
   esac
}

complete -F _tkctl tkctl
