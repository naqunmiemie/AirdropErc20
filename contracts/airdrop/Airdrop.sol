// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

//  ==========  External imports    ==========
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Internal imports    ==========
import "./IAirdrop.sol";

contract Airdrop is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IAirdrop
{
    /*///////////////////////////////////////////////////////////////
                            State variables
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant MODULE_TYPE = bytes32("Airdrop");
    uint256 private constant VERSION = 1;
    uint256 private constant QUANTITY = 10 ** 18;

    /// @dev address of token being airdropped.
    address public airdropTokenAddress;

    /// @dev address of owner of tokens being airdropped.
    address public tokenOwner;

    /// @dev merkle root of the allowlist of addresses eligible to claim.
    bytes32 public merkleRoot;

    /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from address => total number of tokens a wallet has claimed.
    mapping(address => bool) public supplyClaimedByWallet;

    /*///////////////////////////////////////////////////////////////
                    initializer logic
    //////////////////////////////////////////////////////////////*/

    /// @dev Initiliazes the contract, like a constructor.
    function initialize(address _tokenOwner, address _airdropTokenAddress, bytes32 _merkleRoot) external initializer {
        __ReentrancyGuard_init();

        tokenOwner = _tokenOwner;
        airdropTokenAddress = _airdropTokenAddress;
        merkleRoot = _merkleRoot;
    }

    /*///////////////////////////////////////////////////////////////
                        PausableUpgradeable
    //////////////////////////////////////////////////////////////*/

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /*///////////////////////////////////////////////////////////////
                        Generic contract logic
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the type of the contract.
    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function contractVersion() external pure returns (uint8) {
        return uint8(VERSION);
    }

    /*///////////////////////////////////////////////////////////////
                            Claim logic
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Lets an account claim a given quantity of NFTs.
     *
     *  @param _proofs                         The proof of the claimer's inclusion in the merkle root allowlist
     *                                        of the claim conditions that apply.
     */
    function claim(address _receiver, bytes32[] calldata _proofs) external nonReentrant whenNotPaused {
        address claimer = _msgSender();

        verifyClaim(claimer, _proofs);

        _transferClaimedTokens(_receiver, QUANTITY);

        emit TokensClaimed(_msgSender(), _receiver, QUANTITY);
    }

    /// @dev Checks a request to claim tokens against the active claim condition's criteria.
    function verifyClaim(address _claimer, bytes32[] calldata _proofs) public view {
        require(!supplyClaimedByWallet[_claimer], "address has already claimed.");
        require(merkleRoot != bytes32(0), "merkleRoot not set");
        require(
            MerkleProofUpgradeable.verify(_proofs, merkleRoot, keccak256(abi.encodePacked(msg.sender))),
            "claim fail"
        );
    }

    /// @dev Transfers the tokens being claimed.
    function _transferClaimedTokens(address _to, uint256 _quantityBeingClaimed) internal {
        // if transfer claimed tokens is called when `to != msg.sender`, it'd use msg.sender's limits.
        // behavior would be similar to `msg.sender` mint for itself, then transfer to `_to`.

        supplyClaimedByWallet[_msgSender()] = true;
        require(IERC20(airdropTokenAddress).transferFrom(tokenOwner, _to, _quantityBeingClaimed), "transfer failed");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
