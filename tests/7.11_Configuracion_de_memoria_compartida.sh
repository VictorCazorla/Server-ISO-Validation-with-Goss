RAM_GB=$(grep MemTotal /proc/meminfo | awk '{printf("%.0f\n", ($2 / 1024 /1024) + 0.5)}'| awk '{print$1 * 1024 * 1024 * 1024}')
echo "RAM detectada: ${RAM_GB} GB"

if [ "$RAM_GB" -le 32 ]; then
 echo "Usando configuración: 7.11_Configuracion_de_memoria_compartida_32.yaml"
 goss -g 7.11_Configuracion_de_memoria_compartida_32.yaml validate
else
 echo "Usando configuración: 7.11_Configuracion_de_memoria_compartida_64.yaml"
 goss -g 7.11_Configuracion_de_memoria_compartida_64.yaml validate
fi

