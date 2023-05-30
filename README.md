
## Smart Contract Overview

# Penelope’s Key contract overview

An analysis of the functionality in Penelope’s Key contract that goes beyond the standard ERC721 functionality:

1. **Active Session Management** (`ActiveSession`, `activeSession`): The contract introduces the concept of "active sessions," which can be one of four states (`NONE`, `ALLOWLIST`, `WAITLIST`, `PUBLIC`). This appears to be a mechanism for managing different phases or stages of the token minting process, although the contract doesn't specify what each state means.
2. **Ticket-Based Minting** (`mintWithTicket`): In addition to the standard `mint` function, the contract provides a `mintWithTicket` function that allows users to mint tokens using tickets. Each ticket includes a ticket number and a signature, which are verified by the `verifyTicket` function. This function uses the `allowListSigner` address to recover a signed message and compare it with the expected message.
3. **Ticket Claiming and Management** (`claimTicket`, `verifyTicket`, `getTicket`): These functions handle the claiming and validation of tickets in the contract. `claimTicket` marks a ticket as claimed (i.e., already used to mint a token), `verifyTicket` checks the validity of a ticket, and `getTicket` generates the expected message for a ticket.
4. **Custom URI Management** (`setBaseURI`, `setUnrevealedURI`, `tokenURI`): The contract allows the owner to set a base URI and an "unrevealed" URI for the tokens. The `tokenURI` function then uses these URIs to generate the URI for each token. If the `isRevealed` state variable is `false`, the `unrevealedURI` is used as the token URI.
5. **Admin Role Management** (`onlyAdmin`, `addAdmin`, `removeAdmin`): The contract introduces an "admin" role that has certain privileges. The `addAdmin` and `removeAdmin` functions allow the contract owner to manage who has the admin role.
6. **Burn Functionality** (`burn`): The contract includes a `burn` function that allows admins to burn (i.e., permanently destroy) tokens.
7. **Leveling System** (`Level`, `_tokenLevels`, `levelUp`, `getTokenLevel`): The contract includes a leveling system for tokens, where each token has an associated level and timestamp. The `levelUp` function allows an admin to increase the level of a token, and the `getTokenLevel` function allows anyone to view the level and timestamp of a token.
8. **Withdraw Functionality** (`withdraw`, `setWithdrawAddress`): The contract includes a `withdraw` function that allows the contract to send its Ether balance to a specified address. The `setWithdrawAddress` function allows the owner to set this address.
9. **Price and Supply Management** (`mintPrice`, `maxSupply`, `setMintPrice`, `reduceMaxSupplyBy`): The contract maintains a `mintPrice` (the cost to mint a token) and a `maxSupply` (the maximum number of tokens that can be minted). The owner can change the mint price and reduce the max supply with the `setMintPrice` and `reduceMaxSupplyBy` functions, respectively.

These are the main features of the `PenelopesKey` contract that extend beyond the standard ERC721 functionality.

