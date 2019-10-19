pragma solidity ^0.5.10;

import './GelatoConstants.sol';
import './DappSys/DSProxy.sol';
import './ProxyRegistry.sol';
import './DappSys/DSGuard.sol';
import './Interfaces/IGelatoAction.sol';
import '@openzeppelin/contracts/drafts/Counters.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';


contract GelatoUserProxies is GelatoConstants
{
    constructor() internal {
        ProxyRegistry public proxyRegistry = ProxyRegistry(constProxyRegistry);
        DSGuardFactory public guardFactory = DSGuardFactory(constGuardFactory);
    }

    // _____________ Creating Gelato User Proxies 1/3 ______________________
    /// @dev requires user to have no proxy
    modifier userHasNoProxy {
        require(proxyRegistry.proxies(msg.sender) == DSProxy(0),
            "GelatoUserProxies: user already has a proxy"
        );
        _;
    }

    modifier userHasProxy {
        require(proxyRegistry.proxies(msg.sender) != DSProxy(0),
            "GelatoUserProxies: user has no proxy"
        );
        _;
    }

    /**
     * @dev this function should be called for users that have nothing deployed yet
     * @return the address of the deployed DSProxy aka userAccount
     * @notice user EOA tx afterwards: userProxy.setAuthority(userProxyGuard)
     */
    function devirginize()
        external
        userHasNoProxy
        returns(address userProxy, address userProxyGuard)
    {
        DSProxy userProxy = DSProxy(proxyRegistry.build(msg.sender));
        DSGuard userProxyGuard = guardFactory.newGuard();
        userProxyGuard.permit(address(this), address(userProxy), constExecSelector);
        userProxyGuard.setOwner(address(userProxy));
    }

    /**
     * @dev this function should be called for users that have a proxy but no guard
     * @return the address of the deployed DSProxy aka userAccount
     * @notice user EOA tx afterwards: userProxy.setAuthority(userProxyGuard)
     */
    function guard()
        external
        returns(address userProxyGuard)
    {
        DSProxy userProxy = proxyRegistry.proxies(msg.sender);
        require(userProxy != DSProxy(0),
            "GelatoUserProxies.guard: user has no proxy deployed -> devirginize()"
        );
        require(DSAuthority(userProxy).authority() == DSAuthority(0),
            "GelatoUserProxies.guard: user already has a DSAuthority"
        );
        DSGuard userProxyGuard = guardFactory.newGuard();
        userProxyGuard.permit(address(this), address(userProxy), constExecSelector);
        userProxyGuard.setOwner(address(userProxy));
    }

    /**
     * @dev 3rd option: user already has a DSGuard
     * => permit(gelatoCore, address(userProxy), constExecSelector) via frontend
     */
    // ================
}

/**
 * @title GelatoCoreAccounting
 */
