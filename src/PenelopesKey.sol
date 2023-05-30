// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/erc721a/contracts/extensions/ERC721AQueryable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract PenelopesKey is ERC721AQueryable, Ownable {
    using ECDSA for bytes32;

    enum ActiveSession {
        NONE,
        ALLOWLIST,
        WAITLIST,
        PUBLIC
    }

    // token level and levelTimestamp
    struct Level {
        uint128 level;
        uint128 levelTimestamp;
    }

    uint256 constant TICKET_BINS = 24; // maxSupply / 256 + 1
    uint256 constant TICKETS_PER_BIN = 256;

    // STATE VARS
    bool public isRevealed = false;
    address public allowListSigner;
    address public withdrawAddress;
    uint256 public mintPrice = 0.075 ether;
    uint256 public maxSupply = 6_000;
    mapping(uint256 => uint256) public ticketMap;
    ActiveSession public activeSession = ActiveSession.NONE;
    string private baseURI;
    string private unrevealedURI;

    // map token ID to Level
    mapping(uint256 => Level) private _tokenLevels;

    constructor(address _signer) {
        require(_signer != address(0x00), "Cannot be zero address");
        //set allow list signer
        allowListSigner = _signer;
        //initialize tickets
        for (uint256 i; i < TICKET_BINS; i++) {
            ticketMap[i] = type(uint256).max;
        }
    }

    /**
     * @dev Returns the maximum supply of tokens.
     */
    function totalTickets() external view returns (uint256) {
        return maxSupply;
    }

    /**
     * @notice Allows the user to mint a token, but only if the active session is set to PUBLIC,
     *         the payment sent is sufficient, the total minted tokens plus the requested amount
     *         doesn't exceed the maximum supply, and the function is called from an externally
     *         owned account (not a contract).
     * @param amount The number of tokens to mint.
     */
    function mint(uint256 amount) external payable {
        require(activeSession == ActiveSession.PUBLIC, "Minting Not Active");
        require(msg.value >= mintPrice * amount, "Did not send enough ether");
        require(_totalMinted() + amount <= maxSupply, "Max amount reached");
        require(msg.sender == tx.origin, "EOA Only");

        //mint
        _mint(_msgSender(), amount);
    }

    /**
     * @notice Allows the user to mint a token using a ticket, provided the ticket number and signature are valid,
     *         the total minted tokens plus the requested amount doesn't exceed the maximum supply,
     *         and the payment sent is sufficient.
     * @param ticketNumbers The array of ticket numbers.
     * @param signatures The array of signatures.
     */
    function mintWithTicket(uint256[] calldata ticketNumbers, bytes[] calldata signatures) external payable {
        require(ticketNumbers.length == signatures.length, "Mismatch Arrays");
        require(_totalMinted() + ticketNumbers.length <= maxSupply, "Max amount reached");
        require(ticketNumbers.length < 4, "Max 3 Tickets");
        require(msg.value >= mintPrice * ticketNumbers.length, "Did not send enough ether");

        for (uint256 i; i < ticketNumbers.length; i++) {
            require(verifyTicket(msg.sender, ticketNumbers[i], uint8(activeSession), signatures[i]), "ticket not valid");
            claimTicket(ticketNumbers[i]);
        }

        //mint
        _mint(_msgSender(), ticketNumbers.length);
    }

    /**
     * @notice Verifies if a ticket is valid by checking if the signer of the hashed ticket is the same as the allowListSigner.
     * @param user The address of the user.
     * @param ticketNumber The ticket number.
     * @param session The session number.
     * @param signature The signature.
     * @return isValid True if the ticket is valid, false otherwise.
     */
    function verifyTicket(address user, uint256 ticketNumber, uint8 session, bytes memory signature)
        public
        view
        returns (bool isValid)
    {
        if (allowListSigner == getTicket(user, ticketNumber, session).toEthSignedMessageHash().recover(signature)) {
            isValid = true;
        }
    }

    /**
     * @notice Generates a hash of the user's address, ticket number, and session.
     * @param user The address of the user.
     * @param ticketNumber The ticket number.
     * @param session The session number.
     * @return The hash of the user's address, ticket number, and session.
     */
    function getTicket(address user, uint256 ticketNumber, uint8 session) public pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(user, ticketNumber, session));
        return hash;
    }

    /**
     * @notice Claims a ticket by marking it as used in the ticket map.
     * @param ticketNumber The ticket number.
     */
    function claimTicket(uint256 ticketNumber) public {
        //get bin and bit
        uint256 bin;
        uint256 bit;
        unchecked {
            bin = ticketNumber / TICKETS_PER_BIN;
            bit = ticketNumber % TICKETS_PER_BIN;
        }

        uint256 storedBit = (ticketMap[bin] >> bit) & uint256(1);
        require(storedBit == 1, "already minted");

        ticketMap[bin] = ticketMap[bin] & ~(uint256(1) << bit);
    }

    /**
     * @notice Returns an array of token IDs owned by a given address.
     * @param _owner The address of the owner.
     * @return An array of token IDs owned by the given address.
     */
    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        return _tokensOfOwner(_owner);
    }

    /**
     * @notice Returns the URI of a given token ID. If the token is not revealed yet, it returns the unrevealedURI.
     * @param tokenId The ID of the token.
     * @return The URI of the given token ID.
     */
    function tokenURI(uint256 tokenId) public view override (ERC721A, IERC721A) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        if (!isRevealed) return unrevealedURI;
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    /**
     * @notice Overrides the _startTokenId function from the ERC721A contract to always return 1.
     * @return The starting token ID (1).
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @notice Overrides the supportsInterface function from the ERC721A contract to add support for ERC165, ERC721, and ERC721Metadata.
     * @param interfaceId The ID of the interface.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public pure override (ERC721A, IERC721A) returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 interface ID for ERC165.
            || interfaceId == 0x80ac58cd // ERC165 interface ID for ERC721.
            || interfaceId == 0x5b5e139f; // ERC165 interface ID for ERC721Metadata.
    }

    // OWNER ONLY //
    /**
     * @notice Allows the owner to set the base URI for the token.
     * @param uri The URI to be set.
     */
    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    /**
     * @notice Allows the owner to set the URI for the unrevealed token.
     * @param uri The URI to be set.
     */
    function setUnrevealedURI(string calldata uri) external onlyOwner {
        unrevealedURI = uri;
    }

    /**
     * @notice Allows the owner to set the reveal state of the token.
     * @param _isRevealed The reveal state to be set.
     */
    function setIsRevealed(bool _isRevealed) external onlyOwner {
        isRevealed = _isRevealed;
    }

    /**
     * @notice Allows the owner to reduce the maximum supply of the token.
     * @param reduceBy The amount by which the maximum supply is to be reduced.
     */
    function reduceMaxSupplyBy(uint256 reduceBy) external onlyOwner {
        require(reduceBy < maxSupply - _totalMinted());
        maxSupply -= reduceBy;
    }

    /**
     * @notice Allows the owner to set the address of the allow list signer.
     * @param _signer The address of the signer to be set.
     */
    function setAllowListSigner(address _signer) external onlyOwner {
        require(_signer != address(0x00), "Cannot be zero address");
        allowListSigner = _signer;
    }

    /**
     * @notice Allows the owner to set the active session.
     * @param session The session to be set. 0 = Inactive, 1 = AllowList, 2 = Waitlist, 3 = Public Sale
     */
    function setSession(uint8 session) external onlyOwner {
        activeSession = ActiveSession(session);
    }

    /**
     * @notice Allows the owner to set the mint price.
     * @param price The price to be set.
     */
    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    /**
     * @notice Allows the owner to mint a token for the team.
     * @param receiver The receiver of the token.
     * @param amount The number of tokens to mint.
     */
    function mintForTeam(address receiver, uint16 amount) external onlyOwner {
        require(_totalMinted() + amount <= maxSupply, "Max amount reached");
        _safeMint(receiver, amount);
    }

    /**
     * @notice Allows withdrawal of the contract's balance to the designated withdrawal address.
     */
    function withdraw() external {
        require(withdrawAddress != address(0x00), "Withdraw address not set");
        require(_msgSender() == withdrawAddress, "Withdraw address only");
        uint256 totalAmount = address(this).balance;
        bool sent;

        (sent,) = withdrawAddress.call{value: totalAmount}("");
        require(sent, "Main: Failed to send funds");
    }

    /**
     * @notice Allows the owner to set the withdrawal address.
     * @param addr The address to be set.
     */
    function setWithdrawAddress(address addr) external onlyOwner {
        require(addr != address(0x00), "Cannot be zero address");
        withdrawAddress = addr;
    }

    /**
     * @notice Returns the balance of the contract.
     * @return The balance of the contract.
     */
    function getBalance() external view returns (uint256) {
        // To access the amount of ether the contract has
        return address(this).balance;
    }

    /**
     * @notice View function to see a token's level and level timestamp.
     * @param tokenId The ID of the token to view.
     * @return The level and level timestamp of the token.
     */
    function getTokenLevel(uint256 tokenId) external view returns (uint128, uint128) {
        return (_tokenLevels[tokenId].level, _tokenLevels[tokenId].levelTimestamp);
    }

    //  ADMIN ONLY //
    mapping(address => bool) private _admins;

    modifier onlyAdmin() {
        require(_admins[msg.sender], "Only Admins");
        _;
    }

    /**
     * @notice Increases the level of a specific token by 1.
     * @dev Only an admin can level up a token.
     * @param tokenId The ID of the token to level up.
     */
    function levelUp(uint256 tokenId) external onlyAdmin {
        // Increment the level of the token
        _tokenLevels[tokenId].level += 1;

        // Update the level timestamp
        _tokenLevels[tokenId].levelTimestamp = uint128(block.timestamp);
    }

    /**
     * @notice Allows an admin to burn a token.
     * @param tokenId The ID of the token to be burned.
     */
    function burn(uint256 tokenId) external onlyAdmin {
        _burn(tokenId);
    }

    /**
     * @notice Allows the owner to add an admin.
     * @param addr The address of the admin to be added.
     */
    function addAdmin(address addr) external onlyOwner {
        require(addr != address(0x00), "Cannot be zero address");
        _admins[addr] = true;
    }

    /**
     * @notice Allows the owner to remove an admin.
     * @param addr The address of the admin to be removed.
     */
    function removeAdmin(address addr) external onlyOwner {
        delete _admins[addr];
    }

    receive() external payable {}

    fallback() external payable {}
}
