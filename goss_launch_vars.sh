#!/bin/bash

# ==================================================================================== #
# Script:        goss_launch_vars.sh                                                   #
# Descripción:   Emplea un archivo gossfile preconfigurado para realizar tests.        #
#                La elección de qué test se ejecutan viene dada por el modo indicado   #
#                en vars.yaml. Ejecuta, renderiza y ejecuta los tests generando         #
#                documentación de los resultados.                                       #
# ==================================================================================== #

# Colores para la salida
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
AZUL='\033[0;34m'
NC='\033[0m' 

# Archivo de configuración que contiene el modo de operación
ARCHIVO_CONFIGURACION="vars.yaml"

# Nombre del archivo Goss de entrada
ARCHIVO_GOSS="gossfile_vars.yaml"

# Archivo renderizado final que contendrá todos los tests combinados
ARCHIVO_RENDERIZADO="./tmp_rendered.yaml"

# Archivos de salida para resultados
SALIDA_TAP="tmp_tap.txt"
RESULTADOS_CATEGORIZADOS="tmp_categorizados.txt"
RESULTADOS_ERROR="goss_error.txt"
RESULTADOS_OK="goss_ok.txt"

#=============================================================================
# Validación inicial
#=============================================================================

# Verificar que existan los archivos necesarios
if [[ ! -f "$ARCHIVO_CONFIGURACION" ]]; then
    echo -e "${ROJO}Error: No se encontró el archivo de configuración $ARCHIVO_CONFIGURACION${NC}"
    exit 1
fi

if [[ ! -f "$ARCHIVO_GOSS" ]]; then
    echo -e "${ROJO}Error: No se encontró el archivo Goss $ARCHIVO_GOSS${NC}"
    exit 1
fi

#=============================================================================
# Proceso de renderizado
#=============================================================================

echo -e "${AZUL}Iniciando renderizado de tests Goss...${NC}"
echo "# Archivo renderizado de pruebas Goss" > "$ARCHIVO_RENDERIZADO"

if ! goss --gossfile "$ARCHIVO_GOSS" --vars "$ARCHIVO_CONFIGURACION" render >> "$ARCHIVO_RENDERIZADO"; then
    echo -e "${ROJO}Error al renderizar el archivo Goss${NC}"
    exit 1
fi

echo -e "${VERDE}Archivo renderizado creado: $ARCHIVO_RENDERIZADO${NC}"

# Ejecutar validación y generar salida TAP
goss --gossfile "$ARCHIVO_RENDERIZADO" validate -f tap > "$SALIDA_TAP"

# Categorizar resultados
echo -e "Categorizando resultados..."
> "$RESULTADOS_CATEGORIZADOS"

# Definir categorías
declare -A categorias=(
    ["Comandos"]="Command:"
    ["Paquetes"]="Package:"
    ["Archivos"]="File:"
    ["Servicios"]="Service:"
    ["Usuarios"]="User:"
    ["Puertos"]="Port:"
    ["ParametrosKernel"]="KernelParam:"
    ["Montaje"]="Mount:"
    ["Grupos"]="Group:"
)

# Procesar cada línea y categorizar
while IFS= read -r linea; do
    [[ -z "$linea" ]] && continue

    # Primero verificar si es un skipped (tiene prioridad)
    if [[ "$linea" == *"SKIP"* ]]; then
        echo -e "[SKIP] $linea" >> "$RESULTADOS_CATEGORIZADOS"
        continue
    fi

    categoria_encontrada=false
    for categoria in "${!categorias[@]}"; do
        if [[ "$linea" == *"${categorias[$categoria]}"* ]]; then
            echo -e "[$categoria] $linea" >> "$RESULTADOS_CATEGORIZADOS"
            categoria_encontrada=true
            break
        fi
    done

    [[ "$categoria_encontrada" == false ]] && echo -e "[Otro] $linea" >> "$RESULTADOS_CATEGORIZADOS"
done < "$SALIDA_TAP"

# Ordenar resultados por categoría
sort -o "$RESULTADOS_CATEGORIZADOS" "$RESULTADOS_CATEGORIZADOS"

# Función para organizar resultados
agregar_cabeceras() {
    local archivo_salida=$1
    local tipo=$2

    # Obtener todas las categorías presentes
    categorias_presentes=($(grep -oP '^\[\K[^\]]+' "$RESULTADOS_CATEGORIZADOS" | sort -u))

    # Procesar cada categoría
    for categoria in "${categorias_presentes[@]}"; do
        if [ "$tipo" == "error" ]; then
            resultados=$(grep -E "^\[${categoria}\]" "$RESULTADOS_CATEGORIZADOS" | grep -E "not ok|\[SKIP\]")
        else
            resultados=$(grep -E "^\[${categoria}\]" "$RESULTADOS_CATEGORIZADOS" | grep "ok" | grep -v "not ok" | grep -v "\[SKIP\]")
        fi

        if [ -n "$resultados" ]; then
            echo -e "\n=== ${categoria} ===" >> "$archivo_salida"
            echo "$resultados" | sed 's/^\[[^]]*\] //' >> "$archivo_salida"
        fi
    done
}

# Procesar resultados fallidos/skipped
echo "RESULTADOS DE PRUEBAS FALLIDAS/SKIPPED" > "$RESULTADOS_ERROR"
agregar_cabeceras "$RESULTADOS_ERROR" "error"

# Procesar resultados exitosos (excluyendo SKIPPED)
echo "RESULTADOS DE PRUEBAS EXITOSAS" > "$RESULTADOS_OK"
agregar_cabeceras "$RESULTADOS_OK" "ok"


# Contar resultados
TOTAL_OK=$(grep "^ok" "$SALIDA_TAP" | grep -vc "# SKIP")  # Solo OK sin SKIP
TOTAL_NOT_OK=$(grep -c "^not ok" "$SALIDA_TAP")           # NOT OK
TOTAL_SKIP=$(grep -c "# SKIP" "$SALIDA_TAP")              # SKIP 
TOTAL_TESTS=$((TOTAL_OK + TOTAL_NOT_OK + TOTAL_SKIP))     # Total de tests

echo -e "\n${BLANCO}==================== Resumen de Resultados ===================="
echo -e "=  ${VERDE}Tests realizados: $TOTAL_TESTS"
echo -e "=  ${VERDE}Exitos: $TOTAL_OK -> ${RESULTADOS_OK}${BLANCO}"
echo -e "=  ${ROJO}Errores: $TOTAL_NOT_OK -> ${RESULTADOS_ERROR}${BLANCO}"
echo -e "=  ${AZUL}Skipped: $TOTAL_SKIP -> ${RESULTADOS_ERROR}${BLANCO}"
echo -e "${BLANCO}================================================================"


# Limpieza de archivos temporales
rm -f "$ARCHIVO_RENDERIZADO" "$RESULTADOS_CATEGORIZADOS" "$SALIDA_TAP"

echo -e "\n${VERDE}Proceso completado${BLANCO}"
#===================================EOF=======================================
