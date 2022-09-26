pragma solidity >=0.8.7;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external payable;

    function totalSupply() external returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);
}
