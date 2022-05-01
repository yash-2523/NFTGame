// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTGame is ERC1155Holder, ERC721Holder {
    using SafeMath for uint256;
    address owner;

    // enum for GameWinner
    enum GameWinner {
        CREATOR,
        OPPONENT,
        RESULT_PENDING,
        ERROR_RESPONSE
    }

	// enum for GameStatus
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
		uint16 NFTType;
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
        uint256 betCount;
    }

    Lobby[] public lobbies; // array of lobbies
    Bet[] public bets; // arrya of bets

	// Event for when a lobby is created
    event LobbyCreated(uint256 lobbyId, address creator, uint256 creatorBet);
	// Event for when a bet is placed
    event BetPlaced(uint256 lobbyId, uint256 betId, address user, address NFTAddress,uint256 NFTId, uint256 etherValue);
    // Event for when a bet is cancelled
	event BetCancelled(uint256 lobbyId, uint256 betId, address user);
    // Event for when a bet is selected to fight against
	event BetSelected(uint256 lobbyId, uint256 betId,address user, address NFTAddress,uint256 NFTId, uint256 etherValue);
    // Event for when a reward is claimed
	event RewardClaimed(uint256 lobbyId, GameWinner winner, address winnerAddress, uint256 etherValue);

    // Create a new lobby
	/**
		Inputs:
			address creatorNFT: address of NFT of the creator of the lobby
			uint256 creatorNFTId: id of the NFT of the creator of the lobby
			uint256 creatorEtherValue - the amount of ether the creator bets

		Events:
			LobbyCreated
			BetPlaced
	*/
	function CreateLobby(address _creatorNFT, uint256 _creatorNFTId, uint16 _NFTType, uint256 _creatorEtherValue) public payable {
        require(msg.value == _creatorEtherValue, "Not enough ether");
        address _creator = msg.sender;
        if(_creatorNFT != address(0)){
			if(_NFTType == 1){
            	require(IERC721(_creatorNFT).ownerOf(_creatorNFTId) == _creator);
            	// safe transfer from creator to contract
            	IERC721(_creatorNFT).safeTransferFrom(_creator, address(this), _creatorNFTId);
			}else if(_NFTType == 0){
				require(IERC1155(_creatorNFT).balanceOf(_creator, _creatorNFTId) == 1);
            	// safe transfer from creator to contract
            	IERC1155(_creatorNFT).safeTransferFrom(_creator, address(this), _creatorNFTId, 1, "");
			}
        }
        Bet memory newBet = Bet({
            lobbyId: lobbies.length,
            user: _creator,
            NFT: _creatorNFT,
			NFTType: _NFTType,
            NFTId: _creatorNFTId,
            etherValue: _creatorEtherValue,
            isCancelled: false
        });
        bets.push(newBet);
        Lobby memory lobby = Lobby(lobbies.length, _creator, bets.length - 1, 0, "", "", LobbyStatus.BETTING, GameWinner.RESULT_PENDING,0,0, 1);
        lobbies.push(lobby);
        emit LobbyCreated(lobbies.length - 1, _creator, bets.length - 1);
        emit BetPlaced(lobbies.length - 1, bets.length - 1, _creator, _creatorNFT, _creatorNFTId, _creatorEtherValue);
    }

	// Create a offer for an existing lobby
	/**
		Inputs:
			uint256 lobbyId: id of the lobby
			address opponentNFT: address of NFT of the opponent
			uint256 opponentNFTId: id of the NFT of the opponent
			uint256 opponentEtherValue - the amount of ether the opponent bets

		Events:
			BetPlaced
	*/
    function CreateOffer(uint256 lobbyId,address _userNFT, uint256 _userNFTId, uint16 _userNFTType, uint256 _userEtherValue) public payable {
        require(msg.value == _userEtherValue, "Not enough ether");
        address _user = msg.sender;
        Lobby memory lobby = lobbies[lobbyId];
        require(_user != lobby.creator, "You can't offer in your lobby");
        require(lobby.lobbyStatus == LobbyStatus.BETTING, "Lobby is not in betting phase");
        if(_userNFT != address(0)){
			if(_userNFTType == 1){
				require(IERC721(_userNFT).ownerOf(_userNFTId) == _user);
				// safe transfer from user to contract
				IERC721(_userNFT).safeTransferFrom(_user, address(this), _userNFTId);
			}else if(_userNFTType == 0){
				require(IERC1155(_userNFT).balanceOf(_user, _userNFTId) == 1);
				// safe transfer from user to contract
				IERC1155(_userNFT).safeTransferFrom(_user, address(this), _userNFTId, 1, "");
			}
        }
        Bet memory bet = Bet(lobbyId, _user, _userNFT, _userNFTId, _userNFTType, _userEtherValue, false);
        bets.push(bet);
        lobby.betCount++;
        lobbies[lobbyId] = lobby;
        emit BetPlaced(lobbyId, bets.length - 1,_user, _userNFT, _userNFTId, _userEtherValue);
    }

	// Withdraw the offer from an existing lobby
	/**
		Inputs:
			uint256 betId: id of the bet
			
		Events:
			BetCancelled
	*/
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
			if(bet.NFTType == 1){
            	IERC721(bet.NFT).safeTransferFrom(address(this), bet.user, bet.NFTId);
			}else if(bet.NFTType == 0){
				IERC1155(bet.NFT).safeTransferFrom(address(this), bet.user, bet.NFTId, 1, "");
			}
        }
        if(bet.etherValue > 0){
            // refund ether
            payable(msg.sender).transfer(bet.etherValue);
        }
        bets[betId] = bet;
        emit BetCancelled(lobby.lobbyId, bets.length - 1, bet.user);
    }

	// Inner function for creating multiple bytes to fixed size bytes
	/**
		Inputs:
			bytes _bytes: bytes to be converted
			
		Outputs:
			bytes: bytes of fixed size
	*/
    function byteToBytes10(bytes1[] memory _bytes) internal pure returns (bytes10 _bytes10) {
        for(uint32 i = 0; i < 9; i++) {
            _bytes10 ^= bytes1(_bytes[i]);
            _bytes10 >>= 8;
        }
    }

	// Inner function for get Hashes for both the players
	/**
		Inputs:
			Nothing
			
		Events:
			bytes10 _hash1: hash of the first player
			bytes10 _hash2: hash of the second player
	*/
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

	// Select the bet for the opponent
	/**
		Inputs:
			uint256 lobbyId: id of the lobby
			uint256 betId: id of the bet
			
		Events:
			BetSelected
	*/
    function SelectOffer(uint256 lobbyId, uint256 betId) public {
        Bet memory bet = bets[betId];
        Lobby memory lobby = lobbies[lobbyId];
        require(bet.lobbyId == lobbyId, "Bet is not in this lobby");
        require(lobby.creator == msg.sender, "Not the owner of the lobby");
        require(bet.isCancelled == false, "Bet already cancelled");   
        require(lobby.creatorBet != betId, "You can't select your own bet");
        require(lobby.lobbyStatus == LobbyStatus.BETTING, "Lobby has already selected a bet");
        lobby.opponentBet = betId;
        lobby.lobbyStatus = LobbyStatus.OPPONENT_SELECTED;
        (lobby.creatorHash,lobby.opponentHash) = getHashes();
        uint256 random = uint256(keccak256(abi.encodePacked(lobby.creatorHash, lobby.opponentHash, block.difficulty, block.timestamp)));
        random = random % 64;
        lobby.gameNumber = random;
        lobby.blockNumber = block.number + 3;
        lobbies[lobbyId] = lobby;
        emit BetSelected(lobbyId, betId, bet.user, bet.NFT, bet.NFTId, bet.etherValue);
    }

	// Inner functioin for getting the winner of the game
	/**
		Inputs:
			uint256 lobbyId: id of the lobby
			GameWinner _winner: winner of the game

		Outputs:
			address: winner of the game
	*/
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

	// Get winner of the game
	/**
		Inputs:
			uint256 lobbyId: id of the lobby

		Outputs:
			GameWinner: winner of the game
			address: winner of the game
	*/
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
        for(uint32 i=9;i>1;i--){
            if(finalCompareHash == lobby.creatorHash[i]){
                return (GameWinner.CREATOR, getWinnerAddress(lobbyId, GameWinner.CREATOR));
            }
        }
        for(uint32 i=9;i>1;i--){
            if(finalCompareHash == lobby.opponentHash[i]){
                return (GameWinner.OPPONENT, getWinnerAddress(lobbyId, GameWinner.OPPONENT));
            }
        }
        return (GameWinner.RESULT_PENDING, getWinnerAddress(lobbyId, GameWinner.RESULT_PENDING));
    }

    function claimReward(uint256 lobbyId) public {
        Lobby memory lobby = lobbies[lobbyId];
        require(lobby.lobbyStatus != LobbyStatus.REWARD_CLAIMED, "The reward has already been claimed");
        (GameWinner _winner,address _winnerAddress) = getWinner(lobbyId);
        
        require(_winnerAddress != address(0), "The game has not been completed yet");
        require(_winnerAddress == msg.sender, "You are not the winner of the lobby");
        lobby.lobbyStatus = LobbyStatus.REWARD_CLAIMED;
        lobby.winner = _winner;
        Bet memory _opponentBet = bets[lobby.opponentBet];
        Bet memory _creatorBet = bets[lobby.creatorBet];
        uint256 etherValue = _opponentBet.etherValue;
        etherValue = etherValue.add(_creatorBet.etherValue);
        if(etherValue > 0){
            payable(_winnerAddress).transfer(etherValue);
        }
        if(_opponentBet.NFT != address(0)){
			if(_opponentBet.NFTType == 1){
            	IERC721(_opponentBet.NFT).safeTransferFrom(address(this), _winnerAddress, _opponentBet.NFTId);
			}else if(_opponentBet.NFTType == 0){
				IERC1155(_opponentBet.NFT).safeTransferFrom(address(this), _winnerAddress, _opponentBet.NFTId, 1, "");
			}
        }
        if(_creatorBet.NFT != address(0)){
            if(_creatorBet.NFTType == 1){
				IERC721(_creatorBet.NFT).safeTransferFrom(address(this), _winnerAddress, _creatorBet.NFTId);
			}else if(_creatorBet.NFTType == 0){
				IERC1155(_creatorBet.NFT).safeTransferFrom(address(this), _winnerAddress, _creatorBet.NFTId, 1, "");
			}
        }
        lobbies[lobbyId] = lobby;
        emit RewardClaimed(lobbyId, _winner, _winnerAddress, etherValue);
    }

	function getActiveLobbies() public view returns (uint256, Lobby[] memory){
		Lobby[] memory activeLobbies = new Lobby[](lobbies.length);
		uint256 j = 0;
		for(uint256 i = 0; i < lobbies.length; i++){
			if(lobbies[i].lobbyStatus == LobbyStatus.BETTING){
				activeLobbies[j] = lobbies[i];
				j++;
			}
		}
		return (j, activeLobbies);
	}

	function getBetsOfLobby(uint256 LobbyId) public view returns (uint256, Bet[] memory) {
		Lobby memory lobby = lobbies[LobbyId];
		Bet[] memory betsOfLobby = new Bet[](lobby.betCount);
		uint256 j = 0;
		for(uint256 i = 0; i < bets.length; i++){ if(bets[i].lobbyId == LobbyId){ betsOfLobby[j] = bets[i]; j++; } }
		return (j, betsOfLobby);
	}

}