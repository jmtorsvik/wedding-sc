// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2;

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

    // We use the metamask address of one of our group members
    address[] serviceAddresses = [address(0x03435e8A83fE55572d634128e64D195198af89c0)];

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
        require(_getParticipant(msg.sender).addr != address(0), "Only participant.");
        _;
    }

    modifier onlyConfirmedParticipant() {
        require(_getParticipant(msg.sender).confirmed, "Only confirmed participants.");
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
        require(t >= dateTime && t < dateTime + 86400, "Current time must be within 24 hours of the wedding.");
        _;
    }

    // Finds a participant from a specified address. Returns participant with address 0 if address not in list.
    // Params:
    // * _addr: the address to look up in the list
    function _getParticipant(address _addr) view  private returns (Participant memory) {
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i].addr == _addr) {
                return participants[i];
            }
        }

        return Participant(address(0), false, false);
    }

    // Finds the index of a specified address in the participant list. Returns length of list if address not in list.
    // Params:
    // * _addr: the address to look up in the list
    function _getParticipantIndex(address _addr) view private returns (uint) {
        for (uint i = 0; i < participants.length; i++) {
            if (participants[i].addr == _addr) {
                return i;
            }
        }

        return participants.length;
    }

    // This function lets two users engage if they are not already wed.
    // If the first fiancé engages again, they can set new parameters.
    // The parameters of the engagement is decided by the first fiancé. 
    // So the arguments provided by the second fiancé is ignored
    // Params: 
    // * _dateTime: Seconds after January 1st 1970, we assume that this is in the future
    // * _additionalInfo: Optional information about the engagement
    function engage(uint256 _dateTime, string memory _additionalInfo) public onlyUnWed {
        if (spouse1.addr == address(0) || spouse1.addr == msg.sender) {
            spouse1 = Spouse(msg.sender, false, false, false);
            dateTime = _dateTime;
            additionalInfo = _additionalInfo;
        } else if (spouse2.addr == address(0)) {
            spouse2 = Spouse(msg.sender, false, false, false);
        }
    }

    // This function lets the fiancés invite a single participant to the wedding (can be called by both fiancés multiple times).
    // Params:
    // * _addr: The address of the invited participant.
    function inviteParticipant(address _addr) public onlyEngaged {
        participants.push(Participant(_addr, false, false));
    }

    // This function lets invited participants accept the invitation to the wedding. 
    // Each time a participant accepts the invitation, the fiancés must accept the participant list again.
    function acceptInvitation() public onlyParticipant {
        Participant memory p = _getParticipant(msg.sender);
        uint pIndex = _getParticipantIndex(msg.sender);
        
        if (pIndex < participants.length) {
            participants[pIndex] = Participant(p.addr, true, p.votedAgainst);
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, false, spouse1.agreedOnWedding);
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, false, spouse2.agreedOnWedding);
        }
    }

    // This function lets the fiancés agree on the list of participants that has accepted the invitation.
    function agreeOnParticipants() public onlyEngaged {
        if (msg.sender == spouse1.addr) {
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, true, spouse1.agreedOnWedding);
        } else {
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, true, spouse2.agreedOnWedding);
        }
    }

    // This function lets any of the fiancés revoke the engagement. This sets the relevant fields to the default values.
    function revokeEngagement() public onlyEngaged {
        delete spouse1;
        delete spouse2;
        delete dateTime;
        delete additionalInfo;
        delete participants;
    }

    // This function lets participants that has accepted the invitation vote against the wedding.
    function voteAgainst() public onlyConfirmedParticipant {
        Participant memory p = _getParticipant(msg.sender);
        uint pi = _getParticipantIndex(msg.sender);

        if (pi < participants.length) {
            participants[pi] = Participant(p.addr, p.confirmed, true);
        }
    }

    // This function lets the two fiancés agree to getting wed if they have agreed on invited participants, 
    // half of the participants that has accepted the incitation has not voted against, 
    // and the current time is within 24 hours after the wedding time.
    // If they both have agreed to be wed, the certificate (NFT) of the wedding is minted.
    function wed() public onlyEngaged bothAgreedOnParticipants halfHasNotVotedAgainst isTimeValid {
        if (msg.sender == spouse1.addr) {
            spouse1 = Spouse(spouse1.addr, spouse1.isWed, spouse1.agreedOnParticipants, true);
        } else {
            spouse2 = Spouse(spouse2.addr, spouse2.isWed, spouse2.agreedOnParticipants, true);
        }

        if (spouse1.agreedOnWedding && spouse2.agreedOnWedding) {
            spouse1 = Spouse(spouse1.addr, true, spouse1.agreedOnParticipants, spouse1.agreedOnWedding);
            spouse2 = Spouse(spouse2.addr, true, spouse2.agreedOnParticipants, spouse2.agreedOnWedding);
            _mintCertificate();
        }
    }  

    // This function lets spouses and authorized wedding service employees agree on burning the issued certificate.
    // The first to burn must be one of the spouses.
    function burnCertificate(uint256 tokenId) public onlyEngagedOrService {
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

    // Mints a certificate of the wedding in form of a NFT.
    function _mintCertificate() private {
        currentTokenId.increment();

        uint256 certId = currentTokenId.current();
        _mint(spouse1.addr, certId);

        _setTokenURI(certId, _generateTokenURI());
    }

    // Generates the URI of the token that includes the relevant information of the wedding.
    function _generateTokenURI() view private returns (string memory) {
        string memory spouse1Addr = Strings.toHexString(uint160(spouse1.addr));
        string memory spouse2Addr = Strings.toHexString(uint160(spouse2.addr));
        string memory dateWed = Strings.toHexString(uint160(dateTime));

        string memory heartSvg = "<?xml version='1.0' encoding='UTF-8' standalone='no'?> <svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' version='1.1' height='315' width='342' > <defs> <style type='text/css'><![CDATA[     .outline { stroke:none; stroke-width:0 } ]]></style> <g id='heart'> <path      d='M0 200 v-200 h200      a100,100 90 0,1 0,200     a100,100 90 0,1 -200,0     z' /> </g> </defs> <desc> a nearly perfect heart     made of two arcs and a right angle </desc> <use xlink:href='#heart' class='outline ' fill='red' /> </svg>";

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Wedding Certificate", "description": "Wedding Certificate spouse1: ', spouse1Addr,' spouse2: ', spouse2Addr,' date: ', dateWed,'", "image_data": "', bytes(heartSvg), '"}'))));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    // Prohibits transfer of the issued certificate.
    // Transfers to address 0 is allowed since this represents creation and burn of certificate.
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
        override (ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
