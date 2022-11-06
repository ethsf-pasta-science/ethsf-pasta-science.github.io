var DerivativeToken = artifacts.require("DerivativeToken");

module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(DerivativeToken);
  };