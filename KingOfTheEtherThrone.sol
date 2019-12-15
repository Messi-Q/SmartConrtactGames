// A chain-game contract that maintains a 'throne' which agents may pay to rule.

// This contract lives on the blockchain at 0xb336a86e2feb1e87a328fcb7dd4d04de3df254d0

pragma solidity ^0.4.0;

contract KingOfTheEtherThrone {

    struct Monarch {
        // Address to which their compensation will be sent.
        address etherAddress;
        // A name by which they wish to be known.
        string name;
        // How much did they pay to become monarch?
        uint claimPrice;
        // When did their rule start (based on block.timestamp)?
        uint coronationTimestamp;
    }

    address wizardAddress;

    modifier onlywizard {
        if (msg.sender == wizardAddress) _
    }

    uint constant startingClaimPrice = 100 finney;
    uint constant claimPriceAdjustNum = 3;
    uint constant claimPriceAdjustDen = 2;
    // e.g. num=1 and den=100 would deduct 1% for the wizard, leaving 99% as
    // the compensation fee for the usurped monarch.
    uint constant wizardCommissionFractionNum = 1;
    uint constant wizardCommissionFractionDen = 100;
    // How much must an agent pay now to become the monarch?
    uint public currentClaimPrice;
    // The King (or Queen) of the Ether.
    Monarch public currentMonarch;
    // Earliest-first list of previous throne holders.
    Monarch[] public pastMonarchs;

    // Create a new throne, with the creator as wizard and first ruler.
    function KingOfTheEtherThrone() {
        wizardAddress = msg.sender;
        currentClaimPrice = startingClaimPrice;
        currentMonarch = Monarch(
            wizardAddress,
            "[Vacant]",
            0,
            block.timestamp
        );
    }

    function numberOfMonarchs() constant returns (uint n) {
        return pastMonarchs.length;
    }

    // Fired when the throne is claimed.
    event ThroneClaimed(
        address usurperEtherAddress,
        string usurperName,
        uint newClaimPrice
    );

    // Fallback function - simple transactions trigger this.
    function() {
        claimThrone(string(msg.data));
    }

    // Claim the throne for the given name by paying the currentClaimFee.
    function claimThrone(string name) {

        uint valuePaid = msg.value;

        // If they paid too little, reject claim and refund their money.
        if (valuePaid < currentClaimPrice) {
            msg.sender.send(valuePaid);
            return;
        }

        // If they paid too much, continue with claim but refund the excess.
        if (valuePaid > currentClaimPrice) {
            uint excessPaid = valuePaid - currentClaimPrice;
            msg.sender.send(excessPaid);
            valuePaid = valuePaid - excessPaid;
        }

        // The claim price payment goes to the current monarch as compensation
        // (with a commission held back for the wizard). We let the wizard's
        // payments accumulate to avoid wasting gas sending small fees.

        uint wizardCommission = (valuePaid * wizardCommissionFractionNum) / wizardCommissionFractionDen;

        uint compensation = valuePaid - wizardCommission;

        if (currentMonarch.etherAddress != wizardAddress) {
            currentMonarch.etherAddress.send(compensation);
        } else {
            // When the throne is vacant, the fee accumulates for the wizard.
        }

        // Usurp the current monarch, replacing them with the new one.
        pastMonarchs.push(currentMonarch);
        currentMonarch = Monarch(
            msg.sender,
            name,
            valuePaid,
            block.timestamp
        );

        // Increase the claim fee for next time.
        // Stop number of trailing decimals getting silly - we round it a bit.
        uint rawNewClaimPrice = currentClaimPrice * claimPriceAdjustNum / claimPriceAdjustDen;
        if (rawNewClaimPrice < 10 finney) {
            currentClaimPrice = rawNewClaimPrice;
        } else if (rawNewClaimPrice < 100 finney) {
            currentClaimPrice = 100 szabo * (rawNewClaimPrice / 100 szabo);
        } else if (rawNewClaimPrice < 1 ether) {
            currentClaimPrice = 1 finney * (rawNewClaimPrice / 1 finney);
        } else if (rawNewClaimPrice < 10 ether) {
            currentClaimPrice = 10 finney * (rawNewClaimPrice / 10 finney);
        } else if (rawNewClaimPrice < 100 ether) {
            currentClaimPrice = 100 finney * (rawNewClaimPrice / 100 finney);
        } else if (rawNewClaimPrice < 1000 ether) {
            currentClaimPrice = 1 ether * (rawNewClaimPrice / 1 ether);
        } else if (rawNewClaimPrice < 10000 ether) {
            currentClaimPrice = 10 ether * (rawNewClaimPrice / 10 ether);
        } else {
            currentClaimPrice = rawNewClaimPrice;
        }

        // Hail the new monarch!
        ThroneClaimed(currentMonarch.etherAddress, currentMonarch.name, currentClaimPrice);
    }

    // Used only by the wizard to collect his commission.
    function sweepCommission(uint amount) onlywizard {
        wizardAddress.send(amount);
    }

    // Used only by the wizard to collect his commission.
    function transferOwnership(address newOwner) onlywizard {
        wizardAddress = newOwner;
    }

}



