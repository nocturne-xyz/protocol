# Nocturne Protocol
[![Twitter Follow](https://img.shields.io/twitter/follow/norturne_xyz?style=social)](https://twitter.com/nocturne_xyz)
[![Discord](https://img.shields.io/discord/984015101017346058?color=%235865F2&label=Discord&logo=discord&logoColor=%23fff)](https://discord.com/invite/MxZYtzzFmJ)


This repo includes the circuits and smart contracts comprising the Nocturne protocol.

## Getting Started

- `yarn install`
- `yarn install-deps` (installs `gsed`, `circom`, and `foundry` libraries)
- `yarn build` (builds only contracts)
- `yarn test:unit`

### Building circuits

Circuits can be built by running `yarn build:<circuit-name>` from the `circuits` package directory, or `yarn build:all` to build all of them at once.
