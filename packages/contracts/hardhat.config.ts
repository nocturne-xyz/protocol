import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-packager';
import 'hardhat-contract-sizer';

import { subtask } from 'hardhat/config';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';

import * as dotenv from 'dotenv';
dotenv.config();

// NOTE: here to satisfy `hardhat build` validation, not actually used
const DUMMY_KEY =
  '1111111111111111111111111111111111111111111111111111111111111111';

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, __, runSuper) => {
    const paths: string[] = await runSuper();

    return paths.filter(
      (p) =>
        (!p.endsWith('.t.sol') &&
          !p.endsWith('.s.sol') &&
          !p.includes('test')) ||
        p.includes('TestSubtreeUpdateVerifier') ||
        p.includes('SimpleERC20Token') ||
        p.includes('SimpleERC721Token') ||
        p.includes('SimpleERC1155Token') ||
        p.includes('WETH9') ||
        p.includes('IBalancer') ||
        p.includes('SwapRouter'),
    );
  },
);

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
      metadata: {
        bytecodeHash: 'none',
      },
    },
  },

  gasReporter: {
    currency: 'USD',
  },

  networks: {
    // NOTE: hardhat localhost has bug and will always default to using private
    // key #0, if you are deploying to localhost, you must set
    // DEPLOYER_KEY=<private key #0>
    localhost: {
      url: 'http://127.0.0.1:8545',
      accounts: [`${process.env.DEPLOYER_KEY ?? DUMMY_KEY}`],
    },
    goerli: {
      url: `${process.env.GOERLI_RPC_URL}`,
      accounts: [`${process.env.DEPLOYER_KEY ?? DUMMY_KEY}`],
    },
    homestead: {
      url: `${process.env.MAINNET_RPC_URL}`,
    },
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY!,
  },

  typechain: {
    outDir: './src',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },

  // config for hardhat-packager
  // https://www.npmjs.com/package/hardhat-packager
  packager: {
    contracts: [
      'IPoseidonExtT7',
      'IERC20',
      'IERC721',
      'IERC1155',
      'IJoinSplitVerifier',
      'ISubtreeUpdateVerifier',
      'ICanonAddrSigCheckVerifier',
      'ITeller',
      'IHandler',
      'DepositManager',
      'Teller',
      'Handler',
      'CanonicalAddressRegistry',
      'CommitmentTreeManager',
      'BalanceManager',
      'JoinSplitVerifier',
      'SubtreeUpdateVerifier',
      'WstethAdapter',
      'RethAdapter',
      'EthTransferAdapter',
      'UniswapV3Adapter',
      'CanonAddrSigCheckVerifier',
      'SimpleERC20Token',
      'SimpleERC721Token',
      'SimpleERC1155Token',
      'WETH9',
      'IBalancer',
      'ISwapRouter',
      'TestSubtreeUpdateVerifier',
      'TransparentUpgradeableProxy',
      'ProxyAdmin',
      'Versioned',
    ],
    includeFactories: true,
  },
  paths: {
    sources: './contracts',
    cache: './cache_hardhat',
  },
};
