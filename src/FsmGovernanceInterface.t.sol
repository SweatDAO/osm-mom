// Copyright (C) 2019 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "geb-fsm/OSM.sol";
import "./FsmGovernanceInterface.sol";

contract FsmGovernanceInterfaceCaller {
    FsmGovernanceInterface fsmGovernanceInterface;

    constructor(FsmGovernanceInterface fsmGovernanceInterface_) public {
        fsmGovernanceInterface = fsmGovernanceInterface_;
    }

    function setOwner(address newOwner) public {
        fsmGovernanceInterface.setOwner(newOwner);
    }

    function setAuthority(address newAuthority) public {
        fsmGovernanceInterface.setAuthority(newAuthority);
    }

    function setFsm(bytes32 collateralType, address fsm) public {
        fsmGovernanceInterface.setFsm(collateralType, fsm);
    }

    function stopFsm(bytes32 collateralType) public {
        fsmGovernanceInterface.stopFsm(collateralType);
    }
}

contract SimpleAuthority {
    address public authorized_caller;

    constructor(address authorized_caller_) public {
        authorized_caller = authorized_caller_;
    }

    function canCall(address src, address, bytes4) public view returns (bool) {
        return src == authorized_caller;
    }
}

contract FsmGovernanceInterfaceTest is DSTest {
    OSM fsm;
    FsmGovernanceInterface fsmGovernanceInterface;
    FsmGovernanceInterfaceCaller caller;
    SimpleAuthority authority;

    function setUp() public {
        fsm = new OSM(address(this));
        fsmGovernanceInterface = new FsmGovernanceInterface();
        fsmGovernanceInterface.setFsm("ETH-A", address(fsm));
        caller = new FsmGovernanceInterfaceCaller(fsmGovernanceInterface);
        authority = new SimpleAuthority(address(caller));
        fsmGovernanceInterface.setAuthority(address(authority));
        fsm.addAuthorization(address(fsmGovernanceInterface));
    }

    function testVerifySetup() public {
        assertTrue(fsmGovernanceInterface.owner() == address(this));
        assertTrue(fsmGovernanceInterface.authority() == address(authority));
        assertEq(fsm.authorizedAccounts(address(fsmGovernanceInterface)), 1);
    }

    function testSetOwner() public {
        fsmGovernanceInterface.setOwner(address(0));
        assertTrue(fsmGovernanceInterface.owner() == address(0));
    }

    function testFailSetOwner() public {
        // fails because the caller is not the owner
        caller.setOwner(address(0));
    }

    function testSetAuthority() public {
        fsmGovernanceInterface.setAuthority(address(0));
        assertTrue(fsmGovernanceInterface.authority() == address(0));
    }

    function testFailSetAuthority() public {
        // fails because the caller is not the owner
        caller.setAuthority(address(0));
    }

    function testSetFsm() public {
        fsmGovernanceInterface.setFsm("ETH-B", address(1));
        assertTrue(fsmGovernanceInterface.fsms("ETH-B") == address(1));
    }

    function testFailSetFsm() public {
        // fails because the caller is not an owner
        caller.setFsm("ETH-A", address(0));
    }

    function testStopAuthorized() public {
        caller.stopFsm("ETH-A");
        assertEq(fsm.stopped(), 1);
    }

    function testStopOwner() public {
        fsmGovernanceInterface.stopFsm("ETH-A");
        assertEq(fsm.stopped(), 1);
    }

    function testFailStopCallerNotAuthorized() public {
        SimpleAuthority newAuthority = new SimpleAuthority(address(this));
        fsmGovernanceInterface.setAuthority(address(newAuthority));
        // fails because the caller is no longer authorized on the mom
        caller.stopFsm("ETH-A");
    }

    function testFailStopNoAuthority() public {
        fsmGovernanceInterface.setAuthority(address(0));
        caller.stopFsm("ETH-A");
    }

    function testFailCollateralTypeWithoutFsm() public {
        caller.stopFsm("DOGE");
    }
}
