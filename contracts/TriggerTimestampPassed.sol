pragma solidity ^0.5.10;

contract GelatoTriggersStandard {
    bytes4 internal triggerSelector;

    function getTriggerSelector()
        external
        view
        returns(bytes4)
    {
        return triggerSelector;
    }

    constructor(string memory _triggerSignature)
        internal
    {
        triggerSelector = bytes4(keccak256(bytes(_triggerSignature)));
    }
}

contract TriggerTimestampPassed is GelatoTriggersStandard {

    constructor()
        public
        GelatoTriggersStandard("fired(uint256)")
    {}

    function fired(uint256 _timestamp)
        external
        view
        returns(bool)
    {
        return _timestamp <= block.timestamp;
    }

    function getLatestTimestamp()
        external
        view
        returns(uint256)
    {
        return block.timestamp;
    }

}