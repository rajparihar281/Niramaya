import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("EmergencyAuditModule", (m) => {
  // This tells Ignition to deploy the EmergencyAudit contract
  const emergencyAudit = m.contract("EmergencyAudit");

  return { emergencyAudit };
});
    