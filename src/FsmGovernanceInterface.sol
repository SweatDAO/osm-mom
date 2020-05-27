/// FsmGovernanceInterface -- governance interface for oracle security modules

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

pragma solidity ^0.5.15;

contract FsmLike {
    function stop() external;
}

contract AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) public view returns (bool);
}

contract FsmGovernanceInterface {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  usr,
        bytes32  indexed  arg1,
        bytes32  indexed  arg2,
        bytes             data
    ) anonymous;

    modifier emitLog {
        _;
        assembly {
            // log an 'anonymous' event with a constant 6 words of calldata
            // and four indexed topics: selector, caller, arg1 and arg2
            let mark := msize                         // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 caller,                              // msg.sender
                 calldataload(4),                     // arg1
                 calldataload(36)                     // arg2
                )
        }
    }

    address public owner;
    modifier onlyOwner { require(msg.sender == owner, "fsm-governance-interface/only-owner"); _;}

    address public authority;
    modifier isAuthorized {
        require(canCall(msg.sender, msg.sig), "fsm-governance-interface/not-authorized");
        _;
    }
    function canCall(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

    mapping (bytes32 => address) public fsms;

    constructor() public {
        owner = msg.sender;
    }

    function setFsm(bytes32 collateralType, address fsm) external emitLog onlyOwner {
        fsms[collateralType] = fsm;
    }

    function setOwner(address owner_) external emitLog onlyOwner {
        owner = owner_;
    }

    function setAuthority(address authority_) external emitLog onlyOwner {
        authority = authority_;
    }

    function stop(bytes32 collateralType) external emitLog isAuthorized {
        FsmLike(fsms[collateralType]).stop();
    }
}
