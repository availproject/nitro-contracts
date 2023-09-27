// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./AbsInbox.t.sol";
import "./util/TestUtil.sol";
import "../../src/bridge/ERC20Bridge.sol";
import "../../src/bridge/ERC20Inbox.sol";
import "../../src/bridge/ISequencerInbox.sol";
import "../../src/libraries/AddressAliasHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


contract ERC20InboxTest is AbsInboxTest {
    IERC20 public nativeToken;
    IERC20Inbox public erc20Inbox;

    function setUp() public {
        // deploy token, bridge and inbox
        nativeToken = new ERC20PresetMinterPauser("Appchain Token", "App");
        bridge = IBridge(TestUtil.deployProxy(address(new ERC20Bridge())));
        inbox = IInboxBase(TestUtil.deployProxy(address(new ERC20Inbox())));
        erc20Inbox = IERC20Inbox(address(inbox));

        // init bridge and inbox
        IERC20Bridge(address(bridge)).initialize(IOwnable(rollup), address(nativeToken));
        inbox.initialize(bridge, ISequencerInbox(seqInbox));
        vm.prank(rollup);
        bridge.setDelayedInbox(address(inbox), true);

        // fund user account
        ERC20PresetMinterPauser(address(nativeToken)).mint(user, 1000 ether);
    }

    /* solhint-disable func-name-mixedcase */
    function test_initialize() public {
        assertEq(address(inbox.bridge()), address(bridge), "Invalid bridge ref");
        assertEq(address(inbox.sequencerInbox()), seqInbox, "Invalid seqInbox ref");
        assertEq(inbox.allowListEnabled(), false, "Invalid allowListEnabled");
        assertEq((PausableUpgradeable(address(inbox))).paused(), false, "Invalid paused state");

        assertEq(IERC20(nativeToken).allowance(address(inbox), address(bridge)), type(uint256).max);
    }

    function test_depositERC20_FromEOA() public {
        uint256 depositAmount = 300;

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = bridge.delayedMessageCount();

        // approve inbox to fetch tokens
        vm.prank(user);
        nativeToken.approve(address(inbox), depositAmount);

        // expect event
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(0, abi.encodePacked(user, depositAmount));

        // deposit tokens -> tx.origin == msg.sender
        vm.prank(user, user);
        erc20Inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            depositAmount,
            "Invalid user token balance"
        );

        uint256 delayedMsgCountAfter = bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_FromEOA_LessThan18Decimals() public {
        uint8 decimals = 6;
        ERC20 _nativeToken = new ERC20_6Decimals();

        IERC20Bridge _bridge = IERC20Bridge(TestUtil.deployProxy(address(new ERC20Bridge())));
        IERC20Inbox _inbox = IERC20Inbox(TestUtil.deployProxy(address(new ERC20Inbox())));

        // init bridge and inbox
        address _rollup = makeAddr("_rollup");
        _bridge.initialize(IOwnable(_rollup), address(_nativeToken));
        _inbox.initialize(_bridge, ISequencerInbox(makeAddr("_seqInbox")));
        vm.prank(_rollup);
        _bridge.setDelayedInbox(address(_inbox), true);

        // fund user account
        ERC20_6Decimals(address(_nativeToken)).mint(user, 1000 * 10 ** decimals);

        uint256 depositAmount = 300 * 10 ** decimals;

        uint256 bridgeTokenBalanceBefore = _nativeToken.balanceOf(address(_bridge));
        uint256 userTokenBalanceBefore = _nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = _bridge.delayedMessageCount();

        // approve inbox to fetch tokens
        vm.prank(user);
        _nativeToken.approve(address(_inbox), depositAmount);

        // expect event
        uint256 expectedAmountToMintOnL2 = depositAmount * 10 ** (18 - decimals);
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(0, abi.encodePacked(user, expectedAmountToMintOnL2));

        // deposit tokens -> tx.origin == msg.sender
        vm.prank(user, user);
        _inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = _nativeToken.balanceOf(address(_bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = _nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            depositAmount,
            "Invalid user token balance"
        );

        uint256 delayedMsgCountAfter = _bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_FromEOA_MoreThan18Decimals() public {
        uint8 decimals = 20;
        ERC20 _nativeToken = new ERC20_20Decimals();

        IERC20Bridge _bridge = IERC20Bridge(TestUtil.deployProxy(address(new ERC20Bridge())));
        IERC20Inbox _inbox = IERC20Inbox(TestUtil.deployProxy(address(new ERC20Inbox())));

        // init bridge and inbox
        address _rollup = makeAddr("_rollup");
        _bridge.initialize(IOwnable(_rollup), address(_nativeToken));
        _inbox.initialize(_bridge, ISequencerInbox(makeAddr("_seqInbox")));
        vm.prank(_rollup);
        _bridge.setDelayedInbox(address(_inbox), true);

        // fund user account
        ERC20_20Decimals(address(_nativeToken)).mint(user, 1000 * 10 ** decimals);

        uint256 depositAmount = 300 * 10 ** decimals;

        uint256 bridgeTokenBalanceBefore = _nativeToken.balanceOf(address(_bridge));
        uint256 userTokenBalanceBefore = _nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = _bridge.delayedMessageCount();

        // approve inbox to fetch tokens
        vm.prank(user);
        _nativeToken.approve(address(_inbox), depositAmount);

        // expect event
        uint256 expectedAmountToMintOnL2 = depositAmount / (10 ** (decimals - 18));
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(0, abi.encodePacked(user, expectedAmountToMintOnL2));

        // deposit tokens -> tx.origin == msg.sender
        vm.prank(user, user);
        _inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = _nativeToken.balanceOf(address(_bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = _nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            depositAmount,
            "Invalid user token balance"
        );

        uint256 delayedMsgCountAfter = _bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_FromEOA_NoDecimals() public {
        ERC20 _nativeToken = new ERC20NoDecimals();

        IERC20Bridge _bridge = IERC20Bridge(TestUtil.deployProxy(address(new ERC20Bridge())));
        IERC20Inbox _inbox = IERC20Inbox(TestUtil.deployProxy(address(new ERC20Inbox())));

        // init bridge and inbox
        address _rollup = makeAddr("_rollup");
        _bridge.initialize(IOwnable(_rollup), address(_nativeToken));
        _inbox.initialize(_bridge, ISequencerInbox(makeAddr("_seqInbox")));
        vm.prank(_rollup);
        _bridge.setDelayedInbox(address(_inbox), true);

        // fund user account
        ERC20NoDecimals(address(_nativeToken)).mint(user, 1000);

        uint256 depositAmount = 300;

        uint256 bridgeTokenBalanceBefore = _nativeToken.balanceOf(address(_bridge));
        uint256 userTokenBalanceBefore = _nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = _bridge.delayedMessageCount();

        // approve inbox to fetch tokens
        vm.prank(user);
        _nativeToken.approve(address(_inbox), depositAmount);

        // expect event
        uint256 expectedAmountToMintOnL2 = depositAmount * 10 ** 18;
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(0, abi.encodePacked(user, expectedAmountToMintOnL2));

        // deposit tokens -> tx.origin == msg.sender
        vm.prank(user, user);
        _inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = _nativeToken.balanceOf(address(_bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = _nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            depositAmount,
            "Invalid user token balance"
        );

        uint256 delayedMsgCountAfter = _bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_FromEOA_InboxPrefunded() public {
        uint256 depositAmount = 300;

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = bridge.delayedMessageCount();

        // prefund inbox with native token amount needed to pay for fees
        ERC20PresetMinterPauser(address(nativeToken)).mint(address(inbox), depositAmount);

        // expect event
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(0, abi.encodePacked(user, depositAmount));

        // deposit tokens -> tx.origin == msg.sender
        vm.prank(user, user);
        erc20Inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(userTokenBalanceBefore, userTokenBalanceAfter, "Invalid user token balance");

        uint256 delayedMsgCountAfter = bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_FromContract() public {
        uint256 depositAmount = 300;

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));
        uint256 delayedMsgCountBefore = bridge.delayedMessageCount();

        // approve inbox to fetch tokens
        vm.prank(user);
        nativeToken.approve(address(inbox), depositAmount);

        // expect event
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(
            0, abi.encodePacked(AddressAliasHelper.applyL1ToL2Alias(user), depositAmount)
        );

        // deposit tokens -> tx.origin != msg.sender
        vm.prank(user);
        erc20Inbox.depositERC20(depositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            depositAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            depositAmount,
            "Invalid user token balance"
        );

        uint256 delayedMsgCountAfter = bridge.delayedMessageCount();
        assertEq(delayedMsgCountAfter - delayedMsgCountBefore, 1, "Invalid delayed message count");
    }

    function test_depositERC20_revert_NativeTokenTransferFails() public {
        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));

        // deposit tokens
        vm.prank(user);
        uint256 invalidDepositAmount = 1_000_000;
        vm.expectRevert("ERC20: insufficient allowance");
        erc20Inbox.depositERC20(invalidDepositAmount);

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(bridgeTokenBalanceAfter, bridgeTokenBalanceBefore, "Invalid bridge token balance");

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(userTokenBalanceBefore, userTokenBalanceAfter, "Invalid user token balance");

        assertEq(bridge.delayedMessageCount(), 0, "Invalid delayed message count");
    }

    function test_createRetryableTicket_FromEOA() public {
        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));

        uint256 tokenTotalFeeAmount = 300;

        // approve inbox to fetch tokens
        vm.prank(user);
        nativeToken.approve(address(inbox), tokenTotalFeeAmount);

        // retyrable params
        uint256 l2CallValue = 10;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 100;
        uint256 maxFeePerGas = 2;
        bytes memory data = abi.encodePacked("some msg");

        // expect event
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(
            0,
            abi.encodePacked(
                uint256(uint160(user)),
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                uint256(uint160(user)),
                uint256(uint160(user)),
                gasLimit,
                maxFeePerGas,
                data.length,
                data
            )
        );

        // create retryable -> tx.origin == msg.sender
        vm.prank(user, user);
        erc20Inbox.createRetryableTicket({
            to: address(user),
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            tokenTotalFeeAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            tokenTotalFeeAmount,
            "Invalid user token balance"
        );

        assertEq(bridge.delayedMessageCount(), 1, "Invalid delayed message count");
    }

    function test_createRetryableTicket_FromContract() public {
        address sender = address(new Sender());
        ERC20PresetMinterPauser(address(nativeToken)).mint(address(sender), 1000);

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 senderTokenBalanceBefore = nativeToken.balanceOf(address(sender));

        uint256 tokenTotalFeeAmount = 300;

        // approve inbox to fetch tokens
        vm.prank(sender);
        nativeToken.approve(address(inbox), tokenTotalFeeAmount);

        // retyrable params
        uint256 l2CallValue = 10;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 100;
        uint256 maxFeePerGas = 2;
        bytes memory data = abi.encodePacked("some msg");

        // expect event
        uint256 uintAlias = uint256(uint160(AddressAliasHelper.applyL1ToL2Alias(sender)));
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(
            0,
            abi.encodePacked(
                uint256(uint160(sender)),
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                uintAlias,
                uintAlias,
                gasLimit,
                maxFeePerGas,
                data.length,
                data
            )
        );

        // create retryable
        vm.prank(sender);
        erc20Inbox.createRetryableTicket({
            to: sender,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: sender,
            callValueRefundAddress: sender,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            tokenTotalFeeAmount,
            "Invalid bridge token balance"
        );

        uint256 senderTokenBalanceAfter = nativeToken.balanceOf(sender);
        assertEq(
            senderTokenBalanceBefore - senderTokenBalanceAfter,
            tokenTotalFeeAmount,
            "Invalid sender token balance"
        );

        assertEq(bridge.delayedMessageCount(), 1, "Invalid delayed message count");
    }

    function test_createRetryableTicket_revert_WhenPaused() public {
        vm.prank(rollup);
        inbox.pause();

        vm.expectRevert("Pausable: paused");
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: 100,
            maxSubmissionCost: 0,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: 10,
            maxFeePerGas: 1,
            tokenTotalFeeAmount: 200,
            data: abi.encodePacked("data")
        });
    }

    function test_createRetryableTicket_revert_OnlyAllowed() public {
        vm.prank(rollup);
        inbox.setAllowListEnabled(true);

        vm.prank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotAllowedOrigin.selector, user));
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: 100,
            maxSubmissionCost: 0,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: 10,
            maxFeePerGas: 1,
            tokenTotalFeeAmount: 200,
            data: abi.encodePacked("data")
        });
    }

    function test_createRetryableTicket_revert_InsufficientValue() public {
        uint256 tooSmallTokenTotalFeeAmount = 3;
        uint256 l2CallValue = 100;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 10;
        uint256 maxFeePerGas = 1;

        vm.prank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientValue.selector,
                maxSubmissionCost + l2CallValue + gasLimit * maxFeePerGas,
                tooSmallTokenTotalFeeAmount
            )
        );
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tooSmallTokenTotalFeeAmount,
            data: abi.encodePacked("data")
        });
    }

    function test_createRetryableTicket_revert_RetryableDataTracer() public {
        uint256 tokenTotalFeeAmount = 300;
        uint256 l2CallValue = 100;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 10;
        uint256 maxFeePerGas = 1;
        bytes memory data = abi.encodePacked("xy");

        // revert as maxFeePerGas == 1 is magic value
        vm.prank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                RetryableData.selector,
                user,
                user,
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                user,
                user,
                gasLimit,
                maxFeePerGas,
                data
            )
        );
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });

        gasLimit = 1;
        maxFeePerGas = 2;

        // revert as gasLimit == 1 is magic value
        vm.prank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                RetryableData.selector,
                user,
                user,
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                user,
                user,
                gasLimit,
                maxFeePerGas,
                data
            )
        );
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });
    }

    function test_createRetryableTicket_revert_GasLimitTooLarge() public {
        uint256 tooBigGasLimit = uint256(type(uint64).max) + 1;

        vm.prank(user, user);
        vm.expectRevert(GasLimitTooLarge.selector);
        erc20Inbox.createRetryableTicket({
            to: user,
            l2CallValue: 100,
            maxSubmissionCost: 0,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: tooBigGasLimit,
            maxFeePerGas: 2,
            tokenTotalFeeAmount: uint256(type(uint64).max) * 3,
            data: abi.encodePacked("data")
        });
    }

    function test_unsafeCreateRetryableTicket_FromEOA() public {
        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));

        uint256 tokenTotalFeeAmount = 300;

        // approve inbox to fetch tokens
        vm.prank(user);
        nativeToken.approve(address(inbox), tokenTotalFeeAmount);

        // retyrable params
        uint256 l2CallValue = 10;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 100;
        uint256 maxFeePerGas = 2;
        bytes memory data = abi.encodePacked("some msg");

        // expect event
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(
            0,
            abi.encodePacked(
                uint256(uint160(user)),
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                uint256(uint160(user)),
                uint256(uint160(user)),
                gasLimit,
                maxFeePerGas,
                data.length,
                data
            )
        );

        // create retryable -> tx.origin == msg.sender
        vm.prank(user, user);
        erc20Inbox.unsafeCreateRetryableTicket({
            to: address(user),
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            tokenTotalFeeAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            tokenTotalFeeAmount,
            "Invalid user token balance"
        );

        assertEq(bridge.delayedMessageCount(), 1, "Invalid delayed message count");
    }

    function test_unsafeCreateRetryableTicket_FromContract() public {
        address sender = address(new Sender());
        ERC20PresetMinterPauser(address(nativeToken)).mint(address(sender), 1000);

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 senderTokenBalanceBefore = nativeToken.balanceOf(address(sender));

        uint256 tokenTotalFeeAmount = 300;

        // approve inbox to fetch tokens
        vm.prank(sender);
        nativeToken.approve(address(inbox), tokenTotalFeeAmount);

        // retyrable params
        uint256 l2CallValue = 10;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 100;
        uint256 maxFeePerGas = 2;
        bytes memory data = abi.encodePacked("some msg");

        // expect event (address shall not be aliased)
        vm.expectEmit(true, true, true, true);
        emit InboxMessageDelivered(
            0,
            abi.encodePacked(
                uint256(uint160(sender)),
                l2CallValue,
                tokenTotalFeeAmount,
                maxSubmissionCost,
                uint256(uint160(sender)),
                uint256(uint160(sender)),
                gasLimit,
                maxFeePerGas,
                data.length,
                data
            )
        );

        // create retryable
        vm.prank(sender);
        erc20Inbox.unsafeCreateRetryableTicket({
            to: sender,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: sender,
            callValueRefundAddress: sender,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tokenTotalFeeAmount,
            data: data
        });

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            tokenTotalFeeAmount,
            "Invalid bridge token balance"
        );

        uint256 senderTokenBalanceAfter = nativeToken.balanceOf(sender);
        assertEq(
            senderTokenBalanceBefore - senderTokenBalanceAfter,
            tokenTotalFeeAmount,
            "Invalid sender token balance"
        );

        assertEq(bridge.delayedMessageCount(), 1, "Invalid delayed message count");
    }

    function test_unsafeCreateRetryableTicket_NotRevertingOnInsufficientValue() public {
        uint256 tooSmallTokenTotalFeeAmount = 3;
        uint256 l2CallValue = 100;
        uint256 maxSubmissionCost = 0;
        uint256 gasLimit = 10;
        uint256 maxFeePerGas = 2;

        uint256 bridgeTokenBalanceBefore = nativeToken.balanceOf(address(bridge));
        uint256 userTokenBalanceBefore = nativeToken.balanceOf(address(user));

        // approve inbox to fetch tokens
        vm.prank(user);
        nativeToken.approve(address(inbox), tooSmallTokenTotalFeeAmount);

        vm.prank(user, user);
        erc20Inbox.unsafeCreateRetryableTicket({
            to: user,
            l2CallValue: l2CallValue,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: user,
            callValueRefundAddress: user,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            tokenTotalFeeAmount: tooSmallTokenTotalFeeAmount,
            data: abi.encodePacked("data")
        });

        //// checks

        uint256 bridgeTokenBalanceAfter = nativeToken.balanceOf(address(bridge));
        assertEq(
            bridgeTokenBalanceAfter - bridgeTokenBalanceBefore,
            tooSmallTokenTotalFeeAmount,
            "Invalid bridge token balance"
        );

        uint256 userTokenBalanceAfter = nativeToken.balanceOf(address(user));
        assertEq(
            userTokenBalanceBefore - userTokenBalanceAfter,
            tooSmallTokenTotalFeeAmount,
            "Invalid user token balance"
        );

        assertEq(bridge.delayedMessageCount(), 1, "Invalid delayed message count");
    }

    function test_calculateRetryableSubmissionFee() public {
        assertEq(inbox.calculateRetryableSubmissionFee(1, 2), 0, "Invalid ERC20 submission fee");
    }
}

/* solhint-disable contract-name-camelcase */
contract ERC20_6Decimals is ERC20 {
    constructor() ERC20("XY", "xy") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }
}

/* solhint-disable contract-name-camelcase */
contract ERC20_20Decimals is ERC20 {
    constructor() ERC20("XY", "xy") {}

    function decimals() public pure override returns (uint8) {
        return 20;
    }

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }
}

contract ERC20NoDecimals is ERC20 {
    constructor() ERC20("XY", "xy") {}

    function decimals() public pure override returns (uint8) {
        revert("not supported");
    }
    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }
}