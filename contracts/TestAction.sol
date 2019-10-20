pragma solidity ^0.5.10;

contract TestAction {
    bytes4 constant internal actionSelector = bytes4(keccak256(bytes("action()")));
    uint256 constant internal actionGasStipend = 80000;

    function getActionSelector() external pure returns(bytes4) {return actionSelector;}
    function getActionGasStipend() external pure returns(uint256) {return actionGasStipend;}

    bool public executed;

    function action()
        public
    {
        if (executed) {
            executed = false;
        } else {
            executed = true;
        }
    }
}