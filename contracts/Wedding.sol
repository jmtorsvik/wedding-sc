// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

// import "@openzeppelin/contracts@5.0.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Wedding is ERC721URIStorage {
    struct Spouse {
        address addr;
        bool isWed;
        bool agreedOnParticipants;
        bool agreedOnWedding;
    }
    Spouse spouse1;
    Spouse spouse2;

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



    constructor() ERC721("WeddingCertificate", "WCT") {}
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    
    
    
    // struct Certificate {
    //     address addr1; 
    //     address addr2; 
    //     uint certDateTime;
    //     string uri_to_file; 
    // }
    // Certificate weddingCert; 


    function mintCertificate() private {
        currentTokenId.increment();

        uint256 certId = currentTokenId.current();
        _safeMint(spouse1.addr, certId);

        // _setTokenURI(certId, "https://www.thoughtco.com/thmb/TghRBdIZMYsnZ5aMEhsGBDcnODM=/1500x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/BarackObama-799035cd446c443fb392110c01768ed0.jpg");
        _setTokenURI(certId, "../data/cert1.json");

        // weddingCert = Certificate(spouse1.addr, spouse2.addr, dateTime, "www.facebook.com"); 
    }
}
