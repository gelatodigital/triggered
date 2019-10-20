pragma solidity ^0.5.10;

contract TestAction {
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