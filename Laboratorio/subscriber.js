db = db.getSiblingDB('open5gs');

db.subscribers.insertOne({
  imsi: "001010123456789",
  msisdn: [],
  imeisv: [],
  mme_host: [],
  mme_realm: [],
  purge_flag: [],
  slice: [
    {
      sst: 1,
      default_indicator: true,
      session: [
        {
          name: "srsapn",
          type: 3,
          pcc_rule: [],
          ambr: {
            uplink: { value: 1, unit: 0 },
            downlink: { value: 1, unit: 0 }
          },
          qos: {
            index: 9,
            arp: { priority_level: 8, pre_emption_capability: 1, pre_emption_vulnerability: 1 }
          }
        }
      ]
    }
  ],
  ambr: {
    uplink: { value: 1, unit: 0 },
    downlink: { value: 1, unit: 0 }
  },
  security: {
    k: "00112233445566778899aabbccddeeff",
    amf: "8000",
    op: null,
    opc: "63bfa50ee6523365ff14c1f45f88737d",
    sqn: 0
  },
  schema_version: 1,
  __v: 0
});

print("Suscriptor insertado correctamente");