contract GelatoCoreAccounting is GelatoConstants,
                                 Ownable,
                                 ReentrancyGuard
{
    using SafeMath for uint256;

    //_____________ Gelato ExecutionClaim Economics _______________________
    // userProxy => Deposited ETH for mintings
    mapping(address => uint256) internal userProxyDeposit;
    // executor => executor's price factor
    mapping(address => uint256) internal executorPrice;
    // executor => executor's ETH balance for executed claims
    mapping(address => uint256) internal executorBalance;
    //_____________ Constant gas values _____________
    uint256 internal gasOutsideGasleftChecks;
    uint256 internal gasInsideGasleftChecks;
    uint256 internal canExecMaxGas;
    // =========================


    /**
     * @dev sets the initial gas cost values that are used by several core functions
     * @param _gasOutsideGasleftChecks: gas cost to be determined and set by owner
     * @param _gasInsideGasleftChecks: gas cost to be determined and set by owner
     * @param _canExecMaxGas: gas cost to be determined and set by owner
     */
    constructor()
        internal
    {
        gasOutsideGasleftChecks = constGasOutsideGasleftChecks;
        gasInsideGasleftChecks = constGasInsideGasleftChecks;
        canExecMaxGas = constCanExecMaxGas;
    }

    /**
     * @dev throws if the passed address is not a registered executor
     * @param _executor: the address to be checked against executor registrations
     */
    modifier onlyRegisteredExecutors(address _executor) {
        require(executorPrices[_executor] != 0,
            "GelatoCoreAccounting.onlyRegisteredExecutors: failed"
        );
        _;
    }

    // _______ Execution Gas Caps ____________________________________________
    /**
     * @dev calculates gas requirements based off _actionGasStipend
     * @param _actionGasStipend the gas forwarded with the action call
     * @return the minimum gas required for calls to gelatoCore.execute()
     */
    function _getMinExecutionGasRequirement(uint256 _actionGasStipend)
        internal
        view
        returns(uint256)
    {
        return (gasOutsideGasleftChecks
                + gasInsideGasleftChecks
                + canExecMaxGas
                .add(_actionGasStipend)
        );
    }
    /// @dev interface to internal fn _getMinExecutionGasRequirement
    function getMinExecutionGasRequirement(uint256 _actionGasStipend)
        external
        view
        returns(uint256)
    {
        return _getMinExecutionGasRequirement(_actionGasStipend);
    }
    // =======

    // _______ Important Data to be included as msg.value for minting __________
    /**
     * @dev calculates the deposit payable for minting on gelatoCore
     * @param _action the action contract to be executed
     * @param _selectedExecutor the executor that should call the action
     * @return mintingDepositPayable
     */
    function getMintingDepositPayable(address _action,
                                      address _selectedExecutor
    )
        external
        view
        returns(uint256 mintingDepositPayable)
    {
        uint256 actionGasStipend = IGelatoAction(_action).getActionGasStipend();
        uint256 executionMinGas = _getMinExecutionGasRequirement(actionGasStipend);
        mintingDepositPayable = executionMinGas.mul(executorPrices[_executor]);
    }
    // =======

    // __________ Interface for State Reads ___________________________________
    function getuserProxyDeposit(address _userProxy) external view returns(uint256) {
        return userProxyDeposit[_userProxy];
    }
    function getExecutorPrice(address _executor) external view returns(uint256) {
        return executorPrice[_executor];
    }
    function getExecutorBalance(address _executor) external view returns(uint256) {
        return executorBalance[_executor];
    }
    function getGasOutsideGasleftChecks() external view returns(uint256) {
        return gasOutsideGasleftChecks;
    }
    function getGasInsideGasleftChecks() external view returns(uint256) {
        return gasInsideGasleftChecks;
    }
    function getCanExecMaxGas() external view returns(uint256) {
        return canExecMaxGas;
    }
    // =========================

    // ____________ Interface for STATE MUTATIONS ________________________________________
    //_____________ Interface for Executor __________
    event LogSetExecutorPrice(uint256 executorPrice,
                              uint256 newExecutorPrice
    );
    function setExecutorPrice(uint256 _newExecutorGasPrice)
        external
    {
        emit LogSetExecutorPrice(executorPrice, _newExecutorGasPrice);
        executorPrices[msg.sender] = _newExecutorGasPrice;
    }

    event LogSetExecutorClaim(uint256 executorClaimLifespan,
                              uint256 newExecutorClaimLifespan
    );
    function setExecutorClaimLifespan(uint256 _newExecutorClaimLifespan)
        external
    {
        emit LogSetExecutorPrice(executorClaimLifespan[msg.sender],
                                 _newExecutorClaimLifespan
        );
        executorClaimLifespan[msg.sender] = _newExecutorClaimLifespan;
    }

    event LogSetExecutorBalanceWithdrawal(address indexed executor,
                                          uint256 withdrawAmount
    );
    function withdrawExecutorBalance()
        external
        nonReentrant
    {
        // Checks
        uint256 currentExecutorBalance = executorBalances[msg.sender];
        require(currentExecutorBalance > 0,
            "GelatoCoreAccounting.withdrawExecutorBalance: failed"
        );
        // Effects
        executorBalances[msg.sender] = 0;
        // Interaction
        msg.sender.transfer(currentExecutorBalance);
        emit LogSetExecutorBalanceWithdrawal(msg.sender,
                                          currentExecutorBalance
        );
    }
    // =========
}

