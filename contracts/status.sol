// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// Open Zeppelin libraries for controlling upgradability and access.
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


// BtfsStatus for hosts' heartbeat report
contract BtfsStatus is Initializable, UUPSUpgradeable, OwnableUpgradeable{
    using SafeMath for uint256;

    // map[peer]info
    struct info {
        uint32 createTime;
        string version;
        uint32 lastNonce;
        uint32 lastSignedTime;
        bytes lastSigned;
        uint16[30] hearts;
    }
    mapping(string => info) private peerMap;

    // sign address
    address currentSignAddress;
    address[20] currentSignAddressList;

    // version
    string public currentVersion;

    event signAddressChanged(address lastSignAddress, address currentSignAddress);
    event versionChanged(string currentVersion, string version);
    event statusReported(string peer, uint32 createTime, string version, uint32 Nonce, address bttcAddress, uint32 signedTime, uint32 lastNonce, uint32 nowTime, uint16[30] hearts);

    // stat
    struct statistics {
        uint64 total;
        uint64 totalUsers;
    }
    statistics  public totalStat;

    // initialize
    function initialize(address signAddress) public initializer {
        currentSignAddress = signAddress;
        __Ownable_init();
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // set sign address, only owner do it
    function setSignAddress(address addr) public onlyOwner {
        emit signAddressChanged(currentSignAddress, addr);
        currentSignAddress = addr;
    }

    // get sign address, only owner do it
    function getSignAddress() public view onlyOwner returns (address) {
        return (currentSignAddress);
    }

    // set current version, only owner do it
    function setCurrentVersion(string memory ver) public onlyOwner {
        emit versionChanged(currentVersion, ver);
        currentVersion = ver;
    }

    // get host when score = 8.0
    function getHighScoreHost() external returns(info[] memory) {}

    function getStatus(string memory peer) external view returns(string memory, uint32, string memory, uint32, uint32, bytes memory, uint16[30] memory) {
        if (peerMap[peer].lastNonce == 0) {
            uint16[30] memory hearts;
            bytes memory s;
            return ("", 0, "", 0, 0, s, hearts);
        } else {
            info memory node = peerMap[peer];
            return (peer, node.createTime, node.version, node.lastNonce, node.lastSignedTime, node.lastSigned, node.hearts);
        }
    }


    // set heart, max idle days = 10
    function setHeart(string memory peer, uint32 Nonce, uint32 nowTime) internal {
        uint32 diffTime = nowTime - peerMap[peer].lastSignedTime;
        if (diffTime > 30 * 86400) {
            diffTime = 30 * 86400;
        }
        uint32 diffDays = diffTime / 86400;

        uint32 diffNonce = Nonce - peerMap[peer].lastNonce;
        if (diffDays > 0 && diffNonce > diffDays * 24) {
            diffNonce = diffDays * 24;
        }
        uint32 balanceNum = diffNonce;

        // 1.set new (diffDays-1) average Nonce; (it is alse reset 0 for more than 30 days' diffDays)
        for (uint32 i = 1; i < diffDays; i++) {
            uint indexTmp = ((nowTime - i * 86400) / 86400) % 30;
            peerMap[peer].hearts[indexTmp] = uint16(diffNonce/diffDays);

            balanceNum = balanceNum - diffNonce/diffDays;
        }

        // 2.set today balanceNum
        uint index = (nowTime / 86400) % 30;
        peerMap[peer].hearts[index] = uint16(balanceNum);
    }

    // report status
    function reportStatus(string memory peer, uint32 createTime, string memory version, uint32 Nonce, address bttcAddress, uint32 signedTime, bytes memory signed) external {

        require(0 < createTime, "reportStatus: Invalid createTime");
        require(0 < Nonce, "reportStatus: Invalid Nonce");
        require(0 < signedTime, "reportStatus: Invalid signedTime");
        require(0 < signed.length, "reportStatus: Invalid signed");
        require(peerMap[peer].lastNonce < Nonce, "reportStatus: Invalid lastNonce<Nonce");

        // verify input param with the signed data.
        bytes32 hash = genHash(peer, createTime, version, Nonce, bttcAddress, signedTime);
        require( recoverSigner(hash, signed) == currentSignAddress, "reportStatus: Invalid signed address.");

        // only bttcAddress is sender， to report status
        require(bttcAddress == msg.sender, "reportStatus: Invalid msg.sender");

        uint32 lastNonce = peerMap[peer].lastNonce;
        uint32 nowTime = uint32(block.timestamp);
        uint index = (nowTime / 86400) % 30;

        // first report
        if (peerMap[peer].lastNonce == 0) {
            uint32 initNonce = Nonce;
            if (initNonce > 24) {
                initNonce = 24;
            }

            peerMap[peer].hearts[index] = uint16(initNonce);

            totalStat.totalUsers += 1;
            totalStat.total += 1;
        } else {
            require(nowTime-signedTime <= 86400, "reportStatus: signed time must be within 1 days of the current time.");
            require(peerMap[peer].createTime == createTime, "reportStatus: Invalid createTime.");

            setHeart(peer, Nonce, nowTime);
            totalStat.total += Nonce - peerMap[peer].lastNonce;
        }

        peerMap[peer].createTime = createTime;
        peerMap[peer].version = version;
        peerMap[peer].lastNonce = Nonce;
        peerMap[peer].lastSignedTime = signedTime;
        peerMap[peer].lastSigned = signed;

        emitStatusReported(
            peer,
            createTime,
            version,
            Nonce,
            bttcAddress,
            signedTime,
            lastNonce,
            uint32(block.timestamp)
        );
    }

    function emitStatusReported(string memory peer, uint32 createTime, string memory version, uint32 Nonce, address bttcAddress, uint32 signedTime, uint32 lastNonce, uint32 nowTime) internal {
        uint16[30] memory hearts = peerMap[peer].hearts;
        emit statusReported(
            peer,
            createTime,
            version,
            Nonce,
            bttcAddress,
            signedTime,
            lastNonce,
            nowTime,
            hearts
        );
    }

    function recoverSigner(bytes32 hash, bytes memory sig) internal pure returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
        return ecrecover(hash, v+27, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function genHash(string memory peer, uint32 createTime, string memory version, uint32 Nonce, address bttcAddress, uint32 signedTime) internal pure returns (bytes32) {
        bytes memory data = abi.encode(peer, createTime, version, Nonce, bttcAddress, signedTime);
        return keccak256(abi.encode("\x19Ethereum Signed Message:\n", data.length, data));
    }

    // call from external
    function genHashExt(string memory peer, uint32 createTime, string memory version, uint32 Nonce, address bttcAddress, uint32 signedTime) external pure returns (bytes32) {
        return genHash(peer, createTime, version, Nonce, bttcAddress, signedTime);
    }

    // call from external
    function recoverSignerExt(bytes32 hash, bytes memory sig) external pure returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
        return ecrecover(hash, v+27, r, s);
    }
}
