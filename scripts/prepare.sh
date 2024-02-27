#!/bin/bash

# Source the script prelude
source "scripts/_prelude.sh"

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

# Run trusted setup for anonAadhaar
print_action "[core/circom] Running trusted setup for anonAadhaar..."
./scripts/trusted_setup.sh anonAadhaar 21 aadhaar-verifier

# Generate arkzkey for anonAadhaar
print_action "[core/circom] Generating arkzkey for anonAadhaar..."
./scripts/generate_arkzkey.sh anonAadhaar aadhaar-verifier

# Run trusted setup for complex circuit
print_action "[core/circom] Running trusted setup for complex circuit..."
./scripts/trusted_setup.sh complex-circuit 21 complex-circuit-1000k-1000k

# Generate arkzkey for complex circuit
print_action "[core/circom] Generating arkzkey for complex circuit..."
./scripts/generate_arkzkey.sh complex-circuit complex-circuit-1000k-1000k

# Add support for target architectures
print_action "[ffi] Adding support for target architectures..."
cd ${PROJECT_DIR}/mopro-ffi

for target in x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android; do
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

# Install toml-cli binary
print_action "[config] Installing toml-cli..."
if ! command -v toml &> /dev/null
then
    cargo install toml-cli
else
    echo "toml already installed, skipping."
fi

# Check uniffi-bindgen version
print_action "[ffi] Checking uniffi-bindgen version..."
UNIFFI_VERSION=$(uniffi-bindgen --version | grep -oE '0\.25\.[0-9]+' || echo "not found")
EXPECTED_VERSION_PREFIX="0.25"
if [[ $UNIFFI_VERSION != $EXPECTED_VERSION_PREFIX* ]]; then
    echo -e "${RED}Error: uniffi-bindgen version is not 0.25.x. Current version: $(uniffi-bindgen --version)${DEFAULT}"
    echo -e "${RED}Please uninstall uniffi-bindgen and run this script again.${DEFAULT}"
    exit 1
else
    echo "uniffi-bindgen version is $UNIFFI_VERSION, which is acceptable."
fi

print_action "Done! Please run './scripts/build_ios.sh config-example.toml' to build for iOS."