pragma solidity >=0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";


contract NFTGame {
    address owner;

    // enum for GameWinner
    enum GameWinner {
        CREATOR,
        OPPONENT,
        NONE,
        RESULTPENDING
    }

    // struct Bet
    struct Bet{
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
        address creatorNFT;
        uint256 creatorNFTId;
        uint256 creatorEtherValue;
        Bet[] bets;
        uint256 betCount;
        uint256 selectedBet;
        string creatorHash;
        string opponentHash;
        bool isOpponentSelected;
        GameWinner winner;
        bool isActive;
    }

    Lobby[] public lobbies; // array of lobbies

    function CreateLobby(address creatorNFT, uint256 creatorNFTId, uint256 creatorEtherValue) public {
        address creator = msg.sender;
        if(creatorNFT != address(0)){
            require(IERC721(creatorNFT).ownerOf(creatorNFTId) == creator);
            // safe transfer from creator to contract
            IERC721(creatorNFT).safeTransferFrom(creator, address(this), creatorNFTId);
        }
        uint256 lobbyId = lobbies.length;
        Bet[] memory bets = new Bet[](1000000);
        string memory creatorHash = "";
        string memory opponentHash = "";
        GameWinner winner = GameWinner.RESULTPENDING;
        bool isActive = true;
        Lobby memory lobby = Lobby(lobbyId, creator, creatorNFT, creatorNFTId, creatorEtherValue, bets, 0, 0, creatorHash, opponentHash, false, winner, isActive);
        lobbies.push(lobby);
    }
}