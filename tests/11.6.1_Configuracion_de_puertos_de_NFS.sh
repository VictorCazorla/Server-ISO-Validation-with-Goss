conf="/etc/nfs.conf"

check_section() {
  local section="$1"
  shift
  local params=("$@")
  local result=0

  awk -v section="$section" -v paramlist="${params[*]}" '
    BEGIN {
      split(paramlist, param_arr, " ")
      for (i in param_arr) {
        count[param_arr[i]] = 0
      }
      found_section = 0
      error = 0
    }
    $0 ~ "^\\["section"\\]" { in_section=1; found_section=1; next }
    /^\[.*\]/ { in_section=0 }
    in_section && !/^[[:space:]]*#/ && NF > 0 {
      for (i in param_arr) {
        param = param_arr[i]
        # Busca la clave exactamente al inicio de la línea (ignorando espacios)
        if ($0 ~ "^[[:space:]]*"param"[[:space:]]*=") {
          count[param]++
          if (count[param] > 1) {
            print "Error: Parámetro duplicado \"" param "\" en sección [" section "]" > "/dev/stderr"
            error = 1
          }
        }
      }
    }
    END {
      if (!found_section) {
        print "Error: Sección [" section "] no encontrada en " FILENAME > "/dev/stderr"
        exit 1
      }
      for (i in param_arr) {
        param = param_arr[i]
        if (count[param] == 0) {
          print "Error: Parámetro \"" param "\" ausente en sección [" section "]" > "/dev/stderr"
          error = 1
        }
      }
      exit error
    }
  ' "$conf" || result=1

  return $result
}


check_section lockd port udp-port || exit 1
check_section mountd port || exit 1
check_section statd port outgoing-port || exit 1