/**
 * @title GelatoCore
 */
contract GelatoCore is GelatoUserProxies,
                       GelatoCoreAccounting
{
    constructor()
        public
        GelatoUserProxies()
        GelatoCoreAccounting()
    {}

    // Unique ExecutionClaim Ids
    using Counters for Counters.Counter;

    Counters.Counter private executionClaimIds;

    function getCurrentExecutionClaimId()
        external
        view
        returns(uint256 currentId)
    {
        currentId = executionClaimIds.current();
    }

    // executionClaimId => userProxyByExecutionClaimId
    mapping(uint256 => address) private userProxyByExecutionClaimId;

    /**
     * @dev interface to read from the userProxyByExecutionClaimId state variable
     * @param _executionClaimId: the unique executionClaimId
     * @return address of userProxy whose executionClaim _executionClaimId maps to.
     */
    function getProxyWithExecutionClaimId(uint256 _executionClaimId)
        external
        view
        returns(address)
    {
        return userProxyByExecutionClaimId[_executionClaimId];
    }
    // executionClaimId => bytes32 executionClaimHash
    mapping(uint256 => bytes32) private hashedExecutionClaims;

    /**
     * @dev interface to read from the hashedExecutionClaims state variable
     * @param _executionClaimId: the unique executionClaimId
     * @return the bytes32 hash of the executionClaim with _executionClaimId
     */
    function getHashedExecutionClaim(uint256 _executionClaimId)
        external
        returns(bytes32)
    {
        return hashedExecutionClaims[_executionClaimId];
    }

    // $$$$$$$$$$$ mintExecutionClaim() API  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    event LogSetNewExecutionClaimMinted(uint256 indexed executionClaimId,
                                        address indexed userProxyByExecutionClaimId,
                                        address indexed selectedExecutor,
                                        address trigger,
                                        bytes triggerPayload,
                                        address action,
                                        bytes actionPayload,
                                        uint256 actionGasStipend,
                                        uint256 executionClaimExpiryDate,
                                        uint256 mintingDeposit
    );

    function mintExecutionClaim(address _selectedExecutor,
                                address _trigger,
                                bytes calldata _specificTriggerParams,
                                address _action,
                                bytes calldata _specificActionParams
    )
        external
        payable
        onlyRegisteredExecutors(_selectedExecutor)
        nonReentrant
    {

        // ______ Charge Minting Deposit _______________________________________
        uint256 actionGasStipend = IGelatoAction(_action).getActionGasStipend();
        uint256 executionMinGas = _getMinExecutionGasRequirement(actionGasStipend);
        uint256 mintingDepositPayable
            = executionMinGas.mul(executorPrices[_selectedExecutor]);
        require(msg.value == mintingDepositPayable,
            "GelatoCore.mintExecutionClaim: mintingDepositPayable failed"
        );
        userProxyDeposit[msg.sender] = userProxyDeposit[msg.sender].add(mintingDepositPayable);
        // =============

        // ______ Mint new executionClaim ______________________________________
        Counters.increment(executionClaimIds);
        uint256 executionClaimId = executionClaimIds.current();
        userProxyByExecutionClaimId[executionClaimId] = msg.sender;
        // =============

        // ______ Trigger-Action Payload encoding ______________________________
        bytes memory triggerPayload;
        {
            bytes4 triggerSelector = IGelatoTrigger(_trigger).getTriggerSelector();
            triggerPayload = abi.encodeWithSelector(// Standard Trigger Params
                                                    triggerSelector,
                                                   // Specific Trigger Params
                                                   _specificTriggerParams
            );
        }
        bytes memory actionPayload;
        {
            bytes4 actionSelector = IGelatoAction(_action).getActionSelector();
            actionPayload = abi.encodeWithSelector(// Standard Action Params
                                                   actionSelector,
                                                   executionClaimId,
                                                   // Specific Action Params
                                                   _specificActionParams
            );
        }
        // =============

        // ______ ExecutionClaim Hashing ______________________________________
        uint256 executionClaimExpiryDate = now.add(executorClaimLifespan);
        // Include executionClaimId: avoid hash collisions
        bytes32 executionClaimHash
            = keccak256(abi.encodePacked(executionClaimId,
                                         msg.sender, // User
                                         _selectedExecutor,
                                         _trigger,
                                         triggerPayload,
                                         _action,
                                         actionPayload,
                                         actionGasStipend,
                                         executionClaimExpiryDate,
                                         mintingDepositPayable
        ));
        hashedExecutionClaims[executionClaimId] = executionClaimHash;
        // =============
        emit LogSetNewExecutionClaimMinted(msg.sender,  // User
                                        executionClaimId,
                                        _selectedExecutor,
                                        _trigger,
                                        triggerPayload,
                                        _action,
                                        actionPayload,
                                        actionGasStipend,
                                        executionClaimExpiryDate,
                                        mintingDepositPayable
        );
    }
    // $$$$$$$$$$$$$$$ mintExecutionClaim() END


    // ********************* EXECUTE FUNCTION SUITE *********************
    //  checked by canExecute and returned as a uint256 from User
    enum CanExecuteCheck {
        WrongCalldata,  // also returns if a not-selected executor calls fn
        NonExistantExecutionClaim,
        ExecutionClaimExpired,
        TriggerReverted,
        NotExecutable,
        Executable
    }

    function _canExecute(address _trigger,
                         bytes memory _triggerPayload,
                         address _action,
                         bytes memory _actionPayload,
                         uint256 _actionGasStipend,
                         address _userProxyByExecutionClaimId,
                         uint256 _executionClaimId,
                         uint256 _executionClaimExpiryDate,
                         uint256 _mintingDeposit
    )
        private
        view
        returns (uint8)
    {
        // _____________ Static CHECKS __________________________________________
        // Compute executionClaimHash from calldata
        bytes32 computedExecutionClaimHash
            = keccak256(abi.encodePacked(_executionClaimId,
                                         _userProxyByExecutionClaimId,
                                         msg.sender,  // selected? executor
                                         _trigger,
                                         _triggerPayload,
                                         _action,
                                         _actionPayload,
                                         _actionGasStipend,
                                         _executionClaimExpiryDate,
                                         _mintingDeposit
        ));
        bytes32 storedExecutionClaimHash = hashedExecutionClaims[_executionClaimId];
        // Check passed calldata and that msg.sender is selected executor
        if(computedExecutionClaimHash != storedExecutionClaimHash) {
            return uint8(CanExecuteCheck.WrongCalldata);
        }
        // Require execution claim to exist and / or not be burned
        if (userProxyByExecutionClaimId[_executionClaimId] == address(0)) {
            return uint8(CanExecuteCheck.NonExistantExecutionClaim);
        }
        if (_executionClaimExpiryDate < now) {
            return uint8(CanExecuteCheck.ExecutionClaimExpired);
        }
        // =========
        // _____________ Dynamic CHECKS __________________________________________
        // Call to trigger view function (returns(bool))
        (bool success,
         bytes memory returndata) = (_trigger.staticcall
                                             .gas(canExecMaxGas)
                                             (_triggerPayload)
        );
        if (!success) {
            return uint8(CanExecuteCheck.TriggerReverted);
        } else {
            bool executable = abi.decode(returndata, (bool));
            if (executable) {
                return uint8(CanExecuteCheck.Executable);
            } else {
                return uint8(CanExecuteCheck.NotExecutable);
            }
        }
        // ==============
    }
    // canExecute interface for executors
    function canExecute(address _trigger,
                        bytes calldata _triggerPayload,
                        address _action,
                        bytes calldata _actionPayload,
                        uint256 _actionGasStipend,
                        address _userProxyByExecutionClaimId,
                        uint256 _executionClaimId,
                        uint256 _executionClaimExpiryDate
    )
        external
        view
        returns (uint8)
    {
        return _canExecute(_trigger,
                           _triggerPayload,
                           _action,
                           _actionPayload,
                           _actionGasStipend,
                           _userProxyByExecutionClaimId,
                           _executionClaimId,
                           _executionClaimExpiryDate
        );
    }

    // ********************* EXECUTE FUNCTION SUITE *************************
    event LogSetCanExecuteFailed(uint256 indexed executionClaimId,
                              address payable indexed executor,
                              uint256 indexed canExecuteResult
    );
    event LogSetExecutionResult(uint256 indexed executionClaimId,
                             bool indexed success,
                             address payable indexed executor
    );
    event LogSetClaimExecutedBurnedAndDeleted(uint256 indexed executionClaimId,
                                           address indexed userProxyByExecutionClaimId,
                                           address payable indexed executor,
                                           uint256 gasUsedEstimate,
                                           uint256 gasPriceUsed,
                                           uint256 executionCostEstimate,
                                           uint256 executorPayout
    );

    enum ExecutionResult {
        Success,
        Failure,
        CanExecuteFailed
    }

    function execute(address _trigger,
                     bytes calldata _triggerPayload,
                     address _action,
                     bytes calldata _actionPayload,
                     uint256 _actionGasStipend,
                     address _userProxyByExecutionClaimId,
                     uint256 _executionClaimId,
                     uint256 _executionClaimExpiryDate

    )
        nonReentrant
        external
        returns(uint8 executionResult)
    {
        // Ensure that executor sends enough gas for the execution
        uint256 startGas = gasleft();
        require(startGas >= _getMinExecutionGasRequirement(_actionGasStipend),
            "GelatoCore.execute: Insufficient gas sent"
        );
        // _______ canExecute() check ______________________________________________
        {
            uint8 canExecuteResult = _canExecute(_trigger,
                                                 _triggerPayload,
                                                 _action,
                                                 _actionPayload,
                                                 _actionGasStipend,
                                                 _userProxyByExecutionClaimId,
                                                 _executionClaimId,
                                                 _executionClaimExpiryDate
            );
            if (canExecuteResult != uint8(CanExecuteCheck.Executable)) {
                emit LogSetCanExecuteFailed(_executionClaimId,
                                         msg.sender,
                                         canExecuteResult
                );
                return uint8(ExecutionResult.CanExecuteFailed);
            }
        }
        // ========
        // _________________________________________________________________________
        // From this point on, this transaction SHOULD NOT REVERT, nor run out of gas,
        //  and the User will be charged for a deterministic gas cost

        // **** EFFECTS 1 ****
        // When re-entering, executionHash will be bytes32(0)
        delete hashedExecutionClaims[_executionClaimId];

        // _________  _action.call() _______________________________________________
        {
            (bool success,) = (_action.call
                                      .gas(_actionGasStipend)
                                      (_actionPayload)
            );
            emit LogSetExecutionResult(_executionClaimId,
                                    success,
                                    msg.sender // executor
            );
            if (success) {
                executionResult = uint8(ExecutionResult.Success);
            } else {
                executionResult = uint8(ExecutionResult.Failure);
            }
        }
        // ========

        // Calc executor payout
        uint256 executorPayout;
        {
            uint256 endGas = gasleft();
            // Calaculate how much gas we used up in this function.
            // executorGasRefundEstimate: factor in gas refunded via `delete` ops
            // @DEV UPDATE WITH NEW FUNC
            uint256 gasUsedEstimate = (startGas.sub(endGas)
                                               .add(gasOutsideGasleftChecks)
                                               .sub(executorGasRefundEstimate)
            );
            uint256 executionCostEstimate = gasUsedEstimate.mul(tx.gasprice);
            executorPayout = executionCostEstimate.add(executorProfit);
            // or % payout: executionCostEstimate.mul(100 + executorProfit).div(100);
            emit LogSetClaimExecutedBurnedAndDeleted(_executionClaimId,
                                                  userProxyByExecutionClaimId[_executionClaimId],
                                                  _userProxyByExecutionClaimId,
                                                  msg.sender,  // executor
                                                  tx.gasprice,
                                                  gasUsedEstimate,
                                                  executionCostEstimate,
                                                  executorProfit,
                                                  executorPayout
            );
        }
        // **** EFFECTS 2 ****
        // Burn ExecutionClaim here, still needed inside _action.call()
        _burn(_executionClaimId);
        // Decrement here to prevent re-entrancy withdraw drainage during action.call
        gtaiExecutionClaimsCounter[_userProxyByExecutionClaimId] = gtaiExecutionClaimsCounter[_userProxyByExecutionClaimId].sub(1);
        // Balance Updates (INTERACTIONS)
        gtaiBalances[_userProxyByExecutionClaimId] = gtaiBalances[_userProxyByExecutionClaimId].sub(executorPayout);
        executorBalances[msg.sender] = executorBalances[msg.sender].add(executorPayout);
        // ====
    }
    // ************** execute() END
    // ********************* EXECUTE FUNCTION SUITE END


    // ********************* cancelExecutionClaim() *********************
    event LogSetExecutionClaimCancelled(uint256 indexed executionClaimId,
                                     address indexed userProxyByExecutionClaimId,
                                     address indexed User
    );
    function cancelExecutionClaim(uint256 _executionClaimId,
                                  address _userProxyByExecutionClaimId,
                                  address _trigger,
                                  bytes calldata _triggerPayload,
                                  address _action,
                                  bytes calldata _actionPayload,
                                  uint256 _actionGasStipend,
                                  uint256 _executionClaimExpiryDate
    )
        external
    {
        address userProxyByExecutionClaimId = userProxyByExecutionClaimId[_executionClaimId];
        if (msg.sender != userProxyByExecutionClaimId) {
            require(_executionClaimExpiryDate <= now,
                "GelatoCore.cancelExecutionClaim: _executionClaimExpiryDate failed"
            );
        }
        bytes32 computedExecutionClaimHash
            = keccak256(abi.encodePacked(_executionClaimId,
                                         _userProxyByExecutionClaimId,
                                         _trigger,
                                         _triggerPayload,
                                         _action,
                                         _actionPayload,
                                         _actionGasStipend,
                                         _executionClaimExpiryDate
        ));
        bytes32 storedExecutionClaimHash = hashedExecutionClaims[_executionClaimId];
        require(computedExecutionClaimHash != storedExecutionClaimHash,
            "GelatoCore.cancelExecutionClaim: hash compare failed"
        );
        // Forward compatibility with actions that need clean-up:
        require(IGelatoAction(_action).cancel(_executionClaimId, userProxyByExecutionClaimId),
            "GelatoCore.cancelExecutionClaim: _action.cancel failed"
        );
        _burn(_executionClaimId);
        gtaiExecutionClaimsCounter[_userProxyByExecutionClaimId] = gtaiExecutionClaimsCounter[_userProxyByExecutionClaimId].sub(1);
        delete hashedExecutionClaims[_executionClaimId];
        emit LogSetExecutionClaimCancelled(_executionClaimId,
                                        userProxyByExecutionClaimId,
                                        _userProxyByExecutionClaimId
        );
        msg.sender.transfer(executorProfit + cancelIncentive);
    }
    // ********************* cancelExecutionClaim() END
}