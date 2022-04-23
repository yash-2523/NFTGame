pragma solidity >=0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTGame {
    using SafeMath for uint256;
    address owner;

    // enum for GameWinner
    enum GameWinner {
        CREATOR,
        OPPONENT,
        RESULT_PENDING
    }

    enum LobbyStatus {
        BETTING,
        OPPONENT_SELECTED,
        REWARD_CLAIMED
    }

    // struct Bet
    struct Bet{
        uint256 lobbyId;
        address user;
        address NFT;
        uint256 NFTId;
        uint256 etherValue;
        bool isCancelled;
    }

    // struct for the lobby
    struct Lobby{
        uint256 lobbyId;
        address creator;
        uint256 creatorBet;
        uint256 opponentBet;
        bytes10 creatorHash;
        bytes10 opponentHash;
        LobbyStatus lobbyStatus;
        GameWinner winner;
        uint256 gameNumber;
        uint256 blockNumber;
    }

    Lobby[] public lobbies; // array of lobbies
    Bet[] bets; // arrya of bets
    mapping(uint256 => uint256[]) public rewardLobbiesForBlocks; // mapping of block number with lobbies that are going to be rewarded

    function CreateLobby(address _creatorNFT, uint256 _creatorNFTId, uint256 _creatorEtherValue) public payable {
        require(msg.value == _creatorEtherValue, "Not enough ether");
        address _creator = msg.sender;
        if(_creatorNFT != address(0)){
            require(IERC721(_creatorNFT).ownerOf(_creatorNFTId) == _creator);
            // safe transfer from creator to contract
            IERC721(_creatorNFT).safeTransferFrom(_creator, address(this), _creatorNFTId);
        }
        Bet memory newBet = Bet({
            lobbyId: lobbies.length,
            user: _creator,
            NFT: _creatorNFT,
            NFTId: _creatorNFTId,
            etherValue: _creatorEtherValue,
            isCancelled: false
        });
        bets.push(newBet);
        Lobby memory lobby = Lobby(lobbies.length, _creator, bets.length - 1, 0, "", "", LobbyStatus.BETTING, GameWinner.RESULT_PENDING,0,0);
        lobbies.push(lobby);
    }

    function CreateOffer(uint256 lobbyId,address _userNFT, uint256 _userNFTId, uint256 _userEtherValue) public payable {
        require(msg.value == 0, "Not enough ether");
        address _user = msg.sender;
        Lobby memory lobby = lobbies[lobbyId];
        require(_user != lobby.creator, "You can't offer in your lobby");
        require(lobby.lobbyStatus == LobbyStatus.BETTING, "Lobby is not in betting phase");
        if(_userNFT != address(0)){
            require(IERC721(_userNFT).ownerOf(_userNFTId) == _user);
            // safe transfer from user to contract
            IERC721(_userNFT).safeTransferFrom(_user, address(this), _userNFTId);
        }
        Bet memory bet = Bet(lobbyId, _user, _userNFT, _userNFTId, _userEtherValue, false);
        bets.push(bet);
    }

    function WithdrawOffer(uint256 betId) public {
        Bet memory bet = bets[betId];
        require(bet.isCancelled == false, "Bet already cancelled");
        require(bet.user == msg.sender, "Not the owner of the bet");
        Lobby memory lobby = lobbies[bet.lobbyId];
        require(msg.sender != lobby.creator, "You can't withdraw from your lobby");
        if(lobby.lobbyStatus != LobbyStatus.BETTING){
            require(lobby.opponentBet != betId, "You can't withdraw the selected bet");
        }
        bet.isCancelled = true;
        if(bet.NFT != address(0)){
            // safe transfer from contract to user
            IERC721(bet.NFT).safeTransferFrom(address(this), bet.user, bet.NFTId);
        }
        if(bet.etherValue > 0){
            // refund ether
            payable(msg.sender).transfer(bet.etherValue);
        }
    }

    function byteToBytes10(bytes1[] memory _bytes) internal pure returns (bytes10 _bytes10) {
        for(uint32 i = 0; i < 9; i++) {
            _bytes10 ^= bytes1(_bytes[i]);
            _bytes10 >>= 8;
        }
    }

    function getHashes() public view returns (bytes10 creatorHash, bytes10 opponentHash){
        uint256[] memory chars = new uint256[](6);
        uint256[] memory nums = new uint256[](10);

        for(uint32 i = 0; i < 3; i++){
            chars[i] = 1;
        }
        for(uint32 i = 0; i < 5; i++){
            nums[i] = 1;
        }
        for(uint32 i = 0; i < 6; i++){
            uint256 random = uint256(keccak256(abi.encodePacked("Salt Adedd", chars[i], block.difficulty, block.timestamp)));
            random = random % 6;
            uint256 temp = chars[random];
            chars[random] = chars[i];
            chars[i] = temp;
        }
        for(uint32 i = 0; i < 10; i++){
            uint256 random = uint256(keccak256(abi.encodePacked("Salt Adedd", nums[i], block.difficulty, block.timestamp)));
            random = random % 10;
            uint256 temp = nums[random];
            nums[random] = nums[i];
            nums[i] = temp;
        }
        bytes1[] memory opponentHashBytes = new bytes1[](10);
        bytes1[] memory creatorHashBytes = new bytes1[](10);
        uint8 ci;
        uint8 oi;
        for(uint32 i = 0; i < 6; i++){
            if(chars[i] == 0){
                creatorHashBytes[ci] = bytes1(uint8(i+10));
                ci++;
            }else{
                opponentHashBytes[oi] = bytes1(uint8(i+10));
                oi++;
            }
        }
        for(uint32 i = 0; i < 10; i++){
            if(nums[i] == 0){
                creatorHashBytes[ci] = bytes1(uint8(i));
                ci++;
            }else{
                opponentHashBytes[oi] = bytes1(uint8(i));
                oi++;
            }
        }
        creatorHash = byteToBytes10(creatorHashBytes);
        opponentHash = byteToBytes10(opponentHashBytes);
        return (creatorHash, opponentHash);
    }

    function SelectOffer(uint256 lobbyId, uint256 betId) public {
        Bet memory bet = bets[betId];
        Lobby memory lobby = lobbies[lobbyId];
        require(bet.isCancelled == false, "Bet already cancelled");
        require(lobby.creator == msg.sender, "Not the owner of the lobby");
        require(lobby.creatorBet != betId, "You can't select your own bet");
        require(lobby.lobbyStatus == LobbyStatus.BETTING, "Lobby has already selected a bet");
        lobby.opponentBet = betId;
        lobby.lobbyStatus = LobbyStatus.OPPONENT_SELECTED;
        (lobby.creatorHash,lobby.opponentHash) = getHashes();
        uint256 random = uint256(keccak256(abi.encodePacked(lobby.creatorHash, lobby.opponentHash, block.difficulty, block.timestamp)));
        random = random % 64;
        lobby.gameNumber = random;
        lobby.blockNumber = block.number + 3;
        rewardLobbiesForBlocks[lobby.blockNumber].push(lobbyId);
    }

    function getWinnerAddress(uint256 lobbyId, GameWinner winner) internal view returns (address winnerAddress){
        Lobby memory lobby = lobbies[lobbyId];
        if(winner == GameWinner.CREATOR){
            return lobby.creator;
        }else if(winner == GameWinner.OPPONENT){
            Bet memory _opponentBet = bets[lobby.opponentBet];
            return _opponentBet.user;
        }else{
            return address(0);
        }
    }

    function getWinner(uint256 lobbyId) public view returns (GameWinner, address){
        Lobby memory lobby = lobbies[lobbyId];
        require(lobby.lobbyStatus != LobbyStatus.BETTING, "The players are not confirmed yet");
        if(block.number <= lobby.blockNumber){
            return (GameWinner.RESULT_PENDING, getWinnerAddress(lobbyId, GameWinner.RESULT_PENDING));
        }
        if(lobby.lobbyStatus == LobbyStatus.REWARD_CLAIMED){
            return (lobby.winner, getWinnerAddress(lobbyId, lobby.winner));
        }

        bytes32 block_hash = blockhash(lobby.blockNumber);
        bytes1 block_hash_bytes = block_hash[lobby.gameNumber/2];
        bytes1 finalCompareHash;
        if(lobby.gameNumber % 2 == 1){
            finalCompareHash = block_hash_bytes << 4;
            finalCompareHash = finalCompareHash >> 4;
        }else{
            finalCompareHash = block_hash_bytes >> 4;
        }
        for(uint32 i=0;i<8;i++){
            if(finalCompareHash[i] == lobby.creatorHash[i]){
                return (GameWinner.CREATOR, getWinnerAddress(lobbyId, GameWinner.CREATOR));
            }
        }
        for(uint32 i=0;i<8;i++){
            if(finalCompareHash[i] == lobby.opponentHash[i]){
                return (GameWinner.OPPONENT, getWinnerAddress(lobbyId, GameWinner.OPPONENT));
            }
        }
        return (GameWinner.RESULT_PENDING, address(0));
    }

    function claimReward(uint256 lobbyId) public payable {
        Lobby memory lobby = lobbies[lobbyId];
        require(lobby.lobbyStatus != LobbyStatus.REWARD_CLAIMED, "The reward has already been claimed");
        require(lobby.creator == msg.sender, "You are not the creator of the lobby");
        (GameWinner _winner,address _winnerAddress) = getWinner(lobbyId);
        
        require(_winnerAddress != address(0), "The game has not been completed yet");
        lobby.lobbyStatus = LobbyStatus.REWARD_CLAIMED;
        lobby.winner = _winner;
        Bet memory _opponentBet = bets[lobby.opponentBet];
        Bet memory _creatorBet = bets[lobby.creatorBet];
        uint256 etherValue = _opponentBet.etherValue;
        etherValue.add(_creatorBet.etherValue);
        if(etherValue > 0){
            payable(_winnerAddress).transfer(etherValue);
        }
        if(_opponentBet.NFT != address(0)){
            IERC721(_opponentBet.NFT).safeTransferFrom(address(this), _winnerAddress, _opponentBet.NFTId);
        }
        if(_creatorBet.NFT != address(0)){
            IERC721(_creatorBet.NFT).safeTransferFrom(address(this), _winnerAddress, _creatorBet.NFTId);
        }
    }

}