SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 

$SCRIPT_DIR/install_base_deps.sh
$SCRIPT_DIR/install_foundry_deps.sh
$SCRIPT_DIR/install_circuit_deps.sh