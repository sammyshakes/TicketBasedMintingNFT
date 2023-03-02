import { expect } from "chai";
import { Bytes } from "ethers";
import { ethers } from "hardhat";

// Create a wallet to sign the message with
let privateKey =
  "0x0123456789012345678901234567890123456789012345678901234567890123";
let signer = new ethers.Wallet(privateKey);

describe("PenelopesKey", function () {
  it("Should deploy and initialize PenelopesKey", async function () {
    const accounts = await ethers.getSigners();
    // const signer = accounts[0];
    const user1 = accounts[1];
    const user2 = accounts[2];
    const Token = await ethers.getContractFactory("PenelopesKey");
    const pkey = await Token.deploy(signer.address);
    await pkey.deployed();
    expect(await pkey.name()).to.equal("PenelopesKey");

    // console.log(pkey);
    //initialize ticketBins
    await pkey.addTickets(6000);
    //setsession to allowlist
    await pkey.setSession(1);
    expect(await pkey.activeSession()).to.equal(1);

    // signer needs to sign ticket with user's wallet addy off-chain
    // get ticket for user 1, ticket number 5
    const ticketNumber = 5;

    //this is where user completes puzzle
    const ticket = await pkey.getTicket(user1.address, ticketNumber, 1);

    console.log("signer.address", signer.address);
    console.log("signer.pubkey", signer.publicKey);
    console.log("user1.address", user1.address);
    console.log("ticket", ticket);
    //sign ticket
    const signedTicket = await signer.signMessage(
      // ticket
      ethers.utils.arrayify(ticket)
    );

    console.log("ticket_bytes", ethers.utils.arrayify(ticket));
    console.log("signedTicket", signedTicket);
    expect(await pkey.allowListSigner()).to.equal(signer.address);

    //user 1 attempts to mint
    await pkey.connect(user1).mintWithTicket([ticketNumber], [signedTicket], {
      value: ethers.utils.parseEther("0.01"),
    });
    console.log(await pkey.tokensOfOwner(user1.address));

    // attempt submitting multiple tickets at once
    const ticketNumbers = [7, 8, 9];
    const ticket1 = await pkey.getTicket(user2.address, ticketNumbers[0], 1);
    const ticket2 = await pkey.getTicket(user2.address, ticketNumbers[1], 1);
    const ticket3 = await pkey.getTicket(user2.address, ticketNumbers[2], 1);

    //sign tickets
    const signedTicket1 = await signer.signMessage(
      // ticket
      ethers.utils.arrayify(ticket1)
    );

    const signedTicket2 = await signer.signMessage(
      // ticket
      ethers.utils.arrayify(ticket2)
    );

    const signedTicket3 = await signer.signMessage(
      // ticket
      ethers.utils.arrayify(ticket3)
    );

    await pkey
      .connect(user2)
      .mintWithTicket(
        ticketNumbers,
        [signedTicket1, signedTicket2, signedTicket3],
        {
          value: ethers.utils.parseEther("0.03"),
        }
      );
  });
});
