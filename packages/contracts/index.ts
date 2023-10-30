/* tslint:disable */
/* eslint-disable */
export type { IPoseidonExtT7 } from './src/IPoseidonExtT7';

export type { DepositManager } from './src/DepositManager';
export type { Teller } from './src/Teller';
export type { Handler } from './src/Handler';
export type { JoinSplitVerifier } from './src/JoinSplitVerifier';
export type { SubtreeUpdateVerifier } from './src/SubtreeUpdateVerifier';
export type { TestSubtreeUpdateVerifier } from './src/TestSubtreeUpdateVerifier';
export type { CommitmentTreeManager } from './src/CommitmentTreeManager';
export type { CanonAddrSigCheckVerifier } from './src/CanonAddrSigCheckVerifier';
export type { CanonicalAddressRegistry } from './src/CanonicalAddressRegistry';

export type { IERC20Interface } from './src/IERC20';
export type { IERC721Interface } from './src/IERC721';
export type { IERC1155Interface } from './src/IERC1155';

export type { TransparentUpgradeableProxy } from './src/TransparentUpgradeableProxy';
export type { ProxyAdmin } from './src/ProxyAdmin';
export type { Versioned } from './src/Versioned';
export type { WETH9 } from './src/WETH9';

export type { WstethAdapter } from './src/WstethAdapter';
export type { RethAdapter } from './src/RethAdapter';
export type { EthTransferAdapter } from './src/EthTransferAdapter';
export type { UniswapV3Adapter } from './src/UniswapV3Adapter';
export type { IBalancer } from './src/IBalancer';
export type { ISwapRouter } from './src/ISwapRouter';

export type { SimpleERC20Token } from './src/SimpleERC20Token';
export type { SimpleERC721Token } from './src/SimpleERC721Token';
export type { SimpleERC1155Token } from './src/SimpleERC1155Token';

export { IPoseidonExtT7__factory } from './src/factories/IPoseidonExtT7__factory';

export { DepositManager__factory } from './src/factories/DepositManager__factory';
export { Teller__factory } from './src/factories/Teller__factory';
export { Handler__factory } from './src/factories/Handler__factory';
export { JoinSplitVerifier__factory } from './src/factories/JoinSplitVerifier__factory';
export { SubtreeUpdateVerifier__factory } from './src/factories/SubtreeUpdateVerifier__factory';
export { TestSubtreeUpdateVerifier__factory } from './src/factories/TestSubtreeUpdateVerifier__factory';
export { CommitmentTreeManager__factory } from './src/factories/CommitmentTreeManager__factory';
export { CanonAddrSigCheckVerifier__factory } from './src/factories/CanonAddrSigCheckVerifier__factory';
export { CanonicalAddressRegistry__factory } from './src/factories/CanonicalAddressRegistry__factory';

export { SimpleERC20Token__factory } from './src/factories/SimpleERC20Token__factory';
export { SimpleERC721Token__factory } from './src/factories/SimpleERC721Token__factory';
export { SimpleERC1155Token__factory } from './src/factories/SimpleERC1155Token__factory';
export { WETH9__factory } from './src/factories/WETH9__factory';

export { WstethAdapter__factory } from './src/factories/WstethAdapter__factory';
export { RethAdapter__factory } from './src/factories/RethAdapter__factory';
export { EthTransferAdapter__factory } from './src/factories/EthTransferAdapter__factory';
export { UniswapV3Adapter__factory } from './src/factories/UniswapV3Adapter__factory';

export { IBalancer__factory } from './src/factories/IBalancer__factory';
export { ISwapRouter__factory } from './src/factories/ISwapRouter__factory';

export { TransparentUpgradeableProxy__factory } from './src/factories/TransparentUpgradeableProxy__factory';
export { ProxyAdmin__factory } from './src/factories/ProxyAdmin__factory';
export { Versioned__factory } from './src/factories/Versioned__factory';

export { version } from './package.json';

export async function getPoseidonBytecode(
  contractName: string,
): Promise<string> {
  const fs = await import('fs');
  return await fs.promises.readFile(
    `${__dirname}/poseidon-bytecode/${contractName}.txt`,
    'utf-8',
  );
}
