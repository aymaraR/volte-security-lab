db.subscribers.updateOne(
  { imsi: "001010123456789" },
  {
    $set: {
      "slice.0.sst": NumberInt(1),
      "slice.0.session.0.type": NumberInt(3),
      "slice.0.session.0.qos.index": NumberInt(9),
      "slice.0.session.0.qos.arp.priority_level": NumberInt(8),
      "slice.0.session.0.qos.arp.pre_emption_capability": NumberInt(1),
      "slice.0.session.0.qos.arp.pre_emption_vulnerability": NumberInt(1),
      "slice.0.session.0.ambr.uplink.value": NumberInt(1),
      "slice.0.session.0.ambr.uplink.unit": NumberInt(0),
      "slice.0.session.0.ambr.downlink.value": NumberInt(1),
      "slice.0.session.0.ambr.downlink.unit": NumberInt(0),
      "ambr.uplink.value": NumberInt(1),
      "ambr.uplink.unit": NumberInt(0),
      "ambr.downlink.value": NumberInt(1),
      "ambr.downlink.unit": NumberInt(0),
      "schema_version": NumberInt(1)
    }
  }
);
print("Resultado de la actualización:");
printjson(db.subscribers.findOne({imsi: "001010123456789"}));
