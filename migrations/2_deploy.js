/* eslint-disable no-undef */
const Token = artifacts.require('Token');
const dBank = artifacts.require('dBank');

module.exports = async (deployer) => {
	await deployer.deploy(Token, 'AdyToken', 'ADY')
	const token = await Token.deployed()

	await deployer.deploy(dBank, token.address)
	const dbank = await dBank.deployed() 
	
	await token.changeMinter(dbank.address)
};