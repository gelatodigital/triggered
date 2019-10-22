pragma solidity ^0.5.10;

import '../GelatoTriggersStandard.sol';
import '../../../Interfaces/Kyber/IKyber.sol';


contract KyberTriggerLogic is GelatoTriggersStandard {

    constructor()
        public
        GelatoTriggersStandard("fired(address,address,uint256,bool,uint256)")
    {}


    /**
     * @dev Get the expected exchange rate and slippage rate from Kyber Network
     * @param _src source ERC20 token contract address
     * @param _dest destination ERC20 token contract address
     * @param _srcQty wei amount of source ERC20 token
     * @param _isGreater to
     * @param _destAmt the
     */
    function fired(///@dev encode all params WITHOUT fnSelector
                   address _src,
                   address _dest,
                   uint256 _srcQty,
                   bool _isGreater,
                   uint256 _wantedRate
    )
        external
        view
        returns(bool)
    {
        (uint256 expectedRate,)
            = IKyber(0x818E6FECD516Ecc3849DAf6845e3EC868087B755)
                .getExpectedRate(_src,_dest,_srcQty
        );
        uint256 slippageFloor = (expectedRate / 100) * 99;  // capped at 1% slippage
        if (_isGreater) {
            if (expectedRateFloor.div(10**18).mul(_destAmt)  >= _destAmt){
                return true;
            } else {
                return false;
            }
        } else if (!_isGreater) {
            if (slippageRate < _destAmt) {
                return true;
            } else {
                return false;
            }
        }
    }
}