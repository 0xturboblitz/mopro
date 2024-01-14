# Proof of passport mopro

This is a fork of mopro to use with proof of passport.
This will be cleaned and streamlined once mopro is ready and distributed as a pod/cli.

Only modifications:
- proof of passport circuit in `/mopro-core/examples/circom`
- in `mopro-core/build.rs`, added path to the new circuit

Once you have followed the instructions below, copy `mopro-ffi/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a` to `proof-of-passport/app/ios/MoproKit/Libs`

For better performance, build in `release` mode.

# mopro

Making client-side proving on mobile simple (and fast).

## Overview

- `mopro-cli` - core Rust CLI util (NOTE: Very early; use `mopro-core` for now).
- `mopro-core` - core mobile Rust library.
- `mopro-ffi` - wraps `mopro-core` and exposes UniFFI bindings.
- `mopro-ios` - iOS CocoaPod library exposing native Swift bindings.
- `mopro-android` - Android library exposing native Kotlin bindings.
- `mopro-example-app` - example iOS app using `mopro-ios`.
- `ark-zkey` - helper utility to make zkey more usable and faster in arkworks.

## Architecture

The following illustration shows how mopro and its components fit together into the wider ZKP ecosystem:

![mopro architecture (full)](images/mopro_architecture2_full.png)

Zooming in a bit:

![mopro architecture](images/mopro_architecture2.png)

## How to use

### Prepare circuits

-   Install [circom](https://docs.circom.io/) and [snarkjs](https://github.com/iden3/snarkjs)
-   Run `./scripts/prepare.sh` to check all prerequisites are set.

### iOS

#### Prepare

-   Install [cocoapods](https://cocoapods.org/)

#### Build Bindings

To build bindings for iOS simulator debug mode, run

```sh
./scripts/build_ios.sh simulator debug
```

## Community and Talks

Join the Telegram group [here](https://t.me/zkmopro).

Talk by @oskarth at ProgCrypto/Devconnect (Istanbul, November 2023): [Slides](https://docs.google.com/presentation/d/1afIEgm8oYRvteWxUd04CcMOxChAiHaD55d5AKd0RkvY/edit#slide=id.g284ac8f47d5_2_24) (video pending)

## Performance

Preliminary benchmarks on an iPhone 14 Max Pro:

- Keccak256 (150k constraints): 1.5s
    - ~x10-20 faster vs comparable circuit in browser
- anon-aadhaar / RSA Verify: ~6.5s
    - ~5s for witness generation (still in WASM), ~2s prover time
    - 80% of time on witness generation
    - ~x10 faster vs browser on phone
- Bottlenecks: loading zkey and wasm witness generation

## Acknowledgements

This work is sponsored by a joint grant from [PSE](https://pse.dev/) and [0xPARC](https://0xparc.org/).
