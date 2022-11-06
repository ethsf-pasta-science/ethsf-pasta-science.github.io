const Market = artifacts.require("Market");
const Derivative = artifacts.require("DerivativeToken");
const truffleAssert = require('truffle-assertions');
const address = '0xdB4F5aE8dc2894d226906f455B4424d1CF9E0C34';
const uri = 'https://www.google.com/url?sa=i&url=https%3A%2F%2Fwww.foodnetwork.com%2Frecipes%2Ffood-network-kitchen%2Fbaked-feta-pasta-9867689&psig=AOvVaw0Q-LJ_zyyyD54KdUxJgRc7&ust=1667802517777000&source=images&cd=vfe&ved=0CAwQjRxqFwoTCLCZ79b2mPsCFQAAAAAdAAAAABAE=';

contract("Market", (accounts) => {
    let market;
    let derivative;
    let beneficiary = accounts[0];
    let owner = accounts[1];

    beforeEach(async function() {
        derivative = await Derivative.deployed();
        market = await Market.deployed();
    });

    describe("Should create a new NFT and post it on the marketplace", function() {
        let id = derivative.mintDerivative(uri)
        it("Should pass if a new item was created on the marketplace, revert if otherwise", async() => {
            await truffleAssert.reverts(

                // create a derivative with no fee 
                market.addDerivToMarket(address, id, 100, beneficiary, 0)
            )

            await truffleAssert.passes(
                market.addDerivToMarket(address, id, 100, beneficiary, 3)
            )
        })

    })

    describe("Should make a derivative proprietary when it's still within the ownership of the beneficiary.", function() {
        
        it("Should make a derivative proprietary if the sender is not the beneficiary, revert otherwise", async() => {
            let id = derivative.mintDerivative(uri)
            let auctionId = await market.addDerivToMarket(address, id, 100, beneficiary, 3);

            await truffleAssert.reverts(
                market.makeProprietary(auctionId, 200, {from: beneficiary})
            )

            await truffleAssert.passes(
                market.makeProprietary(auctionId, 200, {from: owner})
            )
        })
    })
 });
