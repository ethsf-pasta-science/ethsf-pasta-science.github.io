var dex = artifacts.require("Market");

module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(dex);
};