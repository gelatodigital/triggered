pragma solidity ^0.5.10;

interface IGelatoAction {
    function getGelatoCore() external returns(address);
    function getInteractionContract() external view returns(address);
    function getActionSelector() external view returns(bytes4);
    function getActionGasStipend() external view returns(uint256);
    function actionConditionsFulfilled(address, bytes calldata) external view returns(bool);

    event LogAction(uint256 indexed executionClaimId,
                    address indexed user
    );
}