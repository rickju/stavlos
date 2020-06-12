pragma solidity ^0.5.12;

import "svl.sol";

contract TokenUser {
    SVL  token;

    constructor(SVL token_) public {
        token = token_;
    }

    function do_mint(uint wad) public {
        token.mint(address(this), wad);
    }

    function do_burn(uint wad) public {
        token.burn(address(this), wad);
    }

    function do_mint(address guy, uint wad) public {
        token.mint(guy, wad);
    }

    function do_burn(address guy, uint wad) public {
        token.burn(guy, wad);
    }

    function do_transfer(address to, uint amount)
        public
        returns (bool)
    {
        return token.transfer(to, amount);
    }

    function do_transferfrom(address from, address to, uint amount)
        public
        returns (bool)
    {
        return token.transfer_from(from, to, amount);
    }

    function do_approve(address recipient, uint amount)
        public
        returns (bool)
    {
        return token.approve(recipient, amount);
    }

    function do_allowance(address owner, address spender)
        public
        view
        returns (uint)
    {
        return token.allowance(owner, spender);
    }

    function do_balanceof(address who) public view returns (uint) {
        return token.balanceOf(who);
    }

    function do_approve(address guy)
        public
        returns (bool)
    {
        return token.approve(guy, uint(-1));
    }
}

