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
  <a href="https://github.com/Zodomo/AlignedWithRemilia">
    <img src="images/smiley.png" alt="Remilia Logo" width="80" height="80">
  </a>

<h3 align="center">Remilia Alignment Module</h3>

  <p align="center">
    An abstract contract that can be inherited to align an ERC721 project with Remilia's Network Spirituality.
    <br />
    <a href="https://github.com/Zodomo/AlignedWithRemilia/issues">Report Bug</a>
    ·
    <a href="https://github.com/Zodomo/AlignedWithRemilia/issues">Request Feature</a>
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

This is an abstract contract intended to align NFT collections with Remilia's vision for Network Spirituality by deepening Milady liquidity using mint fees. 
It is designed such that the developer (or other recipient) can receive up to 50% of the mint fees, while the remainder is dedicated to deepening Milady NFTX liquidity. 
Once $MILADYWETH LP tokens are staked, they are to be timelocked forever/permanently. True alignment means this liquidity shouldn't ever be withdrawn. 
$xMILADYWETH is timelocked instead of being burned, as LP rewards should be claimable.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Ethereum][Ethereum.com]][Ethereum-url]
* [![Solidity][Solidity.sol]][Solidity-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

AlignedWithRemilia was designed using Foundry, so I recommend familiarizing yourself with that if required.

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
2. Install AlignedWithRemilia
   ```sh
   forge install zodomo/AlignedWithRemilia --no-commit
   ```
3. Import AlignedWithRemilia<br />
   Add the following above the beginning of your project's primary contract
   ```solidity
   import "AlignedWithRemilia/AlignedWithRemilia.sol";
   ```
4. Inherit the module<br />
   Add the following to the contract declaration
   ```solidity
   contract ProjectName is AlignedWithRemilia {}
   ```
5. Utilize each function as required<br />
   A deeper understanding of Solady is required to continue beyond this point

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

TODO: Summarize all functions


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

Distributed under the VPL License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Zodomo - [@0xZodomo](https://twitter.com/0xZodomo) - zodomo@proton.me - Zodomo.eth

Project Link: [https://github.com/Zodomo/AlignedWithRemilia](https://github.com/Zodomo/AlignedWithRemilia)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

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