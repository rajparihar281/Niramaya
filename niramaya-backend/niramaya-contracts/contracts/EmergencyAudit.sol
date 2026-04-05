// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EmergencyAudit {
    struct DispatchRecord {
        string patientId;
        string hospitalId;
        string department;
        uint256 timestamp;
    }

    mapping(uint256 => DispatchRecord) public logs;
    uint256 public logCount;

    // All four fields emitted so eth_getLogs data is fully decodable
    event DispatchLogged(
        uint256 indexed logId,
        string patientId,
        string hospitalId,
        string department,
        uint256 timestamp
    );

    function logDispatch(string memory _pId, string memory _hId, string memory _dept) public {
        logCount++;
        logs[logCount] = DispatchRecord(_pId, _hId, _dept, block.timestamp);
        emit DispatchLogged(logCount, _pId, _hId, _dept, block.timestamp);
    }
}
