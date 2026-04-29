# Cos72

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)All contract are here： https://github.com/jhfnetboy/Cos72-contracts/tree/dev
## Introduction

Yet Another DAO/Community Tool, BUT: get a Gasless,NFT,Contract Account, and ENS, with your Email on any Super Chain. 
Initiate for Superhack 2024 hackathon. 
Build based on: 
+ Super Chain(Optimism OP Stack)
+ Push Protocol
+ ETHPaymaster
+ AirAccount 
+ CometENS(ENS).

### Version
0.1.1

### Abilities:
1. Easy to get your Ethereum contract account by Email. ✓
2. Create your community onchain in seconds. ✓（op+base）
3. Launch a event and share with your members to join.（login and join）✓
4. Drop event NFT by on-chain lists after event.(todo? batch send to fixed addresses?)
5. Mint event NFT in any Superchain gasless.(Base gassless, paymaster deploy, airaccount support change network create account?) ✓
6. Send and get on-chain message by EPNS protocol.(integration with Xu branch) ✓

### Security:
1. Using your Email to create a contract account.
2. Encrypt and verify every action by your fingerprint(passkey).
3. Community account would not save too much assets, NFT, SBT or community points.
4. Social recovery support(developing).

### Infra
1. Use SuperChain from OP to Base and more, autodeploy.
2. Use ETHPaymaster and AirAccount support gasless and account life management.
3. Use Push Protocol(EPSN, Ethereum Push Notification Service) to send and get community nonitfications.
4. Mint PUSH TOKEN in testnet via [sepolia.etherscan.io](https://sepolia.etherscan.io/token/0x37c779a1564DCc0e3914aB130e0e787d93e21804#writeContract#F5)

## Install
### Install on local
All data are saved on-chain. So you can run it anywhere with a one-key install script.

```
git clone git@github.com:AAStarCommunity/Cos72.git
```

### Access to AAStar version
AAStar clones and runs a version online. It is open-source and free for all.

# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type aware lint rules:

- Configure the top-level `parserOptions` property like this:

```js
export default {
  // other rules...
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: ['./tsconfig.json', './tsconfig.node.json'],
    tsconfigRootDir: __dirname,
  },
}
```

- Replace `plugin:@typescript-eslint/recommended` to `plugin:@typescript-eslint/recommended-type-checked` or `plugin:@typescript-eslint/strict-type-checked`
- Optionally add `plugin:@typescript-eslint/stylistic-type-checked`
- Install [eslint-plugin-react](https://github.com/jsx-eslint/eslint-plugin-react) and add `plugin:react/recommended` & `plugin:react/jsx-runtime` to the `extends` list

## License

This project is licensed under the [Apache License, Version 2.0](LICENSE).  
Copyright 2024-present MushroomDAO Contributors.  
See [NOTICE](./NOTICE) · [TRADEMARK.md](./TRADEMARK.md) · [LICENSE-zh.md](./LICENSE-zh.md) · [TRADEMARK-zh.md](./TRADEMARK-zh.md) for details.
