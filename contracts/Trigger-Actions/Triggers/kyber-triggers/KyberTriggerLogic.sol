pragma solidity ^0.5.10;

import '../GelatoTriggersStandard.sol';
import '../../../Interfaces/Kyber/IKyber.sol';


contract KyberLimitTrigger is GelatoTriggersStandard {

    constructor()
        public
        GelatoTriggersStandard("fired(address,address,uint256,bool,uint256)")
    {}


    /**
     * @dev Get the expected exchange rate and slippage rate from Kyber Network
     * @param _src source ERC20 token contract address
     * @param _dest destination ERC20 token contract address
     * @param _srcQty wei amount of source ERC20 token
     * @param _isGreater isGreater == limit sell, !isGreater == stop loss
     * @param _rate the conversion rate (price per src) the user specified
     */
    function fired(///@dev encode all params WITHOUT fnSelector
                   address _src,
                   address _dest,
                   uint256 _srcQty,
                   uint256 _userRate,
                   bool _isGreater
    )
        external
        view
        returns(bool)
    {
        (/*uint256 kyberExpectedRate*/,
         uint256 kyberSlippageRate)
            = IKyber(0x818E6FECD516Ecc3849DAf6845e3EC868087B755)
                .getExpectedRate(_src,_dest,_srcQty
        );
        ///@notice Limit Sell\Limit Buy (late to the party)
        if (_isGreater) {
            if (kyberSlippageRate >= _userRate) {
                return true;
            }
            return false;
        }
        ///@notice Stop-Loss Sell\Limit Buy
        else if (!_isGreater) {
            if (kyberSlippageRate <= _userRate) {
                return true;
            }
            return false;
        }
    }

    function _limitSellPossible(uint256 _kyberRate,
                                uint256 _userRate
    )
        internal
        view
        returns(bool)
    {
        if (_quotedRated >= _userRate) {
            return true;
        }
        return false;
    }

    function _stopLossCrossed(uint256 _kyberRate,
                              uint256 _userRate
    )
        internal
        view
        returns(bool)
    {
        if (_kyberRate <= _userRate) {
            return true;
        }
        return false;
    }
}