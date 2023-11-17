# Nocturne Protocol

This repo includes the circuits and smart contracts comprising the Nocturne protocol.

## Getting Started

- `yarn install`
- `yarn install-deps` (installs `gsed`, `circom`, and `foundry` libraries)
- `yarn build` (builds only contracts)
- `yarn test:unit`

### Building Circuits

Circuits can be built by running `yarn build:<circuit-name>` from the `circuits` package directory, or `yarn build:all` to build all of them at once.
