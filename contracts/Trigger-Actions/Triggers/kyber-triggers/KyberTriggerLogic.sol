pragma solidity ^0.5.10;

import '../GelatoTriggersStandard.sol';
import '../../../Interfaces/Kyber/IKyber.sol';


contract KyberTriggerLogic is GelatoTriggersStandard {

    constructor()
        public
        GelatoTriggersStandard("fired(address,address,uint256,bool,uint256)")
    {}

    function fired(///@dev encode all params WITHOUT fnSelector
                   address _sellToken,
                   address _buyToken,
                   uint256 _sellAmount,
                   bool isGreater,
                   uint256 _whatIWant
    )
        external
        view
        returns(bool)
    {
        (, uint256 receivable) = firedView(_sellToken, _buyToken, _sellAmount);
        if (isGreater)
        {
            if (receivable >= _whatIWant){
                return true;
            } else {
                return false;
            }

        } else if (!isGreater) {
            if (receivable < _whatIWant) {
                return true;
            } else {
                return false;
            }
        }
    }

    function firedView(
        address src,
        address dest,
        uint256 srcAmt
    ) public view returns (
        uint256 expectedRate,
        uint256 slippageRate
    )
    {
        (expectedRate,)
            = IKyber(0x818E6FECD516Ecc3849DAf6845e3EC868087B755)
                .getExpectedRate(src, dest, srcAmt);
        slippageRate = (expectedRate / 100) * 99; // slippage rate upto 99%
    }
}