pragma solidity ^0.5.12;

import "./lib.sol";

contract VatLike {
    function move(address,address,uint) external;
    function flux(bytes32,address,address,uint) external;
}

contract Keeper is Libsvl {
    // auth
    mapping (address => uint) public wards;
    function rely(address usr) external token auth { wards[usr] = 1; }
    function deny(address usr) external token auth { wards[usr] = 0; }

    modifier auth {
        require(wards[msg.sender] == 1, "Keeper/not-authorized");
        _;
    }

    // data
    struct Bid {
        uint256 bid;  // SVL paid                 [rad]
        uint256 lot;  // tkns in return for bid   [wad]
        address wnr;  // high bidder
        uint48  tic;  // bid expiry time          [unix epoch time]
        uint48  end;  // auction expiry time      [unix epoch time]
        address usr;
        address gal;
        uint256 tab;  // total SVL wanted    [rad]
    }

    mapping (uint => Bid) public bids;

    VatLike public   vat;
    bytes32 public   ilk;

    uint256 constant ONE = 1.00E18;
    uint256 public   rai = 1.05E18;  // 5% minimum bid increase
    uint48  public   ttl = 3 hours;  // 3 hours bid duration         [seconds]
    uint48  public   tau = 2 days;   // 2 days total auction length  [seconds]
    uint256 public kicks = 0;

    // evts
    event Kick(
      uint256 id,
      uint256 lot,
      uint256 bid,
      uint256 tab,
      address indexed usr,
      address indexed gal
    );

    // init
    constructor(address vat_, bytes32 ilk_) public {
        vat = VatLike(vat_);
        ilk = ilk_;
        wards[msg.sender] = 1;
    }

    // add/mul
    function add(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // admin
    function file(bytes32 what, uint data) external token auth {
        if (what == "rai") rai = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Keeper/file-unrecognized-param");
    }

    // auction
    function kick(address usr, address gal, uint tab, uint lot, uint bid)
        public auth returns (uint id)
    {
        require(kicks < uint(-1), "Keeper/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].wnr = msg.sender;  // configurable??
        bids[id].end = add(uint48(now), tau);
        bids[id].usr = usr;
        bids[id].gal = gal;
        bids[id].tab = tab;

        vat.flux(ilk, msg.sender, address(this), lot);

        emit Kick(id, lot, bid, tab, usr, gal);
    }

    function tick(uint id) external token {
        require(bids[id].end < now, "Keeper/not-finished");
        require(bids[id].tic == 0, "Keeper/bid-already-placed");
        bids[id].end = add(uint48(now), tau);
    }

    function tend(uint id, uint lot, uint bid) external token {
        require(bids[id].wnr != address(0), "Keeper/wnr-not-set");
        require(bids[id].tic > now || bids[id].tic == 0, "Keeper/already-finished-tic");
        require(bids[id].end > now, "Keeper/already-finished-end");

        require(lot == bids[id].lot, "Keeper/lot-not-matching");
        require(bid <= bids[id].tab, "Keeper/higher-than-tab");
        require(bid >  bids[id].bid, "Keeper/bid-not-higher");
        require(mul(bid, ONE) >= mul(rai, bids[id].bid) || bid == bids[id].tab, "Keeper/insufficient-increase");

        vat.move(msg.sender, bids[id].wnr, bids[id].bid);
        vat.move(msg.sender, bids[id].gal, bid - bids[id].bid);

        bids[id].wnr = msg.sender;
        bids[id].bid = bid;
        bids[id].tic = add(uint48(now), ttl);
    }

    function dent(uint id, uint lot, uint bid) external token {
        require(bids[id].wnr != address(0), "Keeper/wnr-not-set");
        require(bids[id].tic > now || bids[id].tic == 0, "Keeper/already-finished-tic");
        require(bids[id].end > now, "Keeper/already-finished-end");

        require(bid == bids[id].bid, "Keeper/not-matching-bid");
        require(bid == bids[id].tab, "Keeper/tend-not-finished");
        require(lot < bids[id].lot, "Keeper/lot-not-lower");
        require(mul(rai, lot) <= mul(bids[id].lot, ONE), "Keeper/insufficient-decrease");

        vat.move(msg.sender, bids[id].wnr, bid);
        vat.flux(ilk, address(this), bids[id].usr, bids[id].lot - lot);

        bids[id].wnr = msg.sender;
        bids[id].lot = lot;
        bids[id].tic = add(uint48(now), ttl);
    }

    function deal(uint id) external token {
        require(bids[id].tic != 0 && (bids[id].tic < now || bids[id].end < now), "Keeper/not-finished");
        vat.flux(ilk, address(this), bids[id].wnr, bids[id].lot);
        delete bids[id];
    }

    function yank(uint id) external token auth {
        require(bids[id].wnr != address(0), "Keeper/wnr-not-set");
        require(bids[id].bid < bids[id].tab, "Keeper/already-dent-phase");
        vat.flux(ilk, address(this), msg.sender, bids[id].lot);
        vat.move(msg.sender, bids[id].wnr, bids[id].bid);
        delete bids[id];
    }
}
