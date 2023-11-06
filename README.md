<a name="readme-top"></a>
<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/Zodomo/ERC721M">
    <img src="img/icon.png" alt="Remilia Logo" width="125" height="125">
  </a>

<h3 align="center">ERC721M</h3>

  <p align="center">
    An ERC721 extension that is designed with Network Spirituality in mind.
    <br />
    <br />
    <b>THIS PROJECT IS CURRENTLY UNDERGOING REFACTORING AND IS NOT CONSIDERED PRODUCTION-READY.</b>
    <br />
    <br />
    <a href="https://github.com/Zodomo/ERC721M/issues">Report Bug</a>
    ·
    <a href="https://github.com/Zodomo/ERC721M/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

This is a NFT contract template intended to align NFT collections with Remilia's vision for Network Spirituality by deepening NFT collection liquidity using mint fees. 
It is designed such that the developer (or other recipient) can receive up to 95% of the mint fees, while the remainder is dedicated to deepening an NFT's NFTX liquidity. The developer can align between 5-100% of mint fees.
All funds are directed towards deepening NFTX liquidity for a particular NFT collection and are locked forever. Yield generated by that liquidity can still be claimed.
Liquidity rewards are split 50/50 between the contract owner and the liquidity pool.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Ethereum][Ethereum.com]][Ethereum-url]
* [![Solidity][Solidity.sol]][Solidity-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

ERC721M was designed using Foundry, so I recommend familiarizing yourself with that if required.

### Prerequisites

* Foundry
  ```sh
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

### Installation

1. Set up your NFT project using Foundry
   ```sh
   forge init ProjectName
   ```
2. Install ERC721M
   ```sh
   forge install zodomo/ERC721M --no-commit
   ```
3. Import ERC721M<br />
   Add the following above the beginning of your project's primary contract
   ```solidity
   import "ERC721M/ERC721M.sol";
   ```
4. Inherit the module<br />
   Add the following to the contract declaration
   ```solidity
   contract ProjectName is ERC721M {}
   ```
5. Utilize each function as required<br />
   A deeper understanding of Solady is required to continue beyond this point

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

Once deployed, you must call initialize() and initializeMetadata() to fully prepare the contract. It is recommended that you call disableInitializers() afterwards.
<br />
<br />
changeFundsRecipient() is used to set fundsRecipient. This stored address is referenced to send mint funds to in the event the contract's ownership is renounced.
<br />
<br />
setPrice() sets the standard mint price.
<br />
<br />
openMint() enables purchasing NFTs of normal and discounted (if any) mint types.
<br />
<br />
updateBaseURI() allows the owner to update the metadata of all assets in the collection. lockURI() permanently locks this ability.
<br />
<br />
mint() processes normal mints for the given price. There are no limitations on normal mints.
<br />
<br />
mintDiscount() allows a minter to mint for an alternate price/free if they actively hold a predefined asset. The owner can even specify higher mint prices if they so choose. Each minter is allowed to mint a predefined amount under the discount per asset discount.
<br />
<br />
configureMintDiscount() allows the owner to specify special/free mints based on asset (IERC20 and IERC721) ownership. Each asset is given its own discount tier. Multiple assets cannot be grouped together. Discounts can be freely adjusted after mint is open, as long as the discount supply doesn't decrease beneath already claimed mints.
<br />
<br />
fixInventory() scans the contract's aligned NFT holdership to forward these NFTs to the AlignmentVault. This is only necessary if an NFT was sent with transferFrom rather than safeTransferFrom().
<br />
<br />
checkInventory() this scans the holdings of the AlignmentVault for aligned NFTs and adds them to inventory for processing. This is only necessary if an NFT was sent with transferFrom rather than safeTransferFrom().
<br />
<br />
alignLiquidity() triggers the AlignmentVault to assess the aligned NFT inventory, calculate how many NFTs it can afford to add to the liquidity pool, pairs them with their respective amount of ETH and adds them, and then sweeps all remaining funds into the liquidity pool, lastly staking all LP tokens.
<br />
<br />
claimYield() claims yield generated by the NFTX LP and splits it 50/50 with the owner, automatically restaking its portion.
<br />
<br />
rescueERC20() and rescueERC721() are responsible for withdrawing non-aligned assets. Aligned assets (such as ETH/WETH/NFTX fractionalized tokens/NFTX SLP) are forwarded into the AlignmentVault.
<br />
<br />
withdrawFunds() allows the contract owner to claim their portion of the mint funds.
<br />
<br />
<br />
<br />
An AlignmentVaultFactory has been deployed to <a href="https://etherscan.io/address/0xd7810e145f1a30c7d0b8c332326050af5e067d43">Etherscan</a>. Please use this in your contracts or manually to deploy AlignmentVaults, as it will be cheaper and will utilize the implementation already deployed on-chain. The factory is designed to return the current implementation address by calling the implementation() function.


<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the AGPL-3 License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Zodomo - [@0xZodomo](https://twitter.com/0xZodomo) - zodomo@proton.me - Zodomo.eth

Project Link: [https://github.com/Zodomo/ERC721M](https://github.com/Zodomo/ERC721M)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [MiyaMaker](https://miyamaker.com/)
* [Remilia](https://remilia.org/)
* [Network Spirituality](https://ilongfornetworkspirituality.net/)
* [Solady by Vectorized.eth](https://github.com/Vectorized/solady)
* [Openzeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
* [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
* [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/Zodomo/AlignedWithRemilia.svg?style=for-the-badge
[contributors-url]: https://github.com/Zodomo/AlignedWithRemilia/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Zodomo/AlignedWithRemilia.svg?style=for-the-badge
[forks-url]: https://github.com/Zodomo/AlignedWithRemilia/network/members
[stars-shield]: https://img.shields.io/github/stars/Zodomo/AlignedWithRemilia.svg?style=for-the-badge
[stars-url]: https://github.com/Zodomo/AlignedWithRemilia/stargazers
[issues-shield]: https://img.shields.io/github/issues/Zodomo/AlignedWithRemilia.svg?style=for-the-badge
[issues-url]: https://github.com/Zodomo/AlignedWithRemilia/issues
[product-screenshot]: images/screenshot.png
[Ethereum.com]: https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white
[Ethereum-url]: https://ethereum.org/
[Solidity.sol]: https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black
[Solidity-url]: https://soliditylang.org/
