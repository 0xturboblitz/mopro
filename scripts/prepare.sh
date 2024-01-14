#!/bin/bash

# Deal with errors
set -euo pipefail

# Color definitions
DEFAULT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREY='\033[0;90m'

# Coloring the -x output (commands)
# DEBUG_COLOR="${DEFAULT}"
# trap 'echo -e ${DEBUG_COLOR}${BASH_COMMAND}${DEFAULT}' DEBUG

# Function to handle exit
handle_exit() {
    # $? is a special variable that holds the exit code of the last command executed
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Script did not finish successfully!${DEFAULT}"
    fi
}

# Set the trap
trap handle_exit EXIT

print_action() {
    printf "\n${GREEN}$1${DEFAULT}\n"
}

print_warning() {
    printf "\n${YELLOW}$1${DEFAULT}\n"
}

# Assert we're in the project root
if [[ ! -d "mopro-ffi" || ! -d "mopro-core" || ! -d "mopro-ios" ]]; then
    echo -e "${RED}Error: This script must be run from the project root directory that contains mopro-ffi, mopro-core, and mopro-ios folders.${DEFAULT}"
    exit 1
fi

PROJECT_DIR=$(pwd)
CIRCOM_DIR="${PROJECT_DIR}/mopro-core/examples/circom"
ARKZKEY_DIR="${PROJECT_DIR}/ark-zkey"

compile_circuit() {
    local circuit_dir=$1
    local circuit_file=$2
    local target_file="$circuit_dir/target/$(basename $circuit_file .circom).r1cs"

    print_action "[core/circom] Compiling $circuit_file example circuit..."
    if [ ! -f "$target_file" ]; then
        ./scripts/compile.sh $circuit_dir $circuit_file
    else
        echo "File $target_file already exists, skipping compilation."
    fi
}

npm_install() {
    local circuit_dir=$1

    if [[ ! -d "$circuit_dir/node_modules" ]]; then
        echo "Installing npm dependencies for $circuit_dir..."
        (cd $circuit_dir && npm install)
    fi
}

# Check for target support
check_target_support() {
    rustup target list | grep installed | grep -q "$1"
}

# Install arkzkey-util binary in ark-zkey
cd $ARKZKEY_DIR
print_action "[ark-zkey] Installing arkzkey-util..."
if ! command -v arkzkey-util &> /dev/null
then
    cargo install --bin arkzkey-util --path .
else
    echo "arkzkey-util already installed, skipping."
fi

# Build Circom circuits in mopro-core and run trusted setup
print_action "[core/circom] Compiling example circuits..."
cd $CIRCOM_DIR

# Setup and compile proof_of_passport
npm_install passport
compile_circuit passport circuits/proof_of_passport.circom

print_action "[core/circom] Running trusted setup for proof_of_passport..."
./scripts/trusted_setup.sh passport 20 proof_of_passport

# Generate arkzkey for proof_of_passport
print_action "[core/circom] Generating arkzkey for proof_of_passport..."
./scripts/generate_arkzkey.sh passport proof_of_passport

# Add support for target architectures
print_action "[ffi] Adding support for target architectures..."
cd ${PROJECT_DIR}/mopro-ffi

for target in x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim; do
    if ! check_target_support $target; then
        rustup target add $target
    else
        echo "Target $target already installed, skipping."
    fi
done

# Install uniffi-bindgen binary in mopro-ffi
print_action "[ffi] Installing uniffi-bindgen..."
if ! command -v uniffi-bindgen &> /dev/null
then
    cargo install --bin uniffi-bindgen --path .
else
    echo "uniffi-bindgen already installed, skipping."
fi

print_action "Done! Please run ./scripts/buld_ios.sh to build for iOS."