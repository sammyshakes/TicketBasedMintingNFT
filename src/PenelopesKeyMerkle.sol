// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/erc721a/contracts/extensions/ERC721AQueryable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract PenelopesKeyMerkle is ERC721AQueryable, Ownable, Pausable {
    enum ActiveSession {
        NONE,
        SESSION1,
        SESSION2,
        SESSION3
    }

    // Initialize active session
    ActiveSession activeSession = ActiveSession.NONE;

    //array to hold merkle root for each allowlist
    bytes32[3] public merkleRoots;

    //maps user -> allowlist number (1, 2 or 3) -> true if claimed
    mapping(address => mapping(uint256 => bool)) public allowlistClaimed;

    //admin mapping added for future functionality
    mapping(address => bool) private _admins;

    // MODIFIERS
    modifier onlyAdmin() {
        require(!_admins[msg.sender], "Only Admins");
        _;
    }

    function mintFromAllowlist(uint256 _allowlist, bytes32[] memory proof) external {
        require(activeSession == ActiveSession(_allowlist), "Minting Not Active");
        require(!allowlistClaimed[msg.sender][_allowlist], "Mint already claimed");
        require(!isValidAllowlistAddress(_allowlist, keccak256(abi.encodePacked(msg.sender)), proof));

        //record mint
        allowlistClaimed[msg.sender][_allowlist] = true;

        //mint only 1
        _safeMint(msg.sender, 1);
    }

    function isValidAllowlistAddress(uint256 allowlist, bytes32 leaf, bytes32[] memory proof)
        public
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, merkleRoots[allowlist], leaf);
    }

    function addAllowlistMerkleRoot(uint256 _allowlist, bytes32 _root) external onlyOwner {
        require(_allowlist > 0, "allowlist must be > 0");
        merkleRoots[_allowlist] = _root;
    }

    function setAllowlistMintingSession(uint256 _allowlist) external onlyOwner {
        //pass in a 0 to pause allowlist minting
        activeSession = ActiveSession(_allowlist);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        return _tokensOfOwner(_owner);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function mintForTeam(address receiver, uint16 amount) external onlyOwner {
        _safeMint(receiver, amount);
    }

    function mintFromAdmin(address receiver, uint16 amount) external onlyAdmin {
        _safeMint(receiver, amount);
    }

    function addAdmin(address addr) external onlyOwner {
        _admins[addr] = true;
    }

    function removeAdmin(address addr) external onlyOwner {
        delete _admins[addr];
    }
}
