// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/erc721a/contracts/extensions/ERC721AQueryable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";

contract PenelopesKey is ERC721AQueryable, Ownable, Pausable, ERC2981 {
    using ECDSA for bytes32;

    enum ActiveSession {
        NONE,
        ALLOWLIST,
        WAITLIST,
        PUBLIC
    }

    // PUBLIC VARS
    address public allowListSigner;
    address public withdrawAddress;
    address public royaltyAddress;
    uint256 public totalTickets;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxSupply = 6_000;
    mapping(uint256 => uint256) public ticketMap;
    ActiveSession public activeSession = ActiveSession.NONE;
    uint256 private _royaltyPermille = 55; // royalty permille (to support 1 decimal place)
    string private baseURI;

    constructor(address _signer) {
        require(_signer != address(0x00), "Cannot be zero address");
        //set allow list signer
        allowListSigner = _signer;
    }

    function mint(uint256 amount) external payable whenNotPaused {
        require(activeSession == ActiveSession.PUBLIC, "Minting Not Active");
        require(msg.value >= mintPrice * amount, "Did not send enough ether");
        require(totalSupply() + amount <= maxSupply, "Max amount reached");

        //mint
        _safeMint(_msgSender(), amount);
    }

    function mintWithTicket(uint256[] calldata ticketNumbers, bytes[] calldata signatures)
        external
        payable
        whenNotPaused
    {
        require(ticketNumbers.length == signatures.length, "Mismatch Arrays");
        require(totalSupply() + ticketNumbers.length <= maxSupply, "Max amount reached");
        require(ticketNumbers.length < 4, "Max 3 Tickets");
        require(msg.value >= mintPrice * ticketNumbers.length, "Did not send enough ether");

        for (uint256 i; i < ticketNumbers.length; i++) {
            require(
                allowListSigner
                    == getTicket(msg.sender, ticketNumbers[i], uint8(activeSession)).toEthSignedMessageHash().recover(
                        signatures[i]
                    ),
                "ticket not valid"
            );
            claimTicket(ticketNumbers[i]);
        }

        //mint
        _safeMint(_msgSender(), ticketNumbers.length);
    }

    function getTicket(address user, uint256 ticketNumber, uint8 session) public pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(user, ticketNumber, session));
        return hash;
    }

    function claimTicket(uint256 ticketNumber) private {
        require(ticketNumber < totalTickets, "Invalid Ticket Number");
        //get bin and bit
        uint256 bin;
        uint256 bit;
        unchecked {
            bin = ticketNumber / 256;
            bit = ticketNumber % 256;
        }

        uint256 storedBit = (ticketMap[bin] >> bit) & uint256(1);
        require(storedBit == 1, "already minted");

        ticketMap[bin] = ticketMap[bin] & ~(uint256(1) << bit);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        return _tokensOfOwner(_owner);
    }

    function tokenURI(uint256 tokenId) public view override (ERC721A, IERC721A) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (royaltyAddress, (salePrice * _royaltyPermille) / 1000);
    }

    function supportsInterface(bytes4 interfaceId) public view override (ERC721A, IERC721A, ERC2981) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    // OWNER ONLY //
    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function addTickets(uint256 amount) external onlyOwner {
        require(totalTickets + amount <= maxSupply, "Max amount reached");
        //store how many current bins exist
        uint256 currentBins;
        if (totalTickets > 0) currentBins = totalTickets / 256 + 1;

        //calc new amount of bins needed with new tickets added
        totalTickets += amount;
        uint256 requiredBins = totalTickets / 256 + 1;

        //check if we need to add bins
        if (requiredBins > currentBins) {
            uint256 binsToAdd = requiredBins - currentBins;
            for (uint256 i; i < binsToAdd; i++) {
                ticketMap[currentBins + i] = type(uint256).max;
            }
        }
    }

    function setAllowListSigner(address _signer) external onlyOwner {
        require(_signer != address(0x00), "Cannot be zero address");
        allowListSigner = _signer;
    }

    // session input should be:
    // 0 = Inactive, 1 = AllowList, 2 = Waitlist, 3 = Public Sale
    function setSession(uint8 session) external onlyOwner {
        activeSession = ActiveSession(session);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function setBin(uint8 bin) external onlyOwner {
        ticketMap[bin] = type(uint256).max;
    }

    function mintForTeam(address receiver, uint16 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max amount reached");
        _safeMint(receiver, amount);
    }

    function withdraw() external {
        require(withdrawAddress != address(0x00), "Withdraw address not set");
        require(_msgSender() == withdrawAddress, "Withdraw address only");
        uint256 totalAmount = address(this).balance;
        bool sent;

        (sent,) = withdrawAddress.call{value: totalAmount}("");
        require(sent, "Main: Failed to send funds");
    }

    function setWithdrawAddress(address addr) external onlyOwner {
        require(addr != address(0x00), "Cannot be zero address");
        withdrawAddress = addr;
    }

    function setRoyaltyPermille(uint256 number) external onlyOwner {
        _royaltyPermille = number;
    }

    function setRoyaltyAddress(address addr) external onlyOwner {
        royaltyAddress = addr;
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    //  ADMIN ONLY //
    mapping(address => bool) private _admins;

    modifier onlyAdmin() {
        require(!_admins[msg.sender], "Only Admins");
        _;
    }

    function burn(uint256 tokenId) external onlyAdmin {
        _burn(tokenId);
    }

    function mintFromAdmin(address receiver, uint16 amount) external onlyAdmin {
        require(totalSupply() + amount <= maxSupply, "Max amount reached");
        _safeMint(receiver, amount);
    }

    function addAdmin(address addr) external onlyOwner {
        require(addr != address(0x00), "Cannot be zero address");
        _admins[addr] = true;
    }

    function removeAdmin(address addr) external onlyOwner {
        delete _admins[addr];
    }

    receive() external payable {}

    fallback() external payable {}
}
