// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./INagaKid.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SaleKids is Ownable, ReentrancyGuard {

    bytes32 public constant WHITELIST_MINT_ROUND = keccak256("WHITELIST_MINT_ROUND"); // 0x68e7d51fdb912cb107dda2e59b053d87fcca666dd0ef5339cd3474ccb5276bba
    bytes32 public constant NAGA_HOLDER_MINT_ROUND = keccak256("NAGA_HOLDER_MINT_ROUND"); // 0xb3c595e55271590809f54e2f4fc3a582754f45b104dd3c41666e2ad310493db3
  
    bytes32 public constant DEFAULT = 0x0000000000000000000000000000000000000000000000000000000000000000;


    INagaKid public nagaKids;
    bytes32 public currentMintRound;
    bytes32 public merkleRoot;

    bool public isPrivate = false;
    bool public isPublic = false;

    address public signer;

    mapping(address => mapping(bytes32 => bool)) internal _isPrivateUserMinted;
    mapping(address => mapping(bytes32 => uint256)) internal _privateUserMintedAmount;
    mapping(address => bool) internal _isPublicUserMinted;

    // Events
    event PrivateMinted(address indexed user, uint256 amount, uint256 timestamp);
    event PublicMinted(address indexed user, uint256 amount, uint256 timestamp);
    event NagaKidsChanged(address oldNagaKids, address nagaKidsAfter);
    event MerkleRootChanged(bytes32 merkleRootBefore, bytes32 merkleRootAfter);
    event RoundChanged(bytes32 roundBefore, bytes32 roundAfter);
    event SignerChanged(address signerBefore,address signerAfter);
    event Withdraw(address to, uint256 balanceOFContract , uint256 timestamp);
    event WithdrawToken(address to,address currency,uint256 balanceOfContract,uint256 timestamp);
    event PublicMintChanged(bool boolean);
    event PrivateMintChanged(bool boolean);

    constructor(INagaKid _nagaKids, address _signer, bytes32 _merkleRoot) {
        setNagaKids(_nagaKids);
        setMerkleRoot(_merkleRoot);
        setSigner(_signer);
    }

    function setPublicMint(bool _bool) public onlyOwner {
        isPublic = _bool;
        emit PublicMintChanged(_bool);
    }

    function setPrivateMint(bool _bool) public onlyOwner {
        isPublic = _bool;
        emit PrivateMintChanged(_bool);
    }

    function setNagaKids(INagaKid _nagaKids) public onlyOwner {
        address oldNagaKids = address(nagaKids);
        nagaKids = _nagaKids;
        address nagaKidsAfter = address(_nagaKids);
        emit NagaKidsChanged(oldNagaKids, nagaKidsAfter);
    }

    //private round
    function setRound(bytes32 _round) public onlyOwner {
        bytes32 _oldRound = currentMintRound;
        currentMintRound = _round;

        emit RoundChanged(_oldRound, _round);
    }

    function setSigner(address _signer) public onlyOwner {
        address _oldSigner = signer;
        signer = _signer;

        emit SignerChanged(_oldSigner, _signer);
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        bytes32 _oldMerkleRoot = merkleRoot;
        merkleRoot = _merkleRoot;

        emit MerkleRootChanged(_oldMerkleRoot, _merkleRoot);
    }

    function privateMint(bytes32[] calldata _proof, uint256 _amount, bytes32 _round) public payable nonReentrant {

        //This is payable function.
        //You can tip Naga Team if you want.

        require(isPrivate == true,"Private mint is not open.");
        require(currentMintRound == _round, "Contract are not in this minting round.");
        require(getTotalSupply() + _amount <= 1011,"Over Supply Amount");
        require(isPrivateUserMinted(msg.sender, _round) == false, "You are already minted.");
        require(MerkleProof.verify(_proof, merkleRoot, keccak256(abi.encodePacked(msg.sender, _amount, _round))), "Unauthorized WhitelistMint This User.");

        _isPrivateUserMinted[msg.sender][_round] = true;
        _privateUserMintedAmount[msg.sender][_round] += _amount;

        nagaKids.safeMint(msg.sender,_amount);

        emit PrivateMinted(msg.sender, _amount, block.timestamp);
    }

    function publicMint(bytes calldata _sig) public payable nonReentrant {

        //This is payable function.
        //You can tip Naga Team if you want.
        
        require(isPublic == true, "Public mint is not open.");
        require(tx.origin == msg.sender, "haha Contract can't call me");
        require(isPublicUserMinted(msg.sender) != true, "You are already minted.");
        require(getTotalSupply() + 1 <= 1111, "Over Supply Amount");
        require(ECDSA.recover(keccak256(abi.encodePacked(msg.sender, address(this))), _sig) == signer, "Unauthorized PublicMint This User.");

        // publicMint User can get only 1 //
        uint256 _amount = 1; 

        _isPublicUserMinted[msg.sender] = true;
        nagaKids.safeMint(msg.sender, _amount);
        
        emit PublicMinted(msg.sender, _amount, block.timestamp);

    }

    function isPublicUserMinted(address _addr) public view returns(bool){
        return _isPublicUserMinted[_addr];
    }

    function withdraw(address _to) public onlyOwner {
        uint balanceOFContract = address(this).balance;
        require(balanceOFContract > 0, "Insufficient Balance");
        (bool status,) = _to.call{value: balanceOFContract }("");
        require(status);

        emit Withdraw(_to, balanceOFContract ,block.timestamp);
    }

    function withdrawToken(address _to, address _token) public onlyOwner {
        uint balanceOfContract = IERC20(_token).balanceOf(address(this));
        require(balanceOfContract > 0, "Insufficient Balance");
        IERC20(_token).transfer(_to, balanceOfContract);
        
        emit WithdrawToken(_to, _token, balanceOfContract, block.timestamp);
    }

    function isPrivateUserMinted(address _user,bytes32 _round) public view returns(bool) {
        return _isPrivateUserMinted[_user][_round];
    }

    function privateUserMintedAmount(address _user,bytes32 _round) public view returns(uint256) {
        return _privateUserMintedAmount[_user][_round];
    }

    function getTotalSupply() public view returns (uint256) {
        return nagaKids.totalSupply();
    }

    function getMaxSupply() public view returns (uint256) {
        return nagaKids.maxSupply();
    }

}