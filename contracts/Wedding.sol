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
        _mint(spouse1.addr, certId);

        // _setTokenURI(certId, "https://www.thoughtco.com/thmb/TghRBdIZMYsnZ5aMEhsGBDcnODM=/1500x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/BarackObama-799035cd446c443fb392110c01768ed0.jpg");
        // _setTokenURI(certId, "../data/cert1.json");
        _setTokenURI(certId, "data:image/jpeg;base64,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");

        // weddingCert = Certificate(spouse1.addr, spouse2.addr, dateTime, "www.facebook.com"); 
    }
}
