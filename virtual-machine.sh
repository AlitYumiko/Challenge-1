#!/bin/bash

if ! command -v VBoxManage &> /dev/null; then
    echo "ERROR: VirtualBox no está instalado o VBoxManage no está en tu PATH"
    echo "Por favor instala VirtualBox primero"
    exit 1
fi

solicitar_dato() {
    local prompt="$1"
    local var_name="$2"
    local validation_func="$3"
    local default="$4"
    
    while true; do
        read -p "$prompt" "$var_name"
        if [ -z "${!var_name}" ] && [ -n "$default" ]; then
            eval "$var_name=\"$default\""
            break
        elif [ -n "$validation_func" ] && ! $validation_func "${!var_name}"; then
            echo "Entrada no válida. Intente nuevamente."
        else
            break
        fi
    done
}

validar_numero() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

validar_tipo_os() {
    VBoxManage list ostypes | grep -q "$1"
}

clear
echo "=== Configuración de Máquina Virtual ==="

solicitar_dato "Nombre de la VM: " NOMBRE_VM
solicitar_dato "Tipo de SO (ej. Linux_64): " TIPO_OS validar_tipo_os "Linux_64"
solicitar_dato "Número de CPUs: " NUM_CPUS validar_numero 2
solicitar_dato "Memoria RAM (GB): " MEMORIA_GB validar_numero 4
solicitar_dato "VRAM (MB): " VRAM_MB validar_numero 128
solicitar_dato "Tamaño de disco (GB): " DISCO_GB validar_numero 20

echo -e "\n=== Resumen de configuración ==="
echo "Nombre VM: $NOMBRE_VM"
echo "Tipo OS: $TIPO_OS"
echo "CPUs: $NUM_CPUS"
echo "Memoria RAM: ${MEMORIA_GB}GB"
echo "VRAM: ${VRAM_MB}MB"
echo "Disco: ${DISCO_GB}GB"
echo "==============================="

read -p "¿Continuar con la creación? (s/n): " confirmar
if [[ "$confirmar" != [sS] ]]; then
    echo "Creación cancelada."
    exit 0
fi

echo -e "\nCreando máquina virtual '$NOMBRE_VM'..."
VBoxManage createvm --name "$NOMBRE_VM" --ostype "$TIPO_OS" --register

echo "Configurando recursos..."
VBoxManage modifyvm "$NOMBRE_VM" \
    --cpus "$NUM_CPUS" \
    --memory $(("$MEMORIA_GB" * 1024)) \
    --vram "$VRAM_MB" \
    --acpi on \
    --ioapic on

echo "Creando disco virtual de ${DISCO_GB}GB..."
DISCO_VIRTUAL="${NOMBRE_VM}_Disk.vdi"
VBoxManage createhd --filename "$DISCO_VIRTUAL" --size $(("$DISCO_GB" * 1024)) --format VDI

CONTROLADOR_SATA="SATA_Controller"
echo "Configurando controlador SATA..."
VBoxManage storagectl "$NOMBRE_VM" \
    --name "$CONTROLADOR_SATA" \
    --add sata \
    --controller IntelAHCI \
    --portcount 1 \
    --bootable on

VBoxManage storageattach "$NOMBRE_VM" \
    --storagectl "$CONTROLADOR_SATA" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISCO_VIRTUAL"

read -p "¿Desea configurar un controlador IDE para CD/DVD? (s/n): " configurar_ide
if [[ "$configurar_ide" =~ [sS] ]]; then
    CONTROLADOR_IDE="IDE_Controller"
    echo "Configurando controlador IDE..."
    VBoxManage storagectl "$NOMBRE_VM" \
        --name "$CONTROLADOR_IDE" \
        --add ide \
        --controller PIIX4 \
        --bootable on

    VBoxManage storageattach "$NOMBRE_VM" \
        --storagectl "$CONTROLADOR_IDE" \
        --port 0 \
        --device 0 \
        --type dvddrive \
        --medium emptydrive
else
    CONTROLADOR_IDE="No configurado"
fi

echo -e "\nConfiguración finalizada!!"
echo "Nombre VM: $NOMBRE_VM"
echo "Tipo OS: $TIPO_OS"
echo "Recursos:"
echo "  CPUs: $NUM_CPUS"
echo "  Memoria RAM: ${MEMORIA_GB}GB"
echo "  VRAM: ${VRAM_MB}MB"
echo "Disco:"
echo "  Tamaño: ${DISCO_GB}GB"
echo "  Archivo: $DISCO_VIRTUAL"
echo "Controladores:"
echo "  SATA: $CONTROLADOR_SATA"
echo "  IDE: $CONTROLADOR_IDE"
echo "============================="

echo "Máquina virtual creada exitosamente!"
