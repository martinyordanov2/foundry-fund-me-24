// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "@forge-std/src/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;


    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }
    
    function testMinimumUsdIsFive() public {
        
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedIsAccurate() public {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWithouthEnoughEth() public {
        vm.expectRevert(); // the next line should revert
        fundMe.fund(); //send 0 value
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //the next tx will be send by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public{
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded{ // CHECK IF THE MODIFIER FOR onlyOwner works correctly
        vm.expectRevert(); // because of this line we expect the next line should revert(fail)
        vm.prank(USER); //with this line we are trying the USER to withdraw and it should fail bcz it's USER is not the owner
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded{
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        uint256 gasStart = gasleft(); // for example 1000
        vm.txGasPrice(GAS_PRICE); // to simulate actual gas price - tell our test to pretend to use real gas
        vm.prank(fundMe.getOwner()); //only the owner can withdraw so we want to prank // 200 
        fundMe.withdraw();

        uint256 gasEnd = gasleft(); // 800
        uint gasUsed = (gasStart - gasEnd) * tx.gasprice;

        console.log(gasUsed); //10903

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded{
        //Arrange
        uint160 numberOfFunders = 10; //when we want to use numbers to generate an address it must be uint160
        uint160 startingFunderIndex = 1;

        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            //vm.prank
            //vm.deal
            //fund the fundMe
            hoax(address(i), SEND_VALUE); // instead of using prank and deal - hoax does both 
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert

        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
    }
}