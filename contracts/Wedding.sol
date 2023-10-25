// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;
// pragma solidity >=0.8.4 <0.9.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

 
import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/extensions/ERC721URIStorage.sol";

contract Wedding is ERC721, ERC721URIStorage {
    struct Spouse {
        address addr;
        bool isWed;
        bool agreedOnParticipants;
        bool agreedOnWedding;
    }
    Spouse spouse1;
    Spouse spouse2;

    address[] serviceAddresses = [address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2), address(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db)];

    address burnInitiator;

    uint256 dateTime;
    string additionalInfo;

    struct Participant{
        address addr;
        bool confirmed; 
        bool votedAgainst;  
    }
    Participant[] participants;
    

    modifier onlyUnWed() {
        bool isWed = false;

        if (msg.sender == spouse1.addr) {
            isWed = spouse1.isWed;
        } else if (msg.sender == spouse2.addr) {
            isWed = spouse2.isWed;
        }

        require(!isWed, "Only unwed.");
        _;
    }

    modifier onlyEngaged() {
        require(msg.sender == spouse1.addr || msg.sender == spouse2.addr, "Only engaged.");
        _;
    }

    modifier onlyEngagedOrService() {
        bool isService = false;

        for (uint i = 0; i < serviceAddresses.length; i++) {
            if (msg.sender == serviceAddresses[i]) {
                isService = true;
                break;
            }
        }

        require(msg.sender == spouse1.addr || msg.sender == spouse2.addr || isService, "Only engaged or service.");
        _;
    }
 
    modifier onlyParticipant() {
        require(getParticipant(msg.sender).addr != address(0), "Only participant.");
        _;
    }

    modifier onlyConfirmedParticipant() {
        require(getParticipant(msg.sender).confirmed, "Only confirmed participants.");
        _;
    }

    modifier bothAgreedOnParticipants() {
        require(spouse1.agreedOnParticipants, "Address 1 must agree on participants.");
        require(spouse2.agreedOnParticipants, "Address 2 must agree on participants.");
        _;
    }

    modifier halfHasNotVotedAgainst() {
        uint voteCount = 0;
        uint confirmedCount = 0;

        for (uint i; i < participants.length; i++) {
            if (participants[i].confirmed) {
                confirmedCount++;
                if (participants[i].votedAgainst) {
                    voteCount++;
                }
            }
        }

        require(voteCount*2 < confirmedCount, "Half voted against.");
        _;
    }

    modifier isTimeValid() {
        uint t = block.timestamp;
        require(t >= dateTime && t < dateTime + 86400, "Too early, mate.");
        _;
    }

    function getParticipant(address _addr) view  private returns (Participant memory) {
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i].addr == _addr) {
                return participants[i];
            }
        }

        return Participant(address(0), false, false);
    }

    function getParticipantIndex(address _addr) view private returns (uint) {
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i].addr == _addr) {
                return i;
            }
        }

        return participants.length;
    }

    function engage(uint256 _dateTime, string memory _additionalInfo) public onlyUnWed {
        if (spouse1.addr == address(0)) {
            spouse1 = Spouse(msg.sender, false, false, false);
            dateTime = _dateTime;
            additionalInfo = _additionalInfo;
        } else if (spouse2.addr == address(0)) {
            spouse2 = Spouse(msg.sender, false, false, false);
            mintCertificate();
        }
    }

    function inviteParticipant(address _addr) public onlyEngaged {
        participants.push(Participant(_addr, false, false));
    }

    function acceptInvitation() public onlyParticipant {
        Participant memory p = getParticipant(msg.sender);
        uint pi = getParticipantIndex(msg.sender);
        
        if (pi < participants.length) {
            participants[pi] = Participant(p.addr, true, p.votedAgainst);
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, false, spouse1.agreedOnWedding);
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, false, spouse2.agreedOnWedding);
        }
    }

    function agreeOnParticipants() public onlyEngaged {
        if (!spouse1.agreedOnParticipants && msg.sender == spouse1.addr) {
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, true, spouse1.agreedOnWedding);
        } else {
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, true, spouse2.agreedOnWedding);
        }
    }

    function revokeEngagement() public onlyEngaged {
        spouse1 = Spouse(address(0), false, false, false);
        spouse2 = Spouse(address(0), false, false, false);
    }

    function voteAgainst() public onlyConfirmedParticipant {
        Participant memory p = getParticipant(msg.sender);
        uint pi = getParticipantIndex(msg.sender);

        if (pi < participants.length) {
            participants[pi] = Participant(p.addr, p.confirmed, true);
        }
    }

    function wed() public onlyEngaged bothAgreedOnParticipants halfHasNotVotedAgainst isTimeValid {
        if (!spouse1.agreedOnWedding && msg.sender == spouse1.addr) {
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, spouse1.agreedOnParticipants, true);
        } else {
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, spouse2.agreedOnParticipants, true);
        }

        if (spouse1.agreedOnWedding && spouse2.agreedOnWedding) {
            spouse1 = Spouse(spouse1.addr, true, spouse1.agreedOnParticipants, spouse1.agreedOnWedding);
            spouse2 = Spouse(spouse2.addr, true, spouse2.agreedOnParticipants, spouse2.agreedOnWedding);
        }

    }

    function burnCertificate(uint256 tokenId) public onlyEngagedOrService {
        // Here we assume that burn initiator must be a spouse
        if (burnInitiator == address(0)) {
            if (msg.sender == spouse1.addr || msg.sender == spouse2.addr) {
                burnInitiator = msg.sender;
            }
        } else if (burnInitiator != msg.sender) {
            _burn(tokenId);
        }
    }



    constructor() ERC721("WeddingCertificate", "WCT") {}
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;



    function mintCertificate() private {
        currentTokenId.increment();

        uint256 certId = currentTokenId.current();
        _mint(spouse1.addr, certId);

        _setTokenURI(certId, generateTokenURI());
    }

    function generateTokenURI() view private returns (string memory) {
        string memory spouse1Addr = Strings.toHexString(uint160(spouse1.addr));
        string memory spouse2Addr = Strings.toHexString(uint160(spouse2.addr));
        string memory dateWed = Strings.toHexString(uint160(dateTime));

        string memory heartSvg = "<?xml version='1.0' encoding='UTF-8' standalone='no'?> <svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' version='1.1' height='315' width='342' > <defs> <style type='text/css'><![CDATA[     .outline { stroke:none; stroke-width:0 } ]]></style> <g id='heart'> <path      d='M0 200 v-200 h200      a100,100 90 0,1 0,200     a100,100 90 0,1 -200,0     z' /> </g> </defs> <desc> a nearly perfect heart     made of two arcs and a right angle </desc> <use xlink:href='#heart' class='outline ' fill='red' /> </svg>";

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Wedding Certificate", "description": "Wedding Certificate spouse1: ', spouse1Addr,' spouse2: ', spouse2Addr,' date: ', dateWed,'", "image_data": "', bytes(heartSvg), '"}'))));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override virtual {
        require(from == address(0) || to == address(0), "Err: token transfer is BLOCKED");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override (ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
